import Foundation

/// Priority-signup badge and topic count presentation for `cy-club-card` in `pages/talent/list`.
public struct ClubPriorityMemberBadge: Equatable, Sendable {
    public let prioritySignup: Bool
    public let topicCount: Int?

    public init(prioritySignup: Bool, topicCount: Int? = nil) {
        self.prioritySignup = prioritySignup
        self.topicCount = topicCount
    }

    public var badgeText: String? {
        prioritySignup ? "成员优先报名" : nil
    }

    public var topicCountText: String? {
        guard let count = topicCount, count > 0 else { return nil }
        return "\(count) 个主题"
    }
}

/// Strict response shape validator for `/api/club/home` matching the mini-program contract.
public enum ClubHomeStrictShapeCheck: Sendable {
    public static let requiredKeys: [String] = ["owned", "joined", "nearby", "leaderStatus"]

    public static func validate(jsonObject: [String: Any]) -> Bool {
        requiredKeys.allSatisfy { key in
            guard let value = jsonObject[key] else { return false }
            return !(value is NSNull)
        }
    }
}

/// Mini-program `pages/talent/list` (俱乐部 tab) facts over the existing `/api/club/home` read.
/// Presentation only. The source marks every `owned` row as owner and every `joined` row as
/// joined before drawing `cy-club-card`; rows themselves may omit those flags.
public enum ClubTabPresentation {
    public enum Section: Equatable, Sendable { case owned, joined, nearby }
    /// Source `topTabs`: 帖文 then 俱乐部, with 俱乐部 active on open.
    public enum TopTab: String, CaseIterable, Sendable {
        case feed, club
        public var key: String { self == .feed ? "club.tab.top.feed" : "club.tab.top.club" }
    }

    /// L1–L5 organiser level copy inherited by the club (level 0 shows nothing; others `Lv.N`).
    public static func levelKey(_ level: Int) -> (key: String?, fallback: String?) {
        switch level {
        case 1...5: return ("club.tab.level.\(level)", nil)
        case let value where value > 5: return (nil, "Lv.\(value)")
        default: return (nil, nil)
        }
    }

    public static func isOwner(_ club: ClubRecord, in section: Section) -> Bool { section == .owned || club.isOwner }
    public static func isJoined(_ club: ClubRecord, in section: Section) -> Bool { section == .joined || club.isJoined }

    /// Player-audience card tags: club types, keywords, then 免费加入 for a club the viewer is not in.
    /// Split exactly as the source `splitList`: a JSON string array, or `, ; 、 ， ；` separated text.
    public static func tags(_ club: ClubRecord, in section: Section) -> (labels: [String], freeToJoin: Bool) {
        var seen = Set<String>(), labels: [String] = []
        for value in splitList(club.clubType) + splitList(club.keywords) where seen.insert(value).inserted { labels.append(value) }
        return (labels, !isOwner(club, in: section) && !isJoined(club, in: section))
    }

    static func splitList(_ raw: String?) -> [String] {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return [] }
        if text.hasPrefix("[") {
            guard let data = text.data(using: .utf8), let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
            return array.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        let separators = CharacterSet(charactersIn: ",;、，；")
        return text.components(separatedBy: separators).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// The source shows one list: owned → joined → nearby (merchants see only nearby).
    public static func isEmpty(_ home: ClubHome, nearby: [ClubRecord], merchant: Bool) -> Bool {
        merchant ? nearby.isEmpty : home.owned.isEmpty && home.joined.isEmpty && nearby.isEmpty
    }

    /// 还没有俱乐部 (with the 创建俱乐部 CTA) for players; 本城还没有俱乐部 for merchants.
    public static func emptyKeys(merchant: Bool) -> (title: String, detail: String, offersCreate: Bool) {
        merchant ? ("club.tab.empty.merchant", "club.tab.empty.merchant.detail", false)
                 : ("club.tab.empty", "club.tab.empty.detail", true)
    }

    /// Feed empty copy differs when the viewer has no club at all (`clubCount == 0`).
    public static func feedEmptyKeys(clubCount: Int?) -> (title: String, detail: String) {
        clubCount == 0 ? ("club.tab.feed.noClub", "club.tab.feed.noClub.detail") : ("club.tab.feed.empty", "club.tab.feed.empty.detail")
    }
}

/// Page facts for `pages/talent/list/index` over the existing `POST /api/club/home` data object.
/// `leaderStatus` is read only when the server sends `{isClubLeader, ownedCount, maxOwned, canCreate}`.
/// A missing capability stays hidden. This type does not perform I/O and does not register a route.
public struct ClubTabPageModel: Equatable, Sendable {
    public static let unknownMark = "\u{2014}"
    public static let loadingIdentifier = "club.home.loading"
    public static let emptyIdentifier = "clubTab.empty"
    public static let errorIdentifier = "club.home.error"
    public static let unknownIdentifier = "club.home.unknown"
    public static let readyIdentifier = "club.home.ready"

