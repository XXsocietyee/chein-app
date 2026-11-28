#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/activity/official-inbox/index` (邀约) shows one card per
/// invite (event · city · role, status word, role note, scope, window, capacity, summary), cy-empty 暂无邀约, the load
/// failure with 重试 and the signed-out state. The page had no design fixture, only the UI-test host with English
/// "Synthetic … invitation" rows and guest / account buttons on top. These fixtures mount the same
/// `OfficialInboxView` the activity list pushes, offline, rows in the UI language, no debug controls:
/// `t5-official-inbox`, `t5-official-inbox-empty`, `t5-official-inbox-error`, `t5-official-inbox-signed-out`.
@MainActor final class OfficialInboxDesignFixtureReader: OfficialEventReading {
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
        switch mode {
        case .signedOut: throw APIError.unauthorized
        case .failure: throw APIError.httpStatus(503)
        case .empty: return []
        case .content: return try Self.invites()
        }
    }

    func canPublish() async throws -> Bool { false }

    func myPublished() async throws -> OfficialPublished {
        try JSONDecoder().decode(OfficialPublished.self, from: Data("{}".utf8))
    }

    func broadcastStats(id: Int) async throws -> OfficialBroadcastStats {
        try JSONDecoder().decode(OfficialBroadcastStats.self, from: Data("{}".utf8))
    }

    /// Three invites in the MP status order: a new club invite with its service window and capacity, an accepted
    /// co-organizer role, and an active sponsor on a paused event.
    private static func invites() throws -> [OfficialPartyInvite] {
        let day: Double = 24 * 60 * 60 * 1000
        let now = Date().timeIntervalSince1970 * 1000
        let rows: [[String: Any]] = [
            ["partyId": 81, "partyType": "CLUB", "status": "INVITED", "role": "FULFILLMENT_CLUB", "targetType": "ROUTE",
             "eventTitle": tt("West Lake Lights Night Walk", "西湖灯光夜游"), "city": tt("Hangzhou", "杭州"),
             "capacity": 30, "windowStart": now + 6 * day, "windowEnd": now + 6 * day + 4 * 60 * 60 * 1000,
             "responsibilitySummary": tt("Guide players on stops 2–4 of the lantern route and confirm their check-ins.",
                                         "负责灯笼线第 2–4 站的引导与打卡核验。")],
            ["partyId": 82, "partyType": "CLUB", "status": "ACCEPTED", "role": "CO_ORGANIZER", "targetType": "EVENT",
             "eventTitle": tt("Canal Spring Orienteering", "运河春日定向赛"), "city": tt("Hangzhou", "杭州"),
             "responsibilitySummary": tt("Run the start area and the finish-line photo point.", "负责起点区和终点合影点。")],
            ["partyId": 83, "partyType": "CLUB", "status": "ACTIVE", "role": "SPONSOR", "targetType": "EVENT",
             "eventTitle": tt("Old Town Tea Street Chapter", "老城茶街章节"), "city": tt("Suzhou", "苏州"),
             "controlState": "PAUSED"]
        ]
        let data = try JSONSerialization.data(withJSONObject: rows)
        return try JSONDecoder().decode([OfficialPartyInvite].self, from: data)
    }
}

/// Pushed page inside a stack, like the activity list fixtures.
struct OfficialInboxDesignFixture: View {
    @State private var reader: OfficialInboxDesignFixtureReader

    init(mode: OfficialInboxDesignFixtureReader.Mode) {
        _reader = State(initialValue: OfficialInboxDesignFixtureReader(mode: mode))
    }

    var body: some View {
        NavigationStack {
            OfficialInboxView(reader: reader)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
