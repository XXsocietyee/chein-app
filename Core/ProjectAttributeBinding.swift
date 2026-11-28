import Foundation

/// MP `pages/publish/utils/publish/attribute-binding.js`: the 初始状态 sheet's 启用的注册属性 card.
/// The author ticks registry keys, accepts each 定义差异 against the old `journeyRules.attributes` copy,
/// and 确认启用 rewrites `attributes` as the registry projection plus `attributeBinding`.
public enum ProjectAttributeBinding {
    /// MP `KEY`.
    static let keyPattern = "^(clue|relation|tag|counter)\\.[a-z][a-z0-9_]{0,47}$"
    public static let maxKeys = 32

    /// MP `fields`: registry field → old-config field. The label key is `projectInitialState.binding.field.<registry>`.
    public static let fields: [(registry: String, legacy: String)] = [
        ("label", "label"), ("initialValue", "initial"), ("minValue", "min"), ("maxValue", "max"), ("visible", "visible"),
        ("persistScope", "persistScope"), ("displayType", "displayType"), ("color", "color"), ("icon", "icon"),
        ("sortOrder", "sortOrder"), ("rulesJson", "rulesJson")
    ]

    public struct Difference: Equatable, Identifiable {
        public let field: String
        /// nil = 旧配置未记录.
        public let previous: String?
        /// nil = 未设置.
        public let registered: String?
        public var id: String { field }
    }

    public struct Conflict: Equatable, Identifiable {
        public let key: String
        public let label: String
        public let differences: [Difference]
        public var id: String { key }
    }

    /// MP error copy, as localization keys in table `ProjectInitialState`.
    public enum Issue: Error, Equatable {
        /// 属性规则格式不正确 / 属性引用格式不正确.
        case malformed
        /// 启用属性须为不重复的已注册键，最多32项.
        case tooMany
        /// 请逐项确认差异，或先调整注册定义.
        case unaccepted
        /// 仍有数值联动引用未启用属性：key.
        case statLink(String)
        /// 原键类型不能改变：key.
        case keyType(String)
        /// 属性未注册：key.
        case unregistered(String)
    }

