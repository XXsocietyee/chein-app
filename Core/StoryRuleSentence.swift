import Foundation
import Observation

// MARK: - Story Rule Sentence Engine & Editor (Ported from pages/publish/utils/publish/story-rule-sentence.js & story-rule-editor/index.js)

public struct StoryRuleNameItem: Codable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let initial: Int?
    public let segments: Int?

    public init(key: String, label: String, initial: Int? = nil, segments: Int? = nil) {
        self.key = key
        self.label = label
        self.initial = initial
        self.segments = segments
    }
}

public struct StoryRuleNames: Codable, Equatable, Sendable {
    public var clue: [StoryRuleNameItem]
    public var tag: [StoryRuleNameItem]
    public var item: [StoryRuleNameItem]
    public var trait: [StoryRuleNameItem]
    public var attr: [StoryRuleNameItem]
    public var clock: [StoryRuleNameItem]
    public var value: [StoryRuleNameItem]
    public var node: [StoryRuleNameItem]

    public init(
        clue: [StoryRuleNameItem] = [],
        tag: [StoryRuleNameItem] = [],
        item: [StoryRuleNameItem] = [],
        trait: [StoryRuleNameItem] = [],
        attr: [StoryRuleNameItem] = [],
        clock: [StoryRuleNameItem] = [],
        value: [StoryRuleNameItem] = [],
        node: [StoryRuleNameItem] = []
    ) {
        self.clue = clue
        self.tag = tag
        self.item = item
        self.trait = trait
        self.attr = attr
        self.clock = clock
        self.value = value
        self.node = node
    }

    public subscript(list: String) -> [StoryRuleNameItem] {
        get {
            switch list {
            case "clue": return clue
            case "tag": return tag
            case "item": return item
            case "trait": return trait
            case "attr": return attr
            case "clock": return clock
            case "value": return value
            case "node": return node
            default: return []
            }
        }
        set {
            switch list {
            case "clue": clue = newValue
            case "tag": tag = newValue
            case "item": item = newValue
            case "trait": trait = newValue
            case "attr": attr = newValue
            case "clock": clock = newValue
            case "value": value = newValue
            case "node": node = newValue
            default: break
            }
        }
    }
}

public struct StoryRuleKindDef: Equatable, Sendable {
    public let kind: String
    public let label: String
    public let names: String?

    public init(kind: String, label: String, names: String? = nil) {
        self.kind = kind
        self.label = label
        self.names = names
    }
}

public struct StoryRuleSegmentOption: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct StoryRuleSegmentedControl: Equatable, Sendable {
    public let options: [StoryRuleSegmentOption]
    public let value: String

    public init(options: [StoryRuleSegmentOption], value: String) {
        self.options = options
        self.value = value
    }
}

public struct StoryRuleAmountControl: Equatable, Sendable {
    public let label: String
    public let value: Int
    public let min: Int
    public let max: Int
}

public struct StoryRuleRowEditor: Equatable, Sendable {
    public let neg: StoryRuleSegmentedControl?
    public let names: StoryRuleSegmentedControl?
    public let renameLabel: String?
    public let cmp: StoryRuleSegmentedControl?
    public let result: StoryRuleSegmentedControl?
    public let varOp: StoryRuleSegmentedControl?
    public let amount: StoryRuleAmountControl?
}

public struct StoryRuleRow: Equatable, Identifiable, Sendable {
    public var id: String { path + ":" + type }
    public let path: String
    public let type: String // "leaf" | "group" | "groupSeg" | "groupAdd" | "groupDel"
    public let depth: Int
    public let text: String
    public let open: Bool
    public let unsupported: Bool
    public let canUp: Bool
    public let mode: String?
    public let editor: StoryRuleRowEditor?
}

public struct StoryRuleRegistryEntry: Equatable, Sendable {
    public let stateKey: String
    public let label: String
    public let initialValue: Int?

    public init(stateKey: String, label: String, initialValue: Int? = nil) {
        self.stateKey = stateKey
        self.label = label
        self.initialValue = initialValue
    }
}

public enum StoryRuleSentenceEngine {
    public static let conditionKinds: [StoryRuleKindDef] = [
        StoryRuleKindDef(kind: "clue", label: W8Text.t("已获得线索", "Clue obtained"), names: "clue"),
        StoryRuleKindDef(kind: "equip", label: W8Text.t("装备着物品", "Item equipped"), names: "item"),
        StoryRuleKindDef(kind: "tag", label: W8Text.t("有标签", "Has tag"), names: "tag"),
        StoryRuleKindDef(kind: "trait", label: W8Text.t("有特质", "Has trait"), names: "trait"),
        StoryRuleKindDef(kind: "attr", label: W8Text.t("属性达到…", "Attribute reaches…"), names: "attr"),
        StoryRuleKindDef(kind: "clock", label: W8Text.t("进度钟达到…", "Clock reaches…"), names: "clock"),
        StoryRuleKindDef(kind: "value", label: W8Text.t("数值达到…", "Value reaches…"), names: "value"),
        StoryRuleKindDef(kind: "visit", label: W8Text.t("到过节点…", "Visited station…"), names: "node"),
        StoryRuleKindDef(kind: "done", label: W8Text.t("已完成节点", "Completed station"), names: "node"),
        StoryRuleKindDef(kind: "check", label: W8Text.t("检定结果…", "Check result…"), names: "node"),
        StoryRuleKindDef(kind: "group", label: W8Text.t("一组条件（全部 / 任一）", "Condition group (all / any)"), names: nil),
    ]

    public static let effectKinds: [StoryRuleKindDef] = [
        StoryRuleKindDef(kind: "clue", label: W8Text.t("给线索", "Give clue"), names: "clue"),
        StoryRuleKindDef(kind: "item", label: W8Text.t("给物品", "Give item"), names: "item"),
        StoryRuleKindDef(kind: "equip", label: W8Text.t("穿戴物品", "Equip item"), names: "item"),
        StoryRuleKindDef(kind: "unequip", label: W8Text.t("卸下物品", "Unequip item"), names: "item"),
        StoryRuleKindDef(kind: "tag", label: W8Text.t("记上标签", "Add tag"), names: "tag"),
        StoryRuleKindDef(kind: "trait", label: W8Text.t("加上特质", "Add trait"), names: "trait"),
        StoryRuleKindDef(kind: "untrait", label: W8Text.t("移除特质", "Remove trait"), names: "trait"),
        StoryRuleKindDef(kind: "clock", label: W8Text.t("推进进度钟", "Advance clock"), names: "clock"),
        StoryRuleKindDef(kind: "attr", label: W8Text.t("属性变化", "Change attribute"), names: "attr"),
        StoryRuleKindDef(kind: "value", label: W8Text.t("数值变化", "Change value"), names: "value"),
        StoryRuleKindDef(kind: "xp", label: W8Text.t("给探索值", "Give XP"), names: nil),
        StoryRuleKindDef(kind: "badge", label: W8Text.t("授予徽章", "Award badge"), names: "trait"),
    ]

