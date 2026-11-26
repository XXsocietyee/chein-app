import Foundation

/// Source official-inbox (pages/activity/official-inbox) row rules over decoded inbox rows.
/// Display/eligibility only: the coordinator, server snapshot and the dormant production
/// approval still decide whether any reviewed command may be dispatched.
public enum OfficialInboxPresentation {
    /// Source `organizerInvite`: an OFFICIAL party with the ORGANIZER role.
    public static func isOrganizerInvite(_ invite: OfficialPartyInvite) -> Bool {
        invite.partyType == "OFFICIAL" && invite.role == "ORGANIZER"
    }
    /// Source wxml: every INVITED row offers decline then accept; ACCEPTED/ACTIVE rows offer
    /// withdraw unless the row is the organizer, which must transfer first.
    public static func actions(for invite: OfficialPartyInvite) -> [OfficialResponseAction] {
        switch invite.status {
        case "INVITED": return [.decline, .accept]
        case "ACCEPTED", "ACTIVE": return isOrganizerInvite(invite) ? [] : [.withdraw]
        default: return []
        }
    }
    /// Source wxml shows the organizer transfer explanation instead of a withdraw button.
    public static func showsOrganizerTransferNotice(_ invite: OfficialPartyInvite) -> Bool {
        isOrganizerInvite(invite) && ["ACCEPTED", "ACTIVE"].contains(invite.status ?? "")
    }
    /// Source `act`: an organizer withdrawal never builds a request ("主办需先完成转交才能退出").
    /// OFFICIAL withdrawals are rejected by the backend's dedicated organizer commands, so the
    /// same hint is used for any OFFICIAL party instead of building an invalid request.
    public static func requiresOrganizerTransfer(_ invite: OfficialPartyInvite, action: OfficialResponseAction) -> Bool {
        action == .withdraw && (isOrganizerInvite(invite) || invite.partyType == "OFFICIAL")
    }
    public static func buttonKey(_ action: OfficialResponseAction) -> String {
        switch action {
        case .accept: return "official.privateParity.inbox.accept"
        case .decline: return "official.privateParity.inbox.decline"
        case .withdraw: return "official.privateParity.inbox.withdraw"
        }
    }
    /// Source modal titles.
    public static func confirmationTitleKey(_ invite: OfficialPartyInvite, action: OfficialResponseAction) -> String {
        switch action {
        case .accept: return isOrganizerInvite(invite) ? "official.privateParity.inbox.confirm.acceptOrganizerTitle" : "official.privateParity.inbox.confirm.acceptTitle"
        case .decline: return "official.privateParity.inbox.confirm.declineTitle"
        case .withdraw: return "official.privateParity.inbox.confirm.withdrawTitle"
        }
    }
    /// Source modal content.
    public static func confirmationBodyKey(_ invite: OfficialPartyInvite, action: OfficialResponseAction) -> String {
        if isOrganizerInvite(invite) {
            return action == .accept ? "official.privateParity.inbox.confirm.organizerAcceptBody" : "official.privateParity.inbox.confirm.organizerDeclineBody"
        }
        return action == .accept ? "official.privateParity.inbox.confirm.acceptBody" : "official.privateParity.inbox.confirm.changeBody"
    }
    /// Source official-inbox load failure title and detail copy.
    public static let loadFailureTitle = "邀约没有加载出来"
    public static let loadFailureDetail = "邀约加载失败"
    public static let loadFailureTitleKey = "official.w206.inbox.failed.title"
    public static let loadFailureDetailKey = "official.w206.inbox.failed.detail"
    public static func serviceWindow(start: OfficialEventTime?, end: OfficialEventTime?) -> OfficialServiceWindow {
        OfficialServiceWindow(start: start, end: end)
    }
    public static func serviceWindowText(start: OfficialEventTime?, end: OfficialEventTime?) -> String {
        OfficialServiceWindow(start: start, end: end).sourceText
    }
}

public extension OfficialResponseAction {
    /// Source `_submitAction` fixed audit reasons; accept sends an empty reason.
    var sourceReason: String {
        switch self {
        case .accept: return ""
        case .decline: return "主体拒绝本场邀约"
        case .withdraw: return "主体退出本场职责"
        }
    }
}

public extension OfficialActionCommand {
    /// The only inbox request shape: the current server row's party ID/type and the
    /// source's fixed reason. User text never reaches the audited reason.
    static func sourceInboxResponse(to invite: OfficialPartyInvite, action: OfficialResponseAction) -> OfficialActionCommand {
        .respond(partyID: invite.id, type: invite.partyType ?? "", action: action, reason: action.sourceReason)
    }
}

