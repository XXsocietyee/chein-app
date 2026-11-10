import XCTest
@testable import QuestifyCore

@MainActor final class TemplateAuthoringIntroReadModelTests: XCTestCase {
    @MainActor private final class Box {
        var payload = Data()
        var error: Error?
        var calls = 0
        var hold = false
        private var waiters: [CheckedContinuation<Void, Never>] = []
        func read() async throws -> Data {
            calls += 1
            if hold { await withCheckedContinuation { waiters.append($0) } }
            if let error { throw error }
            return payload
        }
        func release() {
            let pending = waiters
            waiters.removeAll()
            for waiter in pending { waiter.resume() }
        }
    }

    private func model(_ json: String) -> TemplateAuthoringIntroReadModel? {
        TemplateAuthoringIntroReadModel.make(homeData: Data(json.utf8))
    }

    private func fixture(_ json: String) -> TemplateAuthoringIntroReadModel {
        let value = TemplateAuthoringIntroReadModel.make(homeData: Data(json.utf8))
        XCTAssertNotNil(value)
        return value ?? .errored
    }

    func testLoadingAndUnknownAreEmDashNeverZero() {
        XCTAssertEqual(TemplateAuthoringIntroReadModel.loading.phase, .loading)
        XCTAssertEqual(TemplateAuthoringIntroReadModel.loading.total, .unknown)
        XCTAssertEqual(TemplateAuthoringIntroCountState.unknown.text, "—")
        XCTAssertNil(TemplateAuthoringIntroCountState.unknown.literal)
        XCTAssertNotEqual(TemplateAuthoringIntroCountState.unknown.text, "0")
        XCTAssertEqual(TemplateAuthoringIntroCountState.parse(nil), .unknown)
        XCTAssertEqual(TemplateAuthoringIntroCountState.parse(NSNull()), .unknown)
        XCTAssertEqual(TemplateAuthoringIntroCountState.parse("UNKNOWN"), .unknown)
        XCTAssertEqual(TemplateAuthoringIntroCountState.parse("0"), .unknown)
        XCTAssertEqual(TemplateAuthoringIntroCountState.parse(true), .unknown)
        XCTAssertEqual(TemplateAuthoringIntroCountState.parse(1.5), .unknown)
        XCTAssertEqual(TemplateAuthoringIntroCountState.value(0).text, "0")
    }

    func testFixtureRecommendedPoolKeepsCategoryAndSkipsOtherPools() {
        let value = fixture(TemplateAuthoringIntroFixtureData.recommended)
        XCTAssertEqual(value.phase, .ready)
        XCTAssertEqual(value.examples?.pool, .recommended)
        XCTAssertEqual(value.cards.map(\.id), [11, 12])
        XCTAssertEqual(value.cards[0].categoryName, "Synthetic")
        XCTAssertEqual(value.cards[0].useCount, .value(3))
        XCTAssertEqual(value.cards[0].duration, .value(10))
        XCTAssertEqual(value.cards[1].useCount, .unknown)
        XCTAssertEqual(value.cards[1].duration, .unknown)
        XCTAssertEqual(value.cards[1].categoryName, TemplateAuthoringIntroExamples.defaultCategoryName)
        XCTAssertEqual(value.total, .value(2))
        XCTAssertFalse(value.cards.map(\.id).contains(99))
    }

    func testEmptyIsDistinctFromUnknownAndFromLiteralZero() {
        let missing = fixture(TemplateAuthoringIntroFixtureData.empty)
        XCTAssertEqual(missing.phase, .empty)
        XCTAssertTrue(missing.cards.isEmpty)
        XCTAssertEqual(missing.total, .unknown)
        XCTAssertNotEqual(missing.total.text, "0")
        let zero = fixture(TemplateAuthoringIntroFixtureData.emptyZeroTotal)
        XCTAssertEqual(zero.phase, .empty)
        XCTAssertEqual(zero.total, .value(0))
        XCTAssertEqual(zero.total.text, "0")
    }

    func testUnknownTokensStayEmDashAndLiteralZeroStaysZero() {
        let unknown = fixture(TemplateAuthoringIntroFixtureData.unknownCounts)
        XCTAssertEqual(unknown.phase, .ready)
        XCTAssertEqual(unknown.cards.count, 1)
        XCTAssertEqual(unknown.cards[0].useCount, .unknown)
        XCTAssertEqual(unknown.cards[0].duration, .unknown)
        XCTAssertEqual(unknown.total, .unknown)
        XCTAssertEqual(unknown.cards[0].useCount.text, "—")
        XCTAssertNotEqual(unknown.cards[0].useCount.literal, 0)
        let zero = fixture(TemplateAuthoringIntroFixtureData.zeroCounts)
        XCTAssertEqual(zero.cards[0].useCount, .value(0))
        XCTAssertEqual(zero.cards[0].duration, .value(0))
        XCTAssertEqual(zero.total.text, "0")
    }

