import XCTest
@testable import QuestifyCore

/// Deterministic page-model checks for the full leaderboard. No transport and no view.
final class GrowthLeaderboardPageReadyTests: XCTestCase {
    func testUnknownNumbersUseAnEmDashAndNeverBecomeZero() {
        for raw: Int? in [nil, 0, -1, Int.min] {
            let rank = GrowthLeaderboardPageNumber.rank(raw)
            XCTAssertNil(rank.literal)
            XCTAssertNotEqual(rank.literal, 0)
            XCTAssertEqual(rank.displayText, "—")
            XCTAssertNotEqual(rank.displayText, "0")
        }
        let missingScore = GrowthLeaderboardPageNumber.score(nil)
        XCTAssertNil(missingScore.literal)
        XCTAssertNotEqual(missingScore.literal, 0)
        XCTAssertEqual(missingScore.displayText, GrowthLeaderboardPageNumber.unknownDisplay)
        XCTAssertEqual(GrowthLeaderboardPageNumber.unknownDisplay, "—")
        XCTAssertEqual(GrowthLeaderboardPageNumber.score(0).literal, 0)
        XCTAssertEqual(GrowthLeaderboardPageNumber.score(0).displayText, "0")
        XCTAssertEqual(GrowthLeaderboardPageNumber.rank(12).displayText, "12")
    }

    func testLoadingEmptyErrorAndUnknownAreDistinctPageStates() {
        let capability = GrowthLeaderboardPageCapability.productionBoard
        XCTAssertEqual(GrowthLeaderboardPageModel.project(capability: capability, isLoading: true, settled: false, issue: nil, board: nil).state, .some(.loading))
        let empty = GrowthLeaderboardPageModel.project(capability: capability, isLoading: false, settled: true, issue: nil, board: board(list: [], me: entry(rank: nil, score: nil)))
        guard case .empty(let viewer)? = empty.state else { return XCTFail("expected empty") }
        XCTAssertNil(viewer)
        XCTAssertFalse(empty.hidden)
        let failed = GrowthLeaderboardPageModel.project(capability: capability, isLoading: false, settled: true, issue: .unavailable, board: nil)
        XCTAssertEqual(failed.state, .some(.error(.unavailable)))
        let unknown = GrowthLeaderboardPageModel.project(capability: capability, isLoading: false, settled: true, issue: nil, board: nil)
        XCTAssertEqual(unknown.state, .some(.unknown))
        let blankRows = GrowthLeaderboardPageModel.project(capability: capability, isLoading: false, settled: true, issue: nil, board: board(list: [entry(rank: nil, score: nil)], me: entry(rank: nil, score: nil)))
        XCTAssertEqual(blankRows.state, .some(.unknown))
    }

    func testReadyBoardKeepsALiteralZeroScoreAndAnUnknownScoreAsAnEmDash() {
        let zero = entry(rank: 2, score: 0)
        let missing = entry(rank: 3, score: nil)
        let page = GrowthLeaderboardPageModel.project(capability: .productionBoard, isLoading: false, settled: true, issue: nil, board: board(list: [entry(rank: 1, score: 9), zero, missing], me: entry(rank: 8, score: 0)))
        guard case .ready(let ready)? = page.state else { return XCTFail("expected ready") }
        XCTAssertEqual(GrowthLeaderboardPageModel.scoreText(ready.list[1]), "0")
        XCTAssertEqual(GrowthLeaderboardPageModel.scoreText(ready.list[2]), "—")
        XCTAssertNotEqual(GrowthLeaderboardPageModel.scoreText(ready.list[2]), "0")
        XCTAssertNil(GrowthLeaderboardPageNumber.score(ready.list[2].score).literal)
        XCTAssertEqual(GrowthLeaderboardPageModel.rankText(ready.me), "8")
        XCTAssertEqual(GrowthLeaderboardPageModel.scoreText(ready.me), "0")
    }

    func testEmptyBoardCanStillShowAPositiveViewerRankWithoutInventingZero() {
        let page = GrowthLeaderboardPageModel.project(capability: .productionBoard, isLoading: false, settled: true, issue: nil, board: board(list: [], me: entry(rank: 4, score: nil)))
        guard case .empty(let viewer)? = page.state else { return XCTFail("expected empty") }
        XCTAssertEqual(viewer?.rank, 4)
        XCTAssertEqual(viewer?.rankText, "4")
        XCTAssertNil(viewer?.score)
        XCTAssertEqual(viewer?.scoreText, "—")
        XCTAssertNotEqual(viewer?.scoreText, "0")
    }

