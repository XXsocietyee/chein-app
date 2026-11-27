import Foundation
import Observation

public struct PlayAdvancedState: Equatable {
    public let sessionID: Int; public let activityID: Int; public let topicID: Int; public let nodeID: Int
    public let status: String; public let version: Int; public let score: Int?
    public let ownerType: Int?
    public let readyForBase: Bool; public let deadlineAt: Int64?; public let inline: Bool
    public let config: PlayWireValue; public let draws: [PlayWireValue]; public let branch: PlayWireValue
    public let playKit: PlayWireValue; public let multiplayer: PlayWireValue
    public let storyVariables: [String: PlayWireValue]
    public let objectCard: ObjectCard?
    public let modInstallationRuntime: PlayWireValue
    /// UG-03/04 accusation config and the clues this run has earned. `.null` and empty hide the accusation screen.
    public let accusation: PlayWireValue
    public let clues: [PlayWireValue]
    let modInstallationReceipt: PlayWireValue
    public var isMultiplayer: Bool { config["multiplayer"]["enabled"].bool == true }
    public var needsUnverifiedSteps: Bool { playKit["steps"].object != nil && playKit["steps"]["reached"].bool != true }
    public init(_ raw: PlayWireValue) throws {
        guard let session = raw["sessionId"].integer, session > 0, let node = raw["nodeId"].integer, node > 0,
              let version = raw["version"].integer, version >= 0,
              let activity = raw["activityId"].integer, activity >= 0,
              let topic = raw["topicId"].integer, topic > 0,
              let status = raw["status"].text, !status.isEmpty else { throw PlayExperienceError.malformed }
        sessionID = session; activityID = activity; topicID = topic; nodeID = node; self.version = version; self.status = status
        ownerType = raw["ownerType"].integer
        score = raw["score"].integer; readyForBase = raw["readyForBase"].bool == true
        deadlineAt = raw["deadlineAt"].integer.flatMap { $0 > 0 ? Int64($0) : nil }
        inline = raw["present"].text == "inline"; config = raw["config"]; draws = raw["draws"].array ?? []
        branch = raw["branch"]; playKit = raw["playKit"]; multiplayer = raw["multiplayer"]
        storyVariables = raw["vars"].object ?? [:]
        objectCard = PlayObjectCardReceiptDecoder.decode(raw["objectCard"])
        modInstallationRuntime = raw["modInstallationRuntime"]
        accusation = raw["accusation"]; clues = raw["clues"].array ?? []
        modInstallationReceipt = modInstallationRuntime == .null ? .null : raw
    }
    /// `deadlineAt` is a server deadline. This payload has no server clock (`serverNow` is not a field here),
    /// so remaining time is unknown. The device clock must not fill it in.
    public func remainingSeconds(nowMilliseconds: Int64) -> Int? {
        _ = nowMilliseconds
        return nil
    }
}
public enum PlayKitActionCatalog {
    /// Source: Flutter playkit_host.dart plus the newer mini-program playkit-view action catalog.
    /// Bingo is server progress without an action. Walk cannot manufacture encrypted step proof.
    public static let actions: [String: Set<String>] = [
        "sort": ["SUBMIT_SORT"], "match": ["SUBMIT_MATCH"], "classify": ["SUBMIT_CLASSIFY"],
        "compare": ["SUBMIT_COMPARE"], // Current backend-only family, absent from historical client hosts.
        "compass": ["SUBMIT_COMPASS"], "shout": ["START_CHALLENGE", "SUBMIT_SHOUT"],
        "qa": ["SUBMIT_QA"], "branch": ["CHOOSE"], "estimate": ["SUBMIT_ESTIMATE"],
        "pricePair": ["SUBMIT_PRICE_PAIR"], "hiddenObject": ["SUBMIT_HIDDEN_OBJECT"],
        "countdown": ["START_CHALLENGE", "SUBMIT_COUNTDOWN"], "stopwatch": ["START_CHALLENGE", "SUBMIT_STOPWATCH"],
        "blindTaste": ["SUBMIT_BLIND_TASTE"], "diyName": ["SUBMIT_DIY_NAME"], "steps": ["SUBMIT_STEPS"],
        "dailySign": ["CLAIM_DAILY_SIGN"], "slowTask": ["START_SLOW_TASK", "CLAIM_SLOW_TASK"], "silentOrder": [],
        "coinFlip": ["FLIP_COIN"], "diceRoll": ["ROLL_DICE"], "predict": ["SUBMIT_PREDICT", "SKIP_CLOSED_PREDICT"],
        "reaction": ["START_CHALLENGE", "SUBMIT_REACTION"], "ballShake": ["START_CHALLENGE", "SUBMIT_BALL_SHAKE"],
        "quietHold": ["START_CHALLENGE", "SUBMIT_QUIET_HOLD"], "random": ["DRAW"], "scan": ["SUBMIT_SCAN"],
        "profile": ["SUBMIT_PROFILE"], "photoCheck": ["SUBMIT_PHOTO_CHECK", PlayKitInputContract.recordAction], "note": ["SUBMIT_NOTE"],
        "typeIn": ["START_CHALLENGE", "SUBMIT_TYPE_IN"], "timeWindow": [], "musicCorner": [], "walk": [], "gameTimer": [], "stickerBook": [], "bingo": [],
        // UG-01 and the album completion are play actions. Album carries image URLs, not a price or payment.
        "hangman": ["SUBMIT_HANGMAN"], "album": ["SUBMIT_ALBUM"],
        "trueFalse": ["SUBMIT_TRUE_FALSE"], "imageGuess": ["SUBMIT_IMAGE_GUESS"],
        "jigsaw": ["SUBMIT_JIGSAW"], "scratchCard": ["SUBMIT_SCRATCH_CARD"]
    ]
    public static func payload(kind: String, action: String, detail: [String: PlayWireValue]) throws -> [String: PlayWireValue] {
        guard actions[kind]?.contains(action) == true else { throw PlayExperienceError.unsupported }
        switch action {
        case "FLIP_COIN", "ROLL_DICE": return [:] // Never invent a random outcome client-side.
        case "SKIP_CLOSED_PREDICT": return [:] // MP `predict:skip`: the server re-checks that the round is closed.
        case "START_CHALLENGE":
            if ["reaction", "ballShake", "quietHold", "typeIn", "countdown", "stopwatch", "shout"].contains(kind) { return ["game": .string(kind)] }
            return detail
        case "SUBMIT_REACTION":
            guard let times = detail["times"]?.array, !times.isEmpty, times.allSatisfy({ ($0.integer ?? -1) >= 0 }) else { throw PlayExperienceError.invalidAction }
            return ["roundsMs": .array(times)]
        case "SUBMIT_QUIET_HOLD":
            guard let seconds = detail["heldSeconds"]?.double, seconds.isFinite, seconds >= 0, seconds <= 3600 else { throw PlayExperienceError.invalidAction }
            return ["heldMs": .int(Int((seconds * 1000).rounded()))]
        case "SUBMIT_BALL_SHAKE":
            guard let hits = detail["hits"]?.integer, hits >= 0 else { throw PlayExperienceError.invalidAction }
            return ["hits": .int(hits)]
        default: return detail
        }
    }
}

