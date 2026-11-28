import Foundation
import Observation

// MARK: - Theme Gameplay Presentation & Rules (Ported from pages/play/utils/theme-gameplay.js)

public struct PlayThemeStatLabels: Equatable, Sendable {
    public let hp: String
    public let luck: String
    public let action: String

    public init(hp: String = W8Text.t("生命值", "Health"), luck: String = W8Text.t("幸运值", "Luck"), action: String = W8Text.t("行动次数", "Actions")) {
        self.hp = hp
        self.luck = luck
        self.action = action
    }
}

public struct PlayThemeCostOptionRow: Equatable, Identifiable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let label: String
    public let amountText: String
    public let affordable: Bool
    public let shortfallText: String
}

public struct PlayThemeParticipantRow: Equatable, Identifiable, Sendable {
    public var id: String { "\(memberId)" }
    public let memberId: Int
    public let name: String
    public let roleName: String
    public let checked: Bool
}

public struct PlayThemeParticipantChoice: Equatable, Sendable {
    public let actionRow: PlayThemeGameplayActionRow
    public let minCount: Int
    public let maxCount: Int
    public let countText: String
    public var selectedIds: [Int]
    public var rows: [PlayThemeParticipantRow]
}

public struct PlayThemeQuestChoiceItem: Equatable, Identifiable, Sendable {
    public var id: String { choiceKey }
    public let choiceKey: String
    public let label: String
    public let description: String
    public let costText: String
    public let enabled: Bool
}

public struct PlayThemeGameplayActionRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: String // "QUEST" | "FACILITY" | "RECOVERY"
    public let contentId: String
    public let operationKind: String?
    public let operationKey: String?
    public let title: String
    public let statusText: String
    public let costText: String
    public let costOptions: [PlayThemeCostOptionRow]
    public let frozenIndex: Int
    public let nodeId: Int?
    public let choices: [PlayThemeQuestChoiceItem]
    public let operation: String
    public let actionLabel: String
    public let enabled: Bool
    public let cancelable: Bool
    public let minParticipants: Int
    public let maxParticipants: Int
    public let requiredRoles: [String]
}

public struct PlayThemeRouteNodeRef: Equatable, Sendable {
    public let nodeId: Int
    public let name: String

    public init(nodeId: Int, name: String) {
        self.nodeId = nodeId
        self.name = name
    }
}

