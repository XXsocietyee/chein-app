import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G4 community trust, player side. Ports:
/// - `subpackageMember/components/cy/merchant-correction-sheet` (BL-67): contributions taxonomy + submit (ISSUE_REPORT only)
/// - `pages/play/merchant/components/safety-rating-sheet` (BL-89): safety taxonomy + rating
/// - `subpackageMember/components/cy/profile/merchant-safety-summary` (BL-66): merchant safety summary (read only)
/// - `subpackageMember/report-detail` (BL-52): text-only report appeal
public struct CommunityTrustPlayerService {
    public static let contributionTaxonomyPath = "api/community-trust/contributions/taxonomy"
    public static let contributionSubmitPath = "api/community-trust/contributions/submit"
    public static let safetyTaxonomyPath = "api/community-trust/safety/taxonomy"
    public static let safetyRatingPath = "api/community-trust/safety/ratings"
    public static let safetyMerchantPrefix = "api/community-trust/safety/merchants/"
    public static let reportAppealPath = "api/community-trust/reports/appeal"

    let client: PlayerCapabilityClient
    public init(client: PlayerCapabilityClient) { self.client = client }

    // MARK: Merchant correction (BL-67)

    public struct IssueType: Equatable, Identifiable {
        public let code: String
        public let label: String
        public var id: String { code }
    }
    /// Only codes the backend `ISSUE_TYPES` really has get a name; an unknown code is not shown.
    public static let issueLabels: [(String, String)] = [
        ("CLOSED", "已停业或关门"), ("ADDRESS", "地址不对"), ("BUSINESS_TIME", "营业时间不对"),
        ("CONTENT", "介绍内容有误"), ("OTHER", "其他问题")
    ]
    public static let reviewStatusText: [String: String] = [
        "PENDING": "待审核", "APPROVED": "已通过", "REJECTED": "未通过", "NEEDS_EVIDENCE": "需补充说明", "MERGED": "已更新"
    ]
    public static let descriptionMax = 2000

    /// `normalizeTaxonomy`: needs `ISSUE_REPORT` in `contributionTypes`; nil means 「纠错类型没有读取成功」.
    public static func issueTypes(_ raw: SquareGovernanceJSON) -> [IssueType]? {
        guard case .object = raw else { return nil }
        let types = (raw["contributionTypes"].array ?? []).compactMap(\.string)
        guard types.contains("ISSUE_REPORT"), let codes = raw["issueTypes"].array else { return nil }
        let labels = Dictionary(uniqueKeysWithValues: issueLabels)
        let issues = codes.compactMap(\.string).compactMap { code in labels[code].map { IssueType(code: code, label: $0) } }
        return issues.isEmpty ? nil : issues
    }

    public func contributionIssueTypes() async throws -> [IssueType] {
        let raw = try await client.read(try client.getRequest(Self.contributionTaxonomyPath))
        guard let issues = Self.issueTypes(raw) else { throw PlayerCapabilityFailure.malformed }
        return issues
    }

    public struct ContributionReceipt: Equatable {
        public let id: String
        public let statusText: String
        /// 「受理编号 N，当前状态：X。」
        public var text: String { "受理编号 \(id)，当前状态：\(statusText)。" }
    }

    /// `checkDescription`: trimmed, 1–2000 characters.
    public static func checkedDescription(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= descriptionMax else { return nil }
        return value
    }

    public static func contributionKey(merchantID: Int) -> String {
        PlayerCapabilityClient.requestKey("mct-\(merchantID)-")
    }

    /// `buildPayload`: `{merchantId, contributionType: ISSUE_REPORT, issueType, description, idempotencyKey}`; no evidence.
    func contributionRequest(merchantID: Int, issueType: String, description: String, idempotencyKey: String) throws -> URLRequest {
        guard merchantID > 0, Self.issueLabels.contains(where: { $0.0 == issueType }),
              let text = Self.checkedDescription(description), (8...96).contains(idempotencyKey.count) else {
            throw PlayerCapabilityFailure.invalid
        }
        return try client.jsonRequest(Self.contributionSubmitPath, body: [
            "merchantId": .integer(merchantID), "contributionType": .string("ISSUE_REPORT"), "issueType": .string(issueType),
            "description": .string(text), "idempotencyKey": .string(idempotencyKey)
        ])
    }