/// Source `timeRange(windowStart, windowEnd)`. Numeric (or all-digit) values are epoch
/// milliseconds shown in Asia/Shanghai; text dates are kept verbatim, never reinterpreted.
public enum OfficialServiceWindow: Equatable {
    public enum Bound: Equatable {
        /// Source "不限".
        case open
        case time(month: Int, day: Int, hour: Int, minute: Int)
        case text(String)
    }
    /// Source "未限定服务时段".
    case unbounded
    case range(Bound, Bound)

    public init(start: OfficialEventTime?, end: OfficialEventTime?) {
        if start == nil && end == nil { self = .unbounded; return }
        self = .range(Self.bound(start), Self.bound(end))
    }
    static func bound(_ value: OfficialEventTime?) -> Bound {
        switch value {
        case nil: return .open
        case .milliseconds(let ms)?: return clock(ms) ?? .open
        case .text(let text)?:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }), let ms = Double(trimmed), let value = clock(ms) { return value }
            return .text(text)
        }
    }
    private static func clock(_ ms: Double) -> Bound? {
        guard ms.isFinite, abs(ms) < 1e15 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
        let parts = calendar.dateComponents([.month, .day, .hour, .minute], from: Date(timeIntervalSince1970: ms / 1000))
        guard let month = parts.month, let day = parts.day, let hour = parts.hour, let minute = parts.minute else { return nil }
        return .time(month: month, day: day, hour: hour, minute: minute)
    }
    /// Exact source zh-Hans text, e.g. "9月22日 09:00 — 不限".
    public var sourceText: String {
        switch self {
        case .unbounded: return "未限定服务时段"
        case let .range(start, end): return Self.text(start) + " — " + Self.text(end)
        }
    }
    private static func text(_ bound: Bound) -> String {
        switch bound {
        case .open: return "不限"
        case let .time(month, day, hour, minute): return "\(month)月\(day)日 " + String(format: "%02d:%02d", hour, minute)
        case .text(let value): return value
        }
    }
}

/// Additional party-inbox fields the shared OfficialPartyInvite does not decode yet.
/// Kept separate so the shared contract stays untouched; hosts must decode the same row.
public struct OfficialInboxWindowFacts: Decodable, Equatable {
    public let windowStart: OfficialEventTime?
    public let windowEnd: OfficialEventTime?
    private enum CodingKeys: String, CodingKey { case windowStart, windowEnd }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        windowStart = try? c.decode(OfficialEventTime.self, forKey: .windowStart)
        windowEnd = try? c.decode(OfficialEventTime.self, forKey: .windowEnd)
    }
    public var window: OfficialServiceWindow { OfficialServiceWindow(start: windowStart, end: windowEnd) }
}

/// A party-inbox number. A JSON integer, including 0, stays that integer.
/// Null, a missing value, a numeric string, `UNKNOWN`, a bool, and a fraction are unknown.
public enum OfficialInboxQuantity: Decodable, Equatable, Sendable {
    case known(Int)
    case unknown
    public static let unknownMark = "—"
    public var displayText: String {
        switch self {
        case .known(let value): return String(value)
        case .unknown: return Self.unknownMark
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .unknown; return }
        if let value = try? c.decode(Int.self) { self = .known(value); return }
        if let value = try? c.decode(Double.self), let number = Self.exact(value) { self = .known(number); return }
        self = .unknown
    }
    private static func exact(_ value: Double) -> Int? {
        let limit = 9_007_199_254_740_991.0
        guard value.isFinite, value >= -limit, value <= limit else { return nil }
        return Int(exactly: value)
    }
}

/// Read phase for the existing party-inbox contract. A path this repo does not mark
/// live stays hidden (`nil`). Unknown is not an empty list and is never stored as 0.
public enum OfficialInboxPageState: Equatable, Sendable {
    case loading
    case empty
    case error
    case unknown
    case ready(rowCount: Int)
}

