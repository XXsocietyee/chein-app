import Foundation
import CryptoKit
import Observation

// MARK: - DESIGNED: External Game Import, Validation, Sandboxed Storage & Versioned Bridge
// Note: Searched the mini-program (`chengyinhub-xcx`) first; no external game import mechanism exists there.
// Per W8 task spec, this module is minimally designed and labeled `DESIGNED` inside the existing Play backpack/game library.

public enum ExternalGamePermission: String, Codable, CaseIterable, Equatable, Sendable {
    case storage = "storage"
    case haptics = "haptics"
    case audio = "audio"

    public var displayName: String {
        switch self {
        case .storage: return W8Text.t("本地进度存档（仅限本游戏沙盒）", "Local progress save (this game's sandbox only)")
        case .haptics: return W8Text.t("触感反馈（轻触震动）", "Haptic feedback (light taps)")
        case .audio: return W8Text.t("背景音效播放", "Background audio playback")
        }
    }
}

public enum ExternalGameContentRating: String, Codable, CaseIterable, Equatable, Sendable {
    case fourPlus = "4+"
    case ninePlus = "9+"
    case twelvePlus = "12+"
    case seventeenPlus = "17+"
}

public enum ExternalGameImportSource: Codable, Equatable, Sendable {
    case url(URL)
    case qrCode(String)
    case file(URL)

    public var sourceKindLabel: String {
        switch self {
        case .url: return W8Text.t("链接导入 (URL)", "Import by link (URL)")
        case .qrCode: return W8Text.t("扫码导入 (QR)", "Import by QR scan (QR)")
        case .file: return W8Text.t("文件导入 (Files / 分享)", "Import from file (Files / Share)")
        }
    }

    public var displayOrigin: String {
        switch self {
        case .url(let url): return url.absoluteString
        case .qrCode(let raw): return raw
        case .file(let url): return url.lastPathComponent
        }
    }
}

public struct ExternalGameManifest: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let entry: String
    public let permissions: [String]
    public let contentRating: String
    public let allowedDomains: [String]
    public let sha256: String
    public let signature: String
    public let author: String?
    public let summary: String?

    public init(
        id: String,
        name: String,
        version: String,
        entry: String,
        permissions: [String] = [],
        contentRating: String = "4+",
        allowedDomains: [String] = [],
        sha256: String,
        signature: String,
        author: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.entry = entry
        self.permissions = permissions
        self.contentRating = contentRating
        self.allowedDomains = allowedDomains
        self.sha256 = sha256
        self.signature = signature
        self.author = author
        self.summary = summary
    }
}

public struct ExternalGamePackageArchive: Codable, Equatable, Sendable {
    public let manifest: ExternalGameManifest
    /// Map of relative file paths inside the package to UTF-8 or Base64 file contents.
    public let files: [String: Data]

    public init(manifest: ExternalGameManifest, files: [String: Data]) {
        self.manifest = manifest
        self.files = files
    }
}

public enum ExternalGameValidationError: Error, LocalizedError, Equatable, Sendable {
    case invalidManifestID(String)
    case invalidManifestName
    case invalidManifestVersion(String)
    case invalidContentRating(String)
    case pathTraversalDetected(String)
    case disallowedFileExtension(String)
    case missingEntryFile(String)
    case packageOversized(Int, maxAllowed: Int)
    case fileOversized(String, Int, maxAllowed: Int)
    case tooManyFiles(Int, maxAllowed: Int)
    case unsignedManifest
    case invalidSignature
    case hashMismatch(expected: String, actual: String)
    case forbiddenPermission(String)
    case invalidAllowedDomain(String)
    case tooManyAllowedDomains(Int)
    case insecureImportURL(String)
    case paymentOrIAPDetected(String)
    case symlinkOrEscapeDetected(String)
    case malformedArchive
    /// FP-H4: the user blocked this package or its creator on this device.
    case blockedByUser(String)

    public var errorDescription: String? {
        switch self {
        case .invalidManifestID(let id):
            return W8Text.t("游戏标识无效（\(id)），须为 3–64 位小写字母、数字、点、下划线或连字符", "Invalid game ID (\(id)); use 3–64 letters, digits, dots, underscores or hyphens")
        case .invalidManifestName:
            return W8Text.t("游戏名称不能为空且不能超过 80 个字符", "Game name must not be empty or exceed 80 characters")
        case .invalidManifestVersion(let ver):
            return W8Text.t("版本号格式无效（\(ver)），须符合 x.y.z 语义化版本", "Invalid version (\(ver)); use semantic version x.y.z")
        case .invalidContentRating(let rating):
            return W8Text.t("内容分级无效（\(rating)），仅支持 4+、9+、12+、17+", "Invalid content rating (\(rating)); only 4+, 9+, 12+, 17+ are supported")
        case .pathTraversalDetected(let path):
            return W8Text.t("检测到非法路径或目录穿越：\(path)", "Illegal path or directory traversal detected: \(path)")
        case .disallowedFileExtension(let path):
            return W8Text.t("包含不允许的文件类型：\(path)", "Contains a disallowed file type: \(path)")
        case .missingEntryFile(let entry):
            return W8Text.t("缺少入口文件：\(entry)", "Missing entry file: \(entry)")
        case .packageOversized(let size, let maxAllowed):
            return W8Text.t("游戏包体积超限（\(size) 字节，上限 \(maxAllowed) 字节）", "Package too large (\(size) bytes, limit \(maxAllowed) bytes)")
        case .fileOversized(let path, let size, let maxAllowed):
            return W8Text.t("单文件体积超限（\(path)：\(size) 字节，上限 \(maxAllowed) 字节）", "File too large (\(path): \(size) bytes, limit \(maxAllowed) bytes)")
        case .tooManyFiles(let count, let maxAllowed):
            return W8Text.t("文件数量超限（\(count) 个，上限 \(maxAllowed) 个）", "Too many files (\(count), limit \(maxAllowed))")
        case .unsignedManifest:
            return W8Text.t("游戏包缺少数字签名或哈希摘要", "Package is missing a digital signature or hash digest")
        case .invalidSignature:
            return W8Text.t("游戏包数字签名校验未通过", "Package signature verification failed")
        case .hashMismatch:
            return W8Text.t("游戏包内容哈希（SHA-256）与清单不一致", "Package content hash (SHA-256) does not match the manifest")
        case .forbiddenPermission(let perm):
            return W8Text.t("请求了未授权或禁止的权限：\(perm)", "Requested a forbidden or unauthorized permission: \(perm)")
        case .invalidAllowedDomain(let domain):
            return W8Text.t("包含不安全或非法的域名白名单：\(domain)", "Contains an unsafe or invalid allowed domain: \(domain)")
        case .tooManyAllowedDomains(let count):
            return W8Text.t("域名白名单数量超限（\(count) 个，最多 10 个）", "Too many allowed domains (\(count); maximum 10)")
        case .insecureImportURL(let url):
            return W8Text.t("仅允许从安全的 HTTPS 地址导入：\(url)", "Import is only allowed from a secure HTTPS address: \(url)")
        case .paymentOrIAPDetected(let detail):
            return W8Text.t("外部导入游戏禁止包含支付或内购调用：\(detail)", "Imported games must not contain payment or in-app purchase calls: \(detail)")
        case .symlinkOrEscapeDetected(let path):
            return W8Text.t("检测到符号链接或沙盒目录越界：\(path)", "Symbolic link or sandbox escape detected: \(path)")
        case .malformedArchive:
            return W8Text.t("游戏包格式损坏或无法解析", "Package is corrupt or cannot be parsed")
        case .blockedByUser(let name):
            return W8Text.t("你已屏蔽「\(name)」，无法导入或运行", "You blocked \"\(name)\" on this device, so it cannot be imported or run")
        }
    }
}