/// reaction, ballShake and quietHold may submit only after START_CHALLENGE was sent.
public enum PlayKitChallengeStartGate {
    public static let kinds: Set<String> = ["reaction", "ballShake", "quietHold"]
    public static let submitActions: Set<String> = ["SUBMIT_REACTION", "SUBMIT_BALL_SHAKE", "SUBMIT_QUIET_HOLD"]
    public static func allowsSubmit(kind: String, action: String, started: Bool) -> Bool {
        guard kinds.contains(kind), submitActions.contains(action) else { return true }
        return started
    }
}

/// Closing the advanced panel also closes a playkit sheet opened from it.
public struct AdvancedPlayKitPresentation: Equatable {
    public var advancedOpen: Bool
    public var playKitOpen: Bool
    public init(advancedOpen: Bool, playKitOpen: Bool) {
        self.advancedOpen = advancedOpen
        self.playKitOpen = playKitOpen
    }
    public func closingAdvancedPanel() -> Self {
        Self(advancedOpen: false, playKitOpen: false)
    }
    /// One sheet at a time: dismissing the playkit sheet leaves the advanced panel as it was.
    public func closingPlayKitSheet() -> Self {
        Self(advancedOpen: advancedOpen, playKitOpen: false)
    }
}

/// A failed leaderboard fetch is an error. An empty successful board is not.
public enum LeaderboardFetchPresentation: Equatable {
    case error, empty, ready, other
    public static func resolve(phase: String, rowCount: Int) -> Self {
        if phase == "failed" { return .error }
        if phase == "ready" { return rowCount == 0 ? .empty : .ready }
        return .other
    }
}

/// A disabled primary action still explains itself when tapped. Money stays off.
public enum DisabledCallToAction {
    public static func reason(enabled: Bool) -> String? {
        guard !enabled else { return nil }
        return W8Text.t(
            "现在不能继续。这一步还没准备好。这台设备不会收款，也不会把订单标成已支付。",
            "You can’t continue yet. This step is not ready. This device will not collect payment or mark an order paid.")
    }
}