public enum OfficialInboxPageModel {
    /// Already wired by `OfficialEventService.partyInbox`. Not a new route.
    public static let partyInboxPath = "api/official/v2/party-inbox"
    public static func state(path: String = partyInboxPath, loading: Bool, failed: Bool, rows: [OfficialPartyInvite]?) -> OfficialInboxPageState? {
        guard ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction else { return nil }
        if loading { return .loading }
        if failed { return .error }
        guard let rows else { return .unknown }
        if rows.isEmpty { return .empty }
        return .ready(rowCount: rows.count)
    }
    /// Empty is a known zero. Loading, error, and unknown stay an em dash.
    public static func rowCountText(_ state: OfficialInboxPageState) -> String {
        switch state {
        case .ready(let count): return count > 0 ? String(count) : OfficialInboxQuantity.unknownMark
        case .empty: return "0"
        case .loading, .error, .unknown: return OfficialInboxQuantity.unknownMark
        }
    }
}

/// Source official-mine publisher view (activityStatusText(status, 'owner')).
public enum OfficialPublishedPresentation {
    public static func ownerStatusKey(_ status: Int?) -> String {
        switch status {
        case 0?: return "official.privateParity.published.status.draft"
        case 1?: return "official.privateParity.published.status.pending"
        case 2?: return "official.privateParity.published.status.registration"
        case 3?: return "official.privateParity.published.status.live"
        case 4?: return "official.privateParity.published.status.settling"
        case 5?, 6?: return "official.privateParity.published.status.ended"
        case 9?: return "official.privateParity.published.status.offline"
        default: return "official.privateParity.published.status.unknown"
        }
    }
    /// Source `nonBlank`: trimmed text, or nil for the localized fallback.
    public static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
    /// Source official-mine category suffix: `" · \(category)"` when non-blank.
    public static func categorySuffix(_ category: String?) -> String? {
        guard let trimmed = nonBlank(category) else { return nil }
        return " · \(trimmed)"
    }
    /// Source official-mine city + optional category suffix line.
    public static func cityAndCategoryLine(city: String?, category: String?, cityFallback: String = "城市待确认") -> String {
        let cityText = nonBlank(city) ?? cityFallback
        return cityText + (categorySuffix(category) ?? "")
    }
    /// Source official-mine broadcast summary line (`"一起发/分开发 · 发给 … · 城市"` with `"待确认"` fallbacks).
    public static func broadcastSummaryLine(_ facts: OfficialPublishedBroadcastFacts) -> String {
        facts.sourceLine
    }
}

/// Source official-mine `_decoBc` over broadcast fields the shared OfficialBroadcast does not
/// decode (copyMode, audience, status, city). Unknown values stay explicit, never guessed.
public struct OfficialPublishedBroadcastFacts: Decodable, Equatable {
    public enum Mode: Equatable { case together, separate, unknown }
    public enum Status: Equatable { case draft, pending, sent, withdrawn, unknown }
    public let id: Int?
    public let mode: Mode
    public let status: Status
    /// nil when empty or containing any role outside player/club/merchant (source "对象待确认").
    public let audience: [OfficialAudience]?
    /// nil when blank (source "范围待确认").
    public let city: String?
    private enum CodingKeys: String, CodingKey { case id, copyMode, audience, status, city }
    public init(id: Int? = nil, mode: Mode, status: Status = .unknown, audience: [OfficialAudience]?, city: String?) {
        self.id = id
        self.mode = mode
        self.status = status
        self.audience = (audience?.isEmpty == false) ? audience : nil
        self.city = OfficialPublishedPresentation.nonBlank(city)
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(Int.self, forKey: .id)
        switch try? c.decode(Int.self, forKey: .copyMode) {
        case 1?: mode = .together
        case 2?: mode = .separate
        default: mode = .unknown
        }
        switch try? c.decode(Int.self, forKey: .status) {
        case 0?: status = .draft
        case 1?: status = .pending
        case 2?: status = .sent
        case 3?: status = .withdrawn
        default: status = .unknown
        }
        let raw = ((try? c.decode(String.self, forKey: .audience)) ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let roles = raw.compactMap(OfficialAudience.init(rawValue:))
        audience = !raw.isEmpty && roles.count == raw.count ? roles : nil
        city = OfficialPublishedPresentation.nonBlank(try? c.decode(String.self, forKey: .city))
    }
    /// Exact source zh-Hans row: "一起发 · 发给 玩家 / 商家 · 杭州".
    public var sourceLine: String {
        let modeText: String
        switch mode { case .together: modeText = "一起发"; case .separate: modeText = "分开发"; case .unknown: modeText = "发送方式待确认" }
        let names: [OfficialAudience: String] = [.player: "玩家", .club: "俱乐部", .merchant: "商家"]
        let audienceText = audience.map { $0.compactMap { names[$0] }.joined(separator: " / ") } ?? "对象待确认"
        return modeText + " · 发给 " + audienceText + " · " + (city ?? "范围待确认")
    }
    /// Exact source zh-Hans badge (BC_ST).
    public var sourceStatusText: String {
        switch status { case .draft: return "草稿"; case .pending: return "待发"; case .sent: return "已发"; case .withdrawn: return "已撤"; case .unknown: return "状态待确认" }
    }
}

/// A count the server actually sent. Unknown, null, and a non-numeric value stay an em dash.
public enum OfficialMineCount: Equatable {
    case unknown
    case value(Int)
    public static let unknownMark = "—"
    /// Nil, a negative, or an unreadable number is unknown. A server 0 stays 0.
    public static func server(_ number: Int?) -> OfficialMineCount {
        guard let number, number >= 0 else { return .unknown }
        return .value(number)
    }
    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownMark
        case .value(let number):
            guard number >= 0 else { return Self.unknownMark }
            return String(number)
        }
    }
}

