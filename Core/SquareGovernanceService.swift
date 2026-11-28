import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Canned transports only. Never implement this marker on a network transport.
public protocol SquareGovernanceOfflineTransport: HTTPTransport {}
public enum SquareGovernanceCapability: String, CaseIterable, Hashable {
    case appeal, markRead, preferences, approveComment, deleteOwnComment
    init(_ action: SquareGovernanceAction) {
        switch action {
        case .appeal: self = .appeal
        case .markRead: self = .markRead
        case .preferences: self = .preferences
        case .approveComment: self = .approveComment
        case .deleteOwnComment: self = .deleteOwnComment
        }
    }
}
/// Composition-root grant, never derived from screen state, a role name, or network data.
public enum SquareGovernanceMutationGrant: Equatable {
    case disabled
    case reviewedInjection(Set<SquareGovernanceCapability>)
    var capabilities: Set<SquareGovernanceCapability> {
        if case .reviewedInjection(let values) = self { return values }; return []
    }
}
public struct SquareGovernanceService {
    let baseURL: URL
    let transport: any HTTPTransport
    let readsEnabled: Bool
    let mutationCapabilities: Set<SquareGovernanceCapability>
    public init(baseURL: URL, transport: any HTTPTransport, readsEnabled: Bool = false) {
        self.baseURL = baseURL; self.transport = transport; self.readsEnabled = readsEnabled; mutationCapabilities = []
    }
    /// Dormant concrete adapter for any HTTPTransport. A separately reviewed grant
    /// activates only listed operations; neither reads nor mutations default on.
    /// `SquareNotificationLease` is the shipped grant (list, mark-read, appeal).
    public init(dormantBaseURL: URL, transport: any HTTPTransport, readsEnabled: Bool = false, grant: SquareGovernanceMutationGrant = .disabled) {
        baseURL = dormantBaseURL; self.transport = transport; self.readsEnabled = readsEnabled
        mutationCapabilities = grant.capabilities
    }
    public init(offlineBaseURL: URL, transport: any SquareGovernanceOfflineTransport) {
        baseURL = offlineBaseURL; self.transport = transport; readsEnabled = true; mutationCapabilities = Set(SquareGovernanceCapability.allCases)
    }
    public var allowsInjectedWrites: Bool { !mutationCapabilities.isEmpty }
    public func allows(_ action: SquareGovernanceAction) -> Bool { mutationCapabilities.contains(SquareGovernanceCapability(action)) }
    func request(path: String, method: String, fields: [String: SquareGovernanceJSON] = [:], query: [URLQueryItem] = [], token: String, form: Bool = false) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token), baseURL.scheme == "https", !path.contains("..") else { throw SquareGovernanceFailure.invalid }
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw APIError.invalidConfiguration }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw SquareGovernanceFailure.invalid }
        var request = URLRequest(url: url); request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if method != "GET" {
            if form {
                // Dart FormData.fromMap is multipart/form-data, not urlencoded JSON.
                let boundary = "SquareGovernanceBoundary"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                var body = ""
                for key in fields.keys.sorted() {
                    guard let value = fields[key]?.string else { throw SquareGovernanceFailure.invalid }
                    body += "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n"
                }
                body += "--\(boundary)--\r\n"; request.httpBody = Data(body.utf8)
            } else {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; request.httpBody = try encoder.encode(fields)
            }
        }
        return request
    }
    func read(path: String, limit: Int? = nil, cursor: Int? = nil, token: String, check: () throws -> Void) async throws -> SquareGovernanceJSON {
        guard readsEnabled else { throw SquareGovernanceFailure.disabled }
        var query: [URLQueryItem] = []
        if let limit { query.append(.init(name: "limit", value: String(limit))) }
        if let cursor { guard cursor > 0 else { throw SquareGovernanceFailure.invalid }; query.append(.init(name: "cursor", value: String(cursor))) }
        let request = try request(path: path, method: "GET", query: query, token: token)
        try Task.checkCancellation(); try check()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation(); try check()
        return try Self.decode(data, status: status, mutation: false)
    }
    public func enforcements(cursor: Int? = nil, token: String, check: () throws -> Void) async throws -> [SquareEnforcement] {
        let result = try await read(path: "api/v1/community/me/enforcements", limit: 30, cursor: cursor, token: token, check: check)
        guard let items = result["items"].array else { throw SquareGovernanceFailure.malformed }
        return try items.map { try SquareEnforcement(raw: $0) }
    }
    public func notifications(cursor: Int? = nil, token: String, check: () throws -> Void) async throws -> [SquareGovernanceNotification] {
        let result = try await read(path: "api/v1/community/notifications", limit: 50, cursor: cursor, token: token, check: check)
        guard let items = result["items"].array else { throw SquareGovernanceFailure.malformed }
        return try items.map { try SquareGovernanceNotification(raw: $0) }
    }
    public func preferences(token: String, check: () throws -> Void) async throws -> SquareGovernanceJSON {
        let result = try await read(path: "api/v1/community/notification-preferences", token: token, check: check)
        guard case .object = result else { throw SquareGovernanceFailure.malformed }; return result
    }
    func command(_ review: SquareGovernanceReview, token: String) throws -> URLRequest {
        switch review.action {
        case .appeal(let id, let reason):
            return try request(path: "api/v1/community/appeals", method: "POST", fields: ["enforcementId": .integer(id), "reason": .string(reason.trimmingCharacters(in: .whitespacesAndNewlines)), "evidenceAssetIds": .array([]), "requestId": .string(review.requestID)], token: token)
        case .markRead(let id):
            return try request(path: "api/v1/community/notifications/\(id)/read", method: "POST", fields: ["requestId": .string(review.requestID)], token: token)
        case .preferences(let values):
            return try request(path: "api/v1/community/notification-preferences", method: "PATCH", fields: Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, .bool($0.value)) }), token: token)
        case .approveComment(let postID, let commentID):
            guard let comment = review.snapshot.comments.first(where: { $0.id == commentID && $0.postID == postID }), let version = comment.version else { throw SquareGovernanceFailure.invalid }
            return try request(path: "api/v1/community/posts/\(postID)/comments/\(commentID)/approve", method: "POST", fields: ["expectedVersion": .integer(version), "requestId": .string(review.requestID)], token: token)
        case .deleteOwnComment(let id):
            guard let comment = review.snapshot.comments.first(where: { $0.id == id }), comment.generation != .unknown else { throw SquareGovernanceFailure.invalid }
            if comment.generation == .communityV1 {
                guard let version = comment.version else { throw SquareGovernanceFailure.invalid }
                return try request(path: "api/v1/community/posts/\(comment.postID)/comments/\(id)", method: "DELETE", fields: ["expectedVersion": .integer(version), "requestId": .string(review.requestID)], token: token)
            }
            return try request(path: "api/comment/delete", method: "POST", fields: ["id": .string(String(id))], token: token, form: true)
        }
    }
    func dispatch(_ review: SquareGovernanceReview, token: String, release: () -> Void = {}, check: () throws -> Void) async throws -> SquareGovernanceReceipt {
        guard allows(review.action) else { throw SquareGovernanceFailure.disabled }
        let request = try command(review, token: token)
        try Task.checkCancellation(); try check()
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) } catch { throw SquareGovernanceFailure.unknown }
        // Once dispatched, cancellation cannot prove non-execution or release the original lock.
        do { try Task.checkCancellation(); try check() } catch { throw SquareGovernanceFailure.unknown }
        if case .appeal = review.action {
            // MP post-governance settles an appeal as `rejected` (new appeal allowed) on a definite refusal,
            // and reads back on 409 (an appeal for this enforcement already exists) like any unknown result.
            switch Self.appealOutcome(data, status: status) {
            case .rejected:
                release()
                let body = try? JSONDecoder().decode(SquareGovernanceJSON.self, from: data)
                let code = body?["code"].int ?? body?["code"].string.flatMap(Int.init)
                if status == 401 || code == 401 { throw SquareGovernanceFailure.signedOut }
                if status == 403 || code == 403 { throw SquareGovernanceFailure.forbidden }
                throw SquareGovernanceFailure.appealRefused(message: Self.refusalMessage(body))
            case .alreadyExists: throw SquareGovernanceFailure.unknown
            case .other: break
            }
        }
        _ = try Self.decode(data, status: status, mutation: true)
        // Ajax success is acknowledgement only: no invented appeal result, deletion or approval.
        return .acknowledgedNeedsRefresh
    }
    enum AppealOutcome: Equatable { case rejected, alreadyExists, other }
    /// MP `requestError(res, '申诉未提交')` → `safeUserMessage`: the server `msg` / `message` when it is a short
    /// business sentence; nil (the caller's fallback copy) for empty, long, diagnostic or developer-only text.
    static func refusalMessage(_ body: SquareGovernanceJSON?) -> String? {
        let raw = (body?["msg"].string ?? body?["message"].string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw.count <= 60, raw.rangeOfCharacter(from: .newlines) == nil, !raw.contains("\t") else { return nil }
        let unsafePatterns = [
            #"认证失败|无法访问系统资源|timeout|超时"#,
            #"lifecycle|sellingStartedAt|saleEndAt|拒绝售卖|不可再售"#,
            #"Exception|java\.|SQL|database|JSON|HttpMessage|CHENGYIN_|配置缺失|cannot be cast"#,
            #"^[^，,。;；]*(参数错误|参数异常|数据异常|系统错误|系统异常|UNKNOWN|undefined)[^，,。;；]*$"#,
            #"errMsg|:fail\b|<\s*/?\s*(html|body|head|script|style|title)\b|https?://|/api/|/(Users|home|var|etc|opt)/"#,
            #"\b(select|insert|update|delete)\b.+\b(from|into|set|where)\b"#,
            #"\b(bearer|authorization|token|password|secret|openid|unionid|cookie|session(id)?|sid)\b\s*[:=]"#,
            #"\b(trace|request|span|correlation)[_-]?id\b"#,
            #"\b1[3-9]\d{9}\b|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        ]
        for pattern in unsafePatterns where raw.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        return raw
    }
    /// MP `post-governance/index.js` submit: HTTP 2xx with a body code other than 200 is a refusal
    /// (409 reads back); HTTP 4xx other than 408 / 409 is a refusal; everything else stays unknown.
    static func appealOutcome(_ data: Data, status: Int) -> AppealOutcome {
        let body = try? JSONDecoder().decode(SquareGovernanceJSON.self, from: data)
        let code = body?["code"].int ?? body?["code"].string.flatMap(Int.init)
        if (200..<300).contains(status) {
            guard let code, code != 200 else { return .other }
            return code == 409 ? .alreadyExists : .rejected
        }
        if status == 409 { return .alreadyExists }
        if (400..<500).contains(status), status != 408 { return .rejected }
        return .other
    }
    static func decode(_ data: Data, status: Int, mutation: Bool) throws -> SquareGovernanceJSON {
        let body = try? JSONDecoder().decode(SquareGovernanceJSON.self, from: data)
        let code = body?["code"].int ?? body?["code"].string.flatMap(Int.init)
        if status == 401 || code == 401 { throw SquareGovernanceFailure.signedOut }
        if status == 403 || code == 403 { throw SquareGovernanceFailure.forbidden }
        if let code, code != 200 { throw SquareGovernanceFailure.rejected(code) }
        guard (200..<300).contains(status), code == 200, let body else { throw mutation ? SquareGovernanceFailure.unknown : .malformed }
        return body["data"]
    }
}

/// Plan M-11a: the notification list, mark-read and appeal the China routes already serve.
/// Preference writes sit on that lease only when the caller has the community writer and the
/// preference route is admitted. Comment approve and comment delete stay off. Reads stay off
/// when any of the three routes is not admitted, including when a money switch blocks the path.
public enum SquareNotificationLease {
    public static let listPath = "/api/v1/community/notifications"
    public static let readPath = "/api/v1/community/notifications/{}/read"
    public static let appealPath = "/api/v1/community/appeals"
    public static let preferencePath = "/api/v1/community/notification-preferences"
    public static let capabilities: Set<SquareGovernanceCapability> = [.markRead, .appeal]

    public static var routesLive: Bool {
        ChinaReviewedRouteCapability.admitsChinaProductionCall(listPath)
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(readPath)
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(appealPath)
    }

    public static func service(baseURL: URL, transport: any HTTPTransport, preferenceWrites: Bool = false) -> SquareGovernanceService {
        let live = routesLive
        var granted = live ? capabilities : []
        if live, preferenceWrites, ChinaReviewedRouteCapability.admitsChinaProductionCall(preferencePath) {
            granted.insert(.preferences)
        }
        return SquareGovernanceService(dormantBaseURL: baseURL, transport: transport, readsEnabled: live,
                                       grant: granted.isEmpty ? .disabled : .reviewedInjection(granted))
    }
}
