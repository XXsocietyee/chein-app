import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class TemplateIndexPageModelTests: XCTestCase {
    func testUnknownCountIsAnEmDashAndZeroStaysZero() {
        XCTAssertEqual(TemplateIndexCount.unknownDisplay, "—")
        XCTAssertEqual(TemplateIndexCount(nonnegative: nil).text, "—")
        XCTAssertEqual(TemplateIndexCount(nonnegative: -1).text, "—")
        XCTAssertEqual(TemplateIndexCount(nonnegative: 0).text, "0")
        XCTAssertEqual(TemplateIndexCount(nonnegative: 4).text, "4")
        XCTAssertNotEqual(TemplateIndexCount(nonnegative: nil).text, "0")
    }

    func testMissingChapterIsUnknownWhileLiteralZeroStaysZero() throws {
        let missing = try decode(DiscoveryTopicTemplate.self, TemplateIndexFixtureData.topicMissingCounts)
        XCTAssertEqual(missing.chapterCount, 0)
        XCTAssertFalse(missing.chapterCountIncluded)
        let missingFacts = TemplateIndexPageModel.topicFacts(missing)
        XCTAssertEqual(missingFacts.chapterText, "—")
        XCTAssertEqual(missingFacts.stopsText, "—")
        XCTAssertEqual(missingFacts.secondsText, "—")
        XCTAssertEqual(missingFacts.chapterAccessibilityIdentifier, "pages.template.index.chapter.801")

        let nulls = try decode(DiscoveryTopicTemplate.self, TemplateIndexFixtureData.topicNullCounts)
        XCTAssertFalse(nulls.chapterCountIncluded)
        XCTAssertEqual(TemplateIndexPageModel.topicFacts(nulls).chapterText, "—")

        let zero = try decode(DiscoveryTopicTemplate.self, TemplateIndexFixtureData.topicKnownZero)
        XCTAssertTrue(zero.chapterCountIncluded)
        XCTAssertEqual(zero.chapterCount, 0)
        XCTAssertEqual(zero.locationCount, 0)
        XCTAssertEqual(zero.totalTime, 0)
        let zeroFacts = TemplateIndexPageModel.topicFacts(zero)
        XCTAssertEqual(zeroFacts.chapterText, "0")
        XCTAssertEqual(zeroFacts.stopsText, "0")
        XCTAssertEqual(zeroFacts.secondsText, "0")

        let known = try decode(DiscoveryTopicTemplate.self, TemplateIndexFixtureData.topicKnown)
        XCTAssertEqual(TemplateIndexPageModel.topicFacts(known).chapterText, "2")
        XCTAssertEqual(TemplateIndexPageModel.topicFacts(known).stopsText, "4")
        XCTAssertEqual(TemplateIndexPageModel.topicFacts(known).secondsText, "90")

        let negative = try decode(DiscoveryTopicTemplate.self, TemplateIndexFixtureData.topicNegativeChapter)
        XCTAssertEqual(negative.chapterCount, -1)
        XCTAssertTrue(negative.chapterCountIncluded)
        XCTAssertEqual(TemplateIndexPageModel.topicFacts(negative).chapterText, "—")
    }

    func testPlayUseAndPlayersDoNotGuessZero() throws {
        let missing = try decode(DiscoveryPlayTemplate.self, TemplateIndexFixtureData.playMissingUse)
        XCTAssertNil(missing.useNum)
        XCTAssertEqual(TemplateIndexPageModel.playFacts(missing).useText, "—")
        XCTAssertEqual(TemplateIndexPageModel.playFacts(missing).playersText, "—")
        XCTAssertEqual(TemplateIndexPageModel.playFacts(missing).useAccessibilityIdentifier, "pages.template.index.use.701")

        let zero = try decode(DiscoveryPlayTemplate.self, TemplateIndexFixtureData.playKnownZeroUse)
        XCTAssertEqual(TemplateIndexPageModel.playFacts(zero).useText, "0")
        XCTAssertEqual(TemplateIndexPageModel.playFacts(zero).playersText, "—")

        let known = try decode(DiscoveryPlayTemplate.self, TemplateIndexFixtureData.playKnownUse)
        XCTAssertEqual(TemplateIndexPageModel.playFacts(known).useText, "3")
        XCTAssertEqual(TemplateIndexPageModel.playFacts(known).playersText, "2-4")
    }

    func testPhasesKeepUnknownDistinctFromEmptyAndError() {
        let first = TemplateIndexPageModel.beginLoad(.initial)
        XCTAssertEqual(first.phase, .loading)
        XCTAssertEqual(first.phase.localizationKey, "pages.template.index.loading")
        XCTAssertEqual(first.phase.accessibilityIdentifier, "pages.template.index.loading")
        XCTAssertFalse(first.showsSyncing)
        XCTAssertEqual(first.rowCountText, "—")
        XCTAssertEqual(first.homeTotalText, "—")

        let failed = TemplateIndexPageModel.fail(first)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertTrue(failed.showsError)
        XCTAssertEqual(failed.rowCountText, "—")
        XCTAssertEqual(failed.homeTotalText, "—")
        XCTAssertNotEqual(failed.rowCountText, "0")

        let empty = TemplateIndexPageModel.succeed(loadedRows: 0, homeTotal: .read(nil), showsHomeError: false, state: first)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.rowCountText, "0")
        XCTAssertEqual(empty.homeTotalText, "—")

        let knownZero = TemplateIndexPageModel.succeed(loadedRows: 0, homeTotal: .read(0), showsHomeError: false, state: first)
        XCTAssertEqual(knownZero.homeTotalText, "0")

        let negativeTotal = TemplateIndexPageModel.succeed(loadedRows: 1, homeTotal: .read(-3), showsHomeError: false, state: first)
        XCTAssertEqual(negativeTotal.phase, .ready)
        XCTAssertEqual(negativeTotal.rowCountText, "1")
        XCTAssertEqual(negativeTotal.homeTotalText, "—")

        let refreshing = TemplateIndexPageModel.beginLoad(knownZero)
        XCTAssertTrue(refreshing.showsSyncing)
        XCTAssertEqual(refreshing.phase, .empty)
        XCTAssertEqual(refreshing.rowCountText, "0")
        let kept = TemplateIndexPageModel.fail(refreshing)
        XCTAssertEqual(kept.phase, .empty)
        XCTAssertTrue(kept.showsError)
        XCTAssertEqual(kept.rowCountText, "0")
        XCTAssertEqual(kept.homeTotalText, "0")

        let unread = TemplateIndexPageModel.succeed(loadedRows: 2, homeTotal: .notRead, showsHomeError: true, state: knownZero)
        XCTAssertEqual(unread.homeTotalText, "0")
        XCTAssertTrue(unread.showsHomeError)
        XCTAssertEqual(unread.phase, .ready)
    }

    @MainActor func testHiddenCapabilityStaysHiddenAndFlagsStayOff() {
        let hidden = coordinator(capability: nil, scope: .consumer)
        XCTAssertTrue(hidden.publishActionsHidden)
        XCTAssertTrue(hidden.topicTemplateUseHidden)
        XCTAssertEqual(hidden.publishQuotaText, "—")
        XCTAssertFalse(hidden.showsMerchantChoice)
        XCTAssertFalse(hidden.paymentEnabled)
        XCTAssertFalse(hidden.payoutEnabled)
        XCTAssertFalse(hidden.withdrawalEnabled)
        XCTAssertFalse(hidden.virtualGoodsEnabled)

        let staff = coordinator(capability: playerCapability(remaining: 3), scope: .merchant(canManageProjects: false))
        XCTAssertTrue(staff.publishActionsHidden)
        XCTAssertEqual(staff.publishQuotaText, "—")

        let open = coordinator(capability: playerCapability(remaining: nil), scope: .consumer)
        XCTAssertFalse(open.publishActionsHidden)
        XCTAssertEqual(open.publishQuotaText, "—")
        XCTAssertFalse(open.paymentEnabled)

        let zero = coordinator(capability: playerCapability(remaining: 0), scope: .consumer)
        XCTAssertEqual(zero.publishQuotaText, "0")
        XCTAssertFalse(zero.showsMerchantChoice)
        XCTAssertFalse(zero.virtualGoodsEnabled)
    }

    @MainActor func testCoordinatorLoadsExistingReadsAndKeepsUnknownDistinct() async throws {
        let transport = TemplateIndexScriptTransport()
        transport.topics = envelope("[]")
        transport.home = envelope(TemplateIndexFixtureData.homeMissingTotal)
        let model = try coordinator(transport)
        await model.loadTopicsShelf()
        XCTAssertEqual(model.state.phase, .empty)
        XCTAssertEqual(model.state.rowCountText, "0")
        XCTAssertEqual(model.state.homeTotalText, "—")
        XCTAssertTrue(transport.paths.contains { $0.hasSuffix("/api/template/topic-template/list") })
        XCTAssertTrue(transport.paths.contains { $0.hasSuffix("/api/template/homeData") })
        XCTAssertFalse(transport.paths.contains { $0.contains("topic-template/use") })

        transport.paths.removeAll()
        transport.topics = envelope("[\(TemplateIndexFixtureData.topicMissingCounts)]")
        transport.home = envelope(TemplateIndexFixtureData.homeKnownTotal)
        await model.loadTopicsShelf()
        XCTAssertEqual(model.state.phase, .ready)
        XCTAssertEqual(model.state.rowCountText, "1")
        XCTAssertEqual(model.state.homeTotalText, "2")
        XCTAssertEqual(model.topicFacts.map(\.chapterText), ["—"])
        XCTAssertEqual(model.topicFacts.map(\.stopsText), ["—"])

        transport.paths.removeAll()
        transport.topicsStatus = 200
        transport.topics = #"{"code":500,"msg":"nope"}"#
        transport.home = envelope(TemplateIndexFixtureData.homeKnownZeroTotal)
        await model.loadTopicsShelf()
        XCTAssertEqual(model.state.phase, .ready)
        XCTAssertTrue(model.state.showsError)
        XCTAssertEqual(model.state.rowCountText, "1")
        XCTAssertEqual(model.state.homeTotalText, "0")
        XCTAssertEqual(model.topicFacts.map(\.id), [801])

        transport.paths.removeAll()
        let fresh = try coordinator(transport)
        transport.topics = #"{"code":500}"#
        transport.home = #"{"code":500}"#
        await fresh.loadTopicsShelf()
        XCTAssertEqual(fresh.state.phase, .error)
        XCTAssertEqual(fresh.state.rowCountText, "—")
        XCTAssertEqual(fresh.state.homeTotalText, "—")
        XCTAssertTrue(fresh.topicFacts.isEmpty)

        transport.paths.removeAll()
        transport.plays = envelope("[]")
        await fresh.loadGames(keyword: "sample", pack: nil)
        XCTAssertEqual(fresh.state.phase, .empty)
        XCTAssertEqual(fresh.state.rowCountText, "0")
        XCTAssertEqual(fresh.state.homeTotalText, "—")
        XCTAssertTrue(transport.paths.contains { $0.hasSuffix("/api/template/list") })
        XCTAssertFalse(transport.paths.contains { $0.hasSuffix("/api/template/homeData") })

        transport.paths.removeAll()
        transport.home = envelope(TemplateIndexFixtureData.homeNegativeTotal)
        await fresh.loadGames(keyword: "  ", pack: nil)
        XCTAssertEqual(fresh.state.phase, .ready)
        XCTAssertEqual(fresh.state.homeTotalText, "—")
        XCTAssertEqual(fresh.state.rowCountText, "1")
        XCTAssertTrue(transport.paths.contains { $0.hasSuffix("/api/template/homeData") })
        XCTAssertFalse(transport.paths.contains { $0.contains("topic-template/use") })
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func envelope(_ data: String) -> String { #"{"code":200,"data":"# + data + "}" }

    private func playerCapability(remaining: Int?) -> PublishingCapability {
        var body: [String: ProjectEditJSON] = ["role": .string("player")]
        if let remaining {
            body["quota"] = .object(["themesRemaining": .number(Decimal(remaining))])
        }
        return PublishingCapability(body)
    }

    private func coordinator(capability: PublishingCapability?, scope: TemplateTabScope) -> TemplateIndexPageCoordinator {
        let transport = TemplateIndexScriptTransport()
        let service = try! DiscoveryService(configuration: APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!), transport: transport)
        return TemplateIndexPageCoordinator(service: service, publishCapability: capability, scope: scope)
    }

    private func coordinator(_ transport: TemplateIndexScriptTransport) throws -> TemplateIndexPageCoordinator {
        let service = try DiscoveryService(configuration: APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!), transport: transport)
        return TemplateIndexPageCoordinator(service: service, publishCapability: nil, scope: .consumer)
    }
}

private final class TemplateIndexScriptTransport: HTTPTransport {
    var topics = #"{"code":200,"data":[]}"#
    var home = #"{"code":200,"data":{}}"#
    var plays = #"{"code":200,"data":[]}"#
    var topicsStatus = 200
    var homeStatus = 200
    var playsStatus = 200
    var paths: [String] = []
    private let lock = NSLock()

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        lock.lock()
        paths.append(path)
        lock.unlock()
        if path.hasSuffix("/api/template/topic-template/list") { return (Data(topics.utf8), topicsStatus) }
        if path.hasSuffix("/api/template/homeData") { return (Data(home.utf8), homeStatus) }
        if path.hasSuffix("/api/template/list") { return (Data(plays.utf8), playsStatus) }
        return (Data(#"{"code":404}"#.utf8), 404)
    }
}
