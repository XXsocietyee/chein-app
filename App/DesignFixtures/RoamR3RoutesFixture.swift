#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-roam r3: 官方线路 (`subpackageRoam/official-routes`) on the shipping map-home list (`RoamMapHomeRoutesList`),
/// one fixture per MP state: list (`r3-roam-routes`), cy-empty 还没有上架的官方线路 (`-empty`), cy-error 线路加载失败 + 重试 (`-error`).
/// 官方线路详情 (`subpackageRoam/official-route`) on the shipping route card (`RoamMapHomeRouteCard`): content (`r3-roam-route`),
/// cy-error 线路加载失败 (`-error`), cy-empty 这条线路不存在或已下架 (`-notfound`).
/// Offline synthetic routes, names in the UI language; no network.
enum RoamR3RoutesFixture {
    enum Scenario { case content, empty, failure, notFound }

    private static var prefersChinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }

    private static func name(_ en: String, _ zh: String) -> String { prefersChinese ? zh : en }

    static var routes: [OfficialRoute] {
        [
            OfficialRoute(id: "1", name: name("Bund night walk", "外滩夜色步行线"), city: name("Shanghai", "上海"),
                          previewImage: "", distanceKm: 3.2, totalMinutes: 95),
            OfficialRoute(id: "2", name: name("Old street neon loop", "老街霓虹环线"), city: name("Shanghai", "上海"),
                          previewImage: "", distanceKm: 2.4, totalMinutes: 75),
            OfficialRoute(id: "3", name: name("Riverside sunrise trail", "江畔日出线"), city: name("Hangzhou", "杭州"),
                          previewImage: "", distanceKm: 5.8, totalMinutes: 130),
        ]
    }

    static var nodes: [OfficialRouteNode] {
        [
            OfficialRouteNode(key: "a", order: 1, name: name("Bund Origin courtyard", "外滩源庭院"), address: name("33 Zhongshan East 1st Rd", "中山东一路33号"),
                              imageURL: "", stayMinutes: 15, latitude: 31.2433, longitude: 121.4884),
            OfficialRouteNode(key: "b", order: 2, name: name("Waibaidu Bridge", "外白渡桥"), address: name("Suzhou Creek mouth", "苏州河口"),
                              imageURL: "", stayMinutes: 10, latitude: 31.2459, longitude: 121.4893),
            OfficialRouteNode(key: "c", order: 3, name: name("Riverside promenade", "滨江步道"), address: name("Zhongshan East 1st Rd", "中山东一路"),
                              imageURL: "", stayMinutes: 0, latitude: 31.2385, longitude: 121.4903),
        ]
    }

    static func reader(_ scenario: Scenario) -> OfficialRouteReader {
        let list = routes
        let stops = nodes
        return OfficialRouteReader(
            list: {
                switch scenario {
                case .content: return list
                case .empty: return []
                case .failure, .notFound: throw URLError(.badServerResponse)
                }
            },
            detail: { _ in
                switch scenario {
                case .content, .empty: return OfficialRouteDetail(route: list[0], nodes: stops)
                case .failure: throw URLError(.badServerResponse)
                case .notFound: throw OfficialRouteReader.Failure.notFound
                }
            }
        )
    }

    @MainActor static func make(_ scenario: Scenario) -> AnyView {
        AnyView(RoamR3RoutesFixtureHost(scenario: scenario))
    }

    @MainActor static func makeDetail(_ scenario: Scenario) -> AnyView {
        AnyView(RoamR3RouteDetailFixtureHost(scenario: scenario))
    }
}

@MainActor private struct RoamR3RoutesFixtureHost: View {
    let scenario: RoamR3RoutesFixture.Scenario
    @State private var model = RoamMapHomeModel()

    var body: some View {
        NavigationStack {
            RoamMapHomeRoutesList(reader: RoamR3RoutesFixture.reader(scenario), model: model)
        }
    }
}

@MainActor private struct RoamR3RouteDetailFixtureHost: View {
    let scenario: RoamR3RoutesFixture.Scenario
    @State private var model = RoamMapHomeModel()

    var body: some View {
        NavigationStack {
            RoamMapHomeRouteCard(reader: RoamR3RoutesFixture.reader(scenario), routeID: "1", model: model)
        }
    }
}
#endif