    public enum Phase: Equatable, Sendable {
        case loading
        case empty
        case error
        case unknown
        case ready
    }

    /// A server integer, including 0. Missing, null, fractional, boolean, and text stay unknown.
    public struct Count: Equatable, Sendable {
        public let literal: Int?
        public var text: String { literal.map(String.init) ?? ClubTabPageModel.unknownMark }
        public static let unknown = Count(literal: nil)
        public init(literal: Int?) { self.literal = literal }
    }

    public struct Row: Equatable, Sendable {
        public let id: Int
        public let section: ClubTabPresentation.Section
        public let memberCount: Count
        public let topicCount: Count
    }

    public struct EventFact: Equatable, Sendable {
        public let id: Int
        public let signupCount: Count
    }

    public struct LeaderStatus: Equatable, Sendable {
        /// Explicit JSON `true` only. Anything else stays unknown.
        public let isClubLeader: Bool?
        public let ownedCount: Count
        public let maxOwned: Count
        /// Explicit JSON `true` only. `1`, `"UNKNOWN"`, null, and a missing field stay hidden.
        public let canCreate: Bool
        public static let hidden = LeaderStatus(isClubLeader: nil, ownedCount: .unknown, maxOwned: .unknown, canCreate: false)
    }

    public let phase: Phase
    public let accessibilityIdentifier: String
    public let titleKey: String?
    public let detailKey: String?
    public let leader: LeaderStatus
    public let rows: [Row]
    public let events: [EventFact]
    public let eventCount: Count
    public let showsCreateClub: Bool
    public let unreadBadgeText: String?
    public let feedPhase: Phase
    public let feedTitleKey: String?
    public let feedDetailKey: String?
    public let feedClubCount: Count
    public var showsMerchantChoice: Bool { false }
    public var paymentEnabled: Bool { false }
    public var payoutEnabled: Bool { false }
    public var withdrawalEnabled: Bool { false }
    public var virtualGoodsEnabled: Bool { false }

    /// `homeData` is the `data` object of `/api/club/home`. Nil means the read was withheld.
    /// `unreadData` is the raw `data` of the existing `/api/im/unread-total` read; the granted
    /// flag stays false unless that read is already allowed. Feed facts use the existing
    /// community `clubCount` and do not open a feed route.
    public static func project(homeData: [String: Any]?, inFlight: Bool = false, failed: Bool = false,
                               merchant: Bool = false, unreadGranted: Bool = false, unreadData: Any? = nil,
                               feedClubCount: Int? = nil, feedInFlight: Bool = false, feedFailed: Bool = false,
                               feedHasPosts: Bool? = nil) -> ClubTabPageModel {
        let feed = feedFacts(clubCount: feedClubCount, inFlight: feedInFlight, failed: feedFailed, hasPosts: feedHasPosts)
        let badge = unreadBadge(granted: unreadGranted, data: unreadData)
        if inFlight && homeData == nil {
            return make(phase: .loading, merchant: merchant, unread: badge, feed: feed)
        }
        if failed || homeData == nil {
            return make(phase: failed ? .error : .unknown, merchant: merchant, unread: badge, feed: feed)
        }
        guard let homeData else {
            return make(phase: .unknown, merchant: merchant, unread: badge, feed: feed)
        }
        guard let owned = sectionRows(homeData["owned"], section: .owned),
              let joined = sectionRows(homeData["joined"], section: .joined),
              let nearby = sectionRows(homeData["nearby"], section: .nearby) else {
            return make(phase: .error, merchant: merchant, unread: badge, feed: feed)
        }
        let leader = leaderStatus(homeData["leaderStatus"])
        let eventResult: (facts: [EventFact], count: Count)
        if homeData.keys.contains("events") {
            guard let list = homeData["events"] as? [Any] else {
                return make(phase: .error, merchant: merchant, unread: badge, feed: feed)
            }
            var facts: [EventFact] = []
            facts.reserveCapacity(list.count)
            for item in list {
                guard let fact = eventFact(item) else {
                    return make(phase: .error, merchant: merchant, unread: badge, feed: feed)
                }
                facts.append(fact)
            }
            eventResult = (facts, Count(literal: facts.count))
        } else {
            eventResult = ([], .unknown)
        }
        let visible = merchant ? nearby : owned + joined + nearby
        let empty = merchant ? nearby.isEmpty : owned.isEmpty && joined.isEmpty && nearby.isEmpty
        return make(phase: empty ? .empty : .ready, leader: leader, rows: visible, events: eventResult.facts,
                    eventCount: eventResult.count, merchant: merchant, unread: badge, feed: feed)
    }

