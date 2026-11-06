import Foundation

/// Validation/projection of one server-compiled standard graph; no evaluator, arbitrary node registry or runtime stack.
public enum ModCompositionModuleGraph {
    public static let adapter = "first-party-standard-call-topic-3"
    public static let namespace = "module-node-namespace-v1"
    public struct Call: Decodable, Equatable {
        public let id, type, titleKey, entryNodeId, returnNodeId: String
        public let dependency: ModCompositionDependency
        public let venueSlotMap: [String: String]
    }
    public struct Origin: Decodable, Equatable {
        public let namespaceVersion, callNodeId, packageId, packageVersion, contentHash, compilerVersion, compiledHash, sourceNodeId, invocationPath: String
        public let sourceLocale: String?
        public let sourceVenueSlotId: String?
    }
    public struct Frame: Decodable, Equatable, Identifiable {
        public var id: String { callNodeId }
        public let namespaceVersion, callNodeId, entryNodeId, compiledEntryNodeId, returnNodeId, compilerVersion, compiledHash, embeddedPlanAdapter, embeddedPlanHash: String
        public let dependency: ModCompositionDependency
        public let returnNodeKeys: [String]
        public let nodeMap, venueSlotMap: [String: String]
    }
    static func validate(_ root: [String: Any]) throws {
        func require(_ value: Bool) throws { guard value else { throw ModInstallationIssue.malformed } }
        func dictionary(_ raw: Any?) throws -> [String: Any] { guard let d = raw as? [String: Any] else { throw ModInstallationIssue.malformed }; return d }
        func keys(_ d: [String: Any], _ expected: Set<String>) throws { try require(Set(d.keys) == expected) }
        func id(_ raw: Any?) throws -> String { guard let s = raw as? String, s.range(of: #"\A[a-z][a-z0-9_-]{0,63}\z"#, options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }; return s }
        func decoded<T: Decodable>(_ type: T.Type, _ raw: Any) throws -> T { try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: raw)) }
        let venue = root["adapter"] as? String == ModCompositionVenueSelection.adapter
        var rootKeys: Set<String> = ["adapter","title","description","guide","nodes","route"]
        if venue {
            rootKeys.formUnion(["venueSlots","venueMappingVersion","venueMappingHash"])
            if root[QmodContentLocalesArtifact.field] != nil {
                guard let locales = root[QmodContentLocalesArtifact.field] as? String,
                      root["compositionLockHash"] == nil, root["namespaceVersion"] == nil, root["moduleFrames"] == nil else { throw ModInstallationIssue.malformed }
                rootKeys.insert(QmodContentLocalesArtifact.field)
                // Each immutable variant must retain the same original slot and physical binding metadata.
                _ = try QmodContentLocalesArtifact(json: locales, expectedKind: "TOPIC", defaultPayload: root)
            }
            for key in ["compositionLockHash","namespaceVersion","moduleFrames","originalVenueBindings","originalVenueNodes","originalVenueBindingsHash"] where root[key] != nil { rootKeys.insert(key) }
            try require((root["namespaceVersion"] == nil) == (root["moduleFrames"] == nil))
            try require(root["namespaceVersion"] == nil || root["namespaceVersion"] as? String == namespace)
        } else { rootKeys.formUnion(["compositionLockHash","namespaceVersion","moduleFrames"]);try require(root["adapter"] as? String == adapter && root["namespaceVersion"] as? String == namespace) }
        try keys(root, rootKeys)
        let slots: Set<String>
        if venue { slots = try validateVenue(root) } else { slots = [] }
        guard let title = root["title"] as? String, !title.isEmpty, title.utf16.count <= 80,
              let description = root["description"] as? String, !description.isEmpty, description.utf16.count <= 1000 else { throw ModInstallationIssue.malformed }
        guard let rawNodes = root["nodes"] as? [[String: Any]], (2...256).contains(rawNodes.count) else { throw ModInstallationIssue.malformed }
        let rawFrames = root["moduleFrames"] as? [[String: Any]] ?? []
        try require(rawFrames.count <= 64 && (venue || !rawFrames.isEmpty))
        if let lock = root["compositionLockHash"] as? String { try require(QmodSourceSubmissionWire.hashValid(lock)) }
        else { try require(venue && rawFrames.isEmpty && !rawNodes.contains(where: { $0["sourceType"] as? String == "H5_CHALLENGE" })) }
        let frames = try decoded([Frame].self, rawFrames)
        try require(Set(frames.map(\.id)).count == frames.count)
        for raw in rawFrames { try keys(raw, ["namespaceVersion","callNodeId","dependency","entryNodeId","compiledEntryNodeId","returnNodeId","returnNodeKeys","nodeMap","venueSlotMap","compilerVersion","compiledHash","embeddedPlanAdapter","embeddedPlanHash"]) }
        var nodes: [String: [String: Any]] = [:]
        for n in rawNodes { let key = try id(n["sourceNodeId"]); try require(nodes.updateValue(n, forKey: key) == nil) }
        let route = try dictionary(root["route"])
        try keys(route, ["schemaVersion","startNodeKey","terminalNodeKeys","variables","edges","fallbacks","nodeRequirements"])
        guard route["schemaVersion"] as? Int == 1, let start = route["startNodeKey"] as? String,
              let terminals = route["terminalNodeKeys"] as? [String], let edges = route["edges"] as? [[String: Any]],
              let fallbacks = route["fallbacks"] as? [[String: Any]], let variables = route["variables"] as? [String: Any], variables.isEmpty,
              let requirements = route["nodeRequirements"] as? [Any], requirements.isEmpty else { throw ModInstallationIssue.malformed }
        var edgeIds = Set<String>(), adjacency: [String: [String]] = [:]
        for e in edges {
            try keys(e, ["id","fromNodeKey","toNodeKey","trigger","conditions","effects","priority","weight","once","maxVisits"])
            guard let key = e["id"] as? String, key.utf8.count <= 64, edgeIds.insert(key).inserted,
                  let from = e["fromNodeKey"] as? String, nodes[from] != nil, let to = e["toNodeKey"] as? String, nodes[to] != nil,
                  let conditions = e["conditions"] as? [Any], conditions.isEmpty, let effects = e["effects"] as? [Any], effects.isEmpty,
                  e["priority"] as? Int == 0, e["weight"] as? Int == 1, e["once"] as? Bool == true, e["maxVisits"] as? Int == 1 else { throw ModInstallationIssue.malformed }
            let trigger = try dictionary(e["trigger"]);try keys(trigger, ["type","outcomeCode"])
            try require(["CHOICE","ADVANCED_RESULT"].contains(trigger["type"] as? String ?? ""));adjacency[from, default: []].append(to)
        }
        for f in frames {
            try require(f.namespaceVersion == namespace && f.dependency.valid && nodes[f.callNodeId]?["sourceType"] as? String == "MODULE_CALL"
                && !f.nodeMap.isEmpty && Set(f.nodeMap.values).count == f.nodeMap.count && f.nodeMap[f.entryNodeId] == f.compiledEntryNodeId
                && nodes[f.returnNodeId] != nil && !f.returnNodeKeys.isEmpty && Set(f.returnNodeKeys).count == f.returnNodeKeys.count && (venue ? Set(f.venueSlotMap.values).isSubset(of: slots) : f.venueSlotMap.isEmpty)
                && QmodSourceSubmissionWire.hashValid(f.compiledHash) && QmodSourceSubmissionWire.hashValid(f.embeddedPlanHash) && !f.compilerVersion.isEmpty && !f.embeddedPlanAdapter.isEmpty)
            for (source, target) in f.venueSlotMap { _ = try id(source); _ = try id(target) }
            let call = try decoded(Call.self, try dictionary(nodes[f.callNodeId]?["moduleCall"]))
            try require(call.type == "MODULE_CALL" && call.dependency == f.dependency && call.entryNodeId == f.entryNodeId && call.returnNodeId == f.returnNodeId && call.venueSlotMap == f.venueSlotMap)
            for (source, target) in f.nodeMap { _ = try id(source); _ = try id(target);try require(nodes[target] != nil && nodes[target]?["moduleOrigin"] != nil) }
            for end in f.returnNodeKeys { try require(f.nodeMap.values.contains(end) && nodes[end]?["sourceType"] as? String == "MODULE_RETURN") }
        }
        var expectedFallbacks: [String: String] = [:], actualEnds = Set<String>()
        for (key, n) in nodes {
            guard let type = n["sourceType"] as? String, let title = n["title"] as? String, title.utf16.count <= 80,
                  let body = n["body"] as? String, body.utf16.count <= 1000, let configText = n["advancedConfigJson"] as? String, configText.utf8.count <= 65536 else { throw ModInstallationIssue.malformed }
            var expected: Set<String> = ["sourceNodeId","sourceType","title","body","advancedConfigJson"]
            if n["moduleOrigin"] != nil {
                expected.insert("moduleOrigin");let raw = try dictionary(n["moduleOrigin"])
                var originKeys: Set<String> = ["namespaceVersion","callNodeId","packageId","packageVersion","contentHash","compilerVersion","compiledHash","sourceNodeId","invocationPath"]
                if raw["sourceLocale"] != nil { originKeys.insert("sourceLocale") }
                if raw["sourceVenueSlotId"] != nil { try require(venue);originKeys.insert("sourceVenueSlotId") };try keys(raw, originKeys)
                let origin = try decoded(Origin.self, raw)
                guard let f = frames.first(where: { $0.callNodeId == origin.callNodeId }) else { throw ModInstallationIssue.malformed }
                try require(origin.namespaceVersion == namespace && origin.packageId == f.dependency.packageId && origin.packageVersion == f.dependency.packageVersion && origin.contentHash == f.dependency.contentHash
                    && origin.compilerVersion == f.compilerVersion && origin.compiledHash == f.compiledHash && f.nodeMap[origin.sourceNodeId] == key && !origin.invocationPath.isEmpty)
                if let sourceSlot = origin.sourceVenueSlotId { try require(f.venueSlotMap[sourceSlot] == n["venueSlotId"] as? String) }
            }
            let outgoing = edges.filter { $0["fromNodeKey"] as? String == key }
            func has(_ code: String, _ trigger: String, _ target: String? = nil) -> Bool { outgoing.contains { e in
                guard let t = e["trigger"] as? [String:String] else { return false };return t["type"] == trigger && t["outcomeCode"] == code && (target == nil || e["toNodeKey"] as? String == target)
            } }
            if type == "H5_CHALLENGE" {
                expected.formUnion(["dependency","artifactHash","resultContract","onRejected"])
                let d = try decoded(ModCompositionDependency.self, try dictionary(n["dependency"]))
                try require(d.valid && n["artifactHash"] as? String == d.contentHash && n["resultContract"] as? String == "card-order.v1" && n["onRejected"] as? String == "RETRY")
                var branches: [String:String] = [:]
                if let raw = n["attemptPolicy"] { expected.insert("attemptPolicy");let fields = try dictionary(raw);try require(!fields.isEmpty && Set(fields.keys).isSubset(of: ["maxAttempts","timeoutSeconds","onRejected","onTimedOut","onAbandoned"]));let policy = try decoded(ModCompositionAttemptPolicy.self, raw);try require(policy.valid);branches = policy.branches }
                try require(outgoing.count == 1 + branches.count && has("COMPLETED","CHOICE"))
                for (code,target) in branches { try require(has(code,"ADVANCED_RESULT",target)) }
                let config = try dictionary(JSONSerialization.jsonObject(with: Data(configText.utf8)));try keys(config,["schemaVersion","h5Challenge","sort"])
                let h5 = try dictionary(config["h5Challenge"]);try keys(h5,["objectiveId","contentVersionHash","verifierVersion"])
                try require(h5["objectiveId"] as? String == d.packageId && h5["verifierVersion"] as? String == "card-order.v1" && QmodSourceSubmissionWire.hashValid(h5["contentVersionHash"] as? String ?? ""))
            } else if type == "ADVANCED_GAME" {
                let qa = try ModInstallationQaPick(json: configText);try require(body == qa.title && outgoing.count == 1 && has("COMPLETED","CHOICE") && n["moduleOrigin"] != nil)
            } else {
                let native = try ModInstallationNativeGraph(json: configText, allowSingleTerminal: true)
                guard native.startStepId == "__entry", let first = native.steps.first(where: { $0.id == "__entry" }), first.title == title, first.body == body else { throw ModInstallationIssue.malformed }
                switch type {
                case "MODULE_CALL":
                    expected.insert("moduleCall");let raw = try dictionary(n["moduleCall"]);try keys(raw,["id","type","titleKey","dependency","entryNodeId","returnNodeId","venueSlotMap"])
                    guard let frame = frames.first(where: { $0.callNodeId == key }) else { throw ModInstallationIssue.malformed }
                    try require(outgoing.count == 1 && has("COMPLETED","ADVANCED_RESULT",frame.compiledEntryNodeId) && first.options.count == 1)
                case "MODULE_RETURN":
                    let owners = frames.filter { $0.returnNodeKeys.contains(key) };try require(owners.count == 1 && outgoing.count == 1 && has("COMPLETED","ADVANCED_RESULT",owners[0].returnNodeId) && first.terminal)
                case "END": actualEnds.insert(key);try require(outgoing.isEmpty && first.terminal)
                case "VENUE_CHECK":
                    expected.formUnion(["venueSlotId","evidencePolicyRef"])
                    try require(venue && slots.contains(n["venueSlotId"] as? String ?? "") && n["evidencePolicyRef"] as? String == "original-live-code-venue-v1"
                        && outgoing.count == 1 && has("COMPLETED","ADVANCED_RESULT") && first.options.count == 1)
                case "NARRATIVE": try require(outgoing.count == 1 && has("COMPLETED","ADVANCED_RESULT") && first.options.count == 1)
                case "CHOICE":
                    expected.formUnion(["choices","fallbackChoiceId"])
                    let choices = try decoded([ModInstallationTopicGraph.Choice].self, n["choices"] ?? [])
                    guard (2...8).contains(choices.count), let fallback = n["fallbackChoiceId"] as? String, let fallbackChoice = choices.first(where: { $0.id == fallback }) else { throw ModInstallationIssue.malformed }
                    try require(Set(choices.map(\.id)).count == choices.count && outgoing.count == choices.count && first.options.count == choices.count);expectedFallbacks[key] = fallbackChoice.next
                    for choice in choices {
                        guard let button = first.options.first(where: { $0.id == choice.id && $0.label == choice.label }) else { throw ModInstallationIssue.malformed }
                        try require(has(choice.id,"ADVANCED_RESULT",choice.next) && native.steps.contains(where: { $0.id == button.nextStepId && $0.terminal && $0.outcomeCode == choice.id }))
                    }
                default: throw ModInstallationIssue.malformed
                }
            }
            try keys(n, expected)
        }
        try require(!actualEnds.isEmpty && actualEnds == Set(terminals) && terminals.count == actualEnds.count && fallbacks.count == expectedFallbacks.count)
        var fallbackKeys = Set<String>()
        for raw in fallbacks { try keys(raw,["fromNodeKey","toNodeKey"]);guard let from = raw["fromNodeKey"] as? String, fallbackKeys.insert(from).inserted else { throw ModInstallationIssue.malformed };try require(expectedFallbacks[from] == raw["toNodeKey"] as? String) }
        var active = Set<String>(), seen = Set<String>()
        func visit(_ node: String) throws { try require(nodes[node] != nil && !active.contains(node));if seen.contains(node) { return };seen.insert(node);active.insert(node);for next in adjacency[node] ?? [] { try visit(next) };active.remove(node) }
        try visit(start);try require(seen == Set(nodes.keys))
    }
    private static func validateVenue(_ root: [String: Any]) throws -> Set<String> {
        func require(_ ok: Bool) throws { if !ok { throw ModInstallationIssue.malformed } }
        guard let declarations = root["venueSlots"] as? [[String: String]], (1...32).contains(declarations.count),
              root["venueMappingVersion"] as? String == "original-poi-slot-map-v1", QmodSourceSubmissionWire.hashValid(root["venueMappingHash"] as? String ?? ""),
              let nodes = root["nodes"] as? [[String: Any]] else { throw ModInstallationIssue.malformed }
        var slots = Set<String>()
        for d in declarations { guard Set(d.keys) == ["id"], let id = d["id"], id.range(of: #"\A[a-z][a-z0-9_-]{0,47}\z"#, options: .regularExpression) != nil, slots.insert(id).inserted else { throw ModInstallationIssue.malformed } }
        var consumed = Set(nodes.compactMap { $0["venueSlotId"] as? String })
        for f in root["moduleFrames"] as? [[String: Any]] ?? [] {
            guard let map = f["venueSlotMap"] as? [String: String] else { throw ModInstallationIssue.malformed }; consumed.formUnion(map.values)
        }
        try require(consumed == slots)
        let physicalFields = ["originalVenueBindings","originalVenueNodes","originalVenueBindingsHash"]
        if physicalFields.contains(where: { root[$0] != nil }) {
            guard let bindings = root["originalVenueBindings"] as? [[String: Any]], bindings.count == slots.count,
                  let bound = root["originalVenueNodes"] as? [[String: Any]], QmodSourceSubmissionWire.hashValid(root["originalVenueBindingsHash"] as? String ?? "") else { throw ModInstallationIssue.malformed }
            var map: [String: (Int64, String)] = [:]
            for b in bindings {
                guard Set(b.keys) == ["slotId","poiId","fingerprint"], let slot = b["slotId"] as? String, slots.contains(slot), let poi = b["poiId"] as? Int64, poi > 0,
                      let hash = b["fingerprint"] as? String, QmodSourceSubmissionWire.hashValid(hash), map[slot] == nil else { throw ModInstallationIssue.malformed }; map[slot] = (poi,hash)
            }
            let venueNodes = nodes.filter { $0["sourceType"] as? String == "VENUE_CHECK" };try require(venueNodes.count == bound.count)
            var seen = Set<String>()
            for b in bound {
                guard Set(b.keys) == ["planNode","slotId","poiId","fingerprint"], let key = b["planNode"] as? String, seen.insert(key).inserted,
                      let source = venueNodes.first(where: { $0["sourceNodeId"] as? String == key }), let slot = b["slotId"] as? String, source["venueSlotId"] as? String == slot,
                      let actual = map[slot], b["poiId"] as? Int64 == actual.0, b["fingerprint"] as? String == actual.1 else { throw ModInstallationIssue.malformed }
            }
        }
        return slots
    }

}
