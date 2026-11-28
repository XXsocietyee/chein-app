import Foundation

/// 主题详情 → runtime-values card rows 生命值 · 幸运值 (MP `topic-detail-sheet.wxml:115-123`).
/// MP `theme-runtime.js` `_syncRuntimeStats` / `onRuntimeStatToggle` / `onRuntimeStatMax` / `onRuntimeName`
/// and `utils/publish/story-initial-state.js` `parse` / `serialize`.
/// The switch and 上限 live on `journeyRules` (`hp` / `luck`); 显示名称 lives on `themeRuntimeConfig`
/// (`hpName` / `luckName`). This does not post. The topic save already carries both fields.
public enum ProjectEditRuntimeStats {
    public enum Stat: String, CaseIterable, Hashable, Sendable {
        case hp, luck

        /// MP `serialize` ranges: 生命值上限 1–20, 幸运值上限 0–5.
        public var maximumRange: ClosedRange<Int> { self == .hp ? 1...20 : 0...5 }
        var defaultInitial: Int { self == .hp ? 10 : 3 }
        var defaultMaximum: Int { self == .hp ? 10 : 3 }
        var nameField: String { self == .hp ? "hpName" : "luckName" }
        /// Default label when the theme has no own name (MP `runtimeHpLabel` / `runtimeLuckLabel`).
        public var labelKey: String { self == .hp ? "mpPublish.values.hp" : "mpPublish.values.luck" }
        /// MP `serialize`: 生命值上限须为 1 至 20 的整数 / 幸运值上限须为 0 至 5 的整数.
        public var maximumInvalidKey: String { self == .hp ? "mpPublish.values.hp.maxInvalid" : "mpPublish.values.luck.maxInvalid" }
    }

    public enum Copy {
        public static let initialOverMaximum = "mpPublish.values.stat.initialOver"
        public static let schemaTwo = "mpPublish.values.stat.schemaTwo"
    }

    /// The MP card only reads schema-1 journeyRules. Older native schema-2 rules keep their own editor.
    public static func available(in draft: ProjectEditDraft) -> Bool {
        guard let rules = try? ProjectEditD20Rules.readable(draft) else { return false }
        guard let version = rules["schemaVersion"], version != .null else { return true }
        return version.integer == 1
    }

    /// MP `parse`: a missing `hp` / `luck` block is on, unless journeyRules is empty (a fresh topic).
    public static func enabled(_ stat: Stat, in draft: ProjectEditDraft) -> Bool {
        guard let rules = try? ProjectEditD20Rules.readable(draft) else { return false }
        if rules.isEmpty { return false }
        guard let block = rules[stat.rawValue]?.object, let value = block["enabled"], value != .null else { return true }
        return value == .bool(true)
    }

    public static func maximum(_ stat: Stat, in draft: ProjectEditDraft) -> Int {
        guard let rules = try? ProjectEditD20Rules.readable(draft) else { return stat.defaultMaximum }
        return rules[stat.rawValue]?.object?["max"]?.integer ?? stat.defaultMaximum
    }

    public static func initial(_ stat: Stat, in draft: ProjectEditDraft) -> Int {
        guard let rules = try? ProjectEditD20Rules.readable(draft) else { return stat.defaultInitial }
        return rules[stat.rawValue]?.object?["init"]?.integer ?? stat.defaultInitial
    }

    /// MP `hpName` / `luckName` on the theme config (empty = default label).
    public static func name(_ stat: Stat, in draft: ProjectEditDraft) -> String {
        guard let theme = try? NativeRuntimeStructureAuthorDraft.readTheme(draft) else { return "" }
        return theme[stat.nameField]?.text ?? ""
    }

    /// MP `onRuntimeStatToggle`: writes `enabled`, keeps `stateEnabled` in step with hp / luck / attributes,
    /// and turns `checkEnabled` on when either is on. Missing blocks get the MP `parse` defaults.
    public static func setEnabled(_ enabled: Bool, _ stat: Stat, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        guard available(in: draft) else { throw ProjectEditRuntimeActsError.refused(Copy.schemaTwo) }
        let original = try ProjectEditD20Rules.readable(draft)
        var rules = original
        let fresh = rules.isEmpty
        var blocks: [Stat: [String: ProjectEditJSON]] = [:]
        for row in Stat.allCases {
            var block = rules[row.rawValue]?.object ?? [:]
            if block["enabled"] == nil || block["enabled"] == .null { block["enabled"] = .bool(!fresh) }
            if block["init"] == nil || block["init"] == .null { block["init"] = .number(Decimal(row.defaultInitial)) }
            if block["max"] == nil || block["max"] == .null { block["max"] = .number(Decimal(row.defaultMaximum)) }
            blocks[row] = block
        }
        blocks[stat]?["enabled"] = .bool(enabled)
        for row in Stat.allCases { rules[row.rawValue] = .object(blocks[row] ?? [:]) }
        let hpOn = blocks[.hp]?["enabled"] == .bool(true)
        let luckOn = blocks[.luck]?["enabled"] == .bool(true)
        let attributes = rules["attributes"]?.array?.isEmpty == false
        rules["schemaVersion"] = .number(1)
        rules["stateEnabled"] = .bool(hpOn || luckOn || attributes)
        if hpOn || luckOn { rules["checkEnabled"] = .bool(true) }
        if rules == original { return draft }
        return try ProjectEditD20Rules.write(rules, into: draft)
    }

    /// MP `onRuntimeStatMax` (ranges from `serialize`). Returns the draft and, when the first-chapter
    /// value is now above the cap, the MP warning key (the value is kept; 发布前检查 blocks it).
    public static func setMaximum(_ value: Int, _ stat: Stat, in draft: ProjectEditDraft) throws -> (draft: ProjectEditDraft, warning: String?) {
        guard available(in: draft) else { throw ProjectEditRuntimeActsError.refused(Copy.schemaTwo) }
        guard stat.maximumRange.contains(value) else { throw ProjectEditRuntimeActsError.refused(stat.maximumInvalidKey) }
        var rules = try ProjectEditD20Rules.readable(draft)
        var block = rules[stat.rawValue]?.object ?? [:]
        let warning = initial(stat, in: draft) > value ? Copy.initialOverMaximum : nil
        if block["max"]?.integer == value { return (draft, warning) }
        block["max"] = .number(Decimal(value))
        rules[stat.rawValue] = .object(block)
        return (try ProjectEditD20Rules.write(rules, into: draft), warning)
    }

    /// MP `onRuntimeName` for `hpName` / `luckName`: cut to 20 characters, written as typed.
    public static func setName(_ name: String, _ stat: Stat, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var theme = try ProjectEditThemeRules.readable(draft)
        let value = String(name.prefix(ProjectEditThemeRules.statNameLimit))
        if (theme[stat.nameField]?.text ?? "") == value { return draft }
        if theme.isEmpty { theme = ProjectEditThemeRules.defaults }
        theme[stat.nameField] = .string(value)
        return try ProjectEditThemeRules.write(theme, into: draft)
    }

}
