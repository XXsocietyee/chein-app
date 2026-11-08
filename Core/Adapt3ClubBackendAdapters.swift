import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// ADAPT-3: transport-level adapters that map native club/receipt/admission operations onto the
// EXISTING hengyin `/api/club/*` routes (verified against hengyin@4ac8c249, ApiClubController and
// ApiClubRoleController). Nothing here is wired into AppSession / AppCompositionRoot, grants no
// approvals or leases, and does not touch the older receipt-shaped contract types.
//
// Backend contract facts used here (see docs/release/gap345/adapt-3-report.md):
// - Auth: raw token in the `Authorization` header (no `Bearer`), same as the other club services.
// - Every body is JSON (`@RequestBody`), never form-encoded, for the routes below.
// - Response envelope is `AjaxResult {code, msg, data}`; business errors are usually HTTP 200
//   with `code != 200`. There is no `errorCode`, `outcome_known` or `X-Club-*` header contract.
// - A club is a membership/community entity. These adapters never model a club as a channel.

/// Empty success payload for routes whose `data` is absent.
public struct Adapt3Empty: Equatable { public init() {} }

public enum Adapt3Outcome<Value: Equatable>: Equatable {
    /// `code == 200` and the payload satisfied the adapter's own checks.
    case applied(Value, message: String?)
    /// Backend answered with a business refusal (`code` is not 200/401/403/409). Several backend
    /// branches share `500`, so this alone does not prove nothing was written.
    case rejected(code: Int, message: String?)
    /// `code`/HTTP 409 (role routes use `ServiceException` 409 for stale/mismatching replays).
    case conflict(message: String?)
    case unauthorized
    case forbidden
    /// Transport failure, malformed envelope, or a 200 whose payload did not match the request.
    case unknown
}

public enum Adapt3LeaveFact: Equatable {
    case left
    /// Backend answered `已退出`/`未加入`; `未加入` means no membership row was removed.
    case notMember
}

public struct Adapt3ClubBackendClient {
    /// Message the backend returns from `/api/club/quit` when no membership row was removed.
    static let notMemberMessage = "未加入"
    /// Message `BaseController.error` returns for an anonymous principal on the club routes.
    static let notLoggedInMessage = "请先登录"
    static let reviewReasonMax = 500
    static let welcomeNoteMax = 200

