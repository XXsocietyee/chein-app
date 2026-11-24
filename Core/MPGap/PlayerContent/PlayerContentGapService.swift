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
        "api/orient/safety/check",
        "api/official/broadcast/recover"
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

    /// `PC-A-7-2`: `POST /api/template/topic-template/info {id}`
    public func fetchTopicTemplatePreview(id: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/template/topic-template/info",
            method: "POST",
            json: ["id": .number(Double(id))],
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
                "activityId": .number(Double(activityID)),
                "ticketId": .number(Double(ticketID))
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

    /// `PC-B-1-4`: `POST /api/orient/safety/check {topicId}`
    public func checkOrientSafety(topicID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/orient/safety/check",
            method: "POST",
            json: ["topicId": .number(Double(topicID))]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-C-6-2`: `POST /api/official/broadcast/recover {eventId}`
    public func recoverOfficialBroadcast(eventID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/official/broadcast/recover",
            method: "POST",
            json: ["eventId": .number(Double(eventID))]
        ) else { return .unauthorized }
        return await send(req)
    }
}
