import Foundation

/// CLB-detail-11. Parses a topic share card that carries club attribution.
///
/// Accepts `pages/topic/index/index?id=&sourceClubId=&clubCode=` (optional leading slash,
/// `https` URL, or `chein://mp/…`). `id` and `topicId` are aliases. `clubCode` may be absent.
/// Extra query keys are ignored. `clubCode` is carried as data; a later registration places it
/// in `sourceChannelCode`. `sourceClubId` stays `sourceClubId`. This parser does not write a registration.
public struct TopicClubShareLink: Equatable, Sendable {
    public static let page = "pages/topic/index/index"
    /// Later registration field for `clubCode`. `sourceClubId` keeps its own name.
    public static let laterRegistrationField = "sourceChannelCode"
    public let topicID: Int
    public let sourceClubId: Int
    /// Trimmed 1–64. Nil when the link has a club id and no code (`clubCode` / `sourceChannelCode`).
    public let clubCode: String?
    public init(topicID: Int, sourceClubId: Int, clubCode: String?) {
        self.topicID = topicID
        self.sourceClubId = sourceClubId
        self.clubCode = clubCode
    }
}

/// Registration fields from a topic share card. Paid registration stays off and sends nothing.
/// `clubCode` is sent as `sourceChannelCode` only when the card is for this topic.
public enum TicketSourceRegistrationFields {
    public static func payload(topicID: Int, link: TopicClubShareLink?) -> [String: Any] {
        guard let link, link.topicID == topicID else { return [:] }
        var fields: [String: Any] = ["sourceClubId": link.sourceClubId]
        if let code = link.clubCode, !code.isEmpty {
            fields[TopicClubShareLink.laterRegistrationField] = code
        }
        return fields
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
        // utils/ticket-source.js: `id` or `topicId`, required `sourceClubId`, optional code. Extra keys are ignored.
        let topicRaw = (query["topicId"]?.isEmpty == false) ? query["topicId"]! : (query["id"] ?? "")
        guard let topicID = canonicalID(topicRaw),
              let sourceClubId = canonicalID(query["sourceClubId"] ?? "") else { return nil }
        let codeRaw = (query["clubCode"]?.isEmpty == false) ? query["clubCode"]! : query["sourceChannelCode"]
        let clubCode: String?
        if let codeRaw {
            let trimmed = codeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { clubCode = nil }
            else if let code = Self.clubCode(trimmed) { clubCode = code }
            else { return nil }
        } else { clubCode = nil }
        return TopicClubShareLink(topicID: topicID, sourceClubId: sourceClubId, clubCode: clubCode)
    }

    private static func canonicalID(_ text: String) -> Int? {
        guard text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }

    private static func clubCode(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...64).contains(trimmed.unicodeScalars.count),
              trimmed.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { return nil }
        return trimmed
    }
}