public enum PlayThemeGameplayRules {
    public static func labels(_ view: PlayWireValue) -> PlayThemeStatLabels {
        let hp = (view["hpName"].text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? W8Text.t("生命值", "Health")
        let luck = (view["luckName"].text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? W8Text.t("幸运值", "Luck")
        let action = (view["actionName"].text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? W8Text.t("行动次数", "Actions")
        return PlayThemeStatLabels(hp: hp, luck: luck, action: action)
    }

    public static func valueName(_ key: String?, view: PlayWireValue = .object([:])) -> String {
        let name = labels(view)
        guard let key, !key.isEmpty else { return "" }
        if key == "HP" || key == "sys.hp" { return name.hp }
        if key == "LUCK" || key == "sys.luck" { return name.luck }
        if key == "ACTIONS" || key == "sys.actions" { return name.action }
        if let attr = (view["attributes"].array ?? []).first(where: { $0["key"].text == key }),
           let label = attr["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        let catalog = view["world"]["itemCatalog"].array ?? view["itemCatalog"].array ?? []
        let items = catalog + (view["contents"].array ?? [])
        if let item = items.first(where: { $0["id"].text == key }),
           let itemName = item["name"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !itemName.isEmpty {
            return itemName
        }
        return key.hasPrefix("counter.") ? W8Text.t("数值", "Value") : W8Text.t("物资", "Supplies")
    }

    public static func amounts(_ source: PlayWireValue, view: PlayWireValue) -> [String] {
        guard source.object != nil else { return [] }
        let name = labels(view)
        var parts: [String] = []
        if let hpCost = source["hpCost"].tolerantInteger, hpCost > 0 {
            parts.append("\(name.hp) \(hpCost)")
        }
        if let luckCost = source["luckCost"].tolerantInteger, luckCost > 0 {
            parts.append("\(name.luck) \(luckCost)")
        }
        if let actionCost = source["actionCost"].tolerantInteger, actionCost > 0 {
            parts.append("\(name.action) \(actionCost)")
        }
        for row in source["statCosts"].array ?? [] {
            let amount = row["amount"].tolerantInteger ?? row["value"].tolerantInteger ?? 0
            if amount > 0 {
                parts.append("\(valueName(row["statKey"].text ?? row["key"].text, view: view)) \(amount)")
            }
        }
        for row in source["resourceCosts"].array ?? [] {
            let qty = row["quantity"].tolerantInteger ?? 0
            if qty > 0 {
                parts.append("\(valueName(row["itemId"].text, view: view)) ×\(qty)")
            }
        }
        return parts
    }

    public static func hasFees(_ costs: PlayWireValue) -> Bool {
        guard costs.object != nil else { return false }
        if (costs["hpCost"].tolerantInteger ?? 0) > 0 { return true }
        if (costs["luckCost"].tolerantInteger ?? 0) > 0 { return true }
        if (costs["actionCost"].tolerantInteger ?? 0) > 0 { return true }
        if (costs["statCosts"].array ?? []).contains(where: { ($0["amount"].tolerantInteger ?? $0["value"].tolerantInteger ?? 0) > 0 }) { return true }
        if (costs["resourceCosts"].array ?? []).contains(where: { ($0["quantity"].tolerantInteger ?? 0) > 0 }) { return true }
        return false
    }

    public static func shortfallText(_ option: PlayWireValue, view: PlayWireValue) -> String {
        if option["affordable"].bool == true { return "" }
        guard let shortfall = option["shortfall"].array else { return W8Text.t("费用不足", "Insufficient cost") }
        let items = shortfall.compactMap { row -> String? in
            guard let missing = row["missing"].tolerantInteger, missing > 0 else { return nil }
            let k = row["key"].text
            let label = (row["type"].text == "ITEM" && k == nil) ? W8Text.t("物资", "Supplies") : (valueName(k, view: view).isEmpty ? W8Text.t("数值", "Value") : valueName(k, view: view))
            return W8Text.t("缺少\(label) \(missing)", "Missing \(label) \(missing)")
        }
        return items.isEmpty ? W8Text.t("费用不足", "Insufficient cost") : items.joined(separator: " · ")
    }

    public static func options(_ raw: PlayWireValue, view: PlayWireValue) -> [PlayThemeCostOptionRow] {
        guard let list = raw.array else { return [] }
        return list.enumerated().map { index, row in
            let affordable = row["affordable"].bool == true
            let lbl = (row["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? W8Text.t("方案 \(index + 1)", "Option \(index + 1)")
            let amt = amounts(row, view: view).joined(separator: " · ")
            return PlayThemeCostOptionRow(
                index: index,
                label: lbl,
                amountText: amt.isEmpty ? W8Text.t("免费", "Free") : amt,
                affordable: affordable,
                shortfallText: shortfallText(row, view: view)
            )
        }
    }

    public static func toolStatus(_ row: PlayWireValue, view: PlayWireValue, activeOp: Bool = false) -> String {
        var parts: [String] = []
        if activeOp { parts.append(W8Text.t("操作题进行中", "Operation in progress")) }
        let payer = row["payerPolicy"].text
        if payer == "FIRST_TEAM_ONCE" { parts.append(W8Text.t("仅首队支付一次", "Paid once by the first team")) }
        else if payer == "FIRST_PLAYER_ONCE" { parts.append(W8Text.t("仅首人支付一次", "Paid once by the first player")) }
        if row["paidByOwnerId"] != .null || row["paidByTeamId"] != .null { parts.append(W8Text.t("已由先行者支付", "Already paid by an earlier player")) }
        if let rem = row["remaining"].tolerantInteger, rem >= 0 { parts.append(W8Text.t("剩余 \(rem) 次", "\(rem) left")) }
        else if let rem = row["remainingUses"].tolerantInteger, rem >= 0 { parts.append(W8Text.t("剩余 \(rem) 次", "\(rem) left")) }
        if let reason = row["disabledReason"].text, !reason.isEmpty {
            let reasonMap: [String: String] = [
                "COOLDOWN": W8Text.t("冷却中", "Cooling down"),
                "LIMIT_REACHED": W8Text.t("次数已用尽", "No uses left"),
                "PREREQ": W8Text.t("前置条件未满足", "Prerequisites not met"),
                "COST": W8Text.t("费用不足", "Insufficient cost"),
                "FULL_HP": W8Text.t("\(labels(view).hp)已满", "\(labels(view).hp) is full"),
            ]
            parts.append(reasonMap[reason] ?? reason)
        }
        return parts.joined(separator: " · ")
    }

    public static func actionRows(_ view: PlayWireValue, nodes: [PlayThemeRouteNodeRef] = []) -> [PlayThemeGameplayActionRow] {
        let team = view["scope"].text == "TEAM"
        let availableActions = Set((view["availableActions"].array ?? []).compactMap(\.text))
        let allowedList = view["allowedActions"].array ?? []
        let awaitingChallenge = view["awaitingChallenge"].bool == true
        let activeOperation = view["activeOperation"]

        func allowed(_ op: String, _ id: String) -> PlayWireValue? {
            allowedList.first { $0["operation"].text == op && $0["contentId"].text == id }
        }

        func canUse(_ row: PlayWireValue, _ op: String, _ id: String) -> Bool {
            let rule = allowed(op, id)
            let isFree = !hasFees(rule?["costs"] ?? row["costs"]) && (rule?["costOptions"].array ?? row["costOptions"].array ?? []).isEmpty
            let baseAllowed = team ? availableActions.contains(op) : (rule != nil)
            return baseAllowed && (!awaitingChallenge || isFree)
        }

        func costState(_ row: PlayWireValue, _ rule: PlayWireValue?, _ frozen: Int?) -> (costText: String, costOptions: [PlayThemeCostOptionRow], frozenIndex: Int, hasAffordableOption: Bool) {
            let mergedOptions: PlayWireValue
            if let ruleOpts = rule?["costOptions"].array, !ruleOpts.isEmpty {
                let baseCosts = rule?["costs"].object ?? [:]
                mergedOptions = .array(ruleOpts.map { opt in
                    var obj = baseCosts
                    for (k, v) in opt.object ?? [:] { obj[k] = v }
                    return .object(obj)
                })
            } else {
                mergedOptions = row["costOptions"]
            }
            let opts = options(mergedOptions, view: view)
            let fixed = amounts(rule?["costs"].object != nil ? rule!["costs"] : (row["costs"].object != nil ? row["costs"] : row), view: view).joined(separator: " · ")
            let frozenIdx: Int
            if let frozen, opts.indices.contains(frozen) {
                frozenIdx = frozen
            } else {
                frozenIdx = -1
            }
            let costText: String
            if frozenIdx >= 0 {
                costText = W8Text.t("已选 \(opts[frozenIdx].label)：\(opts[frozenIdx].amountText)", "Chosen \(opts[frozenIdx].label): \(opts[frozenIdx].amountText)")
            } else if !opts.isEmpty {
                costText = [fixed, opts.map { "\($0.label)：\($0.amountText)" }.joined(separator: " / ")]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
            } else {
                costText = fixed
            }
            let hasAffordable = opts.isEmpty || opts.contains(where: \.affordable)
            return (costText, opts, frozenIdx, hasAffordable)
        }

        let quests: [PlayThemeGameplayActionRow] = (view["quests"].array ?? []).enumerated().compactMap { idx, q in
            let id = q["questKey"].text ?? q["id"].text ?? "quest_\(idx)"
            let start = allowed("QUEST_START", id)
            let resolve = allowed("QUEST_RESOLVE", id)
            let cancel = allowed("QUEST_CANCEL", id)
            let active = view["activeQuest"].text == id || q["status"].text == "ACTIVE"
            let done = q["status"].text == "COMPLETED" || q["completed"].bool == true
            let frozen = active ? (q["selectedCostOption"].tolerantInteger ?? view["activeQuestCostOption"].tolerantInteger) : nil
            let cost = costState(q, start ?? resolve, frozen)
            let nodeId = q["nodeId"].tolerantInteger
            let canOpen = active && resolve == nil && (!team || !availableActions.contains("QUEST_RESOLVE") || q["verified"].bool == false)
                && (nodeId != nil || cancel != nil || availableActions.contains("QUEST_CANCEL"))
            let op = active ? (canOpen ? "OPEN_QUEST" : "QUEST_RESOLVE") : "QUEST_START"
            let nodeName = nodes.first(where: { $0.nodeId == nodeId })?.name ?? q["title"].text ?? q["name"].text ?? W8Text.t("支线 \(id)", "Side quest \(id)")
            let choices: [PlayThemeQuestChoiceItem] = (q["choices"].array ?? []).map { choice in
                let cKey = choice["choiceKey"].text ?? choice["id"].text ?? ""
                let cLabel = choice["label"].text ?? choice["title"].text ?? (cKey.isEmpty ? W8Text.t("选项", "Option") : cKey)
                let cDesc = choice["description"].text ?? ""
                let cCost = amounts(choice["costs"].object != nil ? choice["costs"] : choice, view: view).joined(separator: " · ")
                return PlayThemeQuestChoiceItem(
                    choiceKey: cKey,
                    label: cLabel,
                    description: cDesc,
                    costText: cCost,
                    enabled: choice["disabled"].bool != true
                )
            }
            let enabled = !done && q["disabled"].bool != true && (canOpen || (canUse(q, op, id) && (active || cost.hasAffordableOption)))
            return PlayThemeGameplayActionRow(
                id: "quest:\(id)",
                kind: "QUEST",
                contentId: id,
                operationKind: nil,
                operationKey: nil,
                title: nodeName,
                statusText: done ? W8Text.t("已完成", "Completed") : (active ? W8Text.t("进行中", "In progress") : (q["disabledReason"].text ?? W8Text.t("可接取", "Available"))),
                costText: cost.costText,
                costOptions: cost.costOptions,
                frozenIndex: cost.frozenIndex,
                nodeId: nodeId,
                choices: choices,
                operation: op,
                actionLabel: done ? W8Text.t("已完成", "Completed") : (canOpen ? W8Text.t("去完成", "Go complete") : (active ? W8Text.t("结算", "Settle") : W8Text.t("开始", "Start"))),
                enabled: enabled,
                cancelable: active && (cancel != nil || (team && availableActions.contains("QUEST_CANCEL"))),
                minParticipants: q["minParticipants"].tolerantInteger ?? 0,
                maxParticipants: q["maxParticipants"].tolerantInteger ?? 0,
                requiredRoles: (q["requiredRoles"].array ?? []).compactMap(\.text)
            )
        }

        let toolsSource = view["interactionTools"].array ?? view["facilities"].array ?? []
        let tools: [PlayThemeGameplayActionRow] = toolsSource.enumerated().map { idx, t in
            let id = t["operationKey"].text ?? t["facilityKey"].text ?? t["id"].text ?? "tool_\(idx)"
            let opKind = t["operationKind"].text ?? t["kind"].text ?? "FACILITY"
            let opNodeId = t["operationNodeId"].tolerantInteger
            let activeOp = activeOperation.object != nil
                && (activeOperation["operationKey"].text ?? activeOperation["id"].text) == id
                && (activeOperation["operationKind"].text ?? "FACILITY") == opKind
            let op = activeOp ? "OPEN_OPERATION" : (opNodeId != nil ? "OPERATION_START" : "FACILITY_USE")
            let rule = allowed(op, id)
            let cost = costState(t, rule, activeOp ? activeOperation["selectedCostOption"].tolerantInteger : nil)
            let resolvedNodeId = activeOperation["nodeId"].tolerantInteger ?? opNodeId
            let enabled = t["disabled"].bool != true && (activeOp
                ? (activeOperation["verified"].bool != true && resolvedNodeId != nil)
                : (canUse(t, op, id) && cost.hasAffordableOption))
            return PlayThemeGameplayActionRow(
                id: "tool:\(id)",
                kind: "FACILITY",
                contentId: id,
                operationKind: opKind,
                operationKey: id,
                title: t["title"].text ?? t["name"].text ?? W8Text.t("工具 \(id)", "Tool \(id)"),
                statusText: toolStatus(t, view: view, activeOp: activeOp),
                costText: cost.costText,
                costOptions: cost.costOptions,
                frozenIndex: cost.frozenIndex,
                nodeId: resolvedNodeId,
                choices: [],
                operation: op,
                actionLabel: activeOp ? W8Text.t("去核验", "Go verify") : (opNodeId != nil ? W8Text.t("开启操作", "Start operation") : W8Text.t("使用", "Use")),
                enabled: enabled,
                cancelable: activeOp && (allowed("OPERATION_CANCEL", id) != nil || (team && availableActions.contains("OPERATION_CANCEL"))),
                minParticipants: t["minParticipants"].tolerantInteger ?? 0,
                maxParticipants: t["maxParticipants"].tolerantInteger ?? 0,
                requiredRoles: (t["requiredRoles"].array ?? []).compactMap(\.text)
            )
        }

        let recoveriesSource = view["recoveries"].array ?? view["recoveryOptions"].array ?? []
        let recoveries: [PlayThemeGameplayActionRow] = recoveriesSource.enumerated().map { idx, r in
            let id = r["recoveryKey"].text ?? r["id"].text ?? "recover_\(idx)"
            let rule = allowed("RECOVER", id)
            let cost = costState(r, rule, nil)
            let enabled = r["disabled"].bool != true && canUse(r, "RECOVER", id) && cost.hasAffordableOption
            return PlayThemeGameplayActionRow(
                id: "recover:\(id)",
                kind: "RECOVERY",
                contentId: id,
                operationKind: nil,
                operationKey: nil,
                title: r["title"].text ?? r["name"].text ?? W8Text.t("恢复 \(id)", "Restore \(id)"),
                statusText: toolStatus(r, view: view),
                costText: cost.costText,
                costOptions: cost.costOptions,
                frozenIndex: -1,
                nodeId: nil,
                choices: [],
                operation: "RECOVER",
                actionLabel: W8Text.t("恢复", "Restore"),
                enabled: enabled,
                cancelable: false,
                minParticipants: 0,
                maxParticipants: 0,
                requiredRoles: []
            )
        }

        return quests + tools + recoveries
    }

    public static func questReceiptText(_ raw: PlayWireValue, view: PlayWireValue) -> String {
        let data = raw["settlement"].object != nil ? raw["settlement"] : (raw["result"].object != nil ? raw["result"] : raw)
        let q = data["questResult"].object != nil ? data["questResult"] : data
        guard q.object != nil else { return "" }
        let hasField = ["questKey", "choiceKey", "completed", "statDeltas", "grantedItems", "rewards", "noEffect"].contains { q[$0] != .null }
        guard hasField else { return "" }
        if q["noEffect"].bool == true { return W8Text.t("支线未产生额外变化", "Side quest made no extra changes") }
        var parts = [q["completed"].bool == false ? W8Text.t("支线已记录", "Side quest recorded") : W8Text.t("支线已结算", "Side quest settled")]
        for (key, val) in (q["statDeltas"].object ?? [:]).sorted(by: { $0.key < $1.key }) {
            if let num = val.tolerantInteger, num != 0 {
                parts.append("\(valueName(key, view: view)) \(num > 0 ? "+" : "")\(num)")
            }
        }
        let items = q["grantedItems"].array ?? q["rewards"].array ?? []
        for row in items {
            if let qty = row["quantity"].tolerantInteger, qty > 0 {
                parts.append("\(valueName(row["itemId"].text ?? row["id"].text, view: view)) ×\(qty)")
            }
        }
        return parts.joined(separator: " · ")
    }

    public static func participantChoice(_ view: PlayWireValue, actionRow: PlayThemeGameplayActionRow) -> PlayThemeParticipantChoice? {
        guard view["scope"].text == "TEAM" else { return nil }
        let minP = max(0, actionRow.minParticipants)
        let maxP = max(0, actionRow.maxParticipants)
        guard minP > 0 || maxP > 0 || !actionRow.requiredRoles.isEmpty else { return nil }
        let roster = (view["roster"].array ?? view["members"].array ?? []).filter { $0["left"].bool != true && $0["exited"].bool != true }
        guard !roster.isEmpty else { return nil }
        let rows: [PlayThemeParticipantRow] = roster.enumerated().map { idx, member in
            let id = member["memberId"].tolerantInteger ?? member["userId"].tolerantInteger ?? member["id"].tolerantInteger ?? (idx + 1)
            let name = member["nickname"].text ?? member["name"].text ?? W8Text.t("队员 \(id)", "Member \(id)")
            let roleName = member["roleName"].text ?? member["roleKey"].text ?? ""
            return PlayThemeParticipantRow(
                memberId: id,
                name: name,
                roleName: roleName,
                checked: maxP == 0 || idx < maxP
            )
        }
        let selectedIds = rows.filter(\.checked).map(\.memberId)
        let countText: String
        if minP > 0 && maxP > 0 { countText = W8Text.t("需 \(minP)–\(maxP) 人", "Needs \(minP)–\(maxP) players") }
        else if minP > 0 { countText = W8Text.t("至少 \(minP) 人", "At least \(minP) players") }
        else if maxP > 0 { countText = W8Text.t("最多 \(maxP) 人", "At most \(maxP) players") }
        else { countText = W8Text.t("选择参与队员", "Choose participants") }
        return PlayThemeParticipantChoice(
            actionRow: actionRow,
            minCount: minP,
            maxCount: maxP,
            countText: countText,
            selectedIds: selectedIds,
            rows: rows
        )
    }
}

// MARK: - Theme Rewards Rules (Ported from pages/play/utils/theme-rewards.js)

public struct PlayThemeRewardSourceItem: Equatable, Sendable {
    public let itemId: String
    public let quantity: Int
    public let source: String
    public let name: String
    public let sourceLabel: String
}

public struct PlayThemeRewardGrantRow: Equatable, Identifiable, Sendable {
    public var id: String { itemId }
    public let itemId: String
    public let quantity: Int
    public let name: String
    public var discard: Int
}

public struct PlayThemeRewardOwnerPreview: Equatable, Identifiable, Sendable {
    public var id: String { "\(ownerId ?? 0)-\(label)" }
    public let ownerId: Int?
    public let own: Bool
    public let label: String
    public let finalUsed: Int
    public let capacity: Int
    public let overflow: Bool
    public let sources: [PlayThemeRewardSourceItem]
    public var rewards: [PlayThemeRewardGrantRow]
}

public struct PlayThemeRewardPreview: Equatable, Sendable {
    public let previewVersion: String
    public let overflow: Bool
    public var owners: [PlayThemeRewardOwnerPreview]
}

public enum PlayThemeRewardsRules {
    public static func ended(_ view: PlayWireValue) -> Bool {
        view["claimOnly"].bool == true
            || view["status"].text == "COMPLETED"
            || view["result"] != .null
            || view["naturallyCompleted"].bool == true
    }

    public static func canClaim(_ view: PlayWireValue, source: String) -> Bool {
        guard view["pending"][source].object != nil else { return false }
        if view["scope"].text == "TEAM" {
            return (view["availableActions"].array ?? []).contains { $0.text == "ITEM_RECEIVE" }
        }
        return (view["allowedActions"].array ?? []).contains {
            $0["operation"].text == "RECEIVE" && $0["contentId"].text == source
        }
    }

    public static func itemName(_ id: String, view: PlayWireValue) -> String {
        if let pendingObj = view["pending"].object,
           let match = pendingObj.values.first(where: { $0["itemId"].text == id }),
           let name = match["name"].text, !name.isEmpty {
            return name
        }
        return PlayThemeGameplayRules.valueName(id, view: view)
    }

    public static func sourceName(_ source: String?) -> String {
        let parts = (source ?? "").split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts.first == "chapter", parts.count >= 2, let ch = Int(parts[1]) {
            let suffix = (parts.count >= 3 && parts[2] == "END") ? W8Text.t("完成奖励", "Completion reward") : W8Text.t("开启奖励", "Start reward")
            return W8Text.t("第\(ch + 1)章\(suffix)", "Chapter \(ch + 1)\(suffix)")
        }
        switch parts.first {
        case "quest": return W8Text.t("任务奖励", "Task reward")
        case "event": return W8Text.t("事件奖励", "Event reward")
        case "facility": return W8Text.t("工具奖励", "Tool reward")
        default: return W8Text.t("动作奖励", "Action reward")
        }
    }

    public static func preview(_ data: PlayWireValue, view: PlayWireValue) -> PlayThemeRewardPreview? {
        let pack: PlayWireValue
        if view["scope"].text == "TEAM" {
            pack = data["settlement"].object != nil ? data["settlement"] : (data["result"].object != nil ? data["result"] : data)
        } else {
            pack = data
        }
        guard pack.object != nil,
              let previewVersion = pack["previewVersion"].text, !previewVersion.isEmpty,
              let overflow = pack["overflow"].bool else {
            return nil
        }
        let rawOwners = pack["rewardOwners"].array ?? []
        let hasOwners = !rawOwners.isEmpty
        let ownersList = hasOwners ? rawOwners : [pack]
        let owners: [PlayThemeRewardOwnerPreview] = ownersList.map { owner in
            let ownerId = owner["ownerId"].tolerantInteger
            let own = !hasOwners || view["scope"].text != "TEAM" || String(ownerId ?? -1) == String(view["teamId"].tolerantInteger ?? -2)
            let drops = owner["discardRewards"].array ?? pack["discardRewards"].array ?? []
            let sources: [PlayThemeRewardSourceItem] = (owner["rewardSources"].array ?? []).map { row in
                let iId = row["itemId"].text ?? ""
                let src = row["source"].text ?? ""
                return PlayThemeRewardSourceItem(
                    itemId: iId,
                    quantity: row["quantity"].tolerantInteger ?? 0,
                    source: src,
                    name: itemName(iId, view: view),
                    sourceLabel: sourceName(src)
                )
            }
            let grantsObj = owner["grants"].object ?? [:]
            let rewards: [PlayThemeRewardGrantRow] = grantsObj.keys.sorted().map { itemId in
                let qty = grantsObj[itemId]?.tolerantInteger ?? 0
                let disc = drops.first(where: { $0["itemId"].text == itemId })?["quantity"].tolerantInteger ?? 0
                return PlayThemeRewardGrantRow(
                    itemId: itemId,
                    quantity: qty,
                    name: itemName(itemId, view: view),
                    discard: disc
                )
            }
            return PlayThemeRewardOwnerPreview(
                ownerId: ownerId,
                own: own,
                label: own ? (view["scope"].text == "TEAM" ? W8Text.t("本队", "Your team") : W8Text.t("本人", "You")) : W8Text.t("队伍 \(ownerId ?? 0)", "Team \(ownerId ?? 0)"),
                finalUsed: owner["finalUsed"].tolerantInteger ?? 0,
                capacity: owner["capacity"].tolerantInteger ?? 6,
                overflow: owner["overflow"].bool == true,
                sources: sources,
                rewards: rewards
            )
        }
        return PlayThemeRewardPreview(previewVersion: previewVersion, overflow: overflow, owners: owners)
    }

    public static func selection(_ rows: [PlayThemeRewardGrantRow]) -> [PlayThemeBackpackDiscard] {
        rows.filter { $0.discard > 0 }.map { PlayThemeBackpackDiscard(itemID: $0.itemId, quantity: $0.discard) }
    }
}

// MARK: - Theme Trade Rules (Ported from pages/play/utils/theme-trade.js)

public struct PlayThemeTradeTargetRow: Equatable, Identifiable, Sendable {
    public var id: String { "\(teamId)" }
    public let teamId: Int
    public let name: String
    public let nodeId: Int?
    public let stationName: String
    public let completed: Bool
    public let disabled: Bool
    public let enabled: Bool
    public let reason: String
}

public struct PlayThemeTradeRow: Equatable, Identifiable, Sendable {
    public var id: String { tradeKey }
    public let tradeKey: String
    public let version: Int
    public let status: String
    public let statusText: String
    public let stationName: String
    public let giveText: String
    public let takeText: String
    public let confirmed: Bool
    public let canConfirm: Bool
    public let canCancel: Bool
}

public struct PlayThemeTradeFormItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public var give: String
    public var take: String

    public init(id: String, name: String, give: String = "0", take: String = "0") {
        self.id = id
        self.name = name
        self.give = give
        self.take = take
    }
}

public struct PlayThemeTradeForm: Equatable, Sendable {
    public let toTeamId: Int
    public let tradeKey: String
    public var items: [PlayThemeTradeFormItem]

    public init(toTeamId: Int, tradeKey: String, items: [PlayThemeTradeFormItem]) {
        self.toTeamId = toTeamId
        self.tradeKey = tradeKey
        self.items = items
    }
}

public struct PlayThemeTradePayloadItem: Codable, Equatable, Sendable {
    public let itemId: String
    public let quantity: Int
}

public struct PlayThemeTradePayload: Codable, Equatable, Sendable {
    public let tradeKey: String
    public let toTeamId: Int
    public let give: [PlayThemeTradePayloadItem]
    public let take: [PlayThemeTradePayloadItem]
}

public enum PlayThemeTradeRules {
    public static func catalogue(_ view: PlayWireValue) -> [PlayWireValue] {
        if let worldCat = view["world"]["itemCatalog"].array {
            return worldCat
        }
        return (view["contents"].array ?? []).filter { $0["kind"].text == "ITEM" }
    }

    public static func itemText(_ rows: [PlayWireValue], view: PlayWireValue) -> String {
        let cat = catalogue(view)
        let texts: [String] = rows.compactMap { row in
            guard let itemId = row["itemId"].text else { return nil }
            let qty = row["quantity"].tolerantInteger ?? 0
            let name = cat.first(where: { $0["id"].text == itemId })?["name"].text ?? W8Text.t("物资 \(itemId)", "Supply \(itemId)")
            return "\(name) ×\(qty)"
        }
        return texts.isEmpty ? W8Text.t("无", "None") : texts.joined(separator: "、")
    }

    public static func present(_ view: PlayWireValue, nodes: [PlayThemeRouteNodeRef] = []) -> (
        tradeTargets: [PlayThemeTradeTargetRow],
        tradeRows: [PlayThemeTradeRow],
        tradeLockedText: String
    ) {
        let world = view["world"]
        let available = Set((view["availableActions"].array ?? []).compactMap(\.text))
        func station(_ row: PlayWireValue) -> String {
            guard let nId = row["nodeId"].tolerantInteger else { return "" }
            return nodes.first(where: { $0.nodeId == nId })?.name ?? W8Text.t("节点资料尚未加载", "Station data not loaded yet")
        }

        let targets: [PlayThemeTradeTargetRow] = (world["tradeTargets"].array ?? []).compactMap { row in
            guard let tId = row["teamId"].tolerantInteger else { return nil }
            let disabled = row["disabled"].bool != false
            let canOpen = available.contains("TRADE_OPEN")
            let enabled = !disabled && canOpen
            let reason: String
            if disabled {
                reason = row["disabledReason"].text ?? W8Text.t("交易暂不可用", "Trading unavailable")
            } else if !canOpen {
                reason = W8Text.t("仅当前队长可操作", "Only the current captain can do this")
            } else {
                reason = ""
            }
            return PlayThemeTradeTargetRow(
                teamId: tId,
                name: row["name"].text ?? W8Text.t("队伍 \(tId)", "Team \(tId)"),
                nodeId: row["nodeId"].tolerantInteger,
                stationName: station(row),
                completed: row["completed"].bool == true,
                disabled: disabled,
                enabled: enabled,
                reason: reason
            )
        }

        let myTeamId = view["teamId"].tolerantInteger.map(String.init) ?? view["teamId"].text ?? ""
        let rows: [PlayThemeTradeRow] = (world["trades"].array ?? []).compactMap { row in
            guard let key = row["tradeKey"].text else { return nil }
            let status = row["status"].text ?? ""
            let statusText: String
            switch status {
            case "OPEN": statusText = W8Text.t("等待双方队长确认", "Waiting for both captains")
            case "COMPLETED": statusText = W8Text.t("已交换", "Exchanged")
            case "CANCELLED": statusText = W8Text.t("已取消", "Canceled")
            default: statusText = status
            }
            let confirmedTeams = (row["confirmedTeams"].array ?? []).map { $0.tolerantInteger.map(String.init) ?? $0.text ?? "" }
            let confirmed = !myTeamId.isEmpty && confirmedTeams.contains(myTeamId)
            let disabled = row["disabled"].bool != false
            let canConfirm = status == "OPEN" && !disabled && available.contains("TRADE_CONFIRM") && !confirmed
            let canCancel = status == "OPEN" && available.contains("TRADE_CANCEL")
            return PlayThemeTradeRow(
                tradeKey: key,
                version: row["version"].tolerantInteger ?? 0,
                status: status,
                statusText: statusText,
                stationName: station(row),
                giveText: itemText(row["give"].array ?? [], view: view),
                takeText: itemText(row["take"].array ?? [], view: view),
                confirmed: confirmed,
                canConfirm: canConfirm,
                canCancel: canCancel
            )
        }

        let lockedObj = world["locked"].object ?? [:]
        let lockedRows: [PlayWireValue] = lockedObj.keys.sorted().map { itemId in
            .object(["itemId": .string(itemId), "quantity": lockedObj[itemId] ?? .int(0)])
        }
        let lockedText = itemText(lockedRows, view: view)
        return (targets, rows, lockedText)
    }

    public static func payload(_ form: PlayThemeTradeForm) throws -> PlayThemeTradePayload {
        var give: [PlayThemeTradePayloadItem] = []
        var take: [PlayThemeTradePayloadItem] = []
        for row in form.items {
            for (side, rawVal) in [("give", row.give), ("take", row.take)] {
                let trimmed = rawVal.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.range(of: "^\\d+$", options: .regularExpression) != nil,
                      let n = Int(trimmed), (0...999).contains(n) else {
                    throw NSError(domain: "PlayThemeTrade", code: 1, userInfo: [NSLocalizedDescriptionKey: W8Text.t("\(row.name)的数量须为 0–999 的整数", "Quantity of \(row.name) must be an integer from 0 to 999")])
                }
                if n > 0 {
                    let item = PlayThemeTradePayloadItem(itemId: row.id, quantity: n)
                    if side == "give" { give.append(item) } else { take.append(item) }
                }
            }
        }
        guard !give.isEmpty || !take.isEmpty else {
            throw NSError(domain: "PlayThemeTrade", code: 2, userInfo: [NSLocalizedDescriptionKey: W8Text.t("请填写至少一项交换物资", "Enter at least one item to exchange")])
        }
        return PlayThemeTradePayload(tradeKey: form.tradeKey, toTeamId: form.toTeamId, give: give, take: take)
    }

    public static func recoveryText(_ raw: PlayWireValue, hpName: String = W8Text.t("生命值", "Health")) -> String {
        let result = raw["facilityResult"].object != nil ? raw["facilityResult"] : raw
        if let recKey = result["recoveryKey"].text, !recKey.isEmpty, let hpDelta = result["hpDelta"].tolerantInteger {
            let effect = hpDelta > 0 ? W8Text.t("恢复\(hpName) \(hpDelta)", "Restore \(hpName) \(hpDelta)") : W8Text.t("\(hpName)已满，未产生效果", "\(hpName) is full; no effect")
            let consumedPart = result["consumed"].bool == true ? W8Text.t("已消耗一次", "One use consumed") : W8Text.t("未消耗", "Not consumed")
            let remPart: String
            if let rem = result["remaining"].tolerantInteger, rem >= 0 {
                remPart = W8Text.t("，剩余 \(rem) 次", ", \(rem) left")
            } else {
                remPart = ""
            }
            return "\(effect)，\(consumedPart)\(remPart)"
        }
        let payer: String
        if result["paidByOwnerId"] != .null {
            payer = W8Text.t("本人", "You")
        } else if let teamId = result["paidByTeamId"].tolerantInteger {
            payer = W8Text.t("队伍 \(teamId) ", "Team \(teamId) ")
        } else if let teamText = result["paidByTeamId"].text, !teamText.isEmpty {
            payer = W8Text.t("队伍 \(teamText) ", "Team \(teamText) ")
        } else {
            payer = ""
        }
        if result["noEffect"].bool == true && (result["consumed"].bool == false || (payer.isEmpty && result["consumed"].bool != true)) {
            return W8Text.t("已满，未消耗", "Full; not consumed")
        }
        if !payer.isEmpty || result["consumed"].bool == true {
            let prefix = result["noEffect"].bool == true ? W8Text.t("未产生效果", "No effect") : W8Text.t("工具已生效", "Tool applied")
            let suffix = !payer.isEmpty ? W8Text.t("仅\(payer)支付一次", "Paid once by \(payer)") : W8Text.t("已消耗一次", "One use consumed")
            return "\(prefix)，\(suffix)"
        }
        return ""
    }
}

// MARK: - Player Operations Rules (Ported from pages/play/utils/theme-player-ops.js)

public struct PlayThemePlayerOperationEntry: Equatable, Identifiable, Sendable {
    public var id: String { action }
    public let action: String
    public let title: String
    public let caption: String
    public let actionLabel: String
}

public struct PlayThemeManualRecordRow: Equatable, Identifiable, Sendable {
    public var id: String { "\(sequence)" }
    public let sequence: Int
    public let actionText: String
    public let status: String
    public let statusText: String
    public let occurredAtText: String
}

public struct PlayThemeArrivalTarget: Equatable, Identifiable, Sendable {
    public var id: String { label + ":" + (questKey ?? operationKey ?? "") }
    public let label: String
    public let nodeId: Int?
    public let questKey: String?
    public let operationKind: String?
    public let operationKey: String?
}

public struct PlayThemeManualCommandOption: Equatable, Identifiable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let label: String
    public let action: String
    public let payload: [String: PlayWireValue]
}

public struct PlayThemeArrivalProof: Equatable, Sendable {
    public let nonce: String
    public let stationName: String
    public let expiresAtText: String
    public let copyText: String
}

public enum PlayThemePlayerOpsRules {
    private static let entries: [PlayThemePlayerOperationEntry] = [
        PlayThemePlayerOperationEntry(action: "ARRIVAL_ISSUE", title: W8Text.t("到点凭证", "Arrival voucher"), caption: W8Text.t("向当前站点出示一次有效口令，待核验后才记为通过", "Show a valid code at the station; it counts only after verification"), actionLabel: W8Text.t("生成凭证", "Generate voucher")),
        PlayThemePlayerOperationEntry(action: "MANUAL_SIGN", title: W8Text.t("人工现场记录", "Manual on-site record"), caption: W8Text.t("现场切换人工授权时，按服务端连续序号登记本人请求", "When switched to manual authorization on site, your request is logged by server sequence number"), actionLabel: W8Text.t("登记记录", "Log record")),
        PlayThemePlayerOperationEntry(action: "TEAM_EXIT", title: W8Text.t("退出本局", "Leave run"), caption: W8Text.t("由当前队长提交离场原因并释放本队锁定资源", "The captain submits a reason and releases the team’s locked resources"), actionLabel: W8Text.t("申请退出", "Request exit")),
    ]

    private static let manualActionLabels: [String: String] = [
        "QUEST_START": W8Text.t("开始任务", "Start task"),
        "QUEST_RESOLVE": W8Text.t("完成任务", "Complete task"),
        "QUEST_CANCEL": W8Text.t("取消任务", "Cancel task"),
        "FACILITY_USE": W8Text.t("使用工具", "Use tool"),
        "OPERATION_START": W8Text.t("开始操作", "Start operation"),
        "OPERATION_CANCEL": W8Text.t("取消操作", "Cancel operation"),
        "RECOVER": W8Text.t("生命恢复", "Health restore"),
        "ITEM_USE": W8Text.t("使用物品", "Use item"),
        "ITEM_DISCARD": W8Text.t("丢弃物品", "Discard item"),
        "ITEM_RECEIVE": W8Text.t("领取奖励", "Claim reward"),
        "PLAN_JOIN": W8Text.t("加入计划", "Join plan"),
        "PLAN_FUND": W8Text.t("投入计划", "Contribute to plan"),
        "PLAN_WITHDRAW": W8Text.t("撤回投入", "Withdraw contribution"),
        "PLAN_CONFIRM": W8Text.t("确认计划", "Confirm plan"),
        "PLAN_LOCK": W8Text.t("锁定计划", "Lock plan"),
        "PLAN_RESOLVE": W8Text.t("执行计划", "Execute plan"),
    ]

    public static func rows(_ view: PlayWireValue) -> [PlayThemePlayerOperationEntry] {
        guard view["scope"].text == "TEAM" else { return [] }
        let allowed = Set((view["availableActions"].array ?? []).compactMap(\.text))
        return entries.filter { allowed.contains($0.action) }
    }

    public static func exitText(_ view: PlayWireValue) -> String {
        guard view["scope"].text == "TEAM" else { return "" }
        let teamId = view["teamId"].tolerantInteger.map(String.init) ?? view["teamId"].text ?? ""
        guard !teamId.isEmpty, let exited = view["run"]["exitedTeams"].object else { return "" }
        return exited[teamId] != nil ? W8Text.t("本队已退出本局", "Your team has left this run") : ""
    }

    public static func runText(_ view: PlayWireValue) -> String {
        guard view["scope"].text == "TEAM", view["run"].object != nil else { return "" }
        let status = view["run"]["operationStatus"].text ?? ""
        let mode = view["run"]["authorityMode"].text ?? ""
        let statusText: String
        switch status {
        case "PAUSED": statusText = W8Text.t("主持人已暂停本局：暂停期间只能查看，不能提交操作", "The host paused this run: view only, no actions while paused")
        case "INTERRUPTED": statusText = W8Text.t("主持人已中断本局：只能查看，进行中的任务已结束", "The host interrupted this run: view only; active tasks ended")
        case "CANCELLED": statusText = W8Text.t("主持人已取消本局：只能查看，进行中的任务已结束", "The host canceled this run: view only; active tasks ended")
        default: statusText = ""
        }
        let modeText: String
        switch mode {
        case "HYBRID": modeText = W8Text.t("当前为混合授权", "Mixed authorization")
        case "MANUAL": modeText = W8Text.t("当前为现场人工授权", "On-site manual authorization")
        default: modeText = ""
        }
        return [statusText, modeText].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    public static func stationName(nodeId: Int?, nodes: [PlayThemeRouteNodeRef]) -> String {
        guard let nodeId else { return W8Text.t("当前站点", "Current station") }
        if let found = nodes.first(where: { $0.nodeId == nodeId }), !found.name.isEmpty {
            return found.name
        }
        return W8Text.t("节点资料尚未加载", "Station data not loaded yet")
    }

    public static func manualRows(_ manual: PlayWireValue) -> [PlayThemeManualRecordRow] {
        guard let records = manual["records"].array else { return [] }
        return records.compactMap { row in
            guard let seq = row["sequence"].tolerantInteger, seq > 0 else { return nil }
            let action = row["command"]["action"].text ?? ""
            let status = row["status"].text ?? ""
            let statusText: String
            switch status {
            case "PENDING": statusText = W8Text.t("待核验", "Pending verification")
            case "VERIFIED": statusText = W8Text.t("已核验", "Verified")
            case "REJECTED": statusText = W8Text.t("未通过", "Failed")
            default: statusText = W8Text.t("状态未确认", "Status unconfirmed")
            }
            let occurredAtText = formatTime(row["occurredAt"].tolerantInteger)
            return PlayThemeManualRecordRow(
                sequence: seq,
                actionText: manualActionLabels[action] ?? W8Text.t("现场登记", "On-site log"),
                status: status,
                statusText: statusText,
                occurredAtText: occurredAtText
            )
        }
    }

    public static func arrivalTargets(_ view: PlayWireValue, nodes: [PlayThemeRouteNodeRef]) -> [PlayThemeArrivalTarget] {
        var targets: [PlayThemeArrivalTarget] = []
        for q in view["quests"].array ?? [] {
            guard q["disabled"].bool != true,
                  q["status"].text != "COMPLETED",
                  q["completed"].bool != true,
                  q["trustedPass"].bool != true,
                  let qKey = q["questKey"].text ?? q["id"].text, !qKey.isEmpty else { continue }
            let nId = q["nodeId"].tolerantInteger
            targets.append(PlayThemeArrivalTarget(
                label: stationName(nodeId: nId, nodes: nodes),
                nodeId: nId,
                questKey: qKey,
                operationKind: nil,
                operationKey: nil
            ))
        }
        for t in (view["interactionTools"].array ?? view["facilities"].array ?? []) {
            guard t["disabled"].bool != true,
                  t["trustedPass"].bool != true,
                  let opKey = t["operationKey"].text ?? t["facilityKey"].text ?? t["id"].text, !opKey.isEmpty else { continue }
            let opKind = t["operationKind"].text ?? t["kind"].text ?? "FACILITY"
            let nId = t["nodeId"].tolerantInteger ?? t["operationNodeId"].tolerantInteger
            targets.append(PlayThemeArrivalTarget(
                label: t["title"].text ?? t["name"].text ?? stationName(nodeId: nId, nodes: nodes),
                nodeId: nId,
                questKey: nil,
                operationKind: opKind,
                operationKey: opKey
            ))
        }
        for p in view["world"]["plans"].array ?? [] {
            guard ["OPEN", "FUNDED", "LOCKED"].contains(p["phase"].text ?? ""),
                  p["trustedPass"].bool != true,
                  let planKey = p["planKey"].text, !planKey.isEmpty else { continue }
            let nId = p["nodeId"].tolerantInteger
            targets.append(PlayThemeArrivalTarget(
                label: p["title"].text ?? stationName(nodeId: nId, nodes: nodes),
                nodeId: nId,
                questKey: nil,
                operationKind: "PLAN",
                operationKey: planKey
            ))
        }
        return targets
    }

    public static func manualCommands(_ view: PlayWireValue, nodes: [PlayThemeRouteNodeRef]) -> [PlayThemeManualCommandOption] {
        var list: [PlayThemeManualCommandOption] = []
        func push(_ label: String, _ action: String, _ payload: [String: PlayWireValue]) {
            list.append(PlayThemeManualCommandOption(index: list.count, label: label, action: action, payload: payload))
        }
        for q in view["quests"].array ?? [] {
            guard let id = q["questKey"].text ?? q["id"].text, !id.isEmpty,
                  q["status"].text != "COMPLETED", q["completed"].bool != true else { continue }
            let name = q["title"].text ?? q["name"].text ?? stationName(nodeId: q["nodeId"].tolerantInteger, nodes: nodes)
            let costOpts = q["costOptions"].array ?? []
            if !costOpts.isEmpty {
                for (idx, opt) in costOpts.enumerated() {
                    let optLabel = opt["label"].text ?? W8Text.t("费用方案 \(idx + 1)", "Cost option \(idx + 1)")
                    push(W8Text.t("开始任务 · \(name) · \(optLabel)", "Start task · \(name) · \(optLabel)"), "QUEST_START", ["questKey": .string(id), "costOption": .int(idx)])
                }
            } else {
                push(W8Text.t("开始任务 · \(name)", "Start task · \(name)"), "QUEST_START", ["questKey": .string(id)])
            }
            let choices = q["choices"].array ?? []
            if !choices.isEmpty {
                for choice in choices {
                    guard let cKey = choice["choiceKey"].text ?? choice["id"].text, !cKey.isEmpty else { continue }
                    let cLabel = choice["label"].text ?? choice["title"].text ?? W8Text.t("所选方案", "Selected option")
                    push(W8Text.t("完成任务 · \(name) · \(cLabel)", "Complete task · \(name) · \(cLabel)"), "QUEST_RESOLVE", ["questKey": .string(id), "choiceKey": .string(cKey)])
                }
            } else {
                push(W8Text.t("完成任务 · \(name)", "Complete task · \(name)"), "QUEST_RESOLVE", ["questKey": .string(id)])
            }
            push(W8Text.t("取消任务 · \(name)", "Cancel task · \(name)"), "QUEST_CANCEL", ["questKey": .string(id)])
        }
        for t in (view["interactionTools"].array ?? view["facilities"].array ?? []) {
            guard let id = t["operationKey"].text ?? t["facilityKey"].text ?? t["id"].text, !id.isEmpty else { continue }
            let kind = t["operationKind"].text ?? t["kind"].text ?? "FACILITY"
            let name = t["title"].text ?? t["name"].text ?? stationName(nodeId: t["nodeId"].tolerantInteger, nodes: nodes)
            if t["operationNodeId"].tolerantInteger != nil {
                push(W8Text.t("开始操作 · \(name)", "Start operation · \(name)"), "OPERATION_START", ["operationKind": .string(kind), "operationKey": .string(id)])
                push(W8Text.t("取消操作 · \(name)", "Cancel operation · \(name)"), "OPERATION_CANCEL", ["operationKind": .string(kind), "operationKey": .string(id)])
            } else {
                let costOpts = t["costOptions"].array ?? []
                if !costOpts.isEmpty {
                    for (idx, opt) in costOpts.enumerated() {
                        let optLabel = opt["label"].text ?? W8Text.t("费用方案 \(idx + 1)", "Cost option \(idx + 1)")
                        push(W8Text.t("使用工具 · \(name) · \(optLabel)", "Use tool · \(name) · \(optLabel)"), "FACILITY_USE", ["facilityKey": .string(id), "costOption": .int(idx)])
                    }
                } else {
                    push(W8Text.t("使用工具 · \(name)", "Use tool · \(name)"), "FACILITY_USE", ["facilityKey": .string(id)])
                }
            }
        }
        for r in (view["recoveries"].array ?? view["recoveryOptions"].array ?? []) {
            guard let id = r["recoveryKey"].text ?? r["id"].text, !id.isEmpty else { continue }
            let name = r["title"].text ?? r["name"].text ?? W8Text.t("恢复项目", "Restore item")
            push(W8Text.t("生命恢复 · \(name)", "Health restore · \(name)"), "RECOVER", ["recoveryKey": .string(id)])
        }
        return list
    }

    /// Strict date-time parser matching `occurredAt(text)` in `pages/play/utils/theme-player-ops.js`.
    public static func occurredAt(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", options: .regularExpression) != nil else {
            return nil
        }
        let parts = trimmed.split(whereSeparator: { "- :".contains($0) }).compactMap { Int($0) }
        guard parts.count == 6 else { return nil }
        let (y, m, d, hh, mm, ss) = (parts[0], parts[1], parts[2], parts[3], parts[4], parts[5])
        guard (1...12).contains(m), (1...31).contains(d), (0...23).contains(hh), (0...59).contains(mm), (0...59).contains(ss) else {
            return nil
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let comps = DateComponents(year: y, month: m, day: d, hour: hh, minute: mm, second: ss)
        guard let date = cal.date(from: comps) else { return nil }
        let check = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard check.year == y, check.month == m, check.day == d,
              check.hour == hh, check.minute == mm, check.second == ss else {
            return nil
        }
        return Int64(date.timeIntervalSince1970 * 1000.0)
    }

    public static func formatTime(_ timestampMs: Int?) -> String {
        guard let timestampMs, timestampMs > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(timestampMs) / 1000.0)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d-%02d-%02d %02d:%02d:%02d",
            c.year ?? 1970, c.month ?? 1, c.day ?? 1,
            c.hour ?? 0, c.minute ?? 0, c.second ?? 0
        )
    }
}

// MARK: - Zero-HP Challenge & Backpack Challenge Presentation (Ported from pages/play/utils/theme-backpack.js)

public struct PlayThemeZeroHpPresentation: Equatable, Sendable {
    public let phase: String
    public let policy: String
    public let progress: Int
    public let required: Int
    public let remainingSeconds: Int
    public let countdownText: String
    public let syncReady: Bool
    public let stepDelta: String
}

public struct PlayThemeChallengePresentation: Equatable, Sendable {
    public let awaitingChallenge: Bool
    public let challengeNodes: [PlayThemeRouteNodeRef]
    public let challengeProgressLabel: String
    public let challengeProgressText: String
    public let challengeRestoreText: String
    public let challengeRetryText: String
}

public enum PlayThemeChallengeRules {
    public static func presentZeroHp(_ raw: PlayWireValue, nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000), stepDelta: String = "") -> PlayThemeZeroHpPresentation? {
        let z = raw["zeroHp"].object != nil ? raw["zeroHp"] : raw
        guard z.object != nil,
              let phase = z["phase"].text,
              phase == "RECOVERING" || phase == "RESCUE_REQUIRED" else { return nil }
        let policy = z["policy"].text ?? ""
        let waitUntil = Int64(z["waitUntilEpochMillis"].tolerantInteger ?? 0)
        let remFromField = z["remainingSeconds"].tolerantInteger ?? 0
        let remainingSeconds: Int
        if policy == "WAIT" {
            let computed = waitUntil > 0 ? Int(ceil(Double(waitUntil - nowMs) / 1000.0)) : remFromField
            remainingSeconds = max(0, computed)
        } else {
            remainingSeconds = 0
        }
        let mins = String(format: "%02d", remainingSeconds / 60)
        let secs = String(format: "%02d", remainingSeconds % 60)
        return PlayThemeZeroHpPresentation(
            phase: phase,
            policy: policy,
            progress: max(0, z["progress"].tolerantInteger ?? 0),
            required: max(0, z["required"].tolerantInteger ?? 0),
            remainingSeconds: remainingSeconds,
            countdownText: "\(mins):\(secs)",
            syncReady: phase == "RECOVERING" && policy == "WAIT" && remainingSeconds == 0,
            stepDelta: stepDelta
        )
    }

    public static func presentChallenge(_ view: PlayWireValue, nodes: [PlayThemeRouteNodeRef]) -> PlayThemeChallengePresentation {
        let awaiting = view["awaitingChallenge"].bool == true
        let ch = view["challenge"]
        var nodeIds: [Int] = []
        if let primary = ch["nodeId"].tolerantInteger ?? view["challengeNodeId"].tolerantInteger {
            nodeIds.append(primary)
        }
        for alt in ch["alternativeNodeIds"].array ?? [] {
            if let id = alt.tolerantInteger, !nodeIds.contains(id) {
                nodeIds.append(id)
            }
        }
        let challengeNodes: [PlayThemeRouteNodeRef] = nodeIds.compactMap { id in
            if let found = nodes.first(where: { $0.nodeId == id }) {
                return found
            }
            return PlayThemeRouteNodeRef(nodeId: id, name: W8Text.t("挑战节点 \(id)", "Challenge station \(id)"))
        }
        let progressText: String
        if let p = ch["progress"].tolerantInteger, let g = ch["goal"].tolerantInteger, g > 0 {
            progressText = "\(p)/\(g)"
        } else {
            progressText = ""
        }
        let restoreText: String
        if let r = ch["restoreTo"].tolerantInteger {
            restoreText = W8Text.t("恢复到 \(r)", "Restore to \(r)")
        } else {
            restoreText = W8Text.t("恢复", "Restore")
        }
        let used = ch["used"].tolerantInteger ?? 0
        let limit = ch["limit"].tolerantInteger ?? 0
        let retryText: String
        if ch["disabledReason"].text == "CHALLENGE_LIMIT" || (limit > 0 && used >= limit) {
            retryText = W8Text.t("挑战次数已达上限（\(used)/\(limit)）", "Challenge limit reached (\(used)/\(limit))")
        } else if limit > 0 {
            retryText = W8Text.t("失败后可免费重试（已用 \(used)/\(limit)）", "Free retry after failure (used \(used)/\(limit))")
        } else {
            retryText = W8Text.t("失败后可免费重试", "Free retry after failure")
        }
        return PlayThemeChallengePresentation(
            awaitingChallenge: awaiting,
            challengeNodes: challengeNodes,
            challengeProgressLabel: view["scope"].text == "TEAM" ? W8Text.t("全队进度", "Team progress") : W8Text.t("挑战进度", "Challenge progress"),
            challengeProgressText: progressText,
            challengeRestoreText: restoreText,
            challengeRetryText: retryText
        )
    }
}


// MARK: - Shared Plans Rules (Ported from pages/play/utils/theme-plans.js)

public struct PlayThemePlanContributionRow: Equatable, Identifiable, Sendable {
    public var id: String { "\(teamId)" }
    public let teamId: Int
    public let confirmed: Bool
    public let statusText: String
    public let itemsText: String
    public let statText: String
}

public struct PlayThemePlanItemRequirement: Equatable, Identifiable, Sendable {
    public var id: String { itemId }
    public let itemId: String
    public let name: String
    public let current: Int
    public let required: Int
}

public struct PlayThemePlanStatRequirement: Equatable, Identifiable, Sendable {
    public var id: String { statKey }
    public let statKey: String
    public let name: String
    public let current: Int
    public let required: Int
}

public struct PlayThemePlanRow: Equatable, Identifiable, Sendable {
    public var id: String { planKey }
    public let planKey: String
    public let title: String
    public let phase: String
    public let phaseText: String
    public let policyText: String
    public let stationName: String
    public let participantCount: Int
    public let minTeams: Int
    public let maxTeams: Int
    public let teamCountText: String
    public let joined: Bool
    public let funded: Bool
    public let confirmed: Bool
    public let itemRequirements: [PlayThemePlanItemRequirement]
    public let statRequirements: [PlayThemePlanStatRequirement]
    public let contributions: [PlayThemePlanContributionRow]
    public let canJoin: Bool
    public let canFund: Bool
    public let canWithdraw: Bool
    public let canConfirm: Bool
    public let canLock: Bool
    public let canResolve: Bool
    public let disabledText: String
}

public struct PlayThemePlanFundingFormItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public var quantity: String

    public init(id: String, name: String, quantity: String = "0") {
        self.id = id
        self.name = name
        self.quantity = quantity
    }
}

public struct PlayThemePlanFundingFormStat: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public var amount: String

    public init(id: String, name: String, amount: String = "0") {
        self.id = id
        self.name = name
        self.amount = amount
    }
}

public struct PlayThemePlanFundingForm: Equatable, Sendable {
    public let planKey: String
    public var items: [PlayThemePlanFundingFormItem]
    public var stats: [PlayThemePlanFundingFormStat]