    func testNonIntegerCountsAreUnknownAndNegativeUseIsError() {
        let fractional = model(#"{"recommendList":[{"id":5,"title":"Row","useNum":1.5,"duration":true}]}"#)
        XCTAssertEqual(fractional?.phase, .ready)
        XCTAssertEqual(fractional?.cards[0].useCount, .unknown)
        XCTAssertEqual(fractional?.cards[0].duration, .unknown)
        XCTAssertNotEqual(fractional?.cards[0].useCount.text, "1")
        XCTAssertNotEqual(fractional?.cards[0].useCount.text, "2")
        let textZero = model(#"{"recommendList":[{"id":5,"title":"Row","useNum":"0"}]}"#)
        XCTAssertEqual(textZero?.cards[0].useCount, .unknown)
        XCTAssertNil(model(#"{"recommendList":[{"id":5,"title":"Row","useNum":-1}]}"#))
        XCTAssertNil(model(TemplateAuthoringIntroFixtureData.malformed))
        let negativeDuration = model(#"{"recommendList":[{"id":5,"title":"Row","duration":-1}]}"#)
        XCTAssertEqual(negativeDuration?.cards[0].duration, .value(-1))
        XCTAssertEqual(negativeDuration?.cards[0].duration.text, "-1")
    }

    func testPrefixStaysThreeAndDecodedHomeNilCountIsUnknown() throws {
        let wide = try XCTUnwrap(model(#"{"recommendList":[{"id":1,"title":"A"},{"id":2,"title":"B"},{"id":3,"title":"C"},{"id":4,"title":"D"}]}"#))
        XCTAssertEqual(wide.cards.map(\.id), [1, 2, 3])
        let hot = try XCTUnwrap(model(#"{"hotList":[{"id":8,"title":"Hot","useNum":4}],"latestList":[{"id":9,"title":"Late"}]}"#))
        XCTAssertEqual(hot.examples?.pool, .hot)
        XCTAssertEqual(hot.cards.map(\.id), [8])
        XCTAssertEqual(hot.cards[0].useCount, .value(4))
        let home = try JSONDecoder().decode(DiscoveryTemplateHome.self, from: Data(#"{"recommendList":[{"id":4,"title":"Named"}],"total":0}"#.utf8))
        let ready = TemplateAuthoringIntroReadModel(home: home)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.cards[0].useCount, .unknown)
        XCTAssertEqual(ready.cards[0].duration, .unknown)
        XCTAssertEqual(ready.cards[0].categoryName, TemplateAuthoringIntroExamples.defaultCategoryName)
        XCTAssertEqual(ready.total, .value(0))
        let empty = TemplateAuthoringIntroReadModel(home: try JSONDecoder().decode(DiscoveryTemplateHome.self, from: Data(#"{}"#.utf8)))
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.total, .unknown)
    }

    func testCoordinatorReadsExistingHomeAndHidesAFailedRead() async throws {
        let home = try JSONDecoder().decode(DiscoveryTemplateHome.self, from: Data(TemplateAuthoringIntroFixtureData.zeroCounts.utf8))
        let ready = TemplateAuthoringIntroCoordinator(templateHome: { home })
        await ready.load()?.value
        XCTAssertEqual(ready.model.phase, .ready)
        XCTAssertEqual(ready.model.cards[0].useCount, .value(0))
        let hidden = TemplateAuthoringIntroCoordinator(templateHome: { throw APIError.notConfigured })
        await hidden.load()?.value
        XCTAssertEqual(hidden.model, .errored)
        XCTAssertTrue(hidden.model.cards.isEmpty)
        XCTAssertEqual(hidden.model.total.text, "—")
        let malformed = TemplateAuthoringIntroCoordinator(homeData: { Data(TemplateAuthoringIntroFixtureData.malformed.utf8) })
        await malformed.load()?.value
        XCTAssertEqual(malformed.model.phase, .error)
        XCTAssertNotEqual(malformed.model.phase, .empty)
        XCTAssertEqual(malformed.model.total, .unknown)
    }

    func testRefreshFailureKeepsReadyCardsAndEmptySuccessClearsThem() async {
        let box = Box()
        box.payload = Data(TemplateAuthoringIntroFixtureData.zeroCounts.utf8)
        let coordinator = TemplateAuthoringIntroCoordinator(homeData: { try await box.read() })
        await coordinator.load()?.value
        XCTAssertEqual(coordinator.model.phase, .ready)
        box.error = APIError.malformedResponse
        await coordinator.load()?.value
        XCTAssertEqual(coordinator.model.phase, .ready)
        XCTAssertEqual(coordinator.model.cards[0].useCount, .value(0))
        XCTAssertEqual(box.calls, 2)
        box.error = nil
        box.payload = Data(TemplateAuthoringIntroFixtureData.empty.utf8)
        await coordinator.load()?.value
        XCTAssertEqual(coordinator.model.phase, .empty)
        XCTAssertTrue(coordinator.model.cards.isEmpty)
        XCTAssertEqual(coordinator.model.total, .unknown)
    }

    func testSingleFlightAndCancelDropTheLateDocument() async {
        let box = Box()
        box.hold = true
        box.payload = Data(TemplateAuthoringIntroFixtureData.recommended.utf8)
        let coordinator = TemplateAuthoringIntroCoordinator(homeData: { try await box.read() })
        let first = coordinator.load()
        for _ in 0..<200 where box.calls == 0 { await Task.yield() }
        XCTAssertEqual(box.calls, 1)
        XCTAssertNil(coordinator.load())
        coordinator.cancel()
        box.release()
        await first?.value
        XCTAssertEqual(coordinator.model, .loading)
        XCTAssertEqual(coordinator.model.total.text, "—")
        box.hold = false
        await coordinator.load()?.value
        XCTAssertEqual(coordinator.model.cards.map(\.id), [11, 12])
        XCTAssertEqual(box.calls, 2)
    }
}
