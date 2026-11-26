import Foundation

/// Club and post share paths from `pages/club/detail/index.js` `onShareAppMessage`.
/// Builds the path only. It does not open a route or attach ticket attribution.
public struct ClubShareLink: Equatable, Sendable {
    public static let page = "pages/club/detail/index"
    public let clubID: Int
    public let postID: Int?

    public init(clubID: Int, postID: Int?) {
        self.clubID = clubID
        self.postID = postID
    }

    public var path: String {
        var value = "/" + Self.page + "?id=" + String(clubID)
        if let postID { value += "&postId=" + String(postID) }
        return value
    }

    /// https universal link when the owner has supplied exactly one verified origin.
    /// The current origin set is empty, so this returns nil. No host is invented.
    public func httpsURL(verifiedOrigins: Set<String> = UniversalLinkConfiguration.verifiedHTTPSOrigins) -> URL? {
        guard verifiedOrigins.count == 1, let raw = verifiedOrigins.first else { return nil }
        guard let base = URLComponents(string: raw),
              base.scheme?.lowercased() == "https",
              let host = base.host?.lowercased(),
              base.user == nil, base.password == nil, base.port == nil,
              base.query == nil, base.fragment == nil,
              base.path.isEmpty || base.path == "/",
              !host.isEmpty, !host.contains(":") else { return nil }
        let sharePath = path
        return URL(string: "https://" + host + sharePath)
    }

    public static func club(id: Int) -> ClubShareLink? {
        guard id > 0 else { return nil }
        return ClubShareLink(clubID: id, postID: nil)
    }

    public static func post(clubID: Int, postID: Int) -> ClubShareLink? {
        guard clubID > 0, postID > 0 else { return nil }
        return ClubShareLink(clubID: clubID, postID: postID)
    }

    public static func parse(_ raw: String) -> ClubShareLink? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("#") else { return nil }
        let components: URLComponents?
        if trimmed.contains("://") {
            components = URLComponents(string: trimmed)
        } else {
            let path = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
            components = URLComponents(string: "https://share.invalid" + path)
        }
        guard let components else { return nil }
        var path = components.percentEncodedPath
        if path.hasPrefix("/") { path.removeFirst() }
        guard path == page, let items = components.queryItems, !items.isEmpty,
              Set(items.map(\.name)).count == items.count else { return nil }
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        guard Set(query.keys).isSubset(of: ["id", "postId"]),
              let clubID = canonical(query["id"] ?? "") else { return nil }
        if query["postId"] == nil { return ClubShareLink(clubID: clubID, postID: nil) }
        guard let postID = canonical(query["postId"] ?? "") else { return nil }
        return ClubShareLink(clubID: clubID, postID: postID)
    }

    private static func canonical(_ text: String) -> Int? {
        guard !text.isEmpty, text.allSatisfy(\.isNumber), let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }
}

/// MP `subpackageMember/myinvite/myinvite.js` `onShareAppMessage`.
/// Path only. No host is invented.
public struct MemberInviteShareLink: Equatable, Sendable {
    public static let page = "pages/index/index"
    public let userID: String

    public init?(userID: String) {
        let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 19, trimmed.allSatisfy(\.isNumber),
              let number = Int(trimmed), number > 0, String(number) == trimmed else { return nil }
        self.userID = trimmed
    }

    public var path: String { "/" + Self.page + "?inviter=" + userID }

    /// https only when the owner has supplied exactly one verified origin.
    /// The current origin set is empty, so this returns nil.
    public func httpsURL(verifiedOrigins: Set<String> = UniversalLinkConfiguration.verifiedHTTPSOrigins) -> URL? {
        guard verifiedOrigins.count == 1, let raw = verifiedOrigins.first else { return nil }
        guard let base = URLComponents(string: raw),
              base.scheme?.lowercased() == "https",
              let host = base.host?.lowercased(),
              base.user == nil, base.password == nil, base.port == nil,
              base.query == nil, base.fragment == nil,
              base.path.isEmpty || base.path == "/",
              !host.isEmpty, !host.contains(":") else { return nil }
        let sharePath = path
        return URL(string: "https://" + host + sharePath)
    }
}
