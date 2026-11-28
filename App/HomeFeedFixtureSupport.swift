#if DEBUG
import SwiftUI

@MainActor final class HomeFeedFixtureReader: HomeFeedReading {
    let isConfigured = true
    let isOfflineExample = true
    let scope = UUID()
    let scenario: String
    private var failedOnce = false
    let showsBanners: Bool
    init(scenario: String = "content", showsBanners: Bool = false) { self.scenario = scenario; self.showsBanners = showsBanners }
    /// Design fixture only: three synthetic banners without a cover (the pager shows the MP default cover).
    func banners() async throws -> [DiscoveryBanner] {
        guard showsBanners else { return [] }
        let titles = HomeFixtureLanguage.zh ? ["雨后夜市", "老城：十个隐藏角落", "滨江灯笼漫步"]
            : ["Night market after rain", "Old Town: ten hidden spots", "Riverside lantern walk"]
        return try (1...3).map { index in
            let json = "{\"id\":\(index),\"picUrl\":null,\"linkType\":0,\"dataId\":null,\"contents\":\"\(titles[index - 1])\"}"
            return try JSONDecoder().decode(DiscoveryBanner.self, from: Data(json.utf8))
        }
    }
    func categories() async throws -> [DiscoveryCategory] {
        if scenario == "offline" { throw URLError(.notConnectedToInternet) }
        return try JSONDecoder().decode([DiscoveryCategory].self, from: Data("[{\"id\":2,\"categoryName\":\"\(HomeFixtureLanguage.zh ? "示例分类" : "Sample category")\"}]".utf8))
    }
    func section(_ section: HomeFeedSection) async throws -> [HomeFeedItem] {
        if scenario == "empty" { return [] }
        if scenario == "offline" { throw URLError(.notConnectedToInternet) }
        // mp-home r3 (all states): MP index.wxml:92 cy-error 编辑精选加载失败 + 重试 while the other rails load.
        if scenario == "sectionFailed", section == .recommended { throw APIError.httpStatus(503) }
        return try section == .recommended ? [HomeFixtureLanguage.topic()] : [HomeFixtureLanguage.activity()]
    }
    func page(query: HomeFeedQuery, number: Int) async throws -> HomeFeedPage {
        if scenario == "offline" { throw URLError(.notConnectedToInternet) }
        if scenario == "retry", !failedOnce { failedOnce = true; throw APIError.httpStatus(503) }
        if scenario == "offline" { throw URLError(.notConnectedToInternet) }
        if scenario == "empty" || number > 1 || (!query.keyword.isEmpty && !"sample".contains(query.keyword.lowercased())) {
            return HomeFeedPage(items: [], number: number, size: query.pageSize)
        }
        let item = try query.kind == .topics ? HomeFixtureLanguage.topic() : HomeFixtureLanguage.activity()
        // Full raw page of duplicate IDs verifies dedup does not disable next-page probing.
        return HomeFeedPage(items: Array(repeating: item, count: query.pageSize), number: number, size: query.pageSize)
    }
}

/// Integrator routes module fixture `home-feed` here. Real detail views belong to app composition.
@MainActor struct HomeFeedFixtureHostView: View {
    @State private var reader: HomeFeedFixtureReader
    @State private var path: [HomeFeedDestination] = []
    /// Same wiring as `SessionHomeFeedView`: feed cards are zoom sources, the pushed detail is the destination.
    @Namespace private var heroNamespace
    @State private var activityReader = ActivityFixtureReader(scenario: .reviews)
    private let hero: Bool
    /// `d2-home` only: the continuity lab (zoom into a real activity detail). The module fixture `home-feed` keeps its plain text destinations.
    private let continuity: Bool
    /// Design fixture override. Nil keeps the UI-test argument.
    private let unavailableKey: String?
    init(forceHero: Bool = false, scenario: String? = nil, unavailableMessageKey: String? = nil) {
        continuity = forceHero
        hero = forceHero || ProcessInfo.processInfo.arguments.contains("--design-hero")
        unavailableKey = unavailableMessageKey
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-home-feed-scenario")
        let chosen = scenario ?? (index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "content")
        _reader = State(initialValue: HomeFeedFixtureReader(scenario: chosen))
    }
    var body: some View {
        NavigationStack(path: $path) {
            HomeFeedView(reader: reader, unavailableMessageKey: unavailableKey, viewerNickname: hero ? "Mia" : nil,
                         selectedCity: hero ? "上海" : nil,
                         showsHeroBanners: hero,
                         // mp-home r3: exactly the MP 首页 content — no continuation, Today or `/banner` seeding.
                         continuationCards: [],
                         onActionBanner: hero ? { _ in } : nil,
                         todayTicket: nil,
                         todayClubEvent: nil,
                         onOpenTodayTicket: {}, onOpenTodayClubEvent: {}, onStartRoam: {},
                         onOpenUnifiedSearch: hero ? { _ in } : nil) { path.append($0) }
                .modifier(HomeFeedFixtureHero(namespace: heroNamespace, enabled: continuity))
                .navigationDestination(for: HomeFeedDestination.self) { destination in
                    switch destination {
                    case .activity(let id):
                        if continuity {
                            // Every synthetic activity opens the one fixture activity (id 101) so the hero lands on a real detail.
                            ActivityDetailView(id: 101, reader: activityReader, registrationEnabled: true)
                                .cyHeroDestinationWithFallback(destination, in: heroNamespace)
                        } else {
                            Text(verbatim: "Synthetic activity destination \(id)").accessibilityIdentifier("homeFeed.destination.activity")
                        }
                    case .topic(let id):
                        Text(verbatim: "Synthetic topic destination \(id)").accessibilityIdentifier("homeFeed.destination.topic")
                    }
                }
        }
    }
}