/// Silent-order give-up stops the local clock. It is not a completion or subscription.
public struct PlayKitSilentOrderGiveUp: Equatable {
    public var running: Bool
    public var gaveUp: Bool
    public init(running: Bool, gaveUp: Bool = false) {
        self.running = running
        self.gaveUp = gaveUp
    }
    public mutating func giveUp() {
        running = false
        gaveUp = true
    }
}
public struct PlayAdvancedPending: Codable, Equatable {
    public let sessionID: Int; public let version: Int; public let key: String
    public let action: String; public let payload: [String: PlayWireValue]
}
extension PlayExperienceService {
    public func startAdvanced(activityID: Int, topicID: Int, nodeID: Int, token: String) async throws -> PlayAdvancedState {
        guard activityID >= 0, topicID > 0, nodeID > 0 else { throw APIError.invalidRequest }
        var body: [String: PlayWireValue] = ["activityId": .int(activityID), "topicId": .int(topicID), "nodeId": .int(nodeID)]
        body.merge(PlayClientCapabilities.startFields()) { current, _ in current }
        let state = try PlayAdvancedState(await request("api/play/advanced/start", json: body, capability: .advanced, token: token))
        guard state.activityID == activityID, state.topicID == topicID, state.nodeID == nodeID else { throw PlayExperienceError.malformed }
        return state
    }
    public func advancedState(sessionID: Int, token: String) async throws -> PlayAdvancedState {
        guard sessionID > 0 else { throw APIError.invalidRequest }
        let state = try PlayAdvancedState(await request("api/play/advanced/state", query: ["sessionId": String(sessionID)], capability: .reads, token: token))
        guard state.sessionID == sessionID else { throw PlayExperienceError.malformed }; return state
    }
    public func advancedAction(_ pending: PlayAdvancedPending, token: String) async throws -> PlayAdvancedState {
        guard pending.sessionID > 0, pending.version >= 0, !pending.key.isEmpty else { throw APIError.invalidRequest }
        let state = try PlayAdvancedState(await request("api/play/advanced/action", json: [
            "sessionId": .int(pending.sessionID), "version": .int(pending.version), "idempotencyKey": .string(pending.key),
            "action": .string(pending.action), "payload": .object(pending.payload)
        ], capability: .advanced, token: token))
        guard state.sessionID == pending.sessionID, state.version > pending.version else { throw PlayExperienceError.malformed }; return state
    }
    /// `advanced-game resolveUnknown`: `GET api/play/advanced/receipt {sessionId, idempotencyKey}`. Proof for this one
    /// request only: the same session and key, and a view the action produced (version past the one it was sent at).
    public func advancedReceipt(_ pending: PlayAdvancedPending, token: String) async throws -> PlayAdvancedState {
        guard pending.sessionID > 0, !pending.key.isEmpty else { throw APIError.invalidRequest }
        let raw = try await request("api/play/advanced/receipt", query: ["sessionId": String(pending.sessionID), "idempotencyKey": pending.key],
                                    capability: .reads, token: token)
        guard raw["sessionId"].tolerantInteger == pending.sessionID, raw["idempotencyKey"].text == pending.key else { throw PlayExperienceError.malformed }
        let state = try PlayAdvancedState(raw["view"])
        guard state.sessionID == pending.sessionID, state.version > pending.version else { throw PlayExperienceError.malformed }
        return state
    }
    public func advancedLeaderboard(activityID: Int, topicID: Int, nodeID: Int, token: String) async throws -> [PlayWireValue] {
        guard activityID >= 0, topicID > 0, nodeID > 0 else { throw APIError.invalidRequest }
        let value = try await request("api/play/advanced/leaderboard", query: ["activityId": String(activityID), "topicId": String(topicID), "nodeId": String(nodeID)], capability: .reads, token: token)
        guard let rows = value.array, rows.count <= 100, rows.allSatisfy({ ($0["rank"].integer ?? 0) > 0 && ($0["ownerId"].integer ?? 0) > 0 && $0["score"].integer != nil && ($0["elapsedSeconds"].integer ?? -1) >= 0 && ($0["completedUnits"].integer ?? -1) >= 0 && $0["displayName"].text?.isEmpty == false }) else { throw PlayExperienceError.malformed }
        return rows
    }
}
@available(macOS 14.0, *)
@MainActor @Observable public final class PlayAdvancedCoordinator {
    public private(set) var state: PlayAdvancedState?
    public private(set) var pending: PlayAdvancedPending?
    public private(set) var phase = "idle"
    public private(set) var issue: PlayExperienceError?
    public private(set) var leaderboard: [PlayWireValue] = []
    public private(set) var leaderboardPhase = "idle"
    public private(set) var playKitPresentation = AdvancedPlayKitPresentation(advancedOpen: true, playKitOpen: false)
    private var acknowledgedChallengeStarts = Set<String>()
    private var leaderboardGeneration: UInt64 = 0
    private var teamSurfaceRevision: UInt64 = 0
    private var teamSurfaceActive = false
    private let defaultTeamSurfaceID = UUID()
    private var teamSurfaceOwner: UUID?
    public var canTeamInteract: Bool {
        canInteract && (state?.deadlineAt.map { $0 > Int64(Date().timeIntervalSince1970 * 1000) } ?? true)
    }
    public var teamProjection: PlayAdvancedTeamProjection? {
        guard isCurrent, !["stale", "disabled"].contains(phase), let state, let owner else { return nil }
        return .init(state: state, actorID: owner.accountID)
    }
    public var leaderboardMetric: PlayAdvancedLeaderboardMetric? {
        guard isCurrent, !["stale", "disabled"].contains(phase), let state, state.config["leaderboard"]["enabled"].bool == true else { return nil }
        return state.config["leaderboard"]["metric"].text.flatMap(PlayAdvancedLeaderboardMetric.init(rawValue:))
    }
    public func beginTeamSurface(id: UUID? = nil) {
        let identity = id ?? defaultTeamSurfaceID
        guard teamSurfaceOwner != identity else { return }
        teamSurfaceOwner = identity; teamSurfaceActive = true; teamSurfaceRevision &+= 1
        clearAdvancedLeaderboard()
    }
    public func endTeamSurface(id: UUID? = nil) {
        guard teamSurfaceOwner == (id ?? defaultTeamSurfaceID) else { return }
        teamSurfaceOwner = nil; teamSurfaceActive = false; teamSurfaceRevision &+= 1
        clearAdvancedLeaderboard()
    }
    private func clearAdvancedLeaderboard() {
        leaderboardGeneration &+= 1; leaderboard = []; leaderboardPhase = "idle"
    }
    public func loadAdvancedLeaderboard(surfaceID: UUID? = nil) async {
        guard teamSurfaceOwner == (surfaceID ?? defaultTeamSurfaceID), teamSurfaceActive, isCurrent, let session = owner, let state, let metric = leaderboardMetric,
              leaderboardPhase != "loading" else { return }
        leaderboardGeneration &+= 1; let request = leaderboardGeneration
        let surface = teamSurfaceRevision; let runtimeGeneration = generation; leaderboardPhase = "loading"; leaderboard = []
        do {
            let rows = try await service.advancedLeaderboard(activityID: activityID, topicID: topicID, nodeID: nodeID, token: session.token)
            guard request == leaderboardGeneration else { return }
            guard teamSurfaceActive, surface == teamSurfaceRevision, currentSession() == session,
                  self.state?.sessionID == state.sessionID, self.state?.version == state.version,
                  leaderboardMetric == metric else { leaderboardPhase = "idle"; return }
            leaderboard = rows; leaderboardPhase = "ready"
        } catch {
            guard request == leaderboardGeneration else { return }
            guard teamSurfaceActive, surface == teamSurfaceRevision, currentSession() == session else { leaderboardPhase = "idle"; return }
            if case PlayExperienceError.unauthorized = error {
                failure(error, session: session, generation: runtimeGeneration)
            } else if case APIError.unauthorized = error {
                failure(error, session: session, generation: runtimeGeneration)
            } else { leaderboard = []; leaderboardPhase = "failed" }
        }
    }
    public func reviewTeamAction(_ action: PlayAdvancedTeamReview.Action, surfaceID: UUID? = nil) throws -> PlayAdvancedTeamReview {
        guard let surfaceOwner = teamSurfaceOwner, surfaceOwner == (surfaceID ?? defaultTeamSurfaceID), teamSurfaceActive, canTeamInteract, let state, let owner, let team = teamProjection else { throw PlayExperienceError.staleSession }
        switch action {
        case .assign(let memberID, let roleID):
            guard team.canAssign(memberID: memberID, roleID: roleID) else { throw PlayExperienceError.invalidAction }
            return .init(action: action, sessionID: state.sessionID, nodeID: state.nodeID, version: state.version,
                         memberName: team.members.first { $0.id == memberID }?.name, roleLabel: team.roleLabel(roleID), owner: owner, surfaceRevision: teamSurfaceRevision, surfaceID: surfaceOwner)
        case .completeUnit:
            guard team.canRequestUnit else { throw PlayExperienceError.invalidAction }
            return .init(action: action, sessionID: state.sessionID, nodeID: state.nodeID, version: state.version,
                         memberName: nil, roleLabel: team.myRole.map(team.roleLabel), owner: owner, surfaceRevision: teamSurfaceRevision, surfaceID: surfaceOwner)
        }
    }
    public func submitTeamReview(_ review: PlayAdvancedTeamReview) async {
        guard teamSurfaceActive, review.surfaceRevision == teamSurfaceRevision,
              review.surfaceID == teamSurfaceOwner, review.owner == currentSession() else { return }
        guard state?.sessionID == review.sessionID, state?.nodeID == review.nodeID, state?.version == review.version,
              (try? reviewTeamAction(review.action, surfaceID: review.surfaceID)) != nil else { issue = .staleSession; return }
        switch review.action {
        case .assign(let memberID, let roleID): await assignRole(memberID: memberID, roleID: roleID)
        case .completeUnit: await completeUnit()
        }
    }
    private var cardReceipts = PlayObjectCardReceiptCache()
    private var cardLifetime: UInt64 = 0
    private var pendingRequestedCard = false
    public var objectCardReceipt: PlayObjectCardReceipt? { isCurrent ? cardReceipts.receipt : nil }
    public func clearObjectCardReceipt() { cardLifetime &+= 1; cardReceipts.clear() }
    let activityID: Int; let topicID: Int; let nodeID: Int
    let service: PlayExperienceService
    let currentSession: () -> PlayExperienceSession?
    private var owner: PlayExperienceSession?
    private var generation: UInt64 = 0
    private let modGameplayMode: PlayGameplayMode?
    private let modJournal: ModInstallationNativeRuntimeJournal?
    private var modRecord: ModInstallationNativeRuntimeRecord?
    private var modJournalReadFailed = false
    private var modProofRequired = false
    private var modActionReceipt: PlayAdvancedState?
    public var modInstallationActionReceipt: PlayAdvancedState? { isCurrent && phase != "stale" && phase != "disabled" ? modActionReceipt : nil }
    public var modInstallationActionKey: String? { modInstallationActionReceipt == nil ? nil : modRecord?.command.key }
    public var modInstallationRecoveryRequired: Bool { modRecord?.settled == false || modJournalReadFailed }
    private let recovery: (any PlayAdvancedRecovery)?
    private var recoverySnapshot: PlayAdvancedRecoverySnapshot?
    public private(set) var startOutcomeUnknown = false
    public init(activityID: Int, topicID: Int, nodeID: Int, service: PlayExperienceService, modJournal: ModInstallationNativeRuntimeJournal? = nil, modGameplayMode: PlayGameplayMode? = nil, recovery: (any PlayAdvancedRecovery)? = nil, currentSession: @escaping () -> PlayExperienceSession?) {
        self.modJournal = modJournal; self.modGameplayMode = modGameplayMode
        if let recovery { self.recovery = recovery }
        else if service.transport is PlayRecoveryRecordingTransport { self.recovery = nil }
        else { self.recovery = PlayUnavailableAdvancedRecovery() }
        self.activityID = activityID; self.topicID = topicID; self.nodeID = nodeID; self.service = service; self.currentSession = { service.hasCurrentReadLifetime ? currentSession() : nil }
    }
    public var readLifetimeID: String? { service.readLifetimeID }
    public var hasCurrentReadLifetime: Bool { service.hasCurrentReadLifetime }
    public var blocksReadRebinding: Bool { modInstallationRecoveryRequired || recoverySnapshot != nil || startOutcomeUnknown || pending != nil || ["loading", "submitting", "unknown", "retryable"].contains(phase) }
    public func start() async {
        if recovery != nil { await startDurably(); return }
        guard !startOutcomeUnknown, state == nil, ["idle", "rejected", "disabled"].contains(phase), let session = currentSession() else { return }
        generation &+= 1; let generation = generation; owner = session; phase = "loading"
        startOutcomeUnknown = true
        do {
            if try restoreModCommand(session: session) {
                startOutcomeUnknown = false; phase = "unknown"; await recover(); return
            }
            try accept(await service.startAdvanced(activityID: activityID, topicID: topicID, nodeID: nodeID, token: session.token), session: session, generation: generation)
            startOutcomeUnknown = false
        } catch {
            // Only a definite non-dispatch/rejection clears the start lock. A
            // retired lease, lost response or stale401 is not an idempotency proof.
            if case PlayExperienceError.disabled = error { startOutcomeUnknown = false }
            if case PlayExperienceError.rejected = error { startOutcomeUnknown = false }
            failure(error, session: session, generation: generation)
        }
    }
    public var isCurrent: Bool { owner != nil && owner == currentSession() }
    public var canInteract: Bool {
        isCurrent && phase == "ready" && pending == nil && !modInstallationRecoveryRequired && state?.status == "RUNNING" &&
        (!modProofRequired || (modJournal != nil && state.flatMap { try? ModInstallationNativeRuntimeProof(state: $0) } != nil))
    }
    /// A fresh same-mode host may read the original journal; this never rebinds the retired host.
    public func canRestoreModAfterRetiredRead(gameplayMode: PlayGameplayMode) -> Bool {
        !hasCurrentReadLifetime && modJournal != nil && modInstallationRecoveryRequired && modGameplayMode == gameplayMode
    }
    public func review(kind: String, action: String, detail: [String: PlayWireValue] = [:]) throws -> PlayKitActionReview {
        guard canInteract, let state, let owner else { throw PlayExperienceError.staleSession }
        guard state.playKit[kind].object != nil || state.config[kind]["enabled"].bool == true else { throw PlayExperienceError.unsupported }
        let started = acknowledgedChallengeStarts.contains("\(state.sessionID)|\(kind)") || state.playKit[kind]["started"].bool == true
        guard PlayKitChallengeStartGate.allowsSubmit(kind: kind, action: action, started: started) else { throw PlayExperienceError.invalidAction }
        let payload = try PlayKitActionCatalog.payload(kind: kind, action: action, detail: detail)
        // Existing mechanical branch/random projections live outside playKit.
        let segment: PlayWireValue
        if state.playKit[kind].object != nil { segment = state.playKit[kind] }
        else if kind == "branch" { segment = state.branch }
        else if kind == "random" { segment = .object(["drawn": .array(state.draws), "drawCount": state.config["random"]["drawCount"]]) }
        else { segment = state.config[kind] }
        try PlayKitInputContract.validate(kind: kind, action: action, payload: payload, segment: segment)
        return PlayKitActionReview(state: state, owner: owner, kind: kind, action: action, payload: payload)
    }
    /// Read model for the timed-challenge page. It does not send, and a missing advanced grant or route stays hidden.
    public func timedChallengePage(kind: PlayKitScreenKind, configuration: RegionalConfiguration) -> PlayKitTimedChallengePage {
        PlayKitTimedChallengePage.project(kind: kind, playKit: state?.playKit, coordinatorPhase: phase,
            advancedEnabled: service.enabled.contains(.advanced), configuration: configuration)
    }
    @discardableResult public func submit(_ review: PlayKitActionReview) async -> Bool {
        guard canInteract, let state, owner == review.owner, currentSession() == review.owner,
              state.sessionID == review.sessionID, state.version == review.version else {
            issue = .staleSession; return false
        }
        pendingRequestedCard = review.kind == "photoCheck" && state.playKit["photoCheck"]["mode"].text == "CARD"
        let command = PlayAdvancedPending(sessionID: review.sessionID, version: review.version,
            key: review.id.uuidString, action: review.action, payload: review.payload)
        do { try prepareModCommand(command, state: state, session: review.owner) }
        catch { failure(error, session: review.owner, generation: generation, preservePending: true); return false }
        pending = command
        await sendPending()
        let sent = pending == nil && phase == "ready" && self.state?.sessionID == review.sessionID && (self.state?.version ?? -1) > review.version
        if sent, review.action == "START_CHALLENGE", PlayKitChallengeStartGate.kinds.contains(review.kind) {
            acknowledgedChallengeStarts.insert("\(review.sessionID)|\(review.kind)")
        }
        return sent
    }
    public func closeAdvancedPanel() {
        playKitPresentation = playKitPresentation.closingAdvancedPanel()
    }
    public func openPlayKitSheet() {
        playKitPresentation.playKitOpen = true
        playKitPresentation.advancedOpen = true
    }
    /// The playkit sheet over the pack was dismissed. The advanced panel stays open.
    public func closePlayKitSheet() {
        playKitPresentation = playKitPresentation.closingPlayKitSheet()
    }
    public func submit(kind: String, action: String, detail: [String: PlayWireValue] = [:]) async {
        do { _ = await submit(try review(kind: kind, action: action, detail: detail)) }
        catch { issue = error as? PlayExperienceError ?? .invalidAction }
    }
    public func assignRole(memberID: Int, roleID: String) async {
        guard canTeamInteract, let state, let team = teamProjection, team.canAssign(memberID: memberID, roleID: roleID), owner == currentSession(),
              state.multiplayer["members"].array?.contains(where: { $0["memberId"].integer == memberID }) == true,
              state.config["multiplayer"]["roles"].array?.contains(where: { $0["id"].text == roleID }) == true else { return }
        pending = .init(sessionID: state.sessionID, version: state.version, key: UUID().uuidString, action: "ASSIGN_ROLE", payload: ["memberId": .int(memberID), "roleId": .string(roleID)])
        await sendPending()
    }
    public func completeUnit() async {
        guard canTeamInteract, let state, teamProjection?.canRequestUnit == true, owner == currentSession() else { return }
        // Source builds one unit per session/version. This is a local idempotency identity, not outcome proof.
        let unitID = "unit-\(state.sessionID)-v\(state.version)"
        pending = .init(sessionID: state.sessionID, version: state.version, key: UUID().uuidString, action: "COMPLETE_UNIT", payload: ["unitId": .string(unitID)])
        await sendPending()
    }
    private func sendPending() async {
        if recovery != nil { await sendPendingDurably(); return }
        guard let pending, let session = owner, session == currentSession() else { return }
        // A rejection of a replay is not proof that the earlier request did not
        // commit. Keep its immutable idempotency key until its own result returns.
        let preservesUnknown = phase == "retryable" || phase == "unknown"
        let generation = generation; let cardLifetime = cardLifetime; phase = "submitting"
        do {
            if modRecord?.receipt != nil { try await finishModReadback(session: session, generation: generation); return }
            let result = try await service.advancedAction(pending, token: session.token)
            try validate(result, session: session, generation: generation)
            if var record = modRecord, !record.settled {
                try record.validateResult(result)
                record.receipt = result.modInstallationReceipt
                try persistMod(record, session: session)
                modActionReceipt = result
                try await finishModReadback(session: session, generation: generation); return
            }
            try accept(result, session: session, generation: generation)
            if self.cardLifetime == cardLifetime { cardReceipts.accept(result, owner: session, pending: pending, requestedCard: pendingRequestedCard) }
            self.pending = nil; pendingRequestedCard = false
        } catch { failure(error, session: session, generation: generation, preservePending: preservesUnknown) }
    }
    public func recover() async {
        if recovery != nil { await recoverDurably(); return }
        guard let session = owner, session == currentSession(), phase == "unknown",
              pending != nil || modJournalReadFailed || modRecord?.receipt != nil else { return }
        let generation = generation; phase = "loading"
        do {
            if modJournalReadFailed {
                guard try restoreModCommand(session: session) else {
                    startOutcomeUnknown = false; issue = nil; phase = state == nil ? "idle" : "ready"; return
                }
            }
            guard let pending else { throw PlayExperienceError.persistenceUnavailable }
            if modRecord?.receipt != nil { try await finishModReadback(session: session, generation: generation); return }
            // The original request's own receipt settles it; anything else leaves only the exact replay.
            if modRecord == nil, let receipt = try? await service.advancedReceipt(pending, token: session.token) {
                try validate(receipt, session: session, generation: generation)
                settleFromReceipt(receipt, pending: pending, session: session)
                try accept(state.flatMap { $0.sessionID == receipt.sessionID && $0.version > receipt.version ? $0 : nil } ?? receipt,
                           session: session, generation: generation)
                return
            }
            let result = try await service.advancedState(sessionID: pending.sessionID, token: session.token)
            try validate(result, session: session, generation: generation)
            guard result.version >= pending.version else { throw PlayExperienceError.malformed }
            if let record = modRecord, !record.settled {
                guard try ModInstallationNativeRuntimeProof(state: result) == record.proof else { throw PlayExperienceError.malformed }
            }
            state = result
            cardReceipts.reconcile(result, owner: session)
            // Version advancement alone is NOT proof, including on a single-user run.
            // Expose only replay of the frozen idempotent request after explicit review.
            phase = "retryable"
        } catch { failure(error, session: session, generation: generation, preservePending: true) }
    }
    public func retryExact() async { guard phase == "retryable" else { return }; await sendPending() }
    public func refreshAuthoritative() async {
        if pending != nil || modInstallationRecoveryRequired { if phase == "unknown" { await recover() }; return }
        guard phase != "submitting", let state, let session = owner, session == currentSession() else { return }
        let generation = generation; phase = "loading"
        do { try accept(await service.advancedState(sessionID: state.sessionID, token: session.token), session: session, generation: generation) }
        catch { failure(error, session: session, generation: generation) }
    }
    private func durableScope() throws -> PlayAdvancedRecoveryScope {
        try .init(activityID: activityID, topicID: topicID, nodeID: nodeID)
    }
    private func checkDurableOwner(_ session: PlayExperienceSession, _ generation: UInt64) throws {
        guard self.generation == generation, currentSession() == session, !Task.isCancelled else { throw PlayExperienceError.staleSession }
        try service.checkReadLifetime()
    }
    private func durableFailure(_ error: Error, session: PlayExperienceSession, generation: UInt64) {
        failure(error, session: session, generation: generation, preservePending: true)
        if self.generation == generation, currentSession() == session, phase != "stale",
           recoverySnapshot != nil || startOutcomeUnknown { phase = "unknown" }
    }
    private func startDurably() async {
        guard let recovery, !startOutcomeUnknown, state == nil,
              ["idle", "rejected", "disabled"].contains(phase), let session = currentSession() else { return }
        generation &+= 1; let generation = generation; owner = session; phase = "loading"
        do {
            _ = try restoreModCommand(session: session)
            let scope = try durableScope()
            let stored = try await recovery.read()
            try checkDurableOwner(session, generation)
            if let stored {
                guard stored.value.sharedPlanR5 == nil, stored.value.sharedPlanStart == nil else { throw PlayExperienceError.persistenceUnavailable }
                try stored.value.validate(session: session, scope: scope)
                recoverySnapshot = stored
                if stored.value.phase == .starting {
                    // No HTTP lookup identifies a lost start response. Keep its durable
                    // marker; /start may select a newer server instance and is not a read.
                    startOutcomeUnknown = true; phase = "unknown"; issue = .unknownResult; return
                }
                if stored.value.phase == .started { startOutcomeUnknown = true }
                else {
                    guard let original = stored.value.pending else { throw PlayExperienceError.persistenceUnavailable }
                    pending = original; pendingRequestedCard = stored.value.requestedCard
                }
                phase = "unknown"; await recoverDurably(); return
            }
            guard !modInstallationRecoveryRequired else { throw PlayExperienceError.persistenceUnavailable }
            guard service.enabled.contains(.advanced) else { throw PlayExperienceError.disabled }
            let marker = try PlayAdvancedRecoveryRecord(session: session, scope: scope, process: recovery.processID)
            recoverySnapshot = try await recovery.prepare(marker)
            startOutcomeUnknown = true
            try checkDurableOwner(session, generation)
            let result = try await service.startAdvanced(activityID: activityID, topicID: topicID, nodeID: nodeID, token: session.token)
            try validate(result, session: session, generation: generation)
            guard let prepared = recoverySnapshot else { throw PlayExperienceError.persistenceUnavailable }
            recoverySnapshot = try await recovery.transition(prepared, to: .started, startedSessionID: result.sessionID)
            try checkDurableOwner(session, generation)
            guard let acknowledged = recoverySnapshot else { throw PlayExperienceError.persistenceUnavailable }
            try await recovery.clear(acknowledged)
            try checkDurableOwner(session, generation)
            try accept(result, session: session, generation: generation)
            recoverySnapshot = nil; startOutcomeUnknown = false
        } catch { durableFailure(error, session: session, generation: generation) }
    }
    private func sendPendingDurably() async {
        guard let recovery, let pending, let session = owner, session == currentSession() else { return }
        let generation = generation; let cardLifetime = cardLifetime; phase = "submitting"
        do {
            try checkDurableOwner(session, generation)
            if modProofRequired {
                guard let record = modRecord,
                      try PlayAdvancedFrozenAction.requestBytes(record.command) == PlayAdvancedFrozenAction.requestBytes(pending) else {
                    throw PlayExperienceError.persistenceUnavailable
                }
            }
            if modRecord?.receipt != nil { try await finishModEncryptedReadback(session: session, generation: generation); return }
            guard service.enabled.contains(.advanced) else { throw PlayExperienceError.disabled }
            if recoverySnapshot == nil {
                let record = try PlayAdvancedRecoveryRecord(session: session, scope: durableScope(), pending: pending, requestedCard: pendingRequestedCard)
                recoverySnapshot = try await recovery.prepare(record)
                try checkDurableOwner(session, generation)
            }
            guard let prepared = recoverySnapshot, let original = prepared.value.pending,
                  try PlayAdvancedFrozenAction.requestBytes(original) == PlayAdvancedFrozenAction.requestBytes(pending) else { throw PlayExperienceError.persistenceUnavailable }
            recoverySnapshot = try await recovery.transition(prepared, to: .dispatching, startedSessionID: nil)
            try checkDurableOwner(session, generation)
            let result = try await service.advancedAction(pending, token: session.token)
            try validate(result, session: session, generation: generation)
            if var record = modRecord, !record.settled {
                try record.validateResult(result)
                record.receipt = result.modInstallationReceipt
                try persistMod(record, session: session)
                modActionReceipt = result
            }
            guard let dispatched = recoverySnapshot else { throw PlayExperienceError.persistenceUnavailable }
            recoverySnapshot = try await recovery.transition(dispatched, to: .acknowledged, startedSessionID: nil)
            try checkDurableOwner(session, generation)
            if modRecord?.receipt != nil { try await finishModEncryptedReadback(session: session, generation: generation); return }
            guard let acknowledged = recoverySnapshot else { throw PlayExperienceError.persistenceUnavailable }
            try await recovery.clear(acknowledged)
            try checkDurableOwner(session, generation)
            // An exact replay can return its older original receipt. Retire that
            // request without replacing a newer authoritative projection with it.
            let display = state.flatMap { $0.sessionID == result.sessionID && $0.version > result.version ? $0 : nil } ?? result
            try accept(display, session: session, generation: generation)
            if self.cardLifetime == cardLifetime { cardReceipts.accept(result, owner: session, pending: pending, requestedCard: pendingRequestedCard) }
            cardReceipts.reconcile(display, owner: session)
            self.pending = nil; pendingRequestedCard = false; recoverySnapshot = nil
        } catch {
            if let stored = recoverySnapshot, stored.value.phase == .dispatching,
               let unknown = try? await recovery.transition(stored, to: .unknown, startedSessionID: nil) { recoverySnapshot = unknown }
            // Even a business error may follow committed server work. The original
            // stays durable; no error response is manufactured into a non-commit receipt.
            durableFailure(error, session: session, generation: generation)
        }
    }
    private func recoverDurably() async {
        guard let recovery, let session = owner, session == currentSession(), phase == "unknown" else { return }
        let generation = generation; phase = "loading"
        do {
            _ = try restoreModCommand(session: session)
            var observed = try await recovery.read()
            try checkDurableOwner(session, generation)
            if observed == nil, recoverySnapshot == nil, modInstallationRecoveryRequired {
                throw PlayExperienceError.persistenceUnavailable // Never invent the missing encrypted companion.
            }
            if observed == nil, recoverySnapshot == nil, let pending {
                // prepare never returned, so this coordinator never dispatched.
                // Retry persistence of that same original, not a new review/key.
                let record = try PlayAdvancedRecoveryRecord(session: session, scope: durableScope(), pending: pending, requestedCard: pendingRequestedCard)
                observed = try await recovery.prepare(record); recoverySnapshot = observed
                try checkDurableOwner(session, generation)
            }
            if observed == nil, recoverySnapshot == nil, pending == nil, !startOutcomeUnknown {
                // No original was ever dispatched after a failed initial store read.
                // Reopening the start control is safe; this does not send a request.
                phase = "idle"; issue = nil; return
            }
            // An acknowledged clear may have committed before its storage error.
            // Only this already-acknowledged local snapshot can explain an empty slot.
            guard let stored = observed ?? (recoverySnapshot?.value.canClear == true ? recoverySnapshot : nil) else { throw PlayExperienceError.persistenceUnavailable }
            try stored.value.validate(session: session, scope: durableScope())
            recoverySnapshot = stored
            if stored.value.phase == .starting {
                startOutcomeUnknown = true; phase = "unknown"; issue = .unknownResult; return
            }
            if let original = stored.value.pending {
                if let pending {
                    guard try PlayAdvancedFrozenAction.requestBytes(original) == PlayAdvancedFrozenAction.requestBytes(pending) else { throw PlayExperienceError.persistenceUnavailable }
                }
                pending = original; pendingRequestedCard = stored.value.requestedCard
            }
            if modProofRequired {
                guard let record = modRecord, let pending,
                      try PlayAdvancedFrozenAction.requestBytes(record.command) == PlayAdvancedFrozenAction.requestBytes(pending) else {
                    throw PlayExperienceError.persistenceUnavailable
                }
                if record.receipt != nil { try await finishModEncryptedReadback(session: session, generation: generation); return }
                guard !stored.value.canClear else { throw PlayExperienceError.persistenceUnavailable }
            }
            // A second viewer must not replay an action still in flight in this process.
            if stored.value.phase == .dispatching, stored.value.dispatchProcess == recovery.processID {
                phase = "unknown"; issue = .unknownResult; return
            }
            guard let sessionID = stored.value.sessionID else { throw PlayExperienceError.persistenceUnavailable }
            if !stored.value.canClear, !modProofRequired, let pending,
               let receipt = try? await service.advancedReceipt(pending, token: session.token) {
                try validate(receipt, session: session, generation: generation)
                try await retireDurably(stored, recovery: recovery, session: session, generation: generation)
                settleFromReceipt(receipt, pending: pending, session: session)
                recoverySnapshot = nil; startOutcomeUnknown = false
                try accept(state.flatMap { $0.sessionID == receipt.sessionID && $0.version > receipt.version ? $0 : nil } ?? receipt,
                           session: session, generation: generation)
                return
            }
            let result = try await service.advancedState(sessionID: sessionID, token: session.token)
            try validate(result, session: session, generation: generation)
            if let pending { guard result.version >= pending.version else { throw PlayExperienceError.malformed } }
            if let record = modRecord, !record.settled {
                guard try ModInstallationNativeRuntimeProof(state: result) == record.proof else { throw PlayExperienceError.malformed }
            }
            if stored.value.canClear {
                if stored.value.phase == .acknowledged, let pending {
                    guard result.version > pending.version else { throw PlayExperienceError.malformed }
                }
                if observed != nil { try await recovery.clear(stored); try checkDurableOwner(session, generation) }
                try accept(result, session: session, generation: generation)
                recoverySnapshot = nil; pending = nil; pendingRequestedCard = false; startOutcomeUnknown = false
            } else {
                guard pending != nil else { throw PlayExperienceError.persistenceUnavailable }
                state = result; cardReceipts.reconcile(result, owner: session)
                // This read authorizes no new action and proves no outcome. Only
                // the original immutable request may be explicitly replayed next.
                phase = "retryable"; issue = nil
            }
        } catch { durableFailure(error, session: session, generation: generation) }
    }
    private func restoreModCommand(session: PlayExperienceSession) throws -> Bool {
        guard let modJournal else { return false }
        do {
            let loaded = try modJournal.load(owner: session, realm: service.configuration.baseURL.absoluteString, activity: activityID, topic: topicID, node: nodeID, gameplayMode: modGameplayMode)
            // No app path deletes an unresolved record. Missing storage cannot release an in-memory dispatched command.
            if modRecord?.settled == false {
                guard loaded?.command == modRecord?.command else { throw PlayExperienceError.persistenceUnavailable }
            }
            modRecord = loaded; modJournalReadFailed = false
            if modRecord != nil { modProofRequired = true }
            guard let record = modRecord, !record.settled || pending?.key == record.command.key else { return false }
            pending = record.command
            modActionReceipt = try record.receipt.map(PlayAdvancedState.init)
            return true
        } catch { modJournalReadFailed = true; throw PlayExperienceError.persistenceUnavailable }
    }