    public static let cmpOps = ["GTE", "LTE", "EQ"]
    public static let cmpLabels = [W8Text.t("至少", "at least"), W8Text.t("至多", "at most"), W8Text.t("正好", "exactly")]
    private static let cmpWord: [String: String] = [
        "GTE": W8Text.t("至少", "at least"), "LTE": W8Text.t("至多", "at most"), "EQ": W8Text.t("正好", "exactly"), "NE": W8Text.t("不是", "not"), "GT": W8Text.t("超过", "more than"), "LT": W8Text.t("少于", "less than")
    ]
    private static let negPair: [String: (String, String)] = [
        "clue": (W8Text.t("已获得", "Obtained"), W8Text.t("未获得", "Not obtained")),
        "equip": (W8Text.t("装备着", "Equipped"), W8Text.t("未装备", "Not equipped")),
        "tag": (W8Text.t("有", "Has"), W8Text.t("没有", "Does not have")),
        "trait": (W8Text.t("有", "Has"), W8Text.t("没有", "Does not have")),
        "done": (W8Text.t("已完成", "Completed"), W8Text.t("未完成", "Not completed")),
    ]
    private static let sysNames: [String: String] = [
        "sys.hp": W8Text.t("生命值", "Health"),
        "sys.luck": W8Text.t("幸运值", "Luck"),
        "sys.actions": W8Text.t("行动次数", "Actions"),
    ]

