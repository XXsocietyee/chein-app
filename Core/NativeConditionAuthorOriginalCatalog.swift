import Foundation

/// Ephemeral projection of the original owner-private GLOBAL_ROUTE binding. This is not
/// an attribute registry, runtime snapshot, evaluator, write grant, or submission receipt.
public struct NativeConditionAuthorOriginalCatalog {
    private let value: NativeConditionAuthorCatalog
    private let references: [NativeConditionAuthorAttributeReference]
    private let version: String
    private struct RPGDeclarations {
        let operations: Set<String>
        let checks, results, conditions, equipment: [NativeConditionAuthorOption]
    }
    private let rpg: RPGDeclarations?

    public init(raw: Data, topicID: Int, configVersion: Int) throws {
        let decoded = try NativeAttributeAuthorWire.decode(raw)
        let tokens = try NativeAttributeAuthorWire.numberSpellings(raw, beneath: [])
        guard decoded.object?["code"]?.integer == 200,
              let body = decoded.object?["data"]?.object,
              let topic = body["topic"]?.object,
              topic["id"]?.integer == topicID, topic["configVersion"]?.integer == configVersion,
              let catalog = body["routeConditionAuthorCatalog"]?.object,
              catalog["schemaVersion"]?.integer == 1, catalog["surface"]?.text == "GLOBAL_ROUTE",
              catalog["available"] == .bool(true), catalog["topicId"]?.integer == topicID,
              catalog["configVersion"]?.integer == configVersion, topicID > 0, configVersion >= 0 else {
            throw NativeConditionAuthorError.invalidJSON
        }
        let prefix = ["data", "routeConditionAuthorCatalog"]
        for (path, expected) in [(["data", "topic", "id"], topicID),
                                 (["data", "topic", "configVersion"], configVersion),
                                 (prefix + ["schemaVersion"], 1), (prefix + ["topicId"], topicID),
                                 (prefix + ["configVersion"], configVersion)] {
            guard tokens[path] == String(expected) else { throw NativeConditionAuthorError.invalidJSON }
        }
        func rows(_ key: String) throws -> [ProjectEditJSON] {
            guard let result = catalog[key]?.array, result.count <= 4096 else { throw NativeConditionAuthorError.invalidJSON }
            return result
        }
        func nonempty(_ value: ProjectEditJSON?) throws -> String {
            guard let text = value?.text, !text.isEmpty, text.utf16.count <= 4096 else { throw NativeConditionAuthorError.invalidJSON }
            return text
        }
        var nodes: [NativeConditionAuthorOption] = [], nodeIDs = Set<Int>()
        for (i, row) in try rows("nodes").enumerated() {
            guard let fields = row.object, let id = fields["id"]?.integer, id > 0,
                  tokens[prefix + ["nodes", String(i), "id"]] == String(id), nodeIDs.insert(id).inserted,
                  let label = fields["label"]?.text else { throw NativeConditionAuthorError.invalidJSON }
            nodes.append(.init(id: String(id), label: label.isEmpty ? String(id) : label))
        }
        var outcomes: [String: [NativeConditionAuthorDeclaredOutcome]] = [:]
        var uniqueOutcomes = Set<Data>(), triggers = Set<String>(), codes = Set<String>()
        for (i, row) in try rows("outcomes").enumerated() {
            guard let fields = row.object, let id = fields["nodeId"]?.integer, nodeIDs.contains(id),
                  tokens[prefix + ["outcomes", String(i), "nodeId"]] == String(id) else { throw NativeConditionAuthorError.invalidJSON }
            let trigger = try nonempty(fields["trigger"]), code = try nonempty(fields["code"])
            let key = try NativeAttributeAuthorWire.encode(.array([.number(Decimal(id)), .string(trigger), .string(code)]))
            guard uniqueOutcomes.insert(key).inserted else { throw NativeConditionAuthorError.invalidJSON }
            outcomes[String(id), default: []].append(.init(triggerType: trigger, code: code, label: code))
            triggers.insert(trigger); codes.insert(code)
        }
        // Empty outcomes for a saved terminal node are legal; a missing node row is not.
        var items: [NativeConditionAuthorOption] = [], medals: [NativeConditionAuthorOption] = [], itemIDs = Set<Data>()
        for row in try rows("items") {
            guard let fields = row.object else { throw NativeConditionAuthorError.invalidJSON }
            let id = try nonempty(fields["id"])
            guard itemIDs.insert(Data(id.utf8)).inserted else { throw NativeConditionAuthorError.invalidJSON }
            let option = NativeConditionAuthorOption(id: id, label: id)
            switch fields["kind"]?.text {
            case "ITEM": items.append(option)
            case "MEDAL": medals.append(option)
            default: throw NativeConditionAuthorError.invalidJSON
            }
        }
        var references: [NativeConditionAuthorAttributeReference] = [], keys = Set<Data>()
        for row in try rows("types") {
            guard let fields = row.object else { throw NativeConditionAuthorError.invalidJSON }
            let key = try nonempty(fields["key"])
            guard keys.insert(Data(key.utf8)).inserted else { throw NativeConditionAuthorError.invalidJSON }
            let type: NativeConditionAuthorAttributeReference.ValueType
            switch fields["type"]?.text {
            case "NUMBER": type = .number
            case "STRING": type = .string
            default: throw NativeConditionAuthorError.invalidJSON
            }
            // Exact original RouteEffects v2 write restriction, not a client capability guess.
            references.append(.init(key: key, label: key, type: type, writable: !key.hasPrefix("sys.passed.") && !key.hasPrefix("sys.quest.") && !OriginalRpgGrowthFacts.reserved(key) && !NativeRpgEnvironmentTemplateDraft.conditionKeys.contains(key) && !OriginalRpgProgressConditions.reserved(key)))
        }
        func options(_ value: ProjectEditJSON?) throws -> [NativeConditionAuthorOption] {
            guard let rows = value?.array, rows.count <= 4096 else { throw NativeConditionAuthorError.invalidJSON }
            var seen = Set<Data>()
            return try rows.map { row in
                let id = try nonempty(row)
                guard seen.insert(Data(id.utf8)).inserted else { throw NativeConditionAuthorError.invalidJSON }
                return .init(id: id, label: id)
            }
        }
        let edges = try options(catalog["edges"])
        // Store neutral declarations only; projection(for:) binds the actual current editor scope.
        var rpg: RPGDeclarations?
        guard let rawRPG = catalog["rpg"] else { throw NativeConditionAuthorError.invalidJSON }
        if rawRPG != .null {
            guard let fields = rawRPG.object else { throw NativeConditionAuthorError.invalidJSON }
            let operations = Set(try options(fields["operations"]).map(\.id))
            guard operations.isSubset(of: ["CHECK_RESULT", "HAS_CONDITION", "ITEM_EQUIPPED"]) else {
                throw NativeConditionAuthorError.invalidJSON
            }
            rpg = .init(operations: operations,
                checks: try options(fields["checks"]), results: try options(fields["results"]),
                conditions: try options(fields["conditions"]), equipment: try options(fields["equipment"]))
        }
        self.references = references; self.rpg = rpg; version = String(configVersion)
        value = .init(nodes: nodes, items: items, medals: medals,
            triggers: triggers.sorted().map { .init(id: $0, label: $0) },
            outcomes: codes.sorted().map { .init(id: $0, label: $0) },
            sourceOutcomes: outcomes, edges: edges)
    }
    public func catalog(for scope: NativeConditionAuthorScope) -> NativeConditionAuthorCatalog {
        var result = value
        if let source = rpg {
            result.rpg = .init(scope: scope, definitionVersion: version, supportedOperations: source.operations,
                checks: source.checks, checkResults: source.results, conditions: source.conditions, equipment: source.equipment)
        }
        return result
    }
    public func attributes(for scope: NativeConditionAuthorScope) -> NativeConditionAuthorAttributeProjection {
        .init(scope: scope, definitionVersion: version, origin: .currentDefinition, references: references)
    }

