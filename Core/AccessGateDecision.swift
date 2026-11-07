import Foundation

/// Pure decision of mini-program `utils/access-gate.js` (`decideMerchantGate` / `decideClubGate`).
/// Input is the already-read `access/me` answer; output is allow / deny / unknown. `unknown` means the
/// answer is unusable and the client must NOT block (the backend still does): a network problem is never
/// presented as "no permission". The guard must never be stricter than the backend.
public enum AccessGateDecision: Equatable {
    public enum DenyReason: Equatable {
        /// "请先登录" with HTTP 200 + code 500 (RuoYi `error`) means no principal at all, not a broken reply.
        case loginExpired
        case notMerchantMember
        case missingMerchantPosition
        case noClubAccess
        case notInThisClub
        case missingClubPermission
    }
    case allow
    case deny(DenyReason)
    case unknown

    /// Server message marker for "no signed-in principal".
    public static let noPrincipalMarker = "请先登录"

    private static func noPrincipal(_ message: String?) -> Bool { message?.contains(noPrincipalMarker) == true }

    /// Source `decideMerchantGate(res, need)`. `access` is the decoded body when the code was 200.
    /// A 200 reply without a decodable body is treated like the source's normalized "inactive" access.
    public static func merchant(code: Int?, message: String?, access: MerchantAccess?, need: MerchantAccess.Permission?) -> Self {
        guard code == 200 else {
            if noPrincipal(message) { return .deny(.loginExpired) }
            return code == 401 || code == 403 ? .deny(.notMerchantMember) : .unknown
        }
        guard let access, access.active else { return .deny(.notMerchantMember) }
        if let need, !access.allows(need) { return .deny(.missingMerchantPosition) }
        return .allow
    }

    /// The club `access/me` body fields the gate reads.
    public struct ClubAccess: Equatable {
        public let active: Bool?
        public let clubID: String?
        public let permissions: [String]
        public init(active: Bool?, clubID: String?, permissions: [String]) {
            self.active = active; self.clubID = clubID; self.permissions = permissions
        }
    }

    /// Source `decideClubGate(res, clubId, need)`. `access == nil` models a missing / non-object `data`.
    /// `active` absent is a bad reply (`unknown`); `active != true` denies; when a club id is required the
    /// reply must describe exactly that club; when a permission is required it must be listed.
    public static func club(code: Int?, message: String?, access: ClubAccess?, clubID: String?, need: String?) -> Self {
        guard code == 200, let access else {
            if noPrincipal(message) { return .deny(.loginExpired) }
            return code == 401 || code == 403 ? .deny(.noClubAccess) : .unknown
        }
        guard let active = access.active else { return .unknown }
        guard active else { return .deny(.noClubAccess) }
        if let clubID, !clubID.isEmpty, access.clubID != clubID { return .deny(.notInThisClub) }
        if let need, !need.isEmpty, !access.permissions.contains(need) { return .deny(.missingClubPermission) }
        return .allow
    }
}