public enum ExternalGameValidator {
    public static let maxPackageSizeBytes = 10 * 1024 * 1024 // 10 MiB
    public static let maxSingleFileSizeBytes = 5 * 1024 * 1024 // 5 MiB
    public static let maxFileCount = 200
    public static let maxAllowedDomains = 10

    public static let allowedFileExtensions: Set<String> = [
        "html", "htm", "css", "js", "mjs", "json",
        "png", "jpg", "jpeg", "webp", "svg", "gif",
        "mp3", "wav", "ogg", "woff2", "txt"
    ]

    public static let forbiddenPermissions: Set<String> = [
        "payment", "iap", "in-app-purchase", "apple-pay", "wechat-pay", "alipay",
        "camera", "microphone", "location", "geolocation", "contacts", "photos",
        "bluetooth", "nfc", "native-bridge", "eval", "filesystem", "notifications"
    ]

    public static let forbiddenContentTokens: [String] = [
        "PaymentRequest",
        "ApplePaySession",
        "itms-apps://",
        "weixin://wap/pay",
        "alipays://",
        "webkit.messageHandlers.nativePay",
        "StoreKit",
    ]

    public static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= 240 else { return false }
        if path.hasPrefix("/") || path.hasPrefix("\\") || path.hasPrefix("~") { return false }
        if path.contains("\\") || path.contains("\0") || path.contains(":") { return false }
        if path.contains("//") { return false }
        let segments = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !segments.isEmpty else { return false }
        for seg in segments {
            if seg.isEmpty || seg == "." || seg == ".." { return false }
            if seg.hasPrefix(".") { return false }
            if seg.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                return false
            }
        }
        return true
    }

    public static func hasAllowedExtension(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return allowedFileExtensions.contains(ext)
    }

    public static func isValidDomain(_ rawDomain: String) -> Bool {
        let domain = rawDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !domain.isEmpty, domain.utf8.count <= 253 else { return false }
        // Reject schemes, ports, paths, wildcards, credentials, and IPv6 literals
        if domain.contains("://") || domain.contains("/") || domain.contains(":")
            || domain.contains("*") || domain.contains("@") || domain.contains("?")
            || domain.contains("#") || domain.contains("[") || domain.contains("]") {
            return false
        }
        // Reject localhost and local domains
        if domain == "localhost" || domain.hasSuffix(".local") || domain.hasSuffix(".internal") || domain.hasSuffix(".lan") {
            return false
        }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard labels.count >= 2 else { return false }
        // Reject IPv4 literals (especially loopback 127.*, private 10.*, 192.168.*, 172.16-31.*, link-local 169.254.*)
        if labels.allSatisfy({ $0.allSatisfy(\.isNumber) }) {
            return false
        }
        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            guard !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
            guard label.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.contains($0) || $0 == "-"
            }) else { return false }
        }
        guard let tld = labels.last, tld.count >= 2, !tld.allSatisfy(\.isNumber) else { return false }
        return true
    }

    public static func validateImportURL(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https",
              let host = url.host,
              isValidDomain(host),
              url.user == nil,
              url.password == nil else {
            throw ExternalGameValidationError.insecureImportURL(url.absoluteString)
        }
    }

    public static func computeDataSHA256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func computePackageSHA256(_ files: [String: Data]) -> String {
        var hasher = SHA256()
        for path in files.keys.sorted() {
            let data = files[path] ?? Data()
            hasher.update(data: Data(path.utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: Data("\(data.count)".utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: data)
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func canonicalSigningPayload(for manifest: ExternalGameManifest) -> Data {
        let perms = manifest.permissions.joined(separator: ",")
        let domains = manifest.allowedDomains.map { $0.lowercased() }.joined(separator: ",")
        let canonical = [
            "v1",
            manifest.id,
            manifest.name,
            manifest.version,
            manifest.entry,
             perms,
            manifest.contentRating,
            domains,
            manifest.sha256.lowercased(),
        ].joined(separator: "|")
        return Data(canonical.utf8)
    }

    public static func dataFromHex(_ hex: String) -> Data? {
        let text = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty, text.count.isMultiple(of: 2) else { return nil }
        var out = Data()
        out.reserveCapacity(text.count / 2)
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            guard let byte = UInt8(text[index..<next], radix: 16) else { return nil }
            out.append(byte)
            index = next
        }
        return out
    }

    /// Ed25519 over `canonicalSigningPayload`. `publicKeyRaw` is the 32-byte key from
    /// `GET /api/external-game/signing-key`. The app holds no signing secret.
    public static func verifyServerSignature(_ manifest: ExternalGameManifest, publicKeyRaw: Data) -> Bool {
        let sigHex = manifest.signature.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard sigHex.count == 128, publicKeyRaw.count == 32,
              let signature = dataFromHex(sigHex), signature.count == 64,
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRaw) else { return false }
        return key.isValidSignature(signature, for: canonicalSigningPayload(for: manifest))
    }

    /// Hash and HTML/JS structure only. The server ignores a client signature and issues its own.
    public static func validatePackageStructure(_ archive: ExternalGamePackageArchive) throws {
        try validateCommon(archive)
    }

    public static func validateArchive(
        _ archive: ExternalGamePackageArchive,
        publicKeyRaw: Data = Data()
    ) throws {
        try validateCommon(archive)
        let sig = archive.manifest.signature.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard sig.range(of: "^[0-9a-f]{128}$", options: .regularExpression) != nil else {
            throw ExternalGameValidationError.unsignedManifest
        }
        guard verifyServerSignature(archive.manifest, publicKeyRaw: publicKeyRaw) else {
            throw ExternalGameValidationError.invalidSignature
        }
    }

    public static func isValidPackageID(_ id: String) -> Bool {
        id.range(of: "^[a-z0-9][a-z0-9._-]{2,63}$", options: .regularExpression) != nil
    }

    private static func validateCommon(_ archive: ExternalGamePackageArchive) throws {
        let manifest = archive.manifest

        // 1. Validate ID, Name, Version, Content Rating
        guard isValidPackageID(manifest.id) else {
            throw ExternalGameValidationError.invalidManifestID(manifest.id)
        }
        let trimmedName = manifest.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 80 else {
            throw ExternalGameValidationError.invalidManifestName
        }
        guard manifest.version.range(of: "^\\d+\\.\\d+\\.\\d+$", options: .regularExpression) != nil else {
            throw ExternalGameValidationError.invalidManifestVersion(manifest.version)
        }
        guard ExternalGameContentRating(rawValue: manifest.contentRating) != nil else {
            throw ExternalGameValidationError.invalidContentRating(manifest.contentRating)
        }

        // 2. Validate entry path
        guard isSafeRelativePath(manifest.entry) else {
            throw ExternalGameValidationError.pathTraversalDetected(manifest.entry)
        }
        let entryExt = (manifest.entry as NSString).pathExtension.lowercased()
        guard entryExt == "html" || entryExt == "htm" else {
            throw ExternalGameValidationError.disallowedFileExtension(manifest.entry)
        }

        // 3. Validate permissions (no payment/IAP or elevated native rights)
        for perm in manifest.permissions {
            let normalized = perm.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if forbiddenPermissions.contains(normalized) || ExternalGamePermission(rawValue: normalized) == nil {
                throw ExternalGameValidationError.forbiddenPermission(perm)
            }
        }

        // 4. Validate allowed domains
        guard manifest.allowedDomains.count <= maxAllowedDomains else {
            throw ExternalGameValidationError.tooManyAllowedDomains(manifest.allowedDomains.count)
        }
        for domain in manifest.allowedDomains {
            guard isValidDomain(domain) else {
                throw ExternalGameValidationError.invalidAllowedDomain(domain)
            }
        }

        // 5. Validate file count, paths, extensions, sizes, and forbidden payment/IAP calls
        guard !archive.files.isEmpty, archive.files.count <= maxFileCount else {
            throw ExternalGameValidationError.tooManyFiles(archive.files.count, maxAllowed: maxFileCount)
        }
        var totalBytes = 0
        for (path, data) in archive.files {
            guard isSafeRelativePath(path) else {
                throw ExternalGameValidationError.pathTraversalDetected(path)
            }
            guard hasAllowedExtension(path) else {
                throw ExternalGameValidationError.disallowedFileExtension(path)
            }
            guard data.count <= maxSingleFileSizeBytes else {
                throw ExternalGameValidationError.fileOversized(path, data.count, maxAllowed: maxSingleFileSizeBytes)
            }
            totalBytes += data.count
            guard totalBytes <= maxPackageSizeBytes else {
                throw ExternalGameValidationError.packageOversized(totalBytes, maxAllowed: maxPackageSizeBytes)
            }

            let ext = (path as NSString).pathExtension.lowercased()
            if ["html", "htm", "js", "mjs"].contains(ext),
               let text = String(data: data, encoding: .utf8) {
                for token in forbiddenContentTokens where text.contains(token) {
                    throw ExternalGameValidationError.paymentOrIAPDetected(token)
                }
            }
        }

        guard let entryData = archive.files[manifest.entry] else {
            throw ExternalGameValidationError.missingEntryFile(manifest.entry)
        }
        guard String(data: entryData, encoding: .utf8) != nil else {
            throw ExternalGameValidationError.malformedArchive
        }

        let trimmedHash = manifest.sha256.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmedHash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw ExternalGameValidationError.unsignedManifest
        }
        let actualHash = computePackageSHA256(archive.files)
        guard actualHash == trimmedHash else {
            throw ExternalGameValidationError.hashMismatch(expected: trimmedHash, actual: actualHash)
        }
    }
}

