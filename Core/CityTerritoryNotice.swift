import Foundation
import CoreFoundation

/// fix/city-gaps-r3 §4: the City territory notifications arrive as IM system cards (`msgType = 3`, sender 0) with
/// `extra = {"cardType": "cityTerritory", "kind", "territoryId"?, "title", "points", "currency": "POINTS"}`.
/// `content` is a full Chinese sentence, so a client that does not know the card still shows it as text.
/// This is a navigation hint only: the property sheet re-reads the place from the server.
public struct CityTerritoryNotice: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        /// 被抢: a challenger took the place (defender compensation 40 %).
        case placeLost = "PLACE_LOST"
        /// 守住了: a challenge failed (defender compensation 30 %, or 0 when the challenger failed the on-site task).
        case defended = "DEFENDED"
        /// The first visit of the board day that earned rent.
        case rent = "RENT"
        /// The 03:00 settle credited pending rent.
        case rentSettled = "RENT_SETTLED"
    }

    public let messageID: Int
    public let kind: Kind
    public let territoryId: String?
    public let title: String
    /// 积分 only; nil when the server sent no number (shown as nothing, never 0).
    public let points: Int64?
    /// The server's own sentence (`content`), the fallback body.
    public let sentence: String?
    public let createdAt: String?

    public init(messageID: Int, kind: Kind, territoryId: String?, title: String, points: Int64?, sentence: String? = nil,
                createdAt: String? = nil) {
        self.messageID = messageID; self.kind = kind; self.territoryId = territoryId; self.title = title
        self.points = points; self.sentence = sentence; self.createdAt = createdAt
    }

    /// The card deep-links to the place's property sheet only when it names a territory.
    public var opensProperty: Bool { territoryId != nil }

    /// Accepts only a visible system card from sender 0 with `cardType == "cityTerritory"`, a known kind, a title and
    /// `currency == "POINTS"` (or no currency). Anything else is not a City card.
    public static func parse(message: MessagingMessage, conversation: MessagingConversation? = nil) -> Self? {
        if let conversation, conversation.kind != .system { return nil }
        guard message.isPayloadVisible, message.type == 3, message.senderID == 0,
              let text = message.extraJSON, let data = text.data(using: .utf8), data.count <= 16 * 1024 else { return nil }
        return parse(extra: data, messageID: message.id, content: message.content, createdAt: message.createdAt)
    }

    public static func parse(extra data: Data, messageID: Int, content: String? = nil, createdAt: String? = nil) -> Self? {
        guard let row = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              row["cardType"] as? String == "cityTerritory",
              let kind = (row["kind"] as? String).flatMap({ Kind(rawValue: $0.uppercased()) }),
              let title = trimmed(row["title"]) else { return nil }
        if let currency = row["currency"] as? String, currency.uppercased() != "POINTS" { return nil }
        return Self(messageID: messageID, kind: kind, territoryId: trimmed(row["territoryId"]), title: title,
                    points: integer(row["points"]), sentence: trimmed(content), createdAt: createdAt)
    }

    static func trimmed(_ value: Any?) -> String? {
        let text: String?
        if let string = value as? String { text = string }
        else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { text = number.stringValue }
        else { text = nil }
        guard let clean = text?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else { return nil }
        return clean
    }

    /// A whole number, rejecting booleans, fractions and negative values.
    static func integer(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            let whole = number.int64Value
            guard Double(whole) == number.doubleValue, whole >= 0 else { return nil }
            return whole
        }
        if let string = value as? String, let whole = Int64(string.trimmingCharacters(in: .whitespaces)), whole >= 0 { return whole }
        return nil
    }
}
