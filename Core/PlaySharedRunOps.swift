import Foundation

/// CLB-G13a: port of the MP 通用玩法现场运营 form (`pages/club/utils/generic-director-ops.js`
/// `genericOpsActions` / `genericOpsFields` / `genericOpsPayload`) and its submit
/// (`pages/club/topic-detail/director.js confirmGenericOps` → `executeAction(action, payload)` →
/// `POST /api/game/session/command`, the same envelope `PLAN_FALLBACK` uses in `PlayDirectorPlanFallback.swift`).
///
/// The 工作人员指导完成 answer form is `guideFields` / `guideAnswers` over `control.guideTasks` (generic-director-ops.js;
/// vectors in MP tests/unit/generic-director-ops.test.js `guideCases`).
public enum PlaySharedRunOps {
    /// MP generic-director-ops.js `labels` key order (the native action list order).
    public static let actions = ["ACT_UNLOCK", "ARRIVAL_CONFIRM", "ARRIVAL_REVOKE", "RUN_PAUSE", "RUN_RESUME", "RUN_INTERRUPT",
                                 "RUN_CANCEL", "MANUAL_BEGIN", "STAFF_MANUAL_SIGN", "MANUAL_IMPORT", "MANUAL_REVIEW",
                                 "AUTHORITY_RESUME", "QUEST_GUIDE", "LOCATION_REBIND", "STAFF_TEAM_EXIT"]
    /// Actions that open the native form (every generic action; OFFLINE_ANCHOR is a confirm, MP director.js startOfflineRecord).
    public static let formActions: Set<String> = Set(actions)
    /// MP `irreversible`: the confirm says 此操作不可撤销.
    public static let irreversible: Set<String> = ["RUN_INTERRUPT", "RUN_CANCEL", "MANUAL_IMPORT", "MANUAL_REVIEW", "STAFF_TEAM_EXIT", "QUEST_GUIDE", "ACT_UNLOCK"]
    /// MP director.js `openGenericOps`: these read the shared export first (ledger rows, hashes, next sequence).
    public static let ledgerActions: Set<String> = ["MANUAL_BEGIN", "STAFF_MANUAL_SIGN", "MANUAL_IMPORT", "MANUAL_REVIEW"]
    /// MP `choices.signedAction`.
    public static let signedActions = ["ARRIVAL_CONFIRM", "ARRIVAL_ATTEST", "QUEST_GUIDE"]
    /// MP `choices.reviewKind`.
    public static let reviewKinds = ["HIGH_WATER", "SIGNATURE", "REQUEST"]
    /// Keys whose draft value is epoch milliseconds (MP `toTimestamp`, 北京时间 in the picker).
    public static let timestampKeys: Set<String> = ["occurredAt", "offlineStartedAt"]
    /// Every action the shared-run command admission accepts: the generic set, the signed attest, and `PLAN_FALLBACK`.
    public static let commandActions: Set<String> = Set(actions).union(["ARRIVAL_ATTEST", "PLAN_FALLBACK"])

    static let targetFields = ["teamId", "questKey", "operationKind", "operationKey"]
    /// MP `schemas`.
    static let schemas: [String: [String]] = [
        "ACT_UNLOCK": ["actKey", "reason"], "ARRIVAL_CONFIRM": targetFields + ["nonce"],
        "ARRIVAL_ATTEST": targetFields + ["reason"], "ARRIVAL_REVOKE": targetFields + ["reason"],
        "QUEST_GUIDE": ["teamId", "questKey", "reason"], "LOCATION_REBIND": ["questKey", "nodeId", "reason"],
        "STAFF_TEAM_EXIT": ["teamId", "reason"],
        "MANUAL_BEGIN": ["highWaterHash", "configHash", "unknownRequests", "offlineStartedAt", "reason"],
        "MANUAL_IMPORT": ["signatureId"], "STAFF_MANUAL_SIGN": ["sequence", "occurredAt", "signedAction"],
        "MANUAL_REVIEW": ["reviewKind"]
    ]

