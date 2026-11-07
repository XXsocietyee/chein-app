import XCTest
import Foundation
@testable import QuestifyCore

final class OrientScorePresentationTests: XCTestCase {
    override func setUp() { super.setUp(); W8Text.languageOverride = "en" }
    override func tearDown() { W8Text.languageOverride = nil; super.tearDown() }

    private func decode(timeline: String = "[]", appeals: String = "[]", settlement: String = "null", status: Int = 1) throws -> OrientSessionScore {
        let json = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":\(status),\"totalCenti\":1700,"
            + "\"byDimension\":{\"TASK\":2000,\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":-300,\"ADJUSTMENT\":0},"
            + "\"timeline\":\(timeline),\"settlement\":\(settlement),\"appeals\":\(appeals),\"disputes\":[]}"
        return try JSONDecoder().decode(OrientSessionScore.self, from: Data(json.utf8))
    }

    func testCentiFormattingUsesExactTwoDecimals() {
        XCTAssertEqual(OrientScoreFormat.centi(1700), "17.00")
        XCTAssertEqual(OrientScoreFormat.centi(5), "0.05")
        XCTAssertEqual(OrientScoreFormat.centi(-300, signed: true), "-3.00")
        XCTAssertEqual(OrientScoreFormat.centi(250, signed: true), "+2.50")
        XCTAssertEqual(OrientScoreFormat.centi(0, signed: true), "0.00")
        XCTAssertEqual(OrientScoreFormat.centi(Int.min), "-92233720368547758.08")
    }

    func testSummaryOrdersDimensionsAndStatesTotalForAccessibility() throws {
        let summary = OrientScorePresentation.summary(from: try decode())
        XCTAssertEqual(summary.dimensions.map(\.key), ["TASK", "PUZZLE", "BONUS", "PENALTY", "ADJUSTMENT"])
        XCTAssertEqual(summary.dimensions.map(\.value), ["+20.00", "0.00", "0.00", "-3.00", "0.00"])
        XCTAssertEqual(summary.total, "17.00")
        XCTAssertEqual(summary.totalAccessibility, "Round total 17.00 points")
        XCTAssertEqual(summary.phase, "Round ended")
        XCTAssertNil(summary.settlement)
        XCTAssertTrue(summary.settlementNotice.contains("not settled"))
    }

    func testTimelineRowsAreParsedAndMalformedRowsDropped() throws {
        let rows = "[{\"entryId\":\"30\",\"nodeId\":\"4\",\"dimension\":\"TASK\",\"deltaCenti\":\"500\",\"runningCenti\":\"500\",\"reasonCode\":\"TASK_DONE\",\"reversesEntryId\":null},"
            + "{\"entryId\":0,\"dimension\":\"TASK\",\"deltaCenti\":1,\"runningCenti\":1},"
            + "{\"entryId\":31,\"dimension\":\"PENALTY\",\"deltaCenti\":-300,\"runningCenti\":200,\"reasonCode\":\"LATE\",\"reversesEntryId\":30}]"
        let appeal = "{\"id\":\"72\",\"sessionId\":\"9\",\"memberId\":\"1\",\"entryId\":\"31\",\"nodeId\":null,\"reason\":\"check\",\"status\":0,\"idempotencyKey\":\"k-1\",\"resolutionEntryId\":null,\"resolutionNote\":null,\"windowDeadline\":null}"
        let summary = OrientScorePresentation.summary(from: try decode(timeline: rows, appeals: "[\(appeal)]"))
        XCTAssertEqual(summary.timeline.map(\.entryID), [30, 31])
        XCTAssertEqual(summary.timeline[0].delta, "+5.00")
        XCTAssertEqual(summary.timeline[0].nodeID, 4)
        XCTAssertFalse(summary.timeline[0].appealPending)
        XCTAssertEqual(summary.timeline[1].delta, "-3.00")
        XCTAssertEqual(summary.timeline[1].reversesEntryID, 30)
        XCTAssertTrue(summary.timeline[1].appealPending)
        XCTAssertEqual(summary.timeline[1].accessibilitySummary, "Penalty -3.00, running total 2.00")
        XCTAssertEqual(summary.appeals.map(\.statusText), ["Pending"])
    }

    func testSettlementSummaryAndPhaseForDisqualified() throws {
        let settlement = "{\"state\":\"SETTLED\",\"settlementId\":\"5\",\"sessionId\":\"9\",\"totalCenti\":1700,\"pointsAwarded\":17,\"xpAwarded\":8,\"idempotencyKey\":\"k-s\"}"
        let summary = OrientScorePresentation.summary(from: try decode(settlement: settlement, status: 3))
        XCTAssertEqual(summary.settlement, OrientScoreSettlementSummary(settlementID: 5, total: "17.00", points: 17, xp: 8))
        XCTAssertEqual(summary.phase, "Disqualified")
        XCTAssertTrue(summary.settlementNotice.contains("do not grant"))
    }

    func testFailureCopyNeverLeaksServerDetailAndOnlyTransientFailuresRetry() {
        W8Text.languageOverride = "zh-Hans"
        guard case .failed(let message, let retryable) = OrientScorePresentation.failure(for: URLError(.notConnectedToInternet)) else { return XCTFail() }
        XCTAssertTrue(retryable)
        XCTAssertFalse(message.contains("URL"))
        XCTAssertTrue(message.contains("重试"))
        XCTAssertTrue(OrientScoreLoadState.loading.isLoading)
        XCTAssertFalse(OrientScoreLoadState.empty.isLoading)
    }
}
