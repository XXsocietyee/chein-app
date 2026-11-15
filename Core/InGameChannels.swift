import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Target scope for resolving or summarizing an in-game IM channel.
public enum InGameChannelScope: Equatable, Hashable {
    case activity(id: Int)
    case topic(id: Int)
    case team(id: Int)
    case roam(district: String)
    case cityTeam(teamID: String?, boardID: String?)

    public var scopeName: String {
        switch self {
        case .activity: return "activity"
        case .topic: return "topic"
        case .team: return "team"
        case .roam: return "roam"
        case .cityTeam: return "city_team"
        }
    }

    public var fields: [String: String] {
        var result: [String: String] = ["scope": scopeName]
        switch self {
        case .activity(let id):
            result["activity_id"] = String(id)
        case .topic(let id):
            result["topic_id"] = String(id)
        case .team(let id):
            result["team_id"] = String(id)
        case .roam(let district):
            let trimmed = district.trimmingCharacters(in: .whitespacesAndNewlines)
            result["district"] = trimmed.isEmpty ? "nearby" : trimmed
        case .cityTeam(let teamID, let boardID):
            if let teamID = teamID?.trimmingCharacters(in: .whitespacesAndNewlines), !teamID.isEmpty {
                result["city_team_id"] = teamID
            }
            if let boardID = boardID?.trimmingCharacters(in: .whitespacesAndNewlines), !boardID.isEmpty {
                result["board_id"] = boardID
            }
        }
        return result
    }

    public var isValid: Bool {
        switch self {
        case .activity(let id), .topic(let id), .team(let id):
            return id > 0
        case .roam:
            return true
        case .cityTeam(let teamID, let boardID):
            let hasTeam = teamID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            let hasBoard = boardID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            return hasTeam || hasBoard
        }
    }

    public var identifierSuffix: String {
        switch self {
        case .activity(let id): return "activity.\(id)"
        case .topic(let id): return "topic.\(id)"
        case .team(let id): return "team.\(id)"
        case .roam(let district):
            let trimmed = district.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "roam.nearby" : "roam"
        case .cityTeam:
            return "cityTeam"
        }
    }
}

/// Resolved in-game IM channel descriptor backed by ImConversation (TYPE_GROUP = 4).
public struct InGameChannelRef: Decodable, Equatable, Identifiable {
    public let conversationId: Int
    public let type: Int?
    public let scope: String
    public let bizKey: String
    public let title: String
    public let unread: Int
    public let muted: Int
    public let memberCount: Int
    public let lastMsgText: String?
    public let teamId: Int?
    public let cityTeamId: String?

    public var id: Int { conversationId }
    public var isMuted: Bool { muted == 1 }

    public var asConversation: MessagingConversation {
        let counterparty = MessagingCounterparty(id: 0, nickname: title, avatar: "", bizKey: bizKey)
        return MessagingConversation(
            id: conversationId,
            type: type ?? 4,
            counterparty: counterparty,
            lastMessageAt: nil,
            unread: unread,
            muted: isMuted
        )
    }

    private enum CodingKeys: String, CodingKey {
        case conversationId, type, scope, bizKey, title, unread, muted, memberCount, lastMsgText, teamId, cityTeamId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conversationId = try c.decode(Int.self, forKey: .conversationId)
        guard conversationId > 0 else { throw APIError.malformedResponse }
        type = try c.decodeIfPresent(Int.self, forKey: .type)
        scope = try c.decodeIfPresent(String.self, forKey: .scope) ?? "roam"
        bizKey = try c.decodeIfPresent(String.self, forKey: .bizKey) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        unread = max(0, try c.decodeIfPresent(Int.self, forKey: .unread) ?? 0)
        muted = try c.decodeIfPresent(Int.self, forKey: .muted) ?? 0
        memberCount = max(0, try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0)
        lastMsgText = try c.decodeIfPresent(String.self, forKey: .lastMsgText)
        teamId = try c.decodeIfPresent(Int.self, forKey: .teamId)
        cityTeamId = try c.decodeIfPresent(String.self, forKey: .cityTeamId)
    }

    public init(conversationId: Int, type: Int? = 4, scope: String, bizKey: String,
                title: String, unread: Int = 0, muted: Int = 0, memberCount: Int = 0,
                lastMsgText: String? = nil, teamId: Int? = nil, cityTeamId: String? = nil) {
        self.conversationId = conversationId
        self.type = type
        self.scope = scope
        self.bizKey = bizKey
        self.title = title
        self.unread = unread
        self.muted = muted
        self.memberCount = memberCount
        self.lastMsgText = lastMsgText
        self.teamId = teamId
        self.cityTeamId = cityTeamId
    }
}

/// Lightweight badge summary for an in-game channel entry point.
public struct InGameChannelSummary: Decodable, Equatable {
    public let exists: Bool
    public let conversationId: Int?
    public let scope: String?
    public let bizKey: String?
    public let title: String?
    public let unread: Int
    public let muted: Int
    public let lastMsgText: String?

