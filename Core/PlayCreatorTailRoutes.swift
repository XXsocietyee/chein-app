import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WP-02 play/creator tail on top of `PlayerGapService`: the author's content audit timeline and appeal
/// (`subpackageA/pages/myproject` + `subpackageA/utils/audit-timeline.js`), the original-run guard appeal
/// (`pages/play/utils/guard-appeal.js`) and the club share-edition empty reason
/// (`pages/club/utils/edition-empty-reason.js`). One request per method, no retry.
extension PlayerGapService {
    /// Non-money routes on the player play grant (`ReviewedProductionGateLeases.playPaths`).
    public static let creatorTailPaths: Set<String> = [
        "api/audit/timeline", "api/audit/appeal", "api/audit/appeal/receipt",
        "api/audit/guard/reference", "api/audit/guard/appeal", "api/audit/guard/appeal/receipt"
    ]
    /// Compensation editions read. Admitted only where `ReviewedAreaSwitch.moneyPayments` opens (TEST/DEBUG hosts).
    public static let editionEmptyReasonPath = "api/club-compensation/editions/empty-reason"

    // MARK: content audit (myproject)

    /// `loadAudit`: GET `{bizType, bizId}`.
    public func auditTimeline(_ target: CreatorAuditTarget) async -> PlayerGapReply {
        guard let request = try? makeRequest("api/audit/timeline", method: "GET", query: ["bizType": target.bizType, "bizId": target.bizID]) else { return .unknown }
        return await send(request)
    }

    /// `appealAudit`: POST JSON, the frozen command exactly as saved.
    public func submitAuditAppeal(_ command: CreatorAuditAppealCommand) async -> PlayerGapReply {
        guard let request = try? makeRequest("api/audit/appeal", method: "POST", json: command.body) else { return .unknown }
        return await send(request)
    }

    /// `recoverAuditAppeal`: GET `{bizType, bizId, requestId}`.
    public func auditAppealReceipt(_ command: CreatorAuditAppealCommand) async -> PlayerGapReply {
        guard let request = try? makeRequest("api/audit/appeal/receipt", method: "GET",
                                             query: ["bizType": command.bizType, "bizId": command.bizID, "requestId": command.requestID]) else { return .unknown }
        return await send(request)
    }

    // MARK: original-run guard appeal (play)

    /// `read()` without a command: GET `{guardLogId, arrivalRequestId}`.
    public func guardAppealReference(_ reference: PlayGuardAppealReference) async -> PlayerGapReply {
        guard let request = try? makeRequest("api/audit/guard/reference", method: "GET",
                                             query: ["guardLogId": reference.guardLogID, "arrivalRequestId": reference.arrivalRequestID]) else { return .unknown }
        return await send(request)
    }

    /// `submit()`: POST JSON `{guardLogId, arrivalRequestId, requestId, reason, evidence: null, attachments: []}`.
    public func submitGuardAppeal(_ command: PlayGuardAppealCommand) async -> PlayerGapReply {
        guard let request = try? makeRequest("api/audit/guard/appeal", method: "POST", json: command.body) else { return .unknown }
        return await send(request)
    }

    /// `read()` with a command: GET `{guardLogId, requestId}`.
    public func guardAppealReceipt(_ command: PlayGuardAppealCommand) async -> PlayerGapReply {
        guard let request = try? makeRequest("api/audit/guard/appeal/receipt", method: "GET",
                                             query: ["guardLogId": command.guardLogID, "requestId": command.requestID]) else { return .unknown }
        return await send(request)
    }

    // MARK: club share editions

    /// `loadShareEditionEmptyReason`: POST JSON `{clubId}`. Nil when the reason cannot be confirmed.
    public func editionEmptyReason(clubID: Int) async -> ClubEditionEmptyReason? {
        guard clubID > 0,
              let request = try? makeRequest(Self.editionEmptyReasonPath, method: "POST", json: ["clubId": .integer(Int64(clubID))]),
              case .ok(let data, _) = await send(request) else { return nil }
        return ClubEditionEmptyReason(data, clubID: clubID)
    }
}

