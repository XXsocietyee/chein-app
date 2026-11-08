#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class StoryParticipationActionsTests: XCTestCase {
    private final class FakeWriter: StoryParticipationWriting {
        var joins: [StoryJoinRequest] = []
        var answers: [StoryAnswerRequest] = []
        var outcome: StoryParticipationWriteOutcome
        init(outcome: StoryParticipationWriteOutcome) { self.outcome = outcome }
        func join(_ request: StoryJoinRequest) async -> StoryParticipationWriteOutcome { joins.append(request); return outcome }
        func submitAnswer(_ request: StoryAnswerRequest) async -> StoryParticipationWriteOutcome { answers.append(request); return outcome }
    }

    private func coordinator() -> StoryParticipationCoordinator {
        let state = StoryProjectJoinState(topicId: 12, role: .player,
                                          stations: [StoryProjectStation(stationId: 5, name: "Cafe")])
        let c = StoryParticipationCoordinator(topicId: 12, fromSource: "topic", joinState: state)
        c.loadStoryNodes([
            .object([
                "nodeId": .int(101), "chapterNo": .int(1), "name": .string("Dock"),
                "questionType": .int(3), "questionTitle": .string("Where?"),
            ])
        ])
        return c
    }

    func testGatedWriterNeverShowsSuccessForJoinOrAnswer() async {
        let c = coordinator()
        let model = StoryParticipationActionModel(writer: GatedStoryParticipationWriter())
        await model.join(coordinator: c)
        XCTAssertEqual(model.joinState, .unavailable)
        XCTAssertFalse(c.joinState.myJoined)
        c.selectAnswer(nodeId: 101, value: "pier")
        await model.submitAnswer(nodeId: 101, coordinator: c)
        XCTAssertEqual(model.answerStates[101], StoryActionState.unavailable)
        XCTAssertNotEqual(c.chapters.first?.nodes.first?.answered, true)
    }

    func testAcceptedJoinSendsRequestShapeThenUpdatesState() async {
        let c = coordinator()
        let writer = FakeWriter(outcome: .accepted(message: "ok"))
        let model = StoryParticipationActionModel(writer: writer)
        await model.join(coordinator: c)
        XCTAssertEqual(writer.joins, [StoryJoinRequest(topicId: 12, stationId: 5, role: .player)])
        XCTAssertEqual(model.joinState, .accepted("ok"))
        XCTAssertTrue(c.joinState.myJoined)
        await model.join(coordinator: c)
        XCTAssertEqual(writer.joins.count, 1, "already joined: nothing more is sent")
        if case .invalid = model.joinState {} else { XCTFail("expected invalid") }
    }

    func testRejectedJoinKeepsLocalStateUnchanged() async {
        let c = coordinator()
        let model = StoryParticipationActionModel(writer: FakeWriter(outcome: .rejected(message: "closed")))
        await model.join(coordinator: c)
        XCTAssertEqual(model.joinState, .rejected("closed"))
        XCTAssertFalse(c.joinState.myJoined)
    }

    func testAnswerValidationBlocksSendAndAcceptedAnswerMarksNode() async {
        let c = coordinator()
        let writer = FakeWriter(outcome: .accepted(message: "saved"))
        let model = StoryParticipationActionModel(writer: writer)
        await model.submitAnswer(nodeId: 101, coordinator: c)
        if case .invalid = model.answerStates[101] ?? .idle {} else { XCTFail("empty answer must be invalid") }
        XCTAssertTrue(writer.answers.isEmpty)
        c.selectAnswer(nodeId: 101, value: " pier ")
        await model.submitAnswer(nodeId: 101, coordinator: c)
        XCTAssertEqual(writer.answers.count, 1)
        XCTAssertEqual(writer.answers[0].endpoint, "api/topic/host-node-answer")
        XCTAssertEqual(writer.answers[0].payload["answer"], PlayWireValue.string("pier"))
        XCTAssertEqual(writer.answers[0].payload["nodeId"], PlayWireValue.int(101))
        XCTAssertEqual(model.answerStates[101], StoryActionState.accepted("saved"))
        XCTAssertEqual(c.chapters.first?.nodes.first?.answered, true)
    }
}
#endif