    public struct Field: Equatable, Identifiable {
        public let key: String
        public let maxLength: Int
        public let multiline: Bool
        public let boolean: Bool
        public let timestamp: Bool
        /// Option codes for a picker (signedAction / reviewKind / questKey / guide options); empty for free text.
        public let options: [String]
        /// Server option labels shown verbatim (guide options, questKey); empty → the app localizes `options`.
        public var optionLabels: [String] = []
        /// Set for a guide answer field (MP `guideFields` label parts).
        public var guide: GuideLabel?
        public var id: String { key }
    }

    /// MP `guideFields` label: `(title || 基本题/问答题/排序题/连线题/分类题) · detail`.
    public struct GuideLabel: Equatable {
        /// basic / qa / sort / match / classify.
        public let kind: String
        /// Server title or prompt, if any.
        public let title: String?
        public let detail: GuideDetail
    }

    public enum GuideDetail: Equatable {
        /// 队伍填写的答案
        case typed
        /// 队伍选择的选项
        case picked
        /// option / left item / classify item label (server text)
        case item(String)
        /// 第 n 项 (1-based)
        case position(Int)
    }

    /// MP generic-director-ops.js `genericOpsError` messages, as stable codes the app localizes.
    public enum Failure: Error, Equatable {
        /// 请确认 + the field label.
        case confirm(String)
        case notOffered, nonce, target, signedAction, originalPair, anchorStale, hashes, unknownFormat, unknownItems, anchorFirst, reviewKind
        /// 请先读取本局题型并选择指导任务 / 本任务没有可指导的题型 / 请完整录入队伍实际作答 / 排序或连线不能重复选择同一项
        case guideTask, guideEmpty, guideIncomplete, guideDuplicate
    }

    /// MP `genericOpsActions`: nothing unless run.authorityEpoch ≥ 1, an integer revision and an action array.
    public static func offered(_ control: PlayWireValue) -> [String] {
        guard let epoch = control["run"]["authorityEpoch"].integer, epoch >= 1, control["revision"].integer != nil,
              let offered = control["availableActions"].array else { return [] }
        var seen = Set<String>()
        return offered.compactMap(\.text).filter { actions.contains($0) && seen.insert($0).inserted }
    }

    /// MP `isGuide`: QUEST_GUIDE, or STAFF_MANUAL_SIGN signing a QUEST_GUIDE.
    public static func isGuide(_ action: String, draft: [String: String]) -> Bool {
        action == "QUEST_GUIDE" || action == "STAFF_MANUAL_SIGN" && draft["signedAction"] == "QUEST_GUIDE"
    }

    /// MP `genericOpsFields` keys and attributes, then `guideFields` for a guided action.
    public static func fields(action: String, draft: [String: String], control: PlayWireValue? = nil) -> [Field] {
        // MP: with guideTasks, questKey is a picker over the task keys (labels are the keys).
        let tasks: [PlayWireValue]? = isGuide(action, draft: draft) ? control?["guideTasks"].array : nil
        let questKeys: [String]? = tasks.map { list in list.compactMap { task in task["questKey"].text } }
        let base: [Field] = baseFields(action: action, draft: draft).map { field in
            guard field.key == "questKey", let questKeys else { return field }
            return Field(key: field.key, maxLength: field.maxLength, multiline: false, boolean: false, timestamp: false,
                         options: questKeys, optionLabels: questKeys)
        }
        guard isGuide(action, draft: draft) else { return base }
        return base + guideFields(guideTask(draft, control: control), draft: draft)
    }

    static func baseFields(action: String, draft: [String: String]) -> [Field] {
        var keys = schemas[action] ?? (actions.contains(action) ? ["reason"] : [])
        if action == "MANUAL_BEGIN" { keys = ["unknownRequests", "reason"] }
        if action == "STAFF_MANUAL_SIGN" {
            keys += (schemas[draft["signedAction"] ?? ""] ?? []) + ["originalRequestId", "originalExpectedRevision"]
        }
        if action == "MANUAL_REVIEW" {
            switch draft["reviewKind"] ?? "" {
            case "SIGNATURE": keys += ["signatureId", "reason"]
            case "REQUEST": keys += ["memberId", "requestId", "acceptLateConflict", "reason"]
            default: keys += ["reason"]
            }
        }
        return keys.map { key in
            Field(key: key, maxLength: key == "unknownRequests" ? 20_000 : key == "reason" ? 200 : 128,
                  multiline: key == "reason" || key == "unknownRequests", boolean: key == "acceptLateConflict",
                  timestamp: timestampKeys.contains(key),
                  options: key == "signedAction" ? signedActions : key == "reviewKind" ? reviewKinds : [])
        }
    }

