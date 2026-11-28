#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-roam r3: 官方线路 (`subpackageRoam/official-routes`) on the shipping map-home list (`RoamMapHomeRoutesList`),
/// one fixture per MP state: list (`r3-roam-routes`), cy-empty 还没有上架的官方线路 (`-empty`), cy-error 线路加载失败 + 重试 (`-error`).
/// Offline synthetic routes, names in the UI language; no network.
enum RoamR3RoutesFixture {
    enum Scenario { case content, empty, failure }

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

    static func reader(_ scenario: Scenario) -> OfficialRouteReader {
        let list = routes
        return OfficialRouteReader(
            list: {
                switch scenario {
                case .content: return list
                case .empty: return []
                case .failure: throw OfficialRouteReader.Failure.notFound
                }
            },
            detail: { _ in throw OfficialRouteReader.Failure.notFound }
        )
    }

    @MainActor static func make(_ scenario: Scenario) -> AnyView {
        AnyView(RoamR3RoutesFixtureHost(scenario: scenario))
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
#endif
