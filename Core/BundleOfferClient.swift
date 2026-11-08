import Foundation

/// Reasons a merchant stall cannot be reserved, one case per server enum value
/// (`bundle-backend-spec.md` B-03). Unknown values map to `.unknown` (generic copy).
public enum BundleOfferUnavailableReason: Equatable, Hashable {
    case merchantExited, offerExpired, notYetValid, noBalance, reservedElsewhere
    case ledgerOff, reservationOff, outsideValidity
    case unknown(String)

    public static let knownServerValues: [String] = [
        "MERCHANT_EXITED", "OFFER_EXPIRED", "NOT_YET_VALID", "NO_BALANCE",
        "RESERVED_ELSEWHERE", "LEDGER_OFF", "RESERVATION_OFF", "OUTSIDE_VALIDITY"
    ]

    public init(serverValue: String) {
        switch serverValue {
        case "MERCHANT_EXITED": self = .merchantExited
        case "OFFER_EXPIRED": self = .offerExpired
        case "NOT_YET_VALID": self = .notYetValid
        case "NO_BALANCE": self = .noBalance
        case "RESERVED_ELSEWHERE": self = .reservedElsewhere
        case "LEDGER_OFF": self = .ledgerOff
        case "RESERVATION_OFF": self = .reservationOff
        case "OUTSIDE_VALIDITY": self = .outsideValidity
        default: self = .unknown(serverValue)
        }
    }

    /// Localization key (table `BundleStall`); listed in docs/owner-plan/iwp-6-new-strings.md.
    public var copyKey: String {
        switch self {
        case .merchantExited: return "reason.merchantExited"
        case .offerExpired: return "reason.offerExpired"
        case .notYetValid: return "reason.notYetValid"
        case .noBalance: return "reason.noBalance"
        case .reservedElsewhere: return "reason.reservedElsewhere"
        case .ledgerOff: return "reason.ledgerOff"
        case .reservationOff: return "reason.reservationOff"
        case .outsideValidity: return "reason.outsideValidity"
        case .unknown: return "reason.generic"
        }
    }
}

/// Server offer detail (EP-03). Not available yet: B-03 is BLOCKED-BACKEND.
public struct BundleOfferDetail: Decodable, Equatable {
    public struct Slot: Decodable, Equatable {
        public let startAt: Int64
        public let remaining: Int
    }
    public let offerId: FreeExploreLaunchID
    public let merchantName: String?
    public let termsMode: String?
    public let perHeadFee: FreeExploreLaunchDecimal?
    public let validEnd: BundleTimestamp?
    public let live: Bool?
    public let unavailableReasons: [String]
    public let slots: [Slot]

    enum CodingKeys: String, CodingKey {
        case offerId, merchantName, termsMode, perHeadFee, validEnd, live, unavailableReasons, slots
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        offerId = try c.decode(FreeExploreLaunchID.self, forKey: .offerId)
        merchantName = try c.decodeIfPresent(String.self, forKey: .merchantName)
        termsMode = try c.decodeIfPresent(String.self, forKey: .termsMode)
        perHeadFee = try c.decodeIfPresent(FreeExploreLaunchDecimal.self, forKey: .perHeadFee)
        validEnd = try c.decodeIfPresent(BundleTimestamp.self, forKey: .validEnd)
        live = try c.decodeIfPresent(Bool.self, forKey: .live)
        unavailableReasons = try c.decodeIfPresent([String].self, forKey: .unavailableReasons) ?? []
        slots = try c.decodeIfPresent([Slot].self, forKey: .slots) ?? []
    }
    public var reasons: [BundleOfferUnavailableReason] { unavailableReasons.map(BundleOfferUnavailableReason.init(serverValue:)) }
}

public protocol BundleOfferClient {
    func offer(offerID: FreeExploreLaunchID, registrationID: FreeExploreLaunchID?,
               fromMs: Int64?, toMs: Int64?) async throws -> BundleOfferDetail
}

/// Default until B-03 lands. Never returns data; callers must show the unavailable state.
public struct UnavailableBundleOfferClient: BundleOfferClient {
    public init() {}
    public func offer(offerID: FreeExploreLaunchID, registrationID: FreeExploreLaunchID?,
                      fromMs: Int64?, toMs: Int64?) async throws -> BundleOfferDetail {
        throw FreeExploreLaunchFailure.disabled
    }
}
