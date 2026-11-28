#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-roam r3: 附近 (`subpackageRoam/nearby`) on the shipping `NearbyTeamsView` tab 0, one fixture per MP state:
/// team list (`r3-roam-nearby`), cy-empty 附近暂无节点 (`-empty`), cy-error 附近信息获取失败 + 重试 (`-error`).
/// Offline fake transport; team, leader and place names in the UI language (the older `nearby-*` fixtures are English only).
enum RoamR3NearbyFixture {
    enum Scenario { case content, empty, failure }

    @MainActor static func make(_ scenario: Scenario) -> AnyView {
        AnyView(RoamR3NearbyFixtureHost(scenario: scenario).themeDomain(.player))
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
        case .content: responses["/api/team/nearby"] = envelope(teamRows)
        case .empty: responses["/api/team/nearby"] = envelope([])
        case .failure: break
        }
        fake.fallbackResponses = responses
        return .init(service: .init(fake: fake), session: NearbyTeamSyntheticFixtures.session, locks: .init())
    }
}

@MainActor private struct RoamR3NearbyFixtureHost: View {
    @State private var coordinator: NearbyTeamCoordinator

    init(scenario: RoamR3NearbyFixture.Scenario) {
        _coordinator = State(initialValue: RoamR3NearbyFixture.coordinator(scenario))
    }

    var body: some View {
        NavigationStack {
            NearbyTeamsView(coordinator: coordinator, context: RoamR3NearbyFixture.context, joinedTeams: [], initialTab: 0) { _ in }
        }
    }
}
#endif
