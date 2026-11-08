#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class MyProjectMutationsTests: XCTestCase {
    private final class FakeMutator: MyProjectMutating {
        var requests: [MyProjectMutationRequest] = []
        var outcome: MyProjectMutationOutcome
        init(outcome: MyProjectMutationOutcome) { self.outcome = outcome }
        func perform(_ request: MyProjectMutationRequest) async -> MyProjectMutationOutcome {
            requests.append(request)
            return outcome
        }
    }

    func testRequestShapesMatchMiniProgram() {
        let topic = MyProjectMutationBuilder.request(for: .toggleOnline(biz: .topic, id: 5, currentlyOnline: true), scope: "MERCHANT")
        XCTAssertEqual(topic.path, "/api/topic/update_user_status")
        XCTAssertEqual(topic.body["expectedUserStatus"], PlayWireValue.int(1))
        XCTAssertEqual(topic.body["scope"], PlayWireValue.string("MERCHANT"))
        let activity = MyProjectMutationBuilder.request(for: .toggleOnline(biz: .activity, id: 5, currentlyOnline: false), scope: "")
        XCTAssertEqual(activity.path, "/api/activity/update_publish_status")
        XCTAssertNil(activity.body["expectedUserStatus"])
        XCTAssertEqual(MyProjectMutationBuilder.request(for: .cancelActivity(id: 3), scope: "").path, "/api/activity/cancel")
        XCTAssertEqual(MyProjectMutationBuilder.request(for: .delete(biz: .topic, id: 3), scope: "").path, "/api/topic/delete")
        XCTAssertEqual(MyProjectMutationBuilder.request(for: .delete(biz: .activity, id: 3), scope: "").path, "/api/activity/delete")
        let tpl = MyProjectMutationBuilder.request(for: .deleteTemplate(id: 8), scope: "")
        XCTAssertEqual(tpl.path, "/api/template/delete")
        XCTAssertEqual(tpl.body["template_id"], PlayWireValue.int(8))
        let lib = MyProjectMutationBuilder.request(for: .setTemplateLibrary(id: 8, published: false), scope: "")
        XCTAssertEqual(lib.path, "/api/template/updateLibraryStatus")
        XCTAssertEqual(lib.body["publish_status"], PlayWireValue.int(0))
    }

    func testDeleteNeedsConfirmationAndOnlyServerDoneTriggersReload() async {
        let fake = FakeMutator(outcome: .done)
        let model = MyProjectMutationModel(writer: fake, scope: "")
        await model.begin(.delete(biz: .topic, id: 3))
        XCTAssertEqual(model.state, .awaitingConfirmation(.delete(biz: .topic, id: 3)))
        XCTAssertTrue(fake.requests.isEmpty, "nothing is sent before the confirm step")
        XCTAssertEqual(model.reloadToken, 0)
        await model.confirm()
        XCTAssertEqual(fake.requests.count, 1)
        XCTAssertEqual(model.state, .done(.delete(biz: .topic, id: 3)))
        XCTAssertEqual(model.reloadToken, 1)
    }

    func testDismissCancelsWithoutSending() async {
        let fake = FakeMutator(outcome: .done)
        let model = MyProjectMutationModel(writer: fake, scope: "")
        await model.begin(.cancelActivity(id: 1))
        model.dismiss()
        await model.confirm()
        XCTAssertTrue(fake.requests.isEmpty)
        XCTAssertEqual(model.state, .idle)
    }

    func testToggleRunsImmediatelyAndFailureKeepsListUntouched() async {
        let fake = FakeMutator(outcome: .failed(message: "stale"))
        let model = MyProjectMutationModel(writer: fake, scope: "")
        await model.begin(.toggleOnline(biz: .topic, id: 1, currentlyOnline: false))
        XCTAssertEqual(fake.requests.count, 1)
        XCTAssertEqual(model.state, .failed(.toggleOnline(biz: .topic, id: 1, currentlyOnline: false), "stale"))
        XCTAssertEqual(model.reloadToken, 0)
    }

    func testGatedMutatorIsNeverDone() async {
        let model = MyProjectMutationModel(writer: GatedMyProjectMutator(), scope: "")
        await model.begin(.setTemplateLibrary(id: 2, published: true))
        XCTAssertEqual(model.state, .unavailable(.setTemplateLibrary(id: 2, published: true)))
        XCTAssertEqual(model.reloadToken, 0)
    }
}
#endif
