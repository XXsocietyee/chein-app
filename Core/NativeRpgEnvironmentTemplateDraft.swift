import Foundation

public struct NativeRpgEnvironmentTemplateDraft: Equatable {
    public static let metricKeys = ["sys.temp", "sys.node.altitude", "sys.distance.km", "sys.party.size"]
    public static let conditionKeys = ["sys.weather", "sys.hour", "sys.is_day", "sys.node.indoor"] + metricKeys
    public static func validThreshold(_ value: Double, for key: String) -> Bool {
        value.isFinite && conditionKeys.contains(key) && (metricKeys.contains(key) || value.rounded() == value && (-99...99).contains(value))
    }
    public static let weatherKeys = ["clear", "cloudy", "rain", "snow", "fog", "windy", "hot", "cold", "storm"]
    public let original: TemplateAdvancedDraft
    public private(set) var draft: TemplateAdvancedDraft
    public init(_ original: TemplateAdvancedDraft) throws {
        guard Self.issues(original).isEmpty else { throw NativeRpgEnvironmentAuthorDraft.Failure.unsupported }
        self.original = original; draft = original
    }
    public var preview: String {
        let payload: [String: TemplateAuthoringJSON] = ["env": draft.value["env"] ?? .null, "mods": .array(draft.rows("check", "mods"))]
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(payload)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
    public var weather: String { draft.value["env"]?.object?["weather"]?.string ?? "" }
    public var indoor: String {
        guard let value = draft.value["env"]?.object?["indoor"]?.bool else { return "" }
        return value ? "indoor" : "outdoor"
    }
    public mutating func weather(_ value: String) {
        guard value.isEmpty || Self.weatherKeys.contains(value) else { return }
        patch("weather", value: value.isEmpty ? nil : .string(value))
    }
    public mutating func indoor(_ value: String) {
        guard ["", "indoor", "outdoor"].contains(value) else { return }
        patch("indoor", value: value.isEmpty ? nil : .bool(value == "indoor"))
    }
    public mutating func appendModifier(label: String, amount: Int, variable: String, operation: String, threshold: Int) throws {
        try appendModifier(label: label, amount: amount, variable: variable, operation: operation, threshold: Double(threshold))
    }
    public mutating func appendModifier(label: String, amount: Int, variable: String, operation: String, threshold: Double) throws {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.utf16.count <= 80, (-99...99).contains(amount), Self.validThreshold(threshold, for: variable),
              Self.conditionKeys.contains(variable), ["EQ", "NE", "GT", "GTE", "LT", "LTE"].contains(operation),
              draft.value["check"]?.object?["mods"] == nil || draft.value["check"]?.object?["mods"]?.array != nil else { throw NativeRpgEnvironmentAuthorDraft.Failure.invalid }
        var rows = draft.rows("check", "mods"); guard rows.count < 16 else { throw NativeRpgEnvironmentAuthorDraft.Failure.invalid }
        rows.append(.object(["label": .string(label), "value": .number(Double(amount)),
            "when": .object(["var": .string(variable), "op": .string(operation), "value": .number(Double(threshold))])]))
        draft.set("check", "mods", .array(rows))
    }
    private mutating func patch(_ key: String, value: TemplateAuthoringJSON?) {
        var env = draft.value["env"]?.object ?? [:]; env[key] = value
        draft.value["env"] = env.isEmpty ? nil : .object(env)
    }
    public func applying(to current: TemplateAdvancedDraft) throws -> TemplateAdvancedDraft {
        guard let bytes = ProjectEditPendingMaterials.exactData(original), ProjectEditPendingMaterials.exactData(current) == bytes else { throw NativeRpgEnvironmentAuthorDraft.Failure.changed }
        guard Self.issues(draft).isEmpty, draft.creatorIssues(.check).isEmpty else { throw NativeRpgEnvironmentAuthorDraft.Failure.invalid }; return draft
    }
    public static func issues(_ draft: TemplateAdvancedDraft) -> [String] {
        guard let value = draft.value["env"], value != .null else { return [] }
        guard let env = value.object, Set(env.keys).isSubset(of: ["weather", "indoor"]) else { return ["节点环境仅接受原剧本天气与明确室内配置"] }
        var result: [String] = []
        if let weather = env["weather"], !weatherKeys.contains(weather.string ?? "") { result.append("请选择正式天气编码；空缺不代表晴天") }
        if let indoor = env["indoor"], indoor.bool == nil { result.append("室内配置须为布尔值；未知不代表户外") }
        return result
    }
}
