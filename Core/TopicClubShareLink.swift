import Foundation

/// CLB-detail-11. Parses a topic share card that carries club attribution.
///
/// Accepts `pages/topic/index/index?id=&sourceClubId=&clubCode=` (optional leading slash,
/// `https` URL, or `chein://mp/…`). `sourceClubId` and `clubCode` are data a later
/// registration may place in `sourceChannelCode`. This parser does not choose that
/// value, open a route, or write a registration.
public struct TopicClubShareLink: Equatable, Sendable {
    public static let page = "pages/topic/index/index"
    /// Later registration field name. The value is not decided here.
    public static let laterRegistrationField = "sourceChannelCode"
    public let topicID: Int
    public let sourceClubId: Int
    public let clubCode: String
    public init(topicID: Int, sourceClubId: Int, clubCode: String) {
        self.topicID = topicID
        self.sourceClubId = sourceClubId
        self.clubCode = clubCode
    }
}

public enum TopicClubShareLinkParser {
    public static func parse(_ raw: String) -> TopicClubShareLink? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 2048, !trimmed.contains("\\"),
              !trimmed.contains("#") else { return nil }
        let components: URLComponents?
        if trimmed.contains("://") {
            components = URLComponents(string: trimmed)
        } else {
            let path = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
            components = URLComponents(string: "https://share.invalid" + path)
        }
        guard let components, components.user == nil, components.password == nil,
              components.port == nil, components.fragment == nil else { return nil }
        if trimmed.contains("://") {
            let scheme = components.scheme?.lowercased()
            if scheme == "https" {
                guard components.host != nil else { return nil }
            } else if scheme == "chein" {
                guard components.host?.lowercased() == "mp" else { return nil }
            } else { return nil }
        }
        var path = components.percentEncodedPath
        if path.hasPrefix("/") { path.removeFirst() }
        guard path == TopicClubShareLink.page, let items = components.queryItems,
              !items.isEmpty, Set(items.map(\.name)).count == items.count,
              items.allSatisfy({ $0.value != nil }) else { return nil }
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        guard Set(query.keys) == ["id", "sourceClubId", "clubCode"],
              let topicID = canonicalID(query["id"] ?? ""),
              let sourceClubId = canonicalID(query["sourceClubId"] ?? ""),
              let clubCode = clubCode(query["clubCode"] ?? "") else { return nil }
        return TopicClubShareLink(topicID: topicID, sourceClubId: sourceClubId, clubCode: clubCode)
    }

    private static func canonicalID(_ text: String) -> Int? {
        guard text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }

    private static func clubCode(_ text: String) -> String? {
        let blocked = Set("&=?/".unicodeScalars)
        guard (1...64).contains(text.unicodeScalars.count),
              text.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value != 127 && !blocked.contains($0) }) else { return nil }
        return text
    }
}
