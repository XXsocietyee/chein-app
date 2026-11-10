import Foundation

/// Mini-program subpackageB/pages/im/list `tabOf`: type 2 is the system tab and
/// type 1/3 (and absent/unknown kinds, `parseInt(type) || 1`) are direct messages.
/// The mini-program hides type 4 because WeChat already owns groups; its source
/// comment reserves groups for the native app, so iOS keeps them on a third tab
/// that is only offered when the server actually returns a group row.
public enum IMInboxTab: String, CaseIterable, Hashable {
    case direct, system, group

    public static func tab(for conversation: MessagingConversation) -> IMInboxTab {
        switch conversation.kind {
        case .system: return .system
        case .group: return .group
        case .direct, .merchant, .unknown: return .direct
        }
    }
}

/// Pure projection of one confirmed `/api/im/conversations` snapshot. Badge
/// counts match the global red dot: muted rows never count (server unreadTotal
/// skips `muted == 1`); an unknown muted value is not treated as muted.
public struct IMInboxSummary: Equatable {
    public let conversations: [MessagingConversation]
    public init(conversations: [MessagingConversation]) { self.conversations = conversations }

    public var visibleTabs: [IMInboxTab] {
        conversations.contains { IMInboxTab.tab(for: $0) == .group } ? [.direct, .system, .group] : [.direct, .system]
    }
    /// Source default is the direct tab. A snapshot holding only group rows opens
    /// on groups so a native-only group inbox is not shown as an empty DM tab.
    public var initialTab: IMInboxTab {
        if !conversations.isEmpty, conversations.allSatisfy({ IMInboxTab.tab(for: $0) == .group }) { return .group }
        return .direct
    }
    public func rows(for tab: IMInboxTab) -> [MessagingConversation] {
        conversations.filter { IMInboxTab.tab(for: $0) == tab }
    }
    public func badge(for tab: IMInboxTab) -> Int {
        rows(for: tab).reduce(0) { total, row in
            row.muted == true ? total : total + max(0, row.unread ?? 0)
        }
    }
    /// `hasUnread` gates the read-all control: any visible row with unread > 0.
    public var hasUnread: Bool { conversations.contains { ($0.unread ?? 0) > 0 } }

    /// Badge text used by every unread surface in the source: `n > 99 ? '99+' : n`.
    public static func badgeText(_ count: Int?) -> String? {
        guard let count, count > 0 else { return nil }
        return count > 99 ? "99+" : String(count)
    }
}

/// Policy for conversation row preview text in P032 (`im/list`). Defaults to
/// `.redactedPlaceholder` (`"打开会话查看消息"`) so existing privacy-preserving row
/// rendering stays unchanged while allowing server preview text when unrecalled.
public enum IMConversationPreviewPolicy: Equatable, Sendable {
    case redactedPlaceholder
    case serverPreviewWhenUnrecalled

    public static let defaultPolicy: Self = .redactedPlaceholder
    public static let redactedPlaceholderText = "打开会话查看消息"

    public func previewText(serverPreview: String?, isRecalled: Bool = false) -> String {
        switch self {
        case .redactedPlaceholder:
            return Self.redactedPlaceholderText
        case .serverPreviewWhenUnrecalled:
            guard !isRecalled,
                  let trimmed = serverPreview?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return Self.redactedPlaceholderText
            }
            return trimmed
        }
    }

    public func previewText(for conversation: MessagingConversation, isRecalled: Bool = false) -> String {
        previewText(serverPreview: conversation.lastMessageText, isRecalled: isRecalled)
    }

    public static func resolve(
        for conversation: MessagingConversation,
        policy: Self = .redactedPlaceholder,
        isRecalled: Bool = false
    ) -> String {
        policy.previewText(for: conversation, isRecalled: isRecalled)
    }
}

/// Silent-refresh indicator model for P032/P033 (`正在刷新消息`) when refreshing
/// on top of an already-rendered conversation or message snapshot.
public struct IMSilentRefreshPresentation: Equatable, Sendable {
    public static let refreshingText = "正在刷新消息"

