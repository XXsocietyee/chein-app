import Foundation

/// Outbound public share links for a square post, a discovery template, and a topic template.
///
/// A `https://www.chengyinhub.com` URL is returned only when `CheinDeepLink` or `UniversalLinkParser`
/// already types that path. This type does not add a route, a query, or a host, and it does not write
/// `UniversalLinkConfiguration`. The China API host is read from `ReviewedMarketLaunch` and kept only
/// when it is still `www.chengyinhub.com`. Parsing does not open a connection or issue a referral.
public enum PublicContentShareLink {
    public static let httpsOrigin = "https://www.chengyinhub.com"

    /// Mini-program `pages/square/detail/index?id=` when `SquareL5ShareCard.isPubliclyShareable`.
    /// Any other post has no public URL.
    public static func squarePost(_ post: SquareL5ShareCard.Post?) -> URL? {
        guard SquareL5ShareCard.isPubliclyShareable(post), let raw = post?.id, let id = canonicalID(raw) else { return nil }
        return universalLink(path: NativeContentTarget.Kind.post.sourcePath, id: id)
    }

    /// Mini-program `pages/activity/detail/index?id=` (MP `onShareAppMessage` → `buildActivityShare` path). Function audit
    /// P2-2: the activity share card carries this link back, so the receiver can open the activity. No referral `ref`.
    public static func activity(id: Int) -> URL? {
        universalLink(path: NativeContentTarget.Kind.activity.sourcePath, id: id)
    }

    /// Mini-program `pages/topic/index/index?id=`.
    public static func topic(id: Int) -> URL? {
        universalLink(path: NativeContentTarget.Kind.topic.sourcePath, id: id)
    }

    /// Mini-program `pages/templatedetail/templatedetail?id=`.
    public static func discoveryTemplate(id: Int) -> URL? {
        universalLink(path: NativeContentTarget.Kind.template.sourcePath, id: id)
    }

    /// Mini-program `pages/templatedetail/topic-detail/index?id=` (MP `onShareAppMessage` path). P2-2: the universal-link
    /// parser already types this page (PC-A-8-1, `MPReviewedPageScreen`), so the share is the https link, not a bare path.
    /// Nil when the id is not canonical or the link would not parse back to the same page.
    public static func topicTemplate(id: Int) -> URL? {
        guard canonicalID(String(id)) != nil else { return nil }
        return reviewedPage("pages/templatedetail/topic-detail/index", items: [URLQueryItem(name: "id", value: String(id))])
    }

    /// Mini-program `subpackageJourney/pages/landing/index?k=r|g|s&t=` plus optional `aid` / `tid`: the link a
    /// seat invite (or an issued referral) is shared as. Nil when the token or ids would not parse back to the same
    /// landing. Building the URL issues nothing; the token comes from the server's own answer.
    public static func journeyLanding(_ intake: JourneyLinkIntake) -> URL? {
        let link = MiniProgramPageLink(journey: intake)
        guard let origin, MiniProgramPageLink(path: link.page, query: link.query) == link else { return nil }
        var components = URLComponents(string: origin)
        components?.path = "/" + link.page
        // Unreserved characters only, so `+`, `/`, `=` and `&` in a token survive the round trip.
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        components?.percentEncodedQuery = ["k", "t", "aid", "tid"].compactMap { key -> String? in
            guard let value = link.query[key], let encoded = value.addingPercentEncoding(withAllowedCharacters: unreserved) else { return nil }
            return key + "=" + encoded
        }.joined(separator: "&")
        guard let url = components?.url,
              let intent = UniversalLinkParser(verifiedHTTPSOrigins: [origin]).parse(url),
              case .miniProgramPage(let parsed) = intent, parsed == link else { return nil }
        return url
    }

    /// Mini-program `subpackageRoam/poi-detail/index?poiId=` (mp-nav r3: MP poi-detail/index.js:4 long-term contract,
    /// utils/place-share.js; the MP page opened with `?id=` shows 找不到这个节点). Nil while that path is not parsed back
    /// to the same place.
    public static func poi(id: Int) -> URL? {
        let path = NativeContentTarget.Kind.poi.sourcePath
        guard let origin, canonicalID(String(id)) != nil,
              let url = URL(string: "\(origin)\(path)?poiId=\(id)"),
              let intent = UniversalLinkParser(verifiedHTTPSOrigins: [origin]).parse(url),
              case .content(let target) = intent, target.kind == .poi, target.id == id else { return nil }
        return url
    }