    /// Hidden unless the unread-total read is already granted. A known zero draws no badge.
    /// Null, text, booleans, and fractions are an em dash, never 0.
    public static func unreadBadge(granted: Bool, data: Any?) -> String? {
        guard granted else { return nil }
        guard let count = exactCount(data) else { return unknownMark }
        return count > 0 ? String(count) : nil
    }

    private struct FeedFacts: Equatable {
        let phase: Phase
        let titleKey: String?
        let detailKey: String?
        let clubCount: Count
    }

    private static func feedFacts(clubCount: Int?, inFlight: Bool, failed: Bool, hasPosts: Bool?) -> FeedFacts {
        let count: Count = {
            guard let clubCount, clubCount >= 0 else { return .unknown }
            return Count(literal: clubCount)
        }()
        if inFlight && hasPosts == nil {
            return FeedFacts(phase: .loading, titleKey: "club.loading", detailKey: nil, clubCount: count)
        }
        if failed && hasPosts == nil {
            return FeedFacts(phase: .error, titleKey: "club.loadFailed", detailKey: "club.retryHint", clubCount: count)
        }
        guard let hasPosts else {
            return FeedFacts(phase: .unknown, titleKey: "club.tab.unknown", detailKey: nil, clubCount: count)
        }
        if hasPosts {
            return FeedFacts(phase: .ready, titleKey: nil, detailKey: nil, clubCount: count)
        }
        guard let literal = count.literal else {
            return FeedFacts(phase: .unknown, titleKey: "club.tab.unknown", detailKey: nil, clubCount: count)
        }
        let keys = ClubTabPresentation.feedEmptyKeys(clubCount: literal)
        return FeedFacts(phase: .empty, titleKey: keys.title, detailKey: keys.detail, clubCount: count)
    }

    private static func make(phase: Phase, leader: LeaderStatus = .hidden, rows: [Row] = [], events: [EventFact] = [],
                             eventCount: Count = .unknown, merchant: Bool, unread: String?, feed: FeedFacts) -> ClubTabPageModel {
        let title: String?
        let detail: String?
        let identifier: String
        switch phase {
        case .loading:
            title = "club.loading"; detail = nil; identifier = loadingIdentifier
        case .empty:
            let keys = ClubTabPresentation.emptyKeys(merchant: merchant)
            title = keys.title; detail = keys.detail; identifier = emptyIdentifier
        case .error:
            title = "club.loadFailed"; detail = "club.retryHint"; identifier = errorIdentifier
        case .unknown:
            title = "club.tab.unknown"; detail = nil; identifier = unknownIdentifier
        case .ready:
            title = nil; detail = nil; identifier = readyIdentifier
        }
        let showsCreateClub = (phase == .ready || phase == .empty) && !merchant && leader.canCreate
        return ClubTabPageModel(phase: phase, accessibilityIdentifier: identifier, titleKey: title, detailKey: detail,
                                leader: leader, rows: rows, events: events, eventCount: eventCount,
                                showsCreateClub: showsCreateClub, unreadBadgeText: unread, feedPhase: feed.phase,
                                feedTitleKey: feed.titleKey, feedDetailKey: feed.detailKey, feedClubCount: feed.clubCount)
    }

