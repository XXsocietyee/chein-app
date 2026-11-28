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
            // mp-nav r3: the MP place link is `poi-detail?poiId=` (poi-detail/index.js:4 "长期契约", mylike.js:435/680,
            // utils/place-share.js); `?id=` stays the native spelling. A lone canonical poiId is the same place.
            if kind == .poi, query.keys.sorted() == ["poiId"], let raw = query["poiId"], let id = Int(raw), String(id) == raw {
                return NativeContentTarget(kind: .poi, id: id).map(NativeEntryIntent.content)
            }
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
        if path == "/pages/index/index", let scene = homeScene(query) { return scene }
        if path == "/pages/index/index", let door = homeReferral(query) { return .door(door) }
        if let page = MiniProgramPageLink(path: path, query: query) { return .miniProgramPage(page) }
        return nil
    }

    /// mp-nav r3: MP invite share card `/pages/index/index?inviter=<uid>` (older cards `?id=`; cy/profile index.js:2413,
    /// myinvite.js:25) and the home QR `?scene=`. MP home onLoad (index.js:37, 318, 355) keeps the inviter until sign-in,
    /// then `setInviter`. Same keys as the `/door` link; a non-numeric inviter is not a route.
    /// mp-nav r3: MP home QR scenes (pages/index/index.js:353-375 `consumeDoorScene`, utils/game-door-entry.js):
    /// `tp.<topicId>` → topic detail, `ac.<activityId>` → official activity, `sh.<memberId>` → shop profile (about tab),
    /// `tm.<code>` / `th.<b64url>` → team join. MP redirects before it reads the inviter, so an inviter key is dropped too.
    /// `rc.` (merchant 招商位置) and the 32-hex door code stay on the door path.
    public static func homeScene(_ query: [String: String]) -> NativeEntryIntent? {
        guard let raw = query["scene"], Set(query.keys).isSubset(of: ["scene", "inviter", "id"]),
              let target = homeScenePath(raw) else { return nil }
        return parseInternal(target)
    }

    public static func homeScenePath(_ raw: String) -> String? {
        let text = (raw.removingPercentEncoding ?? raw).trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return nil }
        let prefix = parts[0]
        let body = parts[1]
        if prefix == "tm" || prefix == "th" {
            guard let code = teamSceneCode(prefix: prefix, body: body) else { return nil }
            return "/pages/team/join/index?code=" + code
        }
        let isDigits = (1...18).contains(body.utf8.count) && body.utf8.allSatisfy { (48...57).contains($0) }
        guard isDigits, let id = Int(body), id > 0 else { return nil }
        switch prefix {
        case "tp": return "/pages/topic/index/index?id=" + String(id)
        case "ac": return "/pages/activity/official-detail/index?id=" + String(id)
        case "sh": return "/pages/userinfo/userinfo?userId=" + String(id) + "&tab=about"
        default: return nil
        }
    }

    /// game-door-entry.js `teamCode`: `tm.` + six-letter join code or a 22-char base64url invite (as is);
    /// `th.` + 22-char base64url = a migrated 32-hex invite, restored to lowercase hex.
    static func teamSceneCode(prefix: String, body: String) -> String? {
        let shortAlphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ".utf8)
        if prefix == "tm", body.utf8.count == 6, body.utf8.allSatisfy({ shortAlphabet.contains($0) }) { return body }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)
        guard body.utf8.count == 22, body.utf8.allSatisfy({ alphabet.contains($0) }) else { return nil }
        if prefix == "tm" { return body }
        var bits = 0
        var value = 0
        var hex = ""
        for byte in body.utf8 {
            guard let v = alphabet.firstIndex(of: byte) else { return nil }
            value = ((value << 6) | v) & 0xFFFF
            bits += 6
            if bits >= 8 {
                bits -= 8
                hex += String(format: "%02x", (value >> bits) & 0xFF)
            }
        }
        return hex.utf8.count == 32 ? hex : nil
    }

    public static func homeReferral(_ query: [String: String]) -> DoorIntent? {
        guard !query.isEmpty, Set(query.keys).isSubset(of: ["scene", "inviter", "id"]) else { return nil }
        let referral = query["inviter"] ?? query["id"]
        if let referral, DoorParsing.inviter(referral) == nil { return nil }
        return DoorIntent(scene: query["scene"], inviter: referral)
    }
}
