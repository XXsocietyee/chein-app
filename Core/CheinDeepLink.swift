import Foundation

/// W3-6 custom-scheme deep links: `chein://roam/go`, `chein://ticket/<id>`, `chein://club/<id>/join`.
///
/// Parsing only classifies the URL into a destination. It grants nothing: it does not start a roam, open a
/// ticket or join a club. The host selects the owning root tab and the destination screen keeps its own
/// sign-in, capability and confirmation gating. Positive canonical decimal ids only; anything else is nil.
public enum CheinDeepLink: Equatable, Sendable {
    case roamGo
    case ticket(id: Int)
    case clubJoin(id: Int)

    public static let scheme = "chein"

    public init?(url: URL) {
        guard url.absoluteString.utf8.count <= 512,
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == Self.scheme,
              c.user == nil, c.password == nil, c.port == nil, c.query == nil, c.fragment == nil,
              let host = c.host?.lowercased(), !host.isEmpty else { return nil }
        let path = c.percentEncodedPath
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        // "" for no path, otherwise "/a" or "/a/b"; reject empty or doubled segments and trailing slashes.
        let rest: [String]
        if path.isEmpty { rest = [] }
        else {
            guard parts.first == "", parts.dropFirst().allSatisfy({ !$0.isEmpty }) else { return nil }
            rest = Array(parts.dropFirst())
        }
        switch (host, rest.count) {
        case ("roam", 1) where rest[0] == "go":
            self = .roamGo
        case ("ticket", 1):
            guard let id = Self.positiveID(rest[0]) else { return nil }
            self = .ticket(id: id)
        case ("club", 2) where rest[1] == "join":
            guard let id = Self.positiveID(rest[0]) else { return nil }
            self = .clubJoin(id: id)
        default:
            return nil
        }
    }

    /// Root tab that owns the destination: Roam for GO, Passport for tickets, Clubs for joining.
    public var rootTab: RootTab {
        switch self {
        case .roamGo: return .roam
        case .ticket: return .mine
        case .clubJoin: return .club
        }
    }

    private static func positiveID(_ text: String) -> Int? {
        guard text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }
}
