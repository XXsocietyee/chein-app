import Foundation
import CoreFoundation

// Source: data/models/official_event.dart and data/api/official_api.dart.
// This domain is unrelated to /api/activity/list and its date-derived ActivityBrowser buckets.
private struct OfficialKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ key: String) { stringValue = key }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
private extension KeyedDecodingContainer where Key == OfficialKey {
    func text(_ key: String) -> String? { try? decode(String.self, forKey: OfficialKey(key)) }
    func integer(_ key: String) -> Int? { try? decode(Int.self, forKey: OfficialKey(key)) }
    func flag(_ key: String) -> Bool? { try? decode(Bool.self, forKey: OfficialKey(key)) }
    func list<T: Decodable>(_ key: String) throws -> [T] {
        try decodeIfPresent([T].self, forKey: OfficialKey(key)) ?? []
    }
}

/// Text dates preserve the supplied timezone/format. Only numeric timestamps become Dates.
/// No implicit operational timezone or invented date is attached to a timezone-less string.
public enum OfficialEventTime: Decodable, Equatable {
    case text(String), milliseconds(Double)
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let number = try? c.decode(Double.self), number.isFinite { self = .milliseconds(number) }
        else if let text = try? c.decode(String.self), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self = .text(text) }
        else { throw APIError.malformedResponse }
    }
    /// Reuse the detail page's existing numeric display boundary. Raw server values
    /// remain intact; an out-of-range value never becomes a fabricated date or limit.
    public var displayMilliseconds: Double? {
        guard case .milliseconds(let value) = self, value.isFinite,
              value > 0, value < 1e15 else { return nil }
        return value
    }
    public var displayDate: Date? {
        displayMilliseconds.map { Date(timeIntervalSince1970: $0 / 1000) }
    }
}
public struct OfficialMission: Decodable, Equatable {
    public let code: String
    public let title: String
    public let description: String?
    public let type: String?
    public let complete: Bool?
    public let canVerifyArrival: Bool?
    public let binding: OfficialMissionBinding?
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        code = c.text("missionCode") ?? ""; title = c.text("title") ?? ""
        description = c.text("description"); type = c.text("missionType")
        complete = c.flag("complete"); canVerifyArrival = c.flag("canVerifyArrival")
        binding = try? c.decode(OfficialMissionBinding.self, forKey: OfficialKey("binding"))
    }
}
/// Source mission `binding`. A THEME sourceRefId is a cms_topic id: a positive long,
/// supplied as a number or a digit string. Anything else stays nil, never zero.
public struct OfficialMissionBinding: Decodable, Equatable {
    public let bindingType: String?
    public let sourceRefID: Int64?
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        bindingType = c.text("bindingType")
        let digits = c.text("sourceRefId")?.trimmingCharacters(in: .whitespaces)
        let parsed = (try? c.decode(Int64.self, forKey: OfficialKey("sourceRefId")))
            ?? digits.flatMap { !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) ? Int64($0) : nil }
        sourceRefID = parsed.flatMap { $0 > 0 ? $0 : nil }
    }
}
public struct OfficialCollectiveProgress: Decodable, Equatable {
    public let enabled: Bool
    public let current: Int?
    public let threshold: Int?
    public let percent: Int?
    public let reached: Bool?
    public var displayFraction: Double? { percent.map { Double(min(100, max(0, $0))) / 100 } }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        enabled = c.flag("enabled") == true
        current = c.integer("current"); threshold = c.integer("threshold")
        percent = c.integer("pct"); reached = c.flag("reached")
    }
}
public enum OfficialReward: Equatable {
    case badge, coupon, experience(String), collectiveCoupon
}
public struct OfficialEvent: Decodable, Equatable, Identifiable {
    public let id: Int
    public let title: String
    public let subtitle: String?
    public let coverImage: String?
    public let city: String?
    public let status: Int?
    public let story: String?
    public let rewardJSON: String?
    public let participants: Int?
    public let myProgress: Int?
    public let signed: Bool?
    public let roamEnabled: Bool
    public let paused: Bool
    public let pausedReason: String?
    /// Public-list information only. These facts never grant or deny participation.
    public let fulfillmentPolicy: String?
    public let recruitmentBlocked: Bool?
    public let recruitmentBlockedReason: String?
    public let eligible: Bool?
    public let contractVersion: Int?
    public let activityStart: OfficialEventTime?
    public let activityEnd: OfficialEventTime?
    public let bannerEnabled: Bool
    public let participantAvatars: [String]
    public let missions: [OfficialMission]
    public let collective: OfficialCollectiveProgress?
    /// Source display-only fields: CATEGORY_TEXT key and the v1 `contentJson` task cards.
    public let category: String?
    public let contentJSON: String?
    /// MP official-detail js:482-483 / wxml:180-182: `safetyNotice{title,version}`. When a title is present, signup
    /// waits for an explicit 我已阅读并同意《title》 (never pre-checked). Absent = no consent step, as in the MP.
    public let safetyNoticeTitle: String?
    /// `e.leaderboard` when `enabled === true`. Nil hides the board.
    public let leaderboard: OfficialEventLeaderboard?
    public var isCompleteRecord: Bool { id > 0 && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var isV2: Bool { (contractVersion ?? 1) >= 2 }
    /// Exact official_event codes from the existing task-list source. This is a
    /// display classification only, never participation or operation authority.
    public var hasKnownListStatus: Bool { status.map { [0, 1, 2, 3, 4, 5, 6, 9].contains($0) } == true }
    public var hasEndedListStatus: Bool { status.map { [5, 6, 9].contains($0) } == true }
    public var completedMissionCount: Int { missions.filter { $0.complete == true }.count }
    public var recruitmentWarningReason: String? {
        guard recruitmentBlocked == true,
              let reason = recruitmentBlockedReason?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reason.isEmpty else { return nil }
        return reason
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        id = c.integer("id") ?? 0; title = c.text("title") ?? ""
        subtitle = c.text("subtitle"); coverImage = c.text("coverImg"); city = c.text("city")
        status = c.integer("status"); story = c.text("story"); rewardJSON = c.text("rewardJson")
        participants = c.integer("participants").flatMap { $0 >= 0 ? $0 : nil }
        myProgress = c.integer("myProgress").flatMap { $0 >= 0 ? $0 : nil }
        signed = c.flag("signed"); roamEnabled = c.flag("roamEnabled") == true
        paused = c.flag("paused") == true; pausedReason = c.text("pausedReason")
        fulfillmentPolicy = c.text("fulfillmentPolicy")
        recruitmentBlocked = c.flag("recruitmentBlocked")
        recruitmentBlockedReason = c.text("recruitmentBlockedReason")
        eligible = c.flag("eligible"); contractVersion = c.integer("contractVersion")
        activityStart = try? c.decode(OfficialEventTime.self, forKey: OfficialKey("activityStart"))
        activityEnd = try? c.decode(OfficialEventTime.self, forKey: OfficialKey("activityEnd"))
        bannerEnabled = c.flag("bannerEnabled") == true || c.integer("bannerEnabled") == 1 || c.text("bannerEnabled") == "1"
        let avatars: [String] = try c.list("participantAvatars")
        participantAvatars = avatars.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        missions = try c.list("missions")
        collective = try c.decodeIfPresent(OfficialCollectiveProgress.self, forKey: OfficialKey("collective"))
        category = c.text("category"); contentJSON = c.text("contentJson")
        let notice = try? c.decode(OfficialSafetyNotice.self, forKey: OfficialKey("safetyNotice"))
        safetyNoticeTitle = notice?.title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        leaderboard = (try? c.decode(OfficialEventLeaderboardBox.self, forKey: OfficialKey("leaderboard")))?.value
    }
    private struct OfficialSafetyNotice: Decodable { let title: String? }
    private var rewardMap: [String: Any] {
        guard let data = rewardJSON?.data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return value
    }
    /// Source reward contract (official-detail positiveInt): settleBadge must be exactly true;
    /// settleXp is a positive Java int and coupon IDs positive Java longs, as numbers or digit strings.
    public var rewards: [OfficialReward] {
        let map = rewardMap
        var result: [OfficialReward] = []
        if let badge = map["settleBadge"] as? NSNumber, CFGetTypeID(badge) == CFBooleanGetTypeID(), badge.boolValue { result.append(.badge) }
        if Self.positiveInteger(map["settleCouponId"], max: Self.longMax) != nil { result.append(.coupon) }
        if let xp = Self.positiveInteger(map["settleXp"], max: Self.intMax) { result.append(.experience(xp)) }
        if hasCollectiveReward { result.append(.collectiveCoupon) }
        return result
    }
    public var hasCollectiveReward: Bool { Self.positiveInteger(rewardMap["collectiveCouponId"], max: Self.longMax) != nil }
    static let intMax = "2147483647", longMax = "9223372036854775807"
    /// Normalized positive decimal text within the backend type's range, or nil.
    static func positiveInteger(_ value: Any?, max: String) -> String? {
        var text: String
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
                  number.doubleValue == number.doubleValue.rounded(.towardZero) else { return nil }
            text = number.stringValue
        } else if let string = value as? String {
            text = string.trimmingCharacters(in: .whitespaces)
        } else { return nil }
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        while text.count > 1 && text.hasPrefix("0") { text.removeFirst() }
        guard text != "0", text.count < max.count || (text.count == max.count && text <= max) else { return nil }
        return text
    }
    public var statusKey: String {
        guard let status else { return "official.status.unknown" }
        if hasEndedListStatus { return "official.status.ended" }
        switch status {
        case 1: return "official.status.upcoming"
        case 2: return "official.status.registration"
        case 3: return "official.status.live"
        case 4: return "official.status.settling"
        default: return "official.status.unknown"
        }
    }
    /// Read-only explanation of the source CTA state machine; never enables a write.
    public var participationKey: String {
        guard hasKnownListStatus else { return "official.participation.unavailable" }
        if hasEndedListStatus { return "official.status.ended" }
        if paused { return "official.status.paused" }
        if signed == true {
            if status == 3 && isV2 {
                if missions.contains(where: { $0.canVerifyArrival == true }) { return "official.participation.arrival" }
                if missions.contains(where: { $0.type == "THEME_VERIFIED_FINISH" }) { return "official.participation.themeSync" }
                return "official.participation.waitTasks"
            }
            if status == 3 { return roamEnabled ? "official.participation.roam" : "official.participation.explore" }
            return status == 1 ? "official.participation.signedWaiting" : "official.participation.signed"
        }
        if status == 2 || status == 3 { return "official.participation.registrationDeferred" }
        if status == 1 { return "official.participation.registrationSoon" }
        return "official.participation.unavailable"
    }
}

