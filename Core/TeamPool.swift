import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Team shared resource pool (contract §4). One team run shares hints, skips and the timer; the server computes the
/// single team score from completion facts. The client never spends points or money here and never writes the score.
public enum TeamPoolFailure: Error, Equatable {
    case invalid
    case unauthorized
    /// A definite rejection: HTTP status equals the body `code` and both are 4xx (contract §0.1).
    case rejected(status: Int, errorCode: String?)
    /// The commit may or may not have happened. Recover with the same request id.
    case outcomeUnknown
    case malformed
}

public struct TeamPoolSnapshot: Decodable, Equatable, Sendable {
    public let teamId: Int64
    public let topicId: Int64?
    public let activityId: Int64?
    public let enabled: Bool
    public let unavailableReason: String?
    public let hintsTotal, hintsUsed, hintsLeft: Int?
    public let skipsTotal, skipsUsed, skipsLeft: Int?
    public let timerLimitSec: Int?
    public let timerStartedAt: String?
    public let timerDeadline: String?
    public let timerExpired: Bool?
    public let teamScore: Int?
    public let scoreBasis: String?
    public let solvedNodeIds: [Int64]?
    public let version: Int64?
    public let frozenAt: String?

    public func validate(teamID: Int64) throws {
        guard teamId == teamID else { throw TeamPoolFailure.malformed }
        guard enabled else { return }
        guard let hintsTotal, let hintsUsed, let hintsLeft, let skipsTotal, let skipsUsed, let skipsLeft,
              hintsTotal >= 0, hintsUsed >= 0, hintsLeft >= 0, hintsUsed + hintsLeft == hintsTotal,
              skipsTotal >= 0, skipsUsed >= 0, skipsLeft >= 0, skipsUsed + skipsLeft == skipsTotal,
              teamScore.map({ $0 >= 0 }) ?? true, timerLimitSec.map({ $0 >= 0 }) ?? true,
              scoreBasis == nil || scoreBasis == "TEAM_FIRST_SOLVE_NODES" else { throw TeamPoolFailure.malformed }
    }
}

/// Hint text from the same frozen run snapshot as the single-player help ladder (contract §4 "Hint text").
public struct TeamPoolHint: Decodable, Equatable, Sendable {
    public let level: Int
    public let type: String
    public let content: String
}

public struct TeamPoolConsume: Decodable, Equatable, Sendable {
    public enum Kind: String, Decodable, Sendable { case hint = "HINT", skip = "SKIP" }
    public let requestId: String
    public let kind: Kind
    public let nodeId: Int64
    /// `true`: this request spent a unit. `false`: an earlier request (maybe another member's) already covered the node.
    public let consumed: Bool
    public let byMemberId: Int64?
    public let pool: TeamPoolSnapshot
    /// Present on HINT results, including `consumed: false` replays. Skips carry none.
    public let hint: TeamPoolHint?

    public func validate(teamID: Int64, nodeID: Int64, kind: Kind, requestID: String) throws {
        try pool.validate(teamID: teamID)
        guard requestId == requestID, nodeId == nodeID, self.kind == kind else { throw TeamPoolFailure.malformed }
        if kind == .hint {
            guard let hint, hint.level >= 0, !hint.type.isEmpty,
                  !hint.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, hint.content.count <= 4000 else {
                throw TeamPoolFailure.malformed
            }
        }
    }
}

/// `GET /api/team/pool/requests/{requestId}`: the stored result of an earlier write, or NOT_FOUND.
public struct TeamPoolReceipt: Decodable, Sendable {
    public let requestId: String
    public let state: String
    public let result: TeamPoolConsume?
}

