#if DEBUG
import SwiftUI

/// Debug-only registry behind the launch argument `--design-fixture <name>`.
/// Screen workers: add ONE `case` per fixture in `make(_:)` that returns your `App/DesignFixtures/<Screen>Fixture.swift` view.
/// Fixtures use synthetic, clearly-labelled data and never ship in Release.
enum DesignFixtureRegistry {
    static func make(_ name: String) -> AnyView {
        switch name {
        case "kit": return AnyView(KitGalleryFixture(domain: .player))
        case "kit-2": return AnyView(KitGalleryFixture(domain: .player, lower: true))
        case "kit-merchant-2": return AnyView(KitGalleryFixture(domain: .merchant, lower: true))
        case "kit-merchant": return AnyView(KitGalleryFixture(domain: .merchant))
        case "d2-home": return AnyView(D2Fixture(screen: .home))
        case "d2-search": return AnyView(D2Fixture(screen: .search))
        case "d2-search-results": return AnyView(D2Fixture(screen: .searchResults))
        case "d2-square": return AnyView(D2Fixture(screen: .square))
        case "d2-play": return AnyView(D2Fixture(screen: .play))
        case "d2-city": return AnyView(D2Fixture(screen: .city))
        case "d2-npc": return AnyView(D2Fixture(screen: .npc))
        case "d2-inbox": return AnyView(D2Fixture(screen: .inbox))
        case "d2-me": return AnyView(D2Fixture(screen: .me))
        case "d2-roam": return AnyView(D2Fixture(screen: .roam))
        case "welcome": return AnyView(WelcomeFixture())
        case "welcome-menu": return AnyView(WelcomeMenuFixture())
        case "consent": return AnyView(ConsentFixture())
        case "login-player": return AnyView(LoginFixture())
        case "d6-play": return AnyView(D6MapFixture(kind: .play))
        case "d6-play-loading": return AnyView(D6MapFixture(kind: .playLoading))
        case "d6-roam": return AnyView(D6MapFixture(kind: .roam))
        case "d6-search": return AnyView(D6MapFixture(kind: .search))
        case "d6-live": return AnyView(D6MapFixture(kind: .live))
        // REAL RoamLiveSessionView on the synthetic RoamLiveFixture controller (offline example, no GPS/network).
        case "d6-real-live": return AnyView(D6RealLiveHost())
        // D1..D5: add cases below, e.g.  case "welcome": return AnyView(WelcomeFixture())
        default:
            if let d3 = MainActor.assumeIsolated({ OrdersWalletFixtures.make(name) }) { return d3 }
            return AnyView(Text(verbatim: "Unknown design fixture: \(name)").padding())
        }
    }
}
#endif