    private static func leaderStatus(_ value: Any?) -> LeaderStatus {
        guard let object = value as? [String: Any] else { return .hidden }
        return LeaderStatus(isClubLeader: jsonBool(object["isClubLeader"]),
                            ownedCount: Count(literal: exactCount(object["ownedCount"])),
                            maxOwned: Count(literal: exactCount(object["maxOwned"])),
                            canCreate: jsonBool(object["canCreate"]) == true)
    }

    private static func sectionRows(_ value: Any?, section: ClubTabPresentation.Section) -> [Row]? {
        guard let list = value as? [Any] else { return nil }
        var rows: [Row] = []
        rows.reserveCapacity(list.count)
        for item in list {
            guard let row = row(item, section: section) else { return nil }
            rows.append(row)
        }
        return rows
    }

    private static func row(_ item: Any, section: ClubTabPresentation.Section) -> Row? {
        guard var object = item as? [String: Any], let id = exactCount(object["id"]), id > 0 else { return nil }
        let members = exactCount(object["memberCount"])
        if object.keys.contains("memberCount"), members == nil { object.removeValue(forKey: "memberCount") }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              (try? JSONDecoder().decode(ClubRecord.self, from: data)) != nil else { return nil }
        return Row(id: id, section: section, memberCount: Count(literal: members), topicCount: Count(literal: exactCount(object["topicCount"])))
    }

    private static func eventFact(_ item: Any) -> EventFact? {
        guard let object = item as? [String: Any], let id = exactCount(object["id"]), id > 0,
              let clubId = exactCount(object["clubId"]), clubId > 0 else { return nil }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              (try? JSONDecoder().decode(ClubHomeEvent.self, from: data)) != nil else { return nil }
        return EventFact(id: id, signupCount: Count(literal: exactCount(object["signupCount"])))
    }

    private static func jsonBool(_ value: Any?) -> Bool? {
        if value is NSNull { return nil }
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
            return number.boolValue
        }
        return value as? Bool
    }

    /// Exact non-negative integers only. Booleans and fractional numbers are not counts.
    private static func exactCount(_ value: Any?) -> Int? {
        if value is NSNull { return nil }
        if let number = value as? Int { return number >= 0 ? number : nil }
        if let number = value as? Int64 {
            guard number >= 0, number <= Int64(Int.max) else { return nil }
            return Int(number)
        }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        switch CFNumberGetType(number) {
        case .sInt8Type, .sInt16Type, .sInt32Type, .sInt64Type, .charType, .shortType, .intType,
             .longType, .longLongType, .cfIndexType, .nsIntegerType:
            let parsed = number.int64Value
            guard parsed >= 0, parsed <= Int64(Int.max) else { return nil }
            return Int(parsed)
        default:
            let double = number.doubleValue
            guard double.isFinite, double >= 0, double <= Double(Int.max) else { return nil }
            let whole = Int(double)
            guard Double(whole) == double else { return nil }
            return whole
        }
    }
}

#if DEBUG
/// Synthetic `/api/club/home` data objects for the club tab. No transport, token, or route.
public enum ClubTabPageFixtureData {
    public static let ready = #"{"owned":[{"id":81,"name":"Synthetic owned","memberCount":3,"topicCount":2,"isOwner":true}],"joined":[],"nearby":[{"id":82,"name":"Synthetic nearby"}],"events":[{"id":91,"clubId":81,"title":"Synthetic outing","signupCount":4}],"leaderStatus":{"isClubLeader":true,"ownedCount":1,"maxOwned":2,"canCreate":true}}"#
    public static let empty = #"{"owned":[],"joined":[],"nearby":[],"events":[],"leaderStatus":{"isClubLeader":false,"ownedCount":0,"maxOwned":2,"canCreate":false}}"#
    public static let unknownCounts = #"{"owned":[{"id":81,"name":"Synthetic"}],"joined":[],"nearby":[],"events":[{"id":91,"clubId":81,"title":"Synthetic"}],"leaderStatus":{"isClubLeader":"UNKNOWN"}}"#
    public static let malformed = #"{"owned":[],"joined":[]}"#

    public static func object(_ json: String) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
        guard let object = value as? [String: Any] else { throw ClubTabPageFixtureError.notObject }
        return object
    }
}

public enum ClubTabPageFixtureError: Error { case notObject }
#endif
