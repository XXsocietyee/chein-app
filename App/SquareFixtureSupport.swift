#if DEBUG
import SwiftUI

@MainActor final class SquareFixtureReader: SquareReading {
    enum Scenario: String { case content, empty, failure, unauthorized, unconfigured, unavailable, partial, pageFailure, invalidCursor, delayed, relatedTopic, relatedCommunity, relatedUnavailable, relatedMissing }
    let scenario: Scenario
    /// Design fixtures (`d2-square`) show posts in the UI language; UI tests keep the Core synthetic posts.
    let designLocalized: Bool
    let scope = UUID()
    var isConfigured: Bool { scenario != .unconfigured }
    var isOfflineExample: Bool { true }
    var isSignedIn: Bool { false }
    private var feedPageFailed = false
    private var commentsFailed = false
    init(scenario: Scenario = .content, designLocalized: Bool = false) {
        self.scenario = scenario
        self.designLocalized = designLocalized
    }
    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }
    /// Coordinator 19:50: fixture data follows the UI language (no mixed `A / 一` copy, no "Synthetic" labels).
    private func post(id: Int) throws -> SquarePost {
        guard designLocalized else { return try SquareSyntheticFixtures.post(id: id) }
        let walk = id == 702
            ? Self.tt("Evening lantern walk along the canal, six stops done.", "傍晚沿运河走了一圈灯笼线，六个点全部打卡。")
            : Self.tt("Morning walk through the old town lanes. Tea at the last stop was worth it.", "清晨穿过老城小巷，最后一站的茶很值得。")
        let swaps: [(String, String)] = [
            ("A synthetic city walk / 一次示例城市漫步", walk),
            ("Example walker", id == 702 ? Self.tt("Mia", "小米") : Self.tt("Leo Chen", "陈乐")),
            ("Example walking club", Self.tt("Riverside Walking Club", "河畔步行俱乐部")),
            ("Synthetic notice", Self.tt("Official", "官方")),
            ("Example guide", Self.tt("Guide", "领队")),
            ("Example city", Self.tt("Hangzhou", "杭州")),
            ("Example river route", Self.tt("Canal Lantern Route", "运河灯笼线"))
        ]
        var json = SquareSyntheticFixtures.legacyPostJSON.replacingOccurrences(of: "\"id\":701", with: "\"id\":\(id)")
        for swap in swaps { json = json.replacingOccurrences(of: swap.0, with: swap.1) }
        return try JSONDecoder().decode(SquarePost.self, from: Data(json.utf8)).qualified(as: .legacySquare)
    }
    private func check() async throws {
        if scenario == .delayed { try await Task.sleep(nanoseconds: 700_000_000) }
        switch scenario {
        case .failure: throw APIError.httpStatus(503)
        case .unauthorized: throw APIError.unauthorized
        case .unconfigured: throw APIError.notConfigured
        default: break
        }
    }
    func squareFeed(query: SquareQuery, cursor: SquareCursor?) async throws -> SquareFeedPage {
        try await check()
        if query.mode.requiresAccount { throw SquareReadFailure.signInRequired }
        if query.mode == .nearby && (query.cityCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw SquareReadFailure.cityRequired }
        if scenario == .pageFailure && cursor != nil && !feedPageFailed { feedPageFailed = true; throw APIError.httpStatus(503) }
        if scenario == .empty || query.keyword?.lowercased() == "missing" { return .init(items: [], hasMore: false) }
        if scenario == .relatedCommunity {
            return .init(items: cursor == nil ? [try relatedCommunityPost()] : [], hasMore: false)
        }
        let items = try (cursor == nil ? [701, 702] : [702, 703]).map { try post(id: $0).qualified(as: .communityV1) }
        return .init(items: items, hasMore: cursor == nil,
                     nextCursor: scenario == .invalidCursor ? nil : (cursor == nil ? SquareCursor(id: 702, score: 10) : nil))
    }
    func squareDetail(route: SquareContentRoute) async throws -> SquarePost {
        let value = try await squareDetail(id: route.id)
        return value.qualified(as: route.generation)
    }
    func squareComments(route: SquareContentRoute, pageNumber: Int) async throws -> SquareCommentPage {
        let value = try await squareComments(postID: route.id, pageNumber: pageNumber)
        return .init(items: value.items.map { $0.qualified(as: route.generation) }, pageNumber: value.pageNumber, pageSize: value.pageSize, hasMore: value.hasMore)
    }
    func squareDetail(id: Int) async throws -> SquarePost {
        try await check()
        if scenario == .unavailable { throw SquareReadFailure.server(code: 404, message: "Synthetic unavailable post / 示例内容不可用") }
        if scenario == .relatedCommunity {
            let post = try relatedCommunityPost()
            guard post.id == id else { throw SquareReadFailure.unavailable }
            return post
        }
        if scenario == .relatedMissing {
            return try JSONDecoder().decode(SquarePost.self, from: Data(#"{"id":701,"memberId":81,"contents":"Synthetic unlinked post","dataId":31,"dataType":2}"#.utf8))
        }
        return try post(id: id)
    }
    private func relatedCommunityPost() throws -> SquarePost {
        try JSONDecoder().decode(SquarePost.self, from: Data(SquareSyntheticFixtures.wrappedPostJSON.utf8)).qualified(as: .communityV1)
    }
    func squareComments(postID: Int, pageNumber: Int) async throws -> SquareCommentPage {
        try await check()
        if scenario == .partial && !commentsFailed { commentsFailed = true; throw APIError.httpStatus(503) }
        if scenario == .empty { return .init(items: [], pageNumber: pageNumber) }
        let all = try SquareSyntheticFixtures.comments()
        // Small pages are fixture-only; the real reader always sends the source pageSize 50.
        return .init(items: pageNumber == 1 ? Array(all.prefix(2)) : [all[1], all[2]], pageNumber: pageNumber, pageSize: pageNumber == 1 ? 2 : 50)
    }
}
@MainActor final class SquareRelatedTopicFixtureReader: TopicReading {
    let scope = UUID()
    let isConfigured = true
    let isOfflineExample = true
    let unavailable: Bool
    init(unavailable: Bool = false) { self.unavailable = unavailable }
    func topicList(query: TopicQuery, pageNumber: Int) async throws -> TopicPage { throw APIError.invalidRequest }
    func topicDetail(id: Int) async throws -> TopicDetail {
        if unavailable { throw TopicReadFailure.unavailable }
        let json = "{\"id\":\(id),\"name\":\"Synthetic linked topic \(id)\",\"chaptersList\":[]}"
        return try JSONDecoder().decode(TopicDetail.self, from: Data(json.utf8))
    }
}

@MainActor struct SquareFixtureHostView: View {
    @State private var reader: SquareFixtureReader
    @State private var topicReader: SquareRelatedTopicFixtureReader
    private let mediaChain: Bool
    init(scenario: SquareFixtureReader.Scenario? = nil, designLocalized: Bool = false) {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--uitesting-square-scenario")
        let value = scenario?.rawValue ?? (index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil })
        mediaChain = value == "mediaChain"
        _topicReader = State(initialValue: SquareRelatedTopicFixtureReader(unavailable: value == "relatedUnavailable"))
        _reader = State(initialValue: SquareFixtureReader(scenario: value.flatMap(SquareFixtureReader.Scenario.init(rawValue:)) ?? .content, designLocalized: designLocalized))
    }
    var body: some View {
        if mediaChain { SquarePostMediaFixtureHost() }
        else if [.relatedTopic, .relatedUnavailable, .relatedMissing].contains(reader.scenario) {
            NavigationStack {
                List {
                    NavigationLink("social.targetPost") { SquareDetailView(id: 701, reader: reader) }
                        .accessibilityIdentifier("fixture.relatedPost")
                }.cyPageTitle("square.title")
                    .toolbar { Button("social.fixtureSwitchAccount") {
                        reader = SquareFixtureReader(scenario: reader.scenario)
                        topicReader = SquareRelatedTopicFixtureReader()
                    }.accessibilityIdentifier("fixture.relatedTopic.switchAccount") }
            }
            .environment(\.squareRelatedTopic, .init(squareScope: reader.scope, reader: topicReader))
            .id(reader.scope)
        } else if reader.scenario == .relatedCommunity {
            SquareBrowserView(reader: reader)
                .environment(\.squareRelatedTopic, .init(squareScope: reader.scope, reader: topicReader))
        } else if reader.scenario == .unavailable || reader.scenario == .partial {
            NavigationStack { SquareDetailView(id: 701, reader: reader) }
        } else { SquareBrowserView(reader: reader) }
    }
}
#endif
