import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class TeamCreateClosedLeaseTests: XCTestCase {
    func testCreateBodyRejectsMoneyAndAcceptsTheOwnedRegistrationShape() {
        XCTAssertTrue(TeamCreateWriteBody.accepts(Data(#"{"ownerType":2,"ownerId":41,"maxMembers":4,"joinMode":1}"#.utf8)))
        XCTAssertFalse(TeamCreateWriteBody.accepts(Data(#"{"ownerType":2,"ownerId":41,"maxMembers":4,"amount":1}"#.utf8)))
        XCTAssertFalse(TeamCreateWriteBody.accepts(Data(#"{"ownerType":1,"ownerId":41,"maxMembers":4}"#.utf8)))
    }

    func testClosedLeaseShowsTheRefusalAndDoesNotSend() async throws {
        let session = try TeamSyntheticFixtures.session()
        let wire = CreateWire()
        let config = try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.test/native")))
        let context = TeamSyntheticFixtures.creation
        let service = TeamHTTPService(configuration: config, transport: wire, journal: TeamMemoryJournal(), currentSession: { session },
                                      creationLoader: { owner, _ in
            guard owner == context.ownerID else { throw TeamFailure.invalidRequest }
            return context
        })
        let coordinator = TeamCoordinator(service: service, journal: TeamMemoryJournal(), currentSession: { session })
        await coordinator.loadCreation(ownerID: context.ownerID)
        XCTAssertEqual(coordinator.creation, context)
        XCTAssertFalse(coordinator.canSubmit)
        coordinator.refuseWhenLeaseClosed()
        XCTAssertEqual(coordinator.writeState, .notSent)
        XCTAssertEqual(coordinator.messageKey, "team.writesDisabled")
        let action = TeamAction.create(context: context, size: 2, inviteOnly: false)
        coordinator.prepare(action)
        let review = try XCTUnwrap(coordinator.review)
        await coordinator.confirm(review)
        XCTAssertEqual(coordinator.writeState, .notSent)
        XCTAssertTrue(wire.paths.isEmpty)
    }

    func testTeamOpenMatchesTheMiniProgramRule() throws {
        let open = try detail(#"{"id":9,"ownerType":2,"ownerId":41,"registrationStatus":2,"cmsActivity":{"name":"Night","teamMode":2,"teamMaxMembers":4}}"#)
        XCTAssertTrue(open.teamOpen)
        XCTAssertEqual(open.teamCreationSource?.context.ownerID, 41)
        let modeOne = try detail(#"{"id":9,"ownerType":2,"ownerId":41,"registrationStatus":2,"cmsActivity":{"name":"Night","teamMode":1}}"#)
        XCTAssertTrue(modeOne.teamOpen)
        XCTAssertNil(modeOne.teamCreationSource)
        let done = try detail(#"{"id":9,"ownerType":2,"ownerId":41,"registrationStatus":2,"verificationStatus":1,"cmsActivity":{"name":"Night","teamMode":2}}"#)
        XCTAssertFalse(done.teamOpen)
        let other = try detail(#"{"id":9,"ownerType":2,"ownerId":41,"registrationStatus":2,"cmsActivity":{"name":"Night","teamMode":3}}"#)
        XCTAssertFalse(other.teamOpen)
    }

    private func detail(_ json: String) throws -> OrderLifecycleDetail {
        try JSONDecoder().decode(OrderLifecycleDetail.self, from: Data(json.utf8))
    }
}

private final class CreateWire: HTTPTransport {
    var paths: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url?.path ?? "")
        return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
    }
}
