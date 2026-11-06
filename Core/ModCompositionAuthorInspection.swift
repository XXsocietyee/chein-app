import Foundation

public struct ModCompositionDependency: Codable, Equatable, Hashable {
    public let packageId, packageVersion, contentHash: String
    var valid: Bool {
        packageId.range(of: #"\A[a-z][a-z0-9._-]{0,63}\z"#, options: .regularExpression) != nil &&
            packageVersion.range(of: #"\A(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\z"#, options: .regularExpression) != nil && QmodSourceSubmissionWire.hashValid(contentHash)
    }
    static func source(_ source: QmodSourceSubmissionSource) throws -> [Self] {
        let entries = try source.exactBytes()
        guard let bytes = entries["manifest.json"] else { throw QmodSourceSubmissionIssue.invalidPackage }
        let m = try QmodSourceSubmissionWire.object(bytes)
        guard let values = m["dependencies"] as? [[String: Any]], values.count <= 32 else { throw QmodSourceSubmissionIssue.invalidPackage }
        let root = m["packageId"] as? String
        var seen = Set<String>()
        return try values.map { value in
            try QmodSourceSubmissionWire.keys(value, ["packageId", "packageVersion", "contentHash"])
            let d = try JSONDecoder().decode(Self.self, from: JSONSerialization.data(withJSONObject: value))
            guard d.valid, d.packageId != root, seen.insert(d.packageId).inserted else { throw QmodSourceSubmissionIssue.invalidPackage }; return d
        }.sorted { $0.packageId < $1.packageId }
    }
}
/// A read from the original author's real licenses and reviewed source. It is explicitly not a durable release lock.
public struct ModCompositionAuthorInspection: Decodable, Equatable {
    public struct Node: Decodable, Equatable, Identifiable {
        public var id: String { packageId }
        public let packageId, packageVersion, releaseId, contentHash, sourceManifestHash, compilerVersion, compiledHash, termsHash, grantHash: String
        public let dependencies: [ModCompositionDependency]
    }
    public let schema, lockHash, rootPackageId, rootPackageVersion, rootSourceHash, rootManifestHash: String
    public let roots: [ModCompositionDependency]
    public let nodes: [Node]
    public let moduleFramesJson, moduleFramesHash: String?
    public var moduleFrames: [ModCompositionModuleGraph.Frame] {
        guard let json = moduleFramesJson, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ModCompositionModuleGraph.Frame].self, from: data)) ?? []
    }
    public let durable: Bool
    public let scope: String
    public func validate(source: QmodSourceSubmissionSource) throws {
        let entries = try source.exactBytes()
        guard let manifest = entries["manifest.json"] else { throw QmodSourceSubmissionIssue.malformed }
        let m = try QmodSourceSubmissionWire.object(manifest)
        guard schema == "mod-composition-author-inspection-v1", !durable, scope == "ORIGINAL_AUTHOR_RIGHTS_INSPECTION_ONLY",
              rootPackageId == m["packageId"] as? String, rootPackageVersion == m["packageVersion"] as? String,
              rootSourceHash == (try source.sourceHash), rootManifestHash == QmodSourceSubmissionWire.hash(manifest),
              QmodSourceSubmissionWire.hashValid(lockHash), roots == (try ModCompositionDependency.source(source)),
              !roots.isEmpty, !nodes.isEmpty, nodes.count <= 64, Set(nodes.map(\.id)).count == nodes.count else { throw QmodSourceSubmissionIssue.malformed }
        let indexed = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        for node in nodes {
            let identity = ModCompositionDependency(packageId: node.packageId, packageVersion: node.packageVersion, contentHash: node.contentHash)
            guard identity.valid, ModReleaseApplicationWire.key(node.releaseId), !node.compilerVersion.isEmpty, node.compilerVersion.utf8.count <= 128,
                  [node.sourceManifestHash, node.compiledHash, node.termsHash, node.grantHash].allSatisfy(QmodSourceSubmissionWire.hashValid),
                  node.dependencies.count <= 32, Set(node.dependencies.map(\.packageId)).count == node.dependencies.count else { throw QmodSourceSubmissionIssue.malformed }
        }
        var active: Set<String> = [rootPackageId], visited = Set<String>()
        func visit(_ dependency: ModCompositionDependency) throws {
            guard dependency.valid, !active.contains(dependency.packageId), let node = indexed[dependency.packageId], node.packageVersion == dependency.packageVersion,
                  node.contentHash == dependency.contentHash else { throw QmodSourceSubmissionIssue.malformed }
            if visited.contains(dependency.packageId) { return }
            active.insert(dependency.packageId)
            for child in node.dependencies { try visit(child) }
            active.remove(dependency.packageId); visited.insert(dependency.packageId)
        }
        for dependency in roots { try visit(dependency) }
        guard visited == Set(indexed.keys) else { throw QmodSourceSubmissionIssue.malformed }
        let runtime = m["runtime"] as? [String: Any], capabilities = runtime?["requiredCapabilities"] as? [String] ?? []
        if capabilities.contains("mod.module-call.v1") {
            guard let json = moduleFramesJson, json.utf8.count <= 524288, let digest = moduleFramesHash, QmodSourceSubmissionWire.hash(Data(json.utf8)) == digest else { throw QmodSourceSubmissionIssue.malformed }
            _ = try ContentDraftJSON.parse(json)
            let frames = try JSONDecoder().decode([ModCompositionModuleGraph.Frame].self, from: Data(json.utf8))
            guard !frames.isEmpty, frames.count <= 64, Set(frames.map(\.id)).count == frames.count, let content = entries["content.json"] else { throw QmodSourceSubmissionIssue.malformed }
            let body = try QmodSourceSubmissionWire.object(content), rawNodes = body["nodes"] as? [[String: Any]] ?? []
            let calls = rawNodes.filter { $0["type"] as? String == "MODULE_CALL" }
            guard !calls.isEmpty else { throw QmodSourceSubmissionIssue.malformed }
            for frame in frames {
                guard frame.namespaceVersion == ModCompositionModuleGraph.namespace, frame.dependency.valid,
                      let dependency = indexed[frame.dependency.packageId], dependency.packageVersion == frame.dependency.packageVersion, dependency.contentHash == frame.dependency.contentHash,
                      dependency.compilerVersion == frame.compilerVersion, dependency.compiledHash == frame.compiledHash, !frame.nodeMap.isEmpty, frame.nodeMap[frame.entryNodeId] == frame.compiledEntryNodeId,
                      frame.venueSlotMap.isEmpty, !frame.returnNodeKeys.isEmpty, QmodSourceSubmissionWire.hashValid(frame.embeddedPlanHash) else { throw QmodSourceSubmissionIssue.malformed }
            }
            for raw in calls {
                let call = try JSONDecoder().decode(ModCompositionModuleGraph.Call.self, from: JSONSerialization.data(withJSONObject: raw))
                guard let frame = frames.first(where: { $0.callNodeId == call.id }), frame.dependency == call.dependency, frame.entryNodeId == call.entryNodeId,
                      frame.returnNodeId == call.returnNodeId, frame.venueSlotMap == call.venueSlotMap else { throw QmodSourceSubmissionIssue.malformed }
            }
        } else { guard moduleFramesJson == nil && moduleFramesHash == nil else { throw QmodSourceSubmissionIssue.malformed } }
    }
}
