import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Gap #17 (1128 plan, G-10b): the Release player grant admits the participation commands on any target and keeps
/// publish / broadcast / merchant invites exact-command only.
@MainActor final class OfficialPlayerTargetApprovalTests: XCTestCase {
    private let url = URL(string: "https://example.com")!
    private let owner = OfficialActionIdentity(accountID: 71, epoch: UUID(), namespace: "official-cn")

    private func context(account: Int = 71) throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: url, role: "player",
              session: try .init(accountID: account, epoch: 1, namespace: owner.namespace, token: "test-token"))
    }

    private func approval(paths: Set<String> = OfficialActionProductionApproval.playerTargetPaths) throws -> OfficialActionProductionApproval {
        try .init(playerMarket: .china, endpoints: .init(baseURL: url, namespace: owner.namespace, accountID: 71, paths: paths),
                  reviewedPolicyVersion: "test")
    }

    func testParticipationCommandsArePermittedOnAnyTarget() throws {
        let grant = try approval(), c = try context()
        let evidence = OfficialArrivalEvidence(identity: owner, eventID: 8, sessionID: 3, missionCode: "ARRIVE", requestID: "r",
                                               latitude: 31, longitude: 121, accuracyM: 5, expiresAt: .distantFuture)
        XCTAssertTrue(grant.permits(.signup(8), context: c))
        XCTAssertTrue(grant.permits(.complete(9), context: c))
        XCTAssertTrue(grant.permits(.arrival(evidence), context: c))
        XCTAssertEqual(grant.approvedReadPaths(for: .arrival(evidence)), ["api/official/events/8"])
        XCTAssertTrue(grant.permits(.respond(partyID: 4, type: "CLUB", action: .accept, reason: nil), context: c))
        XCTAssertTrue(grant.permits(.respond(partyID: 4, type: "OFFICIAL", action: .decline, reason: nil), context: c))
        XCTAssertFalse(grant.permits(.respond(partyID: 4, type: "OFFICIAL", action: .withdraw, reason: nil), context: c))
        var draft = OfficialEventDraft(); draft.title = "x"
        XCTAssertFalse(grant.permits(.publish(draft), context: c))
        XCTAssertFalse(grant.permits(.inviteMerchants([3]), context: c))
        XCTAssertFalse(grant.permits(.signup(0), context: c))
        XCTAssertFalse(grant.permits(.signup(8), context: try context(account: 72)))
    }

    func testPlayerGrantNeedsEveryTemplate() throws {
        var paths = OfficialActionProductionApproval.playerTargetPaths
        paths.remove("api/official/events/{}/arrivals")
        XCTAssertThrowsError(try approval(paths: paths))
        XCTAssertEqual(OfficialActionProductionApproval.template("api/official/v2/parties/41/ACCEPT"), "api/official/v2/parties/{}/ACCEPT")
    }

    func testFactoryReadsTheApprovalSourceOnEveryUse() throws {
        var issued: OfficialActionProductionApproval?
        let c = try context()
        let factory = OfficialActionProductionFactory(api: try .init(baseURL: url), approvalSource: { issued },
                                                      transport: NoTransport(), current: { c }, identity: { self.owner })
        XCTAssertFalse(factory.enabled)
        issued = try approval()
        XCTAssertTrue(factory.enabled, "a grant issued after sign-in is picked up without rebuilding the coordinator")
    }
}

private final class NoTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { throw URLError(.notConnectedToInternet) }
}
