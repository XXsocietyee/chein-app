import Foundation

// MARK: - Bundle voucher + redeem result (IWP-5, T-07 / T-08)
// Backend endpoints B-09 (voucher), B-10 (voucher/version) and B-17 (redemption/result) do NOT exist yet
// (`bundle-gap.md` rows 09/10/17). This file therefore only defines the value types, a client protocol and an
// `unavailable` default. There is no HTTP implementation and no canned data. A real client is added by the
// WP that lands those endpoints; until then the shipped default answers `.unavailable` to everything.
//
// Voucher codes are credentials: the types below redact them from `description`, `debugDescription` and
// `customMirror` so a log line, `print`, `dump` or crash breadcrumb cannot leak one. Nothing here persists.

/// Placeholder used wherever a code would otherwise be printed.
public let bundleVoucherRedactedCode = "<redacted-voucher-code>"

public struct BundleVoucherSubCode: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let unitID: String
    public let chapterID: String
    /// Display/support code only (`subs[].unitCode`); never generated client-side.
    public let unitCode: String
    /// Server status string; unknown values are kept verbatim.
    public let status: String
    public let validFrom: String?
    public let validTo: String?
    public let reservationID: String?

    public init(unitID: String, chapterID: String, unitCode: String, status: String,
                validFrom: String? = nil, validTo: String? = nil, reservationID: String? = nil) {
        self.unitID = unitID; self.chapterID = chapterID; self.unitCode = unitCode; self.status = status
        self.validFrom = validFrom; self.validTo = validTo; self.reservationID = reservationID
    }
    public var description: String { "BundleVoucherSubCode(unitID: \(unitID), status: \(status), code: \(bundleVoucherRedactedCode))" }
    public var debugDescription: String { description }
    public var customMirror: Mirror {
        Mirror(self, children: ["unitID": unitID, "status": status, "unitCode": bundleVoucherRedactedCode],
               displayStyle: .struct)
    }
}

public struct BundleVoucher: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public let registrationID: String
    /// Opaque server digest of the holder's unit statuses; the only thing the poll compares.
    public let version: String
    /// Whatever the server returns as the main QR payload; the app never builds one.
    public let mainCode: String?
    public let mainValidTo: String?
    public let subs: [BundleVoucherSubCode]

    public init(registrationID: String, version: String, mainCode: String?, mainValidTo: String? = nil,
                subs: [BundleVoucherSubCode] = []) {
        self.registrationID = registrationID; self.version = version; self.mainCode = mainCode
        self.mainValidTo = mainValidTo; self.subs = subs
    }
    public var description: String {
        "BundleVoucher(registrationID: \(registrationID), version: \(version), main: \(bundleVoucherRedactedCode), subs: \(subs.count))"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror {
        Mirror(self, children: ["registrationID": registrationID, "version": version,
                                "mainCode": bundleVoucherRedactedCode, "subs": subs.count],
               displayStyle: .struct)
    }
}

public enum BundleVoucherFetchOutcome: Equatable {
    case voucher(BundleVoucher)
    case failed
    case unavailable
}

public enum BundleVoucherVersionOutcome: Equatable {
    /// `pollIntervalHint` is the server's suggested seconds between polls, if it sent one.
    case version(String, pollIntervalHint: Double?)
    case failed
    case unavailable
}

/// Server `outcome` of a redemption. Unknown strings are preserved, never crash a screen.
public enum BundleRedeemOutcome: Equatable {
    case success, review, rejected, notRedeemed
    case unknown(String)

    public init(serverValue: String) {
        switch serverValue {
        case "SUCCESS": self = .success
        case "REVIEW": self = .review
        case "REJECTED": self = .rejected
        case "NONE": self = .notRedeemed
        default: self = .unknown(serverValue)
        }
    }
}

public struct BundleRedeemResult: Equatable {
    public let outcome: BundleRedeemOutcome
    public let unitID: String?
    public let status: String?
    public let redemptionID: String?
    public let merchantName: String?
    /// Epoch milliseconds as sent by the server.
    public let at: Int64?
    /// Server-provided reason text (only meaningful for rejected/review).
    public let reason: String?

    public init(outcome: BundleRedeemOutcome, unitID: String? = nil, status: String? = nil, redemptionID: String? = nil,
                merchantName: String? = nil, at: Int64? = nil, reason: String? = nil) {
        self.outcome = outcome; self.unitID = unitID; self.status = status; self.redemptionID = redemptionID
        self.merchantName = merchantName; self.at = at; self.reason = reason
    }
}

public enum BundleRedeemResultOutcome: Equatable {
    case result(BundleRedeemResult)
    case failed
    case unavailable
}

@MainActor public protocol BundleVoucherServing {
    /// B-09 `GET /api/free-explore/bundle/voucher?registrationId=`
    func voucher(registrationID: String) async -> BundleVoucherFetchOutcome
    /// B-10 `GET /api/free-explore/bundle/voucher/version?registrationId=`
    func version(registrationID: String) async -> BundleVoucherVersionOutcome
    /// B-17 `GET /api/free-explore/bundle/redemption/result?registrationId=&unitId=`
    func redeemResult(registrationID: String, unitID: String) async -> BundleRedeemResultOutcome
}

/// Shipped default until the backend exists: every call reports unavailable, nothing is invented.
public struct UnavailableBundleVoucherClient: BundleVoucherServing {
    nonisolated public init() {}
    public func voucher(registrationID: String) async -> BundleVoucherFetchOutcome { .unavailable }
    public func version(registrationID: String) async -> BundleVoucherVersionOutcome { .unavailable }
    public func redeemResult(registrationID: String, unitID: String) async -> BundleRedeemResultOutcome { .unavailable }
}
