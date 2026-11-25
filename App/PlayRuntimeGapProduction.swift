import Foundation
import SwiftUI

/// G1 play runtime on the session transport that already serves the China composition
/// (`ReviewedPlayerWriteLeases` play grant + `ChinaReviewedRouteCapability`). Same shape as
/// `PlayThemeReplayProduction`: nothing here is a payment, and nothing rolls locally.
@MainActor final class PlayRuntimeGapProduction {
    let scope: PlaySessionScope
    let topicID: Int
    private weak var session: AppSession?
    private var checks: [String: PlayCheckRuntime] = [:]

    init(session: AppSession, scope: PlaySessionScope, topicID: Int) {
        self.session = session; self.scope = scope; self.topicID = topicID
    }

    var ownerID: Int? { session?.account?.id }

    func client() -> PlayRuntimeClient? {
        guard let session, let accountID = session.account?.id, accountID > 0,
              let token = session.token, AuthRequestBuilder.isValidToken(token),
              let api = session.regionalConfiguration?.apiConfiguration, scope.isValid, topicID > 0 else { return nil }
        if case .topic(let scoped) = scope, scoped != topicID { return nil }
        return try? PlayRuntimeClient(configuration: api, transport: session.runtimeHTTPTransport, token: token)
    }

    var activityID: Int? { if case .activity(let id) = scope { return id }; return nil }

    /// `GET api/play/encounter` is the check's source (`enc.check`, `allowedActions` contains `check`).
    func encounterCheck(nodeID: Int) async -> JourneyCheckProblem? {
        guard nodeID > 0, let client = client() else { return nil }
        var query = ["topicId": String(topicID), "nodeId": String(nodeID)]
        if let activityID { query["activityId"] = String(activityID) }
        guard let response = try? await client.get("api/play/encounter", query: query), response.ok else { return nil }
        return JourneyCheckProblem(encounter: response.data)
    }

    private var clearedRunEnd = false
    /// `_clearRunSessionEverywhere` on a finished run: one end tombstone per binding.
    func clearRunSessionOnFinish() async {
        guard !clearedRunEnd, let client = client() else { return }
        clearedRunEnd = true
        _ = await PlayRunSessionClear.clear(client: client, scope: scope, savedAt: Int64(Date().timeIntervalSince1970 * 1000))
    }

    /// `GET api/play/theme/state {topicId, activityId?}` for the personal gameplay rows.
    func themeState() async -> PlayWireValue? {
        guard let client = client() else { return nil }
        var query = ["topicId": String(topicID)]
        if let activityID { query["activityId"] = String(activityID) }
        guard let response = try? await client.get("api/play/theme/state", query: query), response.ok,
              response.data.object != nil else { return nil }
        return response.data
    }

    /// One runtime per owner/session/node/check, so a redraw never forgets an in-flight write.
    func checkRuntime(nodeID: Int, routeSessionID: Int?, problem: JourneyCheckProblem) -> PlayCheckRuntime? {
        guard let owner = ownerID, let original = PlayCheckOriginal(owner: owner, sessionID: routeSessionID, nodeID: nodeID,
            checkID: problem.checkID, topicID: topicID, activityID: activityID) else { return nil }
        if let existing = checks[original.storageKey] { return existing }
        let runtime = PlayCheckRuntime(original: original, problem: problem, store: PlayCheckDefaultsPendingStore.shared,
            client: { [weak self] in self?.client() })
        checks[original.storageKey] = runtime
        return runtime
    }
}

/// Device storage for the one pending check write (mini-program `wx.setStorageSync(key, pending)`).
@MainActor final class PlayCheckDefaultsPendingStore: PlayCheckPendingStore {
    static let shared = PlayCheckDefaultsPendingStore()
    private let defaults = UserDefaults.standard
    func read(_ key: String) throws -> PlayCheckPending? {
        guard let data = defaults.data(forKey: "cy.play." + key) else { return nil }
        return try JSONDecoder().decode(PlayCheckPending.self, from: data)
    }
    func write(_ pending: PlayCheckPending?, key: String) throws {
        guard let pending else { defaults.removeObject(forKey: "cy.play." + key); return }
        defaults.set(try JSONEncoder().encode(pending), forKey: "cy.play." + key)
    }
}

/// One binding per signed-in play scope, like `PlayThemeReplayBridge`.
@MainActor enum PlayRuntimeGapBridge {
    @MainActor private final class Slot {
        weak var session: AppSession?
        let binding: PlayRuntimeGapProduction
        init(session: AppSession, binding: PlayRuntimeGapProduction) { self.session = session; self.binding = binding }
    }
    private static var slots: [Slot] = []

    static func binding(session: AppSession, scope: PlaySessionScope, topicID: Int?) -> PlayRuntimeGapProduction? {
        guard let topicID, topicID > 0, scope.isValid else { return nil }
        if case .topic(let scoped) = scope, scoped != topicID { return nil }
        slots.removeAll { $0.session == nil }
        if let existing = slots.first(where: { $0.session === session && $0.binding.scope == scope && $0.binding.topicID == topicID }) {
            return existing.binding
        }
        let created = PlayRuntimeGapProduction(session: session, scope: scope, topicID: topicID)
        slots.append(Slot(session: session, binding: created))
        return created
    }

    /// Topic detail has no play scope yet; setup only needs a signed-in client.
    static func topicClient(session: AppSession) -> (@MainActor () -> PlayRuntimeClient?) {
        { [weak session] in
            guard let session, (session.account?.id ?? 0) > 0, let token = session.token,
                  let api = session.regionalConfiguration?.apiConfiguration else { return nil }
            return try? PlayRuntimeClient(configuration: api, transport: session.runtimeHTTPTransport, token: token)
        }
    }

    /// `POST /api/orient/safety/check`, then `PlayerOrientSafetyDecision`. Kept off `AppSession.swift`.
    static func orientSafety(session: AppSession) -> PlayOrientSafetyCheck {
        { [weak session] topicID in
            guard let session, (session.account?.id ?? 0) > 0, let token = session.token,
                  let api = session.regionalConfiguration?.apiConfiguration else {
                return .retry(PlayerOrientSafetyDecision.retryLine)
            }
            let service = PlayerContentGapService(baseURL: api.baseURL, token: { token }, transport: session.runtimeHTTPTransport)
            return await service.checkOrientSafety(topicID: topicID).decision
        }
    }
}

typealias PlayOrientSafetyCheck = @MainActor (Int) async -> PlayerOrientSafetyDecision

private struct PlayRuntimeGapKey: EnvironmentKey { static let defaultValue: PlayRuntimeGapProduction? = nil }
private struct PlayRuntimeTopicClientKey: EnvironmentKey { static let defaultValue: (@MainActor () -> PlayRuntimeClient?)? = nil }
private struct PlayOrientSafetyKey: EnvironmentKey { static let defaultValue: PlayOrientSafetyCheck? = nil }

extension EnvironmentValues {
    var playRuntimeGap: PlayRuntimeGapProduction? {
        get { self[PlayRuntimeGapKey.self] }
        set { self[PlayRuntimeGapKey.self] = newValue }
    }
    var playRuntimeTopicClient: (@MainActor () -> PlayRuntimeClient?)? {
        get { self[PlayRuntimeTopicClientKey.self] }
        set { self[PlayRuntimeTopicClientKey.self] = newValue }
    }
    /// Nil (fixtures) skips the network check and lets start proceed.
    var playOrientSafety: PlayOrientSafetyCheck? {
        get { self[PlayOrientSafetyKey.self] }
        set { self[PlayOrientSafetyKey.self] = newValue }
    }
}
