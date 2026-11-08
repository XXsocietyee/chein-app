import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// ADAPT-3 (B1 `api/club/group-code`): `POST /api/verify/groupcode/issue` binds `Long activityId`
// as a plain Spring request parameter (ApiVerifyController, no @RequestBody), so a JSON body is
// ignored and the backend answers `参数缺失`. This adapter sends the parameter form-encoded.
// It is not wired anywhere and holds no approval. The existing JSON path is left untouched.

public struct Adapt3GroupCodeFact: Equatable {
    public let code: String
    public let qrcodeUrl: String
    public let ttlMs: Int64
    public let activityId: Int
}

public struct Adapt3GroupCodeIssueAdapter {
    public static let path = "api/verify/groupcode/issue"
    private let baseURL: URL
    private let token: String
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: String, transport: any HTTPTransport) throws {
        guard AuthRequestBuilder.isValidToken(token), baseURL.host != nil else { throw APIError.invalidRequest }
        self.baseURL = baseURL; self.token = token; self.transport = transport
    }

    public func request(activityID: Int) throws -> URLRequest {
        guard activityID > 0 else { throw APIError.invalidRequest }
        var request = URLRequest(url: baseURL.appendingPathComponent(Self.path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = Data("activityId=\(activityID)".utf8)
        return request
    }

    /// The backend signs a fresh token on every call and persists nothing, so a retry is safe
    /// but yields a different code; callers must not treat two answers as one receipt.
    public func issue(activityID: Int) async throws -> Adapt3Outcome<Adapt3GroupCodeFact> {
        let request = try request(activityID: activityID)
        guard !Task.isCancelled else { return .unknown }
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) } catch { return .unknown }
        return Adapt3ClubBackendClient.interpret(data: data, status: status) { payload, _ in
            guard let payload, let code = payload["code"] as? String, !code.isEmpty,
                  let url = payload["qrcodeUrl"] as? String, !url.isEmpty,
                  let ttl = payload["ttlMs"] as? NSNumber, CFGetTypeID(ttl) != CFBooleanGetTypeID(), ttl.int64Value > 0,
                  let activity = payload["activityId"] as? NSNumber, CFGetTypeID(activity) != CFBooleanGetTypeID(),
                  activity.intValue == activityID else { return nil }
            return Adapt3GroupCodeFact(code: code, qrcodeUrl: url, ttlMs: ttl.int64Value, activityId: activity.intValue)
        }
    }
}
