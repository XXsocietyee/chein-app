import Foundation

/// Production readers for the layout binding stubs. Every value comes from a response
/// the app already decodes, or from the absence of that field. Nothing here fabricates
/// a filing number, a coordinate, a score, a price, or a count.

public struct PlayThemeServerFacts: Equatable, Sendable {
    public var aiGenerated: Bool
    public var productType: Int?
    public var coverURL: URL?
    public var look: PlayThemeLookTokens?

    public init(aiGenerated: Bool = false, productType: Int? = nil, coverURL: URL? = nil, look: PlayThemeLookTokens? = nil) {
        self.aiGenerated = aiGenerated
        self.productType = productType
        self.coverURL = coverURL
        self.look = look
    }

    /// Only an http(s) URL with a host and no userinfo. Anything else is absent.
    public static func coverURL(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let parts = URLComponents(string: raw),
              let scheme = parts.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              let url = parts.url else { return nil }
        return url
    }

    /// Missing, null, or a non-integer stays nil. A bad value does not fail the parent decode.
    public static func lenientInt<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> Int? {
        guard container.contains(key), (try? container.decodeNil(forKey: key)) != true else { return nil }
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let text = try? container.decode(String.self, forKey: key) {
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let value = try? container.decode(Double.self, forKey: key),
           value.isFinite, value == value.rounded(), abs(value) < Double(Int.max) {
            return Int(value)
        }
        return nil
    }
}

/// `look_json` style / palette / params.neon. Unknown style is no look. Unknown palette or neon
/// falls back the same way as the mini-program normalizer: DEFAULT and YELLOW_CYAN.
public struct PlayThemeLookTokens: Equatable, Sendable {
    public let style: String
    public let palette: String
    public let neon: String
    /// SURVIVAL only (`params.climate` CLEAR / RAIN / STORM / SAND, MP default RAIN); nil for the other styles.
    public let climate: String?
    /// SURVIVAL only (`params.volatility` CALM / SHIFTING / VIOLENT, MP default SHIFTING).
    public let volatility: String?

    public init?(style raw: String?, palette: String?, neon: String?, climate: String? = nil, volatility: String? = nil) {
        guard let style = raw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              Self.styles.contains(style) else { return nil }
        let palette = palette?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let neon = neon?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.style = style
        self.palette = Self.palettes.contains(palette ?? "") ? palette! : "DEFAULT"
        self.neon = Self.neons.contains(neon ?? "") ? neon! : "YELLOW_CYAN"
        let climate = climate?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let volatility = volatility?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.climate = style == "SURVIVAL" ? (Self.climates.contains(climate ?? "") ? climate! : "RAIN") : nil
        self.volatility = style == "SURVIVAL" ? (Self.volatilities.contains(volatility ?? "") ? volatility! : "SHIFTING") : nil
    }

    public static func read<K: CodingKey>(_ container: KeyedDecodingContainer<K>, _ key: K) -> PlayThemeLookTokens? {
        guard container.contains(key) else { return nil }
        if let wire = try? container.decode(Wire.self, forKey: key) { return PlayThemeLookTokens(wire) }
        if let text = try? container.decode(String.self, forKey: key),
           let data = text.data(using: .utf8),
           let wire = try? JSONDecoder().decode(Wire.self, from: data) {
            return PlayThemeLookTokens(wire)
        }
        return nil
    }

    private init?(_ wire: Wire) {
        self.init(style: wire.style, palette: wire.palette, neon: wire.params?.neon ?? wire.neon,
                  climate: wire.params?.climate, volatility: wire.params?.volatility)
    }

    private static let styles: Set<String> = ["STARDUST", "PAPER", "SURVIVAL", "CYBER"]
    private static let palettes: Set<String> = ["DEFAULT", "BLUE", "RED", "YELLOW", "WHITE"]
    private static let neons: Set<String> = ["YELLOW_CYAN", "CYAN_PINK", "RED_CYAN"]
    private static let climates: Set<String> = ["CLEAR", "RAIN", "STORM", "SAND"]
    private static let volatilities: Set<String> = ["CALM", "SHIFTING", "VIOLENT"]

    private struct Wire: Decodable {
        let style: String?
        let palette: String?
        let neon: String?
        let params: Params?
        struct Params: Decodable { let neon: String?; let climate: String?; let volatility: String? }
    }
}

@MainActor public protocol ProfileParticipantListFactsReading: AnyObject {
    func profileParticipantListFacts() async throws -> ProfileParticipantListFacts
}

extension ProfileSessionReader: ProfileParticipantListFactsReading {}

@MainActor public protocol OrientScoreEntryProviding: AnyObject {
    /// Nil hides the entry. The loader returns nil when this player has no single round here.
    func orientScoreLoader(topicID: Int, activityID: Int) -> (() async throws -> OrientSessionScore?)?
    /// Nil hides the entry. Given an optional chosen session id, returns one score, the player's own rounds to choose
    /// from (mini-program `state === 'choosing'`), or nothing (PLY-25-1).
    func orientScoreRoundsLoader(topicID: Int, activityID: Int) -> ((Int?) async throws -> OrientScoreLoad)?
}

/// One round's score, the player's own rounds to choose from, or no round at all.
public enum OrientScoreLoad {
    case score(OrientSessionScore)
    case choose([OrientSessionView])
    case none
}

public extension OrientScoreEntryProviding {
    /// Providers without session discovery keep the single-round loader; a chosen id is ignored.
    func orientScoreRoundsLoader(topicID: Int, activityID: Int) -> ((Int?) async throws -> OrientScoreLoad)? {
        guard let single = orientScoreLoader(topicID: topicID, activityID: activityID) else { return nil }
        return { _ in try await single().map(OrientScoreLoad.score) ?? .none }
    }
}

/// `current` then `score` for the player's own round. `orientScoreLoader` never picks a row when there is more
/// than one session; `orientScoreRoundsLoader` returns the rows so the player chooses (mini-program chooser).
/// Sync, settle, appeal, and dispute are not called.
@MainActor public final class OrientScoreEntryProvider: OrientScoreEntryProviding {
    private let service: OrientSessionService?
    private let token: () -> String?