    func testHiddenBoardsStayHiddenAndDoNotBecomeLiveRoutes() {
        XCTAssertEqual(GrowthLeaderboardPageCapability.productionBoard.path, "api/growth/leaderboard")
        XCTAssertTrue(GrowthLeaderboardPageCapability.productionBoard.isLive)
        XCTAssertEqual(GrowthLeaderboardPageCapability.anonymousBoard.path, RePoint04GrowthLeaderboard.unservedPath)
        XCTAssertFalse(GrowthLeaderboardPageCapability.anonymousBoard.isLive)
        let ranked = board(list: [entry(rank: 1, score: 3)], me: entry(rank: 1, score: 3))
        for capability in [GrowthLeaderboardPageCapability.anonymousBoard, .seasonBoard, .worldBoard, .teamBoard] {
            XCTAssertFalse(capability.isLive)
            XCTAssertNotEqual(capability.path, GrowthLeaderboardPageCapability.productionBoard.path)
            let hidden = GrowthLeaderboardPageModel.project(capability: capability, isLoading: true, settled: true, issue: nil, board: ranked)
            XCTAssertNil(hidden.state)
            XCTAssertTrue(hidden.hidden)
        }
        XCTAssertNil(GrowthLeaderboardPageCapability.seasonBoard.path)
        XCTAssertNil(GrowthLeaderboardPageCapability.worldBoard.path)
        XCTAssertNil(GrowthLeaderboardPageCapability.teamBoard.path)
    }

    @MainActor func testCoordinatorLoadsTheExistingReaderAndKeepsHiddenCapabilitiesUncalled() async {
        let reader = PageReader()
        reader.result = .success(board(list: [entry(rank: 1, score: 5)], me: entry(rank: 1, score: 0)))
        let coordinator = GrowthLeaderboardPageCoordinator(reader: reader, query: GrowthBoardQuery(metric: .exp, period: .week))
        XCTAssertEqual(coordinator.model.state, .some(.loading))
        await coordinator.refresh()
        guard case .ready(let ready)? = coordinator.model.state else { return XCTFail("expected ready") }
        XCTAssertEqual(ready.metric, .point)
        XCTAssertEqual(ready.period, .total)
        XCTAssertEqual(GrowthLeaderboardPageModel.scoreText(ready.me), "0")
        XCTAssertEqual(reader.boardReads, 1)
        XCTAssertEqual(reader.overviewReads, 0)
        XCTAssertEqual(reader.lastQuery, GrowthBoardQuery(metric: .exp, period: .week))

        reader.result = .failure(APIError.httpStatus(503))
        await coordinator.refresh()
        XCTAssertEqual(coordinator.model.state, .some(.error(.unavailable)))

        reader.result = .success(board(list: [], me: entry(rank: nil, score: 0)))
        await coordinator.refresh()
        guard case .empty(let viewer)? = coordinator.model.state else { return XCTFail("expected empty") }
        XCTAssertNil(viewer)

        reader.result = .success(board(list: [entry(rank: nil, score: nil)], me: entry(rank: 0, score: nil)))
        await coordinator.refresh()
        XCTAssertEqual(coordinator.model.state, .some(.unknown))

        let hiddenReader = PageReader()
        hiddenReader.result = .success(board(list: [entry(rank: 1, score: 1)], me: entry(rank: 1, score: 1)))
        let hidden = GrowthLeaderboardPageCoordinator(reader: hiddenReader, capability: .anonymousBoard)
        XCTAssertNil(hidden.model.state)
        XCTAssertTrue(hidden.model.hidden)
        await hidden.refresh()
        XCTAssertEqual(hiddenReader.boardReads, 0)
        XCTAssertNil(hidden.model.state)
    }

    @MainActor func testSignedOutAndUnconfiguredReadsStayErrorsWithoutCallingTheBoard() async {
        let guest = PageReader()
        guest.isAuthenticated = false
        let signedOut = GrowthLeaderboardPageCoordinator(reader: guest)
        await signedOut.refresh()
        XCTAssertEqual(signedOut.model.state, .some(.error(.login)))
        XCTAssertEqual(guest.boardReads, 0)

        let offline = PageReader()
        offline.isConfigured = false
        let unconfigured = GrowthLeaderboardPageCoordinator(reader: offline)
        await unconfigured.refresh()
        XCTAssertEqual(unconfigured.model.state, .some(.error(.notConfigured)))
        XCTAssertEqual(offline.boardReads, 0)
    }

    private func entry(rank: Int?, score: Int?) -> GrowthLeaderboardEntry {
        GrowthLeaderboardEntry(rank: rank, memberID: 7, nickname: "Sample", avatar: nil, score: score, rankPercentage: nil)
    }

    private func board(list: [GrowthLeaderboardEntry], me: GrowthLeaderboardEntry) -> GrowthLeaderboard {
        GrowthLeaderboard(metric: .point, period: .total, list: list, me: me)
    }
}

@MainActor private final class PageReader: GrowthCenterReading {
    let scope = UUID()
    var isAuthenticated = true
    var isConfigured = true
    let isOfflineExample = false
    var boardReads = 0
    var overviewReads = 0
    var lastQuery: GrowthBoardQuery?
    var result: Result<GrowthLeaderboard, Error> = .failure(APIError.notConfigured)
    func overview() async throws -> GrowthCenterOverview {
        overviewReads += 1
        throw APIError.notConfigured
    }
    func leaderboard(query: GrowthBoardQuery) async throws -> GrowthLeaderboard {
        boardReads += 1
        lastQuery = query
        return try result.get()
    }
}