/// `edition-empty-reason.js`. The reason comes only from the server's `reasonCode` for the same club.
public enum ClubEditionEmptyReason: String, CaseIterable, Equatable {
    case notUndertaken = "NOT_UNDERTAKEN", undertakenNotOnSale = "UNDERTAKEN_NOT_ON_SALE"
    case noPermission = "NO_PERMISSION", hasEditions = "HAS_EDITIONS"
    public init?(_ raw: PlayWireValue, clubID: Int) {
        guard raw.object != nil, Self.idText(raw["clubId"]) == String(clubID),
              let code = raw["reasonCode"].text, let value = Self(rawValue: code) else { return nil }
        self = value
    }
    /// Only `HAS_EDITIONS` offers a reload.
    public var offersRetry: Bool { self == .hasEditions }
    static func idText(_ value: PlayWireValue) -> String? {
        if let number = value.integer { return String(number) }
        return value.text
    }
}

// MARK: - content audit

/// `audit-timeline.js projectTarget/templateTarget`. Ids stay decimal strings, as the mini-program sends them.
public struct CreatorAuditTarget: Codable, Equatable, Hashable {
    public let bizType: String
    public let bizID: String
    public init?(bizType: String, bizID: String) {
        guard ["TOPIC", "ACTIVITY", "TEMPLATE", "TEMPLATE_LIBRARY"].contains(bizType), PlayGuardAppealReference.positiveID(bizID) else { return nil }
        self.bizType = bizType; self.bizID = bizID
    }
    /// Project cards (topic / activity) offer the audit record only when rejected or offline.
    public static func project(id: Int, bizType: String, state: String?) -> CreatorAuditTarget? {
        guard id > 0, state == "rejected" || state == "offline" else { return nil }
        switch bizType {
        case "topic": return .init(bizType: "TOPIC", bizID: String(id))
        case "activity": return .init(bizType: "ACTIVITY", bizID: String(id))
        default: return nil
        }
    }
}

/// One round row of `GET /api/audit/timeline`. Labels are localized by the view from `kind` and `action`.
public struct CreatorAuditTimelineRow: Equatable, Identifiable {
    public enum Kind: String { case submit = "SUBMIT", report = "REPORT", appeal = "APPEAL" }
    public let id: String
    public let kind: Kind
    /// `SUBMIT`/`APPROVE`/`REJECT`/`REVERT`/`CANCEL`, or nil for an item problem row.
    public let action: String?
    /// Problem rows: `TOPIC`/`CHAPTER`/`NODE`/`TEMPLATE` or nil for other content.
    public let problemItemType: String?
    public let problemItemID: String?
    public let detail: String
}

public struct CreatorAuditTimeline: Equatable {
    public static let actions: Set<String> = ["SUBMIT", "APPROVE", "REJECT", "REVERT", "CANCEL"]
    public static let appealStates: Set<String> = ["SUBMITTED", "REVIEWING", "ACCEPTED", "REJECTED", "WITHDRAWN"]
    public let rows: [CreatorAuditTimelineRow]
    /// Raw `appeal.state`; nil when there is no appeal. An unknown state is kept and shown as a dash.
    public let appealState: String?
    public let canAppeal: Bool

    public init(_ data: PlayWireValue) {
        var rows: [CreatorAuditTimelineRow] = []
        for (r, round) in (data["rounds"].array ?? []).enumerated() {
            let kind = round["kind"].text.flatMap(CreatorAuditTimelineRow.Kind.init(rawValue:)) ?? .submit
            for (i, record) in (round["timeline"].array ?? []).enumerated() {
                guard let action = record["action"].text, Self.actions.contains(action) else { continue }
                let labels = (record["reasonLabels"].array ?? []).compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "、")
                let parts = [labels, record["reasonText"].text ?? "", Self.scalar(record["createTime"]) ?? ""]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                let key = Self.scalar(record["id"]) ?? String(i)
                rows.append(.init(id: "\(r)-\(key)", kind: kind, action: action, problemItemType: nil, problemItemID: nil, detail: parts.joined(separator: " · ")))
            }
            for (i, problem) in (round["problems"].array ?? []).enumerated() {
                guard let text = problem["reasonText"].text else { continue }
                let type = problem["itemType"].text.flatMap { ["TOPIC", "CHAPTER", "NODE", "TEMPLATE"].contains($0) ? $0 : nil }
                let key = Self.scalar(problem["id"]) ?? String(i)
                rows.append(.init(id: "\(r)-problem-\(key)", kind: kind, action: nil, problemItemType: type,
                                  problemItemID: Self.scalar(problem["itemId"]), detail: text))
            }
        }
        self.rows = rows
        appealState = data["appeal"]["state"].text.flatMap { $0.isEmpty ? nil : $0 }
        canAppeal = data["canAppeal"].bool == true
    }
    public init(rows: [CreatorAuditTimelineRow], appealState: String?, canAppeal: Bool) {
        self.rows = rows; self.appealState = appealState; self.canAppeal = canAppeal
    }
    static func scalar(_ value: PlayWireValue) -> String? {
        if let number = value.integer { return String(number) }
        if let text = value.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
        return nil
    }
    /// `validateReason`: 1 to 500 characters after trimming.
    public static func reasonValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 500
    }
}