    /// MP `parse`: the rules object, `{}` for an empty string.
    public static func rules(_ raw: ProjectEditJSON?) throws -> [String: ProjectEditJSON] {
        guard let raw, raw != .null else { return [:] }
        if let object = raw.object { return object }
        guard let text = raw.text else { throw Issue.malformed }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [:] }
        guard let value = try? JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8)), let object = value.object else {
            throw Issue.malformed
        }
        return object
    }

    /// MP `session().enabledKeys`: the keys the stored `attributeBinding` enables, else none.
    public static func enabledKeys(_ rules: [String: ProjectEditJSON]) -> [String] {
        guard let binding = rules["attributeBinding"]?.object, let keys = binding["enabledKeys"]?.array else { return [] }
        return keys.compactMap(\.text)
    }

    public static func isBound(_ rules: [String: ProjectEditJSON]) -> Bool {
        if let binding = rules["attributeBinding"], binding != .null { return true }
        return false
    }

    /// MP `conflicts`: per enabled key, the fields where the old copy (or the frozen cloud definition)
    /// differs from the registry. Keys without an old row have nothing to accept.
    public static func conflicts(rules: [String: ProjectEditJSON], registry: TopicAttributeRegistry,
                                 enabledKeys: [String]) throws -> [Conflict] {
        let frozen = frozenRows(rules, registry: registry)
        return try enabledKeys.compactMap { key -> Conflict? in
            guard let registered = registry.definitions.first(where: { $0.stateKey == key }) else { throw Issue.unregistered(key) }
            var legacy = (rules["attributes"]?.array ?? []).compactMap(\.object).first { $0["key"]?.text == key }
            if let row = frozen[key] { legacy = row }
            guard let legacy else { return nil }
            if let type = legacy["keyType"]?.text, type != registered.keyType { throw Issue.keyType(key) }
            let differences = fields.compactMap { field -> Difference? in
                let current = registered.fields[field.registry] ?? TopicAttributeFieldValue(canonical: "null", display: nil)
                guard let old = legacy[field.legacy] else {
                    return .init(field: field.registry, previous: nil, registered: current.display)
                }
                guard canonical(old) != current.canonical else { return nil }
                return .init(field: field.registry, previous: display(old), registered: current.display)
            }
            return differences.isEmpty ? nil : .init(key: key, label: registered.label, differences: differences)
        }
    }

    /// MP `confirm`: checks, then the new rules object with `attributes` = registry projection, the binding,
    /// `stateEnabled` on when any key is enabled, and the frozen `attributeDefinition` / `attributeSnapshot` dropped.
    public static func confirm(rules: [String: ProjectEditJSON], registry: TopicAttributeRegistry,
                               enabledKeys: [String], acceptedKeys: Set<String>) throws -> [String: ProjectEditJSON] {
        guard enabledKeys.count <= maxKeys, Set(enabledKeys).count == enabledKeys.count,
              enabledKeys.allSatisfy({ $0.range(of: keyPattern, options: .regularExpression) != nil }) else { throw Issue.tooMany }
        let differences = try conflicts(rules: rules, registry: registry, enabledKeys: enabledKeys)
        if differences.contains(where: { !acceptedKeys.contains($0.key) }) { throw Issue.unaccepted }
        for link in rules["statLinks"]?.array ?? [] {
            if let source = link.object?["sourceKey"]?.text, !enabledKeys.contains(source) { throw Issue.statLink(source) }
        }
        var next = rules
        next["attributeSnapshot"] = nil; next["attributeDefinition"] = nil
        next["attributes"] = .array(try projection(registry, enabledKeys: enabledKeys))
        next["attributeBinding"] = .object(["schemaVersion": .number(1), "registryVersion": .string(registry.registryVersion),
                                            "enabledKeys": .array(enabledKeys.map(ProjectEditJSON.string))])
        if !enabledKeys.isEmpty { next["stateEnabled"] = .bool(true) }
        return next
    }

    /// MP `projection`.
    public static func projection(_ registry: TopicAttributeRegistry, enabledKeys: [String]) throws -> [ProjectEditJSON] {
        try enabledKeys.map { key in
            guard let row = registry.definitions.first(where: { $0.stateKey == key }) else { throw Issue.unregistered(key) }
            return .object(["key": .string(key), "label": .string(row.label), "initial": .number(Decimal(row.initialValue)),
                            "min": .number(Decimal(row.minValue)), "max": .number(Decimal(row.maxValue)), "visible": .bool(row.visible)])
        }
    }

    /// MP `frozenReadback` (light): the cloud's frozen definition rows, used only when they belong to the bound
    /// registry version and this config version. `rules` is compared as `rulesJson`.
    static func frozenRows(_ rules: [String: ProjectEditJSON], registry: TopicAttributeRegistry) -> [String: [String: ProjectEditJSON]] {
        guard let definition = rules["attributeDefinition"]?.object, let binding = rules["attributeBinding"]?.object,
              definition["schemaVersion"]?.integer == 1,
              plain(definition["configVersion"]) == registry.configVersion,
              let version = plain(definition["registryVersion"]), version == plain(binding["registryVersion"]),
              let rows = definition["attributes"]?.array else { return [:] }
        let required = ["key", "keyType", "label", "initial", "min", "max", "visible", "displayType", "persistScope", "color", "icon", "sortOrder", "rules"]
        var result: [String: [String: ProjectEditJSON]] = [:]
        for row in rows {
            guard var object = row.object, required.allSatisfy({ object[$0] != nil }), let key = object["key"]?.text else { return [:] }
            let ruleValue = object["rules"] ?? .null
            if ruleValue == .null { object["rulesJson"] = .null }
            else if let bytes = try? sortedEncoder.encode(ruleValue) { object["rulesJson"] = .string(String(decoding: bytes, as: UTF8.self)) }
            result[key] = object
        }
        return result
    }

    private static func plain(_ value: ProjectEditJSON?) -> String? {
        if let text = value?.text { return text }
        return value?.integer.map(String.init)
    }

    private static let sortedEncoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return encoder
    }()

    /// MP `stable(value)` for an old-config value.
    static func canonical(_ value: ProjectEditJSON) -> String {
        switch value {
        case .null: return "null"
        case .bool(let flag): return flag ? "true" : "false"
        case .number(let number): return "n:" + NSDecimalNumber(decimal: number).stringValue
        case .string(let text): return "s:" + text
        case .array, .object:
            return "j:" + ((try? sortedEncoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "")
        }
    }

    /// MP `String(value)`.
    static func display(_ value: ProjectEditJSON) -> String {
        switch value {
        case .null: return "null"
        case .bool(let flag): return flag ? "true" : "false"
        case .number(let number): return NSDecimalNumber(decimal: number).stringValue
        case .string(let text): return text
        case .array, .object:
            return (try? sortedEncoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        }
    }

    /// Registry row fields in the same canonical form.
    static func registryFields(_ row: PlayWireValue) -> [String: TopicAttributeFieldValue] {
        var result: [String: TopicAttributeFieldValue] = [:]
        for field in fields {
            let value = row[field.registry]
            switch value {
            case .null: result[field.registry] = .init(canonical: "null", display: nil)
            case .bool(let flag): result[field.registry] = .init(canonical: flag ? "true" : "false", display: flag ? "true" : "false")
            case .integer(let number):
                let text = NSDecimalNumber(decimal: Decimal(number)).stringValue
                result[field.registry] = .init(canonical: "n:" + text, display: text)
            case .number(let number):
                let text = NSDecimalNumber(decimal: Decimal(number)).stringValue
                result[field.registry] = .init(canonical: "n:" + text, display: text)
            case .string(let text): result[field.registry] = .init(canonical: "s:" + text, display: text)
            case .array, .object:
                let bytes = (try? sortedEncoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? ""
                result[field.registry] = .init(canonical: "j:" + bytes, display: bytes)
            }
        }
        return result
    }
}
