import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Money / Payout Gated Contracts

public struct PaymentReadinessStatus: Equatable, Sendable {
    public let ready: Bool
    public let message: String?

    public init(ready: Bool, message: String?) {
        self.ready = ready
        self.message = message
    }
}

public struct ClubPersonalSettlementItem: Equatable, Identifiable, Sendable {
    public let clubID: Int
    public let name: String

    public var id: Int { clubID }

    public init(clubID: Int, name: String) {
        self.clubID = clubID
        self.name = name
    }
}

// MARK: - Project Audit Timeline & Appeal

public struct AuditTimelineRow: Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let detail: String

    public init(id: String, label: String, detail: String) {
        self.id = id
        self.label = label
        self.detail = detail
    }
}

public struct AuditTimelineDetail: Equatable, Sendable {
    public let rows: [AuditTimelineRow]
    public let appealState: String?
    public let canAppeal: Bool

    public init(rows: [AuditTimelineRow], appealState: String?, canAppeal: Bool) {
        self.rows = rows
        self.appealState = appealState
        self.canAppeal = canAppeal
    }
}

public struct AuditAppealCommand: Codable, Equatable, Sendable {
    public let requestId: String
    public let bizType: String
    public let bizId: String
    public let reason: String
    public let attachments: [String]

    public init(requestId: String, bizType: String, bizId: String, reason: String, attachments: [String] = []) {
        self.requestId = requestId
        self.bizType = bizType
        self.bizId = bizId
        self.reason = reason
        self.attachments = attachments
    }
}

public struct AuditAppealDraft: Codable, Equatable, Sendable {
    public var reason: String
    public var attachments: [String]
    public var pending: Bool
    public var confirmed: Bool
    public var command: AuditAppealCommand?

    public init(reason: String = "", attachments: [String] = [], pending: Bool = false, confirmed: Bool = false, command: AuditAppealCommand? = nil) {
        self.reason = reason
        self.attachments = attachments
        self.pending = pending
        self.confirmed = confirmed
        self.command = command
    }
}

public struct AuditAppealReceipt: Equatable, Sendable {
    public let appealID: String
    public let taskID: String
    public let appealState: String

    public init(appealID: String, taskID: String, appealState: String) {
        self.appealID = appealID
        self.taskID = taskID
        self.appealState = appealState
    }
}

public enum AuditAppealValidation {
    public static let maxReasonLength = 500
    public static let validStates: Set<String> = ["SUBMITTED", "REVIEWING", "ACCEPTED", "REJECTED", "WITHDRAWN"]

    public static func validateReason(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "请写清申诉理由" }
        if trimmed.count > maxReasonLength { return "申诉理由不能超过 500 字" }
        return nil
    }

    public static func normalizeAttachments(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for item in values {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
            if result.count == 6 { break }
        }
        return result
    }
}

public final class AuditAppealStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static func storageKey(accountID: Int, bizType: String, bizID: String) -> String {
        "audit-appeal:\(accountID):\(bizType):\(bizID)"
    }

    public func load(accountID: Int, bizType: String, bizID: String) -> AuditAppealDraft? {
        guard accountID > 0, !bizType.isEmpty, !bizID.isEmpty,
              let data = defaults.data(forKey: Self.storageKey(accountID: accountID, bizType: bizType, bizID: bizID)) else { return nil }
        return try? JSONDecoder().decode(AuditAppealDraft.self, from: data)
    }

    public func save(_ draft: AuditAppealDraft, accountID: Int, bizType: String, bizID: String) throws {
        guard accountID > 0, !bizType.isEmpty, !bizID.isEmpty else { throw APIError.invalidRequest }
        let key = Self.storageKey(accountID: accountID, bizType: bizType, bizID: bizID)
        let encoded = try JSONEncoder().encode(draft)
        defaults.set(encoded, forKey: key)
        guard defaults.data(forKey: key) == encoded else {
            throw APIError.server(code: -1, message: "申诉草稿保存失败，请重试")
        }
    }
}

// MARK: - Play Guard Reference & Appeal

public struct PlayGuardReference: Equatable, Sendable {
    public let guardLogID: Int
    public let routeSessionID: Int
    public let nodeID: Int
    public let arrivalRequestID: String

