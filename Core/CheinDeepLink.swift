import Foundation

/// W3-6 custom-scheme deep links, plus the player-loop landings from
/// `subpackageJourney/pages/landing/index` (`k=r|g|s`, `t`, optional `aid` / `tid`).
///
/// Parsing only classifies the URL. It grants nothing: it does not start a roam, open a ticket, join a club,
/// claim a seat, claim a gift, or issue a referral. The host selects the owning root tab and the destination
/// keeps its own sign-in and confirmation gating.
///
/// The original three links stay query-free and at most 512 bytes. Referral, gift, and seat tokens follow the
/// page rule: a decoded token of 1...512 UTF-16 code units, no control characters. `aid` and `tid` are positive
/// canonical decimal ids.
public enum CheinDeepLink: Equatable, Sendable {
    case roamGo
    case ticket(id: Int)
    case clubJoin(id: Int)
    case referral(token: String, activityID: Int?, topicID: Int?)
    case gift(token: String, activityID: Int?, topicID: Int?)
    case seat(token: String, activityID: Int?, topicID: Int?)

    public static let scheme = "chein"
    /// Spoken product name. It is not a registered URL type; intake rewrites it to `chein` before parsing.
    public static let aliasScheme = "chengyin"

    public static func isPlayerScheme(_ scheme: String?) -> Bool {
        let value = scheme?.lowercased() ?? ""
        return value == Self.scheme || value == Self.aliasScheme
    }

    /// `chengyin://…` uses the same grammar as `chein://…`. Every other URL is returned unchanged.
    public static func canonicalURL(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == aliasScheme,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.scheme = scheme
        return components.url ?? url
    }

    public init?(url: URL) {
        let byteCount = url.absoluteString.utf8.count
        guard byteCount <= 2048,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              components.user == nil, components.password == nil, components.port == nil, components.fragment == nil,
              let host = components.host?.lowercased(), !host.isEmpty else { return nil }
        let journeyHost = host == "referral" || host == "gift" || host == "seat" || host == "landing"
        if !journeyHost {
            guard byteCount <= 512, components.query == nil else { return nil }
        }
        if host != "landing", components.query != nil { return nil }
        let path = components.percentEncodedPath
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let rest: [String]
        if path.isEmpty { rest = [] }
        else {
            guard parts.first == "", parts.dropFirst().allSatisfy({ !$0.isEmpty }) else { return nil }
            rest = Array(parts.dropFirst())
        }
        switch host {
        case "roam" where rest == ["go"]:
            self = .roamGo
        case "ticket" where rest.count == 1:
            guard let id = Self.positiveID(rest[0]) else { return nil }
            self = .ticket(id: id)
        case "club" where rest.count == 2 && rest[1] == "join":
            guard let id = Self.positiveID(rest[0]) else { return nil }
            self = .clubJoin(id: id)
        case "referral" where rest.count == 1:
            guard let token = Self.token(rest[0]) else { return nil }
            self = .referral(token: token, activityID: nil, topicID: nil)
        case "gift" where rest.count == 1:
            guard let token = Self.token(rest[0]) else { return nil }
            self = .gift(token: token, activityID: nil, topicID: nil)
        case "seat":
            guard let link = Self.seatPath(rest) else { return nil }
            self = link
        case "landing" where rest.isEmpty:
            guard let link = Self.init(landingQuery: components.queryItems ?? []) else { return nil }
            self = link
        default:
            return nil
        }
    }

    /// Query shape of the mini-program landing page. Unknown keys are rejected. Empty `aid` / `tid` are absent.
    public init?(landingQuery items: [URLQueryItem]) {
        var seen: [String: String] = [:]
        for item in items {
            guard ["k", "t", "aid", "tid"].contains(item.name), seen[item.name] == nil else { return nil }
            seen[item.name] = item.value ?? ""
        }
        guard let kind = seen["k"], let token = Self.plainToken(seen["t"] ?? "") else { return nil }
        let activity = Self.optionalID(seen["aid"])
        let topic = Self.optionalID(seen["tid"])
        guard activity != .invalid, topic != .invalid else { return nil }
        switch kind {
        case "r": self = .referral(token: token, activityID: activity.value, topicID: topic.value)
        case "g": self = .gift(token: token, activityID: activity.value, topicID: topic.value)
        case "s": self = .seat(token: token, activityID: activity.value, topicID: topic.value)
        default: return nil
        }
    }

    /// Root tab that owns the destination. Journey landings open on Explore and do not claim.
    public var rootTab: RootTab {
        switch self {
        case .roamGo: return .roam
        case .ticket: return .mine
        case .clubJoin: return .club
        case .referral, .gift, .seat: return .home
        }
    }

    public var journeyIntake: JourneyLinkIntake? {
        switch self {
        case .referral(let token, let activityID, let topicID):
            return JourneyLinkIntake(kind: .referral, token: token, activityID: activityID, topicID: topicID)
        case .gift(let token, let activityID, let topicID):
            return JourneyLinkIntake(kind: .gift, token: token, activityID: activityID, topicID: topicID)
        case .seat(let token, let activityID, let topicID):
            return JourneyLinkIntake(kind: .seat, token: token, activityID: activityID, topicID: topicID)
        case .roamGo, .ticket, .clubJoin:
            return nil
        }
    }

    private static func seatPath(_ rest: [String]) -> CheinDeepLink? {
        guard let raw = rest.first, let token = token(raw) else { return nil }
        var activity: Int?
        var topic: Int?
        var index = 1
        while index < rest.count {
            guard index + 1 < rest.count else { return nil }
            switch rest[index] {
            case "aid" where activity == nil:
                guard let id = positiveID(rest[index + 1]) else { return nil }
                activity = id
            case "tid" where topic == nil:
                guard let id = positiveID(rest[index + 1]) else { return nil }
                topic = id
            default:
                return nil
            }
            index += 2
        }
        return .seat(token: token, activityID: activity, topicID: topic)
    }

    private static func token(_ encoded: String) -> String? {
        guard let decoded = encoded.removingPercentEncoding else { return nil }
        return plainToken(decoded)
    }

    private static func plainToken(_ token: String) -> String? {
        guard !token.isEmpty, token.utf16.count <= 512,
              token.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }),
              token != ".", token != "..", !token.contains("\\") else { return nil }
        return token
    }

    /// Absent or empty has no id. A present value that is not a positive canonical id fails the whole link.
    private static func optionalID(_ raw: String?) -> ParsedID {
        guard let raw, !raw.isEmpty else { return .absent }
        guard let id = positiveID(raw) else { return .invalid }
        return .value(id)
    }

    private enum ParsedID: Equatable {
        case absent, invalid, value(Int)
        var value: Int? { if case .value(let id) = self { return id }; return nil }
    }

    private static func positiveID(_ text: String) -> Int? {
        guard text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }
}

public struct JourneyLinkIntake: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable { case referral, gift, seat }
    public let kind: Kind
    public let token: String
    public let activityID: Int?
    public let topicID: Int?

    public init(kind: Kind, token: String, activityID: Int?, topicID: Int?) {
        self.kind = kind
        self.token = token
        self.activityID = activityID
        self.topicID = topicID
    }
}
