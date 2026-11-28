import Foundation

/// 主题详情 → 玩法规则 rows d20 检定 (switch) and d20 与角色设定 (sheet), read and written on `journeyRules`.
/// Mini-program: `pages/publish/fabu/theme-d20.js` (`PRESETS`, `ATTR_PRESETS`, `read`, `apply`, `setCheckEnabled`,
/// `summary`, `newAttr`, `clampAttr`) and `fabu/theme-d20-page.js` (`onD20Toggle`, `onD20Save`).
/// Only the fields the MP sheet owns are touched: `checkEnabled`, `natAuto`, `tiers.*.dc`, `rpg.bargain`,
/// `rpg.momentum` and the `counter.*` attribute rows. Clocks and traits are read, never rewritten here.
/// This does not post. The topic save already carries `journeyRules`.
public enum ProjectEditD20Rules {
    /// MP `PRESETS` (规则难度), in MP order. A theme without `tiers` reads as 标准 (server default 10/13/16).
    public enum Preset: String, CaseIterable, Identifiable, Sendable {
        case easy, std, hard
        public var id: String { rawValue }
        public var dc: [Int] {
            switch self {
            case .easy: return [8, 11, 14]
            case .std: return [10, 13, 16]
            case .hard: return [12, 15, 18]
            }
        }
        public var labelKey: String { "mpPublish.d20.preset." + rawValue }
    }

    /// MP `ATTR_PRESETS`, in MP order: the label key and its range / start value.
    public struct AttributePreset: Identifiable, Sendable {
        public let labelKey: String
        public let min: Int
        public let max: Int
        public let initial: Int
        public var id: String { labelKey }
    }

    public static let attributePresets: [AttributePreset] = [
        AttributePreset(labelKey: "mpPublish.d20.attr.preset.observe", min: 0, max: 5, initial: 2),
        AttributePreset(labelKey: "mpPublish.d20.attr.preset.nerve", min: 0, max: 10, initial: 6),
        AttributePreset(labelKey: "mpPublish.d20.attr.preset.body", min: 0, max: 8, initial: 4),
        AttributePreset(labelKey: "mpPublish.d20.attr.preset.insight", min: 0, max: 5, initial: 1),
        AttributePreset(labelKey: "mpPublish.d20.attr.preset.agility", min: 0, max: 5, initial: 2),
        AttributePreset(labelKey: "mpPublish.d20.attr.preset.charm", min: 0, max: 5, initial: 2),
        AttributePreset(labelKey: "mpPublish.d20.attr.preset.luck", min: 0, max: 3, initial: 1),
    ]

    public static let maxAttributes = 6
    public static let attributeNameLimit = 6
    /// MP `theme-values.js` `RANGE`, shared with the runtime-values editor (L03-201).
    public static let attributeFloor = -10_000
    public static let attributeCeiling = 10_000
    /// The MP stepper upper bound for 最大值 (`d20-settings/index.wxml` `max="{{20}}"`).
    public static let stepperCeiling = 20

    public struct Attribute: Identifiable, Equatable, Sendable {
        public var key: String
        public var label: String
        public var min: Int
        public var max: Int
        public var initial: Int
        public var id: String { key }
    }

    public struct Clock: Identifiable, Equatable, Sendable {
        public var key: String
        public var label: String
        public var danger: Bool
        public var segments: Int
        public var id: String { key }
    }

    public struct Aspect: Identifiable, Equatable, Sendable {
        public var key: String
        public var label: String
        public var desc: String
        public var id: String { key }
    }

    /// MP `read(raw)`: the sheet model.
    public struct Model: Equatable, Sendable {
        public var checkEnabled = false
        public var preset: Preset?
        public var natAuto = true
        public var bargain = false
        public var momentum = false
        public var attributes: [Attribute] = []
        /// MP `bound`: the rules bind the attribute registry, so attribute rows are locked.
        public var bound = false
        public var clocks: [Clock] = []
        public var aspects: [Aspect] = []
    }

    public static func model(in draft: ProjectEditDraft) -> Model {
        read(rules(draft) ?? [:])
    }

