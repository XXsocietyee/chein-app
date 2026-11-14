#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class ChallengePOISubmissionTests: XCTestCase {
    private final class FakeWriter: ChallengePOIWriting {
        var requests: [ChallengePOICompleteRequest] = []
        var outcome: ChallengePOIWriteOutcome
        init(outcome: ChallengePOIWriteOutcome) { self.outcome = outcome }
        func complete(_ request: ChallengePOICompleteRequest) async -> ChallengePOIWriteOutcome {
            requests.append(request)
            return outcome
        }
    }

    private func coordinator(answerPicked: Bool = true) -> ChallengePOICoordinator {
        let c = ChallengePOICoordinator(nodeId: 7)
        c.applyLoadedNode(ChallengePOINode(id: 7, name: "Tower", question: "Which?", options: ["A", "B"]))
        if answerPicked { c.selectedOptionIndex = 1 }
        return c
    }

    func testGatedWriterNeverReportsDone() async {
        let c = coordinator()
        let model = ChallengePOISubmitModel(writer: GatedChallengePOIWriter())
        await model.submit(coordinator: c, userLat: nil, userLon: nil)
        XCTAssertEqual(model.state, .unavailable)
        XCTAssertNotEqual(c.state, .done)
    }

    func testInvalidAttemptSendsNothing() async {
        let c = coordinator(answerPicked: false)
        let writer = FakeWriter(outcome: .success(data: .object(["needRedeem": .bool(false)])))
        let model = ChallengePOISubmitModel(writer: writer)
        await model.submit(coordinator: c, userLat: nil, userLon: nil)
        if case .invalid = model.state {} else { XCTFail("expected invalid") }
        XCTAssertTrue(writer.requests.isEmpty)
    }

    func testSuccessUsesMiniRequestShapeAndShowsDoneOnlyAfterServerAnswer() async {
        let c = coordinator()
        let writer = FakeWriter(outcome: .success(data: .object(["needRedeem": .bool(false), "alreadyClaimed": .bool(true)])))
        let model = ChallengePOISubmitModel(writer: writer)
        await model.submit(coordinator: c, userLat: 31.2, userLon: 121.4)
        XCTAssertEqual(writer.requests.count, 1)
        XCTAssertEqual(writer.requests[0].path, "/api/city/nodes/7/complete")
        XCTAssertEqual(writer.requests[0].body["answer"], PlayWireValue.string("B"))
        XCTAssertEqual(writer.requests[0].body["photoUrl"], PlayWireValue.string(""))
        XCTAssertEqual(writer.requests[0].body["code"], PlayWireValue.string(""))
        XCTAssertEqual(writer.requests[0].body["lat"], PlayWireValue.number(31.2))
        XCTAssertEqual(writer.requests[0].body["lng"], PlayWireValue.number(121.4))
        XCTAssertEqual(model.state, .done)
        XCTAssertEqual(c.state, .done)
        XCTAssertTrue(c.alreadyClaimed)
    }

    func testAmbiguousAnswerLocksAgainstBlindResubmit() async {
        let c = coordinator()
        let writer = FakeWriter(outcome: .success(data: .object([:])))
        let model = ChallengePOISubmitModel(writer: writer)
        await model.submit(coordinator: c, userLat: nil, userLon: nil)
        if case .unconfirmed = model.state {} else { XCTFail("expected unconfirmed") }
        XCTAssertTrue(c.unknownSubmission)
        XCTAssertNotEqual(c.state, .done)
        await model.submit(coordinator: c, userLat: nil, userLon: nil)
        if case .invalid = model.state {} else { XCTFail("second attempt must be blocked until refresh") }
        XCTAssertEqual(writer.requests.count, 1)
    }

    func testPrewriteRejectionIsShownAndDoesNotLock() async {
        let c = coordinator()
        let model = ChallengePOISubmitModel(writer: FakeWriter(outcome: .rejected(message: "答案不正确")))
        await model.submit(coordinator: c, userLat: nil, userLon: nil)
        XCTAssertEqual(model.state, .rejected("答案不正确"))
        XCTAssertFalse(c.unknownSubmission)
        XCTAssertNotEqual(c.state, .done)
    }

    func testNodeDecodesCoverUrlFallback() throws {
        let withCover = try ChallengePOINode.decode(from: .object([
            "id": .integer(7),
            "name": .string("Tower"),
            "coverImg": .string("https://cdn.example/cover.jpg")
        ]), fallbackNodeId: 7)
        XCTAssertEqual(withCover.coverUrl, "https://cdn.example/cover.jpg")
        let noCover = try ChallengePOINode.decode(from: .object(["id": .integer(8), "name": .string("Park")]), fallbackNodeId: 8)
        XCTAssertEqual(noCover.coverUrl, "")
    }
}
#endif
