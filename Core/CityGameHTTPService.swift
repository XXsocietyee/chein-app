import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Owner-approved CITY game capability for the shipped China composition. Minted only by
/// `ReviewedProductionGateLeases` when the reviewed deployment turns on the non-money player
/// writes, the host is the China production host, and the build names a CITY region.
///
/// Every write under this lease is a board move or a spend of the member's existing points
/// (`ums_member.point`, charged to the confirming member only). No route here creates an
/// order, a payment, a refund, a wallet or a payout; those stay behind their own switches.
public struct CityGameProductionLease: Equatable, Sendable {
    public let host: String
    public let regionID: String

    /// The backend routes the CITY board composes (`ApiCityGameController`, gaps A).
    /// `{}` is one opaque request id path segment.
    public static let paths: Set<String> = [
        "/api/city-game/current", "/api/city-game/participation", "/api/city-game/points",
        "/api/city-game/player-rules",
        "/api/city-game/team-participation/state", "/api/city-game/team-participation/invite",
        "/api/city-game/team-participation/command", "/api/city-game/team-participation/request/{}",
        "/api/city-game/game/snapshot", "/api/city-game/game/deltas", "/api/city-game/game/quote",
        "/api/city-game/game/action", "/api/city-game/game/action/{}",
        "/api/city-game/fairness/report", "/api/city-game/fairness/outing",
        "/api/city-game/action-budget/state", "/api/city-game/action-budget/command", "/api/city-game/action-budget/request/{}",
        "/api/city-game/acquisition/state", "/api/city-game/acquisition/titles", "/api/city-game/acquisition/quote/{}",
        "/api/city-game/acquisition/command", "/api/city-game/acquisition/request/{}",
        "/api/city-game/neutral-tasks/state", "/api/city-game/neutral-tasks/command", "/api/city-game/neutral-tasks/request/{}",
        "/api/city-game/onsite-tasks/state", "/api/city-game/onsite-tasks/command", "/api/city-game/onsite-tasks/request/{}",
        "/api/city-game/onsite-tasks/result/{}",
        "/api/city-game/arrival-evidence/state", "/api/city-game/arrival-evidence/merchant", "/api/city-game/arrival-evidence/command",
        "/api/city-game/arrival-evidence/request/{}", "/api/city-game/arrival-evidence/evidence/{}",
        "/api/city-game/merchant/operations/availability", "/api/city-game/merchant/operations/request/{}",
        "/api/city-game/dice/roll", "/api/city-game/dice/audit",
        "/api/roam/territory/nearby", "/api/roam/territory/claim", "/api/roam/territory/checkin",
        "/api/roam/territory/leaderboard", "/api/roam/territory/my"
    ]

    public init?(host: String, regionID: String) {
        let host = host.lowercased()
        guard !host.isEmpty, CityReadRoute.validID(regionID) else { return nil }
        self.host = host; self.regionID = regionID
    }
}

public enum CityGameServiceError: Error, Equatable {
    /// The lease, session or viewer changed; nothing is sent or a late answer is dropped.
    case notCurrent
    case unauthorized
    /// `409 CITY_SNAPSHOT_CHANGED`: the board tuple moved; reload the snapshot.
    case snapshotChanged
    /// Any other non-200 answer, with the server's errorCode.
    case rejected(status: Int, code: String)
    case malformed
}

/// Server-authoritative response for `POST /api/city-game/dice/roll`.
public struct CityUnifiedDiceRollReceipt: Decodable, Equatable, Sendable {
    public let requestId: String
    public let boardId: String
    public let action: String?
    public let decision: String
    public let currentVersion: Int64
    public let reasonCode: String?
    public let taskAttemptKept: Bool?
    public let pointsCharged: Int64?
    public let diceFace: Int64?
    public let idempotentReplay: Bool?
    public let teamId: String?
    public let roundSeq: Int64?
    public let faceIndex: Int?
    public let faceValue: Int64?
    public let previousPosition: Int?
    public let newPosition: Int?
    public let landedPropertyId: String?
}

public struct CityDiceAuditEntry: Decodable, Equatable, Sendable, Identifiable {
    public let rollId: String
    public let requestId: String?
    public let teamId: String?
    public let actorMemberId: Int64?
    public let roundSeq: Int64?
    public let diceId: String?
    public let faceIndex: Int?
    public let faceValue: Int64?
    public let sourcePath: String?
    public let randomTicket: Int?
    public let totalWeight: Int?
    public let previousPosition: Int?
    public let newPosition: Int?
    public let landedPropertyId: String?
    public let beforeUnits: Int?
    public let afterUnits: Int?
    public let boardVersion: Int64?
    public let rolledAtMillis: Int64?
    public var id: String { rollId }
}

