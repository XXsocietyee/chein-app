import Foundation

/// Names the screen a universal link or `chein://` / `chengyin://` link opens.
/// Merchant-center links name the player home tab while that gate is off. Money links keep the screen they already open.
public enum InboundLinkCatalog {
    public static let origin = "https://www.chengyinhub.com"
    public static let verifiedOrigin = "https://www.chengyinhub.com"

    public struct Decision: Equatable {
        public let screenName: String
        public let gate: String
        public let testName: String
    }

    public static func decide(url: URL, verifiedHTTPSOrigins: Set<String>, merchantCenterEnabled: Bool) -> Decision {
        let canonical = CheinDeepLink.canonicalURL(url)
        let routed = route(canonical, origins: verifiedHTTPSOrigins, merchantCenterEnabled: merchantCenterEnabled)
        return Decision(
            screenName: routed.screen,
            gate: routed.gate,
            testName: testName(url: url, gate: routed.gate, content: routed.content, screen: routed.screen)
        )
    }

    public static func sampleQuery(for path: String) -> [String: String] {
        guard let text = pagesByPath[path]?.query, !text.isEmpty else { return [:] }
        return parseQuery(text)
    }

    public static func httpsRoute(path: String, query: [String: String]) -> String {
        join(origin + "/" + path, query)
    }

    public static func mpRoute(scheme: String, path: String, query: [String: String]) -> String {
        join(scheme + "://mp/" + path, query)
    }

    public static func appRoute(path: String, query: [String: String]) -> String {
        join(origin + "/app/" + path, query)
    }

    public static func appMPRoute(path: String, query: [String: String]) -> String {
        join(origin + "/app/mp/" + path, query)
    }

    static func queryText(_ query: [String: String]) -> String {
        query.keys.sorted().map { "\($0)=\(query[$0]!)" }.joined(separator: "&")
    }

    private static func join(_ base: String, _ query: [String: String]) -> String {
        let text = queryText(query)
        return text.isEmpty ? base : base + "?" + text
    }

    private static func parseQuery(_ text: String) -> [String: String] {
        var query: [String: String] = [:]
        for part in text.split(separator: "&") {
            let bits = part.split(separator: "=", maxSplits: 1).map(String.init)
            query[bits[0]] = bits.count > 1 ? bits[1] : ""
        }
        return query
    }

    private struct Routed {
        let screen: String
        let gate: String
        let content: Bool
    }

    private static func route(_ url: URL, origins: Set<String>, merchantCenterEnabled: Bool) -> Routed {
        let scheme = url.scheme?.lowercased() ?? ""
        if CheinDeepLink.isPlayerScheme(scheme) {
            return routeChein(url, enabled: merchantCenterEnabled)
        }
        let router = AppUniversalLinkRouter(verifiedHTTPSOrigins: origins)
        if let destination = router.route(url) {
            return route(destination, enabled: merchantCenterEnabled)
        }
        if isWeChatCallback(url, origins: origins) {
            return Routed(screen: "WeChat SDK callback", gate: "no", content: false)
        }
        return Routed(screen: "no navigation", gate: "no", content: false)
    }

    private static func routeChein(_ url: URL, enabled: Bool) -> Routed {
        let host = url.host?.lowercased() ?? ""
        if host == "mp" {
            if let scene = homeScene(url) { return route(intent: scene, enabled: enabled) }
            if let door = homeReferral(url) { return route(intent: .door(door), enabled: enabled) }
            if let link = MiniProgramPageLink(cheinURL: url) { return route(intent: .miniProgramPage(link), enabled: enabled) }
            return Routed(screen: "NativeRouteErrorView", gate: "no", content: false)
        }
        if let link = CheinDeepLink(url: url) { return route(link) }
        if let destination = AppUniversalLinkRouter.cheinContent(url) { return route(destination, enabled: enabled) }
        return Routed(screen: "NativeRouteErrorView", gate: "no", content: false)
    }

    private static func route(_ destination: AppLinkDestination, enabled: Bool) -> Routed {
        switch destination {
        case .deepLink(let link): return route(link)
        case .entry(let intent): return route(intent: intent, enabled: enabled)
        }
    }

    private static func route(_ link: CheinDeepLink) -> Routed {
        switch link {
        case .roamGo: return Routed(screen: "Roam tab", gate: "no", content: false)
        case .ticket: return Routed(screen: "Ticket pass", gate: "sign-in", content: false)
        case .clubJoin: return Routed(screen: "ClubDetailView", gate: "no", content: false)
        case .referral: return Routed(screen: "JourneyLandingHost", gate: "no", content: false)
        case .gift, .seat: return Routed(screen: "JourneyLandingHost", gate: "money switch", content: false)
        }
    }

