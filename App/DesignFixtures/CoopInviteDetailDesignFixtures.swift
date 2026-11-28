#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/coop/invite-detail/index` (status + 来自 X · time,
/// topic title, validity countdown, 查看主题, 联系方式, 合作条款 (parties, split, slots, 核销据点, deposit), 留言 /
/// 回复, the decide / ongoing footer, and the cy-state-shell missing-invite and load-failure states). The page had no
/// design fixture, only the UI-test host with English "Sample … partner" rows and an offline-example line. These mount
/// the same `CooperationInviteDetailView` the coop list pushes, offline, text in the UI language, no debug controls:
/// `t5-coop-invite-detail` (received, pending), `-accepted` (sent, accepted, contact visible), `-ended`,
/// `-unavailable`, `-error`.
@MainActor final class CoopInviteDetailDesignFixtureReader: CooperationReading {
    enum Mode { case pending, accepted, ended, unavailable, failure }
    let mode: Mode
    let scope = UUID()
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { false }

    init(mode: Mode) {
        self.mode = mode
    }

    var key: CooperationInviteKey {
        CooperationInviteKey(id: 71, direction: mode == .accepted ? .sent : .received)
    }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    private static func stamp(days: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date().addingTimeInterval(days * 24 * 60 * 60))
    }

    func inbox(direction: CooperationDirection) async throws -> CooperationInbox {
        throw APIError.httpStatus(404)
    }

    func detail(key: CooperationInviteKey) async throws -> CooperationInviteDetail {
        switch mode {
        case .failure: throw APIError.httpStatus(503)
        case .unavailable: throw CooperationReadFailure.unavailable
        default: break
        }
        let row = try JSONDecoder().decode(CooperationInvite.self, from: Self.row(mode: mode))
        return CooperationInviteDetail(row: row, occupancy: nil)
    }

    func pool() async throws -> CooperationPool {
        throw APIError.httpStatus(404)
    }

    func candidates(topicID: Int) async throws -> CooperationCandidates {
        throw APIError.httpStatus(404)
    }

    /// One `api/coop/list` row per state: a pending club invite with notes and a 3-day validity, an accepted
    /// fixed-fee invite we sent (partner contact visible), and a declined one with the partner's reply.
    private static func row(mode: Mode) throws -> Data {
        var row: [String: Any] = [
            "id": 71, "inviteType": 1, "fromType": "merchant", "toType": "club", "fromId": 20, "toId": 30,
            "topicId": 301,
            "topicName": tt("West Lake Lantern Route", "西湖灯笼线"),
            "viewerPartyName": tt("Lakeside Walkers Club", "湖畔行走俱乐部"),
            "createTime": stamp(days: -2),
            "supplyStationId": 12,
            "supplyStationName": tt("Lantern Lane Tea House", "灯笼巷茶馆")
        ]
        switch mode {
        case .accepted:
            row["status"] = 1
            row["fromType"] = "club"
            row["toType"] = "merchant"
            row["shareMode"] = 2
            row["fixedFee"] = 80
            row["termsFrozen"] = true
            row["message"] = tt("We'd like your tea house as stop 3. Players get a cup of tea on check-in.",
                                "想请贵店做第 3 站，玩家打卡后可领一杯茶。")
            row["handleReason"] = tt("Happy to join. Weekends 10:00–18:00 work for us.", "乐意参加，周末 10:00–18:00 都可以。")
            row["partner"] = ["name": tt("Lantern Lane Tea House", "灯笼巷茶馆"),
                              "leaderName": tt("Ms. Lin", "林女士"), "phone": "138 0000 0000"]
        case .ended:
            row["status"] = 2
            row["shareMode"] = 1
            row["shareRate"] = 10
            row["message"] = tt("Could your club guide the night walk on Saturdays?", "想请贵俱乐部周六晚带夜游线。")
            row["handleReason"] = tt("Sorry, our members are booked through next month.", "抱歉，下个月成员都已排满。")
            row["partner"] = ["name": tt("Old Town Night Market", "老城夜市")]
        default:
            row["status"] = 0
            row["shareMode"] = 1
            row["shareRate"] = 12.5
            row["expireTime"] = stamp(days: 3)
            row["message"] = tt("Could your club guide players on stops 2–4 of the lantern route this weekend?",
                                "本周末想请贵俱乐部负责灯笼线第 2–4 站的引导。")
            row["partner"] = ["name": tt("Lantern Lane Tea House", "灯笼巷茶馆")]
        }
        return try JSONSerialization.data(withJSONObject: row)
    }
}

/// Pushed page inside a stack, like the coop list pushes it.
struct CoopInviteDetailDesignFixture: View {
    @State private var reader: CoopInviteDetailDesignFixtureReader

    init(mode: CoopInviteDetailDesignFixtureReader.Mode) {
        _reader = State(initialValue: CoopInviteDetailDesignFixtureReader(mode: mode))
    }

    var body: some View {
        NavigationStack {
            CooperationInviteDetailView(key: reader.key, reader: reader)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
