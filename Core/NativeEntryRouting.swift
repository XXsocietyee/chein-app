import Foundation

/// Typed, source-backed inbound routes. Never infer merchant/member identity from an invite.
public enum NativeEntryIntent: Equatable {
    case teamInvitation(TeamInvitationRoute)
    case badge(ObjectBadgeDetailParameters)
    case routeError(NativeRouteFailure)
    case door(DoorIntent)
    case merchantInvitation(MerchantOperatorInviteRoute)
    case publicMerchant(PublicMerchantHomeTarget)
    /// FP-C3. A parsed destination only; no origin is enabled by it and presentation stays the host's choice.
    case content(NativeContentTarget)
    /// A mini-program page with a native parity screen. Parsing grants nothing; the screen keeps its own gating.
    case miniProgramPage(MiniProgramPageLink)
}
/// Positive server ids for public content destinations. Parsing grants no access: the destination screen
/// still reads through its own approved, authenticated source.
public struct NativeContentTarget: Equatable {
    public enum Kind: String, CaseIterable, Equatable {
        case activity, club, topic, template, post, poi, roamSession
        /// Mini-program source paths (docs/parity/page-map.csv). The id travels in the single `id` query item.
        public var sourcePath: String {
            switch self {
            case .activity: return "/pages/activity/detail/index"
            case .club: return "/pages/club/detail/index"
            case .topic: return "/pages/topic/index/index"
            case .template: return "/pages/templatedetail/templatedetail"
            case .post: return "/pages/square/detail/index"
            case .poi: return "/subpackageRoam/poi-detail/index"
            case .roamSession: return "/subpackageRoam/session/index"
            }
        }
    }
    public let kind: Kind
    public let id: Int
    public init?(kind: Kind, id: Int) { guard id > 0 else { return nil }; self.kind = kind; self.id = id }
}
public struct NativeEntryPresentation: Identifiable {
    public let id = UUID()
    public let intent: NativeEntryIntent
    public init(intent: NativeEntryIntent) { self.intent = intent }
}
/// Empty in the app host. An OS callback alone is not an origin/domain approval.
public struct NativeEntryLinkPolicy {
    private let origins: Set<String>
    public init(verifiedHTTPSOrigins: Set<String> = []) { origins = verifiedHTTPSOrigins }
    public func parse(_ url: URL) -> NativeEntryIntent? {
        guard url.absoluteString.utf8.count <= 8192, let c = URLComponents(url: url, resolvingAgainstBaseURL: false), c.scheme == "https",
              let host = c.host, !host.isEmpty, c.user == nil, c.password == nil,
              c.port == nil, c.fragment == nil, origins.contains("https://" + host.lowercased()) else { return nil }
        if let route = NativeNavigationContract.parse(path: c.percentEncodedPath, items: c.queryItems ?? []) { return route }
        if c.percentEncodedPath == "/door" {
            return DoorLinkPolicy(verifiedHTTPSOrigins: origins).parse(url).map(NativeEntryIntent.door)
        }
        let parts = c.percentEncodedPath.split(separator: "/").map(String.init)
        if c.percentEncodedPath == "/" + parts.joined(separator: "/"), c.query == nil, parts.count == 4, parts[0] == "merchant", parts[1] == "public-home", parts[2] == "member",
           let value = Int(parts[3]), String(value) == parts[3], let owner = PublicMerchantOwnerID(value) {
            return .publicMerchant(.ownerMemberID(owner))
        }
        if c.percentEncodedPath == "/" + parts.joined(separator: "/"), c.query == nil, parts.count == 3, parts[0] == "merchant", parts[1] == "public-home",
           let value = Int(parts[2]), String(value) == parts[2], let row = PublicMerchantRowID(value) {
            return .publicMerchant(.legacyMerchantRowID(row))
        }
        if let catalog = PublicCatalogLink.parse(path: c.percentEncodedPath, items: c.queryItems ?? []) {
            // F14c: `/catalog?id=` is the topic. Every other catalog link opens home.
            if catalog.screen == .list, let raw = catalog.fields["id"],
               let id = Int(raw), id > 0, String(id) == raw,
               let topic = NativeContentTarget(kind: .topic, id: id) {
                return .content(topic)
            }
            if let home = MiniProgramPageLink(path: "pages/index/index", query: [:]) {
                return .miniProgramPage(home)
            }
        }
        guard c.percentEncodedPath == "/merchant/team", let items = c.queryItems,
              items.count == 1, items[0].name == "invite",
              c.percentEncodedQuery?.hasPrefix("invite=") == true,
              let route = try? MerchantOperatorInviteRoute(path: c.percentEncodedPath, queryItems: items) else { return nil }
        return .merchantInvitation(route)
    }
}

/// FP-C10 seam. Maps a tapped push's payload to a typed intent. The backend has not published a payload key,
/// so the default accepts no key and routes nothing; the host passes the reviewed key(s) when the contract
/// exists. Only source paths (no scheme or host) are accepted, so a payload can never name an external URL.
public struct PushTapRouter {
    private let routeKeys: [String]
    public init(routeKeys: [String] = []) { self.routeKeys = routeKeys }
    public func intent(userInfo: [AnyHashable: Any]) -> NativeEntryIntent? {
        for key in routeKeys {
            guard let value = userInfo[key] as? String else { continue }
            let path = value.hasPrefix("/") ? value : "/" + value
            if let intent = NativeNavigationContract.parseInternal(path) { return intent }
        }
        return nil
    }
}
