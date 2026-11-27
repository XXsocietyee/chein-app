import Foundation
import WidgetKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Components r1 (C2): the app's only writer of the `QuestWidgetBoard` sections. Each call site already holds the
/// value after a successful read; this stores the display-only copy in the App Group and reloads that widget kind
/// only when the stored bytes changed. Without a provisioned App Group every write is a no-op.
@MainActor enum QuestWidgetBoardPublisher {
    /// Activity times in the wallet are Beijing wall-clock text (`TicketWalletContracts`).
    private static let beijing = TimeZone(identifier: "Asia/Shanghai")
    /// Club community: posts younger than this count as "this week".
    static let postWindow: TimeInterval = 7 * 24 * 60 * 60

    // MARK: Sections

    /// Home 今日 ticket (`SessionHomeFeedView.reloadTodayTicket`); nil clears the countdown.
    static func nextTicket(_ candidate: HomeTodayCandidate?) {
        let event = candidate.flatMap { candidate -> QuestWidgetBoard.Event? in
            guard let start = candidate.start else { return nil }
            // `HomeTodayCandidate.nextTicket` ids are "ticket-<wallet id>".
            let ticketID = candidate.id.hasPrefix("ticket-") ? Int(candidate.id.dropFirst("ticket-".count)) : nil
            return QuestWidgetBoard.Event(title: candidate.title, startsAt: start, place: candidate.place, ticketID: ticketID)
        }
        write(event, key: QuestWidgetStore.eventKey, kind: QuestWidgetBoard.eventKind)
    }

    /// Finished roam walks (local history, newest first) → walked days.
    static func roamHistory(_ records: [RoamHistoryRecord]) {
        let stamps = records.compactMap(\.recordedAt).map { QuestWidgetBoard.RoamDays.stamp($0) }
        let stored = QuestWidgetStore.section(QuestWidgetBoard.RoamDays.self, key: QuestWidgetStore.roamDaysKey)
        // Union with what is stored: the local history keeps 50 walks, the grid shows 12 weeks.
        let days = QuestWidgetBoard.RoamDays(days: stamps + (stored?.days ?? []))
        write(days, key: QuestWidgetStore.roamDaysKey, kind: QuestWidgetBoard.roamStreakKind)
    }

    /// City board around the player (`CityBoardStore.places`): lit share = not fogged / all.
    static func cityPlaces(_ places: [CityPlace]) {
        guard !places.isEmpty else { return }
        let lit = places.filter { $0.ownership != .fogged }.count
        updateCity { $0.revealed = Double(lit) / Double(places.count) }
    }

    /// Passport stamp total (album `RoamAlbumPage.total`, or the device count).
    static func stamps(_ count: Int?) {
        guard let count else { return }
        updateCity { $0.stamps = max(0, count) }
    }

    /// IM unread total (`IMUnreadTotalReader.unreadTotal()`).
    static func unread(_ total: Int) {
        updateCommunity { $0.unread = max(0, total) }
    }

    /// First community page of a club: its name and the posts of the last 7 days.
    static func clubPosts(_ posts: [ClubCommunityPost], clubID: Int, now: Date = Date()) {
        let recent = posts.filter { post in
            guard let created = HomeFeedDate.parse(post.createTime, sourceTimeZone: beijing) else { return false }
            return now.timeIntervalSince(created) <= postWindow
        }
        let name = posts.first(where: { !$0.clubName.isEmpty })?.clubName
        updateCommunity { community in
            community.clubID = clubID
            community.clubNewPosts = recent.count
            if let name { community.clubName = name }
        }
    }

    /// Signed out, or another account signed in: the widgets drop the previous account's titles and counts.
    /// A restore (no account → account) keeps them; the screens overwrite them on their next read.
    static func accountChanged(from previous: Int?, to current: Int?) {
        guard previous != current, current == nil || previous != nil else { return }
        clearAll()
    }

    static func clearAll() {
        let sections: [(key: String, kind: String)] = [
            (QuestWidgetStore.eventKey, QuestWidgetBoard.eventKind),
            (QuestWidgetStore.roamDaysKey, QuestWidgetBoard.roamStreakKind),
            (QuestWidgetStore.cityProgressKey, QuestWidgetBoard.cityProgressKind),
            (QuestWidgetStore.communityKey, QuestWidgetBoard.communityKind),
        ]
        for section in sections {
            let none: QuestWidgetBoard.Event? = nil
            write(none, key: section.key, kind: section.kind)
        }
        if QuestWidgetStore.write(nil) { WidgetCenter.shared.reloadTimelines(ofKind: QuestWidgetStore.nextStopKind) }
        QuestWidgetStore.setPendingRoute(nil)
    }

    // MARK: Control Center controls (iOS 18)

    /// Called at launch: a control intent run in the app process routes at once.
    static func installControlRoute() {
        #if canImport(AppIntents) && os(iOS)
        QuestControlRouteIntent.handler = { MPNotificationTapRouter.shared.open(pagePath: $0) }
        #endif
    }

    /// Scene became active: open a page a control parked while running in the widget extension.
    static func openParkedControlRoute() {
        guard let pagePath = QuestWidgetStore.takePendingRoute() else { return }
        MPNotificationTapRouter.shared.open(pagePath: pagePath)
    }

    // MARK: Storage

    private static func updateCity(_ change: (inout QuestWidgetBoard.CityProgress) -> Void) {
        var value = QuestWidgetStore.section(QuestWidgetBoard.CityProgress.self, key: QuestWidgetStore.cityProgressKey)
            ?? QuestWidgetBoard.CityProgress(cityName: nil, revealed: nil, stamps: nil)
        change(&value)
        write(value, key: QuestWidgetStore.cityProgressKey, kind: QuestWidgetBoard.cityProgressKind)
    }

    private static func updateCommunity(_ change: (inout QuestWidgetBoard.Community) -> Void) {
        var value = QuestWidgetStore.section(QuestWidgetBoard.Community.self, key: QuestWidgetStore.communityKey)
            ?? QuestWidgetBoard.Community(unread: nil, clubName: nil, clubNewPosts: nil, clubID: nil)
        change(&value)
        write(value, key: QuestWidgetStore.communityKey, kind: QuestWidgetBoard.communityKind)
    }

    private static func write<Value: Encodable>(_ value: Value?, key: String, kind: String) {
        if QuestWidgetStore.setSection(value, key: key) { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
    }
}