    public init(planKey: String, items: [PlayThemePlanFundingFormItem], stats: [PlayThemePlanFundingFormStat]) {
        self.planKey = planKey
        self.items = items
        self.stats = stats
    }
}

public struct PlayThemePlanEndingBanner: Equatable, Sendable {
    public let key: String
    public let title: String
    public let summary: String
    public let tone: String
    public let badges: [String]
}

public enum PlayThemePlansRules {
    private static let phaseLabels: [String: String] = [
        "OPEN": W8Text.t("募集中", "Collecting"),
        "FUNDED": W8Text.t("已凑齐", "Fully funded"),
        "LOCKED": W8Text.t("已锁定", "Locked"),
        "RESOLVED": W8Text.t("已执行", "Executed"),
        "CANCELLED": W8Text.t("已取消", "Canceled"),
        "EXPIRED": W8Text.t("已过期", "Expired"),
    ]

    private static let policyLabels: [String: String] = [
        "RETURN_IF_NOT_LOCKED": W8Text.t("锁定前可撤回", "Withdrawable until locked"),
        "LOCK_ON_FUND": W8Text.t("投入即锁定", "Locked once contributed"),
        "CONSUME_ON_RESOLVE": W8Text.t("执行后消耗", "Consumed on execution"),
    ]

    private static let reasonLabels: [String: String] = [
        "NOT_CAPTAIN": W8Text.t("仅当前队长可操作", "Only the current captain can do this"),
        "NOT_at_NODE": W8Text.t("需到达计划所在站点", "Must be at the plan’s station"),
        "NOT_AT_NODE": W8Text.t("需到达计划所在站点", "Must be at the plan’s station"),
        "TEAM_LIMIT": W8Text.t("参与队伍数已满", "Team limit reached"),
        "MIN_TEAMS_NOT_MET": W8Text.t("参与队伍数不足", "Not enough teams"),
        "FUNDING_INCOMPLETE": W8Text.t("计划投入尚未凑齐", "Plan contributions incomplete"),
        "UNCONFIRMED_TEAMS": W8Text.t("仍有参与队伍未确认", "Some teams have not confirmed"),
        "ALREADY_LOCKED": W8Text.t("计划已锁定，不可更改", "Plan is locked and cannot change"),
        "INSUFFICIENT_RESOURCES": W8Text.t("队伍物资或数值不足", "Team supplies or values insufficient"),
    ]