    public let isRefreshingWithSnapshot: Bool

    public init(isRefreshingWithSnapshot: Bool) {
        self.isRefreshingWithSnapshot = isRefreshingWithSnapshot
    }

    public init(isLoading: Bool, hasSnapshot: Bool) {
        self.isRefreshingWithSnapshot = isLoading && hasSnapshot
    }

    public var statusText: String? {
        isRefreshingWithSnapshot ? Self.refreshingText : nil
    }
}

/// Mini-program `fmtTime` (list) and `fmtAbs` (chat dividers). Server wall-clock
/// strings without an offset are anchored to China time (+08:00), as
/// utils/datetime `parseChinaString` does; calendar comparisons use that zone,
/// never the device zone. Unparseable values produce no text instead of a guess.
public enum IMInboxTime {
    public enum ListText: Equatable {
        case justNow
        case minutesAgo(Int)
        case clock(String)
        case yesterday
        case weekday(Int) // 0 = Sunday … 6 = Saturday, as JS getDay
        case monthDay(month: Int, day: Int)
    }
    public enum DividerText: Equatable {
        case today(clock: String)
        case yesterday(clock: String)
        case date(month: Int, day: Int, clock: String)
    }

    public static let chinaZone = TimeZone(secondsFromGMT: 8 * 3600)!
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chinaZone
        return calendar
    }

    public static func parse(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.count == 10, raw.allSatisfy(\.isNumber), let seconds = Double(raw) { return Date(timeIntervalSince1970: seconds) }
        if raw.count == 13, raw.allSatisfy(\.isNumber), let millis = Double(raw) { return Date(timeIntervalSince1970: millis / 1000) }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }
        let pattern = #"^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?)?$"#
        guard let match = raw.range(of: pattern, options: .regularExpression), match == raw.startIndex..<raw.endIndex else { return nil }
        let parts = raw.split(whereSeparator: { "-/ T:.".contains($0) }).compactMap { Int($0) }
        guard parts.count >= 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]; components.month = parts[1]; components.day = parts[2]
        components.hour = parts.count > 3 ? parts[3] : 0
        components.minute = parts.count > 4 ? parts[4] : 0
        components.second = parts.count > 5 ? parts[5] : 0
        guard let date = calendar.date(from: components),
              calendar.component(.month, from: date) == parts[1], calendar.component(.day, from: date) == parts[2] else { return nil }
        return date
    }

    public static func listText(_ raw: String?, now: Date) -> ListText? {
        guard let date = parse(raw) else { return nil }
        let diff = now.timeIntervalSince(date)
        if diff < 60 { return .justNow }
        if diff < 3600 { return .minutesAgo(Int(diff / 60)) }
        let calendar = calendar
        if calendar.isDate(date, inSameDayAs: now) { return .clock(clock(date)) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
        if diff < 7 * 86400 { return .weekday(calendar.component(.weekday, from: date) - 1) }
        return .monthDay(month: calendar.component(.month, from: date), day: calendar.component(.day, from: date))
    }

    public static func dividerText(_ date: Date, now: Date) -> DividerText {
        let calendar = calendar
        let hm = clock(date)
        if calendar.isDate(date, inSameDayAs: now) { return .today(clock: hm) }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday(clock: hm) }
        return .date(month: calendar.component(.month, from: date), day: calendar.component(.day, from: date), clock: hm)
    }

    /// Chat `decorate`: a divider precedes the first message and any message more
    /// than five minutes after the previous one. Messages without a parseable
    /// time never get a divider and do not reset the previous anchor to zero.
    public static func dividers(for messages: [MessagingMessage], now: Date) -> [Int: DividerText] {
        var result: [Int: DividerText] = [:]
        var last: Date?
        for message in messages {
            guard let date = parse(message.createdAt) else { continue }
            if last == nil || date.timeIntervalSince(last!) > 5 * 60 { result[message.id] = dividerText(date, now: now) }
            last = date
        }
        return result
    }

    private static func clock(_ date: Date) -> String {
        let calendar = calendar
        return String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
    }
}