public enum OfficialEventBucket: String, CaseIterable, Identifiable {
    case live, upcoming, ended, mine
    public var id: String { rawValue }
    public var titleKey: String { "official.bucket." + rawValue }
    public func includes(_ value: OfficialEvent) -> Bool {
        switch self {
        // Keep unknown returned records inspectable, with their unknown label.
        // Inclusion in this overview is not a claim that the event is live.
        case .live: return value.status == 2 || value.status == 3 || !value.hasKnownListStatus
        case .upcoming: return value.status == 1
        case .ended: return value.hasEndedListStatus
        case .mine: return true
        }
    }
}
/// Source list copy (pages/activity/list): tab-specific summary and empty states.
public extension OfficialEventBucket {
    /// The source chip reads "我的"; the shared bucket title stays for other hosts.
    var tabTitleKey: String { self == .mine ? "official.tab.mine" : titleKey }
    var emptyTitleKey: String {
        switch self {
        case .live: return "official.empty.live"
        case .upcoming: return "official.empty.upcoming"
        case .ended: return "official.empty.ended"
        case .mine: return "official.empty.mine"
        }
    }
    var emptyDetailKey: String {
        switch self {
        case .live, .upcoming: return "official.emptyDetail.curated"
        case .ended: return "official.emptyDetail.ended"
        case .mine: return "official.emptyDetail.mine"
        }
    }
    /// The source hides search on its "mine" tab; a hidden keyword never filters it here.
    var isSearchable: Bool { self != .mine }
}

