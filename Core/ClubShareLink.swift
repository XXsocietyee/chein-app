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
