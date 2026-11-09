#if DEBUG
import SwiftUI

/// Debug-only registry behind the launch argument `--design-fixture <name>`.
/// Screen workers: add ONE `case` per fixture in `make(_:)` that returns your `App/DesignFixtures/<Screen>Fixture.swift` view.
/// Fixtures use synthetic, clearly-labelled data and never ship in Release.
enum DesignFixtureRegistry {
    static func make(_ name: String) -> AnyView {
        switch name {
        case "kit": return AnyView(KitGalleryFixture(domain: .player))
        case "kit-merchant": return AnyView(KitGalleryFixture(domain: .merchant))
        // D1..D5: add cases below, e.g.  case "welcome": return AnyView(WelcomeFixture())
        default: return AnyView(Text(verbatim: "Unknown design fixture: \(name)").padding())
        }
    }
}
#endif
