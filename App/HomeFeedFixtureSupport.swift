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
        let titles = ["Night market after rain", "Old Town: ten hidden spots", "Riverside lantern walk"]
        return try (1...3).map { index in
            let json = "{\"id\":\(index),\"picUrl\":null,\"linkType\":0,\"dataId\":null,\"contents\":\"\(titles[index - 1])\"}"
            return try JSONDecoder().decode(DiscoveryBanner.self, from: Data(json.utf8))
        }
    }
    func categories() async throws -> [DiscoveryCategory] {
        try JSONDecoder().decode([DiscoveryCategory].self, from: Data(#"[{"id":2,"categoryName":"Sample category"}]"#.utf8))
    }
    func section(_ section: HomeFeedSection) async throws -> [HomeFeedItem] {
        if scenario == "empty" { return [] }
        return try section == .recommended ? [HomeFeedSyntheticFixtures.topic()] : [HomeFeedSyntheticFixtures.activity()]
    }
    func page(query: HomeFeedQuery, number: Int) async throws -> HomeFeedPage {
        if scenario == "retry", !failedOnce { failedOnce = true; throw APIError.httpStatus(503) }
        if scenario == "empty" || number > 1 || (!query.keyword.isEmpty && !"sample".contains(query.keyword.lowercased())) {
            return HomeFeedPage(items: [], number: number, size: query.pageSize)
        }
        let item = try query.kind == .topics ? HomeFeedSyntheticFixtures.topic() : HomeFeedSyntheticFixtures.activity()
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
    /// `--design-today ticket|club|activity` seeds the Today card (`activity`: a club event that opens the activity detail); anything else shows the start-a-roam prompt.
    private let todayState: String?
    /// Design fixture override. Nil keeps the UI-test argument.
    private let unavailableKey: String?
    init(forceHero: Bool = false, scenario: String? = nil, unavailableMessageKey: String? = nil) {
        let todayIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "--design-today")
        todayState = todayIndex.flatMap { ProcessInfo.processInfo.arguments.indices.contains($0 + 1) ? ProcessInfo.processInfo.arguments[$0 + 1] : nil }
        continuity = forceHero
        hero = forceHero || ProcessInfo.processInfo.arguments.contains("--design-hero")
        unavailableKey = unavailableMessageKey
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-home-feed-scenario")
        let chosen = scenario ?? (index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "content")
        _reader = State(initialValue: HomeFeedFixtureReader(scenario: chosen, showsBanners: forceHero && unavailableMessageKey == nil))
    }
    var body: some View {
        NavigationStack(path: $path) {
            HomeFeedView(reader: reader, unavailableMessageKey: unavailableKey, viewerNickname: hero ? "Mia" : nil,
                         selectedCity: hero ? "上海" : nil,
                         showsHeroBanners: hero,
                         continuationCards: hero ? [.init(id: "fx-continue", kind: .continueExploration, destination: .topic(7), title: "Old Town: ten hidden spots", subtitle: "Stop 4 of 10 · 18 min in")] : [],
                         onActionBanner: hero ? { _ in } : nil,
                         todayTicket: todayState == "ticket" ? HomeTodayFixtures.ticket : nil,
                         todayClubEvent: todayState == "club" ? HomeTodayFixtures.clubEvent : (todayState == "activity" ? HomeTodayFixtures.activityEvent : nil),
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

/// Design fixtures for the three Today states (and an unknown-time ticket that must fall back to roam).
enum HomeTodayFixtures {
    static var now: Date { Date() }
    static var ticket: HomeTodayCandidate { HomeTodayCandidate(id: "fx-ticket", title: "Riverside lantern walk", start: now.addingTimeInterval(5 * 3600), place: "West Bund", imageURL: nil) }
    static var clubEvent: HomeTodayCandidate { HomeTodayCandidate(id: "fx-club", title: "Old Town photo walk", start: now.addingTimeInterval(0), place: "Old Town", imageURL: nil) }
    /// A club event that is a real activity (id 7 matches the synthetic feed activity): the Today card zooms into its detail.
    static var activityEvent: HomeTodayCandidate { HomeTodayCandidate(id: "fx-club", title: "Sample riverside walk", start: now.addingTimeInterval(0), place: "Sample meeting point", imageURL: nil, activityID: 7) }
    static var unknownTime: HomeTodayCandidate { HomeTodayCandidate(id: "fx-unknown", title: "Mystery ticket", start: nil, place: nil, imageURL: nil) }
}

#endif