    /// Mini-program `subpackageRoam/official-route/index?id=` (MP official-route/index.js `SHARE_PATH`, `onShareAppMessage` /
    /// `onShareTimeline`): the route detail share. Nil when the id is not canonical or the link would not parse back.
    public static func officialRoute(id: String) -> URL? {
        guard canonicalID(id) != nil else { return nil }
        return reviewedPage("subpackageRoam/official-route/index", items: [URLQueryItem(name: "id", value: id)])
    }

    /// Mini-program `pages/talent/list/index?tab=`. Nil while that page is not already a universal link.
    public static func clubHub(tab: String) -> URL? {
        guard tab == "feed" || tab == "club", let origin,
              let link = MiniProgramPageLink(path: "pages/talent/list/index", query: ["tab": tab]) else { return nil }
        var components = URLComponents(string: origin)
        components?.path = "/" + link.page
        components?.queryItems = [URLQueryItem(name: "tab", value: tab)]
        guard let url = components?.url,
              let intent = UniversalLinkParser(verifiedHTTPSOrigins: [origin]).parse(url),
              case .miniProgramPage(let parsed) = intent, parsed == link else { return nil }
        return url
    }

    /// CLB-detail-30 (MP club/detail js:3509-3545 `onShareAppMessage` path `/pages/club/detail/index?id=[&postId=]`):
    /// the club invite as an https universal link. Nil when the link would not parse back to the same page.
    public static func club(_ link: ClubShareLink) -> URL? {
        var items = [URLQueryItem(name: "id", value: String(link.clubID))]
        if let postID = link.postID { items.append(URLQueryItem(name: "postId", value: String(postID))) }
        return reviewedPage(ClubShareLink.page, items: items)
    }

    /// CLB-detail-30 / CLB-r10-detail-03 (MP club/detail 带票分享 `/pages/topic/index/index?id=&sourceClubId=&clubCode=`).
    /// Nil when the link would not parse back to the same page.
    public static func clubTicket(_ link: TopicClubShareLink) -> URL? {
        var items = [URLQueryItem(name: "id", value: String(link.topicID)),
                     URLQueryItem(name: "sourceClubId", value: String(link.sourceClubId))]
        if let code = link.clubCode, !code.isEmpty { items.append(URLQueryItem(name: "clubCode", value: code)) }
        return reviewedPage(TopicClubShareLink.page, items: items)
    }

    /// T-02 (MP pages/team/detail/index.js:546 `onShareAppMessage` path `/pages/team/join/index?code=`): the team
    /// invite as an https universal link carrying only the code. Nil when it would not parse back to the same invitation.
    public static func teamInvite(code: String) -> URL? {
        guard let origin else { return nil }
        var components = URLComponents(string: origin)
        components?.path = "/pages/team/join/index"
        components?.queryItems = [URLQueryItem(name: "code", value: code)]
        guard let url = components?.url,
              let intent = UniversalLinkParser(verifiedHTTPSOrigins: [origin]).parse(url),
              case .teamInvitation(let route) = intent, route.code == code, route.fromTeamID == nil else { return nil }
        return url
    }

    /// Builds `origin/<page>?<items>` and keeps it only when the existing universal-link parser reads back the same page.
    private static func reviewedPage(_ page: String, items: [URLQueryItem]) -> URL? {
        guard let origin, let link = MiniProgramPageLink(path: page, items: items) else { return nil }
        var components = URLComponents(string: origin)
        components?.path = "/" + page
        components?.queryItems = items
        guard let url = components?.url,
              let intent = UniversalLinkParser(verifiedHTTPSOrigins: [origin]).parse(url) else { return nil }
        switch intent {
        case .miniProgramPage(let parsed):
            return parsed == link ? url : nil
        case .content(let target):
            return items.count == 1 && target.kind.sourcePath == "/" + page && link.query["id"] == String(target.id) ? url : nil
        default:
            return nil
        }
    }