@MainActor public final class TeamPoolService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let token: () -> String?

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping () -> String?) {
        self.configuration = configuration; self.transport = transport; self.token = token
    }

    public static func isRequestID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{16,64}$", options: .regularExpression) != nil
    }
    public static func newRequestID() -> String { UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "") }

    public func pool(teamID: Int64) async throws -> TeamPoolSnapshot {
        guard teamID > 0 else { throw TeamPoolFailure.invalid }
        let value: TeamPoolSnapshot = try await send("GET", "api/team/pool", query: ["teamId": String(teamID)])
        try value.validate(teamID: teamID); return value
    }

    public func hint(teamID: Int64, nodeID: Int64, requestID: String) async throws -> TeamPoolConsume {
        try await consume("api/team/pool/hint", kind: .hint, teamID: teamID, nodeID: nodeID, requestID: requestID)
    }

    public func skip(teamID: Int64, nodeID: Int64, requestID: String) async throws -> TeamPoolConsume {
        try await consume("api/team/pool/skip", kind: .skip, teamID: teamID, nodeID: nodeID, requestID: requestID)
    }

    public func startTimer(teamID: Int64, requestID: String) async throws -> TeamPoolSnapshot {
        guard teamID > 0, Self.isRequestID(requestID) else { throw TeamPoolFailure.invalid }
        let value: TeamPoolSnapshot = try await send("POST", "api/team/pool/timer/start",
            body: ["teamId": teamID, "requestId": requestID])
        try value.validate(teamID: teamID); return value
    }

    /// The stored consume for `requestID`, or nil when the server never applied it.
    public func receipt(teamID: Int64, requestID: String) async throws -> TeamPoolConsume? {
        guard teamID > 0, Self.isRequestID(requestID) else { throw TeamPoolFailure.invalid }
        let value: TeamPoolReceipt = try await send("GET", "api/team/pool/requests/\(requestID)", query: ["teamId": String(teamID)])
        guard value.requestId == requestID else { throw TeamPoolFailure.malformed }
        switch value.state {
        case "NOT_FOUND": guard value.result == nil else { throw TeamPoolFailure.malformed }; return nil
        case "APPLIED":
            guard let result = value.result else { throw TeamPoolFailure.malformed }
            try result.validate(teamID: teamID, nodeID: result.nodeId, kind: result.kind, requestID: requestID)
            return result
        default: throw TeamPoolFailure.malformed
        }
    }

    private func consume(_ path: String, kind: TeamPoolConsume.Kind, teamID: Int64, nodeID: Int64, requestID: String) async throws -> TeamPoolConsume {
        guard teamID > 0, nodeID > 0, Self.isRequestID(requestID) else { throw TeamPoolFailure.invalid }
        let value: TeamPoolConsume = try await send("POST", path, body: ["teamId": teamID, "nodeId": nodeID, "requestId": requestID])
        try value.validate(teamID: teamID, nodeID: nodeID, kind: kind, requestID: requestID)
        return value
    }

    private struct Header: Decodable { let code: Int?; let errorCode: String?; let outcome_known: Bool? }
    private struct Envelope<Value: Decodable>: Decodable { let data: Value }

    private func send<Value: Decodable>(_ method: String, _ path: String, query: [String: String] = [:],
                                        body: [String: Any]? = nil) async throws -> Value {
        guard let token = token(), AuthRequestBuilder.isValidToken(token),
              var parts = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw TeamPoolFailure.unauthorized
        }
        if !query.isEmpty { parts.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        guard let url = parts.url else { throw TeamPoolFailure.invalid }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = method
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) }
        catch { if method == "POST" { throw TeamPoolFailure.outcomeUnknown }; throw error }
        guard data.count <= 256 * 1024 else { throw TeamPoolFailure.malformed }
        let header = try? JSONDecoder().decode(Header.self, from: data)
        if status == 401 || header?.code == 401 { throw TeamPoolFailure.unauthorized }
        guard (200..<300).contains(status), header?.code == 200 else {
            if let code = header?.code, code == status, (400..<500).contains(code) {
                throw TeamPoolFailure.rejected(status: code, errorCode: header?.errorCode)
            }
            if method == "POST" { throw TeamPoolFailure.outcomeUnknown }
            throw TeamPoolFailure.malformed
        }
        do { return try JSONDecoder().decode(Envelope<Value>.self, from: data).data }
        catch { if method == "POST" { throw TeamPoolFailure.outcomeUnknown }; throw TeamPoolFailure.malformed }
    }
}