    /// MP `genericOpsPayload`. `draft` holds trimmed-or-raw text; timestamps are epoch-ms digits; booleans are "true".
    public static func payload(action: String, draft: [String: String], control: PlayWireValue?) throws -> [String: PlayWireValue] {
        guard actions.contains(action) || action == "ARRIVAL_ATTEST" else { throw Failure.notOffered }
        if action == "STAFF_MANUAL_SIGN" {
            let signed = draft["signedAction"] ?? ""
            guard signedActions.contains(signed) else { throw Failure.signedAction }
            let sequence = try integer(draft, "sequence", 1)
            let occurredAt = try integer(draft, "occurredAt", 1)
            let inner = try payload(action: signed, draft: draft, control: control)
            var out: [String: PlayWireValue] = [
                "sequence": .integer(Int64(sequence)),
                "occurredAt": .integer(Int64(occurredAt)),
                "command": .object(["action": .string(signed), "payload": .object(inner)])
            ]
            if let original = try text(draft, "originalRequestId", 64, optional: true) {
                out["originalRequestId"] = .string(original)
                out["originalExpectedRevision"] = .integer(Int64(try integer(draft, "originalExpectedRevision", 0)))
            } else if !(draft["originalExpectedRevision"] ?? "").isEmpty {
                throw Failure.originalPair
            }
            return out
        }
        if action == "MANUAL_IMPORT" {
            let signature = try text(draft, "signatureId", 128) ?? ""
            return ["signatureId": .string(signature)]
        }
        var out: [String: PlayWireValue] = [:]
        if action.hasPrefix("ARRIVAL_") { out = try target(draft) }
        if action == "ARRIVAL_CONFIRM" {
            let nonce = try text(draft, "nonce", 64)!
            guard nonce.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else { throw Failure.nonce }
            out["nonce"] = .string(nonce)
            return out
        }
        out["reason"] = .string(try text(draft, "reason", 200)!)
        if action == "ACT_UNLOCK" { out["actKey"] = .string(try text(draft, "actKey", 64)!) }
        if action == "QUEST_GUIDE" || action == "STAFF_TEAM_EXIT" { out["teamId"] = .integer(Int64(try integer(draft, "teamId", 1))) }
        if action == "QUEST_GUIDE" || action == "LOCATION_REBIND" { out["questKey"] = .string(try text(draft, "questKey", 64)!) }
        if action == "QUEST_GUIDE" { out["answers"] = .object(try guideAnswers(draft, control: control)) }
        if action == "LOCATION_REBIND" { out["nodeId"] = .integer(Int64(try integer(draft, "nodeId", 1))) }
        if action == "MANUAL_BEGIN" { try manualBegin(into: &out, draft: draft, control: control) }
        if action == "MANUAL_REVIEW" {
            switch draft["reviewKind"] ?? "" {
            case "HIGH_WATER": out["acceptCurrentHighWater"] = .bool(true)
            case "SIGNATURE": out["signatureId"] = .string(try text(draft, "signatureId", 128)!)
            case "REQUEST":
                out["memberId"] = .integer(Int64(try integer(draft, "memberId", 1)))
                out["requestId"] = .string(try text(draft, "requestId", 64)!)
                if draft["acceptLateConflict"] == "true" { out["acceptLateConflict"] = .bool(true) }
            default: throw Failure.reviewKind
            }
        }
        return out
    }

    /// MP `genericOpsActions(...).map(irreversible)` + confirm copy: 此操作不可撤销 vs 将按本局规则核验并应用本次操作。
    public static func isIrreversible(_ action: String) -> Bool { irreversible.contains(action) }

