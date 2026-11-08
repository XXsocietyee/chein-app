#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// pages/coop/invite with several selected targets: one reviewed POST /api/coop/invite per
/// recipient, shared note and terms, no sends before each review is confirmed.
@MainActor final class CoopBatchInviteTests: XCTestCase {
    private final class Wire: CoopFlowOfflineHTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":{"conversationId":17}}"#.utf8), 200)
        }
    }
    @MainActor private final class Evidence: CoopFlowEvidenceReading {
        func freshEvidence(for operation: CoopFlowMutation, session: CoopFlowSession) async throws -> CoopFlowEvidence {
            CoopFlowEvidence(baseline: .object([
                "id": .id(8), "status": .id(0), "fromId": .id(9), "inviteType": .id(0),
                "invitationDirection": .string("received"), "revision": .id(1), "termsMode": .string("TRAFFIC")
            ]), permitted: true)
        }
    }
    private let endpoint = URL(string: "https://example.com/source")!
    private func session(_ account: Int = 1, _ epoch: UInt64 = 1) throws -> CoopFlowSession {
        try CoopFlowSession(accountID: account, epoch: epoch, token: "synthetic-token")
    }
    private func contexts(_ ids: [Int], kind: CoopFlowTargetKind = .merchant, session: CoopFlowSession) throws -> [CoopFlowInvitationContext] {
        let topic = try XCTUnwrap(CoopFlowOwnedTopic(row: .object(["id": .id(3), "name": .string("Topic"), "inviteWindowOpen": .bool(true)])))
        return try ids.map { id in
            let row: CoopFlowJSON = .object([kind == .merchant ? "memberId" : "id": .id(id), "name": .string("Target \(id)")])
            let candidate = try XCTUnwrap(CoopFlowTargetCandidate(kind: kind, row: row))
            return try XCTUnwrap(CoopFlowInvitationContext(candidate: candidate, topic: topic, scope: nil, session: session))
        }
    }

    func testThreeTargetsGiveThreeDraftsWithSharedNoteAndFixedFee() throws {
        let s = try session()
        let drafts = try XCTUnwrap(CoopFlowBatchInvite.drafts(contexts: contexts([2, 5, 7], session: s), message: "Hello",
            defaultMessage: "Default", fixed: true, fee: "30.5", currentSession: s))
        XCTAssertEqual(drafts.map(\.recipient.id), [2, 5, 7])
        XCTAssertTrue(drafts.allSatisfy { $0.message == "Hello" && $0.topicID == 3 })
        XCTAssertTrue(drafts.allSatisfy { $0.compensation == .fixed(Decimal(string: "30.5", locale: Locale(identifier: "en_US_POSIX"))!) })
    }

    func testEmptyNoteUsesDefaultAndTrafficHasNoFee() throws {
        let s = try session()
        let drafts = try XCTUnwrap(CoopFlowBatchInvite.drafts(contexts: contexts([2, 5], session: s), message: "  ",
            defaultMessage: "Default", fixed: false, fee: "ignored", currentSession: s))
        XCTAssertTrue(drafts.allSatisfy { $0.message == "Default" && $0.compensation == .traffic })
    }

    func testInvalidFeeStaleSessionDuplicatesAndEmptySelectionProduceNoDrafts() throws {
        let s = try session(), other = try session(2, 1)
        let three = try contexts([2, 5, 7], session: s)
        for fee in ["", "0", "-1", "abc"] {
            XCTAssertNil(CoopFlowBatchInvite.drafts(contexts: three, message: "", defaultMessage: "D", fixed: true, fee: fee, currentSession: s), fee)
        }
        XCTAssertNil(CoopFlowBatchInvite.drafts(contexts: three, message: "", defaultMessage: "D", fixed: false, fee: "", currentSession: other))
        XCTAssertNil(CoopFlowBatchInvite.drafts(contexts: three, message: "", defaultMessage: "D", fixed: false, fee: "", currentSession: nil))
        XCTAssertNil(CoopFlowBatchInvite.drafts(contexts: try contexts([2, 2], session: s), message: "", defaultMessage: "D", fixed: false, fee: "", currentSession: s))
        XCTAssertNil(CoopFlowBatchInvite.drafts(contexts: [], message: "", defaultMessage: "D", fixed: false, fee: "", currentSession: s))
    }

    func testEachDraftSendsExactlyOneWireRequestOnlyAfterItsOwnConfirm() async throws {
        let s = try session(), wire = Wire()
        let drafts = try XCTUnwrap(CoopFlowBatchInvite.drafts(contexts: contexts([2, 5], session: s), message: "Hi",
            defaultMessage: "D", fixed: false, fee: "", currentSession: s))
        let service = CoopFlowService(configuration: try APIConfiguration(baseURL: endpoint), transport: wire,
            dormantWritesEnabled: true,
            protectedDispatch: CoopFlowProtectedDispatch(operations: Set(CoopFlowProtectedOperation.allCases), endpoint: endpoint))
        let lock = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("locks.json")
        let coordinator = CoopFlowCoordinator(current: { s }, evidence: Evidence(),
            executor: CoopFlowDormantExecutor(service: service), locks: CoopFlowFileLocks(url: lock), enabled: true)
        // The coordinator holds one review at a time: each recipient is reviewed, then confirmed.
        for (index, draft) in drafts.enumerated() {
            let review = try await coordinator.prepare(.invite(draft))
            XCTAssertEqual(wire.requests.count, index, "Preparing a review must not send")
            _ = try await coordinator.confirm(review)
            XCTAssertEqual(wire.requests.count, index + 1)
        }
        XCTAssertEqual(wire.requests.count, 2)
        let toIDs = try wire.requests.map { request -> Int? in
            let body = try JSONDecoder().decode(CoopFlowJSON.self, from: XCTUnwrap(request.httpBody))
            return body["toId"].integer
        }
        XCTAssertEqual(toIDs, [2, 5])
        XCTAssertTrue(wire.requests.allSatisfy { $0.url?.path.hasSuffix("api/coop/invite") == true })
    }
}
#endif