    public static func phaseText(_ phase: String?) -> String {
        guard let phase, !phase.isEmpty else { return W8Text.t("未知状态", "Unknown status") }
        return phaseLabels[phase] ?? phase
    }

    public static func policyText(_ policy: String?) -> String {
        guard let policy, !policy.isEmpty else { return "" }
        return policyLabels[policy] ?? policy
    }

    public static func reasonText(_ code: String?) -> String {
        guard let code, !code.isEmpty else { return "" }
        return reasonLabels[code] ?? code
    }

    public static func endingResult(_ view: PlayWireValue) -> PlayThemePlanEndingBanner? {
        let ending = view["endingResult"].object != nil ? view["endingResult"] : view["world"]["endingResult"]
        guard ending.object != nil else { return nil }
        let key = ending["endingKey"].text ?? ending["id"].text ?? ""
        let title = ending["title"].text ?? ending["name"].text ?? ""
        guard !key.isEmpty || !title.isEmpty else { return nil }
        let badges = (ending["badges"].array ?? []).compactMap { $0["name"].text ?? $0["label"].text ?? $0.text }
        return PlayThemePlanEndingBanner(
            key: key,
            title: title.isEmpty ? W8Text.t("终局结算", "Final settlement") : title,
            summary: ending["summary"].text ?? ending["description"].text ?? "",
            tone: ending["tone"].text ?? "NEUTRAL",
            badges: badges
        )
    }