    /// MP director.js `openGenericOps` ledger rows from `shared/export` `manual`:
    /// 「签名 id · 序号 n · ACTION · 已使用|待处理」 then 「会员 m · 操作 r · outcome」. Returned as raw parts; the app formats.
    public static func ledgerRows(_ export: PlayWireValue) -> [LedgerRow] {
        let manual = export["manual"]
        let signatures = (manual["signatures"].object ?? [:]).sorted { $0.key < $1.key }.map { id, signature in
            LedgerRow.signature(id: id, sequence: signature["sequence"].integer, action: signature["command"]["action"].text ?? "",
                                used: signature["used"].bool == true)
        }
        let unknown = (manual["unknownRequests"].array ?? []).map { item in
            LedgerRow.request(memberID: item["memberId"].integer, requestID: item["requestId"].text ?? "", outcome: item["outcome"].text ?? "")
        }
        return signatures + unknown
    }

    public enum LedgerRow: Equatable, Hashable {
        case signature(id: String, sequence: Int?, action: String, used: Bool)
        case request(memberID: Int?, requestID: String, outcome: String)
    }

    /// Body admission for the composition firewall: the exact `submitSharedRunAction` / `submitPlanFallback` envelope.
    public static func acceptsCommandBody(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["activityId", "nodeId", "expectedRevision", "requestId", "action", "payload"],
              object["nodeId"] is NSNull,
              let activity = object["activityId"] as? NSNumber, activity.intValue > 0, CFGetTypeID(activity) != CFBooleanGetTypeID(),
              let revision = object["expectedRevision"] as? NSNumber, revision.intValue >= 0, CFGetTypeID(revision) != CFBooleanGetTypeID(),
              let requestID = object["requestId"] as? String, requestID.range(of: "^[A-Za-z0-9_-]{8,64}$", options: .regularExpression) != nil,
              let action = object["action"] as? String, commandActions.contains(action),
              object["payload"] is [String: Any] else { return false }
        return true
    }

    // MARK: MP helpers

