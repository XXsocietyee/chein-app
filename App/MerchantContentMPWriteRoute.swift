import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// MP-first (owner 2026-11-25, R7-PC-B2-1 / R7-PC-B3-1): composition admission for the merchant-content writes
/// `MerchantContentService` sends once `MerchantContentWriteApproval` permits them. Exact paths from
/// `MerchantContentCommand.request()`; chapter invite / respond keep their own `ChapterWriteExit`.
/// `api/game/session/command` is admitted here only for merchant station actions; team item commands keep the play lease.
/// None of these is money; the server's own permission checks decide.
enum MerchantContentMPWriteRoute {
    static let paths: Set<String> = [
        "api/circle-theme/instance/review",
        "api/merchant/chapter-application/apply", "api/merchant/chapter-application/withdraw",
        "api/merchant/chapter-application/audit",
        "api/registration/merchant/create", "api/registration/merchant/update", "api/registration/merchant/cancel",
        "api/merchant/chapter-node/submit", "api/merchant/chapter-node/audit",
        "api/merchant/city-node/claim", "api/merchant/city-node/claim/cancel", "api/merchant/city-node/offline",
        "api/merchant/city-node/save",
        "api/merchant/chapter-node/npc/save", "api/merchant/chapter-node/npc/voice/enroll",
        "api/merchant/chapter-node/npc/voice/reset"
    ]
    static let stationPath = "api/game/session/command"
    static let stationActions: Set<String> = Set(MerchantStationAction.allCases.map(\.rawValue))

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token), request.httpMethod == "POST",
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.httpBodyStream == nil, let body = request.httpBody, !body.isEmpty,
              let url = request.url, url.query == nil, url.fragment == nil, url.user == nil, url.password == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port else { return false }
        func exact(_ path: String) -> Bool { url.path == baseURL.appendingPathComponent(path).path }
        if paths.contains(where: exact) { return true }
        guard exact(stationPath),
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let action = object["action"] as? String else { return false }
        return stationActions.contains(action)
    }
}
