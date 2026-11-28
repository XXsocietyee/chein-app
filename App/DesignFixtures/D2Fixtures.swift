#if DEBUG
import SwiftUI

/// D2 (player home + discovery) design fixtures. Synthetic, clearly labelled data; they host the real views
/// through the existing module fixture hosts and apply the player (dark) role theme the way the real tabs do.
/// `--design-fixture d2-home | d2-search | d2-square | d2-roam`.
struct D2Fixture: View {
    enum Screen { case home, homeOffline, homeEmpty, homeSectionFailed, search, searchResults, searchEmpty, searchFailed, searchOffline, square, squareEmpty, roam, play, city, npc, inbox, inboxEmpty, inboxError, inboxSignedOut, inboxLoading, me }
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
        case .homeOffline: HomeFeedFixtureHostView(forceHero: true, scenario: "offline")
        // mp-home r3 (Next round item 3, MP index.wxml:246 cy-empty 暂时没有主题 / :92 cy-error 编辑精选加载失败).
        case .homeEmpty: HomeFeedFixtureHostView(forceHero: true, scenario: "empty")
        case .homeSectionFailed: HomeFeedFixtureHostView(forceHero: true, scenario: "sectionFailed")
        case .search: SearchMapFixtureHostView(showsTestControls: false)
        case .searchResults:
            NavigationStack {
                GlobalSearchView(reader: SearchMapFixtureReader(scenario: .content), recommendedKeywords: GlobalSearchRecommendedKeywords.fixtureKeywords,
                                 initialQuery: GlobalSearchQuery(keyword: SearchMapFixtureLanguage.resultsKeyword)) { _ in Color.clear }
            }
        // mp-home r3 (Next round item 3, MP search2/result wxml:23 cy-error / cy-empty): the two result states as fixtures.
        case .searchEmpty:
            NavigationStack {
                GlobalSearchView(reader: SearchMapFixtureReader(scenario: .empty), recommendedKeywords: GlobalSearchRecommendedKeywords.fixtureKeywords,
                                 initialQuery: GlobalSearchQuery(keyword: SearchMapFixtureLanguage.resultsKeyword)) { _ in Color.clear }
            }
        case .searchFailed:
            NavigationStack {
                GlobalSearchView(reader: SearchMapFixtureReader(scenario: .failure), recommendedKeywords: GlobalSearchRecommendedKeywords.fixtureKeywords,
                                 initialQuery: GlobalSearchQuery(keyword: SearchMapFixtureLanguage.resultsKeyword)) { _ in Color.clear }
            }
        case .searchOffline:
            NavigationStack {
                GlobalSearchView(reader: SearchMapFixtureReader(scenario: .unconfigured), recommendedKeywords: GlobalSearchRecommendedKeywords.fixtureKeywords) { _ in Color.clear }
            }
        case .square: SquareFixtureHostView(designLocalized: true)
        case .squareEmpty: SquareFixtureHostView(scenario: .empty, designLocalized: true)
        case .play: PlayExperienceFixtureHostView(designLocalized: true)
        case .city: CityGameFixtureHost()
        case .npc: ShopNPCFixtureView(enabled: true)
        case .inbox:
            NavigationStack {
                MessagingHomeView(reader: MessagingFixtureReader(.success), expanded: nil, squareDestination: { _ in AnyView(EmptyView()) })
            }
        case .inboxEmpty:
            NavigationStack {
                MessagingHomeView(reader: MessagingFixtureReader(.empty), expanded: nil, squareDestination: { _ in AnyView(EmptyView()) })
            }
        case .inboxError: D2InboxStateFixture(scenario: .error)
        case .inboxSignedOut: D2InboxStateFixture(scenario: .unauthorized)
        case .inboxLoading: D2InboxStateFixture(scenario: .loading)
        case .me: D2MeFixture()
        case .roam: RoamHomeFixtureHostView()
        }
    }
}

/// mp-nav r3 "Next round" item 3: the 消息 inbox (MP subpackageB/pages/im/list) in its other MP states, so the sweep
/// shows them: cy-error 加载失败 + 重试, cy-empty no-permission 登录后查看消息 + 登录, and the first-load spinner.
struct D2InboxStateFixture: View {
    let scenario: MessagingFixtureScenario
    var body: some View {
        NavigationStack {
            MessagingHomeView(reader: MessagingFixtureReader(scenario), expanded: nil, squareDestination: { _ in AnyView(EmptyView()) })
        }
    }
}

