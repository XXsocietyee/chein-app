import XCTest
@testable import Questify

/// MP club-director-role-sheet (director.js:121-160, 311-334, 1062-1224; index.js:919-933).
@MainActor final class PlayDirectorRoleSheetTests: XCTestCase {
    private func projection() throws -> PlayDirectorProjection {
        let raw = try PlayExperienceSyntheticFixtures.wire(#"{"perspective":"CLUB","activityId":41,"sessionId":501,"revision":2,"status":"RUNNING","availableActions":["ASSIGN_ROLES","TAKEOVER_ROLE"],"club":{"roleOptions":[{"roleCode":"SCOUT","roleName":"Scout"},{"roleCode":"MEDIC","roleName":"Medic"}],"roles":[{"teamId":61,"memberId":1,"memberName":"Ann","roleCode":"SCOUT","roleName":"Scout","confirmationStatus":"CONFIRMED"},{"teamId":61,"memberId":2,"memberName":"Bo"},{"teamId":61,"memberId":3,"roleCode":"MEDIC","confirmationStatus":"PENDING"},{"teamId":62,"memberId":4,"memberName":"Cy"}]}}"#)
        return try PlayDirectorProjection(raw, activityID: 41)
    }

    func testMembersOptionsAndTakeoverFollowMP() throws {
        let projection = try projection()
        XCTAssertEqual(PlayDirectorRoles.members(projection).map(\.id), ["61:1", "61:2", "61:3", "62:4"])
        XCTAssertEqual(PlayDirectorRoles.members(projection, teamID: 62).map(\.id), ["62:4"])
        XCTAssertEqual(PlayDirectorRoles.options(projection).map(\.code), ["SCOUT", "MEDIC"])
        XCTAssertEqual(PlayDirectorRoles.takeoverSources(projection).map(\.id), ["61:1"])
        let source = try XCTUnwrap(PlayDirectorRoles.takeoverSources(projection).first)
        XCTAssertEqual(PlayDirectorRoles.takeoverTargets(projection, source: source).map(\.memberID), [2])
    }

    func testPayloadsMatchMP() throws {
        let projection = try projection()
        XCTAssertEqual(PlayDirectorRoles.assignPayload(teamID: 61, memberID: 2, roleCode: "MEDIC"),
                       ["teamId": .int(61), "assignments": .array([.object(["memberId": .int(2), "roleCode": .string("MEDIC")])])])
        XCTAssertNil(PlayDirectorRoles.assignPayload(teamID: 61, memberID: 2, roleCode: ""))
        let source = try XCTUnwrap(PlayDirectorRoles.takeoverSources(projection).first)
        XCTAssertEqual(PlayDirectorRoles.takeoverPayload(projection, source: source, targetMemberID: 2, reason: "  left early "),
                       ["teamId": .int(61), "sourceMemberId": .int(1), "targetMemberId": .int(2), "reason": .string("left early")])
        XCTAssertNil(PlayDirectorRoles.takeoverPayload(projection, source: source, targetMemberID: 2, reason: "  "))
        XCTAssertNil(PlayDirectorRoles.takeoverPayload(projection, source: source, targetMemberID: 3, reason: "ok"))
        XCTAssertNil(PlayDirectorRoles.takeoverPayload(projection, source: source, targetMemberID: 4, reason: "ok"))
    }
}
