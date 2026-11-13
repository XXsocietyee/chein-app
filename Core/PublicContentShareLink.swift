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

    /// Mini-program `pages/templatedetail/templatedetail?id=`.
    public static func discoveryTemplate(id: Int) -> URL? {
        universalLink(path: NativeContentTarget.Kind.template.sourcePath, id: id)
    }

    /// Mini-program `pages/templatedetail/topic-detail/index?id=`.
    /// Nil while that path is not already parsed. Callers then copy `topicTemplateCopyText`.
    public static func topicTemplate(id: Int) -> URL? {
        universalLink(path: "/pages/templatedetail/topic-detail/index", id: id)
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