    public static func present(_ view: PlayWireValue, nodes: [PlayThemeRouteNodeRef] = []) -> [PlayThemePlanRow] {
        let plans = view["world"]["plans"].array ?? view["plans"].array ?? []
        let available = Set((view["availableActions"].array ?? []).compactMap(\.text))
        let myTeamId = view["teamId"].tolerantInteger ?? -1

        return plans.compactMap { row in
            guard let planKey = row["planKey"].text ?? row["id"].text, !planKey.isEmpty else { return nil }
            let phase = row["phase"].text ?? row["status"].text ?? "OPEN"
            let nodeId = row["nodeId"].tolerantInteger
            let stationName = nodeId.map { id in
                nodes.first(where: { $0.nodeId == id })?.name ?? W8Text.t("节点资料尚未加载", "Station data not loaded yet")
            } ?? ""
            let participants = (row["participantTeams"].array ?? []).compactMap(\.tolerantInteger)
            let confirmedTeams = (row["confirmedTeams"].array ?? []).compactMap(\.tolerantInteger)
            let joined = myTeamId > 0 && participants.contains(myTeamId)
            let confirmed = myTeamId > 0 && confirmedTeams.contains(myTeamId)
            let minTeams = row["minTeams"].tolerantInteger ?? 1
            let maxTeams = row["maxTeams"].tolerantInteger ?? 0
            let teamCountText = maxTeams > 0 ? W8Text.t("\(participants.count)/\(maxTeams) 队（至少 \(minTeams) 队）", "\(participants.count)/\(maxTeams) teams (min \(minTeams))") : W8Text.t("\(participants.count) 队（至少 \(minTeams) 队）", "\(participants.count) teams (min \(minTeams))")

            let itemReqs: [PlayThemePlanItemRequirement] = (row["itemRequirements"].array ?? []).compactMap { req in
                guard let itemId = req["itemId"].text else { return nil }
                return PlayThemePlanItemRequirement(
                    itemId: itemId,
                    name: PlayThemeGameplayRules.valueName(itemId, view: view),
                    current: req["current"].tolerantInteger ?? 0,
                    required: req["required"].tolerantInteger ?? req["quantity"].tolerantInteger ?? 0
                )
            }
            let statReqs: [PlayThemePlanStatRequirement] = (row["statRequirements"].array ?? []).compactMap { req in
                guard let statKey = req["statKey"].text ?? req["key"].text else { return nil }
                return PlayThemePlanStatRequirement(
                    statKey: statKey,
                    name: PlayThemeGameplayRules.valueName(statKey, view: view),
                    current: req["current"].tolerantInteger ?? 0,
                    required: req["required"].tolerantInteger ?? req["amount"].tolerantInteger ?? 0
                )
            }
            let contributions: [PlayThemePlanContributionRow] = (row["contributions"].array ?? []).compactMap { c in
                guard let tId = c["teamId"].tolerantInteger else { return nil }
                let conf = confirmedTeams.contains(tId) || c["confirmed"].bool == true
                let itemsText = PlayThemeTradeRules.itemText(c["items"].array ?? [], view: view)
                let statParts: [String] = (c["stats"].array ?? []).compactMap { s in
                    guard let k = s["statKey"].text ?? s["key"].text,
                          let amt = s["amount"].tolerantInteger ?? s["value"].tolerantInteger, amt > 0 else { return nil }
                    return "\(PlayThemeGameplayRules.valueName(k, view: view)) \(amt)"
                }
                return PlayThemePlanContributionRow(
                    teamId: tId,
                    confirmed: conf,
                    statusText: conf ? W8Text.t("已确认", "Confirmed") : W8Text.t("待确认", "Awaiting confirmation"),
                    itemsText: itemsText,
                    statText: statParts.joined(separator: " · ")
                )
            }
            let myFunded = contributions.contains { $0.teamId == myTeamId && ($0.itemsText != W8Text.t("无", "None") || !$0.statText.isEmpty) }
            let activePhase = phase == "OPEN" || phase == "FUNDED"
            let disabled = row["disabled"].bool == true
            return PlayThemePlanRow(
                planKey: planKey,
                title: row["title"].text ?? row["name"].text ?? W8Text.t("共同计划 \(planKey)", "Shared plan \(planKey)"),
                phase: phase,
                phaseText: phaseText(phase),
                policyText: policyText(row["policy"].text),
                stationName: stationName,
                participantCount: participants.count,
                minTeams: minTeams,
                maxTeams: maxTeams,
                teamCountText: teamCountText,
                joined: joined,
                funded: myFunded,
                confirmed: confirmed,
                itemRequirements: itemReqs,
                statRequirements: statReqs,
                contributions: contributions,
                canJoin: !disabled && activePhase && !joined && available.contains("PLAN_JOIN"),
                canFund: !disabled && activePhase && joined && available.contains("PLAN_FUND"),
                canWithdraw: !disabled && activePhase && myFunded && available.contains("PLAN_WITHDRAW"),
                canConfirm: !disabled && phase == "FUNDED" && joined && !confirmed && available.contains("PLAN_CONFIRM"),
                canLock: !disabled && phase == "FUNDED" && joined && available.contains("PLAN_LOCK"),
                canResolve: !disabled && phase == "LOCKED" && joined && available.contains("PLAN_RESOLVE"),
                disabledText: reasonText(row["disabledReason"].text)
            )
        }
    }