    public init(guardLogID: Int, routeSessionID: Int, nodeID: Int, arrivalRequestID: String) {
        self.guardLogID = guardLogID
        self.routeSessionID = routeSessionID
        self.nodeID = nodeID
        self.arrivalRequestID = arrivalRequestID
    }
}

public struct PlayGuardEligibility: Equatable, Sendable {
    public let canSubmit: Bool
}

public struct PlayGuardAppealCommand: Codable, Equatable, Sendable {
    public let guardLogId: Int
    public let arrivalRequestId: String
    public let requestId: String
    public let reason: String
    public let attachments: [String]

    public init(guardLogId: Int, arrivalRequestId: String, requestId: String, reason: String, attachments: [String] = []) {
        self.guardLogId = guardLogId
        self.arrivalRequestId = arrivalRequestId
        self.requestId = requestId
        self.reason = reason
        self.attachments = attachments
    }
}

public struct PlayGuardAppealReceipt: Equatable, Sendable {
    public let decisionReason: String?
}

// MARK: - Club Editions Empty Reason

public enum ClubEditionEmptyReasonCode: String, Equatable, CaseIterable, Sendable {
    case notUndertaken = "NOT_UNDERTAKEN"
    case undertakenNotOnSale = "UNDERTAKEN_NOT_ON_SALE"
    case noPermission = "NO_PERMISSION"
    case hasEditions = "HAS_EDITIONS"

    public func title(chinese: Bool) -> String {
        switch self {
        case .notUndertaken:
            return chinese ? "本俱乐部还没有承接自由探索期次" : "This club hasn't undertaken any free-explore editions yet"
        case .undertakenNotOnSale:
            return chinese ? "已承接的期次还没有开售" : "Undertaken editions are not on sale yet"
        case .noPermission:
            return chinese ? "仅主理人或管理员可查看期次" : "Only club owners or admins can view editions"
        case .hasEditions:
            return chinese ? "期次列表已有更新" : "The editions list has updates"
        }
    }

    public func subtitle(chinese: Bool) -> String {
        switch self {
        case .notUndertaken, .undertakenNotOnSale:
            return ""
        case .noPermission:
            return chinese ? "期次与带票分享只对俱乐部负责人开放" : "Editions and ticket sharing are only open to club leads"
        case .hasEditions:
            return chinese ? "重新加载后可查看" : "Reload to view updated editions"
        }
    }

    public var allowsRetry: Bool { self == .hasEditions }
}

// MARK: - Club Lead Release Station & Unlock Chapter Receipt

public enum UnlockChapterReceiptOutcome: Equatable, Sendable {
    case applied(expectedChapterID: Int?, targetChapterID: Int?)
    case pendingConfirmation
    case conflicted(String)
}

// MARK: - Club / Merchant Direct Receivable Ledger

public enum ClubDirectLedgerScope: Equatable, Sendable {
    case club(clubID: Int, topicID: Int? = nil)
    case merchant(topicID: Int? = nil)
}

public enum ClubDirectLedgerStatus: String, Equatable, Sendable {
    case open = "OPEN"
    case settled = "SETTLED"
    case refundDue = "REFUND_DUE"
    case void = "VOID"
    case refunded = "REFUNDED"

    public func label(chinese: Bool) -> String {
        switch self {
        case .open: return chinese ? "待结清" : "Open"
        case .settled: return chinese ? "已结清" : "Settled"
        case .refundDue: return chinese ? "待退回" : "Refund due"
        case .void: return chinese ? "核销已撤销" : "Voided"
        case .refunded: return chinese ? "已退回" : "Refunded"
        }
    }
}

public struct ClubDirectLedgerRow: Equatable, Identifiable, Sendable {
    public let id: Int
    public let redemptionID: Int
    public let amountText: String
    public let claimNo: String
    public let status: ClubDirectLedgerStatus
    public let timeText: String
    public let voucher: String
}

public struct ClubDirectLedgerSummary: Equatable, Sendable {
    public let rows: [ClubDirectLedgerRow]
    public let activeCount: Int
    public let openTotalText: String
    public let settledTotalText: String
    public let refundDueTotalText: String
}