/// Rounded source countdown units: days from 24 h, hours from 1 h, otherwise at least one minute.
public enum OfficialCountdownSpan: Equatable {
    case days(Int), hours(Int), minutes(Int), unknown
    public init(milliseconds: Double) {
        // Finite JSON numbers can still exceed Int. Never trap or clamp them into
        // a believable duration; direct callers also receive an explicit unknown.
        guard milliseconds.isFinite, milliseconds >= 0,
              let hours = Int(exactly: (milliseconds / 3_600_000).rounded(.towardZero)) else {
            self = .unknown; return
        }
        if hours >= 24 { self = .days(hours / 24) }
        else if hours >= 1 { self = .hours(hours) }
        else { self = .minutes(max(1, Int(milliseconds / 60_000))) }
    }
}
public enum OfficialEventCountdown: Equatable {
    case startsIn(OfficialCountdownSpan), startingSoon, endsIn(OfficialCountdownSpan), endingSoon
}
public extension OfficialEvent {
    /// Mirrors the source card timer for numeric timestamps only. Timezone-less text
    /// dates are not reinterpreted, so they fall back to the status label alone.
    func countdown(now: Date) -> OfficialEventCountdown? {
        let current = now.timeIntervalSince1970 * 1000
        guard current.isFinite else { return nil }
        if status == 1, let start = activityStart?.displayMilliseconds {
            let remaining = start - current
            guard remaining > 0 else { return .startingSoon }
            let span = OfficialCountdownSpan(milliseconds: remaining)
            return span == .unknown ? nil : .startsIn(span)
        }
        if status == 2 || status == 3, let end = activityEnd?.displayMilliseconds {
            let remaining = end - current
            guard remaining > 0 else { return .endingSoon }
            let span = OfficialCountdownSpan(milliseconds: remaining)
            return span == .unknown ? nil : .endsIn(span)
        }
        return nil
    }
    /// Collective progress is shown only when the server enables it; nil percent stays unknown.
    var collectivePercentShown: Bool { collective?.enabled == true }
}

