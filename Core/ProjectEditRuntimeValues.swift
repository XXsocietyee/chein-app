import Foundation

/// 主题详情 → runtime-values card rows 自定义整数值 (MP `topic-detail-sheet.wxml:130-135`) and the
/// value editor sheet (MP `fabu/index.wxml:1856-1877`).
/// MP `theme-runtime.js` `openValueEditor` / `saveValueEditor` / `removeValue` / `onValueEnabled` /
/// `onValueLinkSwitch` / `addValueLink` and `fabu/theme-values.js` `nextKey` / `attribute` / `links` / `references`.
/// Rows live on `journeyRules.attributes` (keys `counter.*`), links on `journeyRules.statLinks`.
/// This does not post. The topic save already carries `journeyRules`.
public enum ProjectEditRuntimeValues {
    /// MP `values.RANGE` (L03-201: the value editor and the d20 attributes share one range).
    public static let floor = -10_000
    public static let ceiling = 10_000
    /// MP `attribute`: 数值名称须为 1 至 24 字.
    public static let labelLimit = 24
    /// MP `saveValueEditor`: 初始属性最多配置 32 项.
    public static let maxValues = 32

    public enum Copy {
        public static let title = "mpPublish.values.custom"
        public static let add = "mpPublish.values.custom.add"
        public static let addTitle = "mpPublish.values.custom.addTitle"
        public static let editTitle = "mpPublish.values.custom.editTitle"
        public static let labelInvalid = "mpPublish.values.custom.labelInvalid"
        public static let rangeInvalid = "mpPublish.values.custom.rangeInvalid"
        public static let tooMany = "mpPublish.values.custom.tooMany"
        public static let needsHP = "mpPublish.values.custom.needsHP"
        public static let bound = "mpPublish.values.custom.bound"
        public static let unknown = "mpPublish.values.custom.unknown"
        /// MP `saveValueEditor` (bound): 请先在初始状态中启用注册属性.
        public static let notEnabled = "mpPublish.values.custom.notEnabled"
        /// MP `saveValueEditor` (bound): 属性定义已变化，请重新读取后编辑关联.
        public static let definitionChanged = "mpPublish.values.custom.definitionChanged"
    }

    /// One MP `runtimeValues` row.
    public struct Value: Equatable, Hashable, Identifiable, Sendable {
        public var key: String
        public var label: String
        public var min: Int
        public var max: Int
        public var initial: Int
        public var visible: Bool
        public var id: String { key }
        /// MP `invalidInitial`: the starting value is outside min…max (row shows 开局值越界).
        public var invalidInitial: Bool { initial < min || initial > max }

        public init(key: String, label: String, min: Int, max: Int, initial: Int, visible: Bool) {
            self.key = key; self.label = label; self.min = min; self.max = max; self.initial = initial; self.visible = visible
        }
    }

    /// MP `values.references` places, formatted by the view (第N章费用 / 物品「名」效果 / 关联「id」 /
    /// 第N章节点「名」玩法绑定 · path).
    public enum Reference: Equatable, Hashable, Sendable {
        case chapterCost(Int)
        case item(String)
        case link(String)
        case node(chapter: Int, node: String, path: String)
    }

    public enum Refusal: Error, Equatable {
        case copy(String)
        case referenced([Reference])
    }

    /// MP `_syncRuntimeStats` `runtimeValues`: the `counter.*` attributes in stored order.
    public static func values(in draft: ProjectEditDraft) -> [Value] {
        guard let rules = try? ProjectEditD20Rules.readable(draft) else { return [] }
        return (rules["attributes"]?.array ?? []).compactMap { value($0) }
    }

    /// MP `r.attributeBinding`: definitions come from the registry and are read-only here.
    public static func bound(in draft: ProjectEditDraft) -> Bool {
        guard let rules = try? ProjectEditD20Rules.readable(draft), let binding = rules["attributeBinding"] else { return false }
        return binding != .null
    }

    /// MP `openValueEditor` with no index: a new row 0 至 100, 开局 0, 玩家可见.
    public static func newValue(in draft: ProjectEditDraft, now: Date = Date()) -> Value {
        let rules = (try? ProjectEditD20Rules.readable(draft)) ?? [:]
        let used = Set((rules["attributes"]?.array ?? []).compactMap { $0.object?["key"]?.text })
        let stamp = String(Int(now.timeIntervalSince1970 * 1000), radix: 36)
        var counter = 1
        var key = "counter.value_\(stamp)_\(String(counter, radix: 36))"
        while used.contains(key) {
            counter += 1
            key = "counter.value_\(stamp)_\(String(counter, radix: 36))"
        }
        return Value(key: key, label: "", min: 0, max: 100, initial: 0, visible: true)
    }

    /// MP `valueEditor.links.length > 0` for this row (下降时一起扣生命值).
    public static func linked(_ key: String, in draft: ProjectEditDraft) -> Bool {
        guard let rules = try? ProjectEditD20Rules.readable(draft) else { return false }
        return (rules["statLinks"]?.array ?? []).contains { $0.object?["sourceKey"]?.text == key }
    }

