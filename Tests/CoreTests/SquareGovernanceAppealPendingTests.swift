import XCTest
@testable import QuestifyCore

/// mp-mine-b: MP `post-governance` `pendingUnknown` — a dispatched appeal whose row still offers an
/// appeal reads as unconfirmed; other rows, accounts and fresh journals do not.
@MainActor final class SquareGovernanceAppealPendingTests: XCTestCase {
    func testDispatchedAppealOnOpenRowReadsUnconfirmed() async throws {
        let access = SquareGovernanceSyntheticAccess(), transport = SquareGovernanceSyntheticTransport()
        let identity = try XCTUnwrap(access.identity)
        let journal = SquareGovernanceJournal.ephemeral()
        let service = SquareGovernanceService(offlineBaseURL: URL(string: "https://example.com")!, transport: transport)
        let coordinator = SquareGovernanceCoordinator(service: service, journal: journal)
        let snapshot = try await coordinator.load(access: access)
        XCTAssertFalse(coordinator.appealOutcomeUnconfirmed(enforcementID: 91, snapshot: snapshot))
        XCTAssertTrue(journal.claim("appeal:91", identity: identity))
        XCTAssertTrue(coordinator.appealOutcomeUnconfirmed(enforcementID: 91, snapshot: snapshot))
        XCTAssertFalse(coordinator.appealOutcomeUnconfirmed(enforcementID: 92, snapshot: snapshot))
        XCTAssertFalse(transport.requests.contains { $0.httpMethod != "GET" })
    }
}