    private enum CodingKeys: String, CodingKey {
        case exists, conversationId, scope, bizKey, title, unread, muted, lastMsgText
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exists = try c.decodeIfPresent(Bool.self, forKey: .exists) ?? false
        conversationId = try c.decodeIfPresent(Int.self, forKey: .conversationId)
        scope = try c.decodeIfPresent(String.self, forKey: .scope)
        bizKey = try c.decodeIfPresent(String.self, forKey: .bizKey)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        unread = max(0, try c.decodeIfPresent(Int.self, forKey: .unread) ?? 0)
        muted = try c.decodeIfPresent(Int.self, forKey: .muted) ?? 0
        lastMsgText = try c.decodeIfPresent(String.self, forKey: .lastMsgText)
    }

    public init(exists: Bool, conversationId: Int? = nil, scope: String? = nil, bizKey: String? = nil,
                title: String? = nil, unread: Int = 0, muted: Int = 0, lastMsgText: String? = nil) {
        self.exists = exists
        self.conversationId = conversationId
        self.scope = scope
        self.bizKey = bizKey
        self.title = title
        self.unread = unread
        self.muted = muted
        self.lastMsgText = lastMsgText
    }
}

/// Network service for `/api/im/ingame/resolve` and `/api/im/ingame/summary`.
public struct InGameChannelService {
    public static let resolvePath = "api/im/ingame/resolve"
    public static let summaryPath = "api/im/ingame/summary"

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let resolveEnabled: Bool
    private let summaryEnabled: Bool

    public init(configuration: APIConfiguration, transport: any HTTPTransport, enabledPaths: Set<String>) {
        self.configuration = configuration
        self.transport = transport
        self.resolveEnabled = enabledPaths.contains(Self.resolvePath)
        self.summaryEnabled = enabledPaths.contains(Self.summaryPath)
    }

    public var isConfigured: Bool { resolveEnabled }
    public var isSummaryConfigured: Bool { summaryEnabled }

    public func resolve(token: String, target: InGameChannelScope) async throws -> InGameChannelRef {
        guard resolveEnabled else { throw APIError.notConfigured }
        guard target.isValid, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = try AuthRequestBuilder.makeFormRequest(
            url: configuration.baseURL.appendingPathComponent(Self.resolvePath),
            fields: target.fields,
            token: token
        )
        request.httpShouldHandleCookies = false
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        guard (200..<300).contains(status) else { throw MessagingReadFailure(httpStatus: status) }
        return try Self.decodeEnvelope(InGameChannelRef.self, from: data)
    }

    public func summary(token: String, target: InGameChannelScope) async throws -> InGameChannelSummary {
        guard summaryEnabled else { throw APIError.notConfigured }
        guard target.isValid, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(Self.summaryPath),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = target.fields.keys.sorted().map {
            URLQueryItem(name: $0, value: target.fields[$0])
        }
        guard let url = components?.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        guard (200..<300).contains(status) else { throw MessagingReadFailure(httpStatus: status) }
        return try Self.decodeEnvelope(InGameChannelSummary.self, from: data)
    }

    private struct APIEnvelope<Payload: Decodable>: Decodable {
        let code: Int
        let msg: String?
        let data: Payload?
    }

    public static func decodeEnvelope<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let envelope = try? JSONDecoder().decode(APIEnvelope<T>.self, from: data) else {
            throw APIError.malformedResponse
        }
        guard envelope.code == 200, let payload = envelope.data else {
            if let message = envelope.msg, !message.isEmpty {
                throw MessagingReadFailure(code: envelope.code, message: message)
            }
            throw MessagingReadFailure(code: envelope.code)
        }
        return payload
    }
}

@MainActor public protocol InGameChannelReading: AnyObject {
    var identity: MessagingReadIdentity? { get }
    var isConfigured: Bool { get }
    var isSummaryConfigured: Bool { get }
    func resolveChannel(_ target: InGameChannelScope) async throws -> InGameChannelRef
    func channelSummary(_ target: InGameChannelScope) async throws -> InGameChannelSummary
}

@MainActor public final class InGameChannelReader: InGameChannelReading {
    private let service: InGameChannelService?
    private let session: () -> IMSafetySession?
    private let onUnauthorized: ((IMSafetySession) -> Void)?

    public init(service: InGameChannelService?, session: @escaping () -> IMSafetySession?,
                onUnauthorized: ((IMSafetySession) -> Void)? = nil) {
        self.service = service
        self.session = session
        self.onUnauthorized = onUnauthorized
    }

    public var identity: MessagingReadIdentity? { session()?.identity }
    public var isConfigured: Bool { service?.isConfigured == true }
    public var isSummaryConfigured: Bool { service?.isSummaryConfigured == true }

    public func resolveChannel(_ target: InGameChannelScope) async throws -> InGameChannelRef {
        guard let service, service.isConfigured else { throw APIError.notConfigured }
        guard let snapshot = session() else { throw APIError.unauthorized }
        do {
            let channel = try await snapshot.withToken { try await service.resolve(token: $0, target: target) }
            guard !Task.isCancelled, session() == snapshot else { throw CancellationError() }
            return channel
        } catch let failure as MessagingReadFailure where failure.httpStatus == 401 || failure.code == 401 {
            onUnauthorized?(snapshot)
            throw failure
        }
    }

    public func channelSummary(_ target: InGameChannelScope) async throws -> InGameChannelSummary {
        guard let service, service.isSummaryConfigured else { throw APIError.notConfigured }
        guard let snapshot = session() else { throw APIError.unauthorized }
        let summary = try await snapshot.withToken { try await service.summary(token: $0, target: target) }
        guard !Task.isCancelled, session() == snapshot else { throw CancellationError() }
        return summary
    }
}
