import Foundation

/// Per-entry role gates of mini-program `pages/club/detail` (`goClubRoles`, member management,
/// `goClubAppeal`, `goCooperation`). Read-only policy: it never performs a write and an absent
/// or foreign `access/me` grant only falls back to the legacy owner/admin flags.
public struct ClubDetailEntryGate: Equatable, Sendable {
    public let isOwner: Bool
    public let isJoined: Bool
    public let viewerIsAdmin: Bool
    public let signedIn: Bool
    public let permissions: Set<String>

    public init(clubID: Int, isOwner: Bool, isJoined: Bool, viewerIsAdmin: Bool, signedIn: Bool, grant: ClubDetailManageGrant?) {
        self.isOwner = isOwner; self.isJoined = isJoined; self.viewerIsAdmin = viewerIsAdmin; self.signedIn = signedIn
        // A grant for another club never widens this club's entries.
        permissions = grant?.clubID == clubID ? (grant?.permissions ?? []) : []
    }
    public init(club: ClubRecord, signedIn: Bool, grant: ClubDetailManageGrant?) {
        self.init(clubID: club.id, isOwner: club.isOwner, isJoined: club.isJoined, viewerIsAdmin: club.viewerIsAdmin, signedIn: signedIn, grant: grant)
    }
    private func has(_ code: String) -> Bool { permissions.contains(code) }
    public var canManageRoles: Bool { has("club:role:manage") }
    public var canManageMembers: Bool { has("club:member:manage") }
    public var canApproveMembers: Bool { has("club:member:approve") }
    public var canSendNotify: Bool { has("club:notify:send") }
    /// `wx:if="club.isOwner || canManageRoles"` for 角色与权限 and per-member 权限 buttons.
    public var showsRoleManagement: Bool { signedIn && (isOwner || canManageRoles) }
    /// 成员管理 (vs. read-only 成员): owner, legacy admin, or a member-management permission.
    public var showsMemberManagement: Bool {
        signedIn && (isOwner || viewerIsAdmin || canManageMembers || canManageRoles)
    }
    /// 处罚申诉 is for people who can be sanctioned in the club: joined members and owners.
    public var showsAppealEntry: Bool { signedIn && (isOwner || isJoined) }
    /// 合作 entry is for governors only.
    public var showsCooperationEntry: Bool { signedIn && (isOwner || viewerIsAdmin) }
}