public enum ClubDirectLedgerParser {
    public static func parse(dataArray: [Any], scope: ClubDirectLedgerScope) -> ClubDirectLedgerSummary? {
        let filterTopicID: Int?
        let filterClubID: Int?
        switch scope {
        case .club(let clubID, let topicID):
            guard clubID > 0 else { return nil }
            if let topicID, topicID <= 0 { return nil }
            filterClubID = clubID
            filterTopicID = topicID
        case .merchant(let topicID):
            if let topicID, topicID <= 0 { return nil }
            filterClubID = nil
            filterTopicID = topicID
        }
        var seen: Set<Int> = []
        var openCents = 0
        var settledCents = 0
        var refundDueCents = 0
        var activeCount = 0
        var rows: [ClubDirectLedgerRow] = []

        for item in dataArray {
            guard let row = item as? [String: Any],
                  let id = positiveInt(row["id"]), seen.insert(id).inserted,
                  let redemptionID = positiveInt(row["redemptionId"]),
                  let topicID = positiveInt(row["topicId"]),
                  let payerClubID = positiveInt(row["payerClubId"]),
                  positiveInt(row["merchantMemberId"]) != nil,
                  let statusRaw = row["status"] as? String,
                  let status = ClubDirectLedgerStatus(rawValue: statusRaw),
                  let cents = parseCents(row["perHeadFeeSnapshot"]) else {
                return nil
            }
            if let filterTopicID, topicID != filterTopicID { return nil }
            if let filterClubID, payerClubID != filterClubID { return nil }

            if status == .open || status == .settled { activeCount += 1 }
            switch status {
            case .open: openCents += cents
            case .settled: settledCents += cents
            case .refundDue: refundDueCents += cents
            case .void, .refunded: break
            }
            let rawTime = (row["createTime"] as? String) ?? ""
            let timeText = rawTime.count >= 16 ? String(rawTime.prefix(16)).replacingOccurrences(of: "T", with: " ") : ""
            let voucher: String
            switch status {
            case .settled, .refundDue: voucher = (row["payVoucherNo"] as? String) ?? ""
            case .refunded: voucher = (row["refundVoucherNo"] as? String) ?? ""
            case .open, .void: voucher = ""
            }
            rows.append(ClubDirectLedgerRow(
                id: id,
                redemptionID: redemptionID,
                amountText: formatYuan(cents: cents),
                claimNo: claimNumber(row["claimId"]),
                status: status,
                timeText: timeText,
                voucher: voucher
            ))
        }

        return ClubDirectLedgerSummary(
            rows: rows,
            activeCount: activeCount,
            openTotalText: formatYuan(cents: openCents),
            settledTotalText: formatYuan(cents: settledCents),
            refundDueTotalText: formatYuan(cents: refundDueCents)
        )
    }

    private static func positiveInt(_ raw: Any?) -> Int? {
        if let int = raw as? Int { return int > 0 ? int : nil }
        if let num = raw as? NSNumber {
            let val = num.intValue
            return Double(val) == num.doubleValue && val > 0 ? val : nil
        }
        if let str = raw as? String, str.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil {
            return Int(str)
        }
        return nil
    }

    private static func claimNumber(_ raw: Any?) -> String {
        if let int = raw as? Int, int > 0 { return String(int) }
        guard let str = raw as? String, str.range(of: "^[0-9]+$", options: .regularExpression) != nil else { return "" }
        let trimmed = str.drop(while: { $0 == "0" })
        guard !trimmed.isEmpty, trimmed.count < 19 || (trimmed.count == 19 && String(trimmed) <= "9223372036854775807") else { return "" }
        return str
    }

    private static func parseCents(_ raw: Any?) -> Int? {
        guard let raw else { return nil }
        let text: String
        if let str = raw as? String { text = str }
        else if let num = raw as? NSNumber { text = num.stringValue }
        else { return nil }
        guard text.range(of: "^[0-9]+(\\.[0-9]{1,2})?$", options: .regularExpression) != nil else { return nil }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard let whole = Int(parts[0]) else { return nil }
        let frac: Int
        if parts.count == 2 {
            let padded = parts[1].count == 1 ? "\(parts[1])0" : String(parts[1])
            guard let f = Int(padded) else { return nil }
            frac = f
        } else {
            frac = 0
        }
        return whole * 100 + frac
    }

    private static func formatYuan(cents: Int) -> String {
        String(format: "¥%.2f", Double(cents) / 100.0)
    }
}

// MARK: - Unified HTTP Client

