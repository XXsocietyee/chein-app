#if DEBUG
import SwiftUI

/// D2 (player home + discovery) design fixtures. Synthetic, clearly labelled data; they host the real views
/// through the existing module fixture hosts and apply the player (dark) role theme the way the real tabs do.
/// `--design-fixture d2-home | d2-search | d2-square | d2-roam`.
struct D2Fixture: View {
    enum Screen { case home, search, square, roam }
    let screen: Screen

    var body: some View {
        host
            .themeDomain(.player)
            .cyDomainPageBackground()
            .themeDomain(.player)
    }

    @ViewBuilder private var host: some View {
        switch screen {
        case .home: HomeFeedFixtureHostView(forceHero: true)
        case .search: SearchMapFixtureHostView()
        case .square: SquareFixtureHostView()
        case .roam: RoamHomeFixtureHostView()
        }
    }
}
#endif