public enum OfficialEventFilter {
    public static func visible(_ rows: [OfficialEvent], bucket: OfficialEventBucket, keyword: String = "") -> [OfficialEvent] {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seen = Set<Int>()
        return rows.filter { row in
            row.isCompleteRecord && seen.insert(row.id).inserted && bucket.includes(row) &&
                (keyword.isEmpty || [row.title, row.subtitle ?? "", row.city ?? ""].contains { $0.lowercased().contains(keyword) })
        }
    }
}

/// A local presentation query shared by public and already-authorized "mine"
/// results. It never fetches private rows or changes a reader's request scope.
public struct OfficialEventBrowseQuery: Equatable {
    public let bucket: OfficialEventBucket
    public let keyword: String
    public init(bucket: OfficialEventBucket, keyword: String) { self.bucket = bucket; self.keyword = keyword }
    public var isPrivate: Bool { bucket == .mine }
    public var emptyKey: String {
        if !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "official.searchEmpty" }
        return isPrivate ? "official.emptyMine" : "official.empty"
    }
    /// Source (pages/activity/list) tab-specific empty title.
    public var emptyTitleKey: String { isSearching ? "official.empty.search" : bucket.emptyTitleKey }
    public var emptyDetailKey: String { isSearching ? "official.searchEmptyDetail" : bucket.emptyDetailKey }
    public var trimmedKeyword: String { keyword.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var isSearching: Bool { !trimmedKeyword.isEmpty }
    /// The source list page hides search on "mine", so its hidden keyword never applies there.
    public static func sourceList(bucket: OfficialEventBucket, keyword: String) -> Self {
        .init(bucket: bucket, keyword: bucket.isSearchable ? keyword : "")
    }
    public func visible(_ rows: [OfficialEvent]) -> [OfficialEvent] {
        OfficialEventFilter.visible(rows, bucket: bucket, keyword: keyword)
    }
}

/// pages/activity/list/index projection of the existing list and can-publish reads.
/// It does not fetch, add a route, or mark a route live. A nil publish capability stays hidden.
public enum OfficialActivityListPhase: Equatable {
    case loading, empty, error, unknown, ready
}

/// One visible list row. A missing count is an em dash. A literal zero stays "0".
public struct OfficialActivityListCard: Equatable {
    public let id: Int
    public let statusKey: String
    public let participantsText: String
    /// Nil when the server did not enable collective progress. "—" when enabled and percent is absent.
    public let collectivePercentText: String?
    public init(_ event: OfficialEvent) {
        id = event.id
        statusKey = event.statusKey
        participantsText = event.participants.map { String($0) } ?? OfficialActivityListPage.unknownMark
        if event.collectivePercentShown {
            collectivePercentText = event.collective?.percent.map { String($0) } ?? OfficialActivityListPage.unknownMark
        } else {
            collectivePercentText = nil
        }
    }
}

public struct OfficialActivityListPage: Equatable {
    /// Missing numeric facts. Never a stand-in zero.
    public static let unknownMark = "—"
    public let phase: OfficialActivityListPhase
    public let query: OfficialEventBrowseQuery
    public let visible: [OfficialEvent]
    public let cards: [OfficialActivityListCard]
    /// Nil while loading, failed, or unclassified. Zero only for a known empty list.
    public let summaryCount: Int?
    /// True only when the existing can-publish read returned true.
    public let showsPublishedLink: Bool
    public var summaryCountText: String {
        guard let summaryCount else { return Self.unknownMark }
        return String(summaryCount)
    }