public struct Sweep2Client: Sendable {
    public let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let tokenProvider: @Sendable () -> String?

    public init(configuration: APIConfiguration, transport: any HTTPTransport, tokenProvider: @escaping @Sendable () -> String?) {
        self.configuration = configuration
        self.transport = transport
        self.tokenProvider = tokenProvider
    }

    public var baseURL: URL { configuration.baseURL }

    // MARK: Money / Payout Gated Requests

    public func paymentReadiness() async throws -> PaymentReadinessStatus {
        guard !ReleaseMoneyWriteSwitch.blocks("/api/registration/payment-readiness") else {
            return PaymentReadinessStatus(ready: false, message: nil)
        }
        let payload = try await sendJSON(path: "api/registration/payment-readiness", body: [:])
        let data = (payload["data"] as? [String: Any]) ?? [:]
        return PaymentReadinessStatus(ready: (data["ready"] as? Bool) == true, message: data["message"] as? String)
    }

    public func personalSettlementClubs() async throws -> [ClubPersonalSettlementItem] {
        guard !ReleaseMoneyWriteSwitch.blocks("/api/club/settlement/mine") else {
            throw APIError.server(code: 403, message: "结算提现暂未开放")
        }
        let payload = try await sendJSON(path: "api/club/settlement/mine", body: [:])
        guard let list = payload["data"] as? [[String: Any]] else {
            throw APIError.decodingFailed
        }
        var items: [ClubPersonalSettlementItem] = []
        for row in list {
            guard let id = Self.positiveInt(row["clubId"]),
                  let name = (row["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                throw APIError.decodingFailed
            }
            items.append(ClubPersonalSettlementItem(clubID: id, name: name))
        }
        return items
    }

    // MARK: Project Audit Timeline & Appeal

    public func auditTimeline(bizType: String, bizID: String) async throws -> AuditTimelineDetail {
        let payload = try await sendGET(path: "api/audit/timeline", query: ["bizType": bizType, "bizId": bizID])
        guard let data = payload["data"] as? [String: Any] else { throw APIError.decodingFailed }
        let rows = Self.parseTimelineRows(data: data)
        let appealState = (data["appeal"] as? [String: Any])?["state"] as? String
        return AuditTimelineDetail(rows: rows, appealState: appealState, canAppeal: (data["canAppeal"] as? Bool) == true)
    }

    public func submitAuditAppeal(command: AuditAppealCommand) async throws -> String? {
        let jsonBody: [String: Any] = [
            "bizType": command.bizType,
            "bizId": command.bizId,
            "reason": command.reason,
            "evidence": NSNull(),
            "attachments": command.attachments,
            "requestId": command.requestId
        ]
        let payload = try await sendJSON(path: "api/audit/appeal", body: jsonBody)
        return payload["msg"] as? String
    }

    public func auditAppealReceipt(command: AuditAppealCommand, memberID: Int) async throws -> AuditAppealReceipt? {
        let payload = try await sendGET(path: "api/audit/appeal/receipt", query: [
            "bizType": command.bizType,
            "bizId": command.bizId,
            "requestId": command.requestId
        ])
        guard let data = payload["data"] as? [String: Any],
              (data["state"] as? String) == "FOUND",
              let appealID = data["appealId"] as? String, appealID.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil,
              let taskID = data["taskId"] as? String, taskID.range(of: "^[1-9][0-9]*$", options: .regularExpression) != nil,
              let appealState = data["appealState"] as? String, AuditAppealValidation.validStates.contains(appealState),
              let intent = data["intent"] as? [String: Any],
              (intent["version"] as? Int) == 1,
              (intent["memberId"] as? String) == String(memberID),
              (intent["bizType"] as? String) == command.bizType,
              (intent["bizId"] as? String) == command.bizId,
              (intent["requestId"] as? String) == command.requestId,
              (intent["reason"] as? String) == command.reason,
              intent["evidence"] is NSNull || intent["evidence"] == nil,
              let attachments = intent["attachments"] as? [String],
              attachments == command.attachments else {
            return nil
        }
        return AuditAppealReceipt(appealID: appealID, taskID: taskID, appealState: appealState)
    }

    // MARK: Play Guard Appeal

    public func guardReference(_ reference: PlayGuardReference) async throws -> PlayGuardEligibility {
        let payload = try await sendGET(path: "api/audit/guard/reference", query: [
            "guardLogId": String(reference.guardLogID),
            "arrivalRequestId": reference.arrivalRequestID
        ])
        guard let data = payload["data"] as? [String: Any],
              let origin = data["guardOrigin"] as? [String: Any],
              Self.positiveInt(origin["guardLogId"]) == reference.guardLogID,
              Self.positiveInt(origin["routeSessionId"]) == reference.routeSessionID else {
            throw APIError.server(code: 400, message: "原局引用不匹配")
        }
        return PlayGuardEligibility(canSubmit: (data["canSubmit"] as? Bool) == true)
    }

    public func submitGuardAppeal(command: PlayGuardAppealCommand) async throws {
        let body: [String: Any] = [
            "guardLogId": command.guardLogId,
            "arrivalRequestId": command.arrivalRequestId,
            "requestId": command.requestId,
            "reason": command.reason,
            "evidence": NSNull(),
            "attachments": command.attachments
        ]
        _ = try await sendJSON(path: "api/audit/guard/appeal", body: body)
    }

    public func guardAppealReceipt(command: PlayGuardAppealCommand, memberID: Int) async throws -> PlayGuardAppealReceipt? {
        let payload = try await sendGET(path: "api/audit/guard/appeal/receipt", query: [
            "guardLogId": String(command.guardLogId),
            "requestId": command.requestId
        ])
        guard let data = payload["data"] as? [String: Any],
              (data["state"] as? String) == "FOUND",
              let intent = data["intent"] as? [String: Any],
              (intent["requestId"] as? String) == command.requestId,
              (intent["memberId"] as? String) == String(memberID),
              (intent["bizId"] as? String) == String(command.guardLogId),
              (intent["reason"] as? String) == command.reason,
              intent["evidence"] is NSNull || intent["evidence"] == nil,
              let attachments = intent["attachments"] as? [String], attachments.isEmpty,
              let guardRef = intent["guardReference"] as? [String: Any],
              Self.positiveInt(guardRef["guardLogId"]) == command.guardLogId,
              (guardRef["arrivalRequestId"] as? String) == command.arrivalRequestId else {
            return nil
        }
        return PlayGuardAppealReceipt(decisionReason: data["decisionReason"] as? String)
    }

    // MARK: Club Compensation Editions Empty Reason

    public func editionsEmptyReason(clubID: Int) async throws -> ClubEditionEmptyReasonCode? {
        guard clubID > 0 else { throw APIError.invalidRequest }
        let payload = try await sendJSON(path: "api/club-compensation/editions/empty-reason", body: ["clubId": clubID])
        guard let data = payload["data"] as? [String: Any],
              Self.positiveInt(data["clubId"]) == clubID,
              let code = data["reasonCode"] as? String else { return nil }
        return ClubEditionEmptyReasonCode(rawValue: code)
    }

    // MARK: Club Lead Release Station & Unlock Chapter Receipt

    public func releaseStation(activityID: Int, memberID: Int, nodeID: Int) async throws -> String {
        guard activityID > 0, memberID > 0, nodeID > 0 else { throw APIError.invalidRequest }
        let payload = try await sendForm(path: "api/club/lead/release-station", fields: [
            ("activityId", String(activityID)),
            ("memberId", String(memberID)),
            ("nodeId", String(nodeID))
        ])
        return (payload["msg"] as? String) ?? "已放行，成员可以跳过这一站"
    }

    public func unlockChapterReceipt(activityID: Int, commandID: String, expectedChapterID: Int?, targetChapterID: Int?) async throws -> UnlockChapterReceiptOutcome {
        guard activityID > 0, !commandID.isEmpty else { throw APIError.invalidRequest }
        do {
            let payload = try await sendGET(path: "api/club/lead/unlock-chapter-receipt", query: [
                "activityId": String(activityID),
                "commandId": commandID
            ])
            guard let data = payload["data"] as? [String: Any],
                  (data["commandId"] as? String) == commandID else {
                return .pendingConfirmation
            }
            let returnedExpected = data["expectedChapterId"] as? Int
            let returnedTarget = data["targetChapterId"] as? Int
            if let expectedChapterID, returnedExpected != expectedChapterID { return .pendingConfirmation }
            if let targetChapterID, returnedTarget != targetChapterID { return .pendingConfirmation }
            return .applied(expectedChapterID: returnedExpected, targetChapterID: returnedTarget)
        } catch let error as APIError {
            if case .server(let code, let msg) = error {
                if code == 520 { return .pendingConfirmation }
                if code == 409 { return .conflicted(msg ?? "期望章节已变化") }
            }
            throw error
        }
    }

    // MARK: Club / Merchant Direct Receivable Ledger

    public func directLedger(scope: ClubDirectLedgerScope) async throws -> ClubDirectLedgerSummary {
        let path: String
        var query: [String: String] = [:]
        switch scope {
        case .club(let clubID, let topicID):
            guard clubID > 0 else { throw APIError.invalidRequest }
            path = "api/club-direct-merchant/club"
            query["clubId"] = String(clubID)
            if let topicID, topicID > 0 { query["topicId"] = String(topicID) }
        case .merchant(let topicID):
            path = "api/club-direct-merchant/merchant"
            if let topicID, topicID > 0 { query["topicId"] = String(topicID) }
        }
        let payload = try await sendGET(path: path, query: query)
        guard let list = payload["data"] as? [Any],
              let parsed = ClubDirectLedgerParser.parse(dataArray: list, scope: scope) else {
            throw APIError.decodingFailed
        }
        return parsed
    }

    // MARK: Shared Transport Helpers

    private func authorizedToken() throws -> String {
        guard let token = tokenProvider(), AuthRequestBuilder.isValidToken(token) else {
            throw APIError.unauthorized
        }
        return token
    }

    private func sendGET(path: String, query: [String: String]) async throws -> [String: Any] {
        let token = try authorizedToken()
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await execute(request)
    }

    private func sendJSON(path: String, body: [String: Any]) async throws -> [String: Any] {
        let token = try authorizedToken()
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return try await execute(request)
    }

    private func sendForm(path: String, fields: [(String, String)]) async throws -> [String: Any] {
        let token = try authorizedToken()
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.0, value: $0.1) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        return try await execute(request)
    }