    /// MP `integer(draft, key, minimum)`.
    static func integer(_ draft: [String: String], _ key: String, _ minimum: Int) throws -> Int {
        let raw = (draft[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let value = Int(raw), abs(value) <= 9_007_199_254_740_991, value >= minimum else { throw Failure.confirm(key) }
        return value
    }

    /// MP `text(draft, key, maximum, optional)`: trimmed, 1…maximum characters, no control characters.
    static func text(_ draft: [String: String], _ key: String, _ maximum: Int, optional: Bool = false) throws -> String? {
        let value = (draft[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if optional && value.isEmpty { return nil }
        guard !value.isEmpty, value.count <= maximum,
              !value.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }) else { throw Failure.confirm(key) }
        return value
    }

    /// MP `target(draft)`: a team plus either a quest or a FACILITY/PLAN operation, never both.
    static func target(_ draft: [String: String]) throws -> [String: PlayWireValue] {
        var out: [String: PlayWireValue] = ["teamId": .integer(Int64(try integer(draft, "teamId", 1)))]
        let quest = try text(draft, "questKey", 64, optional: true)
        let kind = try text(draft, "operationKind", 64, optional: true)
        let operation = try text(draft, "operationKey", 64, optional: true)
        if let quest {
            guard kind == nil, operation == nil else { throw Failure.target }
            out["questKey"] = .string(quest)
        } else {
            guard let kind, ["FACILITY", "PLAN"].contains(kind), let operation else { throw Failure.target }
            out["operationKind"] = .string(kind); out["operationKey"] = .string(operation)
        }
        return out
    }

    // MARK: MP guide answer form

    /// MP `guideTask`: the `control.guideTasks` entry whose questKey is the trimmed draft questKey.
    static func guideTask(_ draft: [String: String], control: PlayWireValue?) -> PlayWireValue? {
        let key = (draft["questKey"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return control?["guideTasks"].array?.first { $0["questKey"].text == key }
    }

    private static func options(_ list: PlayWireValue) -> (ids: [String], labels: [String]) {
        let items = list.array ?? []
        return (items.map { $0["id"].text ?? "" }, items.map { $0["label"].text ?? "" })
    }

    private static func guideField(_ key: String, _ label: GuideLabel, _ list: PlayWireValue = .null, boolean: Bool = false) -> Field {
        let (ids, labels) = options(list)
        return Field(key: key, maxLength: 512, multiline: false, boolean: boolean, timestamp: false,
                     options: ids, optionLabels: labels, guide: label)
    }

    /// MP `guideFields(task, draft)`.
    public static func guideFields(_ task: PlayWireValue?, draft: [String: String]) -> [Field] {
        guard let task, task.object != nil else { return [] }
        var fields: [Field] = []
        for kind in ["basic", "qa"] {
            let question = task[kind]
            guard question.object != nil else { continue }
            let title = question["title"].text.flatMap { $0.isEmpty ? nil : $0 }
            let mode = question["mode"].text
            if mode == "TYPE" {
                fields.append(guideField("guide_" + kind, GuideLabel(kind: kind, title: title, detail: .typed)))
            } else if mode == "PICK" && (kind == "basic" || question["multi"].bool == true) {
                for (index, option) in (question["options"].array ?? []).enumerated() {
                    fields.append(guideField("guide_\(kind)_\(index)", GuideLabel(kind: kind, title: title, detail: .item(option["label"].text ?? "")), boolean: true))
                }
            } else if mode == "PICK" {
                fields.append(guideField("guide_" + kind, GuideLabel(kind: kind, title: title, detail: .picked), question["options"]))
            }
        }
        for (kind, itemsKey, choicesKey) in [("sort", "items", "items"), ("match", "left", "right"), ("classify", "items", "bins")] {
            let question = task[kind]
            guard question.object != nil else { continue }
            let prompt = question["prompt"].text.flatMap { $0.isEmpty ? nil : $0 }
            for (index, item) in (question[itemsKey].array ?? []).enumerated() {
                let detail: GuideDetail = kind == "sort" ? .position(index + 1) : .item(item["label"].text ?? "")
                fields.append(guideField("guide_\(kind)_\(index)", GuideLabel(kind: kind, title: prompt, detail: detail), question[choicesKey]))
            }
        }
        return fields
    }

    /// MP `guideAnswers(draft, control)`. Booleans are "true" in the draft.
    static func guideAnswers(_ draft: [String: String], control: PlayWireValue?) throws -> [String: PlayWireValue] {
        guard let task = guideTask(draft, control: control) else { throw Failure.guideTask }
        let fields = guideFields(task, draft: draft)
        guard !fields.isEmpty else { throw Failure.guideEmpty }
        func selected(_ key: String) throws -> String {
            let value = (draft[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let field = fields.first(where: { $0.key == key }), !value.isEmpty, value.count <= field.maxLength,
                  field.options.isEmpty || field.options.contains(value) else { throw Failure.guideIncomplete }
            return value
        }
        func picked(_ kind: String, _ question: PlayWireValue) throws -> [String] {
            let ids = (question["options"].array ?? []).enumerated()
                .filter { draft["guide_\(kind)_\($0.offset)"] == "true" }
                .map { $0.element["id"].text ?? "" }
            guard !ids.isEmpty else { throw Failure.guideIncomplete }
            return ids
        }
        func distinct(_ values: [String]) throws -> [String] {
            guard Set(values).count == values.count else { throw Failure.guideDuplicate }
            return values
        }
        var answers: [String: PlayWireValue] = [:]
        let basic = task["basic"]
        if basic.object != nil {
            if basic["mode"].text == "PICK" {
                answers["answer"] = .string(try picked("basic", basic).joined())
            } else {
                answers["answer"] = .string(try selected("guide_basic"))
            }
        }
        let qa = task["qa"]
        if qa.object != nil {
            if qa["mode"].text == "TYPE" {
                answers["qa"] = .object(["input": .string(try selected("guide_qa"))])
            } else if qa["multi"].bool == true {
                answers["qa"] = .object(["optionIds": .array(try picked("qa", qa).map(PlayWireValue.string))])
            } else {
                answers["qa"] = .object(["optionId": .string(try selected("guide_qa"))])
            }
        }
        let sort = task["sort"]
        if sort.object != nil {
            let order = try distinct((sort["items"].array ?? []).indices.map { try selected("guide_sort_\($0)") })
            answers["sort"] = .object(["order": .array(order.map(PlayWireValue.string))])
        }
        let match = task["match"]
        if match.object != nil {
            let left = match["left"].array ?? []
            let right = try distinct(left.indices.map { try selected("guide_match_\($0)") })
            let pairs: [PlayWireValue] = zip(left, right).map { pair in PlayWireValue.array([.string(pair.0["id"].text ?? ""), .string(pair.1)]) }
            answers["match"] = .object(["pairs": .array(pairs)])
        }
        let classify = task["classify"]
        if classify.object != nil {
            var placement: [String: PlayWireValue] = [:]
            for (index, item) in (classify["items"].array ?? []).enumerated() {
                placement[item["id"].text ?? ""] = .string(try selected("guide_classify_\(index)"))
            }
            answers["classify"] = .object(["placement": .object(placement)])
        }
        return answers
    }

    /// MP `genericOpsPayload` MANUAL_BEGIN: hashes from the offline anchor (same epoch) or the export,
    /// the 待复查操作清单 JSON array, and `offlineStartedAt` only from the anchor.
    static func manualBegin(into out: inout [String: PlayWireValue], draft: [String: String], control: PlayWireValue?) throws {
        let anchor = control?["offlineAnchor"].object != nil ? control?["offlineAnchor"] : nil
        if let anchor {
            guard anchor["epoch"].integer == control?["run"]["authorityEpoch"].integer, let at = anchor["at"].integer, at >= 1 else { throw Failure.anchorStale }
        }
        let high: String?
        let config: String?
        if let anchor {
            high = anchor["highWaterHash"].text
            config = anchor["configHash"].text
        } else {
            high = draft["highWaterHash"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            config = draft["configHash"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let high, let config, [high, config].allSatisfy({ $0.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil }) else { throw Failure.hashes }
        out["highWaterHash"] = .string(high); out["configHash"] = .string(config)
        let raw = (draft["unknownRequests"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = raw.data(using: .utf8), let parsed = try? JSONSerialization.jsonObject(with: data) else { throw Failure.unknownFormat }
        guard let list = parsed as? [Any], list.count <= 100 else { throw Failure.unknownItems }
        var items: [PlayWireValue] = []
        for element in list {
            guard let item = element as? [String: Any], Set(item.keys) == ["memberId", "requestHash", "requestId"],
                  let member = item["memberId"] as? NSNumber, CFGetTypeID(member) != CFBooleanGetTypeID(),
                  let memberID = Int(exactly: member.doubleValue), memberID >= 1, memberID <= 9_007_199_254_740_991,
                  let requestID = item["requestId"] as? String, !requestID.isEmpty, requestID.count <= 64,
                  let hash = item["requestHash"] as? String, hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
            else { throw Failure.unknownItems }
            items.append(.object(["memberId": .integer(Int64(memberID)), "requestId": .string(requestID), "requestHash": .string(hash)]))
        }
        out["unknownRequests"] = .array(items)
        if let at = anchor?["at"].integer {
            out["offlineStartedAt"] = .integer(Int64(at))
        } else if !(draft["offlineStartedAt"] ?? "").isEmpty {
            throw Failure.anchorFirst
        }
    }
}

extension PlayExperienceService {
    /// MP director.js `executeAction(action, payload)` for a 通用玩法 action: `POST /api/game/session/command`
    /// `{activityId, nodeId: null, expectedRevision, requestId, action, payload}`. APPLIED / PENDING is accepted; anything
    /// else is a refusal with the server reason.
    public func submitSharedRunAction(activityID: Int, expectedRevision: Int, action: String, payload: [String: PlayWireValue],
                                      requestID: String = UUID().uuidString, token: String) async throws -> String {
        guard activityID > 0, expectedRevision >= 0, PlaySharedRunOps.commandActions.contains(action),
              requestID.range(of: "^[A-Za-z0-9_-]{8,64}$", options: .regularExpression) != nil else {
            throw PlayExperienceError.invalidAction
        }
        let body: [String: PlayWireValue] = [
            "activityId": .integer(Int64(activityID)),
            "nodeId": .null,
            "expectedRevision": .integer(Int64(expectedRevision)),
            "requestId": .string(requestID),
            "action": .string(action),
            "payload": .object(payload)
        ]
        let raw = try await request("api/game/session/command", json: body, capability: .directorCommands, token: token)
        let outcome = raw["outcome"].text ?? ""
        guard ["APPLIED", "PENDING"].contains(outcome) else { throw PlayExperienceError.rejected(409, raw["reason"].text ?? raw["msg"].text) }
        return outcome
    }
}
