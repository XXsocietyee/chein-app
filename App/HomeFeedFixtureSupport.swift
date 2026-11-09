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
    /// Design fixture only: three synthetic banners without a cover (the kit pager draws brand gradients).
    func banners() async throws -> [DiscoveryBanner] {
        guard showsBanners else { return [] }
        return try (1...3).map { try JSONDecoder().decode(DiscoveryBanner.self, from: Data(#"{"id":\#($0),"picUrl":null,"linkType":0,"dataId":null,"contents":null}"#.utf8)) }
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
    private let hero: Bool
    init(forceHero: Bool = false) {
        hero = forceHero || ProcessInfo.processInfo.arguments.contains("--design-hero")
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-home-feed-scenario")
        _reader = State(initialValue: HomeFeedFixtureReader(scenario: index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "content", showsBanners: forceHero))
    }
    var body: some View {
        NavigationStack(path: $path) {
            HomeFeedView(reader: reader, viewerNickname: hero ? "Mia" : nil,
                         selectedCity: hero ? "Shanghai" : nil,
                         showsHeroBanners: hero,
                         continuationCards: hero ? [.init(id: "fx-continue", kind: .continueExploration, destination: .topic(7), title: "Old Town: ten hidden spots", subtitle: "Stop 4 of 10 · 18 min in")] : [],
                         onActionBanner: hero ? { _ in } : nil,
                         onOpenUnifiedSearch: hero ? { _ in } : nil) { path.append($0) }
                .navigationDestination(for: HomeFeedDestination.self) { destination in
                    switch destination {
                    case .activity(let id): Text(verbatim: "Synthetic activity destination \(id)").accessibilityIdentifier("homeFeed.destination.activity")
                    case .topic(let id): Text(verbatim: "Synthetic topic destination \(id)").accessibilityIdentifier("homeFeed.destination.topic")
                    }
                }
        }
    }
}

#endif