    /// MP `saveValueEditor` (not bound): validates through `attribute`, keeps a saved row's 开局值,
    /// replaces this row's links (a new default PER_POINT link when `link` is on and none existed),
    /// and turns `stateEnabled` on.
    public static func save(_ value: Value, link: Bool, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        if bound(in: draft) { return try saveBoundLinks(value, link: link, in: draft) }
        guard ProjectEditD20Rules.isCounter(value.key) else { throw Refusal.copy(Copy.unknown) }
        let label = value.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.count <= labelLimit else { throw Refusal.copy(Copy.labelInvalid) }
        guard value.min >= floor, value.max <= ceiling, value.min <= value.max else { throw Refusal.copy(Copy.rangeInvalid) }
        var rules = try readableRules(draft)
        var attributes = rules["attributes"]?.array ?? []
        let current = attributes.firstIndex { $0.object?["key"]?.text == value.key }
        var row = current.flatMap { attributes[$0].object } ?? [:]
        row["key"] = .string(value.key)
        row["label"] = .string(label)
        row["min"] = .number(Decimal(value.min))
        row["max"] = .number(Decimal(value.max))
        row["visible"] = .bool(value.visible)
        if current == nil { row["initial"] = .number(Decimal(value.initial)) }
        if let current { attributes[current] = .object(row) } else { attributes.append(.object(row)) }
        guard attributes.count <= maxValues else { throw Refusal.copy(Copy.tooMany) }
        rules["attributes"] = .array(attributes)
        try writeLinks(for: value.key, link: link, into: &rules, draft: draft)
        rules["stateEnabled"] = .bool(true)
        return try ProjectEditD20Rules.write(rules, into: draft)
    }

    /// MP `saveValueEditor` with `r.attributeBinding`: the definition is the registry's, so only this
    /// row's 关联 is written. The row must be enabled in the binding and unchanged since it was read.
    static func saveBoundLinks(_ value: Value, link: Bool, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        var rules = try readableRules(draft)
        let enabled = (rules["attributeBinding"]?.object?["enabledKeys"]?.array ?? []).compactMap { $0.text }
        let stored = (rules["attributes"]?.array ?? []).compactMap { Self.value($0) }.first { $0.key == value.key }
        guard let stored, enabled.contains(value.key) else { throw Refusal.copy(Copy.notEnabled) }
        guard stored == value else { throw Refusal.copy(Copy.definitionChanged) }
        try writeLinks(for: value.key, link: link, into: &rules, draft: draft)
        rules["stateEnabled"] = .bool(true)
        return try ProjectEditD20Rules.write(rules, into: draft)
    }

    /// MP `onValueLinkSwitch` + `saveValueEditor` links: replaces this row's links (a new default
    /// PER_POINT link when `link` is on and none existed; none when off).
    private static func writeLinks(for key: String, link: Bool, into rules: inout [String: ProjectEditJSON], draft: ProjectEditDraft) throws {
        let allLinks = rules["statLinks"]?.array ?? []
        let own = allLinks.filter { $0.object?["sourceKey"]?.text == key }
        var links = allLinks.filter { $0.object?["sourceKey"]?.text != key }
        if link {
            guard ProjectEditRuntimeStats.enabled(.hp, in: draft) else { throw Refusal.copy(Copy.needsHP) }
            if own.isEmpty {
                links.append(defaultLink(source: key, existing: allLinks))
            } else {
                links.append(contentsOf: own)
            }
        }
        // MP writes statLinks only when the rules had them or a link exists.
        if !links.isEmpty || rules["statLinks"] != nil {
            rules["statLinks"] = .array(links)
        }
    }

    /// MP `removeValue` (the row switch off, or 删除数值): refused while the value is referenced.
    public static func remove(_ key: String, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        if bound(in: draft) { throw Refusal.copy(Copy.bound) }
        let found = references(key, in: draft)
        if !found.isEmpty { throw Refusal.referenced(found) }
        var rules = try readableRules(draft)
        let attributes = (rules["attributes"]?.array ?? []).filter { $0.object?["key"]?.text != key }
        rules["attributes"] = .array(attributes)
        let hpOn = ProjectEditRuntimeStats.enabled(.hp, in: draft)
        let luckOn = ProjectEditRuntimeStats.enabled(.luck, in: draft)
        rules["stateEnabled"] = .bool(hpOn || luckOn || !attributes.isEmpty)
        return try ProjectEditD20Rules.write(rules, into: draft)
    }

    /// MP reference keys for the two built-in values (`sys.hp` / `sys.luck`).
    public static let hpKey = "sys.hp"
    public static let luckKey = "sys.luck"