    fileprivate init(phase: OfficialActivityListPhase, query: OfficialEventBrowseQuery, visible: [OfficialEvent],
                     cards: [OfficialActivityListCard], summaryCount: Int?, showsPublishedLink: Bool) {
        self.phase = phase
        self.query = query
        self.visible = visible
        self.cards = cards
        self.summaryCount = summaryCount
        self.showsPublishedLink = showsPublishedLink
    }
}

public enum OfficialActivityListCoordinator {
    /// `list == nil` is still loading. Cancellation stays loading. A malformed payload is
    /// unknown, not an empty list. Any other failure is an error. Counts stay an em dash
    /// until a real list arrives.
    public static func project(query: OfficialEventBrowseQuery, list: Result<[OfficialEvent], Error>?, canPublish: Bool?) -> OfficialActivityListPage {
        let showsPublishedLink = canPublish == true
        guard let list else { return unsettled(.loading, query: query, showsPublishedLink: showsPublishedLink) }
        switch list {
        case .failure(let error):
            if error is CancellationError { return unsettled(.loading, query: query, showsPublishedLink: showsPublishedLink) }
            if case APIError.malformedResponse = error { return unsettled(.unknown, query: query, showsPublishedLink: showsPublishedLink) }
            return unsettled(.error, query: query, showsPublishedLink: showsPublishedLink)
        case .success(let rows):
            let visible = query.visible(rows)
            let cards = visible.map { OfficialActivityListCard($0) }
            return OfficialActivityListPage(phase: visible.isEmpty ? .empty : .ready, query: query, visible: visible,
                                            cards: cards, summaryCount: visible.count, showsPublishedLink: showsPublishedLink)
        }
    }

    private static func unsettled(_ phase: OfficialActivityListPhase, query: OfficialEventBrowseQuery, showsPublishedLink: Bool) -> OfficialActivityListPage {
        OfficialActivityListPage(phase: phase, query: query, visible: [], cards: [], summaryCount: nil, showsPublishedLink: showsPublishedLink)
    }
}

