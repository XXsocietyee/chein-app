import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

@MainActor private final class ComplaintReader: CoopFlowReading {
    var session: CoopFlowSession? = try? .init(accountID: 41, epoch: 1, token: "synthetic-complaint-token")
    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        guard resource == .complaintTopics else { throw APIError.notConfigured }
        return .array([.object(["topicId": .id(71), "topicName": .string("Synthetic city topic")])])
    }
    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement { throw APIError.notConfigured }
}

@MainActor private final class FakeComplaintSubmitter: ProfileComplaintSubmitting {
    var calls: [(Int, String)] = []
    var error: Error?
    func submit(topicID: Int, reason: String) async throws {
        calls.append((topicID, reason))
        if let error { throw error }
    }
}

@MainActor private final class ComplaintEvidence: CoopFlowEvidenceReading {
    func freshEvidence(for operation: CoopFlowMutation, session: CoopFlowSession) async throws -> CoopFlowEvidence {
        .init(baseline: .null, permitted: true)
    }
}
@MainActor private final class ComplaintExecutor: CoopFlowExecuting {
    var dispatchScope: String? { "synthetic-scope" }
    var executed: [CoopFlowMutation] = []
    func permitsDispatch(_ operation: CoopFlowMutation) -> Bool { true }
    func execute(_ operation: CoopFlowMutation, session: CoopFlowSession) async throws -> CoopFlowJSON {
        executed.append(operation); return .object([:])
    }
}
@MainActor private final class ComplaintLocks: CoopFlowLockStore {
    var keys = Set<String>()
    func contains(_ key: String) throws -> Bool { keys.contains(key) }
    func acquire(_ key: String) throws { keys.insert(key) }
    func complete(_ key: String) throws { keys.remove(key) }
}

/// Source subpackageMember/complaint/index.js submit(): POST api/coop/complaint/report {topicId, reason}.
@MainActor final class ProfileComplaintSubmitTests: XCTestCase {
    private func reviewed() async -> (ProfileComplaintPreparationController, ProfileComplaintReview) {
        let model = ProfileComplaintPreparationController(reader: ComplaintReader(), isCurrent: { true })
        await model.load()
        model.change { $0.topicID = 71; $0.kind = .fees; $0.reason = "Synthetic issue text"; $0.contact = "synthetic" }
        XCTAssertTrue(model.beginReview())
        return (model, model.review!)
    }

    func testSuccessIsShownOnlyAfterWriterReturnsAndSendsReviewedReason() async {
        let writer = FakeComplaintSubmitter()
        let (_, review) = await reviewed()
        let sending = ProfileComplaintSubmissionController(submitter: writer)
        XCTAssertTrue(sending.canSend(review: review)); XCTAssertEqual(sending.state, .idle)
        await sending.send(review: review, isCurrent: { true })
        XCTAssertEqual(sending.state, .succeeded)
        XCTAssertEqual(writer.calls.count, 1)
        XCTAssertEqual(writer.calls.first?.0, 71)
        XCTAssertEqual(writer.calls.first?.1, "【费用与退款】Synthetic issue text\n联系方式：synthetic")
        XCTAssertFalse(sending.canSend(review: review))
        await sending.send(review: review, isCurrent: { true })
        XCTAssertEqual(writer.calls.count, 1, "a completed complaint cannot be sent twice")
    }

    func testFailureNeverShowsSuccessAndAllowsExplicitRetry() async {
        let writer = FakeComplaintSubmitter()
        writer.error = CoopFlowFailure.server(500, "Busy")
        let (_, review) = await reviewed()
        let sending = ProfileComplaintSubmissionController(submitter: writer)
        await sending.send(review: review, isCurrent: { true })
        XCTAssertEqual(sending.state, .failed(.rejected("Busy")))
        XCTAssertTrue(sending.canSend(review: review))
        writer.error = nil
        await sending.send(review: review, isCurrent: { true })
        XCTAssertEqual(sending.state, .succeeded); XCTAssertEqual(writer.calls.count, 2)
    }

    func testErrorMapping() {
        XCTAssertEqual(ProfileComplaintSubmitFailure.map(CoopFlowFailure.disabled), .notAvailable)
        XCTAssertEqual(ProfileComplaintSubmitFailure.map(CoopFlowFailure.ambiguous), .ambiguous)
        XCTAssertEqual(ProfileComplaintSubmitFailure.map(APIError.unauthorized), .signIn)
        XCTAssertEqual(ProfileComplaintSubmitFailure.map(URLError(.notConnectedToInternet)), .network)
    }

    func testStaleContextSendsNothing() async {
        let writer = FakeComplaintSubmitter()
        let (_, review) = await reviewed()
        let sending = ProfileComplaintSubmissionController(submitter: writer)
        await sending.send(review: review, isCurrent: { false })
        XCTAssertTrue(writer.calls.isEmpty); XCTAssertEqual(sending.state, .idle)
    }

    func testNoWriterIsHonestlyUnavailableAndSendsNothing() async {
        let (_, review) = await reviewed()
        let sending = ProfileComplaintSubmissionController(submitter: nil)
        XCTAssertFalse(sending.isConfigured); XCTAssertFalse(sending.canSend(review: review))
        await sending.send(review: review, isCurrent: { true })
        XCTAssertEqual(sending.state, .failed(.notAvailable))
    }

    func testCoordinatorSubmitterIsClosedUnlessHostEnablesTheRoute() async throws {
        let session = try CoopFlowSession(accountID: 41, epoch: 1, token: "synthetic-complaint-token")
        let executor = ComplaintExecutor(), locks = ComplaintLocks()
        let (_, review) = await reviewed()
        let closed = CoopFlowCoordinator(current: { session }, evidence: ComplaintEvidence(), executor: executor, locks: locks, enabled: false)
        let blocked = ProfileComplaintSubmissionController(submitter: ProfileComplaintCoordinatorSubmitter(coordinator: closed))
        await blocked.send(review: review, isCurrent: { true })
        XCTAssertEqual(blocked.state, .failed(.notAvailable))
        XCTAssertTrue(executor.executed.isEmpty)

        let open = CoopFlowCoordinator(current: { session }, evidence: ComplaintEvidence(), executor: executor, locks: locks, enabled: true)
        let approved = ProfileComplaintSubmissionController(submitter: ProfileComplaintCoordinatorSubmitter(coordinator: open))
        await approved.send(review: review, isCurrent: { true })
        XCTAssertEqual(approved.state, .succeeded)
        guard case .complaint(let topic, let reason)? = executor.executed.first else { return XCTFail("complaint not executed") }
        XCTAssertEqual(topic, 71)
        let operation = CoopFlowMutation.complaint(topicID: topic, reason: reason)
        XCTAssertEqual(operation.path, "api/coop/complaint/report")
        XCTAssertEqual(try operation.body()["topicId"].integer, 71)
        XCTAssertEqual(try operation.body()["reason"].text, reason)
    }
}
#endif
