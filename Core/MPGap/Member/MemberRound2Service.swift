import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round-2 Core service methods for `member` MP gaps:
/// `FIN-16-2`, `FIN-17-4`, `FIN-18-2`, `FIN-19-1`, `PLY-26-5`.
@MainActor
public final class MemberRound2Service {
    public static let paths: Set<String> = [
        "api/registration/my-joined",
        "api/points/list",
        "api/withdrawal/list",
        "api/user/follow/action",
        "api/club/join",
        "api/template/my-list",
        "api/orient/scoring/session/{}"
    ]

    public let baseURL: URL
    private let token: () -> String?
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: @escaping () -> String?, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    func makeRequest(
        _ path: String,
        method: String,
        query: [String: String] = [:],
        json: [String: PlayWireValue]? = nil,
        form: [String: String]? = nil
    ) throws -> URLRequest {
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
            throw APIError.invalidRequest
        }
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidRequest
            }
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let built = components.url else { throw APIError.invalidRequest }
            url = built
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
        } else if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents()
            components.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
            request.httpBody = Data(encoded.utf8)
        }
        return request
    }

    private func send(_ request: URLRequest) async -> PlayerGapReply {
        do {
            let (data, status) = try await transport.send(request)
            return PlayerGapReply.classify(data: data, status: status)
        } catch {
            return .unknown
        }
    }

    /// `FIN-16-2`: `POST /api/registration/my-joined` (form `pageNum`, `pageSize`)
    public func fetchOrdersPage(pageNum: Int, pageSize: Int = 20) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/registration/my-joined",
            method: "POST",
            form: [
                "pageNum": String(pageNum),
                "pageSize": String(pageSize)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `FIN-18-2`: `POST /api/points/list` (form `{}`)
    public func fetchPointsList() async -> PlayerGapReply {
        guard let req = try? makeRequest("api/points/list", method: "POST", form: [:]) else {
            return .unauthorized
        }
        return await send(req)
    }

    /// `FIN-19-1`: `POST /api/withdrawal/list` (form `pageNum`, `pageSize`)
    public func fetchWithdrawalsPage(pageNum: Int, pageSize: Int = 20) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/withdrawal/list",
            method: "POST",
            form: ["pageNum": String(pageNum), "pageSize": String(pageSize)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `FIN-17-4`: `POST /api/user/follow/action` (form `follow_member_id`, `follow`) / `POST /api/club/join`
    public func followClubOwner(memberID: Int, follow: Bool = true) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/user/follow/action",
            method: "POST",
            form: [
                "follow_member_id": String(memberID),
                "follow": follow ? "1" : "0"
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    public func joinClub(clubID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/club/join",
            method: "POST",
            form: ["clubId": String(clubID)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PLY-26-5`: `POST /api/template/my-list` (form `operationScope`)
    public func fetchMyTemplates(scope: TemplateShelfOperationScope) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/template/my-list",
            method: "POST",
            form: ["operationScope": scope.rawValue]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PLY-25-2`: `GET /api/orient/scoring/session/{id}`
    public func fetchOrientScoring(sessionID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/orient/scoring/session/\(sessionID)",
            method: "GET"
        ) else { return .unauthorized }
        return await send(req)
    }
}