private struct HomeFeedFixtureHero: ViewModifier {
    let namespace: Namespace.ID
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.cyHeroNamespace(namespace) } else { content }
    }
}

/// mp-home r3 (19:50 sweep): 首页 fixture data follows the UI language (zh-Hans gets Chinese names).
enum HomeFixtureLanguage {
    static var zh: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }
    /// mp-home r3 (23:07 sweep): `--design-fixture` shots show real names, not 示例… / Sample… placeholders;
    /// UI-test runs keep the synthetic values.
    static var isDesignFixture: Bool { ProcessInfo.processInfo.arguments.contains("--design-fixture") }
    static func topic() throws -> HomeFeedItem {
        let names: (String, String)
        if zh {
            names = isDesignFixture ? ("老城灯笼夜行", "老城") : ("示例街区路线", "示例街区")
        } else {
            guard isDesignFixture else { return try HomeFeedSyntheticFixtures.topic() }
            names = ("Old Town Lantern Walk", "Old Town")
        }
        let json = HomeFeedSyntheticFixtures.topicJSON
            .replacingOccurrences(of: "Sample neighborhood route", with: names.0)
            .replacingOccurrences(of: "Sample district", with: names.1)
        return .topic(try JSONDecoder().decode(TopicSummary.self, from: Data(json.utf8)))
    }
    static func activity() throws -> HomeFeedItem {
        let names: (String, String)
        if zh {
            names = isDesignFixture ? ("滨江灯笼漫步", "西岸码头") : ("示例滨江漫步", "示例集合点")
        } else {
            guard isDesignFixture else { return try HomeFeedSyntheticFixtures.activity() }
            names = ("Riverside Lantern Walk", "West Bund Pier")
        }
        let json = HomeFeedSyntheticFixtures.activityJSON
            .replacingOccurrences(of: "Sample riverside walk", with: names.0)
            .replacingOccurrences(of: "Sample meeting point", with: names.1)
        return .activity(try JSONDecoder().decode(ActivitySummary.self, from: Data(json.utf8)))
    }
}

/// Design fixtures for the three Today states (and an unknown-time ticket that must fall back to roam).
enum HomeTodayFixtures {
    static var now: Date { Date() }
    static var ticket: HomeTodayCandidate {
        HomeTodayCandidate(id: "fx-ticket", title: HomeFixtureLanguage.zh ? "滨江灯笼漫步" : "Riverside lantern walk", start: now.addingTimeInterval(5 * 3600),
                           place: HomeFixtureLanguage.zh ? "西岸" : "West Bund", imageURL: nil)
    }
    static var clubEvent: HomeTodayCandidate {
        HomeTodayCandidate(id: "fx-club", title: HomeFixtureLanguage.zh ? "老城摄影漫步" : "Old Town photo walk", start: now.addingTimeInterval(0),
                           place: HomeFixtureLanguage.zh ? "老城" : "Old Town", imageURL: nil)
    }
    static var unknownTime: HomeTodayCandidate { HomeTodayCandidate(id: "fx-unknown", title: "Mystery ticket", start: nil, place: nil, imageURL: nil) }
}

#endif
