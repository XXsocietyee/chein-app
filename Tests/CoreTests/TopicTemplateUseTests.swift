#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class TopicTemplateUseTests: XCTestCase {
    private final class FakeUser: TopicTemplateUsing {
        var requests: [TopicTemplateUseRequest] = []
        var outcome: TopicTemplateUseOutcome
        var onUse: (() async -> Void)?
        init(outcome: TopicTemplateUseOutcome) { self.outcome = outcome }
        func use(_ request: TopicTemplateUseRequest) async -> TopicTemplateUseOutcome {
            requests.append(request)
            if let onUse { await onUse() }
            return outcome
        }
    }

    func testRequestShapeMatchesMiniProgram() async {
        let user = FakeUser(outcome: .copied(topicId: 55))
        let model = TopicTemplateUseModel(writer: user, readOnly: false)
        await model.use(id: 801, scope: "MERCHANT")
        XCTAssertEqual(user.requests.count, 1)
        XCTAssertEqual(user.requests[0].path, "/api/template/topic-template/use")
        XCTAssertEqual(user.requests[0].body["id"], PlayWireValue.int(801))
        XCTAssertEqual(user.requests[0].body["scope"], PlayWireValue.string("MERCHANT"))
        XCTAssertEqual(model.state, .copied(topicId: 55))
        let noScope = TopicTemplateUseRequest(id: 1, scope: nil)
        XCTAssertNil(noScope.body["scope"])
    }

    func testGatedUserShowsNotAvailableAndNeverCopied() async {
        let model = TopicTemplateUseModel(writer: GatedTopicTemplateUser(), readOnly: false)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(model.state, .unavailable)
        XCTAssertNotNil(TopicTemplateUseModel.message(for: model.state))
    }

    func testReadOnlyRoleSendsNothing() async {
        let user = FakeUser(outcome: .copied(topicId: 55))
        let model = TopicTemplateUseModel(writer: user, readOnly: true)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(model.state, .readOnly)
        XCTAssertTrue(user.requests.isEmpty)
    }

    func testFailureAndMissingTopicIdAreNotSuccess() async {
        let user = FakeUser(outcome: .failed(message: "no quota"))
        let model = TopicTemplateUseModel(writer: user, readOnly: false)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(model.state, .failed("no quota"))
        user.outcome = .copied(topicId: 0)
        await model.use(id: 801, scope: nil)
        if case .failed = model.state {} else { XCTFail("topicId 0 must not be success") }
        await model.use(id: 0, scope: nil)
        XCTAssertEqual(user.requests.count, 2, "invalid id sends nothing")
    }

    func testSecondTapWhileInFlightIsDropped() async {
        let user = FakeUser(outcome: .copied(topicId: 9))
        let model = TopicTemplateUseModel(writer: user, readOnly: false)
        user.onUse = { await model.use(id: 801, scope: nil) }
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(user.requests.count, 1)
        XCTAssertEqual(model.state, .copied(topicId: 9))
    }
}
#endif
