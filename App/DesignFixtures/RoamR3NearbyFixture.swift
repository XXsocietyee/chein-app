#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-roam r3: 附近 (`subpackageRoam/nearby`) on the shipping `NearbyTeamsView` tab 0, one fixture per MP state:
/// team list (`r3-roam-nearby`), cy-empty 附近暂无节点 (`-empty`), cy-error 附近信息获取失败 + 重试 (`-error`).
/// Offline fake transport; team, leader and place names in the UI language (the older `nearby-*` fixtures are English only).
/// 我的队伍 (`subpackageRoam/my-teams`) on the same view, tab 1: groups 带队 / 已通过 / 审核中 / 未通过 (`r3-roam-my-teams`),
/// 还没有队伍 + 去地图找队伍 + 附近在招募 (`-empty`), 队伍获取失败 + 重试 (`-error`), 登录后查看 + 登录 (`-signedout`).
enum RoamR3NearbyFixture {
    enum Scenario { case content, empty, failure, mine, mineEmpty, mineFailure, mineSignedOut }

    @MainActor static func make(_ scenario: Scenario) -> AnyView {
        AnyView(RoamR3NearbyFixtureHost(scenario: scenario).themeDomain(.player))
    }

    static func isMine(_ scenario: Scenario) -> Bool {
        switch scenario {
        case .mine, .mineEmpty, .mineFailure, .mineSignedOut: return true
        case .content, .empty, .failure: return false
        }
    }

    /// Synthetic /api/team/my rows: one led by the fixture account (7001), one joined.
    static func joinedTeams(_ scenario: Scenario) -> [OwnedTeam] {
        guard scenario == .mine else { return [] }
        let rows: [[String: Any]] = [
            ["id": 631, "title": name("Bund night clue squad", "外滩夜色寻迹队"), "status": 0, "joinedCount": 2, "maxMembers": 4,
             "joinMode": 2, "leaderMemberId": 7001],
            ["id": 632, "title": name("Riverside photo walk", "滨江拍照散步队"), "status": 1, "joinedCount": 3, "maxMembers": 5,
             "joinMode": 2, "leaderMemberId": 8002],
        ]
        struct Envelope: Decodable { let data: [OwnedTeam] }
        let data = (try? JSONSerialization.data(withJSONObject: ["data": rows])) ?? Data()
        return (try? JSONDecoder().decode(Envelope.self, from: data).data) ?? []
    }

    static var applicationRows: [[String: Any]] {
        [
            ["teamId": 641, "title": name("Old street evening walk", "老街夜走搭子"), "leaderName": name("Jun", "小军"),
             "activityName": name("Old street neon", "老街霓虹"), "applyStatus": "PENDING", "applyExpireTime": "2099-10-02T02:00:00Z",
             "joinedCount": 3, "maxMembers": 5],
            ["teamId": 642, "title": name("Yu Garden lantern hunt", "豫园寻灯小队"), "leaderName": name("Mei", "阿梅"),
             "applyStatus": "REJECTED", "joinedCount": 4, "maxMembers": 4],
        ]
    }

    static var applicantRows: [[String: Any]] {
        [["memberId": 6101, "memberName": name("Alex", "小林"), "applyMessage": name("Happy to explore together", "一起走走"),
          "appliedAt": "2026-11-27 12:00:00", "applyExpireTime": "2099-10-02T02:00:00Z"]]
    }

    private static var prefersChinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }

    private static func name(_ en: String, _ zh: String) -> String { prefersChinese ? zh : en }

    static let context = NearbyQueryContext(latitude: 31.2400, longitude: 121.4900)

    private static func envelope(_ rows: [[String: Any]]) -> NearbyTeamResponse {
        let object: [String: Any] = ["code": 200, "data": rows]
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
        return NearbyTeamResponse(data: data)
    }

    static var teamRows: [[String: Any]] {
        [
            ["teamId": 611, "activityId": 921, "topicId": 821, "title": name("Saturday Bund explorers", "周六外滩探索小队"),
             "activityName": name("Bund night clues", "外滩夜色寻迹"), "leaderName": name("River", "阿川"),
             "addressName": name("Bund Origin courtyard", "外滩源庭院"), "coordSource": "GATHER", "productType": 1,
             "distance": 650, "latitude": 31.2433, "longitude": 121.4884, "joinedCount": 2, "maxMembers": 4,
             "viewerStatus": "NONE", "viewerHasTicket": true],
            ["teamId": 612, "activityId": 922, "title": name("Old street evening walk", "老街夜走搭子"),
             "activityName": name("Old street neon", "老街霓虹"), "leaderName": name("Jun", "小军"),
             "addressName": name("Fangbang Rd entrance", "方浜中路路口"), "coordSource": "GATHER", "productType": 1,
             "distance": 1800, "latitude": 31.2270, "longitude": 121.4920, "joinedCount": 3, "maxMembers": 5,
             "viewerStatus": "NONE", "viewerHasTicket": false],
        ]
    }

    @MainActor static func coordinator(_ scenario: Scenario) -> NearbyTeamCoordinator {
        let fake = NearbyTeamFakeTransport()
        var responses: [String: NearbyTeamResponse] = [
            "/api/team/my-applications": envelope([]),
            "/api/team/applications": envelope([]),
        ]
        switch scenario {
        case .content, .mineEmpty, .mineSignedOut: responses["/api/team/nearby"] = envelope(teamRows)
        case .empty: responses["/api/team/nearby"] = envelope([])
        case .failure: break
        case .mine:
            responses["/api/team/my-applications"] = envelope(applicationRows)
            responses["/api/team/applications"] = envelope(applicantRows)
        case .mineFailure:
            responses["/api/team/my-applications"] = nil
        }
        fake.fallbackResponses = responses
        let session: NearbyTeamSession? = scenario == .mineSignedOut ? nil : NearbyTeamSyntheticFixtures.session
        return .init(service: .init(fake: fake), session: session, locks: .init())
    }
}

@MainActor private struct RoamR3NearbyFixtureHost: View {
    @State private var coordinator: NearbyTeamCoordinator
    private let scenario: RoamR3NearbyFixture.Scenario

    init(scenario: RoamR3NearbyFixture.Scenario) {
        self.scenario = scenario
        _coordinator = State(initialValue: RoamR3NearbyFixture.coordinator(scenario))
    }

    private var ownedStatus: NearbyOwnedTeamsStatus {
        scenario == .mineSignedOut ? .failed("team.signIn") : .loaded
    }

    private var signIn: (() -> Void)? {
        guard scenario == .mineSignedOut else { return nil }
        return Self.noSignIn
    }

    private static func noSignIn() {}

    var body: some View {
        NavigationStack {
            NearbyTeamsView(coordinator: coordinator, context: RoamR3NearbyFixture.context,
                            joinedTeams: RoamR3NearbyFixture.joinedTeams(scenario),
                            initialTab: RoamR3NearbyFixture.isMine(scenario) ? 1 : 0,
                            onSignIn: signIn, joinedTeamsStatus: ownedStatus) { _ in }
        }
    }
}
#endif
