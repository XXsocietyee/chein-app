#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/activity/official-mine/index` (我发布的) shows
/// 我发起的活动 · N (title + status badge, city · category) and 我发的通知 · N (title + status badge,
/// "mode · 发给 audience · city", reach line), each with its own cy-empty title, plus the page-level load failure
/// 发布记录加载失败 + 重试 and the login gate. The page had no design fixture. These fixtures mount the same
/// `OfficialPublishedView` the activity list pushes, offline, rows in the UI language, no debug controls:
/// `t5-official-mine`, `t5-official-mine-empty`, `t5-official-mine-error`, `t5-official-mine-signed-out`.
/// The 主办控制台 entry needs an organizer access from the host, so it is not part of these fixtures.
@MainActor final class OfficialPublishedDesignFixtureReader: OfficialEventReading {
    enum Mode { case content, empty, failure, signedOut }
    let mode: Mode
    let scope = UUID()
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { mode != .signedOut }
    var isOfflineExample: Bool { false }

    init(mode: Mode) {
        self.mode = mode
    }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    func events(city: String?) async throws -> [OfficialEvent] {
        []
    }

    func detail(id: Int) async throws -> OfficialEvent {
        throw APIError.httpStatus(404)
    }

    func myEvents() async throws -> [OfficialEvent] {
        []
    }

    func partyInbox() async throws -> [OfficialPartyInvite] {
        []
    }

    func canPublish() async throws -> Bool { mode == .content }

    func myPublished() async throws -> OfficialPublished {
        switch mode {
        case .signedOut: throw APIError.unauthorized
        case .failure: throw APIError.httpStatus(503)
        case .empty: return try Self.decode(events: [], broadcasts: [])
        case .content: return try Self.decode(events: Self.events(), broadcasts: Self.broadcasts())
        }
    }

    func broadcastStats(id: Int) async throws -> OfficialBroadcastStats {
        try JSONDecoder().decode(OfficialBroadcastStats.self, from: Data("{}".utf8))
    }

    private static func decode(events: [[String: Any]], broadcasts: [[String: Any]]) throws -> OfficialPublished {
        let body: [String: Any] = ["events": events, "broadcasts": broadcasts]
        let data = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(OfficialPublished.self, from: data)
    }

    /// Three events in the MP list order: one running, one upcoming, one ended.
    private static func events() -> [[String: Any]] {
        [
            ["id": 401, "title": tt("West Lake Lights Night Walk", "西湖灯光夜游"), "city": tt("Hangzhou", "杭州"),
             "status": 2, "category": "city_light", "contractVersion": 2],
            ["id": 402, "title": tt("Canal Spring Orienteering", "运河春日定向赛"), "city": tt("Hangzhou", "杭州"),
             "status": 1, "category": "challenge", "contractVersion": 2],
            ["id": 403, "title": tt("Old Town Tea Street Chapter", "老城茶街章节"), "city": tt("Suzhou", "苏州"),
             "status": 6, "category": "festival"]
        ]
    }

    /// Two notices: one sent with its reach count, one waiting to go out (reach not known yet).
    private static func broadcasts() -> [[String: Any]] {
        [
            ["id": 501, "title": tt("Lantern route opens this Saturday", "灯笼线本周六开放"), "copyMode": 1,
             "audience": "player,club", "status": 2, "city": tt("Hangzhou", "杭州"), "reachedCount": 1284],
            ["id": 502, "title": tt("Meeting point moved to Gate 2", "集合点改到 2 号门"), "copyMode": 2,
             "audience": "player", "status": 1, "city": tt("Hangzhou", "杭州")]
        ]
    }
}

/// Pushed page inside a stack, like the official inbox fixtures.
struct OfficialPublishedDesignFixture: View {
    @State private var reader: OfficialPublishedDesignFixtureReader

    init(mode: OfficialPublishedDesignFixtureReader.Mode) {
        _reader = State(initialValue: OfficialPublishedDesignFixtureReader(mode: mode))
    }

    var body: some View {
        NavigationStack {
            OfficialPublishedView(reader: reader)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