/// The frozen `POST /api/audit/appeal` body. Attachments are de-duplicated trimmed refs; none is sent empty.
public struct CreatorAuditAppealCommand: Codable, Equatable {
    public let requestID: String
    public let bizType: String
    public let bizID: String
    public let reason: String
    public let attachments: [String]
    public init(requestID: String, target: CreatorAuditTarget, reason: String, attachments: [String] = []) {
        self.requestID = requestID; bizType = target.bizType; bizID = target.bizID; self.reason = reason
        var seen = Set<String>()
        self.attachments = attachments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    var body: [String: PlayWireValue] {
        ["requestId": .string(requestID), "bizType": .string(bizType), "bizId": .string(bizID),
         "reason": .string(reason), "attachments": .array(attachments.map(PlayWireValue.string))]
    }
    var valid: Bool { !requestID.isEmpty && requestID.count <= 64 && CreatorAuditTarget(bizType: bizType, bizID: bizID) != nil }
    public static func newRequestID() -> String { "appeal-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }

    /// `recoverAuditAppeal` match: only a FOUND receipt whose stored intent equals this command, for this owner.
    public func confirmedAppealID(in data: PlayWireValue, owner: Int) -> (appealID: String, appealState: String)? {
        let intent = data["intent"]
        guard data["state"].text == "FOUND", intent["version"].integer == 1, intent["memberId"].text == String(owner),
              intent["bizType"].text == bizType, intent["bizId"].text == bizID, intent["requestId"].text == requestID,
              intent["reason"].text == reason, intent["evidence"] == .null, intent.object?["evidence"] != nil,
              intent["attachments"].array.map({ $0.map(\.text) }) == attachments.map(Optional.some),
              let appealID = data["appealId"].text, PlayGuardAppealReference.positiveID(appealID),
              let task = data["taskId"].text, PlayGuardAppealReference.positiveID(task),
              let state = data["appealState"].text, CreatorAuditTimeline.appealStates.contains(state) else { return nil }
        return (appealID, state)
    }
}

// MARK: - guard appeal

/// `arrival-guard-view.js project` fields the appeal binds to. All ids are positive decimal strings.
public struct PlayGuardAppealReference: Codable, Equatable, Hashable {
    public let guardLogID: String
    public let routeSessionID: String
    public let nodeID: String
    public let arrivalRequestID: String
    public init?(guardLogID: String?, routeSessionID: String?, nodeID: Int, arrivalRequestID: String?) {
        guard let guardLogID, Self.positiveID(guardLogID), let routeSessionID, Self.positiveID(routeSessionID), nodeID > 0,
              let arrivalRequestID, arrivalRequestID.range(of: "^[A-Za-z0-9:_-]{1,80}$", options: .regularExpression) != nil else { return nil }
        self.guardLogID = guardLogID; self.routeSessionID = routeSessionID; self.nodeID = String(nodeID); self.arrivalRequestID = arrivalRequestID
    }
    /// `orient-score-view.js id`: a positive signed 64-bit decimal without sign or leading zeros.
    public static func positiveID(_ text: String) -> Bool {
        guard text.range(of: "^[1-9][0-9]{0,18}$", options: .regularExpression) != nil else { return false }
        return text.count < 19 || text <= "9223372036854775807"
    }
}

public struct PlayGuardAppealCommand: Codable, Equatable {
    public let guardLogID: String
    public let arrivalRequestID: String
    public let requestID: String
    public let reason: String
    var body: [String: PlayWireValue] {
        ["guardLogId": .string(guardLogID), "arrivalRequestId": .string(arrivalRequestID), "requestId": .string(requestID),
         "reason": .string(reason), "evidence": .null, "attachments": .array([])]
    }
}