public struct OfficialPartyInvite: Decodable, Equatable, Identifiable {
    public let id: Int
    public let title: String
    public let partyType: String?
    public let eventTitle: String?
    public let status: String?
    public let city: String?
    /// Source official-inbox display fields: role, responsibility scope and summary.
    public let role: String?
    public let targetType: String?
    public let responsibilitySummary: String?
    public let capacity: Int?
    /// JSON integers stay, including 0. Missing, null, numeric strings, and UNKNOWN are an em dash.
    public let capacityFact: OfficialInboxQuantity
    public let controlState: String?
    /// Source service window (windowStart/windowEnd); absent fields read as unbounded.
    public let windowFacts: OfficialInboxWindowFacts?
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        role = c.text("role"); targetType = c.text("targetType"); responsibilitySummary = c.text("responsibilitySummary")
        capacity = c.integer("capacity").flatMap { $0 > 0 ? $0 : nil }
        capacityFact = (try? c.decode(OfficialInboxQuantity.self, forKey: OfficialKey("capacity"))) ?? .unknown
        controlState = c.text("controlState")
        windowFacts = try? OfficialInboxWindowFacts(from: decoder)
        id = c.integer("partyId") ?? c.integer("id") ?? 0
        title = c.text("title") ?? c.text("partyName") ?? c.text("responsibilitySummary") ?? ""
        partyType = c.text("partyType"); eventTitle = c.text("eventTitle")
        status = c.text("status"); city = c.text("city") // Never read `state`.
    }
    public var isPaused: Bool { controlState == "PAUSED" }
    public var roleNoteTuple: (zh: String, en: String)? {
        switch role {
        case "ORGANIZER":
            return ("对整场活动负责，发布、暂停和恢复由主办操作。", "Responsible for the entire event; publishing, pausing, and resuming are managed by the organizer.")
        case "CO_ORGANIZER":
            return ("与主办方共同承办本场活动，按下方职责范围履约。", "Co-hosts this event with the organizer and fulfills within the scope below.")
        case "FULFILLMENT_MERCHANT":
            return ("以商家身份在指定范围和时段内提供履约服务。", "Provides fulfillment service as a merchant within the designated scope and window.")
        case "FULFILLMENT_CLUB":
            return ("以俱乐部身份在指定范围和时段内组织或协助履约。", "Organizes or assists fulfillment as a club within the designated scope and window.")
        case "SPONSOR":
            return ("作为支持方为本场活动提供支持。", "Supports this event as a sponsor.")
        case "PROMOTION_PARTNER":
            return ("作为推广伙伴协助本场活动的传播。", "Assists in promoting this event as a promotion partner.")
        default:
            return nil
        }
    }
    public var statusKey: String {
        switch status {
        case "INVITED": return "official.invite.invited"
        case "ACCEPTED": return "official.invite.accepted"
        case "ACTIVE": return "official.invite.active"
        default: return "official.status.unknown"
        }
    }
    /// Source STATUS table (待你确认 / 已接受 / 履约中); unknown codes stay explicit.
    public var sourceStatusKey: String {
        switch status {
        case "INVITED": return "official.inbox.status.invited"
        case "ACCEPTED": return "official.inbox.status.accepted"
        case "ACTIVE": return "official.inbox.status.active"
        default: return "official.inbox.status.unknown"
        }
    }
    /// Source ROLE table; nil when the server role is unknown (its raw code is shown verbatim).
    public var roleKey: String? {
        switch role {
        case "ORGANIZER": return "official.inbox.role.organizer"
        case "CO_ORGANIZER": return "official.inbox.role.coOrganizer"
        case "FULFILLMENT_MERCHANT": return "official.inbox.role.merchant"
        case "FULFILLMENT_CLUB": return "official.inbox.role.club"
        case "SPONSOR": return "official.inbox.role.sponsor"
        case "PROMOTION_PARTNER": return "official.inbox.role.promotion"
        default: return nil
        }
    }
    /// EVENT (or absent) is the whole event; internal target IDs are never displayed.
    public var scopeKey: String {
        switch targetType {
        case "NODE": return "official.inbox.scope.node"
        case "ROUTE": return "official.inbox.scope.route"
        case "CHAPTER": return "official.inbox.scope.chapter"
        case nil, "EVENT": return "official.inbox.scope.event"
        default: return "official.inbox.scope.unknown"
        }
    }
}
public struct OfficialBroadcast: Decodable, Equatable, Identifiable {
    public let id: Int
    public let title: String
    public let content: String?
    public let reach: Int?
    /// Source official-mine row facts (copyMode, audience, status, city).
    public let facts: OfficialPublishedBroadcastFacts?
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        facts = try? OfficialPublishedBroadcastFacts(from: decoder)
        id = c.integer("id") ?? 0; title = c.text("title") ?? ""
        content = c.text("content")
        // Source official-mine reads the domain field `reachedCount`; `reach` stays a fallback.
        reach = (c.integer("reachedCount") ?? c.integer("reach")).flatMap { $0 >= 0 ? $0 : nil }
    }
}
public struct OfficialPublished: Decodable, Equatable {
    public let events: [OfficialEvent]
    public let broadcasts: [OfficialBroadcast]
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        events = try c.list("events"); broadcasts = try c.list("broadcasts")
    }
    public var isEmpty: Bool { events.isEmpty && broadcasts.isEmpty }
}
public enum OfficialStatisticValue: Decodable, Equatable {
    case text(String), number(Decimal), flag(Bool), unsupported
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(Bool.self) { self = .flag(value) }
        else if let value = try? c.decode(Decimal.self) { self = .number(value) }
        else if let value = try? c.decode(String.self) { self = .text(value) }
        else { self = .unsupported }
    }
}
public struct OfficialStatistic: Equatable, Identifiable {
    public let id: String
    public let value: OfficialStatisticValue
}
public struct OfficialBroadcastDeliveryCounts: Decodable, Equatable, Sendable {
    public let inappStored: Int
    public let channelAccepted: Int
    public let rejected: Int
    public let notSubmitted: Int
    public let retryable: Int
    public let unknown: Int
    public let legacyUnconfirmed: Int
    public let capped: Int
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        func n(_ key: String) -> Int {
            if let value = c.integer(key) { return value }
            if let value = try? c.decode(Double.self, forKey: OfficialKey(key)), value.isFinite { return Int(value) }
            return 0
        }
        inappStored = n("INAPP_STORED")
        channelAccepted = n("CHANNEL_ACCEPTED")
        rejected = n("REJECTED")
        notSubmitted = n("NOT_SUBMITTED")
        retryable = n("RETRYABLE")
        unknown = n("UNKNOWN")
        legacyUnconfirmed = n("LEGACY_UNCONFIRMED")
        capped = n("CAPPED")
    }
    /// Mini-program `broadcastStatsText` when `deliveryCounts` is a record.
    public var line: String {
        "站内已入库 \(inappStored) · 订阅渠道受理 \(channelAccepted) · 明确拒绝 \(rejected) · 未提交 \(notSubmitted) · 可恢复 \(retryable) · 结果不明 \(unknown) · 历史待核 \(legacyUnconfirmed) · 频控未发 \(capped)；不代表已读"
    }
    /// Same counts for an English reader. `line` stays the Chinese source sentence.
    public func presentedLine(locale: Locale) -> String {
        guard !OfficialReadCopy.isChinese(locale) else { return line }
        return "Stored in-app \(inappStored) · Channel accepted \(channelAccepted) · Rejected \(rejected) · Not submitted \(notSubmitted) · Recoverable \(retryable) · Unknown \(unknown) · Legacy unconfirmed \(legacyUnconfirmed) · Frequency-capped \(capped); not a read receipt"
    }
}