    public init(service: OrientSessionService?, token: @escaping () -> String?) {
        self.service = service
        self.token = token
    }

    public func orientScoreLoader(topicID: Int, activityID: Int) -> (() async throws -> OrientSessionScore?)? {
        guard let service, service.supportsSessionDiscovery, topicID > 0, activityID >= 0 else { return nil }
        let token = self.token
        return {
            guard let token = token(), AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
            let list = try await service.current(topicID: topicID, activityID: activityID, token: token)
            guard list.sessions.count == 1, let session = list.sessions.first else { return nil }
            return try await service.score(sessionID: session.sessionID, scope: session.scope, token: token)
        }
    }

    public func orientScoreRoundsLoader(topicID: Int, activityID: Int) -> ((Int?) async throws -> OrientScoreLoad)? {
        guard let service, service.supportsSessionDiscovery, topicID > 0, activityID >= 0 else { return nil }
        let token = self.token
        return { chosen in
            guard let token = token(), AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
            let list = try await service.current(topicID: topicID, activityID: activityID, token: token)
            // Only a session the server listed for this player is read; a stale choice goes back to the chooser.
            if let chosen, let session = list.sessions.first(where: { $0.sessionID == chosen }) {
                return .score(try await service.score(sessionID: session.sessionID, scope: session.scope, token: token))
            }
            switch list.sessions.count {
            case 0: return .none
            case 1:
                let session = list.sessions[0]
                return .score(try await service.score(sessionID: session.sessionID, scope: session.scope, token: token))
            default: return .choose(list.sessions)
            }
        }
    }
}

public enum AIGCFilingNumber {
    /// `aigcFilingNo` only when it is a JSON string. Trimmed, capped at 64, empty is nil.
    /// A number or bool is not coerced into a filing number.
    public static func parse(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = root["code"] as? NSNumber, CFGetTypeID(code) != CFBooleanGetTypeID(), code.intValue == 200,
              let values = root["data"] as? [String: Any],
              let raw = values["aigcFilingNo"] as? String else { return nil }
        let value = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        return value.isEmpty ? nil : value
    }
}

public enum ReportProgressUnread {
    /// Unread community notifications whose payload action starts with `REPORT_`.
    /// This is the count of the rows actually returned, not a guessed total.
    public static func count(_ notices: [SquareGovernanceNotification]) -> Int {
        notices.reduce(0) { $0 + (($1.unread && $1.action.hasPrefix("REPORT_")) ? 1 : 0) }
    }
}

/// Reads `api/v1/community/notifications` only when that service's read grant is already on.
/// A disabled grant returns nil so the badge stays hidden. It does not turn the grant on,
/// and it does not mark notifications read: production mutations stay disabled.
@MainActor public final class ReportProgressUnreadReader {
    private let service: SquareGovernanceService
    private let token: () -> String?
    private let accountID: () -> Int?

    public init(service: SquareGovernanceService, token: @escaping () -> String?, accountID: @escaping () -> Int?) {
        self.service = service
        self.token = token
        self.accountID = accountID
    }

    public func unreadCount() async -> Int? {
        guard service.readsEnabled else { return nil }
        let owner = accountID()
        guard let token = token(), AuthRequestBuilder.isValidToken(token), owner != nil else { return nil }
        do {
            let page = try await service.notifications(token: token) {
                guard accountID() == owner else { throw SquareGovernanceFailure.signedOut }
            }
            guard accountID() == owner else { return nil }
            return ReportProgressUnread.count(page)
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    /// Mark-read is a mutation. The production grant does not include it, so this returns
    /// without building a request. A present grant still does not send: the review id belongs
    /// to the governance coordinator, and this reader does not invent one.
    /// Callers must not treat `false` as "nothing was unread".
    public func markOpened() async -> Bool {
        guard service.readsEnabled, service.allows(.markRead(notificationID: 1)) else { return false }
        return false
    }
}

public struct CloudB3RawBody: Equatable, Sendable {
    public let body: Data
    public let status: Int
    public init(body: Data, status: Int) { self.body = body; self.status = status }
}

@MainActor public protocol InformationListReceiptReading: AnyObject {
    func informationListReceipt() async throws -> CloudB3RawBody
}

@MainActor public protocol SquareDetailRawReading: AnyObject {
    func squareDetailBody(id: Int) async throws -> Data
    func squareCommentsBody(postID: Int, pageNumber: Int) async throws -> Data
}

@MainActor public protocol TopicListRawReading: AnyObject {
    func topicListDocument(query: TopicQuery, pageNumber: Int) async throws -> TopicListDocument
}

@MainActor public protocol OfficialEventsReceiptReading: AnyObject {
    func officialEventsReceipt(city: String?) async throws -> CloudB3RawBody
}

extension SocialAccountSessionReader: InformationListReceiptReading {}
extension SquareSessionReader: SquareDetailRawReading {}
extension TopicSessionReader: TopicListRawReading {}
extension OfficialSessionReader: OfficialEventsReceiptReading {}

public struct TopicListDocument: Equatable {
    public let page: TopicPage
    public let body: Data
    public init(page: TopicPage, body: Data) { self.page = page; self.body = body }
}
