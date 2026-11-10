import XCTest
@testable import QuestifyCore

/// Mini-program pages/team/detail and pages/team/join facts. Synthetic data only.
final class TeamPagePresentationTests: XCTestCase {
    private func detail(status: Int = 0, joined: Bool? = true, leader: Bool? = true, joinMode: Int = 2, code: String? = "SYNTHETIC-TEAM", expire: String? = "2030-05-02 10:00:00", joinedCount: Int? = 2, maxMembers: Int? = 4, members: [[String: Any]]? = nil) throws -> TeamDetail {
        var team: [String: Any] = ["id": 4101, "title": "Synthetic", "status": status, "joinMode": joinMode]
        if let joinedCount { team["joinedCount"] = joinedCount }
        if let maxMembers { team["maxMembers"] = maxMembers }
        team["inviteCode"] = code; team["expireTime"] = expire
        var object: [String: Any] = ["team": team, "members": members ?? [["memberId": 901, "memberName": "A", "role": 1]]]
        object["joined"] = joined; object["leader"] = leader
        return try JSONDecoder().decode(TeamDetail.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testStatusChipAndModeHelpFollowSource() throws {
        XCTAssertTrue(TeamPagePresentation.statusIsLive(.recruiting)); XCTAssertTrue(TeamPagePresentation.statusIsLive(.full))
        for status in [TeamStatus.inProgress, .ended, .disbanded, .unknown] { XCTAssertFalse(TeamPagePresentation.statusIsLive(status)) }
        XCTAssertEqual(TeamPagePresentation.joinModeHelpKey(.publicApplication), "team.page.modeHelp.public")
        XCTAssertEqual(TeamPagePresentation.joinModeHelpKey(.invitation), "team.page.modeHelp.invitation")
        XCTAssertEqual(TeamPagePresentation.joinModeHelpKey(.unknown), "team.mode.unknown")
    }

    func testStartTextMatchesSourceFormatTime() {
        XCTAssertEqual(TeamPagePresentation.startText("2030-05-02 10:00:00", chinese: true), "5月2日 10:00")
        XCTAssertEqual(TeamPagePresentation.startText("2030-05-02 09:05", chinese: false), "May 2, 09:05")
        XCTAssertEqual(TeamPagePresentation.startText("2030/12/31 23:59", chinese: true), "12月31日 23:59")
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        XCTAssertEqual(TeamPagePresentation.startText("2030-05-02T02:00:00Z", chinese: true, displayZone: shanghai), "5月2日 10:00")
        XCTAssertEqual(TeamPagePresentation.startText("soon", chinese: true), "soon") // source shows unparseable text verbatim
        XCTAssertNil(TeamPagePresentation.startText("  ", chinese: true))
        XCTAssertNil(TeamPagePresentation.startText(nil, chinese: false))
    }

    func testDetailActionsMirrorWxml() throws {
        let leader = try detail()
        XCTAssertTrue(TeamPagePresentation.showsInviteEntry(leader))
        XCTAssertNil(TeamPagePresentation.joinRouteCode(leader))
        XCTAssertEqual(TeamPagePresentation.leaveLabelKey(leader), "team.page.leaveAndTransfer")
        XCTAssertTrue(TeamPagePresentation.showsRefundNote(leader))
        let visitor = try detail(joined: false, leader: false)
        XCTAssertEqual(TeamPagePresentation.joinRouteCode(visitor), "SYNTHETIC-TEAM")
        XCTAssertEqual(TeamPagePresentation.leaveLabelKey(visitor), "team.leave")
        XCTAssertFalse(TeamPagePresentation.showsRefundNote(visitor))
        // An omitted membership fact never offers a join; nor does a closed team or a missing code.
        XCTAssertNil(TeamPagePresentation.joinRouteCode(try detail(joined: nil, leader: nil)))
        XCTAssertNil(TeamPagePresentation.joinRouteCode(try detail(status: 1, joined: false, leader: false)))
        XCTAssertNil(TeamPagePresentation.joinRouteCode(try detail(joined: false, leader: false, code: nil)))
        XCTAssertFalse(TeamPagePresentation.showsInviteEntry(try detail(status: 2)))
    }

    func testInvitationCTAStates() throws {
        XCTAssertEqual(TeamPagePresentation.invitationCTA(try detail()), .openDetail)
        XCTAssertEqual(TeamPagePresentation.invitationCTA(try detail(joined: false, leader: false)), .join)
        XCTAssertEqual(TeamPagePresentation.invitationCTA(try detail(status: 1, joined: false, leader: false)), .full)
        for status in [2, 3, 4, 98] { XCTAssertEqual(TeamPagePresentation.invitationCTA(try detail(status: status, joined: false, leader: false)), .ended) }
        XCTAssertEqual(TeamInvitationCTA.full.key, "team.page.full"); XCTAssertEqual(TeamInvitationCTA.ended.key, "team.page.ended")
    }

    func testBlockingStatesForBothPages() {
        let missing = TeamPagePresentation.blockingState(kind: .detail, messageKey: "team.invalidLink", hasDetail: false)
        XCTAssertEqual(missing?.titleKey, "team.page.linkIncomplete"); XCTAssertEqual(missing?.action, .goBack)
        XCTAssertEqual(TeamPagePresentation.blockingState(kind: .invitation, messageKey: "team.invalidLink", hasDetail: false)?.titleKey, "team.page.inviteIncomplete")
        XCTAssertEqual(TeamPagePresentation.blockingState(kind: .invitation, messageKey: "team.invalidLink", hasDetail: false, legacyTeamID: true)?.kind, .legacyLink)
        XCTAssertEqual(TeamPagePresentation.blockingState(kind: .detail, messageKey: "team.signIn", hasDetail: false)?.action, .signIn)
        XCTAssertEqual(TeamPagePresentation.blockingState(kind: .invitation, messageKey: "team.signIn", hasDetail: false)?.titleKey, "team.page.signInInvite")
        XCTAssertEqual(TeamPagePresentation.blockingState(kind: .detail, messageKey: "team.loadFailed", hasDetail: false)?.action, .reload)
        XCTAssertEqual(TeamPagePresentation.blockingState(kind: .detail, messageKey: "team.unconfigured", hasDetail: false)?.actionKey, nil)
        // A retained snapshot never becomes a full-page error; it gets the stale banner instead.
        XCTAssertNil(TeamPagePresentation.blockingState(kind: .detail, messageKey: "team.refreshFailed", hasDetail: true))
        XCTAssertEqual(TeamPagePresentation.staleBanner(kind: .detail, messageKey: "team.refreshFailed", hasDetail: true)?.title, "team.page.teamStale")
        XCTAssertEqual(TeamPagePresentation.staleBanner(kind: .invitation, messageKey: "team.refreshFailed", hasDetail: true)?.title, "team.page.inviteStale")
        XCTAssertNil(TeamPagePresentation.staleBanner(kind: .detail, messageKey: nil, hasDetail: true))
        XCTAssertNil(TeamPagePresentation.blockingState(kind: .detail, messageKey: nil, hasDetail: false))
    }

    func testLoadingCopy() {
        XCTAssertEqual(TeamPagePresentation.loadingKey(.detail, hasDetail: false), "team.page.loadingDetail")
        XCTAssertEqual(TeamPagePresentation.loadingKey(.invitation, hasDetail: false), "team.page.readingInvite")
        XCTAssertEqual(TeamPagePresentation.loadingKey(.detail, hasDetail: true), "team.loading")
        XCTAssertEqual(TeamPagePresentation.loadingKey(.invitation, hasDetail: true), "team.page.checkingInvite")
    }

    func testInvitationMemberCountUnknownIsEmDashAndZeroStaysZero() throws {
        XCTAssertEqual(TeamPagePresentation.unknownCountText, "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: nil, maximum: nil), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: nil, maximum: 4), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: 2, maximum: nil), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: -1, maximum: 4), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: 0, maximum: 4), "0 / 4")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: 2, maximum: 4), "2 / 4")
        XCTAssertNotEqual(TeamPagePresentation.memberCountText(joined: nil, maximum: 4), "0")
        XCTAssertNotEqual(TeamPagePresentation.memberCountText(joined: nil, maximum: 4), "0 / 4")
        let loaded = try detail(joined: false, leader: false)
        XCTAssertEqual(TeamPagePresentation.memberCountText(loaded.team), "2 / 4")
        XCTAssertFalse(TeamPagePresentation.rosterIsEmpty(loaded))
        var team: [String: Any] = ["id": 4101, "title": "Synthetic", "status": 0, "joinedCount": 0, "maxMembers": 4, "joinMode": 1]
        var object: [String: Any] = ["team": team, "members": [[String: Any]](), "joined": false, "leader": false]
        let empty = try JSONDecoder().decode(TeamDetail.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(TeamPagePresentation.rosterIsEmpty(empty))
        XCTAssertEqual(TeamPagePresentation.memberCountText(empty.team), "0 / 4")
        team = ["id": 4101, "title": "Synthetic", "status": 0, "joinMode": 1]
        object["team"] = team
        let unknown = try JSONDecoder().decode(TeamDetail.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(unknown.team.joinedCount)
        XCTAssertNil(unknown.team.maxMembers)
        XCTAssertEqual(TeamPagePresentation.memberCountText(unknown.team), "—")
        XCTAssertTrue(TeamPagePresentation.rosterIsEmpty(unknown))
    }

    func testInvitationReadoutSeparatesLoadingEmptyAndError() throws {
        XCTAssertEqual(TeamPagePresentation.invitationReadout(loading: true, detail: nil, messageKey: nil, failure: nil), .loading)
        XCTAssertEqual(TeamPagePresentation.invitationReadout(loading: false, detail: nil, messageKey: nil, failure: nil), .empty)
        let legacy = TeamPagePresentation.invitationReadout(loading: false, detail: nil, messageKey: "team.invalidLink", failure: nil, legacyTeamID: true)
        guard case .error(let state) = legacy else { return XCTFail("legacy link is an error") }
        XCTAssertEqual(state.kind, .legacyLink)
        let offline = TeamPagePresentation.invitationReadout(loading: false, detail: nil, messageKey: "team.loadFailed", failure: .network)
        guard case .error(let offlineState) = offline else { return XCTFail("network failure is an error") }
        XCTAssertEqual(offlineState.kind, .network)
        let loaded = try detail(joined: false, leader: false)
        XCTAssertEqual(TeamPagePresentation.invitationReadout(loading: true, detail: loaded, messageKey: nil, failure: nil), .ready)
        XCTAssertEqual(TeamPagePresentation.invitationReadout(loading: false, detail: loaded, messageKey: "team.refreshFailed", failure: .network), .ready)
    }

    func testInviteShareCardPayloadMatchesMiniProgramPath() throws {
        let payload = TeamInviteShareCardPayload(teamID: 4101, inviteCode: "SYNTHETIC-TEAM", title: "  ", canShareExternally: true)
        XCTAssertEqual(payload.teamID, 4101)
        XCTAssertEqual(payload.inviteCode, "SYNTHETIC-TEAM")
        XCTAssertEqual(payload.title, "一起出发的玩家队伍")
        XCTAssertEqual(payload.miniProgramPath, "/pages/team/join/index?code=SYNTHETIC-TEAM")
        XCTAssertTrue(payload.canShareExternally)

        let recruiting = try detail()
        let derived = TeamPagePresentation.inviteShareCard(recruiting)
        XCTAssertEqual(derived?.miniProgramPath, "/pages/team/join/index?code=SYNTHETIC-TEAM")
        XCTAssertEqual(derived?.title, "Synthetic")
        XCTAssertEqual(derived?.canShareExternally, false)
        XCTAssertNil(TeamPagePresentation.inviteShareCard(try detail(status: 1)))
        XCTAssertNil(TeamPagePresentation.inviteShareCard(try detail(code: nil)))
    }

    func testMemberCountUnknownIsEmDashAndLiteralZeroStaysZero() throws {
        XCTAssertEqual(TeamPagePresentation.unknownMetricDisplay, "\u{2014}")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: nil, maximum: 4), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: 2, maximum: nil), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: nil, maximum: nil), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: -1, maximum: 4), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: 2, maximum: 0), "—")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: 0, maximum: 4), "0 / 4")
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: 2, maximum: 4), "2 / 4")
        let omitted = try detail(joined: nil, leader: nil, joinedCount: nil, maxMembers: nil)
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: omitted.team.joinedCount, maximum: omitted.team.maxMembers), "—")
        XCTAssertNotEqual(TeamPagePresentation.memberCountText(joined: omitted.team.joinedCount, maximum: omitted.team.maxMembers), "0")
        XCTAssertNotEqual(TeamPagePresentation.memberCountText(joined: omitted.team.joinedCount, maximum: omitted.team.maxMembers), "0 / 0")
        XCTAssertNil(TeamPagePresentation.joinRouteCode(omitted))
        XCTAssertFalse(TeamAction.leave(teamID: omitted.team.id).isAllowed(detail: omitted))
        XCTAssertFalse(TeamAction.disband(teamID: omitted.team.id).isAllowed(detail: omitted))
        XCTAssertFalse(TeamAction.remove(teamID: omitted.team.id, memberID: 901).isAllowed(detail: omitted))
    }

    func testDetailPhaseCoversLoadingEmptyErrorUnknownAndReady() throws {
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: true, detail: nil, readFailed: false), .loading)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: true, detail: nil, readFailed: true), .loading)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: nil, readFailed: false), .empty)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: nil, readFailed: true), .error)
        let ready = try detail()
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: ready, readFailed: false), .ready)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: true, detail: ready, readFailed: false), .ready)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: ready, readFailed: true), .error)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: try detail(members: []), readFailed: false), .empty)
        let unknown = try detail(joinedCount: nil, maxMembers: 4)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: unknown, readFailed: false), .unknown)
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: unknown, readFailed: true), .unknown)
        let fixture = try TeamSyntheticFixtures.detail()
        XCTAssertEqual(TeamPagePresentation.detailPhase(loading: false, detail: fixture, readFailed: false), .ready)
        XCTAssertEqual(TeamPagePresentation.memberCountText(joined: fixture.team.joinedCount, maximum: fixture.team.maxMembers), "2 / 4")
    }
}