// MARK: - Sandboxed Navigation Policy, Content-Security-Policy & Versioned JS Bridge

public enum ExternalGameSandboxPolicy {
    public static let bridgeName = "PlayExternalBridge"
    public static let supportedBridgeVersion = "1.0"

    /// Builds a strict Content-Security-Policy restricting script execution to `'self'`
    /// and network connections only to the manifest's validated `allowedDomains`.
    public static func contentSecurityPolicy(for manifest: ExternalGameManifest) -> String {
        let httpsDomains = manifest.allowedDomains
            .filter(ExternalGameValidator.isValidDomain)
            .map { "https://\($0.lowercased())" }
            .joined(separator: " ")
        let connectSrc = httpsDomains.isEmpty ? "'none'" : httpsDomains
        let imgSrc = httpsDomains.isEmpty ? "'self' data:" : "'self' data: \(httpsDomains)"
        return [
            "default-src 'self'",
            "script-src 'self'",
            "style-src 'self' 'unsafe-inline'",
            "img-src \(imgSrc)",
            "media-src 'self'",
            "connect-src \(connectSrc)",
            "frame-src 'none'",
            "object-src 'none'",
            "worker-src 'none'",
            "child-src 'none'",
            "base-uri 'none'",
            "form-action 'none'",
        ].joined(separator: "; ")
    }

