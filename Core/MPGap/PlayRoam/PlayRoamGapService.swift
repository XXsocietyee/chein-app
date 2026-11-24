import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Network service for `play-roam` MP gaps (`PLAY-8`, `ROAM-9`, `RPOI-7`, `JSETTLE-3`).
@MainActor
public final class PlayRoamGapService {
    public static let paths: Set<String> = [
        "api/club/lead/start",
        "api/club/lead/settle",
        "api/registration/scan_group_member_ticket",
        "api/roam/nearby-runners",
        "api/roam/greet",
        "api/comment/delete",
        "api/topic/info-to-user"
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
        requireAuth: Bool = true
    ) throws -> URLRequest {
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requireAuth {
            guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
                throw APIError.invalidRequest
            }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        } else if let token = token(), AuthRequestBuilder.isValidToken(token) {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
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

    /// `PLAY-8`: `POST /api/club/lead/start {runId}`
    public func leadStart(runID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/club/lead/start",
            method: "POST",
            json: ["runId": .number(Double(runID))]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PLAY-8`: `POST /api/club/lead/settle {runId}`
    public func leadSettle(runID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/club/lead/settle",
            method: "POST",
            json: ["runId": .number(Double(runID))]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PLAY-8`: `POST /api/registration/scan_group_member_ticket {code}`
    public func scanGroupMemberTicket(code: String) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/registration/scan_group_member_ticket",
            method: "POST",
            json: ["code": .string(code)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `ROAM-9`: `GET /api/roam/nearby-runners?lat=&lng=`
    public func fetchNearbyRunners(latitude: Double, longitude: Double) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/roam/nearby-runners",
            method: "GET",
            query: ["lat": String(latitude), "lng": String(longitude)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `ROAM-9`: `POST /api/roam/greet {userId}`
    public func greetRunner(userID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/roam/greet",
            method: "POST",
            json: ["userId": .number(Double(userID))]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `RPOI-7`: `POST /api/comment/delete {id}`
    public func deleteComment(id: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/comment/delete",
            method: "POST",
            json: ["id": .number(Double(id))]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `JSETTLE-3`: `POST /api/topic/info-to-user {id}`
    public func fetchTopicInfo(topicID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/topic/info-to-user",
            method: "POST",
            json: ["id": .number(Double(topicID))],
            requireAuth: false
        ) else { return .unknown }
        return await send(req)
    }
}
