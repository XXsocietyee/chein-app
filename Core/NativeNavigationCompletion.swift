import Foundation

public enum NativeRouteFailure: String, Equatable { case unsupported, malformed, cannotOpen
    /// Mini-program join links that still carry only the retired `?teamId=` (邀请链接已升级).
    case legacyTeamLink }
public struct TeamInvitationRoute: Equatable {
    public let code: String
    public let fromTeamID: Int?
    public init(code: String, fromTeamID: Int? = nil) throws {
        guard TeamLookup.validInvite(code), code.utf8.count <= 512,
              !code.contains("://"), fromTeamID.map({ $0 > 0 }) ?? true else { throw APIError.invalidRequest }
        self.code = code.trimmingCharacters(in: .whitespacesAndNewlines); self.fromTeamID = fromTeamID
    }
}
/// Source route paths, not an OS scheme registration or a domain approval. Query values
/// are presentation/invitation data only; they never imply ownership, role or entitlement.
public enum NativeNavigationContract {
    public static func parseInternal(_ text: String) -> NativeEntryIntent? {
        guard text.utf8.count <= 4096, !text.contains("\\"),
              !text.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
              let c = URLComponents(string: text), c.scheme == nil, c.host == nil,
              c.user == nil, c.password == nil, c.fragment == nil,
              !c.percentEncodedPath.lowercased().contains("%2e"),
              !c.path.split(separator: "/").contains(where: { $0 == ".." || $0 == "." }) else { return nil }
        return parse(path: c.percentEncodedPath, items: c.queryItems ?? [])
    }
    static func parse(path: String, items: [URLQueryItem]) -> NativeEntryIntent? {
        guard Set(items.map(\.name)).count == items.count, items.allSatisfy({ $0.value != nil }) else { return nil }
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        if path == "/team/join" {
            guard Set(query.keys).isSubset(of: ["code", "fromTeamId"]), let code = query["code"] else { return nil }
            var fromID: Int?
            if let raw = query["fromTeamId"] {
                guard let id = Int(raw), id > 0, String(id) == raw else { return nil }; fromID = id
            }
            return (try? TeamInvitationRoute(code: code, fromTeamID: fromID)).map(NativeEntryIntent.teamInvitation)
        }
        if path == "/pages/team/join/index" {
            // The mini-program share path. A code is an invitation; a lone positive teamId is the retired form.
            if let code = query["code"] {
                guard Set(query.keys).isSubset(of: ["code"]) else { return nil }
                return (try? TeamInvitationRoute(code: code)).map(NativeEntryIntent.teamInvitation)
            }
            // `?entry=code` is the MP manual 加入码 entry (C-J1): the code is typed on the page, not carried by the link.
            if query == ["entry": "code"] { return MiniProgramPageLink(path: path, query: query).map(NativeEntryIntent.miniProgramPage) }
            guard query.keys.sorted() == ["teamId"], let raw = query["teamId"], let id = Int(raw), id > 0, String(id) == raw else { return nil }
            return .routeError(.legacyTeamLink)
        }
        if let kind = NativeContentTarget.Kind.allCases.first(where: { $0.sourcePath == path }) {
            // CLB-detail-30 (MP club/detail js:3509-3545): the club share with `postId` and the 带票分享 topic card with
            // `sourceClubId` / `clubCode` are reviewed mini-program pages (MiniProgramPageLink checks every key and id).
            let keys = Set(query.keys)
            if (kind == .club && keys == ["id", "postId"]) || (kind == .topic && keys.contains("sourceClubId")) {
                return MiniProgramPageLink(path: path, query: query).map(NativeEntryIntent.miniProgramPage)
            }
            // Exactly one canonical positive `id`; extra keys, signs, padding or leading zeros are not a route.
            guard query.keys.sorted() == ["id"], let raw = query["id"], let id = Int(raw), String(id) == raw,
                  let target = NativeContentTarget(kind: kind, id: id) else { return nil }
            return .content(target)
        }
        if path == "/badge" {
            guard Set(query.keys).isSubset(of: ["name", "sub", "img", "style", "rarity"]),
                  query.values.allSatisfy({ $0.utf8.count <= 2048 && $0.rangeOfCharacter(from: .controlCharacters) == nil }) else { return nil }
            return .badge(ObjectBadgeDetailParameters(query: query, fallbackName: ""))
        }
        if path == "/pages/index/index", let door = homeReferral(query) { return .door(door) }
        if let page = MiniProgramPageLink(path: path, query: query) { return .miniProgramPage(page) }
        return nil
    }

    /// mp-nav r3: MP invite share card `/pages/index/index?inviter=<uid>` (older cards `?id=`; cy/profile index.js:2413,
    /// myinvite.js:25) and the home QR `?scene=`. MP home onLoad (index.js:37, 318, 355) keeps the inviter until sign-in,
    /// then `setInviter`. Same keys as the `/door` link; a non-numeric inviter is not a route.
    public static func homeReferral(_ query: [String: String]) -> DoorIntent? {
        guard !query.isEmpty, Set(query.keys).isSubset(of: ["scene", "inviter", "id"]) else { return nil }
        let referral = query["inviter"] ?? query["id"]
        if let referral, DoorParsing.inviter(referral) == nil { return nil }
        return DoorIntent(scene: query["scene"], inviter: referral)
    }
}
