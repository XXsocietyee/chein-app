import Foundation

/// RP-06 re-point (NOT COMPILED). Maps the club join-request flow onto the routes production serves
/// (`ApiClubController` /api/club/join, /join-request/approve, /join-request/reject; JSON bodies; mini-program
/// pages/club/detail/index.js:2246 and pages/club/join-requests/index.js:170).
/// Production has NO application id, NO request_id, NO invite id and NO cancel route. Anything the production
/// shape cannot express is refused (`.unsupported`), never guessed. It does not replace
/// `ChannelAdmissionGovernanceClient`; callers opt in behind the same gate.
public enum RePoint06ClubJoin {
    public static let joinPath = "api/club/join"
    public static let approvePath = "api/club/join-request/approve"
    public static let rejectPath = "api/club/join-request/reject"
    /// `guild_kind` value the existing admission code uses for clubs is owner-defined; the caller passes it in.
    public enum Failure: Error, Equatable { case unsupported, invalidID, malformed }

    public enum JoinState: Equatable { case pending, joined }

    /// Production: POST JSON {id, joinMessage}. Message trimmed, 60 chars like the mini-program, server cuts at 200.
    public static func joinBody(clubID: Int64, isClubKind: Bool, inviteID: Int64?, message: String?) throws -> Data {
        guard isClubKind, inviteID == nil else { throw Failure.unsupported }
        guard clubID > 0 else { throw Failure.invalidID }
        let text = String((message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        return try JSONSerialization.data(withJSONObject: ["id": clubID, "joinMessage": text], options: [.sortedKeys])
    }

    /// Production: POST JSON {clubId, memberId}. The iOS application id has no production meaning; callers supply
    /// the club and the applicant member id (from POST /api/club/join-requests rows). Remark/reject reason
    /// are not accepted by production, so a reason/note is refused rather than silently dropped.
    public static func reviewBody(clubID: Int64, memberID: Int64, note: String?, reasonCode: Int?) throws -> Data {
        guard clubID > 0, memberID > 0 else { throw Failure.invalidID }
        guard (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, reasonCode == nil else {
            throw Failure.unsupported
        }
        return try JSONSerialization.data(withJSONObject: ["clubId": clubID, "memberId": memberID], options: [.sortedKeys])
    }

    /// `AjaxResult`: `{code:200,msg,data:{state:"pending"|"joined"}}`. Missing/other state is malformed, never "joined".
    public static func parseJoin(_ data: Data) throws -> JoinState {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["code"] as? Int) == 200,
              let d = root["data"] as? [String: Any],
              let state = d["state"] as? String else { throw Failure.malformed }
        switch state {
        case "pending": return .pending
        case "joined": return .joined
        default: throw Failure.malformed
        }
    }

    /// Review routes return `{code:200,msg}` with no data key. Only an explicit 200 is success.
    public static func parseReview(_ data: Data) throws {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["code"] as? Int) == 200 else { throw Failure.malformed }
    }
}