public struct CityDiceAuditReport: Decodable, Equatable, Sendable {
    public let boardId: String
    public let regionId: String?
    public let teamId: String?
    public let diceId: String?
    public let rolls: [CityDiceAuditEntry]
}

/// The five game-loop routes plus unified dice roll/audit. Bodies come from the agent-H intent;
/// nothing here prices, rolls or decides.
public enum CityGameRoute: Equatable {
    case snapshot(boardId: String)
    case deltas(boardId: String, seasonId: String, after: Int64)
    case quote(action: CityActionKind, boardId: String, targetId: String)
    case action(body: Data)
    case receipt(requestId: String)
    case unifiedDiceRoll(requestId: String, boardId: String?, regionId: String?, expectedVersion: Int64?)
    case diceAudit(boardId: String?, regionId: String?, limit: Int?)

    public var path: String {
        switch self {
        case .snapshot: return "api/city-game/game/snapshot"
        case .deltas: return "api/city-game/game/deltas"
        case .quote: return "api/city-game/game/quote"
        case .action: return "api/city-game/game/action"
        case .receipt(let requestId): return "api/city-game/game/action/" + requestId
        case .unifiedDiceRoll: return "api/city-game/dice/roll"
        case .diceAudit: return "api/city-game/dice/audit"
        }
    }

    public func request(baseURL: URL, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        let configuration = try APIConfiguration(baseURL: baseURL)
        var query: [String: String] = [:]
        var body: Data?
        switch self {
        case .snapshot(let boardId):
            guard CityReadRoute.validID(boardId) else { throw APIError.invalidRequest }
            query = ["boardId": boardId]
        case .deltas(let boardId, let seasonId, let after):
            guard CityReadRoute.validID(boardId), CityReadRoute.validID(seasonId), ReformWire.version(after) else { throw APIError.invalidRequest }
            query = ["boardId": boardId, "seasonId": seasonId, "after": String(after)]
        case .quote(let action, let boardId, let targetId):
            guard action.requiresQuote, CityReadRoute.validID(boardId), CityReadRoute.validID(targetId) else { throw APIError.invalidRequest }
            body = try JSONSerialization.data(withJSONObject: ["action": action.rawValue, "boardId": boardId, "targetId": targetId], options: [.sortedKeys])
        case .action(let bytes):
            guard !bytes.isEmpty, bytes.count <= 4096 else { throw APIError.invalidRequest }
            body = bytes
        case .receipt(let requestId):
            guard CityReadRoute.validID(requestId) else { throw APIError.invalidRequest }
        case .unifiedDiceRoll(let requestId, let boardId, let regionId, let expectedVersion):
            guard CityReadRoute.validID(requestId) else { throw APIError.invalidRequest }
            var payload: [String: Any] = ["requestId": requestId]
            if let boardId {
                guard CityReadRoute.validID(boardId) else { throw APIError.invalidRequest }
                payload["boardId"] = boardId
            }
            if let regionId {
                guard CityReadRoute.validID(regionId) else { throw APIError.invalidRequest }
                payload["regionId"] = regionId
            }
            if boardId == nil && regionId == nil { throw APIError.invalidRequest }
            if let expectedVersion {
                guard ReformWire.version(expectedVersion) else { throw APIError.invalidRequest }
                payload["expectedVersion"] = expectedVersion
            }
            body = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        case .diceAudit(let boardId, let regionId, let limit):
            if let boardId {
                guard CityReadRoute.validID(boardId) else { throw APIError.invalidRequest }
                query["boardId"] = boardId
            }
            if let regionId {
                guard CityReadRoute.validID(regionId) else { throw APIError.invalidRequest }
                query["regionId"] = regionId
            }
            if boardId == nil && regionId == nil { throw APIError.invalidRequest }
            if let limit {
                guard (1...200).contains(limit) else { throw APIError.invalidRequest }
                query["limit"] = String(limit)
            }
        }
        guard var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidConfiguration
        }
        if !query.isEmpty { components.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) } }
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

/// Production `CityGameServing` over the gaps-A routes. The server rolls the die, prices
/// every paid action and stores one receipt per (member, requestId). A submit whose answer
/// is lost throws, so the coordinator keeps the SAME intent and reads
/// `GET game/action/{requestId}`; only `404 CITY_RECEIPT_NOT_FOUND` means "no receipt yet".
@MainActor public final class CityGameHTTPService: CityGameServing {
    public let lease: CityGameProductionLease
    private let configuration: APIConfiguration
    private let token: String
    private let transport: any HTTPTransport
    private let isCurrent: () -> Bool
    private let onUnauthorized: () -> Void

