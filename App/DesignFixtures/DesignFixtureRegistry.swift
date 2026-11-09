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
        // D1..D5: add cases below, e.g.  case "welcome": return AnyView(WelcomeFixture())
        default: return AnyView(Text(verbatim: "Unknown design fixture: \(name)").padding())
        }
    }
}
#endif
