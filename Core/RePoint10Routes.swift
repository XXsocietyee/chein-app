import Foundation

/// RP-10 re-point: iOS routes that production (hengyin 014fc0d8 / mini-program) does NOT serve under the iOS path.
/// NOT COMPILED. NEW FILE ONLY; existing Core files are untouched. Pure request-shape adapter:
/// it builds nothing that sends by itself and does not open any gate. Callers must stay behind the existing
/// feature gates / approvals (`RegionalHighRiskWriteRoute`, `Adapt5HighRiskWriteSupplement`, `BusinessRuntimeFeature`).
public enum RePoint10Status: String, Equatable, Sendable { case repointed, trueGap, needsOwner }

public struct RePoint10Mapping: Equatable, Sendable {
    public let iosPath: String
    public let productionMethod: String?
    public let productionPath: String?
    public let encoding: String?
    public let status: RePoint10Status
}

public enum RePoint10Routes {
    /// Production request for a repointed route. `nil` for TRUE-GAP / NEEDS-OWNER: UNKNOWN is never mapped to a guess.
    public static let table: [RePoint10Mapping] = {
        func gap(_ p: String) -> RePoint10Mapping { .init(iosPath: p, productionMethod: nil, productionPath: nil, encoding: nil, status: .trueGap) }
        return [
            .init(iosPath: "/api/ugc/block", productionMethod: "POST", productionPath: "/api/im/block", encoding: "form", status: .repointed),
            .init(iosPath: "/api/user/sms/send", productionMethod: "POST", productionPath: "/api/sms/send", encoding: "form", status: .repointed),
            .init(iosPath: "/api/us/auth/apple/exchange", productionMethod: nil, productionPath: nil, encoding: nil, status: .needsOwner),
            gap("/api/topic/edit-requests/read"), gap("/api/topic/edit-requests/resume-post-processing"),
            gap("/api/topic/edit-requests/submit"), gap("/api/topic/module-preflight"),
            gap("/api/us/auth/apple/challenges"), gap("/api/us/auth/session"),
            gap("/api/user/follow-list"), gap("/api/welcome-screen/get"),
            gap("/api/workshop/creator/pending-packages"), gap("/api/workshop/creator/public-theme-use"),
            gap("/api/workshop/owned"), gap("/api/workshop/owned/detail"), gap("/api/workshop/owned/list"),
            gap("/api/workshop/owned/package"),
            gap("/api/workshop/purchased/detail"), gap("/api/workshop/purchased/install"),
            gap("/api/workshop/purchased/installed-text/detail"), gap("/api/workshop/purchased/list"),
            gap("/api/workshop/purchased/professional-operations/cancel"),
            gap("/api/workshop/purchased/professional-operations/history"),
            gap("/api/workshop/purchased/professional-operations/status"),
            gap("/api/workshop/purchased/professional-operations/submit"),
            gap("/api/workshop/purchased/professional-targets/detail"),
            gap("/api/workshop/purchased/professional-targets/list"),
        ]
    }()

    public static func mapping(for iosPath: String) -> RePoint10Mapping? {
        let n = iosPath.hasPrefix("/") ? iosPath : "/" + iosPath
        return table.first { $0.iosPath == n }
    }

    /// Form-encoded production request. Returns nil unless the route is REPOINTED and the value is well formed.
    public static func formRequest(baseURL: URL, iosPath: String, fields: [String: String], token: String) -> URLRequest? {
        guard let m = mapping(for: iosPath), m.status == .repointed, m.encoding == "form",
              let path = m.productionPath, !token.isEmpty else { return nil }
        let required: [String: String] = ["/api/topic/info-to-user": "id", "/api/im/block": "target_member_id", "/api/sms/send": "phone"]
        guard let key = required[path], Set(fields.keys) == [key],
              let v = fields[key], !v.isEmpty else { return nil }
        if key != "phone" { guard let n = Int(v), n > 0, v == String(n) else { return nil } }
        var allowed = CharacterSet.urlQueryAllowed; allowed.remove(charactersIn: "&=+")
        var request = URLRequest(url: baseURL.appendingPathComponent(String(path.dropFirst())))
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if path != "/api/sms/send" { request.setValue(token, forHTTPHeaderField: "Authorization") } // sms is anonymous
        request.httpBody = Data("\(key)=\(v.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")".utf8)
        return request
    }

    /// `/api/topic/info-to-user` returns `AjaxResult{code,msg,data:TopicInfoVO}` (data key omitted when null).
    /// Map onto the existing `TopicDetail`; missing `data` or non-200 code is a failure, never an empty detail.
    public static func decodeTopicDetail(_ body: Data) throws -> TopicDetail {
        struct Env: Decodable { let code: Int; let data: TopicDetail? }
        guard let env = try? JSONDecoder().decode(Env.self, from: body) else { throw APIError.malformedResponse }
        if env.code == 401 { throw APIError.unauthorized }
        guard env.code == 200 else { throw APIError.businessCode(env.code) }
        guard let detail = env.data else { throw APIError.malformedResponse }
        return detail
    }
}
