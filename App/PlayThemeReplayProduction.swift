import Foundation
import SwiftUI

extension PlayThemeReplayAttempt {
    private enum Store {
        static func key(accountID: Int, topicID: Int, sessionID: Int) -> String {
            "cy.play.theme.replay.\(accountID).\(topicID).\(sessionID)"
        }

        static func read(accountID: Int?, topicID: Int, sessionID: Int) -> PlayThemeReplayAttempt? {
            guard let accountID, accountID > 0, topicID > 0, sessionID > 0,
                  let data = UserDefaults.standard.data(forKey: key(accountID: accountID, topicID: topicID, sessionID: sessionID)),
                  let attempt = try? JSONDecoder().decode(PlayThemeReplayAttempt.self, from: data),
                  attempt.sessionID == sessionID, attempt.topicID == topicID, !attempt.requestID.isEmpty else { return nil }
            return attempt
        }

        static func write(accountID: Int?, attempt: PlayThemeReplayAttempt?) {
            guard let accountID, accountID > 0 else { return }
            let key = key(accountID: accountID, topicID: attempt?.topicID ?? 0, sessionID: attempt?.sessionID ?? 0)
            guard let attempt, let data = try? JSONEncoder().encode(attempt) else {
                if attempt == nil { return }
                UserDefaults.standard.removeObject(forKey: key)
                return
            }
            UserDefaults.standard.set(data, forKey: key)
        }

        static func clear(accountID: Int?, topicID: Int, sessionID: Int) {
            guard let accountID, accountID > 0 else { return }
            UserDefaults.standard.removeObject(forKey: key(accountID: accountID, topicID: topicID, sessionID: sessionID))
        }
    }

    fileprivate static func saved(accountID: Int?, topicID: Int, sessionID: Int) -> PlayThemeReplayAttempt? {
        Store.read(accountID: accountID, topicID: topicID, sessionID: sessionID)
    }

    fileprivate static func persist(accountID: Int?, topicID: Int, sessionID: Int, attempt: PlayThemeReplayAttempt?) {
        if let attempt {
            Store.write(accountID: accountID, attempt: attempt)
        } else {
            Store.clear(accountID: accountID, topicID: topicID, sessionID: sessionID)
        }
    }
}

/// Production 再玩一次. Uses the session transport that already serves the China composition.
/// Theme state is not given a production-host refusal, and neither is this write.
@MainActor final class PlayThemeReplayProduction: PlayThemeReplayBinding {
    let scope: PlaySessionScope
    let topicID: Int
    private let session: AppSession
    private var focusedSessionID: Int?
    private(set) var allowed = false
    private(set) var showsUnknown = false

    init(session: AppSession, scope: PlaySessionScope, topicID: Int) {
        self.session = session
        self.scope = scope
        self.topicID = topicID
    }

    func focus(sessionID: Int) async -> Bool {
        focusedSessionID = sessionID
        guard let live = liveService() else {
            let saved = PlayThemeReplayAttempt.saved(accountID: session.account?.id, topicID: topicID, sessionID: sessionID)
            allowed = saved != nil
            showsUnknown = saved != nil
            return allowed
        }
        let status = await PlayThemeReplayExchange.focus(service: live.service, topicID: topicID, sessionID: sessionID,
            token: live.token, attempt: PlayThemeReplayAttempt.saved(accountID: live.accountID, topicID: topicID, sessionID: sessionID))
        apply(status, accountID: live.accountID, sessionID: sessionID)
        return allowed
    }

    func replay() async -> Bool {
        guard let sessionID = focusedSessionID, let live = liveService() else { return false }
        let status = await PlayThemeReplayExchange.submit(service: live.service, topicID: topicID, sessionID: sessionID,
            token: live.token,
            attempt: PlayThemeReplayAttempt.saved(accountID: live.accountID, topicID: topicID, sessionID: sessionID),
            makeRequestID: { UUID().uuidString.lowercased() })
        apply(status, accountID: live.accountID, sessionID: sessionID)
        return status.confirmed
    }

    private struct Live {
        let service: PlayExperienceService
        let token: String
        let accountID: Int
    }

    private func liveService() -> Live? {
        guard let accountID = session.account?.id, accountID > 0,
              let token = session.token, AuthRequestBuilder.isValidToken(token),
              let api = session.regionalConfiguration?.apiConfiguration,
              scope.isValid, topicID > 0 else { return nil }
        if case .topic(let scoped) = scope, scoped != topicID { return nil }
        let service = PlayExperienceService(configuration: api, transport: session.runtimeHTTPTransport, enabled: [.reads])
        return Live(service: service, token: token, accountID: accountID)
    }

    private func apply(_ status: PlayThemeReplayStatus, accountID: Int, sessionID: Int) {
        allowed = status.showsButton
        showsUnknown = status.attempt != nil && !status.confirmed
        PlayThemeReplayAttempt.persist(accountID: accountID, topicID: topicID, sessionID: sessionID, attempt: status.attempt)
    }
}

/// One binding per signed-in play scope. A redraw does not mint a new request id.
@MainActor enum PlayThemeReplayBridge {
    @MainActor private final class Slot {
        weak var session: AppSession?
        let scope: PlaySessionScope
        let topicID: Int
        let binding: PlayThemeReplayProduction
        init(session: AppSession, scope: PlaySessionScope, topicID: Int) {
            self.session = session
            self.scope = scope
            self.topicID = topicID
            binding = PlayThemeReplayProduction(session: session, scope: scope, topicID: topicID)
        }
    }

    private static var slots: [Slot] = []

    static func binding(session: AppSession, scope: PlaySessionScope, topicID: Int?) -> PlayThemeReplayProduction? {
        guard let topicID, topicID > 0, scope.isValid else { return nil }
        if case .topic(let scoped) = scope, scoped != topicID { return nil }
        slots.removeAll { $0.session == nil }
        if let existing = slots.first(where: { $0.session === session && $0.scope == scope && $0.topicID == topicID }) {
            return existing.binding
        }
        let created = Slot(session: session, scope: scope, topicID: topicID)
        slots.append(created)
        return created.binding
    }
}
