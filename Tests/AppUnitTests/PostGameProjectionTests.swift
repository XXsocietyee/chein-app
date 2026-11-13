import XCTest
@testable import Questify

/// §九 U08 (cloud-h7): the battle report, memory and boards read the real server wire.
@MainActor final class PostGameProjectionTests: XCTestCase {
    private func ok(_ json: String) -> JourneyEnvelope {
        JourneyEnvelope(httpStatus: 200, code: "200", netFail: false, message: nil, dataJSON: Data(json.utf8), receiptReread: false)
    }

    func testReportShowsServerResultScoreAndRank() {
        let scope = JourneyRunScope(activityID: nil, topicID: "9", runID: "77", topicName: "城", registrationID: nil)
        let phase = PlayerJourneyProjection.report(ok(#"""
        {"topicId":9,"runId":77,"scopeKind":"RUN","runState":"COMPLETED","completionKind":"LEGITIMATE_COMPLETION",
         "completedNodes":5,"totalNodes":5,"elapsedSeconds":61,"score":{"state":"SCORED","score":88,"penalties":0},
         "rank":{"rank":2,"score":5,"qualified":true},"nodes":[{"nodeId":3,"name":"桥","completionMode":"REVEALED","scored":false}]}
        """#), scope: scope)
        guard case .ready(let report) = phase else { return XCTFail("\(phase)") }
        XCTAssertEqual(report.result, .legitimate)
        XCTAssertEqual(report.nodesText, "5/5")
        XCTAssertEqual(report.elapsedText, "01:01")
        XCTAssertEqual(report.score, 88)
        XCTAssertNil(report.penaltyText, "0 penalties is no penalty row")
        XCTAssertEqual(report.rank, 2)
        XCTAssertEqual(report.rankBasisCount, 5)
        XCTAssertEqual(report.nodes.first?.mode, .revealed)
        XCTAssertNil(report.nodes.first?.score)
        XCTAssertTrue(report.finished)

        let other = PlayerJourneyProjection.report(ok(#"{"runId":78,"scopeKind":"RUN","runState":"COMPLETED"}"#), scope: scope)
        XCTAssertEqual(other, .gone, "another run is not shown as this one")
    }

    func testMemoryHidesPeerPhotosWithoutConsentAndRejectsAnotherRun() {
        let phase = PlayerJourneyProjection.memory(ok(#"""
        {"runId":77,"participantCount":2,"photoShareCapability":"UNAVAILABLE","moments":[{"nodeId":3,"name":"桥","picUrl":"https://cdn.example/a.jpg","checkinTime":"2026-11-08 10:00:00"}]}
        """#), runID: "77")
        guard case .ready(let memory) = phase else { return XCTFail("\(phase)") }
        XCTAssertTrue(memory.peerPhotosHidden)
        XCTAssertTrue(memory.hasPhotos)
        XCTAssertEqual(memory.participants, 2)
        XCTAssertEqual(memory.moments.first?.dayText, "2026.11.08")
        if case .ready = PlayerJourneyProjection.memory(ok(#"{"runId":78,"moments":[{"nodeId":3}]}"#), runID: "77") { XCTFail("another run") }
    }

    func testBoardsUseEntriesAndRefuseAnotherScope() {
        let json = #"{"scope":"quest","scopeId":9,"period":"all","scoreBasis":"COMPLETED_NODES","entries":[{"rank":1,"memberId":5,"nickname":"甲","score":null}],"coverage":{"unverifiedRuns":2}}"#
        guard case .ready(let board) = PlayerJourneyProjection.rank(ok(json), scope: "quest", scopeID: "9", period: "all") else { return XCTFail("board") }
        XCTAssertEqual(board.entries.first?.scoreText, "—", "unknown score is not 0")
        XCTAssertEqual(board.unverifiedRuns, 2)
        XCTAssertEqual(board.basis, .completedNodes)
        XCTAssertEqual(PlayerJourneyProjection.rank(ok(json), scope: "quest", scopeID: "10", period: "all"), .failed(nil))
        guard case .ready(let teams) = PlayerJourneyProjection.teams(ok(#"[{"rank":1,"teamId":3,"title":"红队","activeCount":2,"teamDoneCount":1,"totalTasks":4,"mine":true}]"#)) else {
            return XCTFail("teams")
        }
        XCTAssertEqual(teams.entries.first?.scoreText, "1/4")
        XCTAssertEqual(teams.stats.map(\.value), ["1/4", "2"])
        XCTAssertEqual(teams.basis, .wholeTeam)
        XCTAssertEqual(PlayerJourneyProjection.rankTabs(JourneyRunScope(activityID: "4", topicID: nil)).count, 0, "no quest tab without a topic id")
    }
}