    private func execute(_ request: URLRequest) async throws -> [String: Any] {
        let (data, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            if status >= 400 { throw APIError.http(status: status, data: data) }
            throw APIError.decodingFailed
        }
        let code = Self.codeInt(object["code"])
        if status == 200, code == 200 || code == nil {
            return object
        }
        let resolvedCode = code ?? status
        if resolvedCode == 401 { throw APIError.unauthorized }
        throw APIError.server(code: resolvedCode, message: object["msg"] as? String)
    }

    private static func positiveInt(_ raw: Any?) -> Int? {
        if let int = raw as? Int { return int > 0 ? int : nil }
        if let str = raw as? String, let int = Int(str), int > 0 { return int }
        return nil
    }

    private static func codeInt(_ raw: Any?) -> Int? {
        if let int = raw as? Int { return int }
        if let str = raw as? String { return Int(str) }
        return nil
    }

    private static func parseTimelineRows(data: [String: Any]) -> [AuditTimelineRow] {
        let rounds = (data["rounds"] as? [[String: Any]]) ?? []
        let types: [String: String] = ["NODE": "点位", "BRANCH": "分支", "MEDIA": "媒体", "COVER": "封面", "COPY": "文案"]
        var rows: [AuditTimelineRow] = []
        for (roundIdx, round) in rounds.enumerated() {
            let roundNo = (round["roundNo"] as? Int) ?? (roundIdx + 1)
            let kind = (round["conclusionText"] as? String) ?? "审核"
            let time = (round["decidedAt"] as? String) ?? ""
            rows.append(AuditTimelineRow(
                id: "round-\(roundNo)",
                label: "第 \(roundNo) 轮 · \(kind)",
                detail: time
            ))
            let problems = (round["problems"] as? [[String: Any]]) ?? []
            for (idx, problem) in problems.enumerated() {
                guard let reasonText = problem["reasonText"] as? String else { continue }
                let itemType = types[(problem["itemType"] as? String) ?? ""] ?? "内容"
                let itemID = problem["itemId"].map { " #\($0)" } ?? ""
                rows.append(AuditTimelineRow(
                    id: "round-\(roundNo)-p-\(idx)",
                    label: "\(kind) · \(itemType)\(itemID)问题",
                    detail: reasonText
                ))
            }
        }
        return rows
    }
}