    public static func buildNames(
        journey: PlayWireValue = .object([:]),
        runtime: PlayWireValue = .object([:]),
        nodes: [PlayWireValue] = [],
        variables: [String: Int] = [:]
    ) -> StoryRuleNames {
        let attrs = journey["attributes"].array ?? []
        let rpg = journey["rpg"]
        var clue: [StoryRuleNameItem] = []
        var tag: [StoryRuleNameItem] = []
        var item: [StoryRuleNameItem] = []
        var trait: [StoryRuleNameItem] = []
        var attr: [StoryRuleNameItem] = []
        var clock: [StoryRuleNameItem] = []
        var value: [StoryRuleNameItem] = []

        func push(_ list: inout [StoryRuleNameItem], key: String?, label: String?, initial: Int? = nil, segments: Int? = nil) {
            let k = (key ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let l = (label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !k.isEmpty, !l.isEmpty, !list.contains(where: { $0.key == k }) else { return }
            list.append(StoryRuleNameItem(key: k, label: l, initial: initial, segments: segments))
        }

        for a in attrs {
            guard let k = a["key"].text else { continue }
            let name = a["name"].text ?? a["label"].text
            if k.hasPrefix("clue.") {
                push(&clue, key: k, label: name)
            } else if k.hasPrefix("tag.") {
                push(&tag, key: k, label: name)
            } else if k.hasPrefix("counter.") {
                push(&attr, key: k, label: name, initial: a["initial"].tolerantInteger ?? 0)
            }
        }
        for c in rpg["clocks"].array ?? [] {
            push(&clock, key: c["var"].text, label: c["label"].text, initial: nil, segments: c["segments"].tolerantInteger ?? 6)
        }
        for a in (rpg["aspects"].array ?? []) + (rpg["facets"].array ?? []) {
            push(&trait, key: a["key"].text, label: a["label"].text)
        }
        for it in (runtime["items"].array ?? []) + (journey["items"].array ?? []) {
            push(&item, key: it["id"].text ?? it["key"].text, label: it["name"].text ?? it["label"].text)
        }
        for vKey in variables.keys.sorted() {
            if let sysLabel = sysNames[vKey] {
                push(&value, key: vKey, label: sysLabel)
            }
        }
        let nodeItems: [StoryRuleNameItem] = nodes.compactMap { n in
            let id = n["id"].text ?? n["id"].tolerantInteger.map(String.init) ?? ""
            guard !id.isEmpty else { return nil }
            let lbl = (n["label"].text ?? n["name"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return StoryRuleNameItem(key: id, label: lbl.isEmpty ? W8Text.t("未命名站点", "Unnamed station") : lbl)
        }
        return StoryRuleNames(clue: clue, tag: tag, item: item, trait: trait, attr: attr, clock: clock, value: value, node: nodeItems)
    }

    public static func mergeRegistry(_ names: StoryRuleNames, entries: [StoryRuleRegistryEntry]) -> StoryRuleNames {
        var out = names
        let isAttrOrClock: (String) -> Bool = { k in
            out.attr.contains(where: { $0.key == k }) || out.clock.contains(where: { $0.key == k })
        }
        for r in entries {
            let k = r.stateKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = r.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !k.isEmpty, !label.isEmpty else { continue }
            let listName: String?
            if k.hasPrefix("clue.") { listName = "clue" }
            else if k.hasPrefix("tag.") { listName = "tag" }
            else if k.hasPrefix("counter.") && !isAttrOrClock(k) { listName = "value" }
            else { listName = nil }
            guard let listName else { continue }
            var list = out[listName]
            if let idx = list.firstIndex(where: { $0.key == k }) {
                let cur = list[idx]
                list[idx] = StoryRuleNameItem(key: cur.key, label: label, initial: r.initialValue ?? cur.initial, segments: cur.segments)
            } else {
                list.append(StoryRuleNameItem(key: k, label: label, initial: r.initialValue ?? 0, segments: nil))
            }
            out[listName] = list
        }
        return out
    }

    public static func editorVariables(_ variables: [String: Int], names: StoryRuleNames) -> [String: Int] {
        var out = variables
        for a in names.attr where out[a.key] == nil {
            out[a.key] = a.initial ?? 0
        }
        for c in names.clock where out[c.key] == nil {
            out[c.key] = 0
        }
        for v in names.value where out[v.key] == nil {
            out[v.key] = v.initial ?? 0
        }
        return out
    }

    public static func nameOf(_ list: [StoryRuleNameItem], key: String?) -> String {
        guard let key, !key.isEmpty else { return W8Text.t("未命名", "Unnamed") }
        return list.first(where: { $0.key == key })?.label ?? W8Text.t("未命名", "Unnamed")
    }

    public static func varList(_ varKey: String?, names: StoryRuleNames) -> String {
        guard let varKey else { return "value" }
        if names.clock.contains(where: { $0.key == varKey }) { return "clock" }
        if names.attr.contains(where: { $0.key == varKey }) { return "attr" }
        return "value"
    }

    private static func unwrap(_ row: PlayWireValue) -> (neg: Bool, leaf: PlayWireValue) {
        if row["op"].text == "NOT", row["condition"].object != nil, row["condition"]["op"].text != "AND", row["condition"]["op"].text != "OR" {
            return (true, row["condition"])
        }
        return (false, row)
    }

    public static func leafKind(_ row: PlayWireValue, names: StoryRuleNames) -> String {
        let (_, leaf) = unwrap(row)
        let op = leaf["op"].text ?? ""
        switch op {
        case "HAS_TAG":
            return (leaf["value"].text ?? "").hasPrefix("clue.") ? "clue" : "tag"
        case "ITEM_EQUIPPED": return "equip"
        case "HAS_CONDITION": return "trait"
        case "VISIT_COUNT": return "visit"
        case "NODE_COMPLETED": return "done"
        case "CHECK_RESULT": return "check"
        case "GTE", "LTE", "EQ", "NE", "GT", "LT":
            return varList(leaf["var"].text, names: names)
        default:
            return "unsupported"
        }
    }

    public static func effectKind(_ row: PlayWireValue, names: StoryRuleNames) -> String {
        let op = row["op"].text ?? ""
        switch op {
        case "ADD_TAG":
            return (row["value"].text ?? "").hasPrefix("clue.") ? "clue" : "tag"
        case "ADD_ITEM": return "item"
        case "EQUIP": return "equip"
        case "UNEQUIP": return "unequip"
        case "ADD_CONDITION": return "trait"
        case "REMOVE_CONDITION": return "untrait"
        case "TICK_CLOCK": return "clock"
        case "GRANT_XP": return "xp"
        case "GRANT_BADGE": return "badge"
        case "INC", "SET":
            return varList(row["var"].text, names: names) == "attr" ? "attr" : "value"
        default:
            return "unsupported"
        }
    }

    public static func conditionSentence(_ row: PlayWireValue, names: StoryRuleNames) -> String {
        let (neg, leaf) = unwrap(row)
        let kind = leafKind(row, names: names)
        let w = neg ? (negPair[kind]?.1 ?? "") : (negPair[kind]?.0 ?? "")
        let cmp = cmpWord[leaf["cmp"].text ?? leaf["op"].text ?? "GTE"] ?? W8Text.t("至少", "at least")
        let nodeId = leaf["nodeId"].text ?? leaf["nodeKey"].text ?? leaf["nodeId"].tolerantInteger.map(String.init)
        let num = leaf["value"].tolerantInteger ?? 0
        switch kind {
        case "clue": return W8Text.t("\(w)线索 · \(nameOf(names.clue, key: leaf["value"].text))", "\(w) clue · \(nameOf(names.clue, key: leaf["value"].text))")
        case "tag": return W8Text.t("\(w)标签 · \(nameOf(names.tag, key: leaf["value"].text))", "\(w) tag · \(nameOf(names.tag, key: leaf["value"].text))")
        case "equip": return "\(w) · \(nameOf(names.item, key: leaf["itemId"].text))"
        case "trait": return W8Text.t("\(w)特质 · \(nameOf(names.trait, key: leaf["value"].text))", "\(w) trait · \(nameOf(names.trait, key: leaf["value"].text))")
        case "done": return W8Text.t("\(w)节点 · \(nameOf(names.node, key: nodeId))", "\(w) station · \(nameOf(names.node, key: nodeId))")
        case "visit":
            return (neg ? W8Text.t("未到过节点 · ", "Not visited · ") : W8Text.t("到过节点 · ", "Visited · ")) + nameOf(names.node, key: nodeId) + W8Text.t(" \(cmp) \(num) 次", " \(cmp) \(num) times")
        case "check":
            return W8Text.t("检定结果 · \(nameOf(names.node, key: nodeId)) ", "Check result · \(nameOf(names.node, key: nodeId)) ") + (leaf["result"].text == "FAIL" ? W8Text.t("未通过", "Failed") : W8Text.t("通过", "Passed"))
        case "attr":
            return (neg ? W8Text.t("不满足：属性 · ", "Not met: attribute · ") : W8Text.t("属性 · ", "Attribute · ")) + nameOf(names.attr, key: leaf["var"].text) + " \(cmp) \(num)"
        case "clock":
            return (neg ? W8Text.t("不满足：进度钟 · ", "Not met: clock · ") : W8Text.t("进度钟 · ", "Clock · ")) + nameOf(names.clock, key: leaf["var"].text) + W8Text.t(" \(cmp) \(num) 格", " \(cmp) \(num) segments")
        case "value":
            return (neg ? W8Text.t("不满足：数值 · ", "Not met: value · ") : W8Text.t("数值 · ", "Value · ")) + nameOf(names.value + names.attr, key: leaf["var"].text) + " \(cmp) \(num)"
        default:
            return W8Text.t("不再支持的条件", "Unsupported condition")
        }
    }

    public static func effectSentence(_ row: PlayWireValue, names: StoryRuleNames) -> String {
        let kind = effectKind(row, names: names)
        let v = row["value"].tolerantInteger ?? 0
        let sign = row["op"].text == "SET" ? W8Text.t("设为 \(v)", "set to \(v)") : (v < 0 ? "−\(-v)" : "+\(v)")
        switch kind {
        case "clue": return W8Text.t("获得线索 · \(nameOf(names.clue, key: row["value"].text))", "Got clue · \(nameOf(names.clue, key: row["value"].text))")
        case "tag": return W8Text.t("记上标签 · \(nameOf(names.tag, key: row["value"].text))", "Add tag · \(nameOf(names.tag, key: row["value"].text))")
        case "item": return W8Text.t("给物品 · \(nameOf(names.item, key: row["itemId"].text)) ×\(row["quantity"].tolerantInteger ?? 1)", "Give item · \(nameOf(names.item, key: row["itemId"].text)) ×\(row["quantity"].tolerantInteger ?? 1)")
        case "equip": return W8Text.t("穿戴 · \(nameOf(names.item, key: row["itemId"].text))", "Equip · \(nameOf(names.item, key: row["itemId"].text))")
        case "unequip": return W8Text.t("卸下 · \(nameOf(names.item, key: row["itemId"].text))", "Unequip · \(nameOf(names.item, key: row["itemId"].text))")
        case "trait": return W8Text.t("加上特质 · \(nameOf(names.trait, key: row["value"].text))", "Add trait · \(nameOf(names.trait, key: row["value"].text))")
        case "untrait": return W8Text.t("移除特质 · \(nameOf(names.trait, key: row["value"].text))", "Remove trait · \(nameOf(names.trait, key: row["value"].text))")
        case "clock":
            return W8Text.t("进度钟 · \(nameOf(names.clock, key: row["var"].text)) \(v < 0 ? "−\(-v)" : "+\(v)")", "Clock · \(nameOf(names.clock, key: row["var"].text)) \(v < 0 ? "−\(-v)" : "+\(v)")")
        case "attr":
            return W8Text.t("属性 · \(nameOf(names.attr, key: row["var"].text)) \(sign)", "Attribute · \(nameOf(names.attr, key: row["var"].text)) \(sign)")
        case "value":
            return W8Text.t("数值 · \(nameOf(names.value + names.attr, key: row["var"].text)) \(sign)", "Value · \(nameOf(names.value + names.attr, key: row["var"].text)) \(sign)")
        case "xp":
            return W8Text.t("给探索值 +\(row["value"].tolerantInteger ?? 1)", "Give XP +\(row["value"].tolerantInteger ?? 1)")
        case "badge":
            return W8Text.t("授予徽章 · \(nameOf(names.trait, key: row["value"].text))", "Award badge · \(nameOf(names.trait, key: row["value"].text))")
        default:
            return W8Text.t("不再支持的效果", "Unsupported effect")
        }
    }

    private static func pickList(_ kind: String) -> String? {
        (conditionKinds + effectKinds).first(where: { $0.kind == kind })?.names
    }

    private static func nameEditor(_ listName: String?, currentKey: String?, names: StoryRuleNames) -> (names: StoryRuleSegmentedControl?, renameLabel: String?) {
        guard let listName else { return (nil, nil) }
        let items = names[listName]
        if items.count > 1 && items.count <= 4 {
            return (
                StoryRuleSegmentedControl(
                    options: items.map { StoryRuleSegmentOption(label: $0.label, value: $0.key) },
                    value: currentKey ?? ""
                ),
                nil
            )
        }
        return (nil, nameOf(items, key: currentKey))
    }

    public static func conditionEditor(_ row: PlayWireValue, names: StoryRuleNames) -> StoryRuleRowEditor {
        let (neg, leaf) = unwrap(row)
        let kind = leafKind(row, names: names)
        let key: String?
        if kind == "equip" {
            key = leaf["itemId"].text
        } else if ["visit", "done", "check"].contains(kind) {
            key = leaf["nodeId"].text ?? leaf["nodeKey"].text ?? leaf["nodeId"].tolerantInteger.map(String.init)
        } else if ["attr", "clock", "value"].contains(kind) {
            key = leaf["var"].text
        } else {
            key = leaf["value"].text
        }
        let cmpOp = kind == "visit" ? (leaf["cmp"].text ?? "GTE") : (leaf["op"].text ?? "GTE")
        let cmpIdx = max(0, cmpOps.firstIndex(of: cmpOp) ?? 0)
        let nEd = nameEditor(pickList(kind), currentKey: key, names: names)
        let negCtrl: StoryRuleSegmentedControl? = negPair[kind].map { pair in
            StoryRuleSegmentedControl(
                options: [StoryRuleSegmentOption(label: pair.0, value: "0"), StoryRuleSegmentOption(label: pair.1, value: "1")],
                value: neg ? "1" : "0"
            )
        }
        let cmpCtrl: StoryRuleSegmentedControl? = ["visit", "attr", "clock", "value"].contains(kind)
            ? StoryRuleSegmentedControl(
                options: cmpLabels.enumerated().map { StoryRuleSegmentOption(label: $0.element, value: "\($0.offset)") },
                value: "\(cmpIdx)"
            )
            : nil
        let resCtrl: StoryRuleSegmentedControl? = kind == "check"
            ? StoryRuleSegmentedControl(
                options: [StoryRuleSegmentOption(label: W8Text.t("通过", "Passed"), value: "0"), StoryRuleSegmentOption(label: W8Text.t("未通过", "Failed"), value: "1")],
                value: leaf["result"].text == "FAIL" ? "1" : "0"
            )
            : nil
        let amtCtrl: StoryRuleAmountControl? = ["visit", "attr", "clock", "value"].contains(kind)
            ? StoryRuleAmountControl(
                label: kind == "visit" ? W8Text.t("次数", "Times") : (kind == "clock" ? W8Text.t("格数", "Segments") : W8Text.t("数值", "Value")),
                value: leaf["value"].tolerantInteger ?? 1,
                min: 0,
                max: kind == "clock" ? 12 : 99
            )
            : nil
        return StoryRuleRowEditor(
            neg: negCtrl,
            names: nEd.names,
            renameLabel: nEd.renameLabel,
            cmp: cmpCtrl,
            result: resCtrl,
            varOp: nil,
            amount: amtCtrl
        )
    }

    public static func effectEditor(_ row: PlayWireValue, names: StoryRuleNames) -> StoryRuleRowEditor {
        let kind = effectKind(row, names: names)
        let key: String?
        if ["item", "equip", "unequip"].contains(kind) {
            key = row["itemId"].text
        } else if ["clock", "attr", "value"].contains(kind) {
            key = row["var"].text
        } else {
            key = row["value"].text
        }
        let v = row["value"].tolerantInteger ?? 1
        let varOpVal = row["op"].text == "SET" ? "2" : (v < 0 ? "1" : "0")
        let nEd = nameEditor(pickList(kind), currentKey: key, names: names)
        let varOpCtrl: StoryRuleSegmentedControl? = ["attr", "value"].contains(kind)
            ? StoryRuleSegmentedControl(
                options: [
                    StoryRuleSegmentOption(label: W8Text.t("增加", "Increase"), value: "0"),
                    StoryRuleSegmentOption(label: W8Text.t("减少", "Decrease"), value: "1"),
                    StoryRuleSegmentOption(label: W8Text.t("设为", "Set to"), value: "2"),
                ],
                value: varOpVal
            )
            : nil
        let amtCtrl: StoryRuleAmountControl? = ["item", "clock", "attr", "value", "xp"].contains(kind)
            ? StoryRuleAmountControl(
                label: kind == "item" ? W8Text.t("数量", "Quantity") : (kind == "clock" ? W8Text.t("推进格数", "Segments to advance") : W8Text.t("数值", "Value")),
                value: kind == "item" ? (row["quantity"].tolerantInteger ?? 1) : (row["op"].text == "SET" ? v : max(1, abs(v))),
                min: row["op"].text == "SET" ? 0 : 1,
                max: kind == "clock" ? 12 : 99
            )
            : nil
        return StoryRuleRowEditor(
            neg: nil,
            names: nEd.names,
            renameLabel: nEd.renameLabel,
            cmp: nil,
            result: nil,
            varOp: varOpCtrl,
            amount: amtCtrl
        )
    }

    public static func topMode(_ value: PlayWireValue) -> String {
        let conds = value["conditions"].array ?? []
        if conds.count == 1,
           conds[0]["op"].text == "OR",
           let inner = conds[0]["conditions"].array,
           !inner.contains(where: { ["AND", "OR"].contains($0["op"].text ?? "") }) {
            return "OR"
        }
        return "AND"
    }

    public static func conditionRows(
        _ value: PlayWireValue,
        names: StoryRuleNames,
        openPath: String = "",
        openGroups: [String] = []
    ) -> [StoryRuleRow] {
        let mode = topMode(value)
        let conds = value["conditions"].array ?? []
        let list = mode == "OR" ? (conds.first?["conditions"].array ?? []) : conds
        let prefix = mode == "OR" ? "conditions.0.conditions." : "conditions."
        var out: [StoryRuleRow] = []

        func pushLeaf(_ row: PlayWireValue, path: String, depth: Int) {
            let kind = leafKind(row, names: names)
            let isOpen = (openPath == path && kind != "unsupported")
            out.append(StoryRuleRow(
                path: path,
                type: "leaf",
                depth: depth,
                text: conditionSentence(row, names: names),
                open: isOpen,
                unsupported: kind == "unsupported",
                canUp: false,
                mode: nil,
                editor: isOpen ? conditionEditor(row, names: names) : nil
            ))
        }

        for (i, row) in list.enumerated() {
            let path = "\(prefix)\(i)"
            let op = row["op"].text ?? ""
            if op == "AND" || op == "OR" {
                let kids = row["conditions"].array ?? []
                let open = openGroups.contains(path)
                out.append(StoryRuleRow(
                    path: path,
                    type: "group",
                    depth: 0,
                    text: W8Text.t("一组条件 · \(op == "OR" ? "任一满足" : "全部满足") \(kids.count) 条", "Condition group · \(op == "OR" ? "match any" : "match all") · \(kids.count)"),
                    open: open,
                    unsupported: false,
                    canUp: false,
                    mode: op,
                    editor: nil
                ))
                if open {
                    out.append(StoryRuleRow(path: path, type: "groupSeg", depth: 1, text: "", open: false, unsupported: false, canUp: false, mode: op, editor: nil))
                    for (j, c) in kids.enumerated() {
                        pushLeaf(c, path: "\(path).conditions.\(j)", depth: 1)
                    }
                    if kids.count < 10 {
                        out.append(StoryRuleRow(path: path, type: "groupAdd", depth: 1, text: W8Text.t("在这组里加一条", "Add one to this group"), open: false, unsupported: false, canUp: false, mode: nil, editor: nil))
                    }
                    out.append(StoryRuleRow(path: path, type: "groupDel", depth: 1, text: W8Text.t("删除这一组", "Delete this group"), open: false, unsupported: false, canUp: false, mode: nil, editor: nil))
                }
            } else {
                pushLeaf(row, path: path, depth: 0)
            }
        }
        return out
    }

    public static func effectRows(_ value: PlayWireValue, names: StoryRuleNames, openPath: String = "") -> [StoryRuleRow] {
        let effects = value["effects"].array ?? []
        return effects.enumerated().map { i, row in
            let path = "effects.\(i)"
            let kind = effectKind(row, names: names)
            let isOpen = (openPath == path && kind != "unsupported")
            return StoryRuleRow(
                path: path,
                type: "leaf",
                depth: 0,
                text: effectSentence(row, names: names),
                open: isOpen,
                unsupported: kind == "unsupported",
                canUp: i > 0,
                mode: nil,
                editor: isOpen ? effectEditor(row, names: names) : nil
            )
        }
    }

    // MARK: - Path Resolution & Mutations

    private static func getAt(_ root: PlayWireValue, path: String) -> PlayWireValue? {
        let parts = path.split(separator: ".").map(String.init)
        var cur = root
        for part in parts {
            if let idx = Int(part) {
                guard let arr = cur.array, arr.indices.contains(idx) else { return nil }
                cur = arr[idx]
            } else {
                guard let obj = cur.object, let next = obj[part] else { return nil }
                cur = next
            }
        }
        return cur
    }

    private static func setAt(_ root: PlayWireValue, path: String, newValue: PlayWireValue?) -> PlayWireValue {
        let parts = path.split(separator: ".").map(String.init)
        func update(_ current: PlayWireValue, _ slice: ArraySlice<String>) -> PlayWireValue {
            guard let head = slice.first else { return newValue ?? current }
            let tail = slice.dropFirst()
            if let idx = Int(head) {
                var arr = current.array ?? []
                guard arr.indices.contains(idx) else { return current }
                if tail.isEmpty {
                    if let newValue {
                        arr[idx] = newValue
                    } else {
                        arr.remove(at: idx)
                    }
                } else {
                    arr[idx] = update(arr[idx], tail)
                }
                return .array(arr)
            } else {
                var obj = current.object ?? [:]
                if tail.isEmpty {
                    if let newValue {
                        obj[head] = newValue
                    } else {
                        obj.removeValue(forKey: head)
                    }
                } else {
                    obj[head] = update(obj[head] ?? .object([:]), tail)
                }
                return .object(obj)
            }
        }
        return update(root, parts[...])
    }

    public static func newCondition(_ kind: String, key: String, names: StoryRuleNames) -> PlayWireValue {
        let k: String = {
            if !key.isEmpty { return key }
            if let l = pickList(kind), let first = names[l].first { return first.key }
            return ""
        }()
        switch kind {
        case "clue", "tag": return .object(["op": .string("HAS_TAG"), "value": .string(k)])
        case "equip": return .object(["op": .string("ITEM_EQUIPPED"), "itemId": .string(k)])
        case "trait": return .object(["op": .string("HAS_CONDITION"), "value": .string(k)])
        case "visit": return .object(["op": .string("VISIT_COUNT"), "nodeId": .string(k), "cmp": .string("GTE"), "value": .int(1)])
        case "done": return .object(["op": .string("NODE_COMPLETED"), "nodeId": .string(k)])
        case "check": return .object(["op": .string("CHECK_RESULT"), "nodeId": .string(k), "result": .string("PASS")])
        case "attr", "clock", "value": return .object(["op": .string("GTE"), "var": .string(k), "value": .int(1)])
        case "group": return .object(["op": .string("AND"), "conditions": .array([])])
        default: return .object(["op": .string("HAS_CONDITION"), "value": .string(k)])
        }
    }

    public static func newEffect(_ kind: String, key: String, names: StoryRuleNames) -> PlayWireValue {
        let k: String = {
            if !key.isEmpty { return key }
            if let l = pickList(kind), let first = names[l].first { return first.key }
            return ""
        }()
        let clock = names.clock.first(where: { $0.key == k })
        switch kind {
        case "clue", "tag": return .object(["op": .string("ADD_TAG"), "value": .string(k)])
        case "item": return .object(["op": .string("ADD_ITEM"), "itemId": .string(k), "quantity": .int(1)])
        case "equip": return .object(["op": .string("EQUIP"), "itemId": .string(k)])
        case "unequip": return .object(["op": .string("UNEQUIP"), "itemId": .string(k)])
        case "trait": return .object(["op": .string("ADD_CONDITION"), "value": .string(k)])
        case "untrait": return .object(["op": .string("REMOVE_CONDITION"), "value": .string(k)])
        case "clock": return .object(["op": .string("TICK_CLOCK"), "var": .string(k), "value": .int(1), "max": .int(clock?.segments ?? 6)])
        case "attr", "value": return .object(["op": .string("INC"), "var": .string(k), "value": .int(1)])
        case "xp": return .object(["op": .string("GRANT_XP"), "value": .int(1)])
        case "badge": return .object(["op": .string("GRANT_BADGE"), "value": .string(k)])
        default: return .object(["op": .string("ADD_CONDITION"), "value": .string(k)])
        }
    }

    public static func add(
        _ value: PlayWireValue,
        target: String,
        kind: String,
        key: String,
        names: StoryRuleNames
    ) -> (value: PlayWireValue, path: String) {
        var out = value.object != nil ? value : .object(["conditions": .array([]), "effects": .array([])])
        if target == "effects" {
            var effs = out["effects"].array ?? []
            let newItem = newEffect(kind, key: key, names: names)
            let path = "effects.\(effs.count)"
            effs.append(newItem)
            out = setAt(out, path: "effects", newValue: .array(effs))
            return (out, path)
        }
        let item = newCondition(kind, key: key, names: names)
        if target == "conditions" {
            if topMode(out) == "OR" {
                var inner = out["conditions"].array?.first?["conditions"].array ?? []
                let path = "conditions.0.conditions.\(inner.count)"
                inner.append(item)
                out = setAt(out, path: "conditions.0.conditions", newValue: .array(inner))
                return (out, path)
            }
            var conds = out["conditions"].array ?? []
            let path = "conditions.\(conds.count)"
            conds.append(item)
            out = setAt(out, path: "conditions", newValue: .array(conds))
            return (out, path)
        }
        guard let group = getAt(out, path: target),
              ["AND", "OR"].contains(group["op"].text ?? "") else {
            return (out, "")
        }
        var kids = group["conditions"].array ?? []
        let path = "\(target).conditions.\(kids.count)"
        kids.append(item)
        out = setAt(out, path: "\(target).conditions", newValue: .array(kids))
        return (out, path)
    }

    public static func remove(_ value: PlayWireValue, path: String) -> PlayWireValue {
        var out = setAt(value, path: path, newValue: nil)
        let conds = out["conditions"].array ?? []
        if conds.count == 1,
           conds[0]["op"].text == "OR",
           (conds[0]["conditions"].array ?? []).isEmpty {
            out = setAt(out, path: "conditions", newValue: .array([]))
        }
        return out
    }

    public static func setTopMode(_ value: PlayWireValue, mode: String) -> PlayWireValue {
        var out = value
        let cur = topMode(out)
        guard cur != mode else { return out }
        if mode == "OR" {
            let conds = out["conditions"].array ?? []
            out = setAt(out, path: "conditions", newValue: .array([.object(["op": .string("OR"), "conditions": .array(conds)])]))
        } else {
            let inner = out["conditions"].array?.first?["conditions"].array ?? []
            out = setAt(out, path: "conditions", newValue: .array(inner))
        }
        return out
    }

    public static func setGroupMode(_ value: PlayWireValue, path: String, mode: String) -> PlayWireValue {
        guard let row = getAt(value, path: path), ["AND", "OR"].contains(row["op"].text ?? "") else { return value }
        var obj = row.object ?? [:]
        obj["op"] = .string(mode == "OR" ? "OR" : "AND")
        return setAt(value, path: path, newValue: .object(obj))
    }

    public static func setNegated(_ value: PlayWireValue, path: String, negated: Bool) -> PlayWireValue {
        guard let current = getAt(value, path: path) else { return value }
        let (_, leaf) = unwrap(current)
        let next: PlayWireValue = negated ? .object(["op": .string("NOT"), "condition": leaf]) : leaf
        return setAt(value, path: path, newValue: next)
    }

    private static func mutateLeaf(_ value: PlayWireValue, path: String, fn: (inout [String: PlayWireValue]) -> Void) -> PlayWireValue {
        guard let current = getAt(value, path: path) else { return value }
        let (neg, leaf) = unwrap(current)
        var obj = leaf.object ?? [:]
        fn(&obj)
        let updatedLeaf = PlayWireValue.object(obj)
        let next: PlayWireValue = neg ? .object(["op": .string("NOT"), "condition": updatedLeaf]) : updatedLeaf
        return setAt(value, path: path, newValue: next)
    }

    public static func setKey(_ value: PlayWireValue, path: String, key: String, names: StoryRuleNames? = nil) -> PlayWireValue {
        if path.hasPrefix("effects.") {
            guard let row = getAt(value, path: path) else { return value }
            var obj = row.object ?? [:]
            let op = obj["op"]?.text ?? ""
            if ["ADD_ITEM", "EQUIP", "UNEQUIP"].contains(op) {
                obj["itemId"] = .string(key)
            } else if ["TICK_CLOCK", "INC", "SET"].contains(op) {
                obj["var"] = .string(key)
                if op == "TICK_CLOCK", let seg = names?.clock.first(where: { $0.key == key })?.segments {
                    obj["max"] = .int(seg)
                }
            } else {
                obj["value"] = .string(key)
            }
            return setAt(value, path: path, newValue: .object(obj))
        }
        return mutateLeaf(value, path: path) { leaf in
            let op = leaf["op"]?.text ?? ""
            if op == "ITEM_EQUIPPED" {
                leaf["itemId"] = .string(key)
            } else if ["VISIT_COUNT", "NODE_COMPLETED", "CHECK_RESULT"].contains(op) {
                leaf["nodeId"] = .string(key)
                leaf.removeValue(forKey: "nodeKey")
            } else if ["GTE", "LTE", "EQ", "NE", "GT", "LT"].contains(op) {
                leaf["var"] = .string(key)
            } else {
                leaf["value"] = .string(key)
            }
        }
    }

    public static func setCompare(_ value: PlayWireValue, path: String, cmpIndex: String) -> PlayWireValue {
        let idx = Int(cmpIndex) ?? 0
        let op = cmpOps.indices.contains(idx) ? cmpOps[idx] : "GTE"
        return mutateLeaf(value, path: path) { leaf in
            if leaf["op"]?.text == "VISIT_COUNT" {
                leaf["cmp"] = .string(op)
            } else {
                leaf["op"] = .string(op)
            }
        }
    }

    public static func setResult(_ value: PlayWireValue, path: String, resultIndex: String) -> PlayWireValue {
        return mutateLeaf(value, path: path) { leaf in
            leaf["result"] = .string(resultIndex == "1" ? "FAIL" : "PASS")
        }
    }

    public static func setAmount(_ value: PlayWireValue, path: String, amount: Int) -> PlayWireValue {
        let n = max(0, min(99, amount))
        if path.hasPrefix("effects.") {
            guard let row = getAt(value, path: path) else { return value }
            var obj = row.object ?? [:]
            let op = obj["op"]?.text ?? ""
            if op == "ADD_ITEM" {
                obj["quantity"] = .int(max(1, n))
            } else if op == "INC" && (obj["value"]?.tolerantInteger ?? 1) < 0 {
                obj["value"] = .int(-max(1, n))
            } else {
                obj["value"] = .int(op == "SET" ? n : max(1, n))
            }
            return setAt(value, path: path, newValue: .object(obj))
        }
        return mutateLeaf(value, path: path) { leaf in
            leaf["value"] = .int(n)
        }
    }

    public static func setVarOp(_ value: PlayWireValue, path: String, opIndex: String) -> PlayWireValue {
        guard let row = getAt(value, path: path) else { return value }
        var obj = row.object ?? [:]
        let mag = max(1, abs(obj["value"]?.tolerantInteger ?? 1))
        if opIndex == "2" {
            obj["op"] = .string("SET")
            obj["value"] = .int(abs(obj["value"]?.tolerantInteger ?? 0))
        } else {
            obj["op"] = .string("INC")
            obj["value"] = .int(opIndex == "1" ? -mag : mag)
        }
        return setAt(value, path: path, newValue: .object(obj))
    }

    public static func move(_ value: PlayWireValue, path: String, delta: Int) -> PlayWireValue {
        let parts = path.split(separator: ".").map(String.init)
        guard let last = parts.last, let i = Int(last) else { return value }
        let parentPath = parts.dropLast().joined(separator: ".")
        guard var arr = getAt(value, path: parentPath)?.array else { return value }
        let j = i + delta
        guard arr.indices.contains(i), arr.indices.contains(j) else { return value }
        arr.swapAt(i, j)
        return setAt(value, path: parentPath, newValue: .array(arr))
    }

    public static func namesListFor(_ value: PlayWireValue, path: String, names: StoryRuleNames) -> String? {
        guard let row = getAt(value, path: path) else { return nil }
        let kind = path.hasPrefix("effects.") ? effectKind(row, names: names) : leafKind(row, names: names)
        return pickList(kind)
    }

    /// Validates rule draft against known nodes and variables (`story-rule-form.js` `errors`).
    public static func validateErrors(_ value: PlayWireValue, nodeIds: Set<String>, variables: [String: Int]) -> [String] {
        var issues: [String] = []
        func checkCondition(_ row: PlayWireValue, depth: Int) {
            if depth > 3 {
                issues.append(W8Text.t("条件组合最多嵌套3层", "Condition groups can nest at most 3 levels"))
                return
            }
            let op = row["op"].text ?? ""
            switch op {
            case "AND", "OR":
                let kids = row["conditions"].array ?? []
                if kids.isEmpty { issues.append(W8Text.t("条件组不能为空", "A condition group cannot be empty")) }
                for k in kids { checkCondition(k, depth: depth + 1) }
            case "NOT":
                if row["condition"].object == nil { issues.append(W8Text.t("否定条件缺少子条件", "A negated condition needs a sub-condition")) }
                else { checkCondition(row["condition"], depth: depth + 1) }
            case "HAS_TAG", "HAS_CONDITION":
                if (row["value"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(W8Text.t("条件缺少名称", "Condition is missing a name"))
                }
            case "ITEM_EQUIPPED":
                if (row["itemId"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(W8Text.t("装备条件缺少物品", "Equip condition is missing an item"))
                }
            case "VISIT_COUNT", "NODE_COMPLETED", "CHECK_RESULT":
                let nId = row["nodeId"].text ?? row["nodeKey"].text ?? row["nodeId"].tolerantInteger.map(String.init) ?? ""
                if nId.isEmpty || (!nodeIds.isEmpty && !nodeIds.contains(nId)) {
                    issues.append(W8Text.t("节点条件未选择有效站点", "Station condition has no valid station"))
                }
            case "GTE", "LTE", "EQ", "NE", "GT", "LT":
                let v = row["var"].text ?? ""
                if v.isEmpty || (!variables.isEmpty && variables[v] == nil) {
                    issues.append(W8Text.t("数值条件未选择有效变量", "Value condition has no valid variable"))
                }
            default:
                issues.append(W8Text.t("不支持的条件：\(op)", "Unsupported condition: \(op)"))
            }
        }
        for c in value["conditions"].array ?? [] { checkCondition(c, depth: 0) }
        for e in value["effects"].array ?? [] {
            let op = e["op"].text ?? ""
            switch op {
            case "ADD_TAG", "ADD_CONDITION", "REMOVE_CONDITION", "GRANT_BADGE":
                if (e["value"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(W8Text.t("效果缺少目标名称", "Effect is missing a target name"))
                }
            case "ADD_ITEM", "EQUIP", "UNEQUIP":
                if (e["itemId"].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(W8Text.t("物品效果缺少物品代码", "Item effect is missing an item code"))
                }
            case "TICK_CLOCK", "INC", "SET":
                let v = e["var"].text ?? ""
                if v.isEmpty || (!variables.isEmpty && variables[v] == nil) {
                    issues.append(W8Text.t("数值效果未选择有效变量", "Value effect has no valid variable"))
                }
            case "GRANT_XP":
                if (e["value"].tolerantInteger ?? 0) <= 0 {
                    issues.append(W8Text.t("探索值必须大于 0", "XP must be greater than 0"))
                }
            default:
                issues.append(W8Text.t("不支持的效果：\(op)", "Unsupported effect: \(op)"))
            }
        }
        return issues
    }
}

// MARK: - Story Rule Editor Interactive Model (Ported from pages/publish/components/story-rule-editor/index.js)

public struct StoryRuleLayerRow: Equatable, Identifiable, Sendable {
    public var id: String { kind.isEmpty ? "rename" : kind }
    public let kind: String
    public let label: String
    public let open: Bool
    public let hasNames: Bool
    public let names: [StoryRuleNameItem]
}

public struct StoryRuleLayerState: Equatable, Sendable {
    public let mode: String // "add" | "rename"
    public let target: String
    public let path: String
    public let list: String
    public var kind: String
    public let title: String
}

public struct StoryRuleCreateRequest: Equatable, Sendable {
    public let identity: String
    public let kind: String
    public let label: String
}

@available(macOS 14.0, *)
@MainActor @Observable public final class StoryRuleEditorModel {
    public static let newKey = ":new"
    public static let creatableLists: Set<String> = ["clue", "tag"]

    public let identity: String
    public var readOnly: Bool
    public var names: StoryRuleNames {
        didSet {
            guard active else { return }
            refresh()
            if layer != nil { layerRows = computeLayerRows() }
        }
    }
    public var variables: [String: Int] {
        didSet {
            guard active else { return }
            refresh()
        }
    }
    public var nodeIds: Set<String>

    public private(set) var draft: PlayWireValue
    public private(set) var conditionRows: [StoryRuleRow] = []
    public private(set) var effectRows: [StoryRuleRow] = []
    public private(set) var showTopSeg: Bool = false
    public private(set) var topSegValue: String = "AND"
    public private(set) var error: String = ""
    public private(set) var sorting: Bool = false
    public private(set) var layer: StoryRuleLayerState?
    public private(set) var layerRows: [StoryRuleLayerRow] = []
    public private(set) var query: String = ""

    public private(set) var changeEvents: [PlayWireValue] = []
    public private(set) var createRequests: [StoryRuleCreateRequest] = []
    public private(set) var layerEvents: [(open: Bool, title: String)] = []

    private var active: Bool = true
    private var openPath: String = ""
    private var openGroups: [String] = []
    private var creating: Bool = false

    public init(
        value: PlayWireValue = .object(["conditions": .array([]), "effects": .array([])]),
        names: StoryRuleNames = StoryRuleNames(),
        variables: [String: Int] = [:],
        nodeIds: Set<String> = [],
        identity: String = "",
        readOnly: Bool = false
    ) {
        self.draft = value.object != nil ? value : .object(["conditions": .array([]), "effects": .array([])])
        self.names = names
        self.variables = variables
        self.nodeIds = nodeIds
        self.identity = identity
        self.readOnly = readOnly
        refresh()
    }

    public func detach() {
        active = false
    }

    public func refresh() {
        guard active else { return }
        let issues = StoryRuleSentenceEngine.validateErrors(draft, nodeIds: nodeIds, variables: variables)
        let mode = StoryRuleSentenceEngine.topMode(draft)
        let cRows = StoryRuleSentenceEngine.conditionRows(draft, names: names, openPath: openPath, openGroups: openGroups)
        let topCount = cRows.filter { $0.depth == 0 }.count
        conditionRows = cRows
        effectRows = StoryRuleSentenceEngine.effectRows(draft, names: names, openPath: openPath)
        showTopSeg = topCount > 1 || mode == "OR"
        topSegValue = mode
        error = issues.isEmpty ? "" : W8Text.t("有一句还没选完，请补全或删除", "One sentence is incomplete. Complete or delete it.")
    }

    private func edit(_ transform: (PlayWireValue) -> PlayWireValue) {
        guard active, !readOnly else { return }
        draft = transform(draft)
        refresh()
        changeEvents.append(draft)
    }

    public func toggleRow(path: String, type: String = "leaf") {
        if sorting && type == "leaf" && path.hasPrefix("effects.") { return }
        if type == "group" {
            if let idx = openGroups.firstIndex(of: path) {
                openGroups.remove(at: idx)
            } else {
                openGroups.append(path)
            }
        } else {
            openPath = (openPath == path) ? "" : path
        }
        refresh()
    }

    public func toggleSort() {
        sorting.toggle()
    }

    public func onTopMode(_ mode: String) {
        edit { StoryRuleSentenceEngine.setTopMode($0, mode: mode) }
    }

    public func onGroupMode(path: String, mode: String) {
        edit { StoryRuleSentenceEngine.setGroupMode($0, path: path, mode: mode) }
    }

    public func onNegate(path: String, value: String) {
        edit { StoryRuleSentenceEngine.setNegated($0, path: path, negated: value == "1") }
    }

    public func onPickName(path: String, key: String) {
        let currentNames = names
        edit { StoryRuleSentenceEngine.setKey($0, path: path, key: key, names: currentNames) }
    }

    public func onCompare(path: String, cmpIndex: String) {
        edit { StoryRuleSentenceEngine.setCompare($0, path: path, cmpIndex: cmpIndex) }
    }

    public func onResult(path: String, resultIndex: String) {
        edit { StoryRuleSentenceEngine.setResult($0, path: path, resultIndex: resultIndex) }
    }

    public func onVarOp(path: String, opIndex: String) {
        edit { StoryRuleSentenceEngine.setVarOp($0, path: path, opIndex: opIndex) }
    }

    public func onAmount(path: String, amount: Int) {
        edit { StoryRuleSentenceEngine.setAmount($0, path: path, amount: amount) }
    }

    public func onMoveUp(path: String) {
        edit { StoryRuleSentenceEngine.move($0, path: path, delta: -1) }
    }

    public func onRemove(path: String) {
        guard active, !readOnly else { return }
        openPath = ""
        openGroups = []
        edit { StoryRuleSentenceEngine.remove($0, path: path) }
    }

    // MARK: - Layer (Add / Rename / Inline Create)

    public func openAdd(target: String) {
        guard !readOnly else { return }
        setLayer(StoryRuleLayerState(
            mode: "add",
            target: target,
            path: "",
            list: "",
            kind: "",
            title: target == "effects" ? W8Text.t("添加效果", "Add effect") : W8Text.t("添加条件", "Add condition")
        ))
    }

    public func openRename(path: String) {
        guard let list = StoryRuleSentenceEngine.namesListFor(draft, path: path, names: names) else { return }
        setLayer(StoryRuleLayerState(
            mode: "rename",
            target: "",
            path: path,
            list: list,
            kind: "",
            title: W8Text.t("换一个名字", "Rename")
        ))
    }

    public func closeLayer() {
        if layer != nil { setLayer(nil) }
    }

    public func onLayerKind(_ kind: String) {
        guard var currentLayer = layer else { return }
        let defs = currentLayer.target == "effects" ? StoryRuleSentenceEngine.effectKinds : StoryRuleSentenceEngine.conditionKinds
        guard let def = defs.first(where: { $0.kind == kind }) else { return }
        if def.names == nil {
            commitAdd(kind: kind, key: "")
            return
        }
        currentLayer.kind = (currentLayer.kind == kind) ? "" : kind
        layer = currentLayer
        query = ""
        layerRows = computeLayerRows()
    }

    public func onLayerQuery(_ q: String) {
        query = q
        layerRows = computeLayerRows()
    }

    public func onLayerName(_ key: String) {
        guard let currentLayer = layer else { return }
        if currentLayer.mode == "rename" {
            let currentNames = names
            edit { StoryRuleSentenceEngine.setKey($0, path: currentLayer.path, key: key, names: currentNames) }
            setLayer(nil)
            return
        }
        if key == Self.newKey {
            let defs = currentLayer.target == "effects" ? StoryRuleSentenceEngine.effectKinds : StoryRuleSentenceEngine.conditionKinds
            guard let def = defs.first(where: { $0.kind == currentLayer.kind }),
                  let listName = def.names,
                  !creating else { return }
            creating = true
            createRequests.append(StoryRuleCreateRequest(
                identity: identity,
                kind: listName,
                label: query.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
            return
        }
        commitAdd(kind: currentLayer.kind, key: key)
    }

    public func created(_ key: String?) {
        creating = false
        if let key, !key.isEmpty, let currentLayer = layer, currentLayer.mode == "add" {
            commitAdd(kind: currentLayer.kind, key: key)
        }
    }

    private func commitAdd(kind: String, key: String) {
        guard let currentLayer = layer else { return }
        let currentNames = names
        var addedPath = ""
        edit { v in
            let res = StoryRuleSentenceEngine.add(v, target: currentLayer.target, kind: kind, key: key, names: currentNames)
            addedPath = res.path
            return res.value
        }
        if !addedPath.isEmpty {
            if kind == "group" {
                openGroups.append(addedPath)
            } else {
                openPath = addedPath
            }
            refresh()
        }
        setLayer(nil)
    }

    private func setLayer(_ next: StoryRuleLayerState?) {
        layer = next
        query = ""
        layerRows = computeLayerRows()
        layerEvents.append((open: next != nil, title: next?.title ?? ""))
    }

    private func computeLayerRows() -> [StoryRuleLayerRow] {
        guard let currentLayer = layer else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        func pick(_ listName: String) -> [StoryRuleNameItem] {
            names[listName].filter { q.isEmpty || $0.label.contains(q) }
        }
        if currentLayer.mode == "rename" {
            return [
                StoryRuleLayerRow(
                    kind: "",
                    label: "",
                    open: true,
                    hasNames: true,
                    names: pick(currentLayer.list)
                )
            ]
        }
        let kinds = currentLayer.target == "effects" ? StoryRuleSentenceEngine.effectKinds : StoryRuleSentenceEngine.conditionKinds
        return kinds
            .filter { $0.kind != "group" || currentLayer.target == "conditions" }
            .map { k in
                let isOpen = (currentLayer.kind == k.kind)
                var rows = (isOpen && k.names != nil) ? pick(k.names!) : []
                if isOpen, let listName = k.names,
                   Self.creatableLists.contains(listName),
                   !q.isEmpty,
                   !names[listName].contains(where: { $0.label == q }) {
                    rows.insert(StoryRuleNameItem(key: Self.newKey, label: W8Text.t("新建「\(q)」", "Create “\(q)”")), at: 0)
                }
                return StoryRuleLayerRow(
                    kind: k.kind,
                    label: k.label,
                    open: isOpen,
                    hasNames: k.names != nil,
                    names: rows
                )
            }
    }
}
