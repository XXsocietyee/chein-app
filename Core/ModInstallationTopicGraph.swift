import Foundation

/// The server's native TOPIC adapter projection, not another qmod format or a graph executor.
public struct ModInstallationTopicGraph: Equatable {
    public struct Choice: Decodable, Equatable, Identifiable { public let id, label, next: String }
    public struct Node: Decodable, Equatable, Identifiable {
        public var id: String { sourceNodeId }
        public let sourceNodeId, sourceType, title, body, advancedConfigJson: String
        public let fallbackChoiceId: String?
        public let choices: [Choice]?
        public let dependency: ModCompositionDependency?
        public let artifactHash, resultContract, onRejected: String?
        public let attemptPolicy: ModCompositionAttemptPolicy?
        public let moduleCall: ModCompositionModuleGraph.Call?
        public let moduleOrigin: ModCompositionModuleGraph.Origin?
        public let venueSlotId, evidencePolicyRef: String?
    }
    public struct Trigger: Decodable, Equatable { public let type, outcomeCode: String }
    public struct Edge: Decodable, Equatable, Identifiable {
        public let id, fromNodeKey, toNodeKey: String
        public let trigger: Trigger
        public let priority, weight, maxVisits: Int
        public let once: Bool
    }
    public struct Fallback: Decodable, Equatable { public let fromNodeKey, toNodeKey: String }
    private struct Route: Decodable { let schemaVersion: Int; let startNodeKey: String; let terminalNodeKeys: [String]; let edges: [Edge]; let fallbacks: [Fallback] }
    private struct Root: Decodable { let adapter, title, description, guide: String; let locale: String?; let nodes: [Node]; let route: Route; let compositionLockHash: String?; let moduleFrames: [ModCompositionModuleGraph.Frame]?; let namespaceVersion: String? }
    public let title, description, guide, startNodeKey: String
    public let locale: String?
    public let compositionLockHash: String?
    public let moduleFrames: [ModCompositionModuleGraph.Frame]
    public let nodes: [Node]
    public let edges: [Edge]
    public let fallbacks: [Fallback]
    public init(json: String) throws {
        guard json.utf8.count <= 524288 else { throw ModInstallationIssue.malformed }
        _ = try ContentDraftJSON.parse(json)
        if let module = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any], [ModCompositionModuleGraph.adapter, ModCompositionVenueSelection.adapter].contains(module["adapter"] as? String ?? "") {
            try ModCompositionModuleGraph.validate(module)
            let decoded = try JSONDecoder().decode(Root.self, from: Data(json.utf8))
            title = decoded.title; description = decoded.description; guide = decoded.guide; startNodeKey = decoded.route.startNodeKey; locale = decoded.locale
            compositionLockHash = decoded.compositionLockHash; moduleFrames = decoded.moduleFrames ?? []; nodes = decoded.nodes; edges = decoded.route.edges; fallbacks = decoded.route.fallbacks
            return
        }
        guard let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              Set(object.keys) == (["first-party-h5-retry-topic-1","first-party-h5-policy-topic-2"].contains(object["adapter"] as? String ?? "") ? ["adapter","title","description","guide","nodes","route","compositionLockHash"] : object["adapter"] as? String == "r2-native-qa-pick-topic-1" ? ["adapter", "title", "description", "guide", "nodes", "route", "locale"] : Set(["adapter", "title", "description", "guide", "nodes", "route"]).union(object[QmodContentLocalesArtifact.field] == nil ? [] : [QmodContentLocalesArtifact.field])),
              let rawNodes = object["nodes"] as? [[String: Any]], (2...50).contains(rawNodes.count),
              let rawRoute = object["route"] as? [String: Any],
              Set(rawRoute.keys) == ["schemaVersion", "startNodeKey", "terminalNodeKeys", "variables", "edges", "fallbacks", "nodeRequirements"],
              let variables = rawRoute["variables"] as? [String: Any], variables.isEmpty,
              let requirements = rawRoute["nodeRequirements"] as? [Any], requirements.isEmpty,
              let rawEdges = rawRoute["edges"] as? [[String: Any]], let rawFallbacks = rawRoute["fallbacks"] as? [[String: Any]] else { throw ModInstallationIssue.malformed }
        if let locales = object[QmodContentLocalesArtifact.field] as? String {
            _ = try QmodContentLocalesArtifact(json: locales, expectedKind: "TOPIC", defaultPayload: object)
        } else if object[QmodContentLocalesArtifact.field] != nil { throw ModInstallationIssue.malformed }
        for node in rawNodes {
            let base: Set<String> = ["sourceNodeId", "sourceType", "title", "body", "advancedConfigJson"]
            guard Set(node.keys) == (node["sourceType"] as? String == "H5_CHALLENGE" ? base.union(["dependency","artifactHash","resultContract","onRejected"]).union(node["attemptPolicy"] == nil ? [] : ["attemptPolicy"]) : node["sourceType"] as? String == "CHOICE" ? base.union(["fallbackChoiceId", "choices"]) : base) else { throw ModInstallationIssue.malformed }
            if node.keys.contains("attemptPolicy") {
                guard let policy = node["attemptPolicy"] as? [String: Any], !policy.isEmpty, Set(policy.keys).isSubset(of: ["maxAttempts","timeoutSeconds","onRejected","onTimedOut","onAbandoned"]),
                      let bytes = try? JSONSerialization.data(withJSONObject: policy), let parsed = try? JSONDecoder().decode(ModCompositionAttemptPolicy.self, from: bytes), parsed.valid else { throw ModInstallationIssue.malformed }
            }
            if let choices = node["choices"] as? [[String: Any]] { guard choices.allSatisfy({ Set($0.keys) == ["id", "label", "next"] }) else { throw ModInstallationIssue.malformed } }
        }
        for edge in rawEdges {
            guard Set(edge.keys) == ["id", "fromNodeKey", "toNodeKey", "trigger", "conditions", "effects", "priority", "weight", "once", "maxVisits"],
                  let conditions = edge["conditions"] as? [Any], conditions.isEmpty,
                  let effects = edge["effects"] as? [Any], effects.isEmpty,
                  let trigger = edge["trigger"] as? [String: Any], Set(trigger.keys) == ["type", "outcomeCode"] else { throw ModInstallationIssue.malformed }
        }
        guard rawFallbacks.allSatisfy({ Set($0.keys) == ["fromNodeKey", "toNodeKey"] }) else { throw ModInstallationIssue.malformed }
        let decoded = try JSONDecoder().decode(Root.self, from: Data(json.utf8)), route = decoded.route
        let qaPick = decoded.adapter == "r2-native-qa-pick-topic-1"
        let composite = ["first-party-h5-retry-topic-1","first-party-h5-policy-topic-2"].contains(decoded.adapter)
        if composite { guard decoded.compositionLockHash.map(QmodSourceSubmissionWire.hashValid) == true else { throw ModInstallationIssue.malformed } }
        else { guard decoded.compositionLockHash == nil else { throw ModInstallationIssue.malformed } }
        guard composite || qaPick || decoded.adapter == "r2-native-choice-topic-1", route.schemaVersion == 1,
              qaPick ? ["en", "zh-Hans"].contains(decoded.locale ?? "") : decoded.nodes.count >= 3,
              !decoded.title.isEmpty, decoded.title.utf16.count <= 80, !decoded.description.isEmpty, decoded.description.utf16.count <= 1000 else { throw ModInstallationIssue.malformed }
        let ids = Set(decoded.nodes.map(\.id)), terminals = Set(decoded.nodes.filter { $0.sourceType == "END" }.map(\.id))
        guard ids.count == decoded.nodes.count, ids.contains(route.startNodeKey), !terminals.isEmpty,
              Set(route.terminalNodeKeys) == terminals, route.terminalNodeKeys.count == terminals.count,
              Set(route.edges.map(\.id)).count == route.edges.count else { throw ModInstallationIssue.malformed }
        var expectedEdges = Set<String>(), expectedFallbacks: [String: String] = [:]
        for node in decoded.nodes {
            try Self.identifier(node.id)
            let outgoing = route.edges.filter { $0.fromNodeKey == node.id }
            if node.sourceType == "H5_CHALLENGE" {
                guard composite, let d = node.dependency, d.valid, node.artifactHash == d.contentHash, node.resultContract == "card-order.v1", node.onRejected == "RETRY",
                      node.advancedConfigJson.utf8.count <= 65536, outgoing.count == 1 + (node.attemptPolicy?.branches.count ?? 0),
                      outgoing.contains(where: { $0.id == node.id + ".next" && $0.trigger.type == "CHOICE" && $0.trigger.outcomeCode == "COMPLETED" }) else { throw ModInstallationIssue.malformed }
                _ = try ContentDraftJSON.parse(node.advancedConfigJson)
                guard let config = try JSONSerialization.jsonObject(with: Data(node.advancedConfigJson.utf8)) as? [String: Any],
                      Set(config.keys) == ["schemaVersion","h5Challenge","sort"], let challenge = config["h5Challenge"] as? [String: Any],
                      Set(challenge.keys) == ["objectiveId","contentVersionHash","verifierVersion"], challenge["objectiveId"] as? String == d.packageId,
                      challenge["verifierVersion"] as? String == node.resultContract, let manifest = challenge["contentVersionHash"] as? String,
                      QmodSourceSubmissionWire.hashValid(manifest) else { throw ModInstallationIssue.malformed }
                if let policy = node.attemptPolicy {
                    guard decoded.adapter == "first-party-h5-policy-topic-2", policy.valid else { throw ModInstallationIssue.malformed }
                    for (code, target) in policy.branches {
                        let field = code == "H5_REJECTED" ? "onRejected" : code == "H5_TIMEOUT" ? "onTimedOut" : "onAbandoned"
                        let id = node.id + "." + field; expectedEdges.insert(id)
                        guard outgoing.contains(where: { $0.id == id && $0.toNodeKey == target && $0.trigger.type == "ADVANCED_RESULT" && $0.trigger.outcomeCode == code }) else { throw ModInstallationIssue.malformed }
                    }
                }
                expectedEdges.insert(node.id + ".next");continue
            }
            if node.sourceType == "ADVANCED_GAME" {
                guard qaPick, node.title.utf16.count <= 80 else { throw ModInstallationIssue.malformed }
                let qa = try ModInstallationQaPick(json: node.advancedConfigJson)
                let edgeID = node.id + ".next"; expectedEdges.insert(edgeID)
                guard node.body == qa.title, outgoing.count == 1, outgoing[0].id == edgeID,
                      outgoing[0].trigger.type == "CHOICE", outgoing[0].trigger.outcomeCode == "COMPLETED" else { throw ModInstallationIssue.malformed }
                continue
            }
            guard outgoing.allSatisfy({ $0.trigger.type == "ADVANCED_RESULT" }) else { throw ModInstallationIssue.malformed }
            let native = try ModInstallationNativeGraph(json: node.advancedConfigJson, allowSingleTerminal: true)
            guard native.startStepId == "__entry", node.title.utf16.count <= 80, node.body.utf16.count <= 1000,
                  let start = native.steps.first(where: { $0.id == "__entry" }), start.title == node.title, start.body == node.body else { throw ModInstallationIssue.malformed }
            switch node.sourceType {
            case "CHOICE":
                guard let choices = node.choices, (2...8).contains(choices.count), let fallback = node.fallbackChoiceId,
                      Set(choices.map(\.id)).count == choices.count, let chosen = choices.first(where: { $0.id == fallback }), outgoing.count == choices.count else { throw ModInstallationIssue.malformed }
                expectedFallbacks[node.id] = chosen.next
                guard start.options.count == choices.count else { throw ModInstallationIssue.malformed }
                for choice in choices {
                    try Self.identifier(choice.id)
                    let edgeID = node.id + "." + choice.id; expectedEdges.insert(edgeID)
                    guard ids.contains(choice.next), outgoing.contains(where: { $0.id == edgeID && $0.toNodeKey == choice.next && $0.trigger.outcomeCode == choice.id }),
                          let button = start.options.first(where: { $0.id == choice.id && $0.label == choice.label }),
                          native.steps.contains(where: { $0.id == button.nextStepId && $0.terminal && $0.outcomeCode == choice.id }) else { throw ModInstallationIssue.malformed }
                }
            case "NARRATIVE":
                let edgeID = node.id + ".next"; expectedEdges.insert(edgeID)
                guard outgoing.count == 1, outgoing[0].id == edgeID, outgoing[0].trigger.outcomeCode == "COMPLETED", start.options.count == 1 else { throw ModInstallationIssue.malformed }
            case "END": guard outgoing.isEmpty, start.terminal else { throw ModInstallationIssue.malformed }
            default: throw ModInstallationIssue.malformed
            }
        }
        guard (composite ? decoded.nodes.contains(where: { $0.sourceType == "H5_CHALLENGE" }) : qaPick ? decoded.nodes.contains(where: { $0.sourceType == "ADVANCED_GAME" }) : !expectedFallbacks.isEmpty), Set(route.edges.map(\.id)) == expectedEdges,
              route.fallbacks.count == expectedFallbacks.count,
              Set(route.fallbacks.map(\.fromNodeKey)).count == route.fallbacks.count,
              route.fallbacks.allSatisfy({ expectedFallbacks[$0.fromNodeKey] == $0.toNodeKey }),
              route.edges.allSatisfy({ ids.contains($0.fromNodeKey) && ids.contains($0.toNodeKey) && $0.id.utf8.count <= 64 && $0.priority == 0 && $0.weight == 1 && $0.once && $0.maxVisits == 1 }) else { throw ModInstallationIssue.malformed }
        var active = Set<String>(), visited = Set<String>()
        func visit(_ id: String) throws {
            guard !active.contains(id) else { throw ModInstallationIssue.malformed }
            if visited.contains(id) { return }; active.insert(id)
            for edge in route.edges where edge.fromNodeKey == id { try visit(edge.toNodeKey) }
            active.remove(id); visited.insert(id)
        }
        try visit(route.startNodeKey); guard visited == ids else { throw ModInstallationIssue.malformed }
        title = decoded.title; description = decoded.description; guide = decoded.guide; startNodeKey = route.startNodeKey
        compositionLockHash = decoded.compositionLockHash;moduleFrames = [];nodes = decoded.nodes; edges = route.edges; fallbacks = route.fallbacks; locale = decoded.locale
    }
    private static func identifier(_ value: String) throws {
        guard value.range(of: "\\A[a-z][a-z0-9_-]{0,63}\\z", options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
    }
}
