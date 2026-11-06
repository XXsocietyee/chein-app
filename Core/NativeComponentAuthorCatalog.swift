import Foundation

/// Exact scene declaration proof, never GLOBAL_ROUTE, a runtime value, or a write capability.
public struct NativeComponentAuthorBinding: Equatable {
    public let sceneID: String
    public let nodeID: Int
    public let definitionVersion: String
    public let counters: [String]
    public let tags: [String]
    public let dynamicCounters: [String]
    public let skills: [String: String]
    public let checkEnabled: Bool
    public let whiteRed: Bool
}

public struct NativeComponentAuthorCatalog {
    public struct Scene {
        public let id: String
        public let label: String
        public let components: Set<Int>
        public var originalNodeIDs: Set<Int> { Set(value.nodes.compactMap { Int($0.id) }) }
        private let value: NativeConditionAuthorCatalog
        private let references: [NativeConditionAuthorAttributeReference]
        private let counters: [String], tags: [String], dynamicCounters: [String]
        private let skills: [String: String]
        private let enabled: Bool, whiteRed: Bool
        private let version: String
        private let rpg: [String: [NativeConditionAuthorOption]]
        fileprivate init(id: String, label: String, components: Set<Int>, value: NativeConditionAuthorCatalog,
                         references: [NativeConditionAuthorAttributeReference], counters: [String], tags: [String], dynamicCounters: [String],
                         skills: [String: String], enabled: Bool, whiteRed: Bool, version: String,
                         rpg: [String: [NativeConditionAuthorOption]]) {
            self.id = id; self.label = label; self.components = components; self.value = value; self.references = references
            self.counters = counters; self.tags = tags; self.dynamicCounters = dynamicCounters; self.skills = skills; self.enabled = enabled; self.whiteRed = whiteRed
            self.version = version; self.rpg = rpg
        }
        public func catalog(scope: NativeConditionAuthorScope, nodeID: Int) throws -> NativeConditionAuthorCatalog {
            guard components.contains(nodeID) else { throw NativeConditionAuthorError.staleEditor }
            var result = value
            result.rpg = .init(scope: scope, definitionVersion: version, supportedOperations: Set((rpg["operations"] ?? []).map(\.id)),
                checks: rpg["checks"] ?? [], checkResults: rpg["results"] ?? [], conditions: rpg["conditions"] ?? [], equipment: rpg["equipment"] ?? [])
            result.component = .init(sceneID: id, nodeID: nodeID, definitionVersion: version, counters: counters, tags: tags, dynamicCounters: dynamicCounters,
                skills: skills, checkEnabled: enabled, whiteRed: whiteRed)
            return result
        }
        public func attributes(scope: NativeConditionAuthorScope) -> NativeConditionAuthorAttributeProjection {
            .init(scope: scope, definitionVersion: version, origin: .currentDefinition, references: references)
        }
    }
    public let scenes: [Scene]
    public init(raw: Data, topicID: Int, configVersion: Int) throws {
        let decoded = try NativeAttributeAuthorWire.decode(raw)
        let tokens = try NativeAttributeAuthorWire.numberSpellings(raw, beneath: [])
        let prefix = ["data", "componentAuthorCatalog"]
        guard decoded.object?["code"]?.integer == 200, let body = decoded.object?["data"]?.object,
              body["topic"]?.object?["id"]?.integer == topicID,
              body["topic"]?.object?["configVersion"]?.integer == configVersion,
              let root = body["componentAuthorCatalog"]?.object, root["schemaVersion"]?.integer == 1,
              root["surface"] == .string("COMPONENT"), root["available"] == .bool(true),
              root["topicId"]?.integer == topicID, root["configVersion"]?.integer == configVersion,
              let rows = root["scenes"]?.array, rows.count <= 50, topicID > 0, configVersion >= 0,
              try NativeAttributeAuthorWire.encode(.object(root)).count <= 512 * 1024 else { throw NativeConditionAuthorError.invalidJSON }
        for (path, value) in [(["data", "topic", "id"], topicID), (["data", "topic", "configVersion"], configVersion),
                              (prefix + ["schemaVersion"], 1), (prefix + ["topicId"], topicID), (prefix + ["configVersion"], configVersion)] {
            guard tokens[path] == String(value) else { throw NativeConditionAuthorError.invalidJSON }
        }
        func text(_ value: ProjectEditJSON?) throws -> String {
            guard let text = value?.text, !text.isEmpty, text.utf16.count <= 128 else { throw NativeConditionAuthorError.invalidJSON }; return text
        }
        func array(_ value: ProjectEditJSON?) throws -> [ProjectEditJSON] {
            guard let rows = value?.array, rows.count <= 4096 else { throw NativeConditionAuthorError.invalidJSON }; return rows
        }
        func options(_ raw: ProjectEditJSON?) throws -> [NativeConditionAuthorOption] {
            var seen = Set<Data>()
            return try array(raw).map { row in
                let key = try text(row); guard seen.insert(Data(key.utf8)).inserted else { throw NativeConditionAuthorError.invalidJSON }
                return .init(id: key, label: key)
            }
        }
        var result: [Scene] = [], sceneIDs = Set<String>()
        for (i, rawScene) in rows.enumerated() {
            guard let row = rawScene.object else { throw NativeConditionAuthorError.invalidJSON }
            let id = try text(row["id"])
            guard id.range(of: #"^[a-z][a-z0-9_]{0,31}$"#, options: .regularExpression) != nil,
                  sceneIDs.insert(id).inserted, let label = row["label"]?.text else { throw NativeConditionAuthorError.invalidJSON }
            let path = prefix + ["scenes", String(i)]
            var nodes: [NativeConditionAuthorOption] = [], nodeIDs = Set<Int>()
            for (n, rawNode) in try array(row["nodes"]).enumerated() {
                guard let node = rawNode.object, let nodeID = node["id"]?.integer, nodeID > 0,
                      tokens[path + ["nodes", String(n), "id"]] == String(nodeID), nodeIDs.insert(nodeID).inserted,
                      let name = node["label"]?.text else { throw NativeConditionAuthorError.invalidJSON }
                nodes.append(.init(id: String(nodeID), label: name))
            }
            var components = Set<Int>()
            for (n, value) in try array(row["components"]).enumerated() {
                guard let nodeID = value.integer, nodeIDs.contains(nodeID), components.insert(nodeID).inserted,
                      tokens[path + ["components", String(n)]] == String(nodeID) else { throw NativeConditionAuthorError.invalidJSON }
            }
            var items: [NativeConditionAuthorOption] = [], medals: [NativeConditionAuthorOption] = [], itemIDs = Set<Data>()
            for rawItem in try array(row["items"]) {
                guard let item = rawItem.object else { throw NativeConditionAuthorError.invalidJSON }
                let key = try text(item["id"])
                guard itemIDs.insert(Data(key.utf8)).inserted else { throw NativeConditionAuthorError.invalidJSON }
                switch item["kind"]?.text {
                case "ITEM": items.append(.init(id: key, label: key))
                case "MEDAL": medals.append(.init(id: key, label: key))
                default: throw NativeConditionAuthorError.invalidJSON
                }
            }
            var refs: [NativeConditionAuthorAttributeReference] = [], keys = Set<Data>()
            for rawType in try array(row["types"]) {
                guard let type = rawType.object else { throw NativeConditionAuthorError.invalidJSON }
                let key = try text(type["key"])
                guard keys.insert(Data(key.utf8)).inserted else { throw NativeConditionAuthorError.invalidJSON }
                let scalar: NativeConditionAuthorAttributeReference.ValueType
                switch type["type"]?.text { case "NUMBER": scalar = .number; case "STRING": scalar = .string; default: throw NativeConditionAuthorError.invalidJSON }
                refs.append(.init(key: key, label: key, type: scalar,
                    writable: !key.hasPrefix("sys.passed.") && !key.hasPrefix("sys.quest.") && !OriginalRpgGrowthFacts.reserved(key)
                    && !NativeRpgEnvironmentTemplateDraft.conditionKeys.contains(key) && !OriginalRpgProgressConditions.reserved(key)))
            }
            let counters = try options(row["counters"]).map(\.id), tags = try options(row["tags"]).map(\.id), dynamicCounters = try options(row["dynamicCounters"]).map(\.id)
            guard Set(dynamicCounters).isSubset(of: Set(counters)), counters.allSatisfy({ key in key.hasPrefix("counter.") && refs.contains(where: { $0.key == key && $0.type == .number }) }),
                  let check = row["check"]?.object, case .bool(let enabled)? = check["enabled"], case .bool(let whiteRed)? = check["whiteRed"],
                  let rpgSource = row["rpg"]?.object else { throw NativeConditionAuthorError.invalidJSON }
            var skills: [String: String] = [:]
            for rawSkill in try array(check["skills"]) {
                let key = try text(rawSkill.object?["key"]), category = try text(rawSkill.object?["category"])
                guard skills[key] == nil, ["PHY", "OBS", "SOC", "WIL"].contains(category) else { throw NativeConditionAuthorError.invalidJSON }
                skills[key] = category
            }
            var rpg: [String: [NativeConditionAuthorOption]] = [:]
            for name in ["checks", "results", "conditions", "equipment", "operations"] { rpg[name] = try options(rpgSource[name]) }
            guard Set((rpg["operations"] ?? []).map(\.id)).isSubset(of: ["CHECK_RESULT", "HAS_CONDITION", "ITEM_EQUIPPED"]) else { throw NativeConditionAuthorError.invalidJSON }
            let value = NativeConditionAuthorCatalog(nodes: nodes, items: items, medals: medals, triggers: [], outcomes: [], edges: try options(row["edges"]))
            result.append(.init(id: id, label: label, components: components, value: value, references: refs, counters: counters, tags: tags, dynamicCounters: dynamicCounters,
                skills: skills, enabled: enabled, whiteRed: whiteRed, version: String(configVersion), rpg: rpg))
        }
        scenes = result
    }
}
