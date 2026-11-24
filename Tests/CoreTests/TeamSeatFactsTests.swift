import XCTest
@testable import QuestifyCore

/// U06-01/U06-03: B6 `seats` / `invite` / `viewer` on `/api/team/info` and coded write rejections. Synthetic data only.
@MainActor final class TeamSeatFactsTests: XCTestCase {
    private func detail(_ extra: [String: Any], joined: Bool = true, leader: Bool = false, members: [[String: Any]]? = nil) throws -> TeamDetail {
        var object: [String: Any] = ["team": ["id": 4101, "title": "Synthetic", "status": 0, "joinMode": 2, "joinedCount": 2, "maxMembers": 4],
                                     "members": members ?? [["memberId": 901, "memberName": "A", "role": 1], ["memberId": 902, "memberName": "B", "role": 0]],
                                     "joined": joined, "leader": leader]
        extra.forEach { object[$0.key] = $0.value }
        return try JSONDecoder().decode(TeamDetail.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testSeatRowsFollowMiniProgramAndOmitUnknown() throws {
        let value = try detail(["seats": ["capacity": 4, "occupied": 3, "available": 1, "paidOccupied": 2, "paidTicketMissing": 1, "pendingApplications": 0,
                                          "claimable": 9, "unpaidOccupied": 9]])
        let rows = TeamSeatPresentation.rows(value.seats)
        XCTAssertEqual(rows.map(\.kind), [.paid, .missing, .available]) // pending 0 is not drawn
        XCTAssertEqual(rows.first { $0.kind == .missing }?.warning, true)
        XCTAssertEqual(TeamSeatPresentation.openSeats(team: value.team, seats: value.seats), 1)

        let partial = try detail(["seats": ["available": "x", "paidOccupied": -1]])
        XCTAssertTrue(TeamSeatPresentation.rows(partial.seats).isEmpty)
        XCTAssertEqual(TeamSeatPresentation.openSeats(team: partial.team, seats: partial.seats), 2) // max - joined fallback

        let missing = try detail([:])
        XCTAssertNil(missing.seats); XCTAssertTrue(TeamSeatPresentation.rows(nil).isEmpty)
    }

    func testInviteLineReplaysServerDeadline() throws {
        XCTAssertEqual(TeamSeatPresentation.inviteLine(try detail(["invite": ["mode": "PUBLIC", "available": true, "expiresAt": "2030-05-02 10:00:00", "expired": false]]).invite),
                       .expires("2030-05-02 10:00:00"))
        XCTAssertEqual(TeamSeatPresentation.inviteLine(try detail(["invite": ["available": false, "expiresAt": "2030-05-02 10:00:00"]]).invite), .unavailable)
        XCTAssertNil(TeamSeatPresentation.inviteLine(try detail(["invite": ["available": true]]).invite))
    }

    func testInvitationPreviewMembersWithoutIdsDecodeButCannotBeTargets() throws {
        let preview = try detail(["viewer": ["joined": false, "leader": false, "applicationStatus": "KICKED", "canJoinWithCode": false,
                                             "joinBlockers": ["APPLY_REJECTED", "bad code"], "applyBlockers": []]],
                                 joined: false, members: [["memberName": "A", "role": 1], ["memberName": "B", "role": 0]])
        XCTAssertEqual(preview.members.map(\.id), [-1, -2])
        XCTAssertFalse(preview.members.contains(where: \.identified))
        XCTAssertFalse(TeamAction.remove(teamID: 4101, memberID: -2).isAllowed(detail: preview))
        XCTAssertEqual(preview.viewer?.joinBlockers, ["APPLY_REJECTED"])
        XCTAssertEqual(TeamSeatPresentation.blockerKey(preview.viewer, entry: .join), "team.blocker.APPLY_REJECTED")
        XCTAssertEqual(TeamSeatPresentation.applicationKey(preview.viewer), "team.viewer.application.KICKED")
        // A member must always receive ids.
        XCTAssertThrowsError(try detail([:], joined: true, members: [["memberName": "A", "role": 1]]))
    }

    func testDutyAndLeaveConsequenceSeparateCaptainFromMember() throws {
        let captain = try detail(["viewer": ["joined": true, "leader": true, "role": 1]], leader: true)
        let member = try detail(["viewer": ["joined": true, "leader": false, "role": 0]])
        XCTAssertEqual(TeamSeatPresentation.dutyKey(captain.viewer, detail: captain), "team.viewer.captain")
        XCTAssertEqual(TeamSeatPresentation.dutyKey(member.viewer, detail: member), "team.viewer.member")
        XCTAssertEqual(TeamSeatPresentation.consequenceKey(.leave(teamID: 4101), detail: captain), "team.leave.consequence.leader")
        XCTAssertEqual(TeamSeatPresentation.consequenceKey(.leave(teamID: 4101), detail: member), "team.leave.consequence.member")
        XCTAssertEqual(TeamSeatPresentation.consequenceKey(.disband(teamID: 4101), detail: captain), "team.disband.consequence")
    }

    func testCodedRejectionsBranchOnMachineCodeOnly() throws {
        let id = UUID()
        func body(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
        XCTAssertEqual(TeamHTTPService.decodeAcknowledgment(try body(["code": 500, "msg": "队长移交失败，请重试", "errorCode": "LEADER_HANDOVER_FAILED"]),
                                                            status: 200, action: .leave(teamID: 4101), operationID: id), .rejectedCode("LEADER_HANDOVER_FAILED"))
        XCTAssertEqual(TeamHTTPService.decodeAcknowledgment(try body(["code": 500, "msg": "x"]), status: 200, action: .leave(teamID: 4101), operationID: id), .rejected)
        XCTAssertEqual(TeamHTTPService.decodeAcknowledgment(try body(["code": 500, "errorCode": "队伍已满"]), status: 200, action: .leave(teamID: 4101), operationID: id), .rejected)
        XCTAssertEqual(TeamSeatPresentation.rejectionKey("INVITE_EXPIRED"), "team.reject.INVITE_EXPIRED")
        XCTAssertEqual(TeamSeatPresentation.rejectionKey("SOMETHING_NEW"), "team.rejected")
        XCTAssertEqual(TeamSeatPresentation.rejectionKey(nil), "team.rejected")
        XCTAssertTrue(TeamSeatPresentation.showsBuyTicket(errorCode: "TICKET_REQUIRED"))
        XCTAssertFalse(TeamSeatPresentation.showsBuyTicket(errorCode: "TEAM_FULL"))
        XCTAssertEqual(TeamSeatPresentation.buyTicketTitle, "去买这一场的票")
    }
}
