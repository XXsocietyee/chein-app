#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// pages/club/event-ops: cancel-occurrence / attendance writes are honest about being gated.
@MainActor final class ClubOpsEventWriteGateTests: XCTestCase {
    private final class IdleTransport: ClubGovernanceOfflineTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(), 503)
        }
    }
    private func config() throws -> APIConfiguration { try APIConfiguration(baseURL: URL(string: "https://example.com/")!) }

    func testGateStatesAreOrderedLockedThenUnavailableThenBusy() {
        XCTAssertEqual(ClubOpsEventWriteGate.state(canDispatch: true, busy: false, locked: false), .available)
        XCTAssertEqual(ClubOpsEventWriteGate.state(canDispatch: true, busy: true, locked: false), .busy)
        XCTAssertEqual(ClubOpsEventWriteGate.state(canDispatch: false, busy: false, locked: false), .notAvailableYet)
        XCTAssertEqual(ClubOpsEventWriteGate.state(canDispatch: false, busy: true, locked: true), .locked)
        XCTAssertTrue(ClubOpsEventWriteGate.notAvailableYet.showsNotAvailableNote)
        XCTAssertFalse(ClubOpsEventWriteGate.available.showsNotAvailableNote)
        XCTAssertFalse(ClubOpsEventWriteGate.busy.showsNotAvailableNote)
    }

    func testReadOnlyProductionServiceMakesCancelAndAttendanceNotAvailableYet() throws {
        let transport = IdleTransport()
        let service = ClubGovernanceService(configuration: try config(), transport: transport)
        for mutation in [ClubGovernanceMutation.cancelOccurrence, .correctAttendance] {
            let command = try ClubGovernanceFixtures.command(mutation)
            let gate = ClubOpsEventWriteGate.state(canDispatch: service.permits(command), busy: false, locked: false)
            XCTAssertEqual(gate, .notAvailableYet, mutation.rawValue)
        }
        XCTAssertTrue(transport.requests.isEmpty, "Computing the gate must never send")
    }

    func testOfflineFinancialRiskServiceMakesTheSameWritesAvailable() throws {
        let service = ClubGovernanceService(offlineConfiguration: try config(), offlineTransport: IdleTransport(),
                                            risks: [.administrative, .financial, .identity, .provider])
        for mutation in [ClubGovernanceMutation.cancelOccurrence, .correctAttendance] {
            let command = try ClubGovernanceFixtures.command(mutation)
            XCTAssertEqual(ClubOpsEventWriteGate.state(canDispatch: service.permits(command), busy: false, locked: false), .available, mutation.rawValue)
        }
    }
}
#endif
