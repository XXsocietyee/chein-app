import Foundation

/// Actual original sort configuration, carried privately through the same source/review ledger.
/// This is not a sample challenge and is never copied into the public static assets.
public struct H5OriginalSortSource: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Sendable { public let id: String; public let label: String }
    public let enabled: Bool
    public let prompt: String
    public let items: [Item]
    public let answerOrder: [String]
    public let maxAttempts: Int
    public let xp: Int
    static func read(_ bytes: Data) throws -> Self {
        let object = try QmodSourceSubmissionWire.object(bytes)
        try QmodSourceSubmissionWire.keys(object, ["enabled", "prompt", "items", "answerOrder", "maxAttempts", "xp"])
        guard let items = object["items"] as? [[String: Any]] else { throw QmodSourceSubmissionIssue.invalidPackage }
        for item in items { try QmodSourceSubmissionWire.keys(item, ["id", "label"]) }
        let value = try JSONDecoder().decode(Self.self, from: bytes)
        try value.validate(); return value
    }
    func validate() throws {
        let ids = Set(items.map(\.id))
        guard enabled, maxAttempts == 0, xp == 0, !prompt.isEmpty, prompt.utf16.count <= 2000,
              (2...8).contains(items.count), ids.count == items.count,
              answerOrder.count == items.count, Set(answerOrder) == ids,
              items.allSatisfy({ !$0.id.isEmpty && $0.id.utf16.count <= 128 && !$0.label.isEmpty && $0.label.utf16.count <= 2000 })
        else { throw QmodSourceSubmissionIssue.invalidPackage }
    }
}