    private static func route(intent: NativeEntryIntent, enabled: Bool) -> Routed {
        if PlayerLaunch.isMerchantCenterIntent(intent), !enabled {
            return Routed(screen: "Home tab", gate: "yes", content: false)
        }
        let gated = PlayerLaunch.gate(intent, enabled: enabled)
        switch gated {
        case .content(let target):
            return Routed(screen: contentScreen(target.kind), gate: "no", content: true)
        case .miniProgramPage(let link):
            let hidden = PlayerLaunch.isHidden(page: link.page, enabled: enabled)
            let screen = hidden ? "Home tab" : ungatedScreen(page: link.page, query: link.query)
            return Routed(screen: screen, gate: gateLabel(page: link.page, query: link.query, enabled: enabled), content: isContentPage(link.page) && !hidden)
        case .routeError:
            return Routed(screen: "NativeRouteErrorView", gate: "no", content: false)
        case .badge:
            return Routed(screen: "ObjectBadgeShowroomView", gate: "no", content: false)
        case .teamInvitation:
            return Routed(screen: "SessionTeamDetailView", gate: "sign-in", content: false)
        case .publicMerchant:
            return Routed(screen: "PublicMerchantHomeView", gate: "no", content: false)
        case .merchantInvitation:
            return Routed(screen: "MerchantOperatorInvitationLandingView", gate: "no", content: false)
        case .door(let door):
            if door.scene == nil, door.inviter != nil { return Routed(screen: "Home tab", gate: "no", content: false) }
            return Routed(screen: "Door sheet", gate: "no", content: false)
        }
    }

    static func contentScreen(_ kind: NativeContentTarget.Kind) -> String {
        switch kind {
        case .activity: return "ActivityDetailView"
        case .club: return "ClubDetailView"
        case .topic: return "SessionTopicDetailView"
        case .template: return "DiscoveryTemplateDetailView"
        case .post: return "SquareDetailView"
        case .poi: return "RoamPOIDetailHost"
        case .roamSession: return "RoamPassportRecordView"
        }
    }

    static func ungatedScreen(page: String, query: [String: String]) -> String {
        if page == "subpackageRoam/session/index", query["shareToken"] != nil { return "RoamSharedFootprintView" }
        if page == "pages/userinfo/userinfo", query["userId"] == nil, query["id"] == nil { return "MPUserInfoMissingView" }
        return pagesByPath[page]?.screen ?? "unmapped"
    }

    static func gateLabel(page: String, query: [String: String], enabled: Bool) -> String {
        if PlayerLaunch.isHidden(page: page, enabled: enabled) { return "yes" }
        if page == "subpackageJourney/pages/landing/index", query["k"] == "g" || query["k"] == "s" { return "money switch" }
        if moneyPages.contains(page) { return "money switch" }
        return "no"
    }

    static func isContentPage(_ page: String) -> Bool {
        NativeContentTarget.Kind.allCases.contains { $0.sourcePath == "/" + page || $0.sourcePath == page }
    }

    static func testName(url: URL, gate: String, content: Bool, screen: String) -> String {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let path = url.path
        if CheinDeepLink.isPlayerScheme(scheme), host != "mp" {
            return content ? "testContentPagesOpenTheirScreens" : "testCheinAndChengyinShortForms"
        }
        if path == "/app" || (path.hasPrefix("/app/") && !path.hasPrefix("/app/pages/") && !path.hasPrefix("/app/mp/") && !path.hasPrefix("/app/subpackage")) {
            if path.hasPrefix("/app/wx") { return "testSpecialUniversalLinks" }
            if content { return "testContentPagesOpenTheirScreens" }
            return "testUniversalLinkShortForms"
        }
        if gate == "yes" { return "testMerchantRoutesFallBackToHome" }
        if gate == "money switch" { return "testMoneyRoutesKeepTheirScreens" }
        if screen == "no navigation" || screen == "WeChat SDK callback" { return "testSpecialUniversalLinks" }
        if isSpecial(url) { return "testSpecialUniversalLinks" }
        if content { return "testContentPagesOpenTheirScreens" }
        return "testReviewedPagesOpenOrFallBack"
    }

    private static func isSpecial(_ url: URL) -> Bool {
        let path = url.path
        if path == "/door" || path == "/team/join" || path == "/badge" || path == "/merchant/team" { return true }
        if path.hasPrefix("/merchant/public-home/") || path == "/catalog" || path.hasPrefix("/catalog/") { return true }
        if path == "/pages/index/index" {
            let query = url.query ?? ""
            if query.contains("scene=") || query.contains("inviter=") { return true }
        }
        if path == "/pages/team/join/index", url.query?.contains("teamId=") == true { return true }
        return false
    }

    private static func isWeChatCallback(_ url: URL, origins: Set<String>) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased(), origins.contains("https://" + host) else { return false }
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.count >= 2 && parts[0] == "app" && parts[1].hasPrefix("wx")
    }

    private static func homeQuery(_ url: URL) -> [String: String]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.path == "/pages/index/index" else { return nil }
        let items = components.queryItems ?? []
        guard Set(items.map(\.name)).count == items.count else { return nil }
        var query: [String: String] = [:]
        for item in items { query[item.name] = item.value ?? "" }
        return query
    }

    private static func homeScene(_ url: URL) -> NativeEntryIntent? {
        guard let query = homeQuery(url) else { return nil }
        return NativeNavigationContract.homeScene(query)
    }

    private static func homeReferral(_ url: URL) -> DoorIntent? {
        guard let query = homeQuery(url) else { return nil }
        return NativeNavigationContract.homeReferral(query)
    }
}
