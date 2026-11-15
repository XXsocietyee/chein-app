import XCTest
@testable import QuestifyCore

/// In-memory reads only. No mutation adapter or live request is installed.
@MainActor final class NearbyTeamCancelledReadTests: XCTestCase {
    private let session = NearbyTeamSyntheticFixtures.session
    private let context = NearbyTeamSyntheticFixtures.context
    private let teamID = NearbyTeamID(503)

    private func make() -> (NearbyTeamCoordinator, NearbyCancelledReadTransport) {
        let read = NearbyCancelledReadTransport()
        let model = NearbyTeamCoordinator(
            service: .init(readTransport: read, liveReadGrant: true),
            session: session, locks: .init())
        return (model, read)
    }

    func testPrecancelledEntriesPreserveReviewAndNeverRead() async throws {
        for entry in 0..<3 {
            let (model, read) = make()
            await model.loadNearby(context)
            model.prepare(.apply(.init(501)))
            let reviewID = try XCTUnwrap(model.review).id
            let requests = read.requests
            await Task { @MainActor in
                withUnsafeCurrentTask { $0?.cancel() }
                switch entry {
                case 0: await model.loadNearby(context)
                case 1: await model.loadMine()
                default: await model.loadApplicants(teamID: teamID)
                }
            }.value
            XCTAssertEqual(model.review?.id, reviewID)
            XCTAssertEqual(read.requests, requests)
            XCTAssertFalse(model.busy)
            XCTAssertFalse(model.uncertain)
        }
    }

    func testCancelledApplicantReadPreservesRowsAndAllowsExplicitRefresh() async {
        for unauthorized in [false, true] {
            let (model, read) = make()
            await model.loadNearby(context)
            await model.loadApplicants(teamID: teamID)
            let ids = model.applicants.map(\.id)
            XCTAssertFalse(ids.isEmpty)
            let revision = model.revision
            read.cancelNext = true
            read.unauthorizedNext = unauthorized
            await Task { @MainActor in
                await model.loadApplicants(teamID: teamID)
            }.value
            XCTAssertEqual(model.applicants.map(\.id), ids)
            XCTAssertEqual(model.applicantsTeamID, teamID)
            XCTAssertEqual(model.session, session)
            XCTAssertEqual(model.revision, revision)
            XCTAssertNil(model.messageKey)
            XCTAssertFalse(model.busy)
            XCTAssertFalse(model.uncertain)
            let count = read.requests
            await model.loadApplicants(teamID: teamID)
            XCTAssertEqual(read.requests, count + 1)
            XCTAssertEqual(model.applicants.map(\.id), ids)
            XCTAssertEqual(model.revision, revision + 1)
        }
    }

    func testTransportCancellationWithoutTaskCancellationPreservesApplicants() async {
        let (model, read) = make()
        await model.loadNearby(context)
        await model.loadApplicants(teamID: teamID)
        let ids = model.applicants.map(\.id)
        let revision = model.revision
        read.cancellationErrorNext = true
        await model.loadApplicants(teamID: teamID)
        XCTAssertFalse(Task.isCancelled)
        XCTAssertEqual(model.applicants.map(\.id), ids)
        XCTAssertEqual(model.applicantsTeamID, teamID)
        XCTAssertEqual(model.revision, revision)
        XCTAssertEqual(model.session, session)
        XCTAssertNil(model.messageKey)
        XCTAssertFalse(model.busy)
        XCTAssertFalse(model.uncertain)
    }

    func testUncancelledUnauthorizedStillWithdrawsPrivateProjection() async {
        let (model, read) = make()
        await model.loadNearby(context)
        await model.loadApplicants(teamID: teamID)
        read.unauthorizedNext = true
        await model.loadApplicants(teamID: teamID)
        XCTAssertNil(model.session)
        XCTAssertTrue(model.teams.isEmpty)
        XCTAssertTrue(model.applicants.isEmpty)
        XCTAssertNil(model.applicantsTeamID)
        XCTAssertEqual(model.messageKey, "nearby.signIn")
        XCTAssertFalse(model.busy)
    }
}

@MainActor private final class NearbyCancelledReadTransport: NearbyTeamReadTransport {
    var requests = 0
    var cancelNext = false
    var cancellationErrorNext = false
    var unauthorizedNext = false
    func sendRead(_ request: NearbyTeamRequest, session: NearbyTeamSession) async throws -> NearbyTeamResponse {
        requests += 1
        if cancellationErrorNext { cancellationErrorNext = false; throw CancellationError() }
        let cancel = cancelNext, unauthorized = unauthorizedNext
        cancelNext = false; unauthorizedNext = false
        if cancel { withUnsafeCurrentTask { $0?.cancel() } }
        if unauthorized { throw NearbyTeamFailure.unauthorized }
        switch request.path {
        case "/api/team/nearby":
            return NearbyTeamSyntheticFixtures.response(NearbyTeamSyntheticFixtures.teams)
        case "/api/team/applications":
            return NearbyTeamSyntheticFixtures.response(NearbyTeamSyntheticFixtures.applicants)
        case "/api/team/my-applications":
            return NearbyTeamSyntheticFixtures.response(NearbyTeamSyntheticFixtures.applications)
        default: throw NearbyTeamFailure.invalidRequest
        }
    }
}