    /// The original author producer depends on saved nodes/templates, theme, rules and
    /// route declarations. Pure text/price/story presentation edits do not replace them.
    /// Edges/conditions are intentionally excluded:41 edits those through the original saver.
    public static func sourceMaterials(_ draft: ProjectEditDraft) throws -> Data {
        guard let raw = draft.preserved["routeGraphJson"]?.text,
              NativeConditionAuthorVersion.hasExplicitV2(raw),
              let graph = try NativeAttributeAuthorWire.decode(Data(raw.utf8)).object else {
            throw NativeConditionAuthorError.incompatibleVersion
        }
        var topic: [String: ProjectEditJSON] = [:]
        for key in ["routeMode", "configVersion", "themeRuntimeConfig", "journeyRules", "journeyStory"] {
            if let value = draft.preserved[key] { topic[key] = value }
        }
        var declarations: [String: ProjectEditJSON] = [:]
        for key in ["variables", "stringVariables"] { if let value = graph[key] { declarations[key] = value } }
        var ids = Set<Int>(), nodes: [(Int, ProjectEditJSON)] = []
        for node in draft.chapters.flatMap(\.nodes) {
            guard let id = node.localMetadata["id"]?.integer, id > 0, ids.insert(id).inserted else {
                throw NativeConditionAuthorError.staleEditor
            }
            nodes.append((id, .object(["id": .number(Decimal(id)),
                "templateId": node.templateID.map { .number(Decimal($0)) } ?? .null])))
        }
        return try NativeAttributeAuthorWire.encode(.object(["topic": .object(topic),
            "declarations": .object(declarations), "nodes": .array(nodes.sorted { $0.0 < $1.0 }.map(\.1))]))
    }
}