    private func prepareModCommand(_ command: PlayAdvancedPending, state: PlayAdvancedState, session: PlayExperienceSession) throws {
        guard state.modInstallationRuntime != .null else { return }
        guard let modJournal, modRecord?.settled != false else { throw PlayExperienceError.persistenceUnavailable }
        let record = try ModInstallationNativeRuntimeRecord(owner: session, realm: service.configuration.baseURL.absoluteString, gameplayMode: modGameplayMode,
            proof: ModInstallationNativeRuntimeProof(state: state), command: command)
        do {
            try modJournal.save(record, replacing: modRecord, owner: session)
            modRecord = record; modActionReceipt = nil
        } catch {
            // A failed read-back may follow a successful write. Reload that exact slot before any new command.
            modJournalReadFailed = true; throw error
        }
    }

    private func persistMod(_ record: ModInstallationNativeRuntimeRecord, session: PlayExperienceSession) throws {
        guard let modJournal, currentSession() == session else { throw PlayExperienceError.staleSession }
        do { try modJournal.save(record, replacing: modRecord, owner: session); modRecord = record }
        catch { modJournalReadFailed = true; throw PlayExperienceError.persistenceUnavailable }
    }

    private func finishModReadback(session: PlayExperienceSession, generation: UInt64) async throws {
        guard var record = modRecord, let receipt = record.receipt else { throw PlayExperienceError.malformed }
        let original = try PlayAdvancedState(receipt)
        let latest = try await service.advancedState(sessionID: record.command.sessionID, token: session.token)
        try validate(latest, session: session, generation: generation)
        guard try ModInstallationNativeRuntimeProof(state: latest) == record.proof,
              latest.version >= max(original.version, state?.version ?? original.version) else { throw PlayExperienceError.malformed }
        record.settled = true
        try persistMod(record, session: session)
        modActionReceipt = original; pending = nil; pendingRequestedCard = false
        try accept(latest, session: session, generation: generation)
    }