    public static func fundingPayload(_ form: PlayThemePlanFundingForm) throws -> [String: PlayWireValue] {
        var items: [PlayWireValue] = []
        var stats: [PlayWireValue] = []
        for item in form.items {
            let trimmed = item.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.range(of: "^\\d+$", options: .regularExpression) != nil,
                  let qty = Int(trimmed), (0...999).contains(qty) else {
                throw NSError(domain: "PlayThemePlans", code: 1, userInfo: [NSLocalizedDescriptionKey: W8Text.t("\(item.name)的数量须为 0–999 的整数", "Quantity of \(item.name) must be an integer from 0 to 999")])
            }
            if qty > 0 {
                items.append(.object(["itemId": .string(item.id), "quantity": .int(qty)]))
            }
        }
        for stat in form.stats {
            let trimmed = stat.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.range(of: "^\\d+$", options: .regularExpression) != nil,
                  let amt = Int(trimmed), (0...999).contains(amt) else {
                throw NSError(domain: "PlayThemePlans", code: 2, userInfo: [NSLocalizedDescriptionKey: W8Text.t("\(stat.name)的投入值须为 0–999 的整数", "Contribution to \(stat.name) must be an integer from 0 to 999")])
            }
            if amt > 0 {
                stats.append(.object(["statKey": .string(stat.id), "amount": .int(amt)]))
            }
        }
        guard !items.isEmpty || !stats.isEmpty else {
            throw NSError(domain: "PlayThemePlans", code: 3, userInfo: [NSLocalizedDescriptionKey: W8Text.t("请至少填写一项投入物资或数值", "Enter at least one supply or value to contribute")])
        }
        return [
            "planKey": .string(form.planKey),
            "items": .array(items),
            "stats": .array(stats),
        ]
    }
}

// MARK: - Complete Theme Backpack Gameplay & Player Ops State Machine Coordinator

@available(macOS 14.0, *)
@MainActor @Observable public final class PlayThemeGameplayCoordinator {
    public struct CostChoiceSheet: Equatable, Sendable {
        public let row: PlayThemeGameplayActionRow
        public var selected: Int
    }