/// design-r2-play: the signed-in 我的 header. A bare `AppSession()` is signed out, which painted the signed-out line and
/// dash counters under the name "Mia"; the fixture readers are signed in, so name, counters and 积分 are real values.
/// mp-mine r3 (14:13 visual check): the same MP structure as `AccountView` — identity card → 好友/关注/粉丝 →
/// [开始探索][票夹][···] → tabs 项目 · 帖文 · 成就 · 关于 (the fixture is community-readable, as the MP normally is).
/// `-d2MeTab posts|achievements|about` opens a tab.
@MainActor struct D2MeFixture: View {
    @State private var member = MemberHomeFixtureReader(scenario: "ready")
    @State private var growth = GrowthCenterFixtureReader(scenario: .content)
    @State private var tab: AccountMineTab
    @Environment(\.locale) private var locale
    private let account = try! JSONDecoder().decode(Account.self, from: Data(#"{"id":81,"nickname":"Mia","role":"player","levelId":2}"#.utf8))
    private let tabs: [AccountMineTab] = AccountMineTab.allCases
    /// `initialTab` lets a fixture open on one MP tab (e4-member opens 关于, where 当前权益 lives).
    init(initialTab: AccountMineTab? = nil) {
        let stored = AccountMineTab(rawValue: UserDefaults.standard.string(forKey: "d2MeTab") ?? "")
        _tab = State(initialValue: initialTab ?? stored ?? .mine)
    }
    var body: some View {
        NavigationStack {
            Form {
                MemberIdentityCardSection(account: account, reader: member, growth: growth, onOpenTickets: {},
                                          onEditProfile: {}, showsMetrics: false, onStartExplore: {},
                                          moreMenu: AnyView(Group {
                                              Button {} label: { Label("social.profile", systemImage: "person.crop.rectangle") }
                                              Button {} label: { Label("profile.edit.title", systemImage: "pencil") }
                                          }))
                Section {
                    Picker(selection: $tab) {
                        ForEach(tabs, id: \.self) { item in Text(item.titleKey).tag(item) }
                    } label: { Text("social.profileSection") }
                        .cyAdaptiveSegmented()
                        .accessibilityIdentifier("account.mine.tabs")
                        .sensoryFeedback(.selection, trigger: tab)
                }
                switch tab {
                case .posts:
                    // MP cy-profile TAB · 推文: `cy-empty title="还没有帖文"` when the member has no posts.
                    Section {
                        ContentUnavailableView {
                            Label { Text("club.tab.feed.empty") } icon: { Image(systemName: "text.bubble") }
                        }
                        .accessibilityIdentifier("account.mine.posts.empty")
                    }
                case .mine:
                    // mp-mine r3: MP TAB · 项目 for a player with no orders / projects / bounties:
                    // 我的项目 (header + 管理全部, no preview) → 我的资产 (账户余额) → 通行证与礼品, as AccountView draws on Passport.
                    Section("profile.selfProjects.title") {
                        Button {} label: { Label("profile.selfProjects.all", systemImage: "square.stack") }
                            .accessibilityIdentifier("profile.selfProjects.all")
                    }
                    Section("wallet.assets") {
                        LabeledContent {
                            Text(verbatim: MemberBalanceDisplay.text("0", locale: locale)).monospacedDigit()
                        } label: {
                            Label { Text("member.card.balance", tableName: "MemberProfile") } icon: { Image(systemName: "wallet.pass") }
                        }
                        Button {} label: {
                            CYListRow("mp.account.passes", trailing: .none) { CYRowIcon(systemImage: "ticket") }
                        }
                        .accessibilityIdentifier("account.mp.passes")
                    }
                case .achievements:
                    MemberAchievementMetricsSection(growth: growth, onOpenPoints: {}, onOpenPointsHelp: {}) {
                        Label("growth.title", systemImage: "chart.bar.xaxis")
                    }
                case .about:
                    MemberBenefitsSection(reader: member)
                }
            }
            .cyRootHeader(.mine)
        }
    }
}
#endif
