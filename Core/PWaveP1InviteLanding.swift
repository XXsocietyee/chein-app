import Foundation

/// P1 read landings. Both POSTs are reads: opening a link does not claim, pay, or start a run.
/// Referral copy is only the ordinary line. The gift headline is not emitted: the zip does not
/// name the state token that would authorize it.
/// `registrationState == UNKNOWN` never draws a free or guaranteed signup.
/// `freeSelfPlay == true` stays open when the sale token is `NOT_ON_SALE`.

public struct PWaveReferralFact: Equatable, Sendable {
    public static let ordinaryHeadline = "朋友邀请你一起玩"

    public let state: String
    public let inviterNickname: String?
    public let inviterAvatar: String?
    public let targetPresent: Bool
    public let expiresAt: String?
    public let expiresAtIsUnknown: Bool
    public let registrationState: String?
    public let registrationStateIsUnknown: Bool
    public let freeSelfPlay: Bool?
    public let nextAction: String?
    public let headline: String?
    public var drawsGuaranteedSignup: Bool { false }
    public var performsClaim: Bool { false }
    public var freeEntryOpen: Bool { freeSelfPlay == true }

    public init(state: String, inviterNickname: String?, inviterAvatar: String?, targetPresent: Bool,
                expiresAt: String?, registrationState: String?, freeSelfPlay: Bool?, nextAction: String?,
                headline: String?) {
        self.state = state
        self.inviterNickname = inviterNickname
        self.inviterAvatar = inviterAvatar
        self.targetPresent = targetPresent
        self.expiresAt = expiresAt
        self.expiresAtIsUnknown = expiresAt == "UNKNOWN"
        self.registrationState = registrationState
        self.registrationStateIsUnknown = registrationState == "UNKNOWN"
        self.freeSelfPlay = freeSelfPlay
        self.nextAction = nextAction
        self.headline = headline
    }
}

public struct PWaveGiftLandingFact: Equatable, Sendable {
    public let state: String
    public let productPresent: Bool
    public let claimExpiresAt: String?
    public let claimExpiresAtIsUnknown: Bool
    public let recipientBound: Bool?
    public var reclaimOffered: Bool { false }
    public var performsClaim: Bool { false }

    public init(state: String, productPresent: Bool, claimExpiresAt: String?, recipientBound: Bool?) {
        self.state = state
        self.productPresent = productPresent
        self.claimExpiresAt = claimExpiresAt
        self.claimExpiresAtIsUnknown = claimExpiresAt == "UNKNOWN"
        self.recipientBound = recipientBound
    }
}

public enum PWaveInviteLanding {
    public static func decodeReferral(data: Data, status: Int) -> PWaveServerFact<PWaveReferralFact> {
        switch PWaveEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return referral(payload)
        }
    }

    public static func decodeGift(data: Data, status: Int) -> PWaveServerFact<PWaveGiftLandingFact> {
        switch PWaveEnvelope.classify(data: data, status: status) {
        case .error(let error): return .error(error)
        case .unknown: return .unknown
        case .payload(let payload): return gift(payload)
        }
    }

    static func referral(_ payload: PlayWireValue) -> PWaveServerFact<PWaveReferralFact> {
        guard let object = payload.object, let state = PWaveEnvelope.text(object["state"] ?? .null) else { return .unknown }
        let inviter = object["inviter"]?.object
        let registrationState = PWaveEnvelope.text(object["registrationState"] ?? .null)
        let fact = PWaveReferralFact(
            state: state,
            inviterNickname: PWaveEnvelope.text(inviter?["nickname"] ?? .null),
            inviterAvatar: PWaveEnvelope.text(inviter?["avatar"] ?? .null),
            targetPresent: present(object, "target"),
            expiresAt: PWaveEnvelope.text(object["expiresAt"] ?? .null),
            registrationState: registrationState,
            freeSelfPlay: object["freeSelfPlay"]?.bool,
            nextAction: PWaveEnvelope.text(object["nextAction"] ?? .null),
            headline: state == "VALID" ? PWaveReferralFact.ordinaryHeadline : nil)
        return .ready(fact)
    }

    static func gift(_ payload: PlayWireValue) -> PWaveServerFact<PWaveGiftLandingFact> {
        guard let object = payload.object, let state = PWaveEnvelope.text(object["state"] ?? .null) else { return .unknown }
        return .ready(PWaveGiftLandingFact(
            state: state,
            productPresent: present(object, "product"),
            claimExpiresAt: PWaveEnvelope.text(object["claimExpiresAt"] ?? .null),
            recipientBound: object["recipientBound"]?.bool))
    }

    private static func present(_ object: [String: PlayWireValue], _ key: String) -> Bool {
        guard let value = object[key] else { return false }
        if case .null = value { return false }
        return true
    }
}