    public init(configuration: APIConfiguration, token: String, lease: CityGameProductionLease, transport: any HTTPTransport,
                isCurrent: @escaping () -> Bool, onUnauthorized: @escaping () -> Void = {}) throws {
        guard configuration.baseURL.host?.lowercased() == lease.host, AuthRequestBuilder.isValidToken(token) else {
            throw APIError.invalidConfiguration
        }
        self.configuration = configuration; self.token = token; self.lease = lease; self.transport = transport
        self.isCurrent = isCurrent; self.onUnauthorized = onUnauthorized
    }

    public func snapshot(for read: CityReadSnapshot) async throws -> CityGameSnapshot {
        guard read.board.regionId == lease.regionID else { throw CityGameServiceError.notCurrent }
        let value: CityGameSnapshot = try await exchange(.snapshot(boardId: read.board.boardId))
        guard value.boardId == read.board.boardId else { throw CityGameServiceError.malformed }
        return value
    }

    public func deltas(after cursor: CityStreamCursor) async throws -> [CityDelta] {
        try await exchange(.deltas(boardId: cursor.boardId, seasonId: cursor.seasonId, after: cursor.sequence))
    }

    public func quote(_ kind: CityActionKind, targetId: String, read: CityReadSnapshot) async throws -> CityActionQuote {
        guard read.board.regionId == lease.regionID else { throw CityGameServiceError.notCurrent }
        return try await exchange(.quote(action: kind, boardId: read.board.boardId, targetId: targetId))
    }

    public func submit(_ intent: CityActionIntent) async throws -> CityActionReceipt {
        // The canonical body is the same bytes on every retry, so the server's request hash matches.
        try await exchange(.action(body: intent.body()))
    }

    public func receipt(for intent: CityActionIntent) async throws -> CityActionReceipt? {
        do {
            let value: CityActionReceipt = try await exchange(.receipt(requestId: intent.requestId))
            return value
        } catch CityGameServiceError.rejected(status: 404, code: "CITY_RECEIPT_NOT_FOUND") {
            return nil
        }
    }

    /// Unified server-authoritative dice roll (`POST /api/city-game/dice/roll`).
    public func rollUnifiedDice(requestId: String = UUID().uuidString.lowercased(),
                                boardId: String,
                                expectedVersion: Int64? = nil) async throws -> CityUnifiedDiceRollReceipt {
        try await exchange(.unifiedDiceRoll(requestId: requestId, boardId: boardId, regionId: lease.regionID, expectedVersion: expectedVersion))
    }

    /// Server dice roll audit trail for the viewer's joined team (`GET /api/city-game/dice/audit`).
    public func diceAudit(boardId: String, limit: Int? = 50) async throws -> CityDiceAuditReport {
        try await exchange(.diceAudit(boardId: boardId, regionId: lease.regionID, limit: limit))
    }

    private struct Envelope<Payload: Decodable>: Decodable {
        let code: Int
        let data: Payload?
        let errorCode: String?
    }
    private struct Failure: Decodable {
        let code: Int?
        let errorCode: String?
    }

    private func exchange<Payload: Decodable>(_ route: CityGameRoute) async throws -> Payload {
        try Task.checkCancellation()
        guard isCurrent() else { throw CityGameServiceError.notCurrent }
        let request = try route.request(baseURL: configuration.baseURL, token: token)
        let (data, status) = try await transport.send(request)
        guard isCurrent(), !Task.isCancelled else { throw CityGameServiceError.notCurrent }
        guard data.count <= 1_048_576 else { throw CityGameServiceError.malformed }
        let failure = try? JSONDecoder().decode(Failure.self, from: data)
        // Authentication filters can answer before the CITY controller and omit its envelope.
        if status == 401 || failure?.code == 401 { onUnauthorized(); throw CityGameServiceError.unauthorized }
        guard status == 200, failure?.code == 200 else {
            let code = failure?.errorCode ?? "UNAVAILABLE"
            if status == 409, code == "CITY_SNAPSHOT_CHANGED" { throw CityGameServiceError.snapshotChanged }
            throw CityGameServiceError.rejected(status: status, code: code)
        }
        guard let envelope = try? JSONDecoder().decode(Envelope<Payload>.self, from: data), let payload = envelope.data else {
            throw CityGameServiceError.malformed
        }
        return payload
    }
}
