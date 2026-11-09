#if DEBUG
import SwiftUI

/// Debug-only registry behind the launch argument `--design-fixture <name>`.
/// Screen workers: add ONE `case` per fixture in `make(_:)` that returns your `App/DesignFixtures/<Screen>Fixture.swift` view.
/// Fixtures use synthetic, clearly-labelled data and never ship in Release.
enum DesignFixtureRegistry {
    @MainActor static func make(_ name: String) -> AnyView {
        switch name {
        case "kit": return AnyView(KitGalleryFixture(domain: .player))
        case "kit-2": return AnyView(KitGalleryFixture(domain: .player, lower: true))
        case "kit-merchant-2": return AnyView(KitGalleryFixture(domain: .merchant, lower: true))
        case "kit-merchant": return AnyView(KitGalleryFixture(domain: .merchant))
        case "d4-directory": return AnyView(D4ClubFixture(.directory))
        case "d4-detail": return AnyView(D4ClubFixture(.detail(owner: false)))
        case "d4-owner-detail": return AnyView(D4ClubFixture(.detail(owner: true)))
        case "d4-channels": return AnyView(D4ClubFixture(.channels(list: true)))
        case "d4-channel-chat": return AnyView(D4ClubFixture(.channels(list: false)))
        case "d4-confirm": return AnyView(D4ClubFixture(.confirm))
        case "d4-settings": return AnyView(D4MeFixture(screen: .settings))
        case "d4-growth": return AnyView(D4MeFixture(screen: .growth))
        case "d4-leaderboard": return AnyView(D4MeFixture(screen: .leaderboard))
        case "d4-badges": return AnyView(D4MeFixture(screen: .badges))
        // D5 merchant console (synthetic data, light, real views under .roleTheme(.merchant))
        case "merchant-home": return merchantConsoleFixture(.home)
        case "merchant-home-unknown": return merchantConsoleFixture(.homeUnknown)
        case "merchant-orders": return merchantConsoleFixture(.orders)
        case "merchant-projects": return merchantConsoleFixture(.projects)
        case "merchant-customers": return merchantConsoleFixture(.customers)
        case "merchant-finance": return merchantConsoleFixture(.finance)
        case "merchant-coupons": return merchantCouponFixture()
        case "d6-play": return AnyView(D6MapFixture(kind: .play))
        case "d6-play-loading": return AnyView(D6MapFixture(kind: .playLoading))
        case "d6-roam": return AnyView(D6MapFixture(kind: .roam))
        case "d6-search": return AnyView(D6MapFixture(kind: .search))
        case "d6-live": return AnyView(D6MapFixture(kind: .live))
        // REAL RoamLiveSessionView on the synthetic RoamLiveFixture controller (offline example, no GPS/network).
        case "d6-real-live": return AnyView(D6RealLiveHost())
        // D7 creator / publish (PublishDesignFixtures)
        case let n where PublishDesignFixtures.make(n) != nil: return PublishDesignFixtures.make(n)!
        default: return AnyView(Text(verbatim: "Unknown design fixture: \(name)").padding())
        }
    }
}
#endif