    public static func injectedCSPMetaTag(for manifest: ExternalGameManifest) -> String {
        let csp = contentSecurityPolicy(for: manifest)
        return "<meta http-equiv=\"Content-Security-Policy\" content=\"\(csp)\">"
    }

    /// Strips any creator-supplied Content-Security-Policy meta tag (any case/quoting) and prepends the host's strict CSP.
    public static func applyStrictCSP(to html: String, manifest: ExternalGameManifest) -> String {
        let pattern = "<meta\\b[^>]*http-equiv\\s*=\\s*(['\"]?)\\s*content-security-policy\\s*\\1[^>]*>"
        var stripped = html
        while true {
            let next = stripped.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
            if next == stripped { break }
            stripped = next
        }
        return injectedCSPMetaTag(for: manifest) + "\n" + stripped
    }

    /// Evaluates whether a navigation or resource URL is permitted inside the sandboxed WKWebView.
    public static func allowsNavigation(
        to url: URL,
        packageRoot: URL,
        manifest: ExternalGameManifest
    ) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        // Explicitly block payment, app store, custom deep-link, and inline script schemes
        let blockedSchemes: Set<String> = [
            "javascript", "data", "blob", "about", "tel", "mailto", "sms",
            "itms-apps", "itms-services", "weixin", "alipays", "alipay"
        ]
        if blockedSchemes.contains(scheme) { return false }

        if scheme == "file" {
            let resolvedRoot = packageRoot.resolvingSymlinksInPath().standardizedFileURL.path
            let resolvedTarget = url.resolvingSymlinksInPath().standardizedFileURL.path
            let rootPrefix = resolvedRoot.hasSuffix("/") ? resolvedRoot : (resolvedRoot + "/")
            guard resolvedTarget.hasPrefix(rootPrefix) else { return false }
            let relative = String(resolvedTarget.dropFirst(rootPrefix.count))
            return ExternalGameValidator.isSafeRelativePath(relative)
                && ExternalGameValidator.hasAllowedExtension(relative)
        }

        if scheme == "https" {
            guard url.user == nil, url.password == nil, let host = url.host?.lowercased() else {
                return false
            }
            let allowed = Set(manifest.allowedDomains.map { $0.lowercased() })
            return allowed.contains(host)
        }

        return false
    }
}

public struct ExternalGameBridgeRequest: Codable, Equatable, Sendable {
    public let apiVersion: String
    public let action: String
    public let payload: [String: String]?

    public init(apiVersion: String = "1.0", action: String, payload: [String: String]? = nil) {
        self.apiVersion = apiVersion
        self.action = action
        self.payload = payload
    }
}

public struct ExternalGameBridgeResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let apiVersion: String
    public let data: [String: String]?
    public let error: String?

    public init(ok: Bool, apiVersion: String = "1.0", data: [String: String]? = nil, error: String? = nil) {
        self.ok = ok
        self.apiVersion = apiVersion
        self.data = data
        self.error = error
    }
}

public enum ExternalGameBridgeHandler {
    public static let maxPayloadBytes = 16 * 1024 // 16 KiB
    public static let maxTotalProgressEntries = 64
    public static let maxTotalProgressBytes = 64 * 1024 // 64 KiB
    public static let allowedHapticStyles: Set<String> = ["light", "medium", "heavy", "selection", "success", "warning", "error"]

    private static func isValidStorageKey(_ key: String) -> Bool {
        key.range(of: "^[A-Za-z0-9._-]{1,64}$", options: .regularExpression) != nil
    }

    private static func isValidStorageValue(_ value: String) -> Bool {
        value.utf8.count <= 2048 && !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
    }

