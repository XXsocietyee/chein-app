import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// City Monopoly + attributes v2 routes (CITY-MONOPOLY-SPEC §6.2). Every price is member points;
/// the spec's `GET /api/city-game/wallet` (a city-coin wallet) is not used: under the one-currency
/// ruling the balance is the member's points, read from the growth center.
/// writes carry an upper-case UUID `requestId` and, where known, `expectedVersion`.
/// Admitted by `CityGameProductionLease` like the merged territory routes.
public enum CityMonopolyRoute: Equatable {
    case territoryMap(regionId: String?, bbox: String?, zoom: Int?)
    /// The live layer read: `minLat`, `minLng`, `maxLat`, `maxLng` (each span ≤ 0.5°).
    case territoryMapBounds(CityMapBounds)
    /// The 积分 HUD summary: balance, pending rent, holdings and the holding limit.
    case points
    case property(propertyId: String)
    case claimQuote(CityTerritoryQuoteRequest)
    case claimCommand(CityTerritoryCommandRequest)
    case upgradeQuote(CityTerritoryQuoteRequest)
    case upgradeCommand(CityTerritoryCommandRequest)
    case challengeQuote(CityTerritoryQuoteRequest)
    case challengeCommand(CityTerritoryCommandRequest)
    case scout(CityPropertyActionRequest)
    case shield(CityPropertyActionRequest)
    case revenue(cursor: String?, day: String?)
    case seasonCurrent(regionId: String?)
    case seasonLeaderboard(scope: CitySeasonScope, seasonId: String?, aroundMe: Bool)
    case memberAttributes
    case attributeLedger(key: MemberAttributeKey?, cursor: String?)
    case equipTitle(MemberTitleEquipRequest)

    /// Every path this enum can produce, in lease form (`{}` = one opaque id segment).
    public static let leasePaths: [String] = [
        "/api/city-game/territory/map", "/api/city-game/territory/property/{}",
        "/api/city-game/territory/claim/quote", "/api/city-game/territory/claim/command",
        "/api/city-game/territory/upgrade/quote", "/api/city-game/territory/upgrade/command",
        "/api/city-game/territory/challenge/quote", "/api/city-game/territory/challenge/command",
        "/api/city-game/territory/scout", "/api/city-game/territory/shield",
        "/api/city-game/territory/revenue", "/api/city-game/season/current", "/api/city-game/season/leaderboard",
        "/api/member/attributes", "/api/member/attributes/ledger", "/api/member/titles/equip",
        "/api/city-game/territory/points"
    ]

    public var path: String {
        switch self {
        case .territoryMap, .territoryMapBounds: return "api/city-game/territory/map"
        case .points: return "api/city-game/territory/points"
        case .property(let propertyId): return "api/city-game/territory/property/" + propertyId
        case .claimQuote: return "api/city-game/territory/claim/quote"
        case .claimCommand: return "api/city-game/territory/claim/command"
        case .upgradeQuote: return "api/city-game/territory/upgrade/quote"
        case .upgradeCommand: return "api/city-game/territory/upgrade/command"
        case .challengeQuote: return "api/city-game/territory/challenge/quote"
        case .challengeCommand: return "api/city-game/territory/challenge/command"
        case .scout: return "api/city-game/territory/scout"
        case .shield: return "api/city-game/territory/shield"
        case .revenue: return "api/city-game/territory/revenue"
        case .seasonCurrent: return "api/city-game/season/current"
        case .seasonLeaderboard: return "api/city-game/season/leaderboard"
        case .memberAttributes: return "api/member/attributes"
        case .attributeLedger: return "api/member/attributes/ledger"
        case .equipTitle: return "api/member/titles/equip"
        }
    }

    static func coordinate(_ value: Double) -> String { String(format: "%.6f", value) }

