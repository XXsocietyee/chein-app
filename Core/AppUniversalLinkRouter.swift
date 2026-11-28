import Foundation

/// Where an incoming link goes. `deepLink` feeds the existing chein:// replay (`pendingDeepLink` → `replayDeepLink`);
/// `entry` feeds `receiveNativeIntent` (HomeLanding push). Parsing grants nothing: every destination keeps its own
/// sign-in, capability and confirmation gating (a club join still asks on the club page, a ticket still needs the owner).
public enum AppLinkDestination: Equatable {
    case deepLink(CheinDeepLink)
    case entry(NativeEntryIntent)
}

/// P1-1 (audit 11-28): the app-side half of "no share link or deep link can reach the app".
///
/// Accepted shapes (host = a verified origin, by default `https://www.chengyinhub.com`, the owner's Universal Link
/// domain from the 9-14 plan):
/// - `https://<host>/app/` → home
/// - `https://<host>/app/activity/<id>`, `/app/topic/<id>`, `/app/club/<id>`, `/app/template/<id>`, `/app/post/<id>`
/// - `https://<host>/app/club/<id>/join`, `/app/ticket/<id>`, `/app/roam/go`, `/app/referral/<t>`, `/app/gift/<t>`,
///   `/app/seat/<t>`, `/app/landing?k=…` → the same `CheinDeepLink` the chein:// scheme parses
/// - `https://<host>/app/mp/<mini-program page>?…` and `https://<host>/app/pages/…?…` → the mini-program page router
/// - `https://<host>/<any reviewed path>` (today's shares, `/pages/topic/index/index?id=N`) → `NativeEntryLinkPolicy`
/// - `https://<host>/app/wx<AppID>/…` is the WeChat SDK callback and is never routed here (nil, the SDK drivers own it).
/// The chein:// scheme accepts the same short content forms (`chein://activity/12`, `chein://topic/7`).
public struct AppUniversalLinkRouter {
    public static let defaultDomain = "www.chengyinhub.com"
    public static let pathPrefix = "/app"
    public let origins: Set<String>
    private let policy: NativeEntryLinkPolicy

    public init(verifiedHTTPSOrigins: Set<String>) {
        origins = Set(verifiedHTTPSOrigins.map { $0.lowercased() })
        policy = NativeEntryLinkPolicy(verifiedHTTPSOrigins: origins)
    }

    /// `https://<domain>` when `domain` is a plain lowercase host name, else nil (an empty or malformed build setting).
    public static func origin(domain raw: String?) -> String? {
        let domain = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !domain.isEmpty, domain.utf8.count <= 253, domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix("."),
              !domain.contains(".."),
              domain.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 }) else { return nil }
        return "https://" + domain
    }

    public func route(_ url: URL) -> AppLinkDestination? {
        guard url.absoluteString.utf8.count <= 8192,
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false), c.scheme?.lowercased() == "https",
              let host = c.host?.lowercased(), !host.isEmpty, c.user == nil, c.password == nil, c.port == nil, c.fragment == nil,
              origins.contains("https://" + host) else { return nil }
        let path = c.percentEncodedPath
        guard path == Self.pathPrefix || path.hasPrefix(Self.pathPrefix + "/") else {
            return policy.parse(url).map(AppLinkDestination.entry)
        }
        let rest = String(path.dropFirst(Self.pathPrefix.count))
        return Self.destination(path: rest, percentEncodedQuery: c.percentEncodedQuery, items: c.queryItems ?? [])
    }

    /// The chein:// fallback for the short content forms `CheinDeepLink` does not own.
    public static func cheinContent(_ url: URL) -> AppLinkDestination? {
        guard url.absoluteString.utf8.count <= 512,
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false), c.scheme?.lowercased() == CheinDeepLink.scheme,
              c.user == nil, c.password == nil, c.port == nil, c.fragment == nil, c.query == nil,
              let host = c.host?.lowercased(), !host.isEmpty else { return nil }
        let tail: [String] = c.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false).dropFirst().map { String($0) }
        return content(segments: [host] + tail)
    }

    /// `rest` is the path after `/app` (empty or starting with "/").
    static func destination(path rest: String, percentEncodedQuery: String?, items: [URLQueryItem]) -> AppLinkDestination? {
        if rest.isEmpty || rest == "/" {
            guard percentEncodedQuery == nil, let home = MiniProgramPageLink(path: "pages/index/index", query: [:]) else { return nil }
            return .entry(.miniProgramPage(home))
        }
        guard rest.hasPrefix("/"), !rest.contains("//"), !rest.lowercased().contains("%2e") else { return nil }
        let segments: [String] = rest.split(separator: "/", omittingEmptySubsequences: false).dropFirst().map { String($0) }
        guard let first = segments.first, !first.isEmpty, !segments.contains(where: { $0 == "." || $0 == ".." }) else { return nil }
        // WeChat SDK callback (`/app/wx<AppID>/oauth`, `/pay`): the SDK drivers handle it before routing.
        if first.hasPrefix("wx"), segments.count >= 2 { return nil }
        if first == "mp" {
            let page = "/" + segments.dropFirst().joined(separator: "/")
            return MiniProgramPageLink(path: page, items: items).map { AppLinkDestination.entry(.miniProgramPage($0)) }
        }
        if first == "pages" || first.hasPrefix("subpackage") || first == "team" || first == "badge" {
            return NativeNavigationContract.parse(path: rest, items: items).map(AppLinkDestination.entry)
        }
        if percentEncodedQuery == nil, let content = content(segments: segments) { return content }
        // `/app/club/12/join` → `chein://club/12/join`: the first segment becomes the chein host.
        let query: String = percentEncodedQuery.map { "?" + $0 } ?? ""
        let text: String = CheinDeepLink.scheme + "://" + String(rest.dropFirst()) + query
        guard let url = URL(string: text), let link = CheinDeepLink(url: url) else { return nil }
        return .deepLink(link)
    }

    /// `<kind>/<id>` for the public content kinds that have a detail page.
    static func content(segments: [String]) -> AppLinkDestination? {
        guard segments.count == 2 else { return nil }
        let kinds: [String: NativeContentTarget.Kind] = [
            "activity": .activity, "topic": .topic, "club": .club, "template": .template, "post": .post,
        ]
        guard let kind = kinds[segments[0].lowercased()], segments[1].utf8.count <= 18,
              segments[1].utf8.allSatisfy({ (48...57).contains($0) }),
              let id = Int(segments[1]), String(id) == segments[1],
              let target = NativeContentTarget(kind: kind, id: id) else { return nil }
        return .entry(.content(target))
    }
}
