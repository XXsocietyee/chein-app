#if DEBUG
import Foundation
import SwiftUI

/// mp-home r3 continue 27 ("Next round" item 3, all states): the 首页 banner 和朋友报名活动 opens MP
/// `pages/activity/list/index` (native `OfficialEventsBrowserView`), but no sweep fixture showed it.
/// `rep3-activity-list` = content (live tab), `rep3-activity-list-failed` = MP cy-error 活动列表没能打开 + 重试.
/// Offline data only; every string follows the UI language (coordinator 19:15 / 19:50).
@MainActor final class HomeActivityListFixtureReader: OfficialEventReading {
    let failing: Bool
    let scope = UUID()
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { true }

    init(failing: Bool) { self.failing = failing }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    private static func row(_ id: Int, _ title: String, _ subtitle: String, _ city: String, status: Int, people: Int, startDays: Double) -> [String: Any] {
        let start = (Date().timeIntervalSince1970 + startDays * 86_400) * 1000
        return ["id": id, "title": title, "subtitle": subtitle, "city": city, "status": status,
                "participants": people, "activityStart": start.rounded()]
    }

    private static var rows: [[String: Any]] {
        [
            row(201, tt("Lantern Market Night Walk", "灯笼集市夜游"), tt("Walk the old market lanes with friends", "和朋友一起走老集市小巷"),
                tt("Hangzhou", "杭州"), status: 3, people: 48, startDays: 0),
            row(202, tt("West Lake Morning Photo Walk", "西湖晨光摄影漫步"), tt("Meet at Broken Bridge, cameras ready", "断桥集合，带上相机"),
                tt("Hangzhou", "杭州"), status: 2, people: 16, startDays: 2),
            row(203, tt("Bund Riverside Orienteering", "外滩江畔城市定向"), tt("Teams of four, six checkpoints", "四人一队，六个打卡点"),
                tt("Shanghai", "上海"), status: 3, people: 32, startDays: 1),
            row(204, tt("Tea Street Story Hunt", "茶街故事寻踪"), tt("Opens next week", "下周开放报名"),
                tt("Hangzhou", "杭州"), status: 1, people: 0, startDays: 7),
            row(205, tt("Old Town Autumn Festival", "老城秋日节"), tt("Thanks for joining", "感谢参与"),
                tt("Suzhou", "苏州"), status: 5, people: 120, startDays: -20),
        ]
    }

    private func check() throws {
        if failing { throw APIError.httpStatus(503) }
    }

    func events(city: String?) async throws -> [OfficialEvent] {
        try check()
        let data = try JSONSerialization.data(withJSONObject: Self.rows)
        return try JSONDecoder().decode([OfficialEvent].self, from: data)
    }

    func detail(id: Int) async throws -> OfficialEvent {
        try check()
        let match = Self.rows.first { ($0["id"] as? Int) == id } ?? Self.rows[0]
        let data = try JSONSerialization.data(withJSONObject: match)
        return try JSONDecoder().decode(OfficialEvent.self, from: data)
    }

    func myEvents() async throws -> [OfficialEvent] {
        try check()
        return []
    }

    func partyInbox() async throws -> [OfficialPartyInvite] {
        try check()
        return []
    }

    func canPublish() async throws -> Bool { false }

    func myPublished() async throws -> OfficialPublished {
        try JSONDecoder().decode(OfficialPublished.self, from: Data("{}".utf8))
    }

    func broadcastStats(id: Int) async throws -> OfficialBroadcastStats {
        try JSONDecoder().decode(OfficialBroadcastStats.self, from: Data("{}".utf8))
    }
}

/// Pushed page inside a stack, as the 首页 banner pushes it (`SessionHomeFeedView` navigationDestination).
struct HomeActivityListFixture: View {
    let failing: Bool
    @State private var reader: HomeActivityListFixtureReader

    init(failing: Bool) {
        self.failing = failing
        _reader = State(initialValue: HomeActivityListFixtureReader(failing: failing))
    }

    var body: some View {
        NavigationStack {
            OfficialEventsBrowserView(reader: reader)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