    /// A MOD receipt never advances an encrypted UNKNOWN or foreign in-flight marker.
    private func finishModEncryptedReadback(session: PlayExperienceSession, generation: UInt64) async throws {
        guard let recovery, let record = modRecord, let receipt = record.receipt else { throw PlayExperienceError.persistenceUnavailable }
        if recoverySnapshot == nil { recoverySnapshot = try await recovery.read(); try checkDurableOwner(session, generation) }
        guard let stored = recoverySnapshot, let command = stored.value.pending,
              try PlayAdvancedFrozenAction.requestBytes(command) == PlayAdvancedFrozenAction.requestBytes(record.command) else {
            throw PlayExperienceError.persistenceUnavailable
        }
        try stored.value.validate(session: session, scope: durableScope())
        let original = try PlayAdvancedState(receipt)
        try record.validateResult(original)
        if stored.value.phase != .acknowledged {
            guard stored.value.phase == .dispatching, stored.value.dispatchProcess == recovery.processID else {
                // Preserve the exact original evidence and permit only its current-state GET.
                let latest = try await service.advancedState(sessionID: command.sessionID, token: session.token)
                try validate(latest, session: session, generation: generation)
                guard try ModInstallationNativeRuntimeProof(state: latest) == record.proof,
                      latest.version >= max(original.version, state?.version ?? original.version) else { throw PlayExperienceError.malformed }
                modActionReceipt = original; state = latest; cardReceipts.reconcile(latest, owner: session)
                throw PlayExperienceError.persistenceUnavailable
            }
            recoverySnapshot = try await recovery.transition(stored, to: .acknowledged, startedSessionID: nil)
            try checkDurableOwner(session, generation)
        }
        try await finishModReadback(session: session, generation: generation)
        guard let acknowledged = recoverySnapshot, acknowledged.value.phase == .acknowledged else { throw PlayExperienceError.persistenceUnavailable }
        try await recovery.clear(acknowledged)
        try checkDurableOwner(session, generation)
        recoverySnapshot = nil; pending = nil; pendingRequestedCard = false; startOutcomeUnknown = false
    }

