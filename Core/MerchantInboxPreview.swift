import Foundation

/// Source `pages/merchant/utils/inbox-preview.js` (owner ruling L03, walk-through v2 R02): the workbench
/// 「我的消息」 merges the inbox conversations (`api/im/conversations`), the received cooperation invites
/// (`api/coop/list` → received) and the business events (`api/merchant/events`), newest first, and shows the
/// first three. × marks one read, 清空 marks all read; when every item is read the card collapses to 都看完了.
/// Pure: no storage, no timers. Read marks are carried by `readKey` and kept by the caller.
public struct MerchantInboxItem: Equatable, Identifiable {
    public enum Kind: Equatable {
        case conversation(id: Int, type: Int)
        case invite(id: Int)
        /// `type` is the server's event type (`income`, `verify`, `stationInvite`, …); unknown stays as sent.
        case event(type: String, gameActivityID: Int?)
    }
    public let id: String
    public let kind: Kind
    public let systemImage: String
    /// Server text. `nil` title means the caller draws its own localized fallback for the kind.
    public let title: String?
    public let subtitle: String?
    /// Sort and display time. Nil sorts last and hides the time.
    public let date: Date?
    /// Shown verbatim when the time cannot be parsed into a date (source keeps the raw text in that case).
    public let rawTime: String?
    public let unread: Bool
    public let readKey: String
    /// Invite-only: the partner name and the cooperation kind for the localized "<partner> 的合作邀请" title.
    public let invitePartner: String?
    public let inviteStatus: Int?
}

public enum MerchantInboxPreview {
    public static let previewLimit = 3
    public static let chinaZone = TimeZone(secondsFromGMT: 8 * 3600)!

    /// Source `eventTimestamp`: `/api/merchant/events` sends "MM-dd HH:mm" in China time with no year. Use the
    /// current China year; a result more than a minute in the future (a December row read in January) is last year.
    public static func eventDate(_ text: String?, now: Date) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.range(of: #"^\d{2}-\d{2} \d{2}:\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = text.split(whereSeparator: { "- :".contains($0) }).compactMap { Int($0) }
        guard parts.count == 4 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chinaZone
        let year = calendar.component(.year, from: now)
        func at(_ y: Int) -> Date? {
            var c = DateComponents()
            c.year = y; c.month = parts[0]; c.day = parts[1]; c.hour = parts[2]; c.minute = parts[3]
            guard let date = calendar.date(from: c),
                  calendar.component(.month, from: date) == parts[0],
                  calendar.component(.day, from: date) == parts[1] else { return nil }
            return date
        }
        guard let date = at(year) else { return nil }
        return date.timeIntervalSince(now) > 60 ? at(year - 1) : date
    }

    /// Source `conversationTab`: group chats (type 4) are not shown in the mini-program inbox.
    static func showsConversation(_ c: MessagingConversation) -> Bool { (c.type ?? 1) != 4 }

    static func conversationItem(_ c: MessagingConversation) -> MerchantInboxItem {
        let type = c.type ?? 1
        let date = IMInboxTime.parse(c.lastMessageAt)
        let name: String? = type == 2 ? nil : c.counterparty?.nickname.flatMap { $0.isEmpty ? nil : $0 }
        let preview: String?
        switch c.lastMessageType {
        case 2?: preview = nil // [图片]: localized by the caller
        default:
            let text = (c.lastMessageText ?? "").replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            preview = text.isEmpty ? nil : text
        }
        let key = "conv-\(c.id)"
        return MerchantInboxItem(
            id: key, kind: .conversation(id: c.id, type: type),
            systemImage: type == 2 ? "bell" : "bubble.left",
            title: name, subtitle: preview, date: date, rawTime: nil,
            unread: (c.unread ?? 0) > 0,
            readKey: key + "@" + (date.map { String(Int64($0.timeIntervalSince1970 * 1000)) } ?? (c.lastMessageAt ?? "")),
            invitePartner: nil, inviteStatus: nil)
    }

    static func inviteItem(_ invite: CooperationInvite) -> MerchantInboxItem? {
        guard invite.id > 0 else { return nil }
        let date: Date?
        switch invite.createTime {
        case .milliseconds?: date = invite.createTime?.date
        case .text(let raw)?: date = IMInboxTime.parse(raw)
        case nil: date = nil
        }
        let topic = invite.topicName.flatMap { $0.isEmpty ? nil : $0 } ?? invite.topicId.map { "#\($0)" }
        let key = "invite-\(invite.id)"
        return MerchantInboxItem(
            id: key, kind: .invite(id: invite.id), systemImage: "link",
            title: nil, subtitle: topic, date: date, rawTime: nil, unread: true,
            readKey: key + "@" + (date.map { String(Int64($0.timeIntervalSince1970 * 1000)) } ?? ""),
            invitePartner: invite.partner?.name.flatMap { $0.isEmpty ? nil : $0 }, inviteStatus: invite.status)
    }

    static func eventItem(_ event: MerchantEvent, index: Int, now: Date) -> MerchantInboxItem {
        let type = event.type ?? ""
        // A pending station invite carries the session start (often in the future): sort it as "now", show the raw time.
        let pendingStation = type == "stationInvite"
        let date = pendingStation ? now : eventDate(event.time, now: now)
        let symbol: String
        switch type {
        case "income": symbol = "yensign.circle"
        case "verify": symbol = "checkmark.circle"
        default: symbol = "bell"
        }
        let game = pendingStation ? event.gameActivityID.flatMap { $0 > 0 ? $0 : nil } : nil
        return MerchantInboxItem(
            id: "event-\(index)", kind: .event(type: type, gameActivityID: game), systemImage: symbol,
            title: event.label.flatMap { $0.isEmpty ? nil : $0 },
            subtitle: event.content.isEmpty ? nil : event.content,
            date: date, rawTime: (pendingStation || date == nil) ? event.time : nil,
            unread: true,
            readKey: "event@\(type)@\(event.time)@\(event.content)",
            invitePartner: nil, inviteStatus: nil)
    }

    /// Source `buildInboxPreview`: merge, drop read items, newest first (undated last, original order kept), take `limit`.
    public static func build(
        conversations: [MessagingConversation],
        invites: [CooperationInvite],
        events: [MerchantEvent],
        now: Date,
        limit: Int = previewLimit,
        isRead: (String) -> Bool = { _ in false }
    ) -> [MerchantInboxItem] {
        let items = conversations.filter(showsConversation).map(conversationItem)
            + invites.compactMap(inviteItem)
            + events.enumerated().map { eventItem($0.element, index: $0.offset, now: now) }
        let ranked = items.enumerated()
            .filter { !isRead($0.element.readKey) }
            .sorted { a, b in
                let at = a.element.date?.timeIntervalSince1970 ?? -.infinity
                let bt = b.element.date?.timeIntervalSince1970 ?? -.infinity
                return at != bt ? at > bt : a.offset < b.offset
            }
        return ranked.prefix(max(0, limit)).map { $0.element }
    }

    /// Read marks newest first, capped like the source (300 keys).
    public static func trimmedReadMarks(_ marks: [String: Double], cap: Int = 300) -> [String: Double] {
        guard marks.count > cap else { return marks }
        let kept = marks.sorted { $0.value > $1.value }.prefix(cap)
        return Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
    }
}