/// Page-ready projection for `subpackageB/pages/im/list`. It reads the conversations
/// already returned by `MessagingReading.messagingConversations` (`api/im/conversations`).
/// A missing grant stays hidden. This type does not open a route or draw a view.
/// Unknown numbers are an em dash. A literal 0 stays 0.
public enum IMListPageReady {
    public static let unknownMark = "—"
    public static let conversationsPath = "api/im/conversations"

    public struct Grants: Equatable {
        public var readAll: Bool
        public var square: Bool
        public var coopInviteStrip: Bool
        public init(readAll: Bool = false, square: Bool = false, coopInviteStrip: Bool = false) {
            self.readAll = readAll
            self.square = square
            self.coopInviteStrip = coopInviteStrip
        }
        public static let none = Grants()
    }

    public struct IMListEmptyProjection: Equatable {
        public let showsSquare: Bool
        public let showsCoopInviteStrip: Bool
        public init(showsSquare: Bool, showsCoopInviteStrip: Bool) {
            self.showsSquare = showsSquare
            self.showsCoopInviteStrip = showsCoopInviteStrip
        }
    }

    public struct IMListRowProjection: Equatable {
        public let id: Int
        public let kind: MessagingConversationKind
        public let tab: IMInboxTab
        /// Nil when the server sent 0. An em dash when unread was absent.
        public let unreadBadge: String?
        public let unreadExact: String
        public let muted: Bool?
        public init(id: Int, kind: MessagingConversationKind, tab: IMInboxTab, unreadBadge: String?, unreadExact: String, muted: Bool?) {
            self.id = id
            self.kind = kind
            self.tab = tab
            self.unreadBadge = unreadBadge
            self.unreadExact = unreadExact
            self.muted = muted
        }
    }

    public struct IMListSnapshot: Equatable {
        public let rows: [IMListRowProjection]
        public let visibleTabs: [IMInboxTab]
        public let directUnread: String
        public let systemUnread: String
        public let groupUnread: String
        public let showsGroupTab: Bool
        public let showsReadAll: Bool
        public let showsSquare: Bool
        public let showsCoopInviteStrip: Bool
        public init(rows: [IMListRowProjection], visibleTabs: [IMInboxTab], directUnread: String, systemUnread: String, groupUnread: String, showsGroupTab: Bool, showsReadAll: Bool, showsSquare: Bool, showsCoopInviteStrip: Bool) {
            self.rows = rows
            self.visibleTabs = visibleTabs
            self.directUnread = directUnread
            self.systemUnread = systemUnread
            self.groupUnread = groupUnread
            self.showsGroupTab = showsGroupTab
            self.showsReadAll = showsReadAll
            self.showsSquare = showsSquare
            self.showsCoopInviteStrip = showsCoopInviteStrip
        }
    }

    public enum Phase: Equatable {
        case loading
        case empty(IMListEmptyProjection)
        case error
        case unknown
        case ready(IMListSnapshot)
    }

    public static func rowUnreadExact(_ unread: Int?) -> String {
        guard let unread, unread >= 0 else { return unknownMark }
        return String(unread)
    }

    public static func rowUnreadBadge(_ unread: Int?) -> String? {
        guard let unread else { return unknownMark }
        guard unread > 0 else { return nil }
        return unread > 99 ? "99+" : String(unread)
    }

    /// Muted rows are excluded. One absent unread on a counted row makes the total unknown.
    public static func unreadTotalText(_ conversations: [MessagingConversation], tab: IMInboxTab) -> String {
        let counts = conversations.filter { IMInboxTab.tab(for: $0) == tab && $0.muted != true }.map(\.unread)
        if counts.contains(where: { $0 == nil }) { return unknownMark }
        return String(counts.compactMap { $0 }.reduce(0, +))
    }