public enum H5SourceSubmissionInspection {
    /// A private importer sidecar. Its bytes are parsed into nativeSort, not served as a manifest asset.
    public static let privateRulePath = "h5-native-sort.json"
    static func source(entries: [String: Data]) throws -> QmodSourceSubmissionSource {
        guard let manifest = entries["manifest.json"] else { throw QmodSourceSubmissionIssue.invalidPackage }
        let rule = try entries[privateRulePath].map { bytes in
            try QmodSourceLocalInputFailure.check("PRIVATE_RULE_BYTES", path: privateRulePath, actual: Int64(bytes.count), localFileLimit: 1 << 20)
            return try H5OriginalSortSource.read(bytes)
        }
        return QmodSourceSubmissionSource(manifest: manifest,
            files: entries.filter { $0.key != "manifest.json" && $0.key != privateRulePath }, nativeSort: rule)
    }
    static func validate(_ source: QmodSourceSubmissionSource) throws -> (packageId: String, packageVersion: String, locale: String, title: String, minimumHostVersion: String) {
        let bytes = try source.exactBytes()
        guard let manifest = bytes["manifest.json"] else { throw QmodSourceSubmissionIssue.invalidPackage }
        try QmodSourceLocalInputFailure.check("H5_MANIFEST_BYTES", path: "manifest.json", actual: Int64(manifest.count))
        let m = try QmodSourceSubmissionWire.object(manifest, limit: 262_144)
        try QmodSourceSubmissionWire.keys(m, ["formatVersion","kind","packageId","packageVersion","entrypoint","locales","runtime","dependencies","files","rightsDeclaration","monetizationDeclaration","networkProfile","resultContract","nativeCapabilities"])
        func require(_ value: Bool) throws { guard value else { throw QmodSourceSubmissionIssue.invalidPackage } }
        func text(_ value: Any?, maximum: Int) throws -> String {
            guard let value = value as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.utf16.count <= maximum else { throw QmodSourceSubmissionIssue.invalidPackage }; return value
        }
        func version(_ value: String) -> Bool { value.range(of: "\\A[0-9]{1,8}\\.[0-9]{1,8}\\.[0-9]{1,8}\\z", options: .regularExpression) != nil }
        try require(m["kind"] as? String == "questify.h5" && m["formatVersion"] as? String == "1.0" && m["entrypoint"] as? String == "index.html" && m["networkProfile"] as? String == "STATIC_ONLY")
        let id = try text(m["packageId"], maximum: 64), release = try text(m["packageVersion"], maximum: 32)
        try require(id.range(of: "\\A[a-z][a-z0-9._-]{0,63}\\z", options: .regularExpression) != nil && version(release))
        guard let locales = m["locales"] as? [String], (1...2).contains(locales.count), Set(locales).count == locales.count,
              Set(locales).isSubset(of: ["zh-Hans","en"]), let dependencies = m["dependencies"] as? [Any], dependencies.isEmpty,
              let caps = m["nativeCapabilities"] as? [Any], caps.isEmpty,
              let money = m["monetizationDeclaration"] as? [String], (1...4).contains(money.count), Set(money).count == money.count,
              Set(money).isSubset(of: ["NONE","MERCHANT_FUNDED","IAA","DIGITAL_SALE"]),
              let runtime = m["runtime"] as? [String: Any] else { throw QmodSourceSubmissionIssue.invalidPackage }
        _ = try text(m["rightsDeclaration"], maximum: 2000)
        try QmodSourceSubmissionWire.keys(runtime, ["minHostVersion","requiredCapabilities"])
        let minimum = try text(runtime["minHostVersion"], maximum: 32)
        let required = runtime["requiredCapabilities"] as? [String]
        let wasm = required == ["h5.web-relay.v1", "h5.wasm.single-thread.v1"]
        try require(version(minimum) && (required == ["h5.web-relay.v1"] || wasm))
        try require(wasm == bytes.keys.contains("h5-wasm-build.json"))
        let hasPck = bytes.keys.contains { ($0 as NSString).pathExtension.lowercased() == "pck" }
        let hasUnityData = bytes.keys.contains { path in
            let logical = (path as NSString).pathExtension.lowercased() == "gz" ? (path as NSString).deletingPathExtension : path
            return (logical as NSString).pathExtension.lowercased() == "data"
        }
        if hasPck || hasUnityData {
            // Transport declaration only: original server must parse, process all embedded media and rebuild.
            guard let buildBytes = bytes["h5-wasm-build.json"] else { throw QmodSourceSubmissionIssue.invalidPackage }
            let build = try QmodSourceSubmissionWire.object(buildBytes, limit: 8_388_608)
            var fields = Set(["profile", "resources"])
            if hasPck { fields.insert("godotPckProfile") }
            if hasUnityData { fields.insert("unityWebDataProfile") }
            try require(Set(build.keys) == fields && wasm && build["profile"] as? String == "h5-wasm-webgl-single-thread-v1")
            if hasPck { try require(["godot-4.3.0-pck2-gst2-png-webp-v1", "godot-4.3.0-pck2-gst2-rsrc6-ecfg-gdsc100-v2"].contains(build["godotPckProfile"] as? String ?? "")) }
            if hasUnityData { try require(build["unityWebDataProfile"] as? String == "unity-webdata1-raw-media-v1") }
        }
        switch m["resultContract"] as? String {
        case "card-order.v1": guard let rule = source.nativeSort else { throw QmodSourceSubmissionIssue.invalidPackage }; try rule.validate()
        case "cosmetic.v1": try require(source.nativeSort == nil)
        default: throw QmodSourceSubmissionIssue.invalidPackage
        }
        guard let files = m["files"] as? [[String: Any]], !files.isEmpty else { throw QmodSourceSubmissionIssue.invalidPackage }
        try QmodSourceLocalInputFailure.check("H5_RESOURCES", path: "manifest.json", actual: Int64(files.count))
        try QmodSourceLocalInputFailure.check("H5_RESOURCES", path: "manifest.json", actual: Int64(source.filesBase64.count))
        guard files.count + 1 == bytes.count else { throw QmodSourceSubmissionIssue.invalidPackage }
        var seen = Set<String>(), folded = Set<String>()
        for file in files {
            try QmodSourceSubmissionWire.keys(file, ["path","sha256","bytes"])
            let path = try text(file["path"], maximum: 200)
            try require(path != privateRulePath && path != "manifest.json" && path.range(of: "\\A[A-Za-z0-9_./-]+\\z", options: .regularExpression) != nil
                && !path.hasPrefix("/") && !path.hasSuffix("/") && !path.contains("//")
                && !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." })
                && seen.insert(path).inserted && folded.insert(path.lowercased()).inserted)
            try require(["wasm","gz","pck","data","html","css","js","mjs","json","ccon","cconb","tmj","tsj","tmx","tsx","csv","skel","gltf","glb","bin","babylon","txt","atlas","glsl","vert","frag","xml","fnt","png","jpg","jpeg","webp","gif","mp3","aac","m4a","wav","mp4","mov","ttf","otf","woff","woff2"].contains((path as NSString).pathExtension.lowercased()))
            let suffix = (path as NSString).pathExtension.lowercased()
            if ["wasm", "gz", "pck", "data"].contains(suffix) { try require(wasm) }
            if suffix == "gz" { try require(["wasm", "js", "mjs", "data"].contains(((path as NSString).deletingPathExtension as NSString).pathExtension.lowercased())) }
            try require(!path.split(separator: "/").contains(where: { ["node_modules", ".git"].contains($0.lowercased()) })
                && !["package.json", "package-lock.json", "npm-shrinkwrap.json"].contains((path as NSString).lastPathComponent.lowercased()))
            guard let asset = bytes[path], let size = file["bytes"] as? NSNumber,
                  ["i","q","s","l"].contains(String(cString: size.objCType)), size.int64Value == Int64(asset.count),
                  file["sha256"] as? String == QmodSourceSubmissionWire.hash(asset) else { throw QmodSourceSubmissionIssue.invalidPackage }
        }
        try require(seen.contains("index.html"))
        return (id, release, locales[0], id, minimum)
    }
}
