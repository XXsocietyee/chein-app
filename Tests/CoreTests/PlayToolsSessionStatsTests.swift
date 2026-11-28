import XCTest
import Foundation
@testable import QuestifyCore

/// mp-journey r3: MP `play-hud-overlays.js` `scoreScreen` → 游玩工具 `sessStats` (本局用时 · 当前得分 · 第 N 名).
final class PlayToolsSessionStatsTests: XCTestCase {
    private func score(status: Int = 0, total: Int = 1750, deadline: String? = nil) throws -> OrientSessionScore {
        let window = deadline.map { ",\"disputeWindowDeadline\":\"\($0)\"" } ?? ""
        let json = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":\(status),\"totalCenti\":\(total),"
            + "\"byDimension\":{\"TASK\":2000,\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":-250,\"ADJUSTMENT\":0},\"timeline\":[],\"settlement\":null,\"appeals\":[],\"disputes\":[]\(window)}"
        return try JSONDecoder().decode(OrientSessionScore.self, from: Data(json.utf8))
    }

    private func board(session: Int = 9, rank: Int = 2, elapsed: String = "754000") throws -> OrientSessionLeaderboard {
        let me = "{\"rowKey\":\"5\",\"rank\":\(rank),\"scoreCenti\":1750,\"elapsedMs\":\(elapsed),\"reachedEnding\":false,\"mine\":true}"
        let json = "{\"sessionId\":\(session),\"mode\":\"SCORE\",\"list\":[\(me)],\"me\":\(me)}"
        return try JSONDecoder().decode(OrientSessionLeaderboard.self, from: Data(json.utf8))
    }

    func testRunningRoundShowsElapsedScoreAndProvisionalRank() throws {
        let stats = PlayToolsSessionStats.project(score: try score(), board: try board())
        XCTAssertEqual(stats, .ready(elapsed: "12:34", score: "17.5", rank: 2, provisional: true))
    }

    func testBoardForAnotherSessionIsIgnored() throws {
        let stats = PlayToolsSessionStats.project(score: try score(), board: try board(session: 10))
        XCTAssertEqual(stats, .ready(elapsed: nil, score: "17.5", rank: nil, provisional: true))
    }

    func testEndedRoundIsFinalOnlyAfterTheDisputeWindow() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(PlayToolsSessionStats.project(score: try score(status: 1, total: 1700), board: nil, now: now),
                       .ready(elapsed: nil, score: "17", rank: nil, provisional: false))
        let open = try score(status: 2, deadline: "2099-01-01 00:00:00")
        XCTAssertEqual(PlayToolsSessionStats.project(score: open, board: nil, now: now),
                       .ready(elapsed: nil, score: "17.5", rank: nil, provisional: true))
        let closed = try score(status: 2, deadline: "2020-01-01T00:00:00Z")
        XCTAssertEqual(PlayToolsSessionStats.project(score: closed, board: nil, now: now),
                       .ready(elapsed: nil, score: "17.5", rank: nil, provisional: false))
    }

    func testPointsAndClockFollowTheMP() {
        XCTAssertEqual(PlayToolsSessionStats.points(centi: 1700), "17")
        XCTAssertEqual(PlayToolsSessionStats.points(centi: -300), "-3")
        XCTAssertEqual(PlayToolsSessionStats.points(centi: -350), "-3.5")
        XCTAssertEqual(PlayToolsSessionStats.points(centi: 1799), "18")
        XCTAssertEqual(PlayToolsSessionStats.clock(milliseconds: 59_999), "00:59")
        XCTAssertEqual(PlayToolsSessionStats.clock(milliseconds: 3_723_000), "1:02:03")
        XCTAssertEqual(PlayToolsSessionStats.clock(milliseconds: -5), "00:00")
    }

    func testScoringOffHidesTheRowsInsteadOfFailing() {
        let off = OrientSessionFailure(httpStatus: nil, code: 500, err: nil, errorCode: "ORIENT_SCORING_DISABLED", message: nil, data: nil)
        let other = OrientSessionFailure(httpStatus: nil, code: 500, err: "X", errorCode: nil, message: nil, data: nil)
        XCTAssertTrue(PlayToolsSessionStats.hidesRows(for: off))
        XCTAssertFalse(PlayToolsSessionStats.hidesRows(for: other))
        XCTAssertFalse(PlayToolsSessionStats.hidesRows(for: APIError.malformedResponse))
    }

    func testBothReadsAreLiveChinaProductionRoutes() {
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/orient/scoring/session/9"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/orient/scoring/session/9/leaderboard"))
    }
}
