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
        // D5 merchant console (synthetic data, light, real views under .roleTheme(.merchant))
        case "merchant-home": return merchantConsoleFixture(.home)
        case "merchant-home-unknown": return merchantConsoleFixture(.homeUnknown)
        case "merchant-orders": return merchantConsoleFixture(.orders)
        case "merchant-projects": return merchantConsoleFixture(.projects)
        case "merchant-customers": return merchantConsoleFixture(.customers)
        case "merchant-finance": return merchantConsoleFixture(.finance)
        case "merchant-coupons": return merchantCouponFixture()
        // D1..D4: add cases below, e.g.  case "welcome": return AnyView(WelcomeFixture())
        default: return AnyView(Text(verbatim: "Unknown design fixture: \(name)").padding())
        }
    }
}
#endif