    static func validBBox(_ value: String) -> Bool {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in Double(part).map { $0.isFinite && abs($0) <= 180 } ?? false }
    }

    static func validCursor(_ value: String) -> Bool {
        value.range(of: #"\A[A-Za-z0-9._-]{1,64}\z"#, options: .regularExpression) != nil
    }

    static func validDay(_ value: String) -> Bool {
        value.range(of: #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z"#, options: .regularExpression) != nil
    }

    static func validUpperUUID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil && value == value.uppercased()
    }

    private static func validQuote(_ payload: CityTerritoryQuoteRequest) -> Bool {
        guard CityReadRoute.validID(payload.propertyId) else { return false }
        if let id = payload.territoryId { guard CityReadRoute.validID(id) else { return false } }
        if let id = payload.boardId { guard CityReadRoute.validID(id) else { return false } }
        if let id = payload.pointId { guard CityReadRoute.validID(id) else { return false } }
        if let id = payload.poiId { guard id > 0 else { return false } }
        if let lat = payload.lat { guard lat.isFinite, (-90...90).contains(lat) else { return false } }
        if let lng = payload.lng { guard lng.isFinite, (-180...180).contains(lng) else { return false } }
        if let hAcc = payload.hAcc { guard hAcc.isFinite, hAcc >= 0 else { return false } }
        return true
    }

    private static func validCommand(_ payload: CityTerritoryCommandRequest) -> Bool {
        let evidence = payload.evidence
        guard validUpperUUID(payload.requestId), CityReadRoute.validID(payload.propertyId),
              CityReadRoute.validID(payload.quoteId), !payload.quoteHash.isEmpty, payload.quoteHash.count <= 128,
              evidence.lat.isFinite, (-90...90).contains(evidence.lat),
              evidence.lng.isFinite, (-180...180).contains(evidence.lng),
              evidence.hAcc.isFinite, evidence.hAcc >= 0, evidence.samples.count <= 64 else { return false }
        if let expected = payload.expectedVersion, expected < 0 { return false }
        return evidence.samples.allSatisfy { sample in
            sample.lat.isFinite && (-90...90).contains(sample.lat) && sample.lng.isFinite && (-180...180).contains(sample.lng)
                && sample.hAcc.isFinite && sample.hAcc >= 0
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
        case .territoryMap(let regionId, let bbox, let zoom):
            if let regionId {
                guard CityReadRoute.validID(regionId) else { throw APIError.invalidRequest }
                query["regionId"] = regionId
            }
            if let bbox {
                guard Self.validBBox(bbox) else { throw APIError.invalidRequest }
                query["bbox"] = bbox
            }
            if let zoom {
                guard (1...22).contains(zoom) else { throw APIError.invalidRequest }
                query["zoom"] = String(zoom)
            }
        case .territoryMapBounds(let bounds):
            guard bounds.isValid else { throw APIError.invalidRequest }
            query["minLat"] = Self.coordinate(bounds.minLat); query["minLng"] = Self.coordinate(bounds.minLng)
            query["maxLat"] = Self.coordinate(bounds.maxLat); query["maxLng"] = Self.coordinate(bounds.maxLng)
        case .points:
            break
        case .property(let propertyId):
            guard CityReadRoute.validID(propertyId) else { throw APIError.invalidRequest }
        case .claimQuote(let payload), .upgradeQuote(let payload), .challengeQuote(let payload):
            guard Self.validQuote(payload) else { throw APIError.invalidRequest }
            body = try encoder.encode(payload)
        case .claimCommand(let payload), .upgradeCommand(let payload), .challengeCommand(let payload):
            guard Self.validCommand(payload) else { throw APIError.invalidRequest }
            body = try encoder.encode(payload)
        case .scout(let payload), .shield(let payload):
            guard Self.validUpperUUID(payload.requestId), CityReadRoute.validID(payload.propertyId) else {
                throw APIError.invalidRequest
            }
            if let expected = payload.expectedVersion, expected < 0 { throw APIError.invalidRequest }
            body = try encoder.encode(payload)
        case .revenue(let cursor, let day):
            if let cursor {
                guard Self.validCursor(cursor) else { throw APIError.invalidRequest }
                query["cursor"] = cursor
            }
            if let day {
                guard Self.validDay(day) else { throw APIError.invalidRequest }
                query["day"] = day
            }
        case .memberAttributes:
            break
        case .seasonCurrent(let regionId):
            if let regionId {
                guard CityReadRoute.validID(regionId) else { throw APIError.invalidRequest }
                query["regionId"] = regionId
            }
        case .seasonLeaderboard(let scope, let seasonId, let aroundMe):
            query["scope"] = scope.rawValue
            if let seasonId {
                guard CityReadRoute.validID(seasonId) else { throw APIError.invalidRequest }
                query["seasonId"] = seasonId
            }
            if aroundMe { query["around"] = "me" }
        case .attributeLedger(let key, let cursor):
            if let key { query["key"] = key.rawValue }
            if let cursor {
                guard Self.validCursor(cursor) else { throw APIError.invalidRequest }
                query["cursor"] = cursor
            }
        case .equipTitle(let payload):
            guard Self.validUpperUUID(payload.requestId) else { throw APIError.invalidRequest }
            if let code = payload.titleCode {
                guard CityReadRoute.validID(code) else { throw APIError.invalidRequest }
            }
            body = try encoder.encode(payload)
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

/// What the City Monopoly screens and the profile attributes section read and write.
@MainActor public protocol CityMonopolyReading: AnyObject {
    func territoryMap(bbox: String?, zoom: Int?) async throws -> CityTerritoryMapResponse
    /// The live layer for a viewport. Default: unavailable (older fakes).
    func territoryMap(bounds: CityMapBounds) async throws -> CityTerritoryMapResponse
    /// The 积分 HUD. Default: unavailable (older fakes).
    func pointsSummary() async throws -> CityPointsSummary
    func property(_ propertyId: String) async throws -> CityTerritoryPropertyCard
    func claimQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote
    func claim(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult
    func upgradeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote
    func upgrade(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult
    func challengeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote
    func challenge(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult
    func scout(_ payload: CityPropertyActionRequest) async throws -> CityScoutResult
    func shield(_ payload: CityPropertyActionRequest) async throws -> CityShieldResult
    func revenue(cursor: String?, day: String?) async throws -> CityRevenuePage
    func seasonCurrent() async throws -> CitySeasonCurrent
    func seasonLeaderboard(scope: CitySeasonScope, seasonId: String?) async throws -> CitySeasonLeaderboard
    func memberAttributes() async throws -> MemberAttributesResponse
    func attributeLedger(key: MemberAttributeKey?, cursor: String?) async throws -> MemberAttributeLedgerPage
    func equipTitle(_ payload: MemberTitleEquipRequest) async throws -> MemberTitleEquipReceipt
}

public extension CityMonopolyReading {
    func territoryMap(bounds: CityMapBounds) async throws -> CityTerritoryMapResponse {
        throw RoamTerritoryError.rejected(status: 404, code: "UNAVAILABLE", message: nil)
    }
    func pointsSummary() async throws -> CityPointsSummary {
        throw RoamTerritoryError.rejected(status: 404, code: "UNAVAILABLE", message: nil)
    }
}

/// Live client under the reviewed CITY lease. Errors reuse `RoamTerritoryError`.
@MainActor public final class CityMonopolyService: CityMonopolyReading {
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

    public func territoryMap(bbox: String? = nil, zoom: Int? = nil) async throws -> CityTerritoryMapResponse {
        try await exchange(.territoryMap(regionId: lease.regionID, bbox: bbox, zoom: zoom))
    }

    public func territoryMap(bounds: CityMapBounds) async throws -> CityTerritoryMapResponse {
        try await exchange(.territoryMapBounds(bounds))
    }

    public func pointsSummary() async throws -> CityPointsSummary {
        try await exchange(.points)
    }

    public func property(_ propertyId: String) async throws -> CityTerritoryPropertyCard {
        try await exchange(.property(propertyId: propertyId))
    }

    public func claimQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote {
        try await exchange(.claimQuote(payload))
    }

    public func claim(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult {
        try await exchange(.claimCommand(payload))
    }

    public func upgradeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote {
        try await exchange(.upgradeQuote(payload))
    }

    public func upgrade(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult {
        try await exchange(.upgradeCommand(payload))
    }

    public func challengeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote {
        try await exchange(.challengeQuote(payload))
    }

    public func challenge(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult {
        try await exchange(.challengeCommand(payload))
    }

    public func scout(_ payload: CityPropertyActionRequest) async throws -> CityScoutResult {
        try await exchange(.scout(payload))
    }

    public func shield(_ payload: CityPropertyActionRequest) async throws -> CityShieldResult {
        try await exchange(.shield(payload))
    }

    public func revenue(cursor: String? = nil, day: String? = nil) async throws -> CityRevenuePage {
        try await exchange(.revenue(cursor: cursor, day: day))
    }

    public func seasonCurrent() async throws -> CitySeasonCurrent {
        try await exchange(.seasonCurrent(regionId: lease.regionID))
    }

    public func seasonLeaderboard(scope: CitySeasonScope = .solo, seasonId: String? = nil) async throws -> CitySeasonLeaderboard {
        try await exchange(.seasonLeaderboard(scope: scope, seasonId: seasonId, aroundMe: true))
    }

    public func memberAttributes() async throws -> MemberAttributesResponse {
        try await exchange(.memberAttributes)
    }

    public func attributeLedger(key: MemberAttributeKey? = nil, cursor: String? = nil) async throws -> MemberAttributeLedgerPage {
        try await exchange(.attributeLedger(key: key, cursor: cursor))
    }

    public func equipTitle(_ payload: MemberTitleEquipRequest) async throws -> MemberTitleEquipReceipt {
        try await exchange(.equipTitle(payload))
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

    private func exchange<Payload: Decodable>(_ route: CityMonopolyRoute) async throws -> Payload {
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
