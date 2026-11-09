import XCTest
@testable import QuestifyCore

/// Second-pass parity for pages/team/detail + pages/team/join: error kinds, inline join retry
/// and the mini-program share path. Synthetic data only; authored, not run on Linux.
@MainActor final class TeamPageSecondPassTests: XCTestCase {
    private func coordinator(_ scenario: TeamSyntheticService.Scenario) throws -> TeamCoordinator {
        let service = try TeamSyntheticService(scenario: scenario)
        let session = try TeamSyntheticFixtures.session()
        return TeamCoordinator(service: service, journal: TeamMemoryJournal(), currentSession: { session })
    }

    func testFailureKindsMapLikeSource() {
        XCTAssertEqual(TeamReadFailureKind(URLError(.notConnectedToInternet)), .network)
        XCTAssertEqual(TeamReadFailureKind(TeamFailure.rejected(403)), .forbidden)
        XCTAssertEqual(TeamReadFailureKind(TeamFailure.rejected(500)), .data)
        XCTAssertEqual(TeamReadFailureKind(TeamFailure.unavailable), .data)
        XCTAssertEqual(TeamReadFailureKind(CancellationError()), .data)
    }

    func testNetworkAndForbiddenReadsSelectSourceStates() async throws {
        let offline = try coordinator(.networkFailure)
        await offline.loadDetail(.id(4101))
        XCTAssertEqual(offline.readFailure, .network)
        let state = TeamPagePresentation.blockingState(kind: .detail, messageKey: offline.messageKey, hasDetail: false, failure: offline.readFailure)
        XCTAssertEqual(state?.kind, .network); XCTAssertEqual(state?.titleKey, "team.page.offline"); XCTAssertEqual(state?.action, .reload)

        let denied = try coordinator(.forbidden)
        await denied.loadDetail(.invitation("SYNTHETIC-TEAM"))
        let deniedState = TeamPagePresentation.blockingState(kind: .invitation, messageKey: denied.messageKey, hasDetail: false, failure: denied.readFailure)
        XCTAssertEqual(deniedState?.kind, .noPermission); XCTAssertEqual(deniedState?.titleKey, "team.page.signInInvite"); XCTAssertEqual(deniedState?.action, .reload)

        let data = try coordinator(.failure)
        await data.loadDetail(.id(4101))
        XCTAssertEqual(TeamPagePresentation.blockingState(kind: .detail, messageKey: data.messageKey, hasDetail: false, failure: data.readFailure)?.kind, .unavailable)
    }

    func testLoadedDetailPhaseUsesServerCountsAndFailureIsNotZero() async throws {
        let ready = try coordinator(.content)
        await ready.loadDetail(.id(4101))
        XCTAssertFalse(ready.loading)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: ready.loading, detail: ready.detail, readFailed: ready.readFailure != nil), .ready)
        let detail = try XCTUnwrap(ready.detail)
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: detail.team.joinedCount, maximum: detail.team.maxMembers), "2 / 4")

        let failed = try coordinator(.failure)
        await failed.loadDetail(.id(4101))
        XCTAssertNil(failed.detail)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: failed.loading, detail: failed.detail, readFailed: failed.readFailure != nil), .error)
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: nil, maximum: nil), "—")
    }

    func testSuccessfulReadClearsFailureKind() async throws {
        let retry = try coordinator(.retry)
        await retry.loadDetail(.id(4101)); XCTAssertEqual(retry.readFailure, .data)
        await retry.loadDetail(.id(4101)); XCTAssertNil(retry.readFailure); XCTAssertNotNil(retry.detail)
    }

    func testRejectedJoinOffersFreshReviewOnly() async throws {
        let flow = try coordinator(.invitationRejected)
        await flow.loadDetail(.invitation("SYNTHETIC-TEAM"))
        let action = TeamAction.join(teamID: 4101, inviteCode: "SYNTHETIC-TEAM")
        flow.prepare(action)
        let review = try XCTUnwrap(flow.review)
        await flow.confirm(review)
        XCTAssertEqual(flow.writeState, .rejected)
        XCTAssertTrue(TeamPagePresentation.showsJoinRetry(flow.writeState, page: .invitation))
        XCTAssertFalse(TeamPagePresentation.showsJoinRetry(flow.writeState, page: .detail))
        XCTAssertNil(flow.review, "nothing is resubmitted until the member reviews again")
        flow.prepare(action); XCTAssertNotNil(flow.review)
        for state in [TeamCoordinator.WriteState.unknown, .idle, .simulated, .acknowledged, .blocked] {
            XCTAssertFalse(TeamPagePresentation.showsJoinRetry(state, page: .invitation))
        }
    }

    func testJoinIndexFixtureKeepsOmittedCountsUnknown() throws {
        XCTAssertEqual(TeamJoinIndexFixtureData.page, "pages/team/join/index")
        let unknown = try TeamJoinIndexFixtureData.detail(TeamJoinIndexFixtureData.unknownCountJSON)
        XCTAssertNil(unknown.team.joinedCount)
        XCTAssertNil(unknown.team.maxMembers)
        XCTAssertEqual(TeamPagePresentation.memberCountText(unknown.team), "—")
        XCTAssertNotEqual(TeamPagePresentation.memberCountText(unknown.team), "0")
        let zero = try TeamJoinIndexFixtureData.detail(TeamJoinIndexFixtureData.emptyRosterJSON)
        XCTAssertEqual(zero.team.joinedCount, 0)
        XCTAssertEqual(TeamPagePresentation.memberCountText(zero.team), "0 / 4")
        XCTAssertTrue(TeamPagePresentation.rosterIsEmpty(zero))
        let ready = try TeamJoinIndexFixtureData.detail(TeamJoinIndexFixtureData.readyJSON)
        XCTAssertEqual(ready.team.inviteCode, TeamJoinIndexFixtureData.inviteCode)
        XCTAssertFalse(TeamPagePresentation.rosterIsEmpty(ready))
        XCTAssertEqual(TeamPagePresentation.memberCountText(ready.team), "2 / 4")
        let status = try TeamJoinIndexFixtureData.detail(TeamJoinIndexFixtureData.unknownStatusJSON)
        XCTAssertEqual(status.team.status, .unknown)
        XCTAssertEqual(status.team.joinMode, .unknown)
        XCTAssertNotEqual(status.team.status.rawValue, 0)
    }

    func testMiniProgramJoinPathAndLegacyTeamID() {
        guard case .teamInvitation(let route) = NativeNavigationContract.parseInternal("/pages/team/join/index?code=SYNTHETIC-TEAM") else { return XCTFail() }
        XCTAssertEqual(route.code, "SYNTHETIC-TEAM"); XCTAssertNil(route.fromTeamID)
        XCTAssertEqual(NativeNavigationContract.parseInternal("/pages/team/join/index?teamId=71"), .routeError(.legacyTeamLink))
        for bad in ["/pages/team/join/index", "/pages/team/join/index?teamId=0", "/pages/team/join/index?teamId=071",
                    "/pages/team/join/index?code=", "/pages/team/join/index?code=A&teamId=7", "/pages/team/join/index?teamId=7&role=leader",
                    "/pages/team/join/index?code=https://evil.example"] {
            XCTAssertNil(NativeNavigationContract.parseInternal(bad), bad)
        }
        // The existing native route keeps its exact contract.
        XCTAssertNil(NativeNavigationContract.parseInternal("/team/join?teamId=7"))
    }
}