    public static func handle(
        rawJSON: Data,
        manifest: ExternalGameManifest,
        progressStore: inout [String: String]
    ) -> ExternalGameBridgeResponse {
        guard rawJSON.count <= maxPayloadBytes,
              let req = try? JSONDecoder().decode(ExternalGameBridgeRequest.self, from: rawJSON) else {
            return ExternalGameBridgeResponse(ok: false, error: "INVALID_BRIDGE_MESSAGE")
        }
        guard req.apiVersion == ExternalGameSandboxPolicy.supportedBridgeVersion else {
            return ExternalGameBridgeResponse(ok: false, error: "UNSUPPORTED_API_VERSION")
        }
        let granted = Set(manifest.permissions.map { $0.lowercased() })

        switch req.action {
        case "getMetadata":
            guard (req.payload ?? [:]).isEmpty else {
                return ExternalGameBridgeResponse(ok: false, error: "INVALID_ARGUMENTS")
            }
            return ExternalGameBridgeResponse(
                ok: true,
                data: [
                    "id": manifest.id,
                    "name": manifest.name,
                    "version": manifest.version,
                    "contentRating": manifest.contentRating,
                ]
            )
        case "loadProgress":
            guard (req.payload ?? [:]).isEmpty else {
                return ExternalGameBridgeResponse(ok: false, error: "INVALID_ARGUMENTS")
            }
            guard granted.contains(ExternalGamePermission.storage.rawValue) else {
                return ExternalGameBridgeResponse(ok: false, error: "PERMISSION_DENIED_STORAGE")
            }
            return ExternalGameBridgeResponse(ok: true, data: progressStore)
        case "saveProgress":
            guard granted.contains(ExternalGamePermission.storage.rawValue) else {
                return ExternalGameBridgeResponse(ok: false, error: "PERMISSION_DENIED_STORAGE")
            }
            let incoming = req.payload ?? [:]
            guard incoming.count <= 32,
                  incoming.allSatisfy({ isValidStorageKey($0.key) && isValidStorageValue($0.value) }) else {
                return ExternalGameBridgeResponse(ok: false, error: "STORAGE_QUOTA_EXCEEDED")
            }
            var candidate = progressStore
            for (k, v) in incoming { candidate[k] = v }
            let totalBytes = candidate.reduce(0) { $0 + $1.key.utf8.count + $1.value.utf8.count }
            guard candidate.count <= maxTotalProgressEntries, totalBytes <= maxTotalProgressBytes else {
                return ExternalGameBridgeResponse(ok: false, error: "STORAGE_QUOTA_EXCEEDED")
            }
            progressStore = candidate
            return ExternalGameBridgeResponse(ok: true, data: ["saved": "true"])
        case "haptic":
            guard granted.contains(ExternalGamePermission.haptics.rawValue) else {
                return ExternalGameBridgeResponse(ok: false, error: "PERMISSION_DENIED_HAPTICS")
            }
            if let payload = req.payload, !payload.isEmpty {
                guard Set(payload.keys) == ["style"],
                      let style = payload["style"], allowedHapticStyles.contains(style) else {
                    return ExternalGameBridgeResponse(ok: false, error: "INVALID_ARGUMENTS")
                }
            }
            return ExternalGameBridgeResponse(ok: true, data: ["triggered": "true"])
        case "submitResult":
            let payload = req.payload ?? [:]
            guard Set(payload.keys).isSubset(of: ["passed", "score", "digest"]),
                  let rawPassed = payload["passed"] else {
                return ExternalGameBridgeResponse(ok: false, error: "INVALID_ARGUMENTS")
            }
            let lower = rawPassed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let passed: Bool
            if lower == "true" || lower == "1" { passed = true }
            else if lower == "false" || lower == "0" { passed = false }
            else { return ExternalGameBridgeResponse(ok: false, error: "INVALID_ARGUMENTS") }
            var score: Int?
            if let rawScore = payload["score"] {
                guard let parsed = Int(rawScore.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    return ExternalGameBridgeResponse(ok: false, error: "INVALID_ARGUMENTS")
                }
                score = parsed
            }
            var data: [String: String] = ["accepted": "true", "passed": passed ? "true" : "false"]
            if let score { data["score"] = String(score) }
            if let digest = payload["digest"], !digest.isEmpty, digest.count <= 128 { data["digest"] = digest }
            return ExternalGameBridgeResponse(ok: true, data: data)
        default:
            return ExternalGameBridgeResponse(ok: false, error: "ACTION_NOT_ALLOWLISTED")
        }
    }
}

// MARK: - Sandboxed Package Store (List / Install / Update / Remove)

public struct InstalledExternalGame: Codable, Equatable, Identifiable, Sendable {
    public var id: String { manifest.id }
    public let manifest: ExternalGameManifest
    public let source: ExternalGameImportSource
    public let installedAt: Date
    public var updatedAt: Date
    public let totalBytes: Int
    public let hardenedEntrySHA256: String?
    public let hardenedPackageSHA256: String?

    public init(
        manifest: ExternalGameManifest,
        source: ExternalGameImportSource,
        installedAt: Date,
        updatedAt: Date,
        totalBytes: Int,
        hardenedEntrySHA256: String? = nil,
        hardenedPackageSHA256: String? = nil
    ) {
        self.manifest = manifest
        self.source = source
        self.installedAt = installedAt
        self.updatedAt = updatedAt
        self.totalBytes = totalBytes
        self.hardenedEntrySHA256 = hardenedEntrySHA256
        self.hardenedPackageSHA256 = hardenedPackageSHA256
    }
}

public struct ExternalGamePendingConfirmation: Equatable, Identifiable, Sendable {
    public var id: String { archive.manifest.id + "@" + archive.manifest.version }
    public let archive: ExternalGamePackageArchive
    public let source: ExternalGameImportSource
    public let isUpdate: Bool
    public let previousVersion: String?
    public let totalBytes: Int

    public var sha256Fingerprint: String {
        String(archive.manifest.sha256.prefix(16))
    }

    public var permissionsList: [ExternalGamePermission] {
        archive.manifest.permissions.compactMap { ExternalGamePermission(rawValue: $0.lowercased()) }
    }
}

@available(macOS 14.0, *)
public struct ExternalGameBridgeResult: Codable, Equatable, Sendable {
    public let gameID: String
    public let passed: Bool
    public let score: Int?
    public let digest: String?
    public let reportedAt: Date

    public init(gameID: String, passed: Bool, score: Int?, digest: String?, reportedAt: Date = Date()) {
        self.gameID = gameID
        self.passed = passed
        self.score = score
        self.digest = digest
        self.reportedAt = reportedAt
    }
}

@MainActor @Observable public final class ExternalGameStore {
    public let rootDirectory: URL
    /// 32-byte Ed25519 public key from the server. Empty until `GET /api/external-game/signing-key` succeeds.
    public private(set) var verificationPublicKey: Data
    public private(set) var installedGames: [InstalledExternalGame] = []
    public var pendingConfirmation: ExternalGamePendingConfirmation?
    public var activeLaunchingGame: InstalledExternalGame?
    public var lastBridgeResultByGameID: [String: ExternalGameBridgeResult] = [:]
    public private(set) var lastError: String = ""
    /// FP-H4. Local, device-only blocklist of package ids and creator names. It is not a server block and
    /// not a report; it only stops this device from importing or running the blocked package or creator.
    public private(set) var blockedPackageIDs: Set<String> = []
    public private(set) var blockedCreators: Set<String> = []

    private var progressByGameID: [String: [String: String]] = [:]
    private var ageGateAccepted: [String: String] = [:]