    public static func project(_ conversations: [MessagingConversation], grants: Grants = .none) -> Phase {
        if conversations.isEmpty {
            return .empty(IMListEmptyProjection(showsSquare: grants.square, showsCoopInviteStrip: grants.coopInviteStrip))
        }
        let summary = IMInboxSummary(conversations: conversations)
        let rows = conversations.map { conversation in
            IMListRowProjection(
                id: conversation.id,
                kind: conversation.kind,
                tab: IMInboxTab.tab(for: conversation),
                unreadBadge: rowUnreadBadge(conversation.unread),
                unreadExact: rowUnreadExact(conversation.unread),
                muted: conversation.muted)
        }
        return .ready(IMListSnapshot(
            rows: rows,
            visibleTabs: summary.visibleTabs,
            directUnread: unreadTotalText(conversations, tab: .direct),
            systemUnread: unreadTotalText(conversations, tab: .system),
            groupUnread: unreadTotalText(conversations, tab: .group),
            showsGroupTab: summary.visibleTabs.contains(.group),
            showsReadAll: grants.readAll && summary.hasUnread,
            showsSquare: false,
            showsCoopInviteStrip: grants.coopInviteStrip))
    }

    public static func countText(for phase: Phase) -> String {
        switch phase {
        case .ready(let snapshot): return String(snapshot.rows.count)
        case .empty: return "0"
        case .loading, .error, .unknown: return unknownMark
        }
    }

    public static func unreadText(for phase: Phase, tab: IMInboxTab) -> String {
        switch phase {
        case .ready(let snapshot):
            switch tab {
            case .direct: return snapshot.directUnread
            case .system: return snapshot.systemUnread
            case .group: return snapshot.groupUnread
            }
        case .empty: return "0"
        case .loading, .error, .unknown: return unknownMark
        }
    }
}

/// Applies one existing conversations read. Keeps a loaded snapshot when a later
/// read fails. An unconfigured or signed-out reader stays unknown and is not called.
public struct IMListPageCoordinator: Equatable {
    public private(set) var phase: IMListPageReady.Phase
    public var grants: IMListPageReady.Grants
    public init(grants: IMListPageReady.Grants = .none) {
        self.grants = grants
        phase = .loading
    }
    public var hasSnapshot: Bool {
        switch phase {
        case .ready, .empty: return true
        case .loading, .error, .unknown: return false
        }
    }
    @MainActor
    public mutating func reload(using reader: any MessagingReading) async {
        let keep = hasSnapshot
        if !keep { phase = .loading }
        guard reader.isConfigured, reader.identity != nil else {
            if !keep { phase = .unknown }
            return
        }
        do {
            phase = IMListPageReady.project(try await reader.messagingConversations(), grants: grants)
        } catch is CancellationError {
            if !keep { phase = .unknown }
        } catch {
            if !keep { phase = .error }
        }
    }
}

#if DEBUG
/// Synthetic conversations for the message-center list. No host, credential, or personal record.
public enum IMListFixtureData {
    public static let direct = #"{"conversationId":901,"type":1,"unread":3,"muted":0,"counterparty":{"nickname":"Fixture direct"}}"#
    public static let system = #"{"conversationId":902,"type":2,"unread":0,"muted":0}"#
    public static let merchant = #"{"conversationId":903,"type":3,"unread":2,"muted":0,"counterparty":{"nickname":"Fixture merchant"}}"#
    public static let group = #"{"conversationId":904,"type":4,"unread":1,"muted":1}"#
    public static let unknownKind = #"{"conversationId":905,"type":9,"unread":4,"muted":0}"#
    public static let unknownUnread = #"{"conversationId":906,"type":1,"muted":0}"#
    public static let list = "[\(direct),\(system),\(merchant),\(group),\(unknownKind),\(unknownUnread)]"
    public static let empty = "[]"
    public static func conversations(_ json: String) throws -> [MessagingConversation] {
        try JSONDecoder().decode([MessagingConversation].self, from: Data(json.utf8))
    }
}
#endif