    private let baseURL: URL
    private let token: String
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: String, transport: any HTTPTransport) throws {
        guard AuthRequestBuilder.isValidToken(token), baseURL.scheme != nil, baseURL.host != nil else {
            throw APIError.invalidRequest
        }
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    // MARK: - Request builders (pure, exposed for deterministic tests)

    /// `POST /api/club/join-request/approve|reject` with `{clubId, memberId, reviewReason?}`.
    /// The backend identifies a pending application by `(clubId, memberId)`; it has no application id,
    /// no `request_id`, and `reviewReason` is trimmed and limited to 500 characters.
    public func joinReviewRequest(approve: Bool, clubID: Int, memberID: Int, reviewReason: String?) throws -> URLRequest {
        guard clubID > 0, memberID > 0 else { throw APIError.invalidRequest }
        var fields: [String: Any] = ["clubId": clubID, "memberId": memberID]
        if let reviewReason {
            let trimmed = reviewReason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count <= Self.reviewReasonMax else { throw APIError.invalidRequest }
            if !trimmed.isEmpty { fields["reviewReason"] = trimmed }
        }
        return try makeRequest(path: approve ? "api/club/join-request/approve" : "api/club/join-request/reject", fields: fields)
    }

    /// `POST /api/club/quit` with `{id}`. The owner is refused by the backend (code 500), not by the client.
    public func leaveRequest(clubID: Int) throws -> URLRequest {
        guard clubID > 0 else { throw APIError.invalidRequest }
        return try makeRequest(path: "api/club/quit", fields: ["id": clubID])
    }

    /// `POST /api/club/open-settings/welcome-note` with `{id, welcomeNote}`. The write is a plain
    /// overwrite, so a body-identical resend is the recovery path (no receipt route exists).
    public func welcomeNoteRequest(clubID: Int, note: String) throws -> URLRequest {
        guard clubID > 0 else { throw APIError.invalidRequest }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.unicodeScalars.count <= Self.welcomeNoteMax else { throw APIError.invalidRequest }
        return try makeRequest(path: "api/club/open-settings/welcome-note", fields: ["id": clubID, "welcomeNote": trimmed])
    }

    /// `POST /api/club/detail` with `{id}` (read-back). `PublicClubVO.welcomeNote` is always a string.
    public func detailRequest(clubID: Int) throws -> URLRequest {
        guard clubID > 0 else { throw APIError.invalidRequest }
        return try makeRequest(path: "api/club/detail", fields: ["id": clubID])
    }

    /// Replay of `POST /api/club/roles/assign`. The DTO rejects unknown JSON fields
    /// (`@JsonAnySetter` throws), so there is no `expiresAtEpochMs`/`expiresAt` key at all.
    /// The backend replays an exact same `requestId` and returns the committed assignment.
    public func roleAssignRequest(clubID: Int, activityID: Int?, targetMemberID: Int, roleCode: String, requestID: String) throws -> URLRequest {
        guard clubID > 0, targetMemberID > 0, !roleCode.isEmpty,
              !requestID.trimmingCharacters(in: .whitespaces).isEmpty,
              activityID == nil || activityID! > 0 else { throw APIError.invalidRequest }
        var fields: [String: Any] = ["clubId": clubID, "targetMemberId": targetMemberID, "roleCode": roleCode, "requestId": requestID]
        if let activityID { fields["activityId"] = activityID }
        return try makeRequest(path: "api/club/roles/assign", fields: fields)
    }

    /// Replay of `POST /api/club/roles/revoke`: `{clubId, activityId?, assignmentId, version, reason, requestId}`.
    /// `reason` is required by the backend; the caller supplies the original reviewed text.
    public func roleRevokeRequest(clubID: Int, activityID: Int?, assignmentID: Int, version: Int, reason: String, requestID: String) throws -> URLRequest {
        guard clubID > 0, assignmentID > 0, version >= 0, version <= Int(Int32.max),
              !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !requestID.trimmingCharacters(in: .whitespaces).isEmpty,
              activityID == nil || activityID! > 0 else { throw APIError.invalidRequest }
        var fields: [String: Any] = ["clubId": clubID, "assignmentId": assignmentID, "version": version, "reason": reason, "requestId": requestID]
        if let activityID { fields["activityId"] = activityID }
        return try makeRequest(path: "api/club/roles/revoke", fields: fields)
    }

    // MARK: - Dispatch

    public func reviewJoinRequest(approve: Bool, clubID: Int, memberID: Int, reviewReason: String? = nil) async throws -> Adapt3Outcome<Adapt3Empty> {
        let request = try joinReviewRequest(approve: approve, clubID: clubID, memberID: memberID, reviewReason: reviewReason)
        return await dispatch(request) { _, _ in Adapt3Empty() }
    }

    public func leave(clubID: Int) async throws -> Adapt3Outcome<Adapt3LeaveFact> {
        let request = try leaveRequest(clubID: clubID)
        return await dispatch(request) { _, message in message == Self.notMemberMessage ? Adapt3LeaveFact.notMember : Adapt3LeaveFact.left }
    }

    /// Returns `.applied(saved)` only when the server read-back equals the trimmed request text.
    public func saveWelcomeNote(clubID: Int, note: String) async throws -> Adapt3Outcome<String> {
        let request = try welcomeNoteRequest(clubID: clubID, note: note)
        let expected = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return await dispatch(request) { data, _ in
            guard let saved = data?["welcomeNote"] as? String, saved == expected else { return nil }
            return saved
        }
    }

    public func readWelcomeNote(clubID: Int) async throws -> Adapt3Outcome<String> {
        let request = try detailRequest(clubID: clubID)
        return await dispatch(request) { data, _ in data?["welcomeNote"] as? String }
    }

    public func replayRoleAssignment(clubID: Int, activityID: Int?, targetMemberID: Int, roleCode: String, requestID: String) async throws -> Adapt3Outcome<Int> {
        let request = try roleAssignRequest(clubID: clubID, activityID: activityID, targetMemberID: targetMemberID, roleCode: roleCode, requestID: requestID)
        let scopeID = activityID ?? clubID
        let scopeType = activityID == nil ? "CLUB" : "EVENT"
        return await dispatch(request) { data, _ in
            guard let data, let id = Self.integer(data["id"]), id > 0,
                  Self.integer(data["targetMemberId"]) == targetMemberID,
                  data["roleCode"] as? String == roleCode,
                  data["scopeType"] as? String == scopeType,
                  Self.integer(data["scopeId"]) == scopeID,
                  Self.integer(data["version"]) == 0 else { return nil }
            return id
        }
    }

    public func replayRoleRevocation(clubID: Int, activityID: Int?, assignmentID: Int, version: Int, reason: String, requestID: String) async throws -> Adapt3Outcome<Adapt3Empty> {
        let request = try roleRevokeRequest(clubID: clubID, activityID: activityID, assignmentID: assignmentID, version: version, reason: reason, requestID: requestID)
        return await dispatch(request) { _, _ in Adapt3Empty() }
    }

    // MARK: - Response interpretation (pure)

    /// Maps HTTP status + `AjaxResult` envelope to an outcome. `payload` receives `data` as a
    /// dictionary (or nil when absent/not an object) and the envelope `msg`; returning nil means
    /// the 200 did not satisfy the adapter's checks, which is `.unknown`.
    public static func interpret<Value: Equatable>(data: Data, status: Int,
                                                   payload: ([String: Any]?, String?) -> Value?) -> Adapt3Outcome<Value> {
        if status == 401 { return .unauthorized }
        if status == 403 { return .forbidden }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = object?["msg"] as? String
        if status == 409 { return .conflict(message: message) }
        guard (200..<300).contains(status) else { return .unknown }
        guard let number = object?["code"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return .unknown }
        switch number.intValue {
        case 200:
            guard let value = payload(object?["data"] as? [String: Any], message) else { return .unknown }
            return .applied(value, message: message)
        case 401: return .unauthorized
        case 403: return .forbidden
        case 409: return .conflict(message: message)
        case let code:
            if message == notLoggedInMessage { return .unauthorized }
            return .rejected(code: code, message: message)
        }
    }

    // MARK: - Private

    private func dispatch<Value: Equatable>(_ request: URLRequest, payload: ([String: Any]?, String?) -> Value?) async -> Adapt3Outcome<Value> {
        guard !Task.isCancelled else { return .unknown }
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) } catch { return .unknown }
        return Self.interpret(data: data, status: status, payload: payload)
    }

    private func makeRequest(path: String, fields: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        return request
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return Int(exactly: number.int64Value)
    }
}
