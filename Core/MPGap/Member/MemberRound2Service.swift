import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round-2 Core service methods for `member` MP gaps:
/// `FIN-16-2`, `FIN-17-4`, `FIN-18-2`, `FIN-19-1`, `PLY-26-5`.
@MainActor
public final class MemberRound2Service {
    public static let paths: Set<String> = [
        "api/registration/list",
        "api/points/list",
        "api/withdrawal/list",
        "api/user/follow/action",
        "api/club/join",
        "api/template/my-list",
        "api/orient/scoring"
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
        json: [String: PlayWireValue]? = nil
    ) throws -> URLRequest {
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
            throw APIError.invalidRequest
        }
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
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

    /// `FIN-16-2`: `POST /api/registration/list`
    public func fetchOrdersPage(pageNum: Int, pageSize: Int = 20) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/registration/list",
            method: "POST",
            json: [
                "pageNum": .number(Double(pageNum)),
                "pageSize": .number(Double(pageSize)),
                "status": .string("0")
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `FIN-18-2`: `POST /api/points/list {}`
    public func fetchPointsList() async -> PlayerGapReply {
        guard let req = try? makeRequest("api/points/list", method: "POST", json: [:]) else {
            return .unauthorized
        }
        return await send(req)
    }

    /// `FIN-19-1`: `GET /api/withdrawal/list?pageNum=&pageSize=`
    public func fetchWithdrawalsPage(pageNum: Int, pageSize: Int = 20) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/withdrawal/list",
            method: "GET",
            query: ["pageNum": String(pageNum), "pageSize": String(pageSize)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `FIN-17-4`: `POST /api/user/follow/action {follow_member_id, follow}` / `POST /api/club/join {clubId}`
    public func followClubOwner(memberID: Int, follow: Bool = true) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/user/follow/action",
            method: "POST",
            json: [
                "follow_member_id": .number(Double(memberID)),
                "follow": .string(follow ? "1" : "0")
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    public func joinClub(clubID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/club/join",
            method: "POST",
            json: ["clubId": .number(Double(clubID))]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PLY-26-5`: `POST /api/template/my-list {operationScope}`
    public func fetchMyTemplates(scope: TemplateShelfOperationScope) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/template/my-list",
            method: "POST",
            json: ["operationScope": .string(scope.rawValue)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PLY-25-2`: `GET /api/orient/scoring?sessionId=`
    public func fetchOrientScoring(sessionID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/orient/scoring",
            method: "GET",
            query: ["sessionId": String(sessionID)]
        ) else { return .unauthorized }
        return await send(req)
    }
}