    /// 400/401/403/422 are definite refusals; any other failure keeps the same key (`outcomeUnknown`).
    public func submitContribution(merchantID: Int, issueType: String, description: String,
                                   idempotencyKey: String) async throws -> ContributionReceipt {
        let request = try contributionRequest(merchantID: merchantID, issueType: issueType,
                                              description: description, idempotencyKey: idempotencyKey)
        let raw: SquareGovernanceJSON
        do { raw = try await client.write(request) }
        catch PlayerCapabilityFailure.rejected(let code, let message) {
            guard [400, 401, 403, 422].contains(code) else { throw PlayerCapabilityFailure.outcomeUnknown }
            throw PlayerCapabilityFailure.rejected(code: code, message: message)
        }
        guard let id = PlayerCapabilityClient.positiveID(raw["id"]),
              let status = raw["reviewStatus"].string.flatMap({ Self.reviewStatusText[$0] }) else {
            throw PlayerCapabilityFailure.outcomeUnknown
        }
        return ContributionReceipt(id: String(id), statusText: status)
    }

    // MARK: Safety rating (BL-89)

    public static let levelLabels: [(String, String)] = [("SAFE", "安心"), ("NEUTRAL", "一般"), ("UNSAFE", "不安心")]

    /// `levelTabs`: upper-cased, known levels only, first occurrence order.
    public static func levelTabs(_ raw: SquareGovernanceJSON) -> [(key: String, label: String)] {
        let labels = Dictionary(uniqueKeysWithValues: levelLabels)
        var seen = Set<String>()
        return (raw["levels"].array ?? []).compactMap { value -> (key: String, label: String)? in
            let level = (value.string ?? "").uppercased()
            guard let label = labels[level], seen.insert(level).inserted else { return nil }
            return (level, label)
        }
    }

    public func safetyLevels() async throws -> [(key: String, label: String)] {
        let tabs = Self.levelTabs(try await client.read(try client.getRequest(Self.safetyTaxonomyPath)))
        guard !tabs.isEmpty else { throw PlayerCapabilityFailure.malformed }
        return tabs
    }

    public static func safetyKey(merchantID: Int) -> String {
        PlayerCapabilityClient.requestKey("safety-\(merchantID)-", limit: 128)
    }

    /// `receiptText`: 「你的感受：X · 评价周期 P · 受理编号 N」.
    public static func safetyReceiptText(_ raw: SquareGovernanceJSON) -> String {
        var parts: [String] = []
        if let level = raw["overallLevel"].string, let label = Dictionary(uniqueKeysWithValues: levelLabels)[level] {
            parts.append("你的感受：" + label)
        }
        let period = PlayerCapabilityClient.text(raw["ratingPeriod"])
        if !period.isEmpty { parts.append("评价周期 " + period) }
        if let id = PlayerCapabilityClient.positiveID(raw["ratingId"]) { parts.append("受理编号 \(id)") }
        return parts.joined(separator: " · ")
    }

    /// `merchantId` here is `mms_merchant.id` (resolved by the caller through `api/merchant/public-home`).
    func safetyRequest(merchantID: Int, level: String, reason: String, idempotencyKey: String) throws -> URLRequest {
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard merchantID > 0, Self.levelLabels.contains(where: { $0.0 == level }), !text.isEmpty, text.count <= 1000,
              !idempotencyKey.isEmpty else { throw PlayerCapabilityFailure.invalid }
        return try client.jsonRequest(Self.safetyRatingPath, body: [
            "merchantId": .integer(merchantID), "overallLevel": .string(level), "reason": .string(text),
            "idempotencyKey": .string(idempotencyKey)
        ])
    }

    public func submitSafetyRating(merchantID: Int, level: String, reason: String, idempotencyKey: String) async throws -> String {
        let raw = try await client.write(try safetyRequest(merchantID: merchantID, level: level, reason: reason,
                                                           idempotencyKey: idempotencyKey))
        guard PlayerCapabilityClient.positiveID(raw["ratingId"]) != nil else { throw PlayerCapabilityFailure.outcomeUnknown }
        return Self.safetyReceiptText(raw)
    }