    static func read(_ rules: [String: ProjectEditJSON]) -> Model {
        var model = Model()
        let rpg = rules["rpg"]?.object ?? [:]
        let clockRows = (rpg["clocks"]?.array ?? []).compactMap { $0.object }
        let clockKeys = Set(clockRows.compactMap { $0["var"]?.text })
        model.checkEnabled = rules["checkEnabled"] == .bool(true)
        model.preset = preset(rules)
        model.natAuto = rules["natAuto"] != .bool(false)
        model.bargain = truthy(rpg["bargain"]?.object?["enabled"])
        model.momentum = truthy(rpg["momentum"]?.object?["enabled"])
        model.bound = truthy(rules["attributeBinding"])
        model.attributes = (rules["attributes"]?.array ?? []).compactMap { value -> Attribute? in
            guard let row = value.object, let key = row["key"]?.text, isCounter(key), !clockKeys.contains(key) else { return nil }
            return Attribute(key: key, label: row["label"]?.text ?? "", min: row["min"]?.integer ?? 0,
                             max: row["max"]?.integer ?? 0, initial: row["initial"]?.integer ?? 0)
        }
        model.clocks = clockRows.map { row in
            let segments = row["segments"]?.integer ?? 0
            return Clock(key: row["var"]?.text ?? "", label: row["label"]?.text ?? "",
                         danger: row["kind"]?.text == "danger", segments: segments == 0 ? 6 : segments)
        }
        model.aspects = (rpg["aspects"]?.array ?? []).compactMap { $0.object }.map { row in
            Aspect(key: row["key"]?.text ?? "", label: row["label"]?.text ?? "", desc: row["desc"]?.text ?? "")
        }
        return model
    }

    /// MP `presetOf`: the preset whose three DCs match; no `tiers` = 标准; customised numbers = none.
    static func preset(_ rules: [String: ProjectEditJSON]) -> Preset? {
        guard let tiers = rules["tiers"]?.object else { return .std }
        let dc = ["easy", "medium", "hard"].map { tiers[$0]?.object?["dc"]?.integer }
        return Preset.allCases.first { preset in preset.dc.enumerated().allSatisfy { dc[$0.offset] == $0.element } }
    }

    /// MP `onD20Toggle` → `setCheckEnabled`: off also switches off 魔鬼交易 and 动量 (they hang on checks),
    /// and keeps `stateEnabled` on when clocks or traits exist. Everything else stays as it is.
    public static func setCheckEnabled(_ enabled: Bool, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var rules = try readable(draft)
        rules["checkEnabled"] = .bool(enabled)
        if !enabled, var rpg = rules["rpg"]?.object {
            if var bargain = rpg["bargain"]?.object {
                bargain["enabled"] = .bool(false)
                rpg["bargain"] = .object(bargain)
            }
            if var momentum = rpg["momentum"]?.object {
                momentum["enabled"] = .bool(false)
                rpg["momentum"] = .object(momentum)
            }
            rules["rpg"] = .object(rpg)
            let hasClocks = !(rpg["clocks"]?.array ?? []).isEmpty
            let hasAspects = !(rpg["aspects"]?.array ?? []).isEmpty
            if hasClocks || hasAspects { rules["stateEnabled"] = .bool(true) }
        }
        return try write(rules, into: draft)
    }

    /// MP `onD20Save` → `apply(rules, model)`. An unchanged model writes nothing.
    public static func save(_ model: Model, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var rules = try readable(draft)
        let current = read(rules)
        if current == model { return draft }
        if let preset = model.preset {
            var tiers = rules["tiers"]?.object ?? [:]
            for (index, name) in ["easy", "medium", "hard"].enumerated() {
                var row = tiers[name]?.object ?? [:]
                row["dc"] = .number(Decimal(preset.dc[index]))
                tiers[name] = .object(row)
            }
            rules["tiers"] = .object(tiers)
        }
        rules["natAuto"] = .bool(model.natAuto)
        var rpg = rules["rpg"]?.object ?? [:]
        var bargain = rpg["bargain"]?.object ?? [:]
        bargain["enabled"] = .bool(model.bargain)
        rpg["bargain"] = .object(bargain)
        var momentum = rpg["momentum"]?.object ?? [:]
        momentum["enabled"] = .bool(model.momentum)
        rpg["momentum"] = .object(momentum)
        rules["rpg"] = .object(rpg)
        if !current.bound {
            let mine = Set(current.attributes.map(\.key))
            let rows = (rules["attributes"]?.array ?? [])
            var old: [String: [String: ProjectEditJSON]] = [:]
            for row in rows {
                if let fields = row.object, let key = fields["key"]?.text { old[key] = fields }
            }
            let kept = rows.filter { row in
                guard let key = row.object?["key"]?.text else { return true }
                return !mine.contains(key)
            }
            let written: [ProjectEditJSON] = model.attributes.map { attribute in
                var row: [String: ProjectEditJSON] = ["visible": .bool(true)]
                for (field, value) in old[attribute.key] ?? [:] { row[field] = value }
                row["key"] = .string(attribute.key)
                row["label"] = .string(attribute.label)
                row["min"] = .number(Decimal(attribute.min))
                row["max"] = .number(Decimal(attribute.max))
                row["initial"] = .number(Decimal(attribute.initial))
                return .object(row)
            }
            rules["attributes"] = .array(written + kept)
            if !written.isEmpty { rules["stateEnabled"] = .bool(true) }
        }
        return try write(rules, into: draft)
    }