public enum OfficialMinePageIssue: Equatable {
    case notConfigured, unauthorized, noPublisherPermission, forbidden, unavailable
    case unreadable, rejected(Int), httpStatus(Int), businessCode(Int), cancelled, failed
    /// The body was not a countable list. Callers show an em dash, never 0.
    public var isUnreadable: Bool {
        if case .unreadable = self { return true }
        return false
    }
    public init(_ error: Error) {
        if error is CancellationError { self = .cancelled; return }
        if let api = error as? APIError {
            switch api {
            case .notConfigured, .invalidConfiguration: self = .notConfigured
            case .invalidRequest, .malformedResponse: self = .unreadable
            case .unauthorized: self = .unauthorized
            case .httpStatus(let code): self = .httpStatus(code)
            case .businessCode(let code): self = .businessCode(code)
            }
            return
        }
        if let read = error as? OfficialReadFailure {
            switch read {
            case .noPublisherPermission: self = .noPublisherPermission
            case .unavailable: self = .unavailable
            case .forbidden: self = .forbidden
            case .rejected(let code), .explained(let code, _): self = .rejected(code)
            }
            return
        }
        self = .failed
    }
}

public enum OfficialMineAccessibility {
    public static let content = "official.published.content"
    public static let loading = "official.published.loading"
    public static let empty = "official.published.empty"
    public static let emptyEvents = "official.published.empty.events"
    public static let emptyBroadcasts = "official.published.empty.broadcasts"
    public static let error = "official.published.error"
    public static let unknown = "official.published.unknown"
    public static let entry = "official.publishedLink"
    public static func event(_ id: Int) -> String { "official.published.event.\(id)" }
    public static func eventStatus(_ id: Int) -> String { "official.published.eventStatus.\(id)" }
    public static func broadcast(_ id: Int) -> String { "official.broadcast.\(id)" }
}

public struct OfficialMineEventRow: Equatable {
    public let id: Int
    public let title: String?
    public let statusKey: String
    public let cityText: String
    public let categoryKey: String?
    public let accessibilityIdentifier: String
    public let statusAccessibilityIdentifier: String
    public init(_ event: OfficialEvent) {
        id = event.id
        title = OfficialPublishedPresentation.nonBlank(event.title)
        statusKey = OfficialPublishedPresentation.ownerStatusKey(event.status)
        cityText = OfficialPublishedPresentation.nonBlank(event.city) ?? OfficialMineCount.unknownMark
        categoryKey = OfficialPublishedPresentation.nonBlank(event.category) == nil ? nil : event.categoryKey
        accessibilityIdentifier = OfficialMineAccessibility.event(event.id)
        statusAccessibilityIdentifier = OfficialMineAccessibility.eventStatus(event.id)
    }
}

public struct OfficialMineBroadcastRow: Equatable {
    public let id: Int
    public let title: String?
    public let reach: OfficialMineCount
    public let facts: OfficialPublishedBroadcastFacts?
    public let statusKey: String?
    public let accessibilityIdentifier: String
    public init(_ broadcast: OfficialBroadcast) {
        id = broadcast.id
        title = OfficialPublishedPresentation.nonBlank(broadcast.title)
        reach = OfficialMineCount.server(broadcast.reach)
        facts = broadcast.facts
        statusKey = broadcast.facts.map { OfficialMinePageModel.broadcastStatusKey($0.status) }
        accessibilityIdentifier = OfficialMineAccessibility.broadcast(broadcast.id)
    }
}