    // MARK: Merchant safety summary (BL-66)

    public struct SafetySummary: Equatable {
        public let level: String
        public let text: String
        public let note: String
    }

    /// `shapeMerchantSafety`: shown only for SUFFICIENT samples with a known level and a positive count.
    public static func safetySummary(_ raw: SquareGovernanceJSON) -> SafetySummary? {
        let text = ["SAFE": "到访用户感到安全", "NEUTRAL": "到访用户感受一般", "UNSAFE": "部分到访用户感到不安全"]
        guard raw["sampleStatus"].string == "SUFFICIENT", let level = raw["level"].string, let label = text[level],
              let count = PlayerCapabilityClient.positiveID(raw["sampleCount"]) else { return nil }
        let days = PlayerCapabilityClient.positiveID(raw["windowDays"])
        let scope = (days.map { "近 \($0) 天 " } ?? "") + "\(count) 人反馈"
        return SafetySummary(level: level, text: label, note: scope + "，仅代表用户感受，不构成安全保证")
    }

    /// Insufficient sample, policy off, or any failure: nil (the profile shows nothing).
    public func merchantSafety(merchantID: Int) async -> SafetySummary? {
        guard merchantID > 0, let request = try? client.getRequest(Self.safetyMerchantPrefix + String(merchantID)),
              let raw = try? await client.read(request) else { return nil }
        return Self.safetySummary(raw)
    }

    // MARK: Report appeal (BL-52)

    public static let appealMax = 1000
    public static let appealableStages: Set<String> = ["RESOLVED", "CLOSED"]
    /// `report-common/view.js` STAGES labels (2026-10-15 user decision CL2).
    public static let stageLabels: [String: String] = [
        "SUBMITTED": "已提交", "TRIAGED": "已受理", "INVESTIGATING": "调查中",
        "RESOLVED": "已处理", "CLOSED": "已关闭", "APPEALED": "申诉中"
    ]

    public static func appealKey(reportID: Int) -> String {
        PlayerCapabilityClient.requestKey("rpa-\(reportID)-")
    }

    /// Picks the body for one appeal attempt. The id is written before the first send.
    /// A later attempt keeps that id and the reason it was first sent with, even when the editor text changed.
    public static func appealSubmission(existingRequestID: String, lockedReason: String, reason: String, reportID: Int) -> (requestID: String, reason: String)? {
        guard reportID > 0 else { return nil }
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if existingRequestID.isEmpty {
            guard !text.isEmpty, text.count <= appealMax else { return nil }
            let id = appealKey(reportID: reportID)
            guard (8...96).contains(id.count) else { return nil }
            return (id, text)
        }
        guard (8...96).contains(existingRequestID.count) else { return nil }
        let locked = lockedReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = locked.isEmpty ? text : locked
        guard !payload.isEmpty, payload.count <= appealMax else { return nil }
        return (existingRequestID, payload)
    }

    func appealRequest(reportID: Int, reason: String, requestID: String) throws -> URLRequest {
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard reportID > 0, !text.isEmpty, text.count <= Self.appealMax, (8...96).contains(requestID.count) else {
            throw PlayerCapabilityFailure.invalid
        }
        return try client.jsonRequest(Self.reportAppealPath, body: [
            "reportId": .integer(reportID), "reason": .string(text), "requestId": .string(requestID)
        ])
    }

    /// Confirmed receipt 「举报编号 N · 当前阶段：X」.
    /// A write that does not identify this report stays unconfirmed (`outcomeUnknown`), the same as a dropped response.
    public func appeal(reportID: Int, reason: String, requestID: String,
                       stageLabel: (String) -> String?) async throws -> String {
        let raw = try await client.write(try appealRequest(reportID: reportID, reason: reason, requestID: requestID))
        guard PlayerCapabilityClient.positiveID(raw["reportId"]) == reportID,
              let stage = raw["stage"].string, let label = stageLabel(stage) else {
            throw PlayerCapabilityFailure.outcomeUnknown
        }
        return "举报编号 \(reportID) · 当前阶段：\(label)"
    }
}
