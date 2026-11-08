import Foundation

// MARK: - Bundle (free-explore) read contracts
// Shapes copied from docs/owner-plan/bundle-gap.md §4 (backend primary branch, parked deltas optional).
// Decode-only. No price / refund / threshold arithmetic lives here: every number is a server display value.
// Ids go through FreeExploreLaunchID (number or string, rejects <= 0); money/ratios through
// FreeExploreLaunchDecimal (never Double). Status strings stay `String` so a new server state never
// crashes a screen; use the `isKnown` helpers to decide whether to offer an action.

/// Backend mixes "yyyy-MM-dd HH:mm:ss" (Asia/Shanghai), epoch-ms numbers and raw `Date` serialisations.
/// `raw` is always kept for display; `epochMs` is nil when the value cannot be parsed (fail closed).
public struct BundleTimestamp: Decodable, Equatable {
    public let raw: String
    public let epochMs: Int64?
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self) {
            raw = text; epochMs = MoneyParityTime.timestamp(text)
        } else if let integer = try? c.decode(Int64.self) {
            raw = String(integer); epochMs = MoneyParityTime.timestamp(number: Double(integer))
        } else if let number = try? c.decode(Double.self) {
            raw = String(number); epochMs = MoneyParityTime.timestamp(number: number)
        } else {
            throw FreeExploreLaunchFailure.malformed
        }
    }
}

public enum BundleStatusCatalog {
    public static let knownUnitStatuses: Set<String> = [
        "AVAILABLE", "RESERVED", "REDEEMED", "FORFEITED", "HELD", "REFUND_PENDING", "REFUNDED"
    ]
    public static let knownReservationStatuses: Set<String> = [
        "BOOKED", "CANCELLED", "WAIVED", "LATE_CANCELLED", "NO_SHOW", "FULFILLED", "MERCHANT_EXITED"
    ]
    public static let knownCancelOutcomes: Set<String> = ["CANCELLED", "WAIVED", "LATE_CANCELLED"]
}

public struct BundlePolicy: Decodable, Equatable {
    public let version: String
    public let freeCancelHours: Int
    public let partialRefundMinRatio: FreeExploreLaunchDecimal
    public let monthlyVoluntaryWaivers: Int
}

public struct BundleUnit: Decodable, Equatable {
    public let id: FreeExploreLaunchID
    public let grantId: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
    public let chapterId: FreeExploreLaunchID
    public let unitSeq: Int
    public let unitCode: String
    public let unitValue: FreeExploreLaunchDecimal
    /// Unknown values stay readable and never become permission to write.
    public let status: String
    public let redemptionId: FreeExploreLaunchID?
    public let reservationId: FreeExploreLaunchID?
    public let statusReason: String?
    public let version: Int
    public let grantNo: Int
    public let validFrom: BundleTimestamp
    public let validTo: BundleTimestamp
    public var isKnown: Bool { BundleStatusCatalog.knownUnitStatuses.contains(status) }
}

public struct BundleBalance: Decodable, Equatable {
    public let grantId: FreeExploreLaunchID
    public let chapterId: FreeExploreLaunchID
    public let grantNo: Int
    public let grantType: String
    public let unitsTotal: Int
    /// Keyed by unit status (AVAILABLE, RESERVED, ...); unknown keys are kept.
    public let counts: [String: Int]
    public let validFrom: BundleTimestamp
    public let validTo: BundleTimestamp
    public let expired: Bool
}

public struct BundleExitCase: Decodable, Equatable {
    public let id: FreeExploreLaunchID
    public let unitId: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
    public let exitedOfferId: FreeExploreLaunchID
    public let reservationId: FreeExploreLaunchID?
    /// SWAP_CONSENTED | REFUND_UNFULFILLED (unknown values kept).
    public let decision: String
    public let targetOfferId: FreeExploreLaunchID?
    public let idempotencyKey: String
    public let requestFingerprint: String
}

/// Parked backend branch only (`orderView.bundle.refundHold`). Absent on primary; every field but `state`
/// is optional because the shape is unverified against a running backend.
public struct BundleRefundHold: Decodable, Equatable {
    public let registrationId: FreeExploreLaunchID?
    public let refundId: String?
    public let refundNo: String?
    public let cashAmount: FreeExploreLaunchDecimal?
    public let state: String
    public let version: Int?
}

public struct BundleFulfilledMerchant: Decodable, Equatable {
    public let merchantId: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
}

public struct BundleOrderHeader: Decodable, Equatable {
    public let id: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
    public let topicId: FreeExploreLaunchID
    public let activityId: FreeExploreLaunchID?
    public let productVersion: String
    public let quotaVersion: String
    public let policyVersion: String
    public let contractVersion: String
    public let settlementRuleVersion: String
    public let paidAmount: FreeExploreLaunchDecimal
    public let validFrom: BundleTimestamp
    public let validTo: BundleTimestamp
    public let idempotencyKey: String
}

/// `GET order?registrationId=` data (also embedded in the receipt). `bundle == nil` is a legacy order.
public struct BundleOrderView: Decodable, Equatable {
    public struct Bundle: Decodable, Equatable {
        public let order: BundleOrderHeader
        public let balances: [BundleBalance]
        public let units: [BundleUnit]
        /// Reuses the existing reservation contract (id, unit, offer, startAt string, status, fingerprint).
        public let reservations: [FreeExploreLaunchReservation]
        public let exitCases: [BundleExitCase]
        public let policy: BundlePolicy
        public let refundHold: BundleRefundHold?
        public let fulfilledMerchants: [BundleFulfilledMerchant]?
    }
    public let registrationId: FreeExploreLaunchID
    public let registrationNo: String?
    public let parentOrderNo: String?
    public let paymentStatus: Int?
    public let registrationStatus: Int?
    public let bundle: Bundle?
}

/// `GET order/receipt?requestId=`. NOT_FOUND is a negative read, never proof that no write happened.
public struct BundleOrderReceipt: Decodable, Equatable {
    public enum Kind: String, Decodable, Equatable { case found = "FOUND", notFound = "NOT_FOUND" }
    public let requestId: String
    public let receipt: Kind
    public let order: BundleOrderView?
    /// Parked branch: "UNKNOWN" on NOT_FOUND.
    public let outcome: String?
    /// Always false: a NOT_FOUND receipt must be re-read, a write must never be assumed absent.
    public var provesNoWrite: Bool { false }
}

public struct BundleCancelQuote: Decodable, Equatable {
    public let reservationId: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
    public let version: Int
    public let status: String
    public let asOf: BundleTimestamp
    public let useWaiver: Bool
    /// CANCELLED | WAIVED | LATE_CANCELLED (unknown kept).
    public let outcome: String
    /// CANCELLED | LATE_CANCELLED | "WAIVED:yyyy-MM". Sent back verbatim on confirm, never computed here.
    public let expectedOutcome: String
    public let canCancel: Bool
    public let waiverMonth: String?
}

public struct BundleExitOptions: Decodable, Equatable {
    public struct Target: Decodable, Equatable {
        public let offerId: FreeExploreLaunchID
        public let merchantName: String?
        public let validEnd: BundleTimestamp?
    }
    public let registrationId: FreeExploreLaunchID
    public let unitId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID
    public let merchantExited: Bool
    public let targets: [Target]
    public let refundSubmissionAvailable: Bool
}