/// Read model for pages/activity/official-mine/index. It projects the existing
/// my-published payload. It does not open a route. Publish stays hidden unless
/// the existing can-publish read grants it.
public struct OfficialMinePageModel: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(OfficialMinePageIssue)
        case unknown
        case ready
    }
    public let phase: Phase
    public let eventCount: OfficialMineCount
    public let broadcastCount: OfficialMineCount
    public let events: [OfficialMineEventRow]
    public let broadcasts: [OfficialMineBroadcastRow]
    /// True only when an existing can-publish read returned true for a loaded page.
    public let showsPublishActions: Bool
    public var eventCountText: String { eventCount.displayText }
    public var broadcastCountText: String { broadcastCount.displayText }
    public var accessibilityIdentifier: String {
        switch phase {
        case .loading: return OfficialMineAccessibility.loading
        case .empty: return OfficialMineAccessibility.empty
        case .error: return OfficialMineAccessibility.error
        case .unknown: return OfficialMineAccessibility.unknown
        case .ready: return OfficialMineAccessibility.content
        }
    }
    public static func broadcastStatusKey(_ status: OfficialPublishedBroadcastFacts.Status) -> String {
        switch status {
        case .draft: return "official.w206.broadcast.status.draft"
        case .pending: return "official.w206.broadcast.status.pending"
        case .sent: return "official.w206.broadcast.status.sent"
        case .withdrawn: return "official.w206.broadcast.status.withdrawn"
        case .unknown: return "official.w206.broadcast.status.unknown"
        }
    }
    public static let loading = OfficialMinePageModel(
        phase: .loading, eventCount: .unknown, broadcastCount: .unknown,
        events: [], broadcasts: [], showsPublishActions: false)
    public static let unknown = OfficialMinePageModel(
        phase: .unknown, eventCount: .unknown, broadcastCount: .unknown,
        events: [], broadcasts: [], showsPublishActions: false)
    public static func failure(_ issue: OfficialMinePageIssue) -> OfficialMinePageModel {
        OfficialMinePageModel(phase: .error(issue), eventCount: .unknown, broadcastCount: .unknown,
                              events: [], broadcasts: [], showsPublishActions: false)
    }
    public static func loaded(_ published: OfficialPublished, publisherCapabilityGranted: Bool = false) -> OfficialMinePageModel {
        let events = OfficialEventFilter.visible(published.events, bucket: .mine).map(OfficialMineEventRow.init)
        let broadcasts = published.broadcasts.filter { $0.id > 0 }.map(OfficialMineBroadcastRow.init)
        let phase: Phase = events.isEmpty && broadcasts.isEmpty ? .empty : .ready
        let granted = publisherCapabilityGranted && (phase == .empty || phase == .ready)
        return OfficialMinePageModel(phase: phase, eventCount: .value(events.count), broadcastCount: .value(broadcasts.count),
                                     events: events, broadcasts: broadcasts, showsPublishActions: granted)
    }
    public static func from(result: Result<OfficialPublished, Error>, publisherCapabilityGranted: Bool = false) -> OfficialMinePageModel {
        switch result {
        case .success(let value): return loaded(value, publisherCapabilityGranted: publisherCapabilityGranted)
        case .failure(let error):
            let issue = OfficialMinePageIssue(error)
            return issue.isUnreadable ? .unknown : failure(issue)
        }
    }
}

/// Loads the existing private my-published read. A missing publisher grant stays hidden.
/// This type does not add a route or a money-moving capability.
@MainActor public final class OfficialMinePageCoordinator {
    public private(set) var model: OfficialMinePageModel
    private var generation: UInt64 = 0
    public init() { model = .loading }
    public func reload(using reader: any OfficialEventReading) async {
        generation &+= 1
        let ticket = generation
        model = .loading
        guard reader.isConfigured else {
            guard generation == ticket else { return }
            model = .failure(.notConfigured)
            return
        }
        guard reader.isAuthenticated else {
            guard generation == ticket else { return }
            model = .failure(.unauthorized)
            return
        }
        do {
            let published = try await reader.myPublished()
            guard generation == ticket, !Task.isCancelled else { return }
            let granted: Bool
            do { granted = try await reader.canPublish() }
            catch { granted = false }
            guard generation == ticket, !Task.isCancelled else { return }
            model = .loaded(published, publisherCapabilityGranted: granted)
        } catch is CancellationError {
            return
        } catch {
            guard generation == ticket, !Task.isCancelled else { return }
            model = .from(result: .failure(error))
        }
    }
}