    /// A matching receipt proves the original request committed: retire it like an acknowledged action.
    private func settleFromReceipt(_ receipt: PlayAdvancedState, pending: PlayAdvancedPending, session: PlayExperienceSession) {
        cardReceipts.accept(receipt, owner: session, pending: pending, requestedCard: pendingRequestedCard)
        self.pending = nil; pendingRequestedCard = false
    }
    /// unknown/prepared/other-process dispatching → dispatching (this process) → acknowledged → cleared.
    /// If a step fails, a record this process left dispatching goes back to unknown so it is not stuck "in flight".
    private func retireDurably(_ stored: PlayAdvancedRecoverySnapshot, recovery: any PlayAdvancedRecovery,
                               session: PlayExperienceSession, generation: UInt64) async throws {
        var snapshot = try await recovery.transition(stored, to: .dispatching, startedSessionID: nil)
        do {
            try checkDurableOwner(session, generation)
            snapshot = try await recovery.transition(snapshot, to: .acknowledged, startedSessionID: nil)
            try checkDurableOwner(session, generation)
            try await recovery.clear(snapshot)
            try checkDurableOwner(session, generation)
        } catch {
            if snapshot.value.phase == .dispatching,
               let unknown = try? await recovery.transition(snapshot, to: .unknown, startedSessionID: nil) { recoverySnapshot = unknown }
            else { recoverySnapshot = snapshot }
            throw error
        }
    }
    private func validate(_ state: PlayAdvancedState, session: PlayExperienceSession, generation: UInt64) throws {
        guard self.generation == generation, currentSession() == session, !Task.isCancelled else { throw PlayExperienceError.staleSession }
        guard state.activityID == activityID, state.topicID == topicID, state.nodeID == nodeID,
              self.state == nil || self.state?.sessionID == state.sessionID else { throw PlayExperienceError.malformed }
    }
    private func accept(_ state: PlayAdvancedState, session: PlayExperienceSession, generation: UInt64) throws {
        try validate(state, session: session, generation: generation)
        if modProofRequired || state.modInstallationRuntime != .null {
            guard state.version >= (self.state?.version ?? state.version) else { throw PlayExperienceError.malformed }
        }
        if self.state?.version != state.version { clearAdvancedLeaderboard() }
        self.state = state; issue = nil
        if state.modInstallationRuntime != .null { modProofRequired = true }
        if modProofRequired && (modJournal == nil || (try? ModInstallationNativeRuntimeProof(state: state)) == nil) { issue = .persistenceUnavailable }
        if let record = modRecord, record.settled, (try? ModInstallationNativeRuntimeProof(state: state)) == record.proof {
            modActionReceipt = try record.receipt.map(PlayAdvancedState.init)
        } else if modRecord?.settled != false { modActionReceipt = nil }
        cardReceipts.reconcile(state, owner: session)
        // An unresolved steps proof must not disable unrelated server-present kits.
        // Step submission itself is separately unsupported until its proof contract is approved.
        phase = "ready"
    }
    private func failure(_ error: Error, session: PlayExperienceSession, generation: UInt64, preservePending: Bool = false) {
        guard self.generation == generation else { return }
        guard currentSession() == session else { clearAdvancedLeaderboard(); self.state = nil; clearObjectCardReceipt(); phase = "stale"; return }
        issue = error as? PlayExperienceError ?? .unknownResult
        if modInstallationRecoveryRequired {
            clearAdvancedLeaderboard()
            if case PlayExperienceError.unauthorized = error { clearObjectCardReceipt(); phase = "stale" }
            else if case APIError.unauthorized = error { clearObjectCardReceipt(); phase = "stale" }
            else { phase = "unknown" }
            return
        }
        if preservePending, pending != nil {
            // A current-state read has no original action identity. Missing data,
            // an expired grant or a business error must not release that action.
            clearAdvancedLeaderboard()
            if case PlayExperienceError.unauthorized = error { clearObjectCardReceipt(); phase = "stale" }
            else if case APIError.unauthorized = error { clearObjectCardReceipt(); phase = "stale" }
            else {
                if case PlayExperienceError.rejected = error { clearObjectCardReceipt() }
                if case PlayExperienceError.disabled = error { clearObjectCardReceipt() }
                phase = "unknown"
            }
            return
        }
        if case PlayExperienceError.rejected = error { pending = nil; clearObjectCardReceipt(); phase = "rejected"; clearAdvancedLeaderboard() }
        else if case PlayExperienceError.disabled = error { clearAdvancedLeaderboard(); pending = nil; clearObjectCardReceipt(); phase = "disabled" }
        else if case PlayExperienceError.unauthorized = error { clearAdvancedLeaderboard(); clearObjectCardReceipt(); phase = "stale" }
        else if case APIError.unauthorized = error { clearAdvancedLeaderboard(); clearObjectCardReceipt(); phase = "stale" }
        else { phase = "unknown" }
    }
}
