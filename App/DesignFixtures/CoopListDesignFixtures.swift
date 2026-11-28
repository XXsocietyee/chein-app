#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/coop/list/index` (协作邀请 title, 收到的 / 我发出的
/// tabs, invite cards: status · 来自 X, topic, type · countdown, terms, deposit line, 留言, 拒绝 / 接受合作 or
/// 查看合作 + 缴纳保证金; received 带队申请 with 拒绝 / 回邀约; 承接报名 with 确认占槽; cy-empty per box;
/// cy-skeleton loading; cy-error 协作邀请加载失败 + 重试; 当前身份不能查看协作邀请; 登录后查看协作邀请 + 去登录;
/// a partial source failure). The only fixtures were the merchant lane's `t12-coop-invites(-empty)`: English
/// "Sample … partner" rows in both languages, an offline-example line, and no failure or signed-out state. These mount
/// the same `CooperationBrowserView`, offline, rows in the UI language: `t5-coop-list`, `-empty`, `-error`,
/// `-signed-out`, `-no-permission`, `-loading`, `-partial`.
@MainActor final class CoopListDesignFixtureReader: CooperationReading {
    enum Mode { case content, empty, failure, signedOut, noPermission, loading, partial }
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

    private static func stamp(days: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date().addingTimeInterval(days * 24 * 60 * 60))
    }

    private static func day(_ days: Double) -> String {
        String(stamp(days: days).prefix(10))
    }

    func inbox(direction: CooperationDirection) async throws -> CooperationInbox {
        switch mode {
        case .loading:
            try await Task.sleep(for: .seconds(600))
            throw CancellationError()
        case .signedOut: throw APIError.unauthorized
        case .failure: throw APIError.httpStatus(503)
        case .noPermission: throw CooperationReadFailure.forbidden(message: nil)
        default: break
        }
        let empty = mode == .empty
        let invites = try JSONDecoder().decode(CooperationInvites.self, from: Self.invitations(empty: empty))
        let applies = try JSONDecoder().decode([CooperationApplication].self, from: Self.applications(direction: direction, empty: empty))
        let registrations: CooperationSection<CooperationRegistrations>?
        if direction == .sent {
            registrations = nil
        } else if mode == .partial {
            registrations = .failure(.server(Self.tt("Candidate registrations couldn't be loaded. Pull to refresh.", "承接报名暂时没加载出来，下拉刷新再试。")))
        } else {
            registrations = .content(try JSONDecoder().decode(CooperationRegistrations.self, from: Self.registrations(empty: empty)))
        }
        return CooperationInbox(direction: direction, invitations: .content(invites), applications: .content(applies), registrations: registrations)
    }

    func detail(key: CooperationInviteKey) async throws -> CooperationInviteDetail {
        throw CooperationReadFailure.unavailable
    }

    func pool() async throws -> CooperationPool {
        try JSONDecoder().decode(CooperationPool.self, from: Data(#"{"hasClub":true,"rows":[]}"#.utf8))
    }

    func candidates(topicID: Int) async throws -> CooperationCandidates {
        try JSONDecoder().decode(CooperationCandidates.self, from: Data(#"{"clubApplies":[],"registrations":[]}"#.utf8))
    }

    /// `api/coop/list`: received = a pending club invite from a tea house (3-day validity, notes) and an accepted
    /// split invite with the deposit still owed; sent = an accepted fixed-fee invite to a bike rental.
    private static func invitations(empty: Bool) throws -> Data {
        if empty { return Data(#"{"sent":[],"received":[]}"#.utf8) }
        let pending: [String: Any] = [
            "id": 71, "inviteType": 1, "fromType": "merchant", "toType": "club", "fromId": 20, "toId": 30, "topicId": 301,
            "topicName": tt("West Lake Lantern Route", "西湖灯笼线"), "status": 0, "shareMode": 1, "shareRate": 12.5,
            "message": tt("Could your club guide players on stops 2–4 this weekend?", "本周末想请贵俱乐部负责第 2–4 站的引导。"),
            "partner": ["name": tt("Lantern Lane Tea House", "灯笼巷茶馆")],
            "createTime": stamp(days: -1), "expireTime": stamp(days: 3)
        ]
        let accepted: [String: Any] = [
            "id": 72, "inviteType": 1, "fromType": "merchant", "toType": "club", "fromId": 21, "toId": 30, "topicId": 302,
            "topicName": tt("Old Town Night Walk", "老城夜游"), "status": 1, "shareMode": 1, "shareRate": 10,
            "termsFrozen": true, "depositOwed": true,
            "partner": ["name": tt("Old Town Night Market", "老城夜市")],
            "createTime": stamp(days: -6)
        ]
        let sent: [String: Any] = [
            "id": 73, "inviteType": 0, "fromType": "club", "toType": "merchant", "fromId": 30, "toId": 22, "topicId": 301,
            "topicName": tt("West Lake Lantern Route", "西湖灯笼线"), "status": 1, "shareMode": 2, "fixedFee": 80,
            "termsFrozen": true,
            "partner": ["name": tt("Lakeside Bike Rental", "湖畔单车租赁")],
            "createTime": stamp(days: -3)
        ]
        let slots: [String: Any] = ["byTopic": ["301": ["accepted": 1, "cap": 3]]]
        return try JSONSerialization.data(withJSONObject: ["sent": [sent], "received": [pending, accepted], "slots": slots])
    }

    /// `api/coop/pool/applies`: received = a club asking to lead our route; sent = our pending application.
    private static func applications(direction: CooperationDirection, empty: Bool) throws -> Data {
        if empty { return Data("[]".utf8) }
        let row: [String: Any]
        if direction == .received {
            row = ["applyId": 81, "topicId": 301, "status": 0, "clubId": 31, "scope": "MERCHANT",
                   "clubName": tt("Hill Trail Runners", "山径跑团"), "topicName": tt("West Lake Lantern Route", "西湖灯笼线"),
                   "startDate": day(9)]
        } else {
            row = ["applyId": 82, "topicId": 303, "status": 0,
                   "clubName": tt("Lakeside Walkers Club", "湖畔行走俱乐部"), "merchantNick": tt("Canal Boat Tours", "运河游船"),
                   "topicName": tt("Grand Canal Evening Cruise", "大运河夜航"),
                   "message": tt("We can lead groups of up to 12 on Friday nights.", "我们周五晚可带 12 人以内的队。")]
        }
        return try JSONSerialization.data(withJSONObject: [row])
    }

    /// `api/coop/registrations/received`: one merchant waiting for 确认占槽.
    private static func registrations(empty: Bool) throws -> Data {
        let rows: [[String: Any]] = empty ? [] : [[
            "id": 91, "topicId": 301, "topicName": tt("West Lake Lantern Route", "西湖灯笼线"), "memberId": 50,
            "merchantName": tt("Lotus Pond Café", "荷塘咖啡"), "merchantMeta": tt("Café · Xihu", "咖啡馆 · 西湖区"),
            "addressName": tt("Stop 3 · Su Causeway north gate", "第 3 站 · 苏堤北口"), "auditStatus": 0
        ]]
        return try JSONSerialization.data(withJSONObject: ["rows": rows, "hasMore": false])
    }
}

/// Tab-root style page in its own stack, like the workbench 协作邀请 row opens it; 去登录 is a no-op here.
struct CoopListDesignFixture: View {
    @State private var reader: CoopListDesignFixtureReader

    init(mode: CoopListDesignFixtureReader.Mode) {
        _reader = State(initialValue: CoopListDesignFixtureReader(mode: mode))
    }

    var body: some View {
        CooperationBrowserView(reader: reader)
            .environment(\.merchantOpenSignIn, {})
            .themeDomain(.player)
            .cyDomainPageBackground()
    }
}
#endif