    public struct QuestChoiceSheet: Equatable, Sendable {
        public let row: PlayThemeGameplayActionRow
        public var selected: String
    }

    public struct PlayerOperationForm: Equatable, Sendable {
        public let action: String
        public var targetIndex: Int
        public var commandIndex: Int
        public var occurredAtText: String
        public var reason: String
        public var sequence: Int
        public var authorityEpoch: Int
    }

    public struct PendingTeamCommand: Equatable, Sendable {
        public let activityId: Int
        public let requestId: String
        public let action: String
        public let expectedRevision: Int
        public let authorityEpoch: Int
        public let payload: [String: PlayWireValue]
    }

    public private(set) var rawView: PlayWireValue = .object([:])
    public private(set) var nodes: [PlayThemeRouteNodeRef] = []
    public private(set) var statLabels = PlayThemeStatLabels()
    public private(set) var actionRows: [PlayThemeGameplayActionRow] = []
    public private(set) var zeroHp: PlayThemeZeroHpPresentation?
    public private(set) var challenge: PlayThemeChallengePresentation = PlayThemeChallengeRules.presentChallenge(.object([:]), nodes: [])
    public private(set) var plans: [PlayThemePlanRow] = []
    public private(set) var endingBanner: PlayThemePlanEndingBanner?
    public private(set) var tradeTargets: [PlayThemeTradeTargetRow] = []
    public private(set) var tradeRows: [PlayThemeTradeRow] = []
    public private(set) var tradeLockedText: String = W8Text.t("无", "None")
    public private(set) var playerOperationRows: [PlayThemePlayerOperationEntry] = []
    public private(set) var playerManualRows: [PlayThemeManualRecordRow] = []
    public private(set) var playerRunText: String = ""
    public private(set) var playerExitText: String = ""
    public private(set) var playerArrivalProof: PlayThemeArrivalProof?

    public var costChoice: CostChoiceSheet?
    public var questChoice: QuestChoiceSheet?
    public var rewardPreview: PlayThemeRewardPreview?
    public var tradeForm: PlayThemeTradeForm?
    public var planFundingForm: PlayThemePlanFundingForm?
    public var playerOperationForm: PlayerOperationForm?
    public var playerExitConfirm: Bool = false

    public private(set) var recoveryText: String = ""
    public private(set) var questReceiptText: String = ""
    public private(set) var errorMessage: String = ""
    public private(set) var unknownReceiptPending: Bool = false
    public private(set) var pendingTeamCommand: PendingTeamCommand?
    public private(set) var openedChallengeNodeId: Int?

    public init(rawView: PlayWireValue = .object([:]), nodes: [PlayThemeRouteNodeRef] = []) {
        applyView(rawView, nodes: nodes)
    }

    public func applyView(_ view: PlayWireValue, nodes: [PlayThemeRouteNodeRef]? = nil) {
        if let nodes { self.nodes = nodes }
        self.rawView = view
        self.statLabels = PlayThemeGameplayRules.labels(view)
        self.actionRows = PlayThemeGameplayRules.actionRows(view, nodes: self.nodes)
        self.zeroHp = PlayThemeChallengeRules.presentZeroHp(view)
        self.challenge = PlayThemeChallengeRules.presentChallenge(view, nodes: self.nodes)
        self.plans = PlayThemePlansRules.present(view, nodes: self.nodes)
        self.endingBanner = PlayThemePlansRules.endingResult(view)
        let trade = PlayThemeTradeRules.present(view, nodes: self.nodes)
        self.tradeTargets = trade.tradeTargets
        self.tradeRows = trade.tradeRows
        self.tradeLockedText = trade.tradeLockedText
        self.playerOperationRows = PlayThemePlayerOpsRules.rows(view)
        self.playerManualRows = PlayThemePlayerOpsRules.manualRows(view["run"]["manual"])
        self.playerRunText = PlayThemePlayerOpsRules.runText(view)
        self.playerExitText = PlayThemePlayerOpsRules.exitText(view)
    }

