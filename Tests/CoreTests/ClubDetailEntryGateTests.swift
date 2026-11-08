#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class ClubDetailEntryGateTests: XCTestCase {
    private func gate(owner: Bool = false, joined: Bool = false, admin: Bool = false, signedIn: Bool = true,
                      permissions: Set<String>? = nil, grantClub: Int = 7) -> ClubDetailEntryGate {
        let grant = permissions.map { ClubDetailManageGrant(clubID: grantClub, permissions: $0, hasEventScope: false) }
        return ClubDetailEntryGate(clubID: 7, isOwner: owner, isJoined: joined, viewerIsAdmin: admin, signedIn: signedIn, grant: grant)
    }
    func testOwnerSeesRolesMembersAppealAndCooperation() {
        let owner = gate(owner: true)
        XCTAssertTrue(owner.showsRoleManagement); XCTAssertTrue(owner.showsMemberManagement)
        XCTAssertTrue(owner.showsAppealEntry); XCTAssertTrue(owner.showsCooperationEntry)
    }
    func testPlainMemberHasNoRoleOrCooperationEntryButCanAppeal() {
        let member = gate(joined: true)
        XCTAssertFalse(member.showsRoleManagement); XCTAssertFalse(member.showsMemberManagement)
        XCTAssertFalse(member.showsCooperationEntry); XCTAssertTrue(member.showsAppealEntry)
    }
    func testRolePermissionGrantOpensRolesWithoutAdminFlag() {
        let delegate = gate(joined: true, permissions: ["club:role:manage"])
        XCTAssertTrue(delegate.canManageRoles); XCTAssertTrue(delegate.showsRoleManagement); XCTAssertTrue(delegate.showsMemberManagement)
        XCTAssertFalse(delegate.showsCooperationEntry)
    }
    func testAdminManagesMembersButNotRolesWithoutPermission() {
        let admin = gate(joined: true, admin: true)
        XCTAssertTrue(admin.showsMemberManagement); XCTAssertFalse(admin.showsRoleManagement); XCTAssertTrue(admin.showsCooperationEntry)
    }
    func testForeignClubGrantNeverWidensEntries() {
        let foreign = gate(joined: true, permissions: ["club:role:manage", "club:member:manage"], grantClub: 8)
        XCTAssertFalse(foreign.showsRoleManagement); XCTAssertFalse(foreign.showsMemberManagement)
    }
    func testSignedOutSeesNoEntries() {
        let out = gate(owner: true, admin: true, signedIn: false)
        XCTAssertFalse(out.showsRoleManagement); XCTAssertFalse(out.showsAppealEntry)
        XCTAssertFalse(out.showsCooperationEntry); XCTAssertFalse(out.showsMemberManagement)
    }
    func testGrantRetainsPermissionsOnlyWhenActive() {
        XCTAssertEqual(ClubDetailManageGrant(clubID: 7, permissions: ["club:write"], hasEventScope: false).permissions, ["club:write"])
    }
}
#endif
