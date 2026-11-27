#if DEBUG
import SwiftUI

/// Four-tab IA fixtures (W1-1 / W1-4 / W3-6). Synthetic and clearly labelled; never shipped in Release.
/// Names: ia-tabs, ia-explore-create, ia-passport, ia-passport-unknown, ia-passport-ax5, ia-deeplinks.

/// The real player bar chrome over four placeholder roots: Explore, Roam, Clubs, Passport (no Publish).
struct IATabsFixture: View {
    @State private var selection: RootTab = .home
    var body: some View {
        TabView(selection: $selection) {
            ForEach(RootTab.playerTabs, id: \.self) { tab in
                NavigationStack {
                    VStack(spacing: CYSpacing.md) {
                        Image(systemName: tab.playerSystemImage).accessibilityHidden(true).font(.largeTitle)
                        Text(LocalizedStringKey(tab.playerTitleKey)).cyText(.pageTitle)
                        Text(verbatim: "Synthetic fixture").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cyDomainPageBackground()
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
                Section {
                    Text(verbatim: "Synthetic fixture: identity card goes here (MemberIdentityCardSection)")
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                Section { PassportOverviewContent(stampCount: count, badges: badges, badgeTotal: badgeTotal) }
                    .listRowBackground(CYColor.bgSurface)
            }
            .scrollContentBackground(.hidden)
            .cyDomainPageBackground()
            .navigationTitle(Text("tabBar.passport")).navigationBarTitleDisplayMode(.inline)
            .cyPassportStampHost()
        }
        // Player domain is dark: the real app sets this through roleTheme(.player); without it the preview renders light.
        .themeDomain(.player)
        .preferredColorScheme(.dark)
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
