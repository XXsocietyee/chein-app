import Foundation

/// One saved replay attempt. The request id stays on the client. The POST body is only `{sessionId}`.
public struct PlayThemeReplayAttempt: Equatable, Sendable, Codable {
    public let requestID: String
    public let sessionID: Int
    public let topicID: Int
    public var readBackSessionID: Int?

    public init(requestID: String, sessionID: Int, topicID: Int, readBackSessionID: Int? = nil) {
        self.requestID = requestID
        self.sessionID = sessionID
        self.topicID = topicID
        self.readBackSessionID = readBackSessionID
    }
}

/// Button state after a focus or a replay. Confirmed is the only success.
/// An unknown post keeps `attempt` and does not report success.
public struct PlayThemeReplayStatus: Equatable, Sendable {
    public var showsButton: Bool
    public var confirmed: Bool
    public var attempt: PlayThemeReplayAttempt?

    public static let hidden = PlayThemeReplayStatus(showsButton: false, confirmed: false, attempt: nil)

    public init(showsButton: Bool, confirmed: Bool, attempt: PlayThemeReplayAttempt?) {
        self.showsButton = showsButton
        self.confirmed = confirmed
        self.attempt = attempt
    }
}

/// Mini-program `replayThemeSession` / `checkThemeReplay` for one finish-sheet session.
/// The service is whatever already reads theme state. This type does not refuse a production host.
@MainActor public enum PlayThemeReplayExchange {
    public static func focus(service: PlayExperienceService, topicID: Int, sessionID: Int, token: String,
                              attempt: PlayThemeReplayAttempt?) async -> PlayThemeReplayStatus {
        guard topicID > 0, sessionID > 0 else { return .hidden }
        if let attempt, attempt.sessionID == sessionID, attempt.topicID == topicID {
            if await confirmed(service: service, token: token, attempt: attempt) {
                return PlayThemeReplayStatus(showsButton: false, confirmed: true, attempt: nil)
            }
            return PlayThemeReplayStatus(showsButton: true, confirmed: false, attempt: attempt)
        }
        switch await read(service: service, topicID: topicID, sessionID: sessionID, token: token) {
        case .facts(let facts):
            let allowed = facts.replayAllowed && facts.sessionID == sessionID && !facts.isTeam
            return PlayThemeReplayStatus(showsButton: allowed, confirmed: false, attempt: nil)
        case .mismatch, .unknown:
            return .hidden
        }
    }

    public static func submit(service: PlayExperienceService, topicID: Int, sessionID: Int, token: String,
                               attempt: PlayThemeReplayAttempt?,
                               makeRequestID: () -> String) async -> PlayThemeReplayStatus {
        guard topicID > 0, sessionID > 0 else { return .hidden }
        if let attempt, attempt.sessionID == sessionID, attempt.topicID == topicID {
            if await confirmed(service: service, token: token, attempt: attempt) {
                return PlayThemeReplayStatus(showsButton: false, confirmed: true, attempt: nil)
            }
            return PlayThemeReplayStatus(showsButton: true, confirmed: false, attempt: attempt)
        }
        let fresh: PlayThemeReplayFacts
        switch await read(service: service, topicID: topicID, sessionID: sessionID, token: token) {
        case .facts(let facts): fresh = facts
        case .mismatch: return .hidden
        case .unknown: return PlayThemeReplayStatus(showsButton: true, confirmed: false, attempt: nil)
        }
        guard fresh.replayAllowed, fresh.sessionID == sessionID, !fresh.isTeam else { return .hidden }
        let requestID = makeRequestID()
        guard !requestID.isEmpty else { return PlayThemeReplayStatus(showsButton: true, confirmed: false, attempt: nil) }
        var pending = PlayThemeReplayAttempt(requestID: requestID, sessionID: sessionID, topicID: topicID)
        let posted: Post
        do {
            let raw = try await service.themeReplay(sessionID: sessionID, token: token)
            posted = .body(raw)
        } catch {
            posted = classify(error)
        }
        switch posted {
        case .body(let raw):
            if let next = raw["sessionId"].tolerantInteger, next > 0 { pending.readBackSessionID = next }
            if await confirmed(service: service, token: token, attempt: pending) {
                return PlayThemeReplayStatus(showsButton: false, confirmed: true, attempt: nil)
            }
            return PlayThemeReplayStatus(showsButton: true, confirmed: false, attempt: pending)
        case .unknown:
            if await confirmed(service: service, token: token, attempt: pending) {
                return PlayThemeReplayStatus(showsButton: false, confirmed: true, attempt: nil)
            }
            return PlayThemeReplayStatus(showsButton: true, confirmed: false, attempt: pending)
        case .refused:
            return PlayThemeReplayStatus(showsButton: false, confirmed: false, attempt: nil)
        case .notSent:
            return PlayThemeReplayStatus(showsButton: true, confirmed: false, attempt: nil)
        }
    }

    private enum Read { case facts(PlayThemeReplayFacts), mismatch, unknown }
    private enum Post { case body(PlayWireValue), unknown, refused, notSent }

    private static func read(service: PlayExperienceService, topicID: Int, sessionID: Int, token: String) async -> Read {
        do {
            let raw = try await service.themeReplayState(topicID: topicID, sessionID: sessionID, token: token)
            guard let facts = PlayThemeReplayFacts(raw) else { return .unknown }
            guard facts.sessionID == sessionID else { return .mismatch }
            return .facts(facts)
        } catch {
            return .unknown
        }
    }

    private static func confirmed(service: PlayExperienceService, token: String, attempt: PlayThemeReplayAttempt) async -> Bool {
        let querySession = attempt.readBackSessionID ?? attempt.sessionID
        guard querySession > 0 else { return false }
        do {
            let raw = try await service.themeReplayState(topicID: attempt.topicID, sessionID: querySession, token: token)
            guard let facts = PlayThemeReplayFacts(raw), facts.sessionID == querySession else { return false }
            return facts.confirmsReplay(of: attempt.sessionID)
        } catch {
            return false
        }
    }

    private static func classify(_ error: Error) -> Post {
        if let error = error as? PlayExperienceError {
            switch error {
            case .unknownResult, .malformed: return .unknown
            case .unauthorized, .rejected: return .refused
            default: return .notSent
            }
        }
        if let error = error as? APIError {
            switch error {
            case .notConfigured, .invalidRequest, .invalidConfiguration: return .notSent
            case .unauthorized: return .refused
            default: return .unknown
            }
        }
        return .unknown
    }
}