struct OfficialEventLeaderboardBox: Decodable {
    let value: OfficialEventLeaderboard?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: OfficialKey.self)
        guard c.flag("enabled") == true else { value = nil; return }
        let raw = (try? c.decode([Row].self, forKey: OfficialKey("rows"))) ?? []
        let rows: [OfficialEventLeaderboardRow] = raw.enumerated().compactMap { index, row in
            guard let rank = row.rank, rank > 0 else { return nil }
            let name = row.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = (name?.isEmpty == false) ? name! : "城瘾玩家"
            var score = "\(row.done) / \(row.total)"
            if let elapsed = row.elapsedSeconds {
                score += " · " + Self.clock(elapsed)
            }
            return OfficialEventLeaderboardRow(id: String(index), rank: rank, displayName: display, scoreText: score, isSelf: false)
        }
        let my = c.integer("myRank")
        let final = c.flag("final") == true
        let chip: String
        if let my, my > 0 { chip = final ? "第 \(my) 名" : "暂列第 \(my) 名" }
        else { chip = "" }
        value = OfficialEventLeaderboard(rows: rows, chipText: chip, myRank: (my ?? 0) > 0 ? my : nil, isFinal: final)
    }
    private struct Row: Decodable {
        let rank: Int?
        let name: String?
        let done: Int
        let total: Int
        let elapsedSeconds: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: OfficialKey.self)
            rank = c.integer("rank")
            name = c.text("name")
            done = c.integer("doneCount") ?? 0
            total = c.integer("totalCount") ?? 0
            if let whole = c.integer("elapsedSeconds") { elapsedSeconds = Double(whole) }
            else if let value = try? c.decode(Double.self, forKey: OfficialKey("elapsedSeconds")), value.isFinite { elapsedSeconds = value }
            else { elapsedSeconds = nil }
        }
    }
    private static func clock(_ seconds: Double) -> String {
        let n = max(0, Int(seconds.rounded(.down)))
        func p2(_ value: Int) -> String { value < 10 ? "0\(value)" : String(value) }
        return "\(n / 3600):\(p2((n / 60) % 60)):\(p2(n % 60))"
    }
}