    /// Path text for a POI whose route is not a universal link. Not a URL.
    public static func poiCopyText(id: Int) -> String? {
        guard canonicalID(String(id)) != nil, poi(id: id) == nil else { return nil }
        return "\(NativeContentTarget.Kind.poi.sourcePath)?poiId=\(id)"
    }

    /// Path text for the talent club hub when it is not a universal link. Not a URL.
    public static func clubHubCopyText(tab: String) -> String? {
        guard tab == "feed" || tab == "club", clubHub(tab: tab) == nil else { return nil }
        return "/pages/talent/list/index?tab=\(tab)"
    }

    /// Mini-program `subpackageA/pages/infomationdetail/infomationdetail?id=` (source spelling).
    /// MP infomationdetail.js:161 share path; parsed back as that MP page. Nil for a non-canonical id;
    /// callers then copy `informationCopyText`.
    public static func information(id: Int) -> URL? {
        guard canonicalID(String(id)) != nil else { return nil }
        return reviewedPage("subpackageA/pages/infomationdetail/infomationdetail", items: [URLQueryItem(name: "id", value: String(id))])
    }

    /// Path text when the information page is not a universal link. Not a URL.
    public static func informationCopyText(id: Int) -> String? {
        guard canonicalID(String(id)) != nil, information(id: id) == nil else { return nil }
        return "/subpackageA/pages/infomationdetail/infomationdetail?id=\(id)"
    }

    /// Path text for a topic template whose route is not a universal link. Not a URL and not a referral.
    public static func topicTemplateCopyText(id: Int) -> String? {
        guard canonicalID(String(id)) != nil, topicTemplate(id: id) == nil else { return nil }
        return "/pages/templatedetail/topic-detail/index?id=\(id)"
    }

    /// Native `SquarePost` fields in the shape `isPubliclyShareable` already understands.
    /// A blank or `PUBLISHED` lifecycle is the mini-program's absent status. Numeric 1 stays 1.
    public static func l5Post(from post: SquarePost) -> SquareL5ShareCard.Post {
        SquareL5ShareCard.Post(
            id: post.id > 0 ? String(post.id) : nil,
            audience: absentIfBlank(post.audience),
            status: squareStatus(post.lifecycle),
            contents: post.contents,
            pics: nil,
            picList: post.images)
    }

    private static func universalLink(path: String, id: Int) -> URL? {
        guard let origin, canonicalID(String(id)) != nil,
              let url = URL(string: "\(origin)\(path)?id=\(id)"),
              acceptsExistingParser(url, path: path, id: id) else { return nil }
        return url
    }

    /// True only when an existing parser types this exact path and id. The default allowlist is not changed.
    private static func acceptsExistingParser(_ url: URL, path: String, id: Int) -> Bool {
        if let link = CheinDeepLink(url: url) {
            return link.journeyIntake == nil && path == url.path
        }
        guard let origin, let intent = UniversalLinkParser(verifiedHTTPSOrigins: [origin]).parse(url),
              case .content(let target) = intent, target.id == id, target.kind.sourcePath == path else { return false }
        return true
    }

    /// The reviewed China API origin, or nil if that constant is no longer this host.
    private static var origin: String? {
        guard let components = URLComponents(string: ReviewedMarketLaunch.chinaProductionBaseURL),
              components.scheme == "https",
              components.host == "www.chengyinhub.com",
              components.user == nil, components.password == nil, components.port == nil,
              httpsOrigin == "https://www.chengyinhub.com" else { return nil }
        return httpsOrigin
    }

    private static func squareStatus(_ lifecycle: String) -> String? {
        let trimmed = lifecycle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.uppercased() == "PUBLISHED" { return nil }
        if Double(trimmed) == 1 { return "1" }
        return trimmed
    }

    private static func absentIfBlank(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func canonicalID(_ raw: String) -> Int? {
        guard raw.utf8.count <= 18, raw.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(raw), value > 0, String(value) == raw else { return nil }
        return value
    }
}
