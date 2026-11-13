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

    private func copied(_ id: Int) -> TopicTemplateUseOutcome { .copied(TopicTemplateUseReceipt(topicId: id)) }
    private var counter = 0
    private func makeModel(_ user: FakeUser, readOnly: Bool = false) -> TopicTemplateUseModel {
        TopicTemplateUseModel(writer: user, readOnly: readOnly) { [unowned self] in
            self.counter += 1
            return "tpluse-test-\(self.counter)"
        }
    }

    func testRequestShapeMatchesMiniProgram() async {
        let user = FakeUser(outcome: copied(55))
        let model = makeModel(user)
        await model.use(id: 801, scope: "MERCHANT")
        XCTAssertEqual(user.requests.count, 1)
        XCTAssertEqual(user.requests[0].path, "/api/template/topic-template/use")
        XCTAssertEqual(user.requests[0].body["id"], PlayWireValue.int(801))
        XCTAssertEqual(user.requests[0].body["scope"], PlayWireValue.string("MERCHANT"))
        XCTAssertEqual(user.requests[0].body["requestId"], PlayWireValue.string("tpluse-test-1"))
        XCTAssertNil(user.requests[0].body["bindingIntent"], "no plan -> legacy adoption, no intent")
        XCTAssertEqual(model.copiedReceipt?.topicId, 55)
        XCTAssertEqual(model.openRequest?.topicId, 55)
        let noScope = TopicTemplateUseRequest(id: 1, scope: nil)
        XCTAssertNil(noScope.body["scope"])
        XCTAssertEqual(user.requests[0].formFields["id"], "801")
    }

    func testPlacedTemplateSendsSameCityAndRevisionNeverNewCity() async throws {
        let json = #"{"revision":{"contentRevisionId":"77","revisionNo":3},"locationRequirement":{"physicalPlaceRequired":true,"stationWithAddressCount":4,"cityCode":"310100"}}"#
        let delivery = try JSONDecoder().decode(TopicTemplateContentDelivery.self, from: Data(json.utf8))
        let user = FakeUser(outcome: copied(9))
        await makeModel(user).use(id: 801, scope: nil, plan: TopicTemplateAdoptionPlan(delivery: delivery))
        XCTAssertEqual(user.requests[0].body["bindingIntent"], PlayWireValue.string("SAME_CITY"))
        XCTAssertEqual(user.requests[0].body["sourceContentRevisionId"], PlayWireValue.string("77"))
        let noCity = try JSONDecoder().decode(TopicTemplateContentDelivery.self,
                                              from: Data(#"{"locationRequirement":{"physicalPlaceRequired":true}}"#.utf8))
        XCTAssertNil(TopicTemplateAdoptionPlan(delivery: noCity).bindingIntent, "no source city -> no intent")
        XCTAssertTrue(TopicTemplateAdoptionPlan(delivery: noCity).keepsPlaces)
    }

    func testGatedUserShowsNotAvailableAndNeverCopied() async {
        let model = TopicTemplateUseModel(writer: GatedTopicTemplateUser(), readOnly: false)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(model.state, .unavailable)
        XCTAssertNotNil(TopicTemplateUseModel.message(for: model.state))
        XCTAssertNil(model.openRequest)
    }

    func testReadOnlyRoleSendsNothing() async {
        let user = FakeUser(outcome: copied(55))
        let model = makeModel(user, readOnly: true)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(model.state, .readOnly)
        XCTAssertTrue(user.requests.isEmpty)
    }

    func testFailureIsNotSuccessAndMintsAFreshIdNextTime() async {
        let user = FakeUser(outcome: .failed(message: "no quota"))
        let model = makeModel(user)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(model.state, .failed("no quota"))
        XCTAssertNil(model.openRequest)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(user.requests[1].body["requestId"], PlayWireValue.string("tpluse-test-2"))
        await model.use(id: 0, scope: nil)
        XCTAssertEqual(user.requests.count, 2, "invalid id sends nothing")
    }

    func testUnknownKeepsRequestIdUntilTheReceiptIsRead() async {
        let user = FakeUser(outcome: .unknown)
        let model = makeModel(user)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(model.state, .unknown)
        XCTAssertNil(model.openRequest, "unknown is never shown as copied")
        user.outcome = copied(31)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(user.requests.map { $0.body["requestId"] }, [.string("tpluse-test-1"), .string("tpluse-test-1")])
        XCTAssertEqual(model.copiedReceipt?.topicId, 31)
        XCTAssertNil(model.pendingRequestId)
    }

    func testSecondTapAfterCopyReopensTheSameDraft() async {
        let user = FakeUser(outcome: copied(9))
        let model = makeModel(user)
        await model.use(id: 801, scope: nil)
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(user.requests.count, 1)
        XCTAssertEqual(model.openRequest, .init(topicId: 9, sequence: 2))
    }

    func testSecondTapWhileInFlightIsDropped() async {
        let user = FakeUser(outcome: copied(9))
        let model = makeModel(user)
        user.onUse = { await model.use(id: 801, scope: nil) }
        await model.use(id: 801, scope: nil)
        XCTAssertEqual(user.requests.count, 1)
        XCTAssertEqual(model.copiedReceipt?.topicId, 9)
    }

    func testCopiedMessageCountsOnlyErrorIssuesAsBlocking() {
        let receipt = TopicTemplateUseReceipt(topicId: 3, pendingRebindSlotKeys: ["loc-1"], bindingIssues: [
            .init(slotKey: "loc-1", code: "X", level: "warn", message: "check")])
        XCTAssertEqual(receipt.blockingCount, 0)
        XCTAssertEqual(receipt.warningCount, 1)
        W8Text.languageOverride = "en"
        defer { W8Text.languageOverride = nil }
        let message = TopicTemplateUseModel.message(for: .copied(receipt)) ?? ""
        XCTAssertFalse(message.contains("before publishing"))
    }
}
#endif
