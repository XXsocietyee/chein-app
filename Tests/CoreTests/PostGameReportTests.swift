import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// §九 U08 (cloud-h7). Synthetic payloads shaped like hengyin `PlayerRunReportVO`, `PlayerJourneyMemoryVO`,
/// `ScopedLeaderboardVO`, the orient team ranking rows and `PlayRunFeedbackService` receipts.
final class PostGameReportTests: XCTestCase {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    // MARK: U08-01 report

    func testReportReadsTheRealWireAndKeepsUnknownsNil() throws {
        let report = try XCTUnwrap(PostGameRunReport.decode(data(#"""
        {"activityId":0,"topicId":9,"runState":"COMPLETED","scopeKind":"RUN","runId":77,"completionKind":"ASSISTED_COMPLETION",
         "completedAt":"2026-11-08 23:30:00","completedNodes":4,"totalNodes":5,"elapsedSeconds":3725,"elapsedSource":"PLAYER_RUN_SESSION_PAUSED",
         "score":{"state":"SCORED","score":120,"penalties":20},
         "rank":{"scope":"quest","scopeId":9,"scoreBasis":"COMPLETED_NODES","rank":3,"score":4,"qualified":true},
         "nodes":[{"nodeId":11,"name":"桥","completionMode":"SKIPPED","score":0,"scored":true},{"nodeId":12,"name":"塔","scored":false,"score":null}],
         "rewardsState":"AVAILABLE","rewardsScope":"TOPIC_ACTIVITY","rewards":{"items":[{"id":1},{"id":2}]}}
        """#)))
        XCTAssertEqual(report.completion, .assisted)
        XCTAssertFalse(report.win, "assisted is not cleared")
        XCTAssertTrue(report.finished)
        XCTAssertFalse(report.legacyScope)
        XCTAssertEqual(report.runID, "77")
        XCTAssertNil(report.activityID, "0 is no activity")
        XCTAssertEqual(report.nodesText, "4/5")
        XCTAssertEqual(report.elapsedText, "1:02:05")
        XCTAssertEqual(report.dateText, "2026.11.08", "server time read as Beijing")
        XCTAssertEqual(report.score, 120)
        XCTAssertEqual(report.penalties, 20)
        XCTAssertEqual(report.rank, 3)
        XCTAssertEqual(report.rankScore, 4)
        XCTAssertEqual(report.nodes.map(\.mode), [.skipped, nil])
        XCTAssertEqual(report.nodes.map(\.score), [0, nil], "a skipped node really scored 0; an unscored node is nil")
        XCTAssertEqual(report.assistedCount, 1, "SKIPPED counts; an unscored node does not")
        XCTAssertTrue(report.showsAssistedCount)
        XCTAssertNil(report.startModeText, "a normal start has no label")
        XCTAssertEqual(report.backpackItems, 2)
    }

    func testAssistedCountStartModeAndNodePhoto() throws {
        let desk = try XCTUnwrap(PostGameRunReport.decode(data(#"""
        {"runState":"COMPLETED","scopeKind":"RUN","runId":3,"runStartMode":"DESK","completionKind":"LEGITIMATE_COMPLETION",
         "nodes":[{"nodeId":1,"completionMode":"REVEALED","photoUrl":"https://fixture.example/a.jpg"},{"nodeId":2,"completionMode":"SKIPPED","photoUrl":""}]}
        """#)))
        XCTAssertEqual(desk.assistedCount, 2)
        XCTAssertEqual(desk.startModeText, "桌面完成")
        XCTAssertTrue(desk.showsStartMode)
        XCTAssertEqual(desk.nodes.map(\.photoURL), ["https://fixture.example/a.jpg", nil])
        let alt = try XCTUnwrap(PostGameRunReport.decode(data(#"{"runState":"ENDED","scopeKind":"RUN","runStartMode":"ALT","nodes":[]}"#)))
        XCTAssertEqual(alt.startModeText, "替代站开局")
        XCTAssertEqual(alt.assistedCount, 0)
        XCTAssertFalse(alt.showsAssistedCount)
        let other = try XCTUnwrap(PostGameRunReport.decode(data(#"{"runState":"ENDED","scopeKind":"RUN","runStartMode":"MAYBE"}"#)))
        XCTAssertNil(other.startModeText)
    }

    func testNotScoredUnqualifiedAndLegacyStayEmpty() throws {
        let report = try XCTUnwrap(PostGameRunReport.decode(data(#"""
        {"runState":"ENDED","completionKind":"ENDED","scopeKind":"LEGACY_TOPIC_SCOPE","elapsedSeconds":null,"elapsedSource":"UNAVAILABLE_OTHER_RUN",
         "score":{"state":"NOT_SCORED","score":null,"penalties":null,"reason":"NO_AUTHORITATIVE_BASE_SCORE"},
         "rank":{"rank":null,"qualified":false},"rewardsState":"UNAVAILABLE","totalNodes":0}
        """#)))
        XCTAssertTrue(report.legacyScope)
        XCTAssertNil(report.score)
        XCTAssertNil(report.penalties)
        XCTAssertNil(report.rank)
        XCTAssertNil(report.elapsedText)
        XCTAssertNil(report.nodesText)
        XCTAssertNil(report.backpackItems)
        XCTAssertEqual(report.completion, .ended)
        let unqualified = try XCTUnwrap(PostGameRunReport.decode(data(#"{"runState":"IN_PROGRESS","rank":{"rank":2,"qualified":false},"score":{"state":"SCORED"}}"#)))
        XCTAssertNil(unqualified.rank, "an unqualified rank is not shown")
        XCTAssertNil(unqualified.score, "SCORED without a number stays unknown")
        XCTAssertTrue(unqualified.inProgress)
    }

    func testReportTimingDerivesElapsedAndFallsBackToEndedAt() throws {
        let derived = try XCTUnwrap(PostGameRunReport.decode(data(#"""
        {"runState":"COMPLETED","completionKind":"LEGITIMATE_COMPLETION","scopeKind":"RUN",
         "startedAt":"2026-11-14 10:00:00","endedAt":"2026-11-14 10:05:30"}
        """#)))
        XCTAssertEqual(derived.elapsedSeconds, 330)
        XCTAssertEqual(derived.elapsedText, "05:30")
        XCTAssertEqual(derived.dateText, "2026.11.14")

        let overWeek = try XCTUnwrap(PostGameRunReport.decode(data(#"""
        {"runState":"ENDED","completionKind":"ENDED","scopeKind":"RUN",
         "startedAt":"2026-11-01 10:00:00","completedAt":"2026-11-14 10:00:00"}
        """#)))
        XCTAssertNil(overWeek.elapsedSeconds)
    }

    func testFinishResultOnlyClearsFromServerFacts() {
        XCTAssertEqual(PostGameFinishResult.resolve(report: .loaded(.legitimate), topicCompleted: false, allDone: true, chapterDone: true), .cleared)
        XCTAssertEqual(PostGameFinishResult.resolve(report: .loaded(.assisted), topicCompleted: true, allDone: true, chapterDone: true), .assisted)
        XCTAssertEqual(PostGameFinishResult.resolve(report: .loaded(.ended), topicCompleted: false, allDone: true, chapterDone: false), .ended)
        XCTAssertEqual(PostGameFinishResult.resolve(report: .pending, topicCompleted: false, allDone: true, chapterDone: true), .unknown)
        XCTAssertEqual(PostGameFinishResult.resolve(report: .failed, topicCompleted: false, allDone: true, chapterDone: true), .unknown)
        XCTAssertEqual(PostGameFinishResult.resolve(report: .pending, topicCompleted: true, allDone: true, chapterDone: false), .cleared)
        XCTAssertEqual(PostGameFinishResult.resolve(report: .loaded(.inProgress), topicCompleted: false, allDone: true, chapterDone: true), .chapterDone)
        XCTAssertEqual(PostGameFinishResult.resolve(report: .loaded(.inProgress), topicCompleted: false, allDone: false, chapterDone: false), .ended)
    }

    func testMemoryKeepsOwnPhotosAndWritesTheDayOnce() throws {
        let memory = try XCTUnwrap(PostGameRunMemory.decode(data(#"""
        {"runId":77,"participantCount":3,"identityPolicy":"SELF_ONLY","photoShareCapability":"NO_PRIVATE_PHOTO_SHARE_CONSENT_FACT",
         "moments":[{"nodeId":11,"name":"桥","picUrl":"https://cdn.example/a.jpg","checkinTime":"2026-11-08 10:05:00"},
                    {"nodeId":12,"name":"塔","picUrl":"http://cdn.example/b.jpg","checkinTime":"2026-11-08 11:00:00"},
                    {"nodeId":13,"fragmentText":"夜","checkinTime":"2026-11-09 00:10:00"}]}
        """#)))
        XCTAssertEqual(memory.runID, "77")
        XCTAssertEqual(memory.companions, 3)
        XCTAssertFalse(memory.peerPhotosAvailable)
        XCTAssertEqual(memory.moments.map(\.dayText), ["2026.11.08", nil, "2026.11.09"])
        XCTAssertEqual(memory.moments.map(\.timeText), ["10:05", "11:00", "00:10"])
        XCTAssertNotNil(memory.moments[0].pictureURL)
        XCTAssertNil(memory.moments[1].pictureURL, "http is not shown")
        let alone = try XCTUnwrap(PostGameRunMemory.decode(data(#"{"participantCount":1,"moments":[]}"#)))
        XCTAssertNil(alone.companions)
        XCTAssertTrue(alone.isEmpty)
    }

    // MARK: U08-05 boards

    func testScopedBoardEchoCoverageAndWindow() {
        let json = #"""
        {"scope":"quest","scopeId":9,"period":"week","periodStart":"2026-11-02 00:00:00","periodEnd":"2026-11-09 00:00:00","scoreBasis":"COMPLETED_NODES",
         "entries":[{"rank":1,"memberId":5,"nickname":"甲","score":5},{"rank":1,"memberId":6,"nickname":"乙","score":5},{"rank":null,"memberId":7}],
         "me":{"rank":1,"memberId":6,"score":5},
         "coverage":{"rankedMembers":40,"unverifiedRuns":3,"unattributedRuns":null,"attributionBasis":"SCOPE_CONTENT"}}
        """#
        guard case .board(let board) = PostGameRankBoard.decodeScoped(data(json), scope: "quest", scopeID: "9", period: "week") else {
            return XCTFail("board")
        }
        XCTAssertEqual(board.entries.map(\.rank), [1, 1], "server ties kept; a row without a rank is dropped")
        XCTAssertEqual(board.entries.map(\.mine), [false, true])
        XCTAssertEqual(board.basis, .completedNodes)
        XCTAssertEqual(board.unverifiedRuns, 3)
        XCTAssertNil(board.unattributedRuns)
        XCTAssertEqual(board.windowText, "2026.11.02 – 2026.11.08", "exclusive end shown as the day before")
        XCTAssertEqual(board.topPercent, 3)
        XCTAssertEqual(PostGameRankBoard.decodeScoped(data(json), scope: "quest", scopeID: "9", period: "all"), .mismatch)
        XCTAssertEqual(PostGameRankBoard.decodeScoped(data(json), scope: "world", scopeID: nil, period: "week"), .mismatch)
        XCTAssertEqual(PostGameRankBoard.decodeScoped(data(#"{"scope":"world","scopeId":null,"period":"all","entries":[],"me":null}"#),
                                                      scope: "world", scopeID: nil, period: "all"), .empty)
    }

    func testTeamBoardIsTeamsNotMembers() {
        let json = #"[{"rank":1,"teamId":3,"title":"红队","activeCount":4,"teamDoneCount":6,"totalTasks":8,"mine":false},{"rank":2,"teamId":4,"title":"蓝队","activeCount":3,"teamDoneCount":2,"totalTasks":8,"mine":true}]"#
        guard case .board(let board) = PostGameRankBoard.decodeTeams(data(json)) else { return XCTFail("board") }
        XCTAssertEqual(board.basis, .teamTasks)
        XCTAssertEqual(board.myRank, 2)
        XCTAssertEqual(board.entries[1].active, 3)
        XCTAssertEqual(board.entries[1].total, 8)
        XCTAssertNil(board.topPercent, "fewer than five teams")
        XCTAssertEqual(PostGameRankBoard.decodeTeams(data("[]")), .empty)
        XCTAssertEqual(PostGameRankBoard.decodeTeams(data(#"{"rows":[]}"#)), .malformed)
    }

    // MARK: U08-02 feedback

    func testFeedbackDraftLimitsAndOutcomes() {
        XCTAssertEqual(PostGameFeedbackDraft(runID: "0", nodeID: nil, category: .place, content: "x").problem, .noRun)
        XCTAssertEqual(PostGameFeedbackDraft(runID: "7", nodeID: nil, category: .place, content: "  ").problem, .empty)
        XCTAssertEqual(PostGameFeedbackDraft(runID: "7", nodeID: nil, category: .place, content: String(repeating: "字", count: 501)).problem, .tooLong)
        XCTAssertNil(PostGameFeedbackDraft(runID: "7", nodeID: "11", category: .question, content: String(repeating: "字", count: 500)).problem)

        let ok = JourneyLoopSource.envelope(data: data(#"{"code":200,"data":{"feedbackId":31,"runId":7,"nodeId":null,"category":"PLACE","contentRevisionId":null,"state":"RECEIVED","replayed":true}}"#), status: 200, receiptReread: true)
        guard case .received(let receipt) = PostGameFeedbackOutcome.classify(ok) else { return XCTFail("receipt") }
        XCTAssertEqual(receipt.feedbackID, "31")
        XCTAssertNil(receipt.contentRevisionID, "unmatched revision stays unknown")
        XCTAssertTrue(receipt.replayed)
        let noReceipt = JourneyLoopSource.envelope(data: data(#"{"code":200,"data":{}}"#), status: 200, receiptReread: false)
        XCTAssertEqual(PostGameFeedbackOutcome.classify(noReceipt), .unconfirmed, "2xx without a receipt is not success")
        let conflict = JourneyLoopSource.envelope(data: data(#"{"code":409,"msg":"原请求号对应的内容不一致"}"#), status: 200, receiptReread: false)
        XCTAssertEqual(PostGameFeedbackOutcome.classify(conflict), .refused(code: "409", message: "原请求号对应的内容不一致"))
        XCTAssertEqual(PostGameFeedbackOutcome.classify(.networkFailure), .unconfirmed)
    }

    func testFeedbackKeepsTheRequestIdUntilAFinalAnswer() async throws {
        let wire = Queue([(Data(#"{"code":503}"#.utf8), 503),
                          (Data(#"{"code":200,"data":{"feedbackId":31,"runId":7,"state":"RECEIVED","replayed":true}}"#.utf8), 200)])
        let source = try JourneyLoopSource(configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!), transport: wire,
                                           nowMillis: { 1_700_000_000_000 }, entropy: { "aaaa1111" })
        let draft = PostGameFeedbackDraft(runID: "7", nodeID: "11", category: .place, content: " 入口被围挡 ")
        XCTAssertTrue(source.sendsRunFeedback)
        let first = try await source.runFeedback(draft, token: "session-token")
        XCTAssertTrue(first.unconfirmed)
        let second = try await source.rereadRunFeedback(draft, token: "session-token")
        XCTAssertTrue(second.ok)
        XCTAssertTrue(second.receiptReread)
        XCTAssertEqual(wire.requests.map { $0.url?.path }, ["/api/play/feedback/submit", "/api/play/feedback/submit"])
        let bodies = wire.requests.map { (try? JSONSerialization.jsonObject(with: $0.httpBody ?? Data())) as? [String: String] ?? [:] }
        XCTAssertEqual(bodies[0], ["runId": "7", "nodeId": "11", "category": "PLACE", "content": "入口被围挡", "requestId": bodies[0]["requestId"] ?? "-"])
        XCTAssertEqual(bodies[0]["requestId"], bodies[1]["requestId"], "same id on the re-read")
        XCTAssertEqual(bodies[0]["requestId"]?.hasPrefix("runfb-"), true)
        do {
            _ = try await source.rereadRunFeedback(draft, token: "session-token")
            XCTFail("a final answer clears the saved id")
        } catch JourneyRefusal.noSavedRequest {}
        do {
            _ = try await source.runFeedback(PostGameFeedbackDraft(runID: "7", nodeID: nil, category: .other, content: ""), token: "session-token")
            XCTFail("empty")
        } catch JourneyRefusal.invalidRequest {}
        XCTAssertEqual(wire.requests.count, 2)
    }

    func testFeedbackStaysHiddenOnProductionUntilGranted() throws {
        let host = URL(string: ReviewedMarketLaunch.chinaProductionBaseURL)!
        let source = try JourneyLoopSource(configuration: APIConfiguration(baseURL: host), transport: Queue([]), endpointClass: .production,
                                           productionLease: JourneyProductionLease(host: host.host ?? ""))
        XCTAssertEqual(source.sendsRunFeedback,
                       ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/feedback/submit"))
        XCTAssertFalse(JourneyLoopSource.journey(.runFeedback).money)
    }

    // MARK: U08-02 recommendation

    func testEndedRowsAreNotCandidatesAndImpressionCarriesTheSourceRun() throws {
        let rows = try JSONDecoder().decode([PlayFinishRouteRow].self, from: data(#"""
        [{"id":1,"topicId":2,"name":"已结束场","endDate":"2026-11-01 18:00:00"},{"id":3,"topicId":4,"name":"进行中","endDate":"2026-12-01 18:00:00"}]
        """#))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-09T04:00:00Z"))
        XCTAssertEqual(PlayFinishRouteCard.pick(rows, currentActivityID: nil, currentTopicID: nil, now: now)?.activityID, 3)
        XCTAssertNil(PlayFinishRouteCard.pick([rows[0]], currentActivityID: nil, currentTopicID: nil, now: now), "no candidate ends naturally")
        let open = try JSONDecoder().decode([PlayFinishRouteRow].self, from: data(#"[{"id":5,"endDate":null}]"#))
        XCTAssertEqual(PlayFinishRouteCard.pick(open, currentActivityID: nil, currentTopicID: nil, now: now)?.activityID, 5)

        let impression = PlayFinishRouteImpression.make(activityID: 10, topicID: 100, runID: "77", now: Date(timeIntervalSince1970: 1), entropy: "abcd1234")
        XCTAssertEqual(impression.impressionID, "frr-rs-abcd1234")
        XCTAssertEqual(impression.trackProperties(mode: 1),
                       ["placement": "play_finish", "impressionId": "frr-rs-abcd1234", "mode": "1",
                        "sourceActivityId": "10", "sourceTopicId": "100", "sourceRunId": "77"])
        XCTAssertNil(PlayFinishRouteImpression.make(activityID: nil, topicID: nil, runID: "x").sourceRunID)
    }

    private final class Queue: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var responses: [(Data, Int)]
        init(_ responses: [(Data, Int)]) { self.responses = responses }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            guard !responses.isEmpty else { return (Data(), 500) }
            return responses.removeFirst()
        }
    }
}
