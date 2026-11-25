import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Network service for `player-content` MP gaps using the shared `HTTPTransport` and `PlayerGapReply`.
@MainActor
public final class PlayerContentGapService {
    public static let paths: Set<String> = [
        "api/template/topic-template/info",
        "api/play/nodes",
        "api/team/nearby",
        "api/free-explore/bundle/catalog",
        "api/club/event-ops/host/request",
        "api/topic/pricing/sale-status",
        "api/topic/pricing/settlement-pending",
        "api/orient/safety/check"
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
        form: [String: String]? = nil,
        requireAuth: Bool = true
    ) throws -> URLRequest {
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

    /// `PC-A-7-2`: `POST /api/template/topic-template/info` (form `id`)
    public func fetchTopicTemplatePreview(id: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/template/topic-template/info",
            method: "POST",
            form: ["id": String(id)],
            requireAuth: false
        ) else { return .unknown }
        return await send(req)
    }

    /// `PC-B-1-5`: `GET /api/play/nodes?topicId=`
    public func fetchTopicRouteNodes(topicID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/play/nodes",
            method: "GET",
            query: ["topicId": String(topicID)],
            requireAuth: false
        ) else { return .unknown }
        return await send(req)
    }

    /// `PC-B-1-5`: `GET /api/team/nearby?lat=&lng=&radius=`
    public func fetchTopicNearbyTeams(latitude: Double, longitude: Double, radius: Int = 20000) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/team/nearby",
            method: "GET",
            query: [
                "lat": String(latitude),
                "lng": String(longitude),
                "radius": String(radius)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-B-1-5`: `GET /api/free-explore/bundle/catalog?topicId=`
    public func fetchFreeExploreCatalog(topicID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/free-explore/bundle/catalog",
            method: "GET",
            query: ["topicId": String(topicID)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-C-2-3`: `POST /api/club/event-ops/host/request {activityId, ticketId}`
    public func requestHostReservation(activityID: Int, ticketID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/club/event-ops/host/request",
            method: "POST",
            json: [
                "activityId": .integer(Int64(activityID)),
                "ticketId": .integer(Int64(ticketID))
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-B-4-4`: `GET /api/topic/pricing/sale-status?topicId=`
    public func fetchTopicPricingSaleStatus(topicID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/topic/pricing/sale-status",
            method: "GET",
            query: ["topicId": String(topicID)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-B-4-4`: `GET /api/topic/pricing/settlement-pending?topicId=`
    public func fetchTopicPricingSettlementPending(topicID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/topic/pricing/settlement-pending",
            method: "GET",
            query: ["topicId": String(topicID)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `pages/topic/index/index.js`: `POST /api/orient/safety/check` JSON `{topicId}`.
    /// `PlayerGapReply` drops `errorCode`, so the decision is read from the same body.
    public func checkOrientSafety(topicID: Int) async -> OrientSafetyCheck {
        guard let req = try? makeRequest(
            "api/orient/safety/check",
            method: "POST",
            json: ["topicId": .integer(Int64(topicID))]
        ) else {
            return OrientSafetyCheck(reply: .unauthorized, decision: .retry(PlayerOrientSafetyDecision.retryLine))
        }
        do {
            let (data, status) = try await transport.send(req)
            let reply = PlayerGapReply.classify(data: data, status: status)
            let raw = (try? JSONDecoder().decode(PlayWireValue.self, from: data)) ?? .null
            let code = raw["code"].text ?? raw["code"].tolerantInteger.map(String.init)
            let decision = PlayerOrientSafetyDecision.decide(
                code: code, errorCode: raw["errorCode"].text, allowed: raw["data"]["allowed"].bool)
            return OrientSafetyCheck(reply: reply, decision: decision)
        } catch {
            return OrientSafetyCheck(reply: .unknown, decision: .retry(PlayerOrientSafetyDecision.retryLine))
        }
    }
}

/// Safety-check reply plus the play-button decision. The reply alone cannot see `errorCode`.
public struct OrientSafetyCheck: Equatable, Sendable {
    public let reply: PlayerGapReply
    public let decision: PlayerOrientSafetyDecision
    public init(reply: PlayerGapReply, decision: PlayerOrientSafetyDecision) {
        self.reply = reply
        self.decision = decision
    }
}

/// Play-button decision for `POST /api/orient/safety/check`.
/// `ORIENT_DISABLED` and `ORIENT_NOT_ORIENTEERING` proceed. Anything else that is not an allow refuses or retries.
public enum PlayerOrientSafetyDecision: Equatable, Sendable {
    case proceed
    case refused(String)
    case retry(String)
    public static let refusedLine = "按平台规则，现在不能开始这个主题。"
    public static let retryLine = "网络异常，请重试"
    public static func decide(code: String?, errorCode: String?, allowed: Bool?) -> PlayerOrientSafetyDecision {
        if errorCode == "ORIENT_DISABLED" || errorCode == "ORIENT_NOT_ORIENTEERING" { return .proceed }
        if code != "200" || allowed == nil { return .retry(retryLine) }
        if allowed != true { return .refused(refusedLine) }
        return .proceed
    }
}