    /// MP `newAttr`: a preset keeps its range; a custom name gets 0…5, start 0.
    public static func newAttribute(label: String, preset: AttributePreset?, in model: Model) -> Attribute {
        let used = Set(model.attributes.map(\.key) + model.clocks.map(\.key))
        let stamp = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        var counter = 1
        var key = "counter.value_\(stamp)_\(String(counter, radix: 36))"
        while used.contains(key) {
            counter += 1
            key = "counter.value_\(stamp)_\(String(counter, radix: 36))"
        }
        return Attribute(key: key, label: label, min: preset?.min ?? 0, max: preset?.max ?? 5, initial: preset?.initial ?? 0)
    }

    public enum AttributeField: Sendable { case min, max, initial }

    /// MP `clampAttr`: min < max, and the start value stays inside the range.
    public static func clamp(_ attribute: Attribute, _ field: AttributeField, _ value: Int) -> Attribute {
        var next = attribute
        switch field {
        case .min:
            next.min = Swift.max(attributeFloor, Swift.min(next.max - 1, value))
            next.initial = Swift.max(next.initial, next.min)
        case .max:
            next.max = Swift.max(next.min + 1, Swift.min(attributeCeiling, value))
            next.initial = Swift.min(next.initial, next.max)
        case .initial:
            next.initial = Swift.max(next.min, Swift.min(next.max, value))
        }
        return next
    }

    // MARK: journeyRules plumbing

    static func rules(_ draft: ProjectEditDraft) -> [String: ProjectEditJSON]? {
        try? readable(draft)
    }

    /// MP `parseRules`: an empty value reads as `{}`. Unlike the MP, unreadable non-empty JSON is refused
    /// instead of being replaced by `{}`, so a save never drops rules this page does not show.
    static func readable(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
        guard let raw = draft.preserved["journeyRules"], raw != .null else { return [:] }
        if let object = raw.object { return object }
        guard let text = raw.text else { throw ProjectEditRuntimeActsError.refused(ProjectEditThemeRules.Copy.unreadable) }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [:] }
        guard text.utf8.count <= 1_048_576,
              let value = try? JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8)),
              let object = value.object else {
            throw ProjectEditRuntimeActsError.refused(ProjectEditThemeRules.Copy.unreadable)
        }
        return object
    }

    static func write(_ rules: [String: ProjectEditJSON], into draft: ProjectEditDraft) throws -> ProjectEditDraft {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ProjectEditJSON.object(rules))
        guard let text = String(data: data, encoding: .utf8), data.count <= 1_048_576 else { throw ProjectEditError.invalidDraft }
        var next = draft
        next.preserved["journeyRules"] = .string(text)
        return next
    }

    /// MP `values.COUNTER`: `counter.` + a lowercase name of up to 48 characters.
    static func isCounter(_ key: String) -> Bool {
        key.range(of: "^counter\\.[a-z][a-z0-9_]{0,47}$", options: .regularExpression) != nil
    }

    private static func truthy(_ value: ProjectEditJSON?) -> Bool {
        switch value {
        case .bool(let flag)?: return flag
        case .number(let number)?: return number != 0
        case .string(let text)?: return !text.isEmpty
        case .array?, .object?: return true
        default: return false
        }
    }
}
