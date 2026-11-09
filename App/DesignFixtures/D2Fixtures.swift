#if DEBUG
import SwiftUI

/// D2 (player home + discovery) design fixtures. Synthetic, clearly labelled data; they host the real views
/// through the existing module fixture hosts and apply the player (dark) role theme the way the real tabs do.
/// `--design-fixture d2-home | d2-search | d2-square | d2-roam`.
struct D2Fixture: View {
    enum Screen { case home, search, searchResults, square, roam, play, city, npc, inbox, me }
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
        case .searchResults:
            NavigationStack {
                GlobalSearchView(reader: SearchMapFixtureReader(scenario: .content), recommendedKeywords: GlobalSearchRecommendedKeywords.china) { _ in Color.clear }
            }
        case .square: SquareFixtureHostView()
        case .play: PlayExperienceFixtureHostView()
        case .city: CityGameFixtureHost()
        case .npc: ShopNPCFixtureView(enabled: true)
        case .inbox:
            NavigationStack {
                MessagingHomeView(reader: MessagingFixtureReader(.success), expanded: nil, squareDestination: { _ in AnyView(EmptyView()) })
            }
        case .me:
            AccountView(account: try! JSONDecoder().decode(Account.self, from: Data(#"{"id":81,"nickname":"Mia","role":"player","levelId":2}"#.utf8)))
                .environmentObject(AppSession())
        case .roam: RoamHomeFixtureHostView()
        }
    }
}
#endif
