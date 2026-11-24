import Foundation

/// Models for `member` MP gaps (`MKT-7-1/3`, `MKT-5-3`, `MKT-10-1`, `PLY-25-2/3/4/5`, `PLY-29-4`).

// MARK: - MKT-7-1 / MKT-7-3: Free Explore Bundle Receipt & Unified Actions

public struct FreeExploreBundleUnitItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let chapterName: String
    public let statusText: String
    public let content: String?
    public let validTo: String
    public let canReserve: Bool
    public let canSwapMerchant: Bool

    public init(
        id: Int,
        chapterName: String,
        statusText: String,
        content: String? = nil,
        validTo: String,
        canReserve: Bool = false,
        canSwapMerchant: Bool = false
    ) {
        self.id = id
        self.chapterName = chapterName
        self.statusText = statusText
        self.content = content
        self.validTo = validTo
        self.canReserve = canReserve
        self.canSwapMerchant = canSwapMerchant
    }
}

public struct FreeExploreExitCaseItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct FreeExploreReceiptSummary: Equatable, Sendable {
    public let registrationNo: String
    public let paymentText: String
    public let registrationText: String
    public let units: [FreeExploreBundleUnitItem]
    public let exitCases: [FreeExploreExitCaseItem]

    public init(
        registrationNo: String,
        paymentText: String,
        registrationText: String,
        units: [FreeExploreBundleUnitItem] = [],
        exitCases: [FreeExploreExitCaseItem] = []
    ) {
        self.registrationNo = registrationNo
        self.paymentText = paymentText
        self.registrationText = registrationText
        self.units = units
        self.exitCases = exitCases
    }
}

// MARK: - PLY-25-2 / 25-3 / 25-4 / 25-5: Orient Score Leaderboard, Appeals & Settlement

public struct OrientScoreLeaderboardItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let rank: Int
    public let isMine: Bool
    public let scoreText: String
    public let elapsedText: String

    public init(id: String, rank: Int, isMine: Bool, scoreText: String, elapsedText: String) {
        self.id = id
        self.rank = rank
        self.isMine = isMine
        self.scoreText = scoreText
        self.elapsedText = elapsedText
    }
}

public enum OrientReviewSheetKind: String, Identifiable, Sendable {
    case appeal = "APPEAL"
    case dispute = "DISPUTE"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .appeal: return "计分申诉"
        case .dispute: return "成绩争议"
        }
    }
}

public enum OrientAppealValidator {
    public static let maxReasonLength = 500

    public static func clampReason(_ text: String) -> String {
        text.count <= maxReasonLength ? text : String(text.prefix(maxReasonLength))
    }

    public static func isValid(kind: OrientReviewSheetKind, entryID: String?, nodeIDText: String, reason: String) -> Bool {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty && trimmedReason.count <= maxReasonLength else { return false }
        if kind == .appeal && entryID == nil {
            let trimmedNode = nodeIDText.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedNode.isEmpty && Int(trimmedNode) != nil
        }
        return true
    }
}

// MARK: - MKT-10-1: Merchant Coupon Summary

public struct MerchantCouponSummary: Equatable, Sendable {
    public let totalClaimed: Int
    public let totalRedeemed: Int

    public init(totalClaimed: Int, totalRedeemed: Int) {
        self.totalClaimed = totalClaimed
        self.totalRedeemed = totalRedeemed
    }

    public static func fromWire(_ data: PlayWireValue) -> MerchantCouponSummary {
        MerchantCouponSummary(
            totalClaimed: data["totalClaimed"].tolerantInteger ?? data["claimedCount"].tolerantInteger ?? 0,
            totalRedeemed: data["totalRedeemed"].tolerantInteger ?? data["redeemedCount"].tolerantInteger ?? 0
        )
    }
}

// MARK: - PLY-29-4: Report Appeal Sheet

public enum ReportAppealSheetPhase: Equatable, Sendable {
    case form
    case confirm
    case busy
    case ok(receiptText: String?)
    case fail(message: String)
    case unknown
}

public enum ReportAppealValidator {
    public static let maxReasonLength = 1000

    public static func clamp(_ text: String) -> String {
        text.count <= maxReasonLength ? text : String(text.prefix(maxReasonLength))
    }

    public static func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxReasonLength
    }
}

// MARK: - MKT-5-3: Platform Pass Order Cancel / Refund (Owner-gated)

public enum PassOrderActionKind: String, Identifiable, Sendable {
    case cancel
    case refundApply

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .cancel: return "取消通行证订单"
        case .refundApply: return "申请退款"
        }
    }
}
