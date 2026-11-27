import Foundation

/// Components r1 (C2): display-only values for the Home Screen, Lock Screen and StandBy widgets. Like
/// `QuestNextStopSnapshot`, nothing here is an account, token, coordinate or server secret: titles, counts,
/// a start time and day stamps. Each section is written by the app where it already has the value and stored
/// under its own App Group key (`QuestWidgetStore`), so two writers never overwrite each other's section.
/// This file is compiled into the app and the widget extension (`tools/generate_project.py`).
public enum QuestWidgetBoard {
    /// Widget kinds, also the `WidgetCenter.reloadTimelines(ofKind:)` keys.
    public static let eventKind = "QuestEventCountdownWidget"
    public static let roamStreakKind = "QuestRoamStreakWidget"
    public static let cityProgressKind = "QuestCityProgressWidget"
    public static let communityKind = "QuestCommunityWidget"

    /// The next activity ticket in the player's wallet (the Home 今日 card's `HomeTodayCandidate.nextTicket`).
    public struct Event: Codable, Hashable, Sendable {
        public var title: String
        public var startsAt: Date
        public var place: String?
        /// Wallet ticket id for the ticket pass link (`chein://ticket/<id>`, where the check-in code is shown);
        /// nil opens the activity list (MP `pages/activity/list`).
        public var ticketID: Int?
        public init(title: String, startsAt: Date, place: String?, ticketID: Int?) {
            self.title = title; self.startsAt = startsAt; self.place = place
            self.ticketID = ticketID
        }
        /// After the start the widget keeps "进行中" this long, then falls back to the activity list entry.
        public static let afterStart: TimeInterval = 3 * 60 * 60
        public var expiresAt: Date { startsAt.addingTimeInterval(Self.afterStart) }
    }

    /// Days with a finished roam walk, as local `yyyy-MM-dd` stamps (MP `subpackageRoam/history`).
    public struct RoamDays: Codable, Hashable, Sendable {
        public var days: [String]
        public init(days: [String]) {
            self.days = Array(Set(days)).sorted().suffix(RoamDays.keep).map { $0 }
        }
        /// Twelve weeks: enough for the medium grid.
        public static let keep = 84

        public static func stamp(_ date: Date, calendar: Calendar = .current) -> String {
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }

        public func walked(on date: Date, calendar: Calendar = .current) -> Bool {
            days.contains(Self.stamp(date, calendar: calendar))
        }

        /// Consecutive days up to today; a streak that ended yesterday still counts until today ends.
        public func streak(now: Date, calendar: Calendar = .current) -> Int {
            let set = Set(days)
            var day = calendar.startOfDay(for: now)
            if !set.contains(Self.stamp(day, calendar: calendar)) {
                guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
                day = yesterday
            }
            var count = 0
            while set.contains(Self.stamp(day, calendar: calendar)) {
                count += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previous
            }
            return count
        }

        /// Walked days inside the last `span` days (today included).
        public func walkedCount(last span: Int, now: Date, calendar: Calendar = .current) -> Int {
            let today = calendar.startOfDay(for: now)
            return (0..<max(0, span)).reduce(0) { total, offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return total }
                return total + (walked(on: day, calendar: calendar) ? 1 : 0)
            }
        }
    }

    /// Lit share of the city board around the player (`CityBoardStore.places`, not fogged / all) and passport stamps
    /// (MP `subpackageP3/pages/stamp-album`, `RoamAlbumPage.total`). Either half may be unknown until its screen loaded.
    public struct CityProgress: Codable, Hashable, Sendable {
        public var cityName: String?
        /// 0...1.
        public var revealed: Double?
        public var stamps: Int?
        public init(cityName: String?, revealed: Double?, stamps: Int?) {
            self.cityName = cityName
            self.revealed = revealed.map { $0.isFinite ? min(1, max(0, $0)) : 0 }
            self.stamps = stamps.map { max(0, $0) }
        }
    }

    /// IM unread total (MP `subpackageB/pages/im/list`, `IMUnreadTotalReader`) and the posts of the last 7 days on the
    /// first community page of the club the player last opened (MP `pages/club/detail` community tab; the API has no
    /// per-viewer "new posts" count).
    public struct Community: Codable, Hashable, Sendable {
        public var unread: Int?
        public var clubName: String?
        public var clubNewPosts: Int?
        /// Club id for the detail link.
        public var clubID: Int?
        public init(unread: Int?, clubName: String?, clubNewPosts: Int?, clubID: Int?) {
            self.unread = unread.map { max(0, $0) }; self.clubName = clubName
            self.clubNewPosts = clubNewPosts.map { max(0, $0) }; self.clubID = clubID
        }
    }

    // MARK: Links (reviewed `chein://` intake only, like `QuestWidgetLinks`)

    public static let myActivities = URL(string: "chein://mp/pages/activity/list/index")!
    public static let roamHistory = URL(string: "chein://mp/subpackageRoam/history/index")!
    public static let messages = URL(string: "chein://mp/subpackageB/pages/im/list/index")!
    public static let clubs = URL(string: "chein://mp/pages/talent/list/index")!

    /// The ticket pass (`CheinDeepLink.ticket`), or the activity list without a ticket.
    public static func ticket(_ id: Int?) -> URL {
        guard let id, id > 0, let url = URL(string: "chein://ticket/\(id)") else { return myActivities }
        return url
    }

    public static func club(_ id: Int?) -> URL {
        guard let id, id > 0, let url = URL(string: "chein://mp/pages/club/detail/index?id=\(id)") else { return clubs }
        return url
    }
}

/// Section storage on top of `QuestWidgetStore`'s App Group defaults.
public extension QuestWidgetStore {
    static let eventKey = "questWidget.event"
    static let roamDaysKey = "questWidget.roamDays"
    static let cityProgressKey = "questWidget.cityProgress"
    static let communityKey = "questWidget.community"
    /// A route a Control Center control asked for, consumed by the app when it becomes active.
    static let pendingRouteKey = "questWidget.pendingRoute"

    static func section<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = sharedDefaults()?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Stores (nil removes) a section. True when the stored bytes changed, so the caller reloads the widget only then.
    @discardableResult
    static func setSection<Value: Encodable>(_ value: Value?, key: String) -> Bool {
        guard let defaults = sharedDefaults() else { return false }
        let old = defaults.data(forKey: key)
        guard let value else {
            defaults.removeObject(forKey: key)
            return old != nil
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(value), data != old else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    /// MP page path a control parked for the app (nil clears it).
    static func setPendingRoute(_ pagePath: String?) {
        guard let defaults = sharedDefaults() else { return }
        if let pagePath, !pagePath.isEmpty { defaults.set(pagePath, forKey: pendingRouteKey) }
        else { defaults.removeObject(forKey: pendingRouteKey) }
    }

    /// Returns and clears the parked page path.
    static func takePendingRoute() -> String? {
        guard let defaults = sharedDefaults(), let path = defaults.string(forKey: pendingRouteKey) else { return nil }
        defaults.removeObject(forKey: pendingRouteKey)
        return path.isEmpty ? nil : path
    }
}
