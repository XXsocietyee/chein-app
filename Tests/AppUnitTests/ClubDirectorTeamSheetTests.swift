import XCTest
@testable import Questify

/// MP topic-detail index.js:939-962 (`refreshTeamRows`) and director.js:78-114, 162-188 (team / broadcast views).
@MainActor final class ClubDirectorTeamSheetTests: XCTestCase {
    private func projection() throws -> PlayDirectorProjection {
        let raw = try PlayExperienceSyntheticFixtures.wire(#"{"perspective":"CLUB","activityId":41,"sessionId":501,"revision":2,"status":"RUNNING","availableActions":[],"club":{"teams":[{"teamId":61,"name":"North","status":"RUNNING","completedNodes":2,"totalNodes":5},{"teamId":62,"teamName":"South","status":"BLOCKED","blockedReason":"Gate closed","currentStuckNode":{"nodeName":"Synthetic gate"},"hintLevel":2,"recentEvent":{"action":"PLAYER_SUBMIT","outcome":"FAILED","occurredAt":"20:15"}},{"status":"weird","members":[{"memberId":9}]}],"broadcasts":[{"id":3,"content":"Meet at the gate","targetType":"TEAM","targetName":"North","receiptStatus":"APPLIED"},{"scope":"ALL","status":"odd"}]}}"#)
        return try PlayDirectorProjection(raw, activityID: 41)
    }

    func testTeamRowsFollowMPMapping() throws {
        let rows = ClubDirectorTeamSheetRows.teams(try projection())
        XCTAssertEqual(rows.map(\.id), ["61", "62", "m9"])
        XCTAssertEqual(rows.map(\.statusCode), ["RUNNING", "BLOCKED", "unknown"])
        XCTAssertEqual(rows.map(\.abnormal), [false, true, false])
        XCTAssertEqual(rows[0].completed, 2)
        XCTAssertEqual(rows[1].issue, "Gate closed")
        XCTAssertEqual(rows[1].stuckNode, "Synthetic gate")
        XCTAssertEqual(rows[1].hintLevel, 2)
        XCTAssertEqual(rows[1].eventAction, "PLAYER_SUBMIT")
        XCTAssertEqual(rows[1].eventOutcome, "FAILED")
        XCTAssertNil(rows[2].title)
    }

    func testBroadcastRowsFollowMPMapping() throws {
        let rows = ClubDirectorTeamSheetRows.broadcasts(try projection())
        XCTAssertEqual(rows.map(\.id), ["3", "b1"])
        XCTAssertEqual(rows.map(\.receiptCode), ["CONFIRMED", "unknown"])
        XCTAssertEqual(rows.map(\.targetCode), ["TEAM", "ALL"])
        XCTAssertNil(rows[1].content)
    }
}