public struct OfficialEventLeaderboard: Equatable, Sendable {
    public let rows: [OfficialEventLeaderboardRow]
    public let chipText: String
    public let myRank: Int?
    public let isFinal: Bool
    public init(rows: [OfficialEventLeaderboardRow], chipText: String, myRank: Int?, isFinal: Bool) {
        self.rows = rows
        self.chipText = chipText
        self.myRank = myRank
        self.isFinal = isFinal
    }
    /// Enabled board with neither rows nor a rank. The page still reads the empty state.
    public var isEmptyBoard: Bool {
        rows.isEmpty && (myRank ?? 0) <= 0 && chipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// Chinese payload name stays in `rows`. English readers see the fallback name in English.
    public func presentedRows(locale: Locale) -> [OfficialEventLeaderboardRow] {
        guard !OfficialReadCopy.isChinese(locale) else { return rows }
        return rows.map { row in
            guard row.displayName == Self.unnamedPlayer else { return row }
            return OfficialEventLeaderboardRow(id: row.id, rank: row.rank, displayName: "Chengyin player", scoreText: row.scoreText, isSelf: row.isSelf)
        }
    }
    /// Chinese `chipText` stays the source string. English readers get the same rank.
    public func presentedChip(locale: Locale) -> String {
        guard !OfficialReadCopy.isChinese(locale), let myRank, myRank > 0 else { return chipText }
        return isFinal ? "Rank \(myRank)" : "Provisional rank \(myRank)"
    }
    private static let unnamedPlayer = "城瘾玩家"
}

public struct OfficialBroadcastStats: Decodable, Equatable {
    public let rows: [OfficialStatistic]
    public let canRecoverInapp: Bool
    public let deliveryCounts: OfficialBroadcastDeliveryCounts?
    public init(from decoder: Decoder) throws {
        let values = try [String: OfficialStatisticValue](from: decoder)
        rows = values.keys.sorted().compactMap { key in
            guard let value = values[key], value != .unsupported else { return nil }
            return OfficialStatistic(id: key, value: value)
        }
        if case .flag(let value) = values["canRecoverInapp"] { canRecoverInapp = value }
        else { canRecoverInapp = false }
        let c = try decoder.container(keyedBy: OfficialKey.self)
        deliveryCounts = try c.decodeIfPresent(OfficialBroadcastDeliveryCounts.self, forKey: OfficialKey("deliveryCounts"))
    }
    /// Prefers the delivery-count sentence. Otherwise the reach/click sentence when both counts exist.
    public var summaryLine: String? {
        if let deliveryCounts { return deliveryCounts.line }
        func number(_ key: String) -> Int? {
            guard let row = rows.first(where: { $0.id == key }) else { return nil }
            if case .number(let value) = row.value { return NSDecimalNumber(decimal: value).intValue }
            return nil
        }
        guard let reached = number("reached") ?? number("reach"), let clicked = number("clicked") ?? number("clicks") else { return nil }
        return "站内触达 \(reached) 人 · 点击 \(clicked) 人"
    }
    /// Locale-facing summary. Chinese keeps `summaryLine`. This does not send a recover write.
    public func presentedSummaryLine(locale: Locale) -> String? {
        guard !OfficialReadCopy.isChinese(locale) else { return summaryLine }
        if let deliveryCounts { return deliveryCounts.presentedLine(locale: locale) }
        func number(_ key: String) -> Int? {
            guard let row = rows.first(where: { $0.id == key }) else { return nil }
            if case .number(let value) = row.value { return NSDecimalNumber(decimal: value).intValue }
            return nil
        }
        guard let reached = number("reached") ?? number("reach"), let clicked = number("clicked") ?? number("clicks") else { return nil }
        return "Reached \(reached) in app · \(clicked) clicked"
    }
    /// Server message, then the mini-program retry suffix. Empty message uses `fallback`.
    public static func failureLine(serverMessage: String?, fallback: String = "复盘没读到") -> String {
        let trimmed = serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (trimmed.isEmpty ? fallback : trimmed) + "，点一下重试"
    }
    /// Same retry fact in the reader's language. The server note stays verbatim.
    public static func failureLine(serverMessage: String?, locale: Locale) -> String {
        if OfficialReadCopy.isChinese(locale) { return failureLine(serverMessage: serverMessage) }
        let trimmed = serverMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return "Couldn't read the recap. Tap to try again." }
        return "\(trimmed). Tap to try again."
    }
    /// `msg` carried by a broadcast stats or recover failure. Other errors stay nil.
    public static func serverNote(_ error: Error) -> String? {
        guard case .explained(_, let text) = error as? OfficialReadFailure else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Official-event read copy: Chinese source sentence plus an English counterpart.
public enum OfficialReadCopy {
    public static func isChinese(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "zh"
    }
    public static func text(_ zh: String, _ en: String, locale: Locale) -> String {
        isChinese(locale) ? zh : en
    }
    /// Read of `canRecoverInapp`. Not a recover button and not a POST.
    public static func recoverableDelivery(locale: Locale) -> String {
        text("站内投递标记为可恢复", "In-app delivery is marked recoverable", locale: locale)
    }
    public static func safetyNoticeHeading(locale: Locale) -> String {
        text("安全须知", "Safety notice", locale: locale)
    }
    public static func emptyLeaderboard(locale: Locale) -> String {
        text("暂无成绩", "No scores yet", locale: locale)
    }
}