/// The team-mode section of the play hint dialog. The pool is shown only when the server says `enabled: true`.
/// A hint request keeps one request id until the server settles it, so a retry or recovery never spends twice.
@MainActor @Observable public final class TeamPoolHintModel {
    public enum Notice: Equatable { case exhausted, timerExpired, disabled, unavailable, hintUnavailable, notMember, unknown, failed }
    public let nodeID: Int64
    public private(set) var teamID: Int64?
    public private(set) var pool: TeamPoolSnapshot?
    public private(set) var hint: TeamPoolHint?
    /// True when another member's earlier request covered this node (`consumed: false`).
    public private(set) var coveredByTeam = false
    public private(set) var notice: Notice?
    public private(set) var busy = false
    private var pendingRequestID: String?
    private let service: TeamPoolService
    private let resolveTeam: () async -> Int64?
    private var generation = 0

    public init(service: TeamPoolService, nodeID: Int64, resolveTeam: @escaping () async -> Int64?) {
        self.service = service; self.nodeID = nodeID; self.resolveTeam = resolveTeam
    }

    /// Shown only for an enabled pool of a resolved team.
    public var isVisible: Bool { teamID != nil && pool?.enabled == true }
    public var canRequestHint: Bool {
        guard isVisible, !busy, hint == nil, let pool else { return false }
        return (pool.hintsLeft ?? 0) > 0 && pool.timerExpired != true
    }
    public var canRecover: Bool { pendingRequestID != nil && !busy }

    public func load() async {
        generation += 1; let stamp = generation
        guard let team = await resolveTeam(), team > 0, stamp == generation else { teamID = nil; pool = nil; return }
        teamID = team
        do {
            let value = try await service.pool(teamID: team)
            guard stamp == generation else { return }
            pool = value
            if !value.enabled { notice = nil }
        } catch {
            guard stamp == generation else { return }
            pool = nil; apply(error)
        }
    }

    public func requestHint() async {
        guard canRequestHint, let teamID else { return }
        let requestID = pendingRequestID ?? TeamPoolService.newRequestID()
        pendingRequestID = requestID
        busy = true; notice = nil
        defer { busy = false }
        do {
            let result = try await service.hint(teamID: teamID, nodeID: nodeID, requestID: requestID)
            settle(result)
        } catch { apply(error) }
    }

    /// Reads the stored result of the pending request instead of sending another one.
    public func recover() async {
        guard let teamID, let requestID = pendingRequestID, !busy else { return }
        busy = true; defer { busy = false }
        do {
            if let result = try await service.receipt(teamID: teamID, requestID: requestID) {
                guard result.kind == .hint, result.nodeId == nodeID else { notice = .failed; return }
                settle(result)
            } else {
                // Never applied: the same id may be sent again by an explicit retry.
                notice = nil
            }
        } catch { apply(error) }
    }

    private func settle(_ result: TeamPoolConsume) {
        pendingRequestID = nil
        pool = result.pool; hint = result.hint; coveredByTeam = !result.consumed; notice = nil
    }

    private func apply(_ error: Error) {
        switch error as? TeamPoolFailure {
        case .rejected(_, let code)?:
            pendingRequestID = nil
            switch code {
            case "TEAM_POOL_EXHAUSTED": notice = .exhausted
            case "TEAM_POOL_TIMER_EXPIRED": notice = .timerExpired
            case "TEAM_POOL_DISABLED": notice = .disabled
            case "TEAM_POOL_HINT_UNAVAILABLE": notice = .hintUnavailable
            case "TEAM_NOT_MEMBER", "TEAM_NOT_FOUND": notice = .notMember
            default: notice = .failed
            }
        case .outcomeUnknown?: notice = .unknown
        case .unauthorized?: notice = .unavailable
        default: notice = pendingRequestID == nil ? .failed : .unknown
        }
    }
}