    public init(
        rootDirectory: URL? = nil,
        verificationPublicKey: Data = Data()
    ) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.rootDirectory = base.appendingPathComponent("ExternalGames-v1", isDirectory: true)
        }
        self.verificationPublicKey = verificationPublicKey
        loadRegistryFromDisk()
        loadBlocklistFromDisk()
        loadAgeGate()
        loadPermissions()
    }

    public static func normalizedCreator(_ author: String?) -> String? {
        guard let value = author?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else { return nil }
        return value
    }
    public func isBlocked(_ manifest: ExternalGameManifest) -> Bool {
        if blockedPackageIDs.contains(manifest.id) { return true }
        if let creator = Self.normalizedCreator(manifest.author), blockedCreators.contains(creator) { return true }
        return false
    }
    /// Blocks the package and, when the manifest names one, its creator; closes a running game.
    public func block(_ manifest: ExternalGameManifest, includingCreator: Bool = true) {
        blockedPackageIDs.insert(manifest.id)
        if includingCreator, let creator = Self.normalizedCreator(manifest.author) { blockedCreators.insert(creator) }
        if let active = activeLaunchingGame, isBlocked(active.manifest) { activeLaunchingGame = nil }
        saveBlocklistToDisk()
    }
    public func unblock(_ manifest: ExternalGameManifest) {
        blockedPackageIDs.remove(manifest.id)
        if let creator = Self.normalizedCreator(manifest.author) { blockedCreators.remove(creator) }
        saveBlocklistToDisk()
    }
    /// Plain-text summary. The in-app report posts to `/api/external-game/reports` separately.
    public func reportSummary(for manifest: ExternalGameManifest) -> String {
        [
            "Package report",
            "id: \(manifest.id)",
            "name: \(manifest.name)",
            "version: \(manifest.version)",
            "creator: \(manifest.author ?? "-")",
            "sha256: \(manifest.sha256)",
            "contentRating: \(manifest.contentRating)",
            "permissions: \(manifest.permissions.joined(separator: ","))",
            "allowedDomains: \(manifest.allowedDomains.joined(separator: ","))"
        ].joined(separator: "\n")
    }

    public func adoptVerificationKey(_ raw: Data) {
        verificationPublicKey = raw
    }

    public func ageGateNeedsConfirmation(_ manifest: ExternalGameManifest) -> Bool {
        ageGateAccepted[manifest.id] != manifest.contentRating
    }

    public func acceptAgeGate(_ manifest: ExternalGameManifest) {
        guard ExternalGameContentRating(rawValue: manifest.contentRating) != nil else { return }
        ageGateAccepted[manifest.id] = manifest.contentRating
        saveAgeGate()
    }

    /// Drops installed games whose ids are absent from a completed approved-catalog read.
    /// The caller must not invoke this when that read failed.
    @discardableResult
    public func removeUnpublished(approvedGameIDs: Set<String>) throws -> [String] {
        let gone = installedGames.map(\.manifest.id).filter { !approvedGameIDs.contains($0) }
        for id in gone {
            try remove(id: id)
        }
        return gone
    }

    public func packageDirectory(for gameID: String) -> URL {
        rootDirectory
            .appendingPathComponent("packages", isDirectory: true)
            .appendingPathComponent(gameID, isDirectory: true)
    }

    public func entryFileURL(for game: InstalledExternalGame) -> URL? {
        guard !isBlocked(game.manifest) else { return nil }
        guard verificationPublicKey.count == 32,
              ExternalGameValidator.verifyServerSignature(game.manifest, publicKeyRaw: verificationPublicKey) else { return nil }
        let pkgRoot = packageDirectory(for: game.manifest.id)
        let target = pkgRoot.appendingPathComponent(game.manifest.entry, isDirectory: false)
        guard ExternalGameSandboxPolicy.allowsNavigation(to: target, packageRoot: pkgRoot, manifest: game.manifest) else {
            return nil
        }
        guard verifyInstalledEntryIntegrity(target: target, game: game) else {
            return nil
        }
        return target
    }

    private func verifyInstalledEntryIntegrity(target: URL, game: InstalledExternalGame) -> Bool {
        let manifest = game.manifest
        guard let expectedEntryHash = game.hardenedEntrySHA256?.lowercased(),
              expectedEntryHash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              let expectedPackageHash = game.hardenedPackageSHA256?.lowercased(),
              expectedPackageHash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            return false
        }
        guard FileManager.default.fileExists(atPath: target.path),
              let onDiskEntryData = try? Data(contentsOf: target),
              ExternalGameValidator.computeDataSHA256(onDiskEntryData) == expectedEntryHash else {
            return false
        }
        let expectedPrefix = ExternalGameSandboxPolicy.injectedCSPMetaTag(for: manifest) + "\n"
        guard let onDiskHTML = String(data: onDiskEntryData, encoding: .utf8),
              onDiskHTML.hasPrefix(expectedPrefix) else {
            return false
        }
        let bodyAfterPrefix = String(onDiskHTML.dropFirst(expectedPrefix.count))
        guard ExternalGameSandboxPolicy.applyStrictCSP(to: bodyAfterPrefix, manifest: manifest) == onDiskHTML else {
            return false
        }

        let pkgRoot = packageDirectory(for: manifest.id).resolvingSymlinksInPath().standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(at: pkgRoot, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        var onDiskFiles: [String: Data] = [:]
        let rootPath = pkgRoot.path.hasSuffix("/") ? pkgRoot.path : (pkgRoot.path + "/")
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true else { return false }
            guard values.isRegularFile == true else { continue }
            let resolved = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            guard resolved.hasPrefix(rootPath) else { return false }
            let relPath = String(resolved.dropFirst(rootPath.count))
            guard ExternalGameValidator.isSafeRelativePath(relPath),
                  let raw = try? Data(contentsOf: fileURL) else { return false }
            onDiskFiles[relPath] = raw
        }
        guard onDiskFiles[manifest.entry] == onDiskEntryData else { return false }
        return ExternalGameValidator.computePackageSHA256(onDiskFiles) == expectedPackageHash
    }

    /// Validates an imported archive from URL, QR code, or local file and prepares a permission + source confirmation sheet.
    @discardableResult
    public func prepareImport(
        archive: ExternalGamePackageArchive,
        source: ExternalGameImportSource
    ) throws -> ExternalGamePendingConfirmation {
        lastError = ""
        switch source {
        case .url(let url):
            try ExternalGameValidator.validateImportURL(url)
        case .qrCode(let raw):
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed) else {
                throw ExternalGameValidationError.insecureImportURL(raw)
            }
            try ExternalGameValidator.validateImportURL(url)
        case .file:
            break
        }

        try ExternalGameValidator.validateArchive(archive, publicKeyRaw: verificationPublicKey)
        guard !isBlocked(archive.manifest) else { throw ExternalGameValidationError.blockedByUser(archive.manifest.name) }
        let totalBytes = archive.files.values.reduce(0) { $0 + $1.count }
        let existing = installedGames.first(where: { $0.manifest.id == archive.manifest.id })
        let confirmation = ExternalGamePendingConfirmation(
            archive: archive,
            source: source,
            isUpdate: existing != nil,
            previousVersion: existing?.manifest.version,
            totalBytes: totalBytes
        )
        pendingConfirmation = confirmation
        return confirmation
    }

    /// Parses and validates a JSON-encoded `ExternalGamePackageArchive` data blob.
    @discardableResult
    public func prepareImport(
        archiveData: Data,
        source: ExternalGameImportSource
    ) throws -> ExternalGamePendingConfirmation {
        guard archiveData.count <= ExternalGameValidator.maxPackageSizeBytes + 65_536,
              let archive = try? JSONDecoder().decode(ExternalGamePackageArchive.self, from: archiveData) else {
            lastError = ExternalGameValidationError.malformedArchive.localizedDescription
            throw ExternalGameValidationError.malformedArchive
        }
        return try prepareImport(archive: archive, source: source)
    }

    public func cancelPendingImport() {
        pendingConfirmation = nil
    }

    /// Commits the user-confirmed game package to the app sandbox.
    @discardableResult
    public func confirmInstall() throws -> InstalledExternalGame {
        guard let confirmation = pendingConfirmation else {
            throw ExternalGameValidationError.malformedArchive
        }
        try ExternalGameValidator.validateArchive(confirmation.archive, publicKeyRaw: verificationPublicKey)

        let manifest = confirmation.archive.manifest
        let pkgDir = packageDirectory(for: manifest.id)
        let fm = FileManager.default

        if fm.fileExists(atPath: pkgDir.path) {
            try fm.removeItem(at: pkgDir)
        }
        try fm.createDirectory(at: pkgDir, withIntermediateDirectories: true)

        let resolvedPkgRoot = pkgDir.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPrefix = resolvedPkgRoot.hasSuffix("/") ? resolvedPkgRoot : (resolvedPkgRoot + "/")

        var hardenedFiles: [String: Data] = [:]
        var hardenedEntrySHA256: String?

        for (relPath, content) in confirmation.archive.files {
            guard ExternalGameValidator.isSafeRelativePath(relPath) else {
                throw ExternalGameValidationError.pathTraversalDetected(relPath)
            }
            let fileURL = pkgDir.appendingPathComponent(relPath, isDirectory: false)
            let parentDir = fileURL.deletingLastPathComponent()
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
            let resolvedParent = parentDir.resolvingSymlinksInPath().standardizedFileURL.path
            guard resolvedParent == resolvedPkgRoot || resolvedParent.hasPrefix(rootPrefix) else {
                throw ExternalGameValidationError.symlinkOrEscapeDetected(relPath)
            }
            var dataToWrite = content
            // Strip any creator-supplied CSP meta tags and prepend the host's strict CSP before writing.
            if relPath == manifest.entry {
                guard let html = String(data: content, encoding: .utf8) else {
                    throw ExternalGameValidationError.malformedArchive
                }
                let hardenedHTML = ExternalGameSandboxPolicy.applyStrictCSP(to: html, manifest: manifest)
                dataToWrite = Data(hardenedHTML.utf8)
                hardenedEntrySHA256 = ExternalGameValidator.computeDataSHA256(dataToWrite)
            }
            hardenedFiles[relPath] = dataToWrite
            #if os(iOS)
            try dataToWrite.write(to: fileURL, options: [.atomic, .completeFileProtection])
            #else
            try dataToWrite.write(to: fileURL, options: [.atomic])
            #endif
        }

        guard let hardenedEntrySHA256 else {
            throw ExternalGameValidationError.missingEntryFile(manifest.entry)
        }
        let hardenedPackageSHA256 = ExternalGameValidator.computePackageSHA256(hardenedFiles)

        let now = Date()
        let installed: InstalledExternalGame
        if let idx = installedGames.firstIndex(where: { $0.manifest.id == manifest.id }) {
            let prev = installedGames[idx]
            installed = InstalledExternalGame(
                manifest: manifest,
                source: confirmation.source,
                installedAt: prev.installedAt,
                updatedAt: now,
                totalBytes: confirmation.totalBytes,
                hardenedEntrySHA256: hardenedEntrySHA256,
                hardenedPackageSHA256: hardenedPackageSHA256
            )
            installedGames[idx] = installed
        } else {
            installed = InstalledExternalGame(
                manifest: manifest,
                source: confirmation.source,
                installedAt: now,
                updatedAt: now,
                totalBytes: confirmation.totalBytes,
                hardenedEntrySHA256: hardenedEntrySHA256,
                hardenedPackageSHA256: hardenedPackageSHA256
            )
            installedGames.append(installed)
        }

        pendingConfirmation = nil
        permissionAccepted.insert(manifest.id + "@" + manifest.version)
        savePermissions()
        saveRegistryToDisk()
        return installed
    }

    public func remove(id: String) throws {
        let pkgDir = packageDirectory(for: id)
        if FileManager.default.fileExists(atPath: pkgDir.path) {
            try FileManager.default.removeItem(at: pkgDir)
        }
        installedGames.removeAll { $0.manifest.id == id }
        progressByGameID.removeValue(forKey: id)
        if activeLaunchingGame?.manifest.id == id {
            activeLaunchingGame = nil
        }
        saveRegistryToDisk()
    }

    public func handleBridgeMessage(_ rawJSON: Data, for gameID: String) -> ExternalGameBridgeResponse {
        guard let game = installedGames.first(where: { $0.manifest.id == gameID }) else {
            return ExternalGameBridgeResponse(ok: false, error: "GAME_NOT_INSTALLED")
        }
        var progress = progressByGameID[gameID] ?? [:]
        let response = ExternalGameBridgeHandler.handle(rawJSON: rawJSON, manifest: game.manifest, progressStore: &progress)
        progressByGameID[gameID] = progress
        saveProgressToDisk(for: gameID, progress: progress)
        if response.ok, let passedStr = response.data?["passed"] {
            let parsedScore = response.data?["score"].flatMap { Int($0) }
            let result = ExternalGameBridgeResult(
                gameID: gameID,
                passed: passedStr == "true",
                score: parsedScore,
                digest: response.data?["digest"],
                reportedAt: Date()
            )
            lastBridgeResultByGameID[gameID] = result
        }
        return response
    }

    public func progress(for gameID: String) -> [String: String] {
        progressByGameID[gameID] ?? [:]
    }

    /// Creates a signed sample external mini-game archive for local testing or demo import inside the backpack.
    public static func makeSampleSignedArchive(
        id: String = "rpg.campfire.riddle",
        name: String = "篝火谜题小游戏",
        version: String = "1.0.0",
        entry: String = "index.html",
        permissions: [String] = ["storage", "haptics"],
        contentRating: String = "4+",
        allowedDomains: [String] = ["assets.example.com"],
        sign: ((Data) -> String)? = nil
    ) -> ExternalGamePackageArchive {
        let html = """
        <!doctype html>
        <html lang="zh-CN">
        <head><meta charset="utf-8"><title>\(name)</title></head>
        <body>
          <h1>\(name)</h1>
          <p>版本 \(version) · 沙盒运行中</p>
        </body>
        </html>
        """
        let files: [String: Data] = [entry: Data(html.utf8)]
        let sha256 = ExternalGameValidator.computePackageSHA256(files)
        let unsigned = ExternalGameManifest(
            id: id,
            name: name,
            version: version,
            entry: entry,
            permissions: permissions,
            contentRating: contentRating,
            allowedDomains: allowedDomains,
            sha256: sha256,
            signature: "",
            author: "Chein Workshop",
            summary: "在背包沙盒内运行的轻量解谜互动"
        )
        let sig = sign?(ExternalGameValidator.canonicalSigningPayload(for: unsigned)) ?? String(repeating: "0", count: 128)
        let signed = ExternalGameManifest(
            id: id,
            name: name,
            version: version,
            entry: entry,
            permissions: permissions,
            contentRating: contentRating,
            allowedDomains: allowedDomains,
            sha256: sha256,
            signature: sig,
            author: "Chein Workshop",
            summary: "在背包沙盒内运行的轻量解谜互动"
        )
        return ExternalGamePackageArchive(manifest: signed, files: files)
    }

    // MARK: - Persistence Helpers

    private var registryFileURL: URL {
        rootDirectory.appendingPathComponent("registry.json", isDirectory: false)
    }

    private func progressFileURL(for gameID: String) -> URL {
        rootDirectory
            .appendingPathComponent("progress", isDirectory: true)
            .appendingPathComponent("\(gameID).json", isDirectory: false)
    }

    private func loadRegistryFromDisk() {
        guard let data = try? Data(contentsOf: registryFileURL),
              let decoded = try? JSONDecoder().decode([InstalledExternalGame].self, from: data) else {
            return
        }
        installedGames = decoded
        for game in decoded {
            let pURL = progressFileURL(for: game.manifest.id)
            if let pData = try? Data(contentsOf: pURL),
               let pMap = try? JSONDecoder().decode([String: String].self, from: pData) {
                progressByGameID[game.manifest.id] = pMap
            }
        }
    }

    public private(set) var permissionAccepted: Set<String> = []

    public func needsPermissionConfirmation(_ manifest: ExternalGameManifest) -> Bool {
        !manifest.permissions.isEmpty && !permissionAccepted.contains(manifest.id + "@" + manifest.version)
    }

    private func writeProtected(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
    }

    private var ageGateFileURL: URL { rootDirectory.appendingPathComponent("age-gate-v1.json", isDirectory: false) }
    private func loadAgeGate() {
        guard let data = try? Data(contentsOf: ageGateFileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        ageGateAccepted = decoded
    }
    private func saveAgeGate() {
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(ageGateAccepted) {
            try? writeProtected(data, to: ageGateFileURL)
        }
    }
    private var permissionFileURL: URL { rootDirectory.appendingPathComponent("permissions-v1.json", isDirectory: false) }
    private func loadPermissions() {
        guard let data = try? Data(contentsOf: permissionFileURL),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        permissionAccepted = decoded
    }
    private func savePermissions() {
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(permissionAccepted) {
            try? writeProtected(data, to: permissionFileURL)
        }
    }

    private var blocklistFileURL: URL { rootDirectory.appendingPathComponent("blocklist-v1.json", isDirectory: false) }
    private struct Blocklist: Codable { var packages: Set<String>; var creators: Set<String> }
    private func loadBlocklistFromDisk() {
        guard let data = try? Data(contentsOf: blocklistFileURL),
              let decoded = try? JSONDecoder().decode(Blocklist.self, from: data) else { return }
        blockedPackageIDs = decoded.packages; blockedCreators = decoded.creators
    }
    private func saveBlocklistToDisk() {
        try? FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(Blocklist(packages: blockedPackageIDs, creators: blockedCreators)) {
            try? writeProtected(data, to: blocklistFileURL)
        }
    }

    private func saveRegistryToDisk() {
        let fm = FileManager.default
        try? fm.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(installedGames) {
            try? writeProtected(data, to: registryFileURL)
        }
    }

    private func saveProgressToDisk(for gameID: String, progress: [String: String]) {
        let url = progressFileURL(for: gameID)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(progress) {
            try? writeProtected(data, to: url)
        }
    }
}
