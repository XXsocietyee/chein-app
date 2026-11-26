import Foundation

/// CLB-G13a: port of the MP 通用玩法现场运营 form (`pages/club/utils/generic-director-ops.js`
/// `genericOpsActions` / `genericOpsFields` / `genericOpsPayload`) and its submit
/// (`pages/club/topic-detail/director.js confirmGenericOps` → `executeAction(action, payload)` →
/// `POST /api/game/session/command`, the same envelope `PLAN_FALLBACK` uses in `PlayDirectorPlanFallback.swift`).
///
/// Not ported: the 工作人员指导完成 answer form (`guideFields` / `guideAnswers`, which reads `control.guideTasks`).
/// `QUEST_GUIDE` and the signed `QUEST_GUIDE` stay out of `formActions` / `signedActions` and keep the director page.
public enum PlaySharedRunOps {
    /// MP generic-director-ops.js `labels` key order (the native action list order).
    public static let actions = ["ACT_UNLOCK", "ARRIVAL_CONFIRM", "ARRIVAL_REVOKE", "RUN_PAUSE", "RUN_RESUME", "RUN_INTERRUPT",
                                 "RUN_CANCEL", "MANUAL_BEGIN", "STAFF_MANUAL_SIGN", "MANUAL_IMPORT", "MANUAL_REVIEW",
                                 "AUTHORITY_RESUME", "QUEST_GUIDE", "LOCATION_REBIND", "STAFF_TEAM_EXIT"]
    /// Actions that open the native form. `QUEST_GUIDE` needs the answer form, which is not ported.
    public static let formActions: Set<String> = Set(actions).subtracting(["QUEST_GUIDE"])
    /// MP `irreversible`: the confirm says 此操作不可撤销.
    public static let irreversible: Set<String> = ["RUN_INTERRUPT", "RUN_CANCEL", "MANUAL_IMPORT", "MANUAL_REVIEW", "STAFF_TEAM_EXIT", "QUEST_GUIDE", "ACT_UNLOCK"]
    /// MP director.js `openGenericOps`: these read the shared export first (ledger rows, hashes, next sequence).
    public static let ledgerActions: Set<String> = ["MANUAL_BEGIN", "STAFF_MANUAL_SIGN", "MANUAL_IMPORT", "MANUAL_REVIEW"]
    /// MP `choices.signedAction` without `QUEST_GUIDE` (answer form not ported).
    public static let signedActions = ["ARRIVAL_CONFIRM", "ARRIVAL_ATTEST"]
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
        /// Option codes for a picker (signedAction / reviewKind); empty for free text.
        public let options: [String]
        public var id: String { key }
    }

    /// MP generic-director-ops.js `genericOpsError` messages, as stable codes the app localizes.
    public enum Failure: Error, Equatable {
        /// 请确认 + the field label.
        case confirm(String)
        case notOffered, nonce, target, signedAction, originalPair, anchorStale, hashes, unknownFormat, unknownItems, anchorFirst, reviewKind
    }

    /// MP `genericOpsActions`: nothing unless run.authorityEpoch ≥ 1, an integer revision and an action array.
    public static func offered(_ control: PlayWireValue) -> [String] {
        guard let epoch = control["run"]["authorityEpoch"].integer, epoch >= 1, control["revision"].integer != nil,
              let offered = control["availableActions"].array else { return [] }
        var seen = Set<String>()
        return offered.compactMap(\.text).filter { actions.contains($0) && seen.insert($0).inserted }
    }

    /// MP `genericOpsFields` keys and attributes (without the guide answer fields).
    public static func fields(action: String, draft: [String: String]) -> [Field] {
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
        if action == "STAFF_TEAM_EXIT" { out["teamId"] = .integer(Int64(try integer(draft, "teamId", 1))) }
        if action == "LOCATION_REBIND" {
            out["questKey"] = .string(try text(draft, "questKey", 64)!)
            out["nodeId"] = .integer(Int64(try integer(draft, "nodeId", 1)))
        }
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