    public func tapGameplayAction(index: Int) -> (immediateOperation: String?, contentId: String?, costOption: Int?, choiceKey: String?) {
        guard actionRows.indices.contains(index) else { return (nil, nil, nil, nil) }
        let row = actionRows[index]
        guard row.enabled, pendingTeamCommand == nil else { return (nil, nil, nil, nil) }
        errorMessage = ""

        if row.operation == "OPEN_QUEST" || row.operation == "OPEN_OPERATION" {
            openedChallengeNodeId = row.nodeId
            return (row.operation, row.contentId, nil, nil)
        }
        if row.operation == "QUEST_RESOLVE" && !row.choices.isEmpty {
            let firstEnabled = row.choices.first(where: \.enabled)?.choiceKey ?? ""
            questChoice = QuestChoiceSheet(row: row, selected: firstEnabled)
            return (nil, nil, nil, nil)
        }
        if row.frozenIndex < 0 && !row.costOptions.isEmpty {
            let firstAffordable = row.costOptions.first(where: \.affordable)?.index ?? -1
            costChoice = CostChoiceSheet(row: row, selected: firstAffordable)
            return (nil, nil, nil, nil)
        }
        return (row.operation, row.contentId, row.frozenIndex >= 0 ? row.frozenIndex : nil, nil)
    }

    public func selectCostOption(_ index: Int) {
        guard var sheet = costChoice,
              sheet.row.costOptions.indices.contains(index),
              sheet.row.costOptions[index].affordable else { return }
        sheet.selected = index
        costChoice = sheet
    }

    public func confirmCostChoice() -> (operation: String, contentId: String, costOption: Int)? {
        guard let sheet = costChoice,
              sheet.row.costOptions.indices.contains(sheet.selected),
              sheet.row.costOptions[sheet.selected].affordable else {
            errorMessage = W8Text.t("请选择可负担的费用方案", "Choose an affordable cost option")
            return nil
        }
        costChoice = nil
        return (sheet.row.operation, sheet.row.contentId, sheet.selected)
    }

    public func selectQuestChoice(_ key: String) {
        guard var sheet = questChoice,
              let item = sheet.row.choices.first(where: { $0.choiceKey == key }),
              item.enabled else { return }
        sheet.selected = key
        questChoice = sheet
    }

    public func confirmQuestChoice() -> (operation: String, contentId: String, choiceKey: String)? {
        guard let sheet = questChoice, !sheet.selected.isEmpty else {
            errorMessage = W8Text.t("请选择结算方案", "Choose a settlement option")
            return nil
        }
        questChoice = nil
        return ("QUEST_RESOLVE", sheet.row.contentId, sheet.selected)
    }

    public func openChallengeNode(_ nodeId: Int) {
        openedChallengeNodeId = nodeId
    }

    public func applySettlementReceipt(_ response: PlayWireValue) {
        let data = response["settlement"].object != nil ? response["settlement"] : (response["result"]["result"].object != nil ? response["result"]["result"] : (response["result"].object != nil ? response["result"] : response))
        let recText = PlayThemeTradeRules.recoveryText(data, hpName: statLabels.hp)
        if !recText.isEmpty {
            recoveryText = recText
        }
        let qText = PlayThemeGameplayRules.questReceiptText(response, view: rawView)
        if !qText.isEmpty {
            questReceiptText = qText
        }
        if let preview = PlayThemeRewardsRules.preview(response, view: rawView) {
            rewardPreview = preview
        }
    }

    // MARK: - Player Operations (ARRIVAL_ISSUE, MANUAL_SIGN, TEAM_EXIT)

    public func openPlayerOperation(_ action: String) {
        guard pendingTeamCommand == nil,
              playerOperationRows.contains(where: { $0.action == action }) else { return }
        errorMessage = ""
        playerExitConfirm = false
        let seq = rawView["run"]["manual"]["nextSequence"].tolerantInteger ?? 1
        let epoch = rawView["authorityEpoch"].tolerantInteger ?? 0
        playerOperationForm = PlayerOperationForm(
            action: action,
            targetIndex: 0,
            commandIndex: 0,
            occurredAtText: "",
            reason: "",
            sequence: seq,
            authorityEpoch: epoch
        )
    }

    public func closePlayerOperation() {
        guard pendingTeamCommand == nil else { return }
        playerOperationForm = nil
        playerExitConfirm = false
        errorMessage = ""
    }

    public func preparePlayerOperationCommand(requestId: String = "ops_" + UUID().uuidString.lowercased()) -> PendingTeamCommand? {
        guard pendingTeamCommand == nil,
              let form = playerOperationForm,
              rawView["scope"].text == "TEAM",
              playerOperationRows.contains(where: { $0.action == form.action }) else {
            errorMessage = W8Text.t("当前不可执行该操作", "This action is unavailable right now")
            return nil
        }
        let activityId = rawView["activityId"].tolerantInteger ?? 0
        let revision = rawView["revision"].tolerantInteger ?? 0
        let currentEpoch = rawView["authorityEpoch"].tolerantInteger ?? 0
        guard currentEpoch == form.authorityEpoch else {
            playerExitConfirm = false
            errorMessage = W8Text.t("执行权已变化，请重新确认", "Authority changed. Please confirm again.")
            return nil
        }

        switch form.action {
        case "ARRIVAL_ISSUE":
            let targets = PlayThemePlayerOpsRules.arrivalTargets(rawView, nodes: nodes)
            guard targets.indices.contains(form.targetIndex) else {
                errorMessage = W8Text.t("当前没有可生成凭证的站点", "No station is available for a voucher")
                return nil
            }
            let target = targets[form.targetIndex]
            let payload: [String: PlayWireValue]
            if let qKey = target.questKey {
                payload = ["questKey": .string(qKey)]
            } else if let opKind = target.operationKind, let opKey = target.operationKey {
                payload = ["operationKind": .string(opKind), "operationKey": .string(opKey)]
            } else {
                errorMessage = W8Text.t("目标参数无效", "Invalid target")
                return nil
            }
            let cmd = PendingTeamCommand(
                activityId: activityId,
                requestId: requestId,
                action: "ARRIVAL_ISSUE",
                expectedRevision: revision,
                authorityEpoch: currentEpoch,
                payload: payload
            )
            pendingTeamCommand = cmd
            return cmd

        case "MANUAL_SIGN":
            guard let nextSeq = rawView["run"]["manual"]["nextSequence"].tolerantInteger,
                  nextSeq > 0,
                  nextSeq == form.sequence else {
                errorMessage = W8Text.t("现场记录序号已变化，请刷新", "On-site record sequence changed. Refresh.")
                return nil
            }
            guard let occurredAt = PlayThemePlayerOpsRules.occurredAt(form.occurredAtText) else {
                errorMessage = W8Text.t("请按 YYYY-MM-DD HH:mm:ss 填写实际发生时间", "Enter the actual time as YYYY-MM-DD HH:mm:ss")
                return nil
            }
            let commands = PlayThemePlayerOpsRules.manualCommands(rawView, nodes: nodes)
            guard commands.indices.contains(form.commandIndex) else {
                errorMessage = W8Text.t("请选择登记内容", "Choose what to log")
                return nil
            }
            let chosen = commands[form.commandIndex]
            let payload: [String: PlayWireValue] = [
                "sequence": .int(nextSeq),
                "occurredAt": .int(Int(occurredAt)),
                "command": .object([
                    "action": .string(chosen.action),
                    "payload": .object(chosen.payload),
                ]),
            ]
            let cmd = PendingTeamCommand(
                activityId: activityId,
                requestId: requestId,
                action: "MANUAL_SIGN",
                expectedRevision: revision,
                authorityEpoch: currentEpoch,
                payload: payload
            )
            pendingTeamCommand = cmd
            return cmd

        case "TEAM_EXIT":
            let trimmedReason = form.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedReason.isEmpty, trimmedReason.count <= 200 else {
                errorMessage = W8Text.t("请填写 200 字以内的离场原因", "Enter an exit reason within 200 characters")
                return nil
            }
            if !playerExitConfirm {
                playerExitConfirm = true
                return nil
            }
            guard let teamId = rawView["teamId"].tolerantInteger else {
                errorMessage = W8Text.t("未找到当前队伍", "Current team not found")
                return nil
            }
            let cmd = PendingTeamCommand(
                activityId: activityId,
                requestId: requestId,
                action: "TEAM_EXIT",
                expectedRevision: revision,
                authorityEpoch: currentEpoch,
                payload: [
                    "teamId": .int(teamId),
                    "reason": .string(trimmedReason),
                ]
            )
            pendingTeamCommand = cmd
            return cmd

        default:
            return nil
        }
    }

    public func resolveTeamCommandReceipt(_ receipt: PlayWireValue) -> Bool {
        guard let pending = pendingTeamCommand else { return false }
        let outcome = receipt["outcome"].text ?? ""
        let reqId = receipt["requestId"].text ?? ""
        let action = receipt["action"].text ?? ""
        if outcome == "PENDING" || reqId.isEmpty {
            unknownReceiptPending = true
            errorMessage = W8Text.t("操作结果待确认，请先核对原请求回执", "Result pending. Check the original request receipt first.")
            return false
        }
        guard reqId == pending.requestId, action == pending.action else {
            unknownReceiptPending = true
            errorMessage = W8Text.t("回执身份异常，未确认结果", "Receipt identity mismatch; result unconfirmed")
            return false
        }
        if outcome == "APPLIED" {
            if pending.action == "ARRIVAL_ISSUE" {
                let res = receipt["result"]
                if let nonce = res["nonce"].text, nonce.count >= 16 {
                    let targets = PlayThemePlayerOpsRules.arrivalTargets(rawView, nodes: nodes)
                    let idx = playerOperationForm?.targetIndex ?? 0
                    let stName = targets.indices.contains(idx) ? targets[idx].label : W8Text.t("当前站点", "Current station")
                    let exp = PlayThemePlayerOpsRules.formatTime(res["expiresAt"].tolerantInteger)
                    playerArrivalProof = PlayThemeArrivalProof(
                        nonce: nonce,
                        stationName: stName,
                        expiresAtText: exp,
                        copyText: W8Text.t("\(stName) 到点凭证：\(nonce)", "\(stName) arrival voucher: \(nonce)")
                    )
                } else {
                    unknownReceiptPending = true
                    errorMessage = W8Text.t("凭证回执异常，请稍后核对", "Voucher receipt error. Check again later.")
                    return false
                }
            }
            pendingTeamCommand = nil
            unknownReceiptPending = false
            playerOperationForm = nil
            playerExitConfirm = false
            errorMessage = ""
            applySettlementReceipt(receipt)
            return true
        }
        // Authoritative business rejection unlocks the pending command while preserving form inputs
        pendingTeamCommand = nil
        unknownReceiptPending = false
        playerExitConfirm = false
        errorMessage = receipt["message"].text ?? receipt["msg"].text ?? W8Text.t("操作未通过", "Action not passed")
        return false
    }
}
