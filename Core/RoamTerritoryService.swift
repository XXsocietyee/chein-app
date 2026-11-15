import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Routes for merged Roam + CITY territory interactions (`/api/roam/territory/*`).
/// Admitted by `CityGameProductionLease` without touching any money/payment switches.
public enum RoamTerritoryRoute: Equatable {
    case nearby(lat: Double, lng: Double, radius: Int?, boardId: String?, regionId: String?, seasonId: String?)
    case claim(RoamTerritoryClaimRequest)
    case checkin(RoamTerritoryCheckinRequest)
    case leaderboard(boardId: String?, regionId: String?, seasonId: String?, limit: Int?)
    case myTerritories

    public var path: String {
        switch self {
        case .nearby: return "api/roam/territory/nearby"
        case .claim: return "api/roam/territory/claim"
        case .checkin: return "api/roam/territory/checkin"
        case .leaderboard: return "api/roam/territory/leaderboard"
        case .myTerritories: return "api/roam/territory/my"
        }
    }

    public func request(baseURL: URL, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        let configuration = try APIConfiguration(baseURL: baseURL)
        var query: [String: String] = [:]
        var body: Data?

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        switch self {
        case .nearby(let lat, let lng, let radius, let boardId, let regionId, let seasonId):
            guard lat.isFinite, (-90...90).contains(lat), lng.isFinite, (-180...180).contains(lng) else {
                throw APIError.invalidRequest
            }
            query["lat"] = String(lat)
            query["lng"] = String(lng)
            if let radius {
                guard (50...50_000).contains(radius) else { throw APIError.invalidRequest }
                query["radius"] = String(radius)
            }
            if let boardId {
                guard CityReadRoute.validID(boardId) else { throw APIError.invalidRequest }
                query["boardId"] = boardId
            }
            if let regionId {
                guard CityReadRoute.validID(regionId) else { throw APIError.invalidRequest }
                query["regionId"] = regionId
            }
            if let seasonId {
                guard CityReadRoute.validID(seasonId) else { throw APIError.invalidRequest }
                query["seasonId"] = seasonId
            }
        case .claim(let payload):
            guard CityReadRoute.validID(payload.requestId),
                  payload.lat.isFinite, (-90...90).contains(payload.lat),
                  payload.lng.isFinite, (-180...180).contains(payload.lng),
                  let photoURL = URL(string: payload.photoUrl),
                  photoURL.scheme == "https",
                  payload.poiId != nil || payload.propertyId != nil || payload.pointId != nil else {
                throw APIError.invalidRequest
            }
            body = try encoder.encode(payload)
        case .checkin(let payload):
            guard CityReadRoute.validID(payload.requestId),
                  payload.lat.isFinite, (-90...90).contains(payload.lat),
                  payload.lng.isFinite, (-180...180).contains(payload.lng),
                  (payload.territoryId != nil && !payload.territoryId!.isEmpty) || payload.poiId != nil else {
                throw APIError.invalidRequest
            }
            body = try encoder.encode(payload)
        case .leaderboard(let boardId, let regionId, let seasonId, let limit):
            if let boardId {
                guard CityReadRoute.validID(boardId) else { throw APIError.invalidRequest }
                query["boardId"] = boardId
            }
            if let regionId {
                guard CityReadRoute.validID(regionId) else { throw APIError.invalidRequest }
                query["regionId"] = regionId
            }
            if let seasonId {
                guard CityReadRoute.validID(seasonId) else { throw APIError.invalidRequest }
                query["seasonId"] = seasonId
            }
            if let limit {
                guard (1...100).contains(limit) else { throw APIError.invalidRequest }
                query["limit"] = String(limit)
            }
        case .myTerritories:
            break
        }

        guard var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidConfiguration
        }
        if !query.isEmpty {
            components.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        }
        guard let url = components.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }
}

/// Live client for merged Roam + CITY territory reads, photo+GPS claims, POINTS check-ins, and leaderboard.
@MainActor public final class RoamTerritoryService {
    public let lease: CityGameProductionLease
    private let configuration: APIConfiguration
    private let token: String
    private let transport: any HTTPTransport
    private let isCurrent: () -> Bool
    private let onUnauthorized: () -> Void

    public init(configuration: APIConfiguration, token: String, lease: CityGameProductionLease,
                transport: any HTTPTransport, isCurrent: @escaping () -> Bool,
                onUnauthorized: @escaping () -> Void = {}) throws {
        guard configuration.baseURL.host?.lowercased() == lease.host, AuthRequestBuilder.isValidToken(token) else {
            throw APIError.invalidConfiguration
        }
        self.configuration = configuration
        self.token = token
        self.lease = lease
        self.transport = transport
        self.isCurrent = isCurrent
        self.onUnauthorized = onUnauthorized
    }

    public func nearby(lat: Double, lng: Double, radius: Int? = 3000,
                       boardId: String? = nil, seasonId: String? = nil) async throws -> RoamTerritoryNearbyResponse {
        try await exchange(.nearby(lat: lat, lng: lng, radius: radius, boardId: boardId, regionId: lease.regionID, seasonId: seasonId))
    }

    public func claim(_ payload: RoamTerritoryClaimRequest) async throws -> RoamTerritoryClaimReceipt {
        try await exchange(.claim(payload))
    }

    public func checkin(_ payload: RoamTerritoryCheckinRequest) async throws -> RoamTerritoryCheckinReceipt {
        try await exchange(.checkin(payload))
    }

    public func leaderboard(boardId: String? = nil, seasonId: String? = nil, limit: Int? = 20) async throws -> RoamTerritoryLeaderboardResponse {
        try await exchange(.leaderboard(boardId: boardId, regionId: lease.regionID, seasonId: seasonId, limit: limit))
    }

    public func myTerritories() async throws -> [RoamTerritoryRow] {
        try await exchange(.myTerritories)
    }

    private struct Envelope<Payload: Decodable>: Decodable {
        let code: Int
        let data: Payload?
        let msg: String?
        let errorCode: String?
    }

    private struct Failure: Decodable {
        let code: Int?
        let msg: String?
        let errorCode: String?
    }

    private func exchange<Payload: Decodable>(_ route: RoamTerritoryRoute) async throws -> Payload {
        try Task.checkCancellation()
        guard isCurrent() else { throw RoamTerritoryError.notCurrent }
        let request = try route.request(baseURL: configuration.baseURL, token: token)
        let (data, status) = try await transport.send(request)
        guard isCurrent(), !Task.isCancelled else { throw RoamTerritoryError.notCurrent }
        guard data.count <= 1_048_576 else { throw RoamTerritoryError.malformed }
        let failure = try? JSONDecoder().decode(Failure.self, from: data)
        if status == 401 || failure?.code == 401 {
            onUnauthorized()
            throw RoamTerritoryError.unauthorized
        }
        guard status == 200, failure?.code == 200 else {
            throw RoamTerritoryError.rejected(status: status, code: failure?.errorCode ?? "UNAVAILABLE", message: failure?.msg)
        }
        guard let envelope = try? JSONDecoder().decode(Envelope<Payload>.self, from: data), let payload = envelope.data else {
            throw RoamTerritoryError.malformed
        }
        return payload
    }
}
