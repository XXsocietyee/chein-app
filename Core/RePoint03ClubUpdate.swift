import Foundation

// RePoint 03 - Club profile update adapter. NOT COMPILED.
// iOS route `api/club/update` (native-only) -> production `POST /api/club/update-mine`, JSON body (@RequestBody Club).
// Evidence: ApiClubController.java:457 (chengyin), components/cy/scene-club-edit/index.js:255.
// Not money movement. Gated by whatever gate already guards the iOS `club.create_edit` surface.

public enum RePoint03ClubUpdateError: Error, Equatable { case malformed, notSaved(String) }

public enum RePoint03ClubUpdateAdapter {
    public static let path = "api/club/update-mine"
    public static let method = "POST"

    /// Builds the production JSON body from the existing draft. `id` is required (multi-club accounts).
    /// Operation-config fields are sent only when the owner changed them (server rejects admins that send them).
    public static func body(clubID: Int, draft: ClubOperationsDraft, operationConfigChanged: Bool) throws -> Data {
        guard clubID > 0 else { throw RePoint03ClubUpdateError.malformed }
        var f: [String: Any] = [
            "id": clubID, "name": draft.name, "city": draft.city, "description": draft.description,
            "keywords": draft.keywords, "style": draft.style, "clubType": draft.clubType,
            "activityPrefs": draft.activityPrefs, "logo": draft.logo, "cover": draft.cover,
            "joinPolicy": draft.joinPolicy
        ]
        if operationConfigChanged {
            guard let quota = draft.memberReservedQuota.isEmpty ? 0 : Int(draft.memberReservedQuota), quota >= 0 else {
                throw RePoint03ClubUpdateError.malformed
            }
            f["operationConfigUpdated"] = true
            f["prioritySignupEnabled"] = draft.prioritySignupEnabled ? 1 : 0
            f["memberReservedQuota"] = quota
        }
        return try JSONSerialization.data(withJSONObject: f, options: [.sortedKeys])
    }

    /// Response: `{code:200,msg:"已保存",data:{joinPolicySupported:Bool,joinPolicy:Int}}`; failures are `{code:500,msg}`.
    public struct Saved: Equatable { public let joinPolicySupported: Bool; public let joinPolicy: Int }
    public static func decode(_ data: Data) throws -> Saved {
        struct Env: Decodable {
            let code: Int?; let msg: String?
            let data: D?
            struct D: Decodable { let joinPolicySupported: Bool?; let joinPolicy: Int? }
        }
        guard let env = try? JSONDecoder().decode(Env.self, from: data), let code = env.code else {
            throw RePoint03ClubUpdateError.malformed
        }
        guard code == 200 else { throw RePoint03ClubUpdateError.notSaved(env.msg ?? "") }
        guard let d = env.data, let s = d.joinPolicySupported, let p = d.joinPolicy else {
            throw RePoint03ClubUpdateError.malformed
        }
        return Saved(joinPolicySupported: s, joinPolicy: p)
    }
}
