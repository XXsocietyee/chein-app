import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Acceptance r2, F-05 (flow 03): station 1 (typed answer) refused its submit on the device with no message,
/// and only one station could be tried. The refusal is now a named, visible reason; the server's done flag
/// decides a stop's state; and the station list keeps every visible stop.
@available(macOS 14.0, *)
@MainActor final class AcceptanceR2PlayAnswerTests: XCTestCase {
    // MARK: Fixtures (synthetic; activity 41, topic 71)

    private func node(_ id: Int, _ extra: String = "") -> String {
        #"{"nodeId":\#(id),"name":"Synthetic stop \#(id)","done":false,"arrived":true,"validationMethod":1,"question":"Synthetic question"\#(extra)}"#
    }
    private func nodes(_ rows: [String], doneCount: Int = 0, routeState: String? = nil) -> String {
        let route = routeState.map { #","routeState":"# + $0 } ?? ""
        return #"{"topicId":71,"topicName":"Synthetic journey","mode":1,"registered":true,"playable":true,"total":\#(rows.count),"doneCount":\#(doneCount),"nodes":[\#(rows.joined(separator: ","))]\#(route)}"#
    }
    private func snapshot(_ json: String) throws -> PlaySnapshot {
        try PlaySnapshot(scope: .activity(41), result: JSONDecoder().decode(PlayNodesResult.self, from: Data(json.utf8)))
    }
    private func coordinator(_ json: String) async throws -> (PlayExperienceCoordinator, PlayRecoveryRecordingTransport) {
        let owner = try PlayExperienceSession(accountID: 9001, epoch: 1, namespace: "synthetic-cn", token: "synthetic-token")
        let wire = PlayRecoveryRecordingTransport()
        wire.responses["/fixture/api/play/nodes"] = .reply(PlayExperienceSyntheticFixtures.envelope(json), 200)
        let service = PlayExperienceService(configuration: try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com/fixture/"))),
                                            transport: wire, enabled: [.reads, .classicCompletion, .runPersistence, .hints, .advanced])
        let model = PlayExperienceCoordinator(scope: .activity(41), service: service, recovery: PlayMemoryCompletionRecovery(),
                                              pausedStorage: PlayMemoryPausedStorage(), currentSession: { owner })
        await model.load()
        return (model, wire)
    }
    private func posts(_ wire: PlayRecoveryRecordingTransport) -> Int { wire.requests.filter { $0.httpMethod == "POST" }.count }

    // MARK: Server done flag

    func testServerDoneFlagMakesStopCompletedInEveryPresentation() throws {
        let forms = [
            nodes([node(701).replacingOccurrences(of: #""done":false"#, with: #""done":true"#), node(702)], doneCount: 1),
            nodes([node(701, #","routeNodeState":"COMPLETED""#), node(702)], doneCount: 1),
            nodes([node(701), node(702)], doneCount: 1, routeState: #"{"routeMode":"LINEAR","nodeStates":{"701":"COMPLETED"}}"#),
        ]
        for json in forms {
            let read = try snapshot(json)
            let done = try XCTUnwrap(read.visibleNodes.first { $0.id == 701 })
            XCTAssertTrue(read.isDone(done), json)
            XCTAssertEqual(PlayTaskStatusPresentation(node: done, snapshot: read), .completed, json)
            XCTAssertEqual(PlayReviewRefusal.station(nodeID: 701, in: read, mode: .cityOrientation, advancedReady: true), .completed, json)
            XCTAssertEqual(PlayStationListPresentation.rows(read).first { $0.id == 701 }?.state, .completed, json)
            // The next stop stays open once the earlier one is done.
            XCTAssertNil(PlayReviewRefusal.station(nodeID: 702, in: read, mode: .cityOrientation, advancedReady: false), json)
            XCTAssertEqual(PlayStationListPresentation.rows(read).first { $0.id == 702 }?.state, .current, json)
        }
    }

    func testDoneStopIsRefusedWithCompletedReasonAndSendsNothing() async throws {
        let (model, wire) = try await coordinator(nodes([node(701).replacingOccurrences(of: #""done":false"#, with: #""done":true"#), node(702)], doneCount: 1))
        XCTAssertEqual(model.reviewRefusal(nodeID: 701), .completed)
        XCTAssertThrowsError(try model.review(nodeID: 701, evidence: .answer("1921")))
        XCTAssertEqual(model.reviewRefusal(nodeID: 701, evidence: .answer("1921")), .completed)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(posts(wire), 0)
    }

    // MARK: Review refusal -> visible reason

    func testAdvancedPrerequisiteRefusalIsNamedNotSilent() async throws {
        // Station 1 on TEST: a typed answer whose node carries an advanced (qa) section.
        let (model, wire) = try await coordinator(nodes([node(701, #","advancedConfigJson":{"qa":{"enabled":true}}"#)]))
        XCTAssertEqual(model.reviewRefusal(nodeID: 701), .advancedRequired)
        do { _ = try model.review(nodeID: 701, evidence: .answer("1921")); XCTFail("review must refuse") }
        catch {
            let reason = model.reviewRefusal(nodeID: 701, evidence: .answer("1921")) ?? PlayReviewRefusal(error: error)
            XCTAssertEqual(reason, .advancedRequired)
            XCTAssertEqual(reason.messageKey, "playReview.refusal.advancedRequired")
        }
        XCTAssertEqual(posts(wire), 0)
    }

    func testAdvancedReadyStopOpensTheConfirmation() async throws {
        let (model, _) = try await coordinator(nodes([node(701, #","advancedConfigJson":{"qa":{"enabled":true}}"#)]))
        let ready = try PlayAdvancedState(PlayExperienceSyntheticFixtures.wire(
            #"{"sessionId":601,"activityId":41,"topicId":71,"nodeId":701,"version":2,"status":"RUNNING","readyForBase":true,"config":{}}"#))
        try model.acceptAdvanced(ready, context: model.interactionContext)
        XCTAssertNil(model.reviewRefusal(nodeID: 701, evidence: .answer("1921")))
        XCTAssertNoThrow(try model.review(nodeID: 701, evidence: .answer("1921")))
        XCTAssertEqual(model.phase, .reviewing)
    }

    func testValidNotDoneStopOpensConfirmationAndSubmits() async throws {
        let (model, wire) = try await coordinator(nodes([node(701), node(702)]))
        wire.responses["/fixture/api/play/answer"] = .reply(PlayExperienceSyntheticFixtures.envelope(#"{"nodeId":701,"firstTime":true,"done":1,"total":2}"#), 200)
        XCTAssertNil(model.reviewRefusal(nodeID: 701))
        XCTAssertNil(model.reviewRefusal(nodeID: 701, evidence: .answer("1921")))
        let review = try model.review(nodeID: 701, evidence: .answer("1921"))
        XCTAssertEqual(model.phase, .reviewing)
        await model.submit(review)
        XCTAssertEqual(wire.requests.filter { $0.httpMethod == "POST" && $0.url?.path == "/fixture/api/play/answer" }.count, 1)
    }

    func testEvidenceLevelRefusalsAreNamed() async throws {
        let (model, _) = try await coordinator(nodes([node(701), node(702, #","options":{"A":"North","B":"South"}"#).replacingOccurrences(of: #""validationMethod":1"#, with: #""validationMethod":3"#),
                                                       node(703, #","arrived":false,"needGps":true"#).replacingOccurrences(of: #""arrived":true,"#, with: "")]))
        XCTAssertEqual(model.reviewRefusal(nodeID: 701, evidence: .answer("   ")), .emptyAnswer)
        XCTAssertEqual(model.reviewRefusal(nodeID: 702, evidence: .answer("C")), .invalidChoice)
        XCTAssertNil(model.reviewRefusal(nodeID: 702, evidence: .answer("A")))
        XCTAssertEqual(model.reviewRefusal(nodeID: 703, evidence: .answer("1921")), .arrivalRequired)
        XCTAssertEqual(model.reviewRefusal(nodeID: 999), .notVisible)
        for (id, text) in [(701, "   "), (702, "C"), (703, "1921")] {
            XCTAssertThrowsError(try model.review(nodeID: id, evidence: .answer(text)))
        }
    }

    func testThrownErrorsMapToVisibleReasons() {
        XCTAssertEqual(PlayReviewRefusal(error: PlayExperienceError.staleSession), .sessionChanged)
        XCTAssertEqual(PlayReviewRefusal(error: PlayExperienceError.unauthorized), .sessionChanged)
        XCTAssertEqual(PlayReviewRefusal(error: PlayExperienceError.unsupported), .unsupported)
        XCTAssertEqual(PlayReviewRefusal(error: PlayExperienceError.disabled), .disabled)
        XCTAssertEqual(PlayReviewRefusal(error: PlayExperienceError.invalidAction), .invalidEvidence)
        XCTAssertEqual(PlayReviewRefusal(error: CancellationError()), .invalidEvidence)
        for reason in PlayReviewRefusal.allCases { XCTAssertEqual(reason.messageKey, "playReview.refusal." + reason.rawValue) }
    }

    func testEveryRefusalHasEnglishAndChineseCopy() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/\(PlayReviewRefusal.table).xcstrings"))
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for reason in PlayReviewRefusal.allCases {
            let entry = try XCTUnwrap(strings[reason.messageKey] as? [String: Any], reason.messageKey)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            XCTAssertNotNil(localizations["en"], reason.messageKey); XCTAssertNotNil(localizations["zh-Hans"], reason.messageKey)
        }
    }

    // MARK: Station list

    func testStationListKeepsEveryVisibleStopInServerOrder() throws {
        let read = try snapshot(nodes([
            node(701).replacingOccurrences(of: #""done":false"#, with: #""done":true"#),
            node(702), node(703, #","locked":true"#), node(704, #","routeNodeState":"HIDDEN""#), node(705, #","routeNodeState":"PLAYABLE""#),
        ], doneCount: 1))
        let rows = PlayStationListPresentation.rows(read)
        XCTAssertEqual(rows.map(\.id), [701, 702, 703, 705])
        XCTAssertEqual(rows.map(\.position), [1, 2, 3, 4])
        // Two open stops: neither is promoted to "current", both stay openable.
        XCTAssertEqual(rows.map(\.state), [.completed, .available, .locked, .available])
        XCTAssertNil(PlayReviewRefusal.station(nodeID: 705, in: read, mode: .cityOrientation, advancedReady: false))
        XCTAssertEqual(PlayReviewRefusal.station(nodeID: 703, in: read, mode: .cityOrientation, advancedReady: false), .locked)
        XCTAssertEqual(PlayReviewRefusal.station(nodeID: 704, in: read, mode: .cityOrientation, advancedReady: false), .notVisible)
    }

    func testStationListChapterFilterAndSingleOpenStopIsCurrent() throws {
        let read = try snapshot(nodes([node(701, #","chapterId":11"#), node(702, #","chapterId":12,"locked":true"#), node(703, #","chapterId":12"#).replacingOccurrences(of: #""done":false"#, with: #""done":true"#)], doneCount: 1))
        XCTAssertEqual(PlayStationListPresentation.rows(read).map(\.state), [.current, .locked, .completed])
        let chapter = PlayStationListPresentation.rows(read, chapterID: 12)
        XCTAssertEqual(chapter.map(\.id), [702, 703]); XCTAssertEqual(chapter.map(\.position), [1, 2])
    }
}