    /// MP `values.references` for the runtime config (chapter `statCosts`, item `statKey`),
    /// journeyRules `statLinks` and each node's gameplay binding (the node's retained MP fields).
    public static func references(_ key: String, in draft: ProjectEditDraft) -> [Reference] {
        var found: [Reference] = []
        let theme = (try? ProjectEditThemeRules.readable(draft)) ?? [:]
        for (index, chapter) in (theme["chapters"]?.array ?? []).enumerated() {
            guard let object = chapter.object else { continue }
            let number = (object["index"]?.integer ?? index) + 1
            let costs = object["statCosts"]?.array ?? []
            if costs.contains(where: { $0.object?["statKey"]?.text == key }) { found.append(.chapterCost(number)) }
        }
        // MP: 生命值 / 幸运值 are also spent through the chapter hpCost / luckCost fields.
        for (index, chapter) in (theme["chapters"]?.array ?? []).enumerated() {
            guard let object = chapter.object else { continue }
            let number = (object["index"]?.integer ?? index) + 1
            let hpCost = object["hpCost"]?.integer ?? 0
            let luckCost = object["luckCost"]?.integer ?? 0
            if (key == hpKey && hpCost > 0) || (key == luckKey && luckCost > 0) { found.append(.chapterCost(number)) }
        }
        for item in theme["items"]?.array ?? [] {
            guard let object = item.object else { continue }
            let stat = object["stat"]?.text ?? ""
            let uses = object["statKey"]?.text == key || (key == hpKey && stat == "HP") || (key == luckKey && stat == "LUCK")
            guard uses else { continue }
            let name = object["name"]?.text ?? ""
            found.append(.item(name.isEmpty ? (object["id"]?.text ?? "") : name))
        }
        let rules = (try? ProjectEditD20Rules.readable(draft)) ?? [:]
        for link in rules["statLinks"]?.array ?? [] {
            guard let object = link.object else { continue }
            if object["sourceKey"]?.text == key || object["targetKey"]?.text == key {
                found.append(.link(object["id"]?.text ?? ""))
            }
        }
        for (chapterIndex, chapter) in draft.chapters.enumerated() {
            for (nodeIndex, node) in chapter.nodes.enumerated() {
                let name = node.name.isEmpty ? String(nodeIndex + 1) : node.name
                for path in nodePaths(key, in: .object(node.localMetadata), path: "") {
                    found.append(.node(chapter: chapterIndex + 1, node: name, path: path))
                }
            }
        }
        var unique: [Reference] = []
        for row in found where !unique.contains(row) { unique.append(row) }
        return unique
    }

    // MARK: plumbing

    private static let keyFields = ["statKey", "sourceKey", "targetKey"]

    /// MP `references` `walk`: JSON text that starts with `[` or `{` is parsed and walked; arrays add
    /// `[n]` (1-based); a `statKey` / `sourceKey` / `targetKey` equal to `key` yields `path + field`.
    /// Object keys are walked in sorted order so the list is stable.
    static func nodePaths(_ key: String, in node: ProjectEditJSON, path: String) -> [String] {
        switch node {
        case .string(let text):
            let trimmed = text.drop(while: { $0.isWhitespace })
            guard trimmed.first == "[" || trimmed.first == "{",
                  let parsed = try? JSONDecoder().decode(ProjectEditJSON.self, from: Data(text.utf8)) else { return [] }
            return nodePaths(key, in: parsed, path: path)
        case .array(let rows):
            var result: [String] = []
            for (index, row) in rows.enumerated() {
                result.append(contentsOf: nodePaths(key, in: row, path: path + "[\(index + 1)]"))
            }
            return result
        case .object(let object):
            var result: [String] = []
            for field in keyFields where object[field]?.text == key {
                result.append(path + field)
            }
            for field in object.keys.sorted() where !keyFields.contains(field) {
                if let child = object[field] {
                    result.append(contentsOf: nodePaths(key, in: child, path: path + field + "."))
                }
            }
            return result
        default:
            return []
        }
    }

    private static func readableRules(_ draft: ProjectEditDraft) throws -> [String: ProjectEditJSON] {
        do {
            return try ProjectEditD20Rules.readable(draft)
        } catch {
            throw Refusal.copy(ProjectEditThemeRules.Copy.unreadable)
        }
    }

    private static func value(_ json: ProjectEditJSON) -> Value? {
        guard let object = json.object, let key = object["key"]?.text, ProjectEditD20Rules.isCounter(key) else { return nil }
        let min = object["min"]?.integer ?? 0
        let max = object["max"]?.integer ?? 100
        let initial = object["initial"]?.integer ?? min
        let visible = object["visible"] != .bool(false)
        return Value(key: key, label: object["label"]?.text ?? "", min: min, max: max, initial: initial, visible: visible)
    }

    /// MP `addValueLink`: `link_N` (first free N), PER_POINT × 1 on TASK_COST, once per event, onto `sys.hp`.
    private static func defaultLink(source: String, existing: [ProjectEditJSON]) -> ProjectEditJSON {
        let ids = Set(existing.compactMap { $0.object?["id"]?.text })
        var suffix = 1
        while ids.contains("link_\(suffix)") { suffix += 1 }
        return .object([
            "id": .string("link_\(suffix)"),
            "sourceKey": .string(source),
            "targetKey": .string("sys.hp"),
            "trigger": .string("PER_POINT"),
            "allowedReasons": .array([.string("TASK_COST")]),
            "frequency": .string("EVENT"),
            "multiplier": .number(1),
        ])
    }
}
