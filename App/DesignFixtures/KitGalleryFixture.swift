#if DEBUG
import SwiftUI

/// Gallery of every kit component (`--design-fixture kit` for player dark, `kit-merchant` for merchant light).
/// Delegates directly to `DesignKitFixture` so both `kit` and `design-kit` routes showcase every Part 4 & Part 5 component state.
struct KitGalleryFixture: View {
    let domain: ThemeDomain
    var lower = false

    var body: some View {
        DesignKitFixture(
            initialDomain: domain,
            initialMode: domain == .merchant ? .merchant : .player
        )
    }
}

#Preview("Kit · player dark") { KitGalleryFixture(domain: .player) }
#Preview("Kit · merchant light") { KitGalleryFixture(domain: .merchant) }
#endif
