#if DEBUG
import SwiftUI

/// Four-tab IA fixtures (W1-1 / W1-4 / W3-6). Synthetic and clearly labelled; never shipped in Release.
/// Names: ia-tabs, ia-explore-create, ia-passport, ia-passport-unknown, ia-passport-ax5, ia-deeplinks.

/// The real player bar chrome over the tab roots, each with the standard large top-left title (OWNER RULE 2); no debug copy.
struct IATabsFixture: View {
    @State private var selection: RootTab = .home
    var body: some View {
        TabView(selection: $selection) {
            ForEach(RootTab.playerTabs, id: \.self) { tab in
                NavigationStack {
                    ScrollView {
                        Image(systemName: tab.playerSystemImage)
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, CYSpacing.xl)
                            .accessibilityHidden(true)
                    }
                    .cyDomainPageBackground()
                    .cyRootHeader(tab)
                }
                .tabItem { CYDomainTabLabel(tab: tab, selected: selection, domain: .player) }
                .tag(tab)
            }
        }
        .cyScreenStyle()
        .cyDomainTabBar(.player)
        .overlay { CYNightTabBar(selection: selection) }
    }
}

/// Explore toolbar with the "+" Create entry shown (capability present) or hidden (capability absent).
struct IAExploreCreateFixture: View {
    let hasPublishingSession: Bool
    @State private var showsCreate = false
    var body: some View {
        NavigationStack {
            Text(verbatim: "Synthetic fixture: Explore root")
                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(Text("tabBar.explore")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if hasPublishingSession {
                            Button("homeFeed.create", systemImage: "plus") { showsCreate = true }
                                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                                .accessibilityIdentifier("homeFeed.openCreate")
                        }
                        Button("homeFeed.more", systemImage: "ellipsis.circle") {}
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    }
                }
                .cySheet(isPresented: $showsCreate) { Group {
                    Text(verbatim: "Synthetic fixture: former Publish tab content").padding()
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
        }
        .cyDomainPageBackground()
    }
}

/// Synthetic fixture copy in the launch language (zh-Hans or en), like `tt` in the e5b fixtures.
func iaFixtureText(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}

/// Passport actions + stamp grid in its real Form section. `count == nil` is the unknown state (em dash, all locked).
struct IAPassportFixture: View {
    let count: Int?
    /// nil = unknown (em dash), [] = known none (rail hidden).
    var badges: [PassportBadge]? = nil
    /// design-r2-play: the wall total, so the rail reads "n of N" like the stamps.
    var badgeTotal: Int? = nil
    var body: some View {
        NavigationStack {
            Form {
                // mp-mine r3 (19:36 sweep): no developer placeholder line on a player screen; the identity card
                // is shown by d2-me, this fixture hosts only the passport overview.
                Section { PassportOverviewContent(stampCount: count, badges: badges, badgeTotal: badgeTotal) }
                    .listRowBackground(CYColor.bgSurface)
            }
            .scrollContentBackground(.hidden)
            .cyDomainPageBackground()
            .cyRootHeader(.mine, titleKey: "tabBar.passport")
            .cyPassportStampHost()
        }
        // mp-mine r3 (18:15 sweep): fixtures follow the system appearance (player forcedColorScheme == nil);
        // the Passport tab root carries the large top-left title (OWNER RULE 2).
        .themeDomain(.player)
    }
}

/// Every supported chein:// link and a few rejected ones, with the tab each resolves to.
struct IADeepLinksFixture: View {
    private let samples = ["chein://roam/go", "chein://ticket/42", "chein://club/7/join",
                           "chein://club/7/leave", "chein://ticket/0", "https://roam/go"]
    var body: some View {
        List {
            Section { Text(verbatim: "Synthetic fixture: CheinDeepLink parse results").cyText(.meta) }
            ForEach(samples, id: \.self) { text in
                let link = URL(string: text).flatMap(CheinDeepLink.init(url:))
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: text).cyText(.label)
                    Text(verbatim: link.map { "→ \(String(describing: $0.rootTab))" } ?? "→ rejected")
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                .accessibilityIdentifier("ia.deeplink.\(text)")
            }
        }
    }
}
#endif
