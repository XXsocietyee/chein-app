#if DEBUG
import SwiftUI

@MainActor final class SquareFixtureReader: SquareReading, SquareOfflineNoteHiding {
    enum Scenario: String { case content, empty, failure, unauthorized, unconfigured, unavailable, partial, pageFailure, invalidCursor, delayed, relatedTopic, relatedCommunity, relatedUnavailable, relatedMissing }
    let scenario: Scenario
    /// Design fixtures (`d2-square`) show posts in the UI language; UI tests keep the Core synthetic posts.
    let designLocalized: Bool
    let scope = UUID()
    var isConfigured: Bool { scenario != .unconfigured }
    var isOfflineExample: Bool { true }
    var hidesOfflineExampleNote: Bool { designLocalized }
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
    /// One varied author per fixture post (P2 13:15 sweep: no repeated avatar / date / text).
    private struct DesignPost {
        let author: String, club: String, badge: String, text: String, memoji: Int, minutesAgo: Int, likes: Int, comments: Int
    }
    private static func designPost(id: Int) -> DesignPost {
        switch id {
        case 702: return DesignPost(author: tt("Mia", "小米"), club: tt("Canal Night Walkers", "运河夜行社"), badge: tt("Guide", "领队"),
                                    text: tt("Evening lantern walk along the canal, six stops done.", "傍晚沿运河走了一圈灯笼线，六个点全部打卡。"),
                                    memoji: 2, minutesAgo: 190, likes: 34, comments: 8)
        case 703: return DesignPost(author: tt("Nina Zhou", "周宁"), club: tt("West Lake Runners", "西湖跑团"), badge: tt("Member", "成员"),
                                    text: tt("First city orienteering run with the team. We found the hidden gate on the third try!", "第一次和队友跑城市定向，第三次才找到那扇暗门！"),
                                    memoji: 3, minutesAgo: 2 * 24 * 60 + 40, likes: 7, comments: 2)
        default: return DesignPost(author: tt("Leo Chen", "陈乐"), club: tt("Riverside Walking Club", "河畔步行俱乐部"), badge: tt("Official", "官方"),
                                   text: tt("Morning walk through the old town lanes. Tea at the last stop was worth it.", "清晨穿过老城小巷，最后一站的茶很值得。"),
                                   memoji: 1, minutesAgo: 25, likes: 12, comments: 3)
        }
    }
    /// Coordinator 19:50: fixture data follows the UI language (no mixed `A / 一` copy, no "Synthetic" labels).
    private func post(id: Int) throws -> SquarePost {
        guard designLocalized else { return try SquareSyntheticFixtures.post(id: id) }
        let design = Self.designPost(id: id)
        let createdMillis = Int64((Date().timeIntervalSince1970 - Double(design.minutesAgo * 60)) * 1000)
        let swaps: [(String, String)] = [
            ("A synthetic city walk / 一次示例城市漫步", design.text),
            ("Example walker", design.author),
            ("Example walking club", design.club),
            ("Synthetic notice", design.badge),
            ("Example guide", design.badge),
            ("Example city", Self.tt("Hangzhou", "杭州")),
            ("Example river route", Self.tt("Canal Lantern Route", "运河灯笼线")),
            ("\"createTime\":\"2026-01-01 10:00\"", "\"createTime\":\"\(createdMillis)\",\"memberAvatar\":\"\(SquareAuthorAvatar.fixtureMemojiPrefix)\(design.memoji)\""),
            ("\"memberId\":81", "\"memberId\":\(80 + design.memoji)"),
            ("\"likeNum\":12", "\"likeNum\":\(design.likes)"),
            ("\"commentCount\":3", "\"commentCount\":\(scenario == .empty ? 0 : design.comments)")
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
        if scenario == .unavailable {
            // Design fixtures show the MP 这条帖文暂不可用 shell in the UI language, never the synthetic server text.
            if designLocalized { throw SquareReadFailure.unavailable }
            throw SquareReadFailure.server(code: 404, message: "Synthetic unavailable post / 示例内容不可用")
        }
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
    /// `d2-square-detail`: a root comment, a reply to it and a second root, in the UI language with recent times.
    private static func designComments() throws -> [SquareComment] {
        let now = Date().timeIntervalSince1970
        func millis(_ minutesAgo: Int) -> String { String(Int64((now - Double(minutesAgo * 60)) * 1000)) }
        let rows: [[String: Any]] = [
            ["id": 801, "memberId": 82, "memberAvatar": SquareAuthorAvatar.fixtureMemojiPrefix + "2", "contents": tt("Which teahouse was it? Saving this route for Saturday.", "最后一站是哪家茶馆？周六也想走这条线。"),
             "memberNickname": tt("Mia", "小米"), "likeCount": 4, "createTime": millis(18)],
            ["id": 802, "memberId": 81, "memberAvatar": SquareAuthorAvatar.fixtureMemojiPrefix + "1", "contents": tt("The one by the old bridge, ask for the osmanthus tea.", "老桥边那家，点桂花茶。"),
             "memberNickname": tt("Leo Chen", "陈乐"), "likeCount": 1, "createTime": millis(12),
             "rootId": 801, "parentId": 801, "repliedToMemberId": 82],
            ["id": 803, "memberId": 83, "memberAvatar": SquareAuthorAvatar.fixtureMemojiPrefix + "3", "contents": tt("Great photos. Did the lanes get crowded later?", "照片很好看！后面巷子人多吗？"),
             "memberNickname": tt("Nina Zhou", "周宁"), "likeCount": 0, "createTime": millis(6)]
        ]
        let data = try JSONSerialization.data(withJSONObject: rows)
        return try JSONDecoder().decode([SquareComment].self, from: data).map { $0.qualified(as: .legacySquare) }
    }
    private func relatedCommunityPost() throws -> SquarePost {
        try JSONDecoder().decode(SquarePost.self, from: Data(SquareSyntheticFixtures.wrappedPostJSON.utf8)).qualified(as: .communityV1)
    }
    func squareComments(postID: Int, pageNumber: Int) async throws -> SquareCommentPage {
        try await check()
        if scenario == .partial && !commentsFailed { commentsFailed = true; throw APIError.httpStatus(503) }
        if scenario == .empty { return .init(items: [], pageNumber: pageNumber) }
        let all = try designLocalized ? Self.designComments() : SquareSyntheticFixtures.comments()
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
