import Foundation
import Observation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Opaque, one-shot durable dispatch. Only this coordinator file can construct or retire it.
@MainActor final class PlayPreparedDispatch {
    let request: URLRequest
    let baseURL: URL
    let capability: PlayExperienceCapability
    private enum Proof {
        case completion(any PlayCompletionRecoveryStore, PlayCompletionRecoverySnapshot)
        case paused(any PlayPausedStorage, PlayPausedStorageSnapshot)
    }
    private let proof: Proof
    private let key: String
    private let isCurrent: () -> Bool
    private var started = false
    private var retired = false
    fileprivate init(service: PlayExperienceService, scope: PlaySessionScope, session: PlayExperienceSession,
                     completion: PlayCompletionRecoverySnapshot, store: any PlayCompletionRecoveryStore, isCurrent: @escaping () -> Bool) throws {
        guard completion.value.state == .dispatching, completion.value.intent.owner.matches(session), completion.value.intent.gameplayMode != nil else { throw PlayExperienceError.persistenceUnavailable }
        let intent = completion.value.intent
        request = try service.completionRequest(scope: scope, nodeID: intent.nodeID, evidence: intent.evidence,
            advance: intent.advance, token: session.token, boundary: intent.id.uuidString, start: intent.startFields)
        baseURL = service.configuration.baseURL; capability = .classicCompletion; proof = .completion(store, completion)
        key = PlayRunStorageKey.make(session: session, scope: scope); self.isCurrent = isCurrent
    }
    fileprivate init(service: PlayExperienceService, scope: PlaySessionScope, session: PlayExperienceSession,
                     paused: PlayPausedStorageSnapshot, store: any PlayPausedStorage, isCurrent: @escaping () -> Bool) throws {
        guard let value = paused.value, value.owner.matches(session) else { throw PlayExperienceError.persistenceUnavailable }
        request = try service.pausedRequest(scope: scope, record: value.record, savedAt: value.record?.savedAt ?? value.tombstone, token: session.token)
        baseURL = service.configuration.baseURL; capability = .runPersistence; proof = .paused(store, paused)
        key = PlayRunStorageKey.make(session: session, scope: scope); self.isCurrent = isCurrent
    }
    fileprivate func retire() { retired = true }
    func consume(request: URLRequest, transport: any HTTPTransport) async throws {
        guard !started, !retired, request == self.request else { throw PlayExperienceError.persistenceUnavailable }
        started = true; try checkLifetime()
        switch proof {
        case .completion(let store, let expected):
            guard transport is PlayRecoveryRecordingTransport || (store as? PlayDurableRecovery)?.permitsSystemDispatch(to: baseURL) == true,
                  try await store.read(key) == expected else { throw PlayExperienceError.persistenceUnavailable }
        case .paused(let store, let expected):
            guard transport is PlayRecoveryRecordingTransport || (store as? PlayDurableRecovery)?.permitsSystemDispatch(to: baseURL) == true,
                  try await store.read(key: key) == expected else { throw PlayExperienceError.persistenceUnavailable }
        }
        try checkLifetime()
    }
    func checkLifetime() throws {
        guard started, !retired, isCurrent(), !retired else { throw PlayExperienceError.staleSession }
        try Task.checkCancellation()
    }
}

/// An ephemeral command belongs to the exact rendered read, not just a node ID.
/// It cannot be constructed by a view, persisted, or reused after a refresh.
public struct PlayInteractionContext: Equatable {
    fileprivate let owner: UUID
    fileprivate let session: PlayExperienceSession
    fileprivate let generation: UInt64
    fileprivate let mode: PlayGameplayMode
    var authoritativeMode: PlayGameplayMode { mode }
    var lifetimeIdentity: String { "\(owner.uuidString):\(generation):\(mode.rawValue)" }
}

/// Action id and route session id already stored on one completion journal or receipt.
/// A missing id is not filled from the live route snapshot and is not minted.
public struct HeldRouteActionIdentity: Equatable {
    public let actionID: String
    public let routeSessionID: Int64
}

public struct PlayCompletionReview: Equatable {
    public let nodeID: Int
    public let evidence: PlayCompletionEvidence
    public let advance: PlayRouteAdvance?
    let session: PlayExperienceSession
    let generation: UInt64
    let routeSessionID: Int?
    let gameplayMode: PlayGameplayMode?
    let id: UUID
    /// START-r11-1 (CG-ALL-11): `startMode` / `altStationId` for the run's first `/api/play/arrive`. Journaled with
    /// the intent, so a retry replays the same body. Nil for every other command (request shape unchanged).
    /// MP pages/play/utils/run-start-mode.js:33-37 (`arriveParams`), pages/play/index.js:6371.
    let startFields: [String: String]?
    init(nodeID: Int, evidence: PlayCompletionEvidence, advance: PlayRouteAdvance?, session: PlayExperienceSession, generation: UInt64, routeSessionID: Int?, id: UUID = UUID(), gameplayMode: PlayGameplayMode? = nil, startFields: [String: String]? = nil) {
        self.nodeID = nodeID; self.evidence = evidence; self.advance = advance; self.session = session
        self.generation = generation; self.routeSessionID = routeSessionID; self.id = id; self.gameplayMode = gameplayMode
        self.startFields = startFields
    }
    /// UG-09: the same review carrying the server's action context. A branch review keeps the action
    /// id and expected version it was reviewed with; a linear review gets one new action id here,
    /// before anything is journaled. `routeSessionID` stays the snapshot value used by readback.
    func bound(to context: PlayBasicActionContext) throws -> PlayCompletionReview {
        let advance = try PlayRouteAdvance(actionID: self.advance?.actionID ?? UUID().uuidString,
            expectedVersion: self.advance?.expectedVersion ?? context.expectedRouteVersion,
            routeSessionID: context.routeSessionID, runtimeInstance: context.runtimeInstance, authorityEpoch: context.authorityEpoch)
        return .init(nodeID: nodeID, evidence: evidence, advance: advance, session: session, generation: generation,
                     routeSessionID: routeSessionID, id: id, gameplayMode: gameplayMode, startFields: startFields)
    }
}
/// Independent of the existing linear-answer reader. A successful write invalidates the
/// snapshot; only authoritative readback changes progress. No hidden write retries.
@available(macOS 14.0, *)
@MainActor @Observable public final class PlayExperienceCoordinator {
    public let scope: PlaySessionScope
    private var storedSnapshot: PlaySnapshot?
    /// Every display read rechecks the caller's live session/approval lease.
    public private(set) var snapshot: PlaySnapshot? {
        get { loadedSession != nil && loadedSession == currentSession() ? storedSnapshot : nil }
        set { storedSnapshot = newValue; publishLiveActivity() }
    }
    /// Lock Screen / Dynamic Island mirror of this session. Display only; it never drives progress or the run clock.
    @ObservationIgnored public weak var liveActivity: (any QuestLiveActivityPublishing)?
    private func publishLiveActivity() {
        guard let liveActivity else { return }
        liveActivity.publish(QuestLiveActivityMapping.play(key: "play:\(scope)", snapshot: snapshot, clockPhase: clock.phase,
            elapsedSeconds: clock.elapsed(monotonicNow: ProcessInfo.processInfo.systemUptime), now: Date(),
            score: leaderboard?.me.score, rank: leaderboard?.me.rank))
    }
    public private(set) var extras: [Int: PlayNodeExtras] = [:]
    public private(set) var chapterStories: [Int: ChapterStoryDocument] = [:]
    public private(set) var storyVariables: [String: PlayWireValue] = [:]
    public private(set) var storyVoices: [String: PlayWireValue] = [:]
    public private(set) var storyThoughts: [PlayWireValue] = []
    /// U04-03 verdict for the current read; nil when the server sent none.
    public private(set) var compatibility: PlayContentCompatibility?
    /// Content identity of the current read; reading positions are kept per identity.
    public private(set) var contentVersion: String?
    public private(set) var thoughtSyncPhase: ChapterThoughtSyncPhase = .idle
    public private(set) var pendingThoughtKeys: Set<String> = []
    private var thoughtClaimSessionID: Int?
    private var thoughtSyncInFlight = false
    private var thoughtSyncNonce = UUID()
    public private(set) var phase: Phase = .idle
    public private(set) var issue: PlayExperienceError?
    public private(set) var reward: PlayWireValue?
    /// mp-journey r3: MP `_applyAiScore` — the AI 参考分 a photo receipt carried, kept per node for the stop card.
    public private(set) var aiScores: [Int: PlayAIScoreCard] = [:]
    public private(set) var hint: PlayHintReceipt?
    public private(set) var ending: PlayEndingDocument?
    public private(set) var leaderboard: PlayCompanionLeaderboard?
    /// fix-1128b #16 (J-05a/J-09f): the finish ranking read failed. Soft, like the MP board `error`: the finish
    /// screen keeps its record and shows a retry row; the page phase is not failed.
    public private(set) var leaderboardUnavailable = false
    public private(set) var lead: PlayLeadProgress?
    public private(set) var clock = PlayRunClock()
    public private(set) var remoteRunSaveFailed = false
    public private(set) var unresolved = false
    /// U05-03: recovery state of this run's last basic submission (checking the original receipt,
    /// still pending, confirmed, definitely failed, or a run conflict). Nil when there is none.
    public private(set) var submitRecovery: PlaySubmitRecoveryState?
    /// U05-01/02: the last definite arrival refusal for this run, with server-approved replacements.
    public private(set) var arrivalFailure: PlayArrivalFailure?
    /// Read-only free-exploration chapters. Set for an offline or expired read; a live route keeps using `snapshot`.
    public private(set) var storyArchive: FreeExplorationStoryArchive?
    public private(set) var storyArchiveSource: FreeExplorationArchiveSource?
    private let storyArchiveStore: (any FreeExplorationStoryArchiveStore)?
    /// §23.2: the arrival reading from a real success receipt only; never from a refusal or a read.
    public var arrivalReading: PlayArrivalReading? { reward.flatMap(PlayArrivalReading.init(receipt:)) }
    /// U05-02: route-level notice (configuration withdrawn, ended, switched to the fallback route).
    public var routeNotice: PlayRouteNotice? { PlayRouteNotice(route: snapshot?.route) }
    /// Cast fields from the latest accepted nodes read. Cleared with the snapshot.
    public private(set) var castPayload: PlayWireValue = .null
    public private(set) var leaderOutcomeUnknown = false
    /// The latest applied team-progress read failed; the last applied lead stays as read.
    public private(set) var leadReadFailed = false
    private var leadReadIssued: UInt64 = 0
    private var leadReadApplied: UInt64 = 0
    public enum Phase: String { case idle, loading, ready, reviewing, submitting, needsReadback, unknown, failed }
    private let service: PlayExperienceService
    private let currentSession: () -> PlayExperienceSession?
    private let recovery: any PlayCompletionRecoveryStore
    private let pausedStorage: any PlayPausedStorage
    private let onUnauthorized: (PlayExperienceSession) -> Void
    private var cachedCompletion: PlayCompletionRecoverySnapshot?
    private var retryReadbackVerified = false
    private var pausedLease: PlayPausedStorageSnapshot?
    private var pausedOwner: PlayExperienceSession?
    private var completionAttempt: PlayPreparedDispatch?
    private var runAttempt: PlayPreparedDispatch?
    private var completionTask: Task<PlayWireValue, Error>?
    private var completionTaskID = UUID()
    private var runTask: Task<Void, Error>?
    private var runTaskID = UUID()
    private var runStorageBusy = false
    public private(set) var localRecoveryFailed = false
    private var loadedSession: PlayExperienceSession?
    private var authorityOwner: PlayExperienceSession?
    private var authorityMode: PlayGameplayMode?
    private var unknownLeaderKeys: Set<String> = []
    /// WP-02: the open chapter release per owner and session (`lead-chapter` intent). Kept until its outcome is known.
    private var unlockCommands: [String: PlayLeadUnlockCommand] = [:]
    public enum LeadNotice: Equatable { case server(String?), unlockApplied, unlockPending, unlockNotExecuted, noNextChapter, released, releaseNotSent }
    public private(set) var leadNotice: LeadNotice?
    public private(set) var leadToolBusy = false
    @ObservationIgnored private var issuedInteractionLifetime: PlayInteractionLifetime?
    private let interactionOwner = UUID()
    private var generation: UInt64 = 0
    private var advancedReadyNodeIDs: Set<Int> = []
    private var hintUnknownNodes: Set<Int> = []
    private var unknownHintRequests: [String: [Int: Int]] = [:]
    public var identity: String? {
        currentSession().map { PlayRunStorageKey.make(session: $0, scope: scope) + ":" + String($0.epoch) }
    }
    public var hasModeRecoveryBlock: Bool {
        guard let mode = gameplayMode, let pending = cachedCompletion?.value else { return false }
        return pending.intent.gameplayMode != mode
    }
    /// Both ids from the current completion journal, or both from the current receipt.
    /// Does not mint an action id or a session id, and does not pair an older journal with a newer receipt.
    public var heldRouteActionIdentity: HeldRouteActionIdentity? {
        journalRouteActionIdentity ?? receiptRouteActionIdentity
    }
    private var journalRouteActionIdentity: HeldRouteActionIdentity? {
        guard let pending = cachedCompletion?.value,
              let routeSessionID = pending.intent.routeSessionID, routeSessionID > 0,
              let stored = pending.intent.advance?.actionID else { return nil }
        let actionID = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !actionID.isEmpty, actionID.count <= 96 else { return nil }
        return HeldRouteActionIdentity(actionID: actionID, routeSessionID: Int64(routeSessionID))
    }
    private var receiptRouteActionIdentity: HeldRouteActionIdentity? {
        guard let reward else { return nil }
        let stored = reward["routeActionId"].text ?? reward["actionId"].text
        let actionID = stored?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let session = reward["routeState"]["sessionId"].integer
            ?? reward["themeRuntime"]["sessionId"].integer
            ?? reward["sessionId"].integer
        guard !actionID.isEmpty, actionID.count <= 96, let session, session > 0 else { return nil }
        return HeldRouteActionIdentity(actionID: actionID, routeSessionID: Int64(session))
    }
    public var available: Bool { service.enabled.contains(.reads) }
    public var gameplayMode: PlayGameplayMode? { PlayGameplayMode(serverValue: snapshot?.result.mode) }
    public var interactionContext: PlayInteractionContext? {
        guard phase == .ready, let session = loadedSession, session == currentSession(),
              let mode = gameplayMode else { return nil }
        return .init(owner: interactionOwner, session: session, generation: generation, mode: mode)
    }
    public func makeInteractionLifetime() -> PlayInteractionLifetime? {
        guard let context = interactionContext else { return nil }
        if let issuedInteractionLifetime, issuedInteractionLifetime.identity == context.lifetimeIdentity { return issuedInteractionLifetime }
        let request = generation
        let lifetime = PlayInteractionLifetime(context: context,
            current: { [weak self] in self?.interactionContext },
            onRetired: { [weak self] in self?.retireChildRead(generation: request) })
        issuedInteractionLifetime = lifetime
        return lifetime
    }
    /// U05-04: download model bound to this run's current reader. Nil without a current read.
    public func makeOfflinePackModel(store: PlayContentPrefetchStore, fetch: @escaping @Sendable (URL) async throws -> Data) -> PlayOfflinePackModel? {
        guard service.enabled.contains(.reads), let session = loadedSession, session == currentSession() else { return nil }
        let currentSession = self.currentSession
        return PlayOfflinePackModel(scope: scope, service: service, session: session, isCurrent: { currentSession() == session }, store: store, fetch: fetch)
    }
    /// Uploads an `audio_clip` sensor recording using the active read-bound session.
    public func uploadAudio(_ bytes: Data, mimeType: String) async throws -> String {
        guard let session = loadedSession, session == currentSession() else { throw PlayExperienceError.unauthorized }
        return try await service.uploadAudio(bytes, mimeType: mimeType, token: session.token)
    }
    private func retireChildRead(generation request: UInt64) {
        guard generation == request else { return }
        generation &+= 1; loadedSession = nil; snapshot = nil; castPayload = .null; extras = [:]
        reward = nil; aiScores = [:]; hint = nil; ending = nil; leaderboard = nil; lead = nil; leadReadFailed = false; advancedReadyNodeIDs = []
        // Keep durable completion/pause records and pending thought keys intact.
        // Nothing about a changed mode proves an earlier mutation's outcome.
        thoughtSyncNonce = UUID(); thoughtSyncInFlight = false
        runAttempt?.retire(); runAttempt = nil; runTask?.cancel(); runTask = nil; runTaskID = UUID()
        pausedLease = nil; pausedOwner = nil; clock.restore(nil)
        issue = .staleSession; phase = .needsReadback
    }
    private func accepts(_ context: PlayInteractionContext?) -> Bool {
        guard let context, let current = interactionContext else { return false }
        return context == current
    }
    /// Read authority only; audio never grants gameplay completion authority.
    public var hasCurrentMediaSnapshot: Bool {
        snapshot != nil && loadedSession != nil && loadedSession == currentSession() && (phase == .ready || phase == .unknown)
    }
    /// A read-only projection must not enable completion, hint or leader controls.
    public var canWrite: Bool { !service.enabled.isDisjoint(with: [.classicCompletion, .hints, .leader, .thoughtClaims]) && phase == .ready && !unresolved && !thoughtSyncInFlight && pendingThoughtKeys.isEmpty && loadedSession != nil && loadedSession == currentSession() }
    /// Arrival uses the existing classic-completion channel. The grant stays off until a composition turns it on.
    public var canSubmitArrival: Bool { service.enabled.contains(.classicCompletion) && canWrite }
    /// Run state and durable pause records require their own reviewed capability.
    public var canManageRun: Bool { gameplayMode == .cityOrientation && service.enabled.contains(.runPersistence) && hasCurrentMediaSnapshot && !localRecoveryFailed && pausedLease?.value?.pendingRemote != true }
    public init(scope: PlaySessionScope, service: PlayExperienceService, recovery: any PlayCompletionRecoveryStore,
                pausedStorage: any PlayPausedStorage, currentSession: @escaping () -> PlayExperienceSession?,
                onUnauthorized: @escaping (PlayExperienceSession) -> Void = { _ in },
                storyArchiveStore: (any FreeExplorationStoryArchiveStore)? = nil) {
        self.scope = scope; self.service = service; self.recovery = recovery; self.pausedStorage = pausedStorage
        self.currentSession = currentSession; self.onUnauthorized = onUnauthorized
        self.storyArchiveStore = storyArchiveStore ?? (recovery as? any FreeExplorationStoryArchiveStore)
    }
    public func load() async {
        guard phase != .submitting else { return }
        generation &+= 1; let request = generation
        phase = .loading; issue = nil; snapshot = nil; castPayload = .null; extras = [:]; cachedCompletion = nil; retryReadbackVerified = false
        storyArchive = nil; storyArchiveSource = nil
        guard let session = currentSession(), scope.isValid else { phase = .failed; issue = .staleSession; return }
        if authorityOwner != session {
            reward = nil; aiScores = [:]; hint = nil; ending = nil; leaderboard = nil; lead = nil; leadReadFailed = false; leadNotice = nil
            advancedReadyNodeIDs = []; submitRecovery = nil; arrivalFailure = nil
            hintUnknownNodes = Set((unknownHintRequests[PlayRunStorageKey.make(session: session, scope: scope)] ?? [:]).keys)
            leaderOutcomeUnknown = unknownLeaderKeys.contains(PlayRunStorageKey.make(session: session, scope: scope))
            authorityOwner = session
            chapterStories = [:]; storyVariables = [:]; storyVoices = [:]; storyThoughts = []
            compatibility = nil; contentVersion = nil
            pendingThoughtKeys = []; thoughtClaimSessionID = nil; thoughtSyncInFlight = false; thoughtSyncPhase = .idle; thoughtSyncNonce = UUID()
        }
        loadedSession = nil
        do {
            let key = PlayRunStorageKey.make(session: session, scope: scope)
            var pending = try await recovery.read(key)
            try check(session, request)
            if let pending { guard pending.value.intent.owner.matches(session) else { throw PlayExperienceError.persistenceUnavailable } }
            // U05-03: after a restart (or a later visit) an unsettled journal is settled only by its
            // original receipt, read with the journaled action id. Never resubmitted from here.
            var settledArrival: (nodeID: Int, refusal: PlayCommandRefusal, actionID: String?)?
            if service.enabled.contains(.actionContextBinding), let captured = pending,
               captured.value.state == .unknown || (captured.value.state == .dispatching && captured.value.dispatchProcess != recovery.processID),
               let stored = captured.value.intent.advance?.actionID,
               let actionID = PlayActionReceiptIdentity.retained(original: stored, proposed: stored) {
                let nodeID = captured.value.intent.nodeID
                submitRecovery = .checking(nodeID: nodeID)
                let outcome = try? await service.originalActionReceipt(scope: scope, nodeID: nodeID, routeActionID: actionID, token: session.token)
                try check(session, request)
                switch outcome {
                case .confirmed(let value)? where Self.receipt(value, names: nodeID):
                    try await recovery.clear(captured, key: key)
                    try check(session, request); pending = nil
                    reward = value; noteAIScore(value); submitRecovery = .confirmed(nodeID: nodeID)
                case .failed(let refusal)?:
                    try await recovery.clear(captured, key: key)
                    try check(session, request); pending = nil
                    submitRecovery = .failed(nodeID: nodeID, refusal: refusal)
                    if case .location = captured.value.intent.evidence { settledArrival = (nodeID, refusal, actionID) }
                default:
                    // No settled receipt (or no answer): still waiting, which is not a failure.
                    submitRecovery = .pending(nodeID: nodeID)
                }
            }
            let document = try await service.nodes(scope: scope, token: session.token)
            try check(session, request)
            let route = document.base.routeState?.isBranch == true ? try await service.route(scope: scope, token: session.token) : nil
            try check(session, request)
            let snapshot = try PlaySnapshot(scope: scope, result: document.base, authority: route)
            if let captured = pending, landed(captured.value.intent, snapshot: snapshot) {
                try await recovery.clear(captured, key: key)
                try check(session, request); pending = nil
                // Authoritative readback settled it; the receipt state no longer applies.
                if submitRecovery?.nodeID == captured.value.intent.nodeID { submitRecovery = nil }
            }
            if let settledArrival {
                arrivalFailure = PlayArrivalFailure(nodeID: settledArrival.nodeID, refusal: settledArrival.refusal, snapshot: snapshot, arrivalRequestID: settledArrival.actionID)
            }
            cachedCompletion = pending; retryReadbackVerified = true
            var hintRequests = unknownHintRequests[key] ?? [:]
            for (nodeID, level) in hintRequests {
                guard let detail = document.extras[nodeID] else { continue }
                if level == -1, detail.hintLocked == false, detail.hint1?.isEmpty == false || detail.hint2?.isEmpty == false { hintRequests.removeValue(forKey: nodeID) }
                else if level >= 1, (detail.puzzleHintLevel ?? 0) >= level, !detail.usedHints.isEmpty { hintRequests.removeValue(forKey: nodeID) }
            }
            unknownHintRequests[key] = hintRequests; hintUnknownNodes = Set(hintRequests.keys)
            unresolved = pending != nil || !hintUnknownNodes.isEmpty || leaderOutcomeUnknown
            let mode = PlayGameplayMode(serverValue: snapshot.result.mode)
            if authorityMode != mode {
                reward = nil; aiScores = [:]; hint = nil; ending = nil; leaderboard = nil; lead = nil; leadReadFailed = false
                advancedReadyNodeIDs = []
            }
            authorityMode = mode
            self.snapshot = snapshot; extras = document.extras; castPayload = document.castPayload; loadedSession = session
            if mode != .cityOrientation {
                // Discard only in-memory orientation state. Free exploration does
                // not read, clear or rewrite its durable pause records.
                runAttempt?.retire(); runAttempt = nil; runTask?.cancel(); runTask = nil; runTaskID = UUID()
                pausedLease = nil; pausedOwner = nil; clock.restore(nil)
                remoteRunSaveFailed = false; localRecoveryFailed = false
            }
            chapterStories = document.chapterStories
            compatibility = document.compatibility; contentVersion = document.contentVersion
            storyVariables.merge(document.storyVariables) { _, new in new }
            storyVoices.merge(document.storyVoices) { _, new in new }
            storyThoughts = snapshot.route?.thoughts ?? document.storyThoughts
            if let previous = thoughtClaimSessionID, let current = snapshot.route?.sessionID, previous != current {
                pendingThoughtKeys = []; thoughtClaimSessionID = nil; thoughtSyncPhase = .idle
            }
            if !pendingThoughtKeys.isEmpty {
                pendingThoughtKeys.subtract(storyThoughts.compactMap { $0["key"].text })
                thoughtSyncPhase = pendingThoughtKeys.isEmpty ? .synced : .needsReadback
                unresolved = unresolved || !pendingThoughtKeys.isEmpty
            }
            phase = unresolved ? .unknown : .ready
            await refreshStoryArchive(snapshot: snapshot, session: session, generation: request)
        } catch {
            let offline = (error as? URLError).map(PlayExperienceService.isOffline) == true
            let expired: Bool
            if case PlayExperienceError.rejected(402, _) = error { expired = true } else { expired = false }
            fail(error, session: session, generation: request)
            guard generation == request, currentSession() == session else { return }
            if expired {
                let topicID: Int? = { if case .topic(let id) = scope { return id }; return nil }()
                await loadExpiredStory(session: session, topicID: topicID, topicName: nil, generation: request)
            } else if offline {
                await showCachedStory(session: session, generation: request)
            }
        }
    }
    public func claimVisibleThoughts(chapterID: Int) async {
        guard service.enabled.contains(.thoughtClaims) else { thoughtSyncPhase = .disabled; return }
        guard canWrite, hasCurrentMediaSnapshot, let snapshot, snapshot.availability == .active,
              let chapter = chapterStories[chapterID], let topicID = snapshot.result.topicID,
              let routeSessionID = snapshot.route?.sessionID, let version = snapshot.route?.version,
              let session = loadedSession, session == currentSession(), !thoughtSyncInFlight, pendingThoughtKeys.isEmpty else { return }
        let claims = ChapterStoryProjection.claimableThoughtKeys(chapter: chapter, snapshot: snapshot, thoughts: storyThoughts)
        guard !claims.isEmpty else { return }
        let nonce = UUID(); thoughtSyncNonce = nonce; thoughtSyncInFlight = true
        let request = generation
        pendingThoughtKeys = Set(claims); thoughtClaimSessionID = routeSessionID; thoughtSyncPhase = .syncing
        defer { if thoughtSyncNonce == nonce { thoughtSyncInFlight = false } }
        do {
            _ = try await service.syncChapterThoughts(scope: scope, topicID: topicID, claims: claims,
                sessionID: routeSessionID, previousVersion: version, token: session.token)
            try check(session, request)
            thoughtSyncPhase = .needsReadback
            await load() // Only a fresh nodes + route read projects names and completion facts.
        } catch {
            guard thoughtSyncNonce == nonce, currentSession() == session else { return }
            if error as? PlayExperienceError == .unauthorized { onUnauthorized(session); invalidate(); return }
            // No implicit retry after a possibly committed claim. Reopening must read first.
            thoughtSyncPhase = pendingThoughtKeys.isEmpty ? .synced : .needsReadback
            unresolved = unresolved || !pendingThoughtKeys.isEmpty
        }
    }
    /// Called only from an accepted advanced state, never a local timer or preview.
    public func acceptAdvanced(_ state: PlayAdvancedState, context: PlayInteractionContext? = nil) throws {
        guard accepts(context), loadedSession == currentSession(), let snapshot,
              state.nodeID > 0, snapshot.visibleNodes.contains(where: { $0.id == state.nodeID }),
              state.topicID == snapshot.result.topicID, state.readyForBase else { throw PlayExperienceError.invalidAction }
        switch scope {
        case .activity(let id): guard state.activityID == id else { throw PlayExperienceError.invalidAction }
        case .topic: guard state.activityID == 0 else { throw PlayExperienceError.invalidAction }
        }
        advancedReadyNodeIDs.insert(state.nodeID)
    }
    /// UI/provider callbacks must present the authority captured when offered.
    public func review(nodeID: Int, evidence: PlayCompletionEvidence, context: PlayInteractionContext?, start: PlayRunStartRequest? = nil) throws -> PlayCompletionReview {
        guard accepts(context) else { throw PlayExperienceError.staleSession }
        return try review(nodeID: nodeID, evidence: evidence, start: start)
    }
    /// START-r11-1: 换个方式开局 is offered only in city orientation, before the run has started and while the server
    /// has not recorded a start mode (MP pages/play/utils/run-start-mode.js:51-54 `_startModesAvailable`).
    public func runStartModesAvailable(nodeID: Int) -> Bool {
        guard gameplayMode == .cityOrientation, let snapshot, snapshot.availability == .active,
              snapshot.result.mode == 1, snapshot.result.runStartMode == nil else { return false }
        if let done = snapshot.displayedDoneCount, done > 0 { return false }
        if snapshot.visibleNodes.contains(where: { snapshot.isDone($0) || $0.arrived == true }) { return false }
        return snapshot.visibleNodes.contains { $0.id == nodeID }
    }
    public func review(nodeID: Int, evidence: PlayCompletionEvidence, start: PlayRunStartRequest? = nil) throws -> PlayCompletionReview {
        var startFields: [String: String]?
        if let start {
            switch evidence {
            case .location, .stationArrival: break
            default: throw PlayExperienceError.invalidAction
            }
            guard runStartModesAvailable(nodeID: nodeID) else { throw PlayExperienceError.invalidAction }
            startFields = start.fields
        }
        guard service.enabled.contains(.classicCompletion), canWrite, let session = loadedSession, let snapshot,
              snapshot.availability == .active,
              let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }),
              !snapshot.isDone(node), !snapshot.isLocked(node), node.done == false else { throw PlayExperienceError.invalidAction }
        let task: PlayNodeTask
        if gameplayMode == .freeExploration {
            guard let merchantTask = FreeExplorationPresentation.evidenceTask(for: node, in: snapshot) else { throw PlayExperienceError.unsupported }
            task = merchantTask
        } else {
            guard gameplayMode == .cityOrientation else { throw PlayExperienceError.unsupported }
            guard !node.hasAdvancedPrerequisite || advancedReadyNodeIDs.contains(nodeID) else { throw PlayExperienceError.invalidAction }
            task = PlayNodeTask.resolve(mode: snapshot.result.mode, node: node)
        }
        switch (task, evidence) {
        case (.answer, .answer(let text)):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  node.validationMethod != 3 || node.options?[text] != nil else { throw PlayExperienceError.invalidAction }
            guard (node.needScan != true && node.needGPS != true) || node.arrived == true else { throw PlayExperienceError.invalidAction }
        case (.scan, .scan), (.merchantScan, .scan), (.photo, .photo), (.merchantPhoto, .photo), (.arrive, .location): break
        case (.arrive, .stationArrival): break
        case (.answer, .stationArrival):
            guard node.needGPS == true, node.needScan != true, node.arrived != true else { throw PlayExperienceError.invalidAction }
        case (.answer, .location(let longitude, let latitude, let system, _, _)):
            guard node.needGPS == true, node.needScan != true, node.arrived != true,
                  system == "GCJ02", longitude.isFinite, latitude.isFinite else { throw PlayExperienceError.invalidAction }
        case (.merchantScan, .location(let longitude, let latitude, let system, _, _)):
            guard node.visitCheck != .scan, node.visitCheck != .online,
                  system == "GCJ02", longitude.isFinite, latitude.isFinite else { throw PlayExperienceError.unsupported }
        case (.sensor, .sensor(let type, let payload)):
            guard type == node.sensorType else { throw PlayExperienceError.invalidAction }
            switch type {
            case "still":
                guard let config = try? PlayStillnessConfiguration(raw: extras[nodeID]?.sensorConfig ?? .null),
                      payload.keys.sorted() == ["heldSec"], payload["heldSec"]?.integer == config.durationSeconds else { throw PlayExperienceError.invalidAction }
            case "audio_clip":
                guard let config = try? PlayAudioClipConfiguration(raw: extras[nodeID]?.sensorConfig ?? .null),
                      payload.keys.sorted() == ["durationSec", "mediaUrl"],
                      let duration = payload["durationSec"]?.integer,
                      (config.minDurationSeconds...60).contains(duration),
                      let url = payload["mediaUrl"]?.text, PlayExperienceService.validHTTPS(url) else { throw PlayExperienceError.invalidAction }
            default:
                throw PlayExperienceError.invalidAction
            }
        default: throw PlayExperienceError.unsupported
        }
        let advance: PlayRouteAdvance?
        if snapshot.route?.isBranch == true {
            guard let version = snapshot.route?.version else { throw PlayExperienceError.invalidAction }
            advance = try PlayRouteAdvance(actionID: UUID().uuidString, expectedVersion: version)
        } else { advance = nil }
        phase = .reviewing
        return PlayCompletionReview(nodeID: nodeID, evidence: evidence, advance: advance, session: session, generation: generation, routeSessionID: snapshot.route?.sessionID, gameplayMode: gameplayMode, startFields: startFields)
    }
    /// F-05: the reason `review` refuses (or would refuse) this stop, for the screen to show. Nil when the
    /// stop can be reviewed. Read-only: it never changes the phase and never sends anything. Without
    /// evidence only stop-level facts are checked (done, locked, run state, advanced prerequisite).
    public func reviewRefusal(nodeID: Int, evidence: PlayCompletionEvidence? = nil) -> PlayReviewRefusal? {
        guard service.enabled.contains(.classicCompletion) else { return .disabled }
        guard let snapshot, loadedSession != nil else { return unresolved ? .unresolved : .sessionUnavailable }
        if let refusal = PlayReviewRefusal.station(nodeID: nodeID, in: snapshot, mode: gameplayMode,
                                                  advancedReady: advancedReadyNodeIDs.contains(nodeID)) { return refusal }
        if unresolved { return .unresolved }
        guard canWrite else { return .busy }
        if case .answer(let text)? = evidence { return PlayReviewRefusal.answer(text, nodeID: nodeID, in: snapshot) }
        return nil
    }
    public func cancelReview() { if phase == .reviewing { phase = .ready } }
    public func submit(_ review: PlayCompletionReview) async {
        guard service.enabled.contains(.classicCompletion), review.gameplayMode == gameplayMode, gameplayMode != nil, phase == .reviewing, review.session == currentSession(), review.session == loadedSession,
              review.generation == generation, !unresolved else { return }
        do { try review.evidence.validateNewLocationMeasurement() }
        catch { issue = .invalidAction; return }
        arrivalFailure = nil; submitRecovery = nil
        guard service.enabled.contains(.actionContextBinding) else { await dispatch(review); return }
        // UG-09: read the run identity first. Nothing is journaled or sent until it is known.
        let session = review.session, request = generation
        phase = .submitting
        let bound: PlayCompletionReview
        do {
            let context = try await service.actionContext(scope: scope, nodeID: review.nodeID, token: session.token)
            try check(session, request)
            if review.advance != nil, let held = review.routeSessionID, held != context.routeSessionID {
                // The branch run changed after review. Refresh; never write into another run.
                submitRecovery = .conflict(nodeID: review.nodeID); phase = .needsReadback; await load(); return
            }
            bound = try review.bound(to: context)
        } catch {
            guard generation == request else { return }
            guard currentSession() == session else { invalidate(); return }
            if (error as? PlayExperienceError) == .unauthorized { fail(error, session: session, generation: request); return }
            // A failed identity read changes nothing on the server; the player can try again.
            issue = error as? PlayExperienceError ?? .unknownResult; phase = .ready; return
        }
        await dispatch(bound)
    }
    private func noteAIScore(_ receipt: PlayWireValue) {
        guard let card = PlayAIScoreCard(receipt: receipt) else { return }
        aiScores[card.nodeID] = card
    }
    static func receipt(_ value: PlayWireValue, names nodeID: Int) -> Bool {
        value["nodeId"].tolerantInteger == nodeID || value["data"]["nodeId"].tolerantInteger == nodeID
    }
    /// The original action settled as not applied (terminal receipt, or proof nothing ran):
    /// retire its journal and show why. Returns false when the journal could not be retired.
    private func settleFailed(_ ticket: PlayCompletionRecoverySnapshot, refusal: PlayCommandRefusal, review: PlayCompletionReview,
                              session: PlayExperienceSession, request: UInt64, key: String) async -> Bool {
        do {
            try await recovery.clear(ticket, key: key)
            try check(session, request)
        } catch {
            guard currentSession() == session, generation == request else { return true }
            localRecoveryFailed = true; issue = .persistenceUnavailable; phase = .unknown; return false
        }
        cachedCompletion = nil
        unresolved = !hintUnknownNodes.isEmpty || leaderOutcomeUnknown || !pendingThoughtKeys.isEmpty
        issue = .rejected(refusal.code, refusal.message)
        submitRecovery = .failed(nodeID: review.nodeID, refusal: refusal)
        var arrival = refusal.arrivalReason != nil
        if case .location = review.evidence { arrival = true }
        if case .stationArrival = review.evidence { arrival = true }
        if arrival { arrivalFailure = PlayArrivalFailure(nodeID: review.nodeID, refusal: refusal, snapshot: snapshot, arrivalRequestID: review.advance?.actionID) }
        if refusal.refreshRequired || refusal.code == 409 {
            submitRecovery = .conflict(nodeID: review.nodeID); phase = .needsReadback; await load()
        } else { phase = unresolved ? .unknown : .ready }
        return true
    }
    private func dispatch(_ review: PlayCompletionReview, recovering: PlayCompletionRecoverySnapshot? = nil) async {
        let session = review.session, request = generation, key = PlayRunStorageKey.make(session: review.session, scope: scope)
        // Fence synchronously before any storage suspension. Other viewers are fenced by CAS.
        unresolved = true; phase = .submitting; reward = nil; retryReadbackVerified = false
        var ticket: PlayCompletionRecoverySnapshot?
        var sent = false
        do {
            let prepared: PlayCompletionRecoverySnapshot
            if let recovering { prepared = recovering }
            else { prepared = try await recovery.prepare(.init(review: review), key: key) }
            ticket = prepared; try check(session, request)
            let dispatched = try await recovery.transition(prepared, to: .dispatching, key: key)
            ticket = dispatched; cachedCompletion = dispatched; try check(session, request)
            sent = true
            let attempt = try PlayPreparedDispatch(service: service, scope: scope, session: session, completion: dispatched, store: recovery,
                isCurrent: { [weak self] in guard let self else { return false }; return self.generation == request && self.currentSession() == session })
            completionAttempt = attempt
            let taskID = UUID(); completionTaskID = taskID
            let service = self.service
            let task = Task { try await service.dispatch(attempt) }
            completionTask = task
            defer { attempt.retire(); if completionTaskID == taskID { completionTask = nil; completionAttempt = nil } }
            let receipt = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            try check(session, request)
            guard receipt["nodeId"].tolerantInteger == review.nodeID else { throw PlayExperienceError.malformed }
            let acknowledged = try await recovery.transition(dispatched, to: .acknowledged, key: key)
            ticket = acknowledged; try check(session, request); cachedCompletion = acknowledged
            reward = receipt; noteAIScore(receipt); submitRecovery = nil; arrivalFailure = nil; phase = .needsReadback; await load()
        } catch {
            guard generation == request else { return }
            guard currentSession() == session else { invalidate(); return }
            // A storage error is never converted into an empty bucket or a safe-to-send state.
            if error as? PlayExperienceError == .persistenceUnavailable {
                localRecoveryFailed = true; issue = .persistenceUnavailable; phase = .unknown; return
            }
            if let ticket, sent, let refusal = error as? PlayCommandRefusal, refusal.settlesAsFailed {
                _ = await settleFailed(ticket, refusal: refusal, review: review, session: session, request: request, key: key)
                return
            }
            if let refusal = error as? PlayCommandRefusal, refusal.errorCode == PlayCommandRefusal.actionReused {
                // The action id answers for another input; its outcome stays unknown. Refresh first.
                submitRecovery = .conflict(nodeID: review.nodeID)
            }
            let mayHaveApplied: Bool = {
                if case PlayExperienceError.unknownResult = error { return true }
                return (error as? PlayCommandRefusal)?.isPending == true
            }()
            if let ticket, sent {
                if mayHaveApplied,
                   let actionID = ticket.value.intent.advance?.actionID,
                   let retained = PlayActionReceiptIdentity.retained(original: actionID, proposed: actionID) {
                    let outcome = try? await service.originalActionReceipt(
                        scope: scope, nodeID: review.nodeID, routeActionID: retained, token: session.token)
                    if case .failed(let refusal)? = outcome {
                        _ = await settleFailed(ticket, refusal: refusal, review: review, session: session, request: request, key: key)
                        return
                    }
                    if service.enabled.contains(.actionContextBinding) { submitRecovery = .pending(nodeID: review.nodeID) }
                    if let outcome, case .confirmed(let value) = outcome, Self.receipt(value, names: review.nodeID) {
                        do {
                            let acknowledged = try await recovery.transition(ticket, to: .acknowledged, key: key)
                            try check(session, request)
                            cachedCompletion = acknowledged
                            reward = value
                            noteAIScore(value)
                            submitRecovery = service.enabled.contains(.actionContextBinding) ? .confirmed(nodeID: review.nodeID) : nil
                            phase = .needsReadback
                            await load()
                            return
                        } catch {
                            guard currentSession() == session, generation == request else { return }
                        }
                    }
                }
                do {
                    switch error {
                    case PlayExperienceError.disabled:
                        if recovering == nil || recovering?.value.state == .prepared {
                            try await recovery.clear(ticket, key: key)
                            try check(session, request); cachedCompletion = nil; unresolved = false
                        } else {
                            // Disabled retry cannot establish the outcome of the original write.
                            let unknown = try await recovery.transition(ticket, to: .unknown, key: key)
                            try check(session, request); cachedCompletion = unknown
                        }
                    default:
                        // Generic business errors (including 4xx/5xx envelope codes) do not
                        // establish no commit. Keep the exact intent until matching readback.
                        let unknown = try await recovery.transition(ticket, to: .unknown, key: key)
                        try check(session, request); cachedCompletion = unknown
                    }
                } catch {
                    guard currentSession() == session, generation == request else { return }
                    localRecoveryFailed = true; issue = .persistenceUnavailable; phase = .unknown; return
                }
            }
            if case PlayExperienceError.rejected(let code, _) = error, code == 409 {
                phase = .needsReadback; await load(); return
            }
            fail(error, session: session, generation: request)
            if unresolved { phase = .unknown }
        }
    }
    /// Only a verified readback offers replay. The dispatch CAS rechecks its exact generation.
    public var canRetryExactBranch: Bool {
        guard gameplayMode == .cityOrientation, service.enabled.contains(.classicCompletion), phase == .unknown, retryReadbackVerified, hintUnknownNodes.isEmpty, !leaderOutcomeUnknown,
              let session = loadedSession, session == currentSession(), let snapshot,
              let pending = cachedCompletion?.value, pending.intent.gameplayMode == gameplayMode, let advance = pending.intent.advance,
              !pending.requestAcknowledged, pending.intent.owner.matches(session),
              pending.state != .dispatching || pending.dispatchProcess != recovery.processID,
              snapshot.route?.sessionID == pending.intent.routeSessionID,
              snapshot.route?.version == advance.expectedVersion,
              snapshot.route?.nodeStates[pending.intent.nodeID] == "PLAYABLE" else { return false }
        return true
    }
    public func retryExactBranchAfterReadback() async {
        guard canRetryExactBranch, let session = loadedSession, let pending = cachedCompletion,
              let review = try? pending.value.intent.review(session: session, generation: generation),
              let stored = pending.value.intent.advance?.actionID,
              let proposed = review.advance?.actionID,
              PlayActionReceiptIdentity.retained(original: stored, proposed: proposed) == stored else { return }
        await dispatch(review, recovering: pending)
    }
    public func requestHint(nodeID: Int, level: Int?, context: PlayInteractionContext? = nil) async {
        // Puzzle scoring is orientation-only. Generic template hints have their
        // own source authority and are not reclassified by entry scope.
        guard accepts(context), level == nil || gameplayMode == .cityOrientation,
              service.enabled.contains(.hints), canWrite, !hintUnknownNodes.contains(nodeID), let session = loadedSession,
              let node = snapshot?.visibleNodes.first(where: { $0.id == nodeID }), snapshot?.isLocked(node) == false else { return }
        let request = generation; phase = .submitting; hintUnknownNodes.insert(nodeID)
        let hintKey = PlayRunStorageKey.make(session: session, scope: scope)
        unknownHintRequests[hintKey, default: [:]][nodeID] = level ?? -1
        do {
            let receipt = try await service.hint(scope: scope, nodeID: nodeID, level: level, token: session.token)
            try check(session, request); hint = receipt; hintUnknownNodes.remove(nodeID); unknownHintRequests[hintKey]?.removeValue(forKey: nodeID); phase = .needsReadback; await load()
        } catch {
            if case PlayExperienceError.rejected = error { hintUnknownNodes.remove(nodeID); unknownHintRequests[hintKey]?.removeValue(forKey: nodeID) }
            if case PlayExperienceError.disabled = error { hintUnknownNodes.remove(nodeID); unknownHintRequests[hintKey]?.removeValue(forKey: nodeID) }
            unresolved = !hintUnknownNodes.isEmpty
            fail(error, session: session, generation: request)
        }
    }
    /// Cast reads for this play session. Capabilities stay empty, so profile, voice and branch writes do not send.
    public func makeCastCoordinator() -> CastCoordinator {
        CastCoordinator(service: CastService(configuration: service.configuration, transport: service.transport, enabled: CastCapability.productionEnabled), currentSession: currentSession)
    }
    /// UG-05…UG-09: the hint ladder client for one node of the current route run. Nil without a route
    /// session, a current read, or both the read and hint grants. Replies for another session are dropped.
    public func helpClient(nodeID: Int) -> PlayHelpClient? {
        guard service.enabled.isSuperset(of: [.reads, .hints]), hasCurrentMediaSnapshot, let session = loadedSession,
              let identity = PlayHelpIdentity(owner: PlayRunStorageKey.make(session: session, scope: scope),
                                              runID: snapshot?.route?.sessionID, nodeID: nodeID) else { return nil }
        let service = self.service, request = generation, token = session.token
        let runID = identity.runID
        let isCurrent: () -> Bool = { [weak self] in
            guard let self else { return false }
            return self.generation == request && self.currentSession() == session && self.snapshot?.route?.sessionID == runID
        }
        return PlayHelpClient(identity: identity,
            view: { await service.help(.view, runID: runID, nodeID: nodeID, token: token) },
            use: { level, requestID in await service.help(.use(level: level, requestID: requestID), runID: runID, nodeID: nodeID, token: token) },
            skip: { requestID in await service.help(.skip(requestID: requestID), runID: runID, nodeID: nodeID, token: token) },
            receipt: { await service.help(.receipt, runID: runID, nodeID: nodeID, token: token) },
            isCurrent: isCurrent,
            onSkipped: { [weak self] in
                // The skip is settled by the server (0 points, assisted). Re-read progress; no completion or reward here.
                guard let self, isCurrent() else { return }
                await self.load()
            },
            onUnauthorized: { [weak self] in
                guard let self, self.currentSession() == session else { return }
                self.onUnauthorized(session)
            })
    }
    /// Free exploration reads its own ending only after authoritative redemption.
    /// No orientation leaderboard or completion command is inferred from card count.
    public func loadFreeExplorationEnding() async {
        guard gameplayMode == .freeExploration, hasCurrentMediaSnapshot, let snapshot,
              FreeExplorationPresentation(snapshot: snapshot)?.isFullyRedeemed == true,
              let session = loadedSession, session == currentSession(), phase != .submitting else { return }
        let request = generation
        do { let value = try await service.ending(scope: scope, token: session.token); try check(session, request); ending = value }
        catch { fail(error, session: session, generation: request) }
    }
    public func loadEndingAndLeaderboard() async {
        guard gameplayMode == .cityOrientation, let session = loadedSession, session == currentSession(), phase != .submitting else { return }
        let request = generation
        leaderboardUnavailable = false
        // fix-1128b #16: both reads are soft. MP mode 1 has no ending card and its board shows `board.error` in place,
        // so a refused or failed read never sets a page issue. Sign-out and a changed session still go through `fail`.
        do {
            let ending = try await service.ending(scope: scope, token: session.token); try check(session, request); self.ending = ending
        } catch {
            guard continuesAfterSoftRead(error, session: session, generation: request) else { return }
        }
        do {
            let board = try await service.leaderboard(scope: scope, token: session.token); try check(session, request)
            guard board.me.id == session.accountID else { throw PlayExperienceError.malformed }; leaderboard = board
            publishLiveActivity() // components r1 C1: the final Live Activity card shows the player's score / rank
        } catch {
            if continuesAfterSoftRead(error, session: session, generation: request) { leaderboardUnavailable = true }
        }
    }
    /// True when a failed optional read leaves the page as it is. Unauthorized, a stale session or a newer generation
    /// go through `fail` (sign-out / invalidate) and return false.
    private func continuesAfterSoftRead(_ error: Error, session: PlayExperienceSession, generation request: UInt64) -> Bool {
        let playError = error as? PlayExperienceError
        guard generation == request, currentSession() == session, !(error is CancellationError),
              playError != .unauthorized, playError != .staleSession else {
            fail(error, session: session, generation: request); return false
        }
        return true
    }
    /// mp-journey r3: MP 同行者榜 sheet (`openBoard`, `/api/play/leaderboard`). A failure stays in the sheet (MP
    /// `board.error`) and never fails the page.
    public func readLeaderboard() async throws -> PlayCompanionLeaderboard {
        guard let session = loadedSession, session == currentSession() else { throw PlayExperienceError.staleSession }
        let request = generation
        let board = try await service.leaderboard(scope: scope, token: session.token)
        try check(session, request)
        guard board.me.id == session.accountID else { throw PlayExperienceError.malformed }
        return board
    }
    public func loadLead(context: PlayInteractionContext? = nil) async {
        await readLead(context: context, polling: false)
    }
    /// mp-journey r3: MP `loadData` probes team-progress once after the nodes read (`loadTeamProgress`). A probe failure
    /// only marks `leadReadFailed` (MP `leadLoadError`), never the page phase.
    public func probeLead(context: PlayInteractionContext? = nil) async {
        await readLead(context: context, polling: true)
    }
    /// Mini pages/play polls team-progress every 4s while a team exists. The loop
    /// ends when its task is cancelled (page left or scene inactive), the context
    /// changes or a read reports exists=false. It never dispatches a leader command.
    public func pollLead(context: PlayInteractionContext?, intervalNanoseconds: UInt64 = PlayLeadProgressPolling.intervalNanoseconds,
                         sleep: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }) async {
        while PlayLeadProgressPolling.continues(lead: lead), accepts(context), !Task.isCancelled {
            do { try await sleep(intervalNanoseconds) } catch { return }
            guard !Task.isCancelled, accepts(context) else { return }
            await readLead(context: context, polling: true)
        }
    }
    private func readLead(context: PlayInteractionContext?, polling: Bool) async {
        // The source's club lead tools are mode-independent, but a queued
        // request from an earlier render must not acquire a new mode's lease.
        guard accepts(context), case .activity(let activity) = scope, let session = currentSession(), phase != .submitting else { return }
        let request = generation
        leadReadIssued &+= 1; let epoch = leadReadIssued
        do {
            let result = try await service.teamProgress(activityID: activity, token: session.token); try check(session, request)
            // Poll, manual reload and post-command readback can overlap. Only a response
            // newer than the one already applied lands; "latest issued" would starve
            // every response once a GET is slower than the poll interval.
            guard claimLeadRead(epoch) else { return }
            lead = result; leadReadFailed = false
        } catch {
            guard generation == request, currentSession() == session else { fail(error, session: session, generation: request); return }
            if polling && Task.isCancelled { return }
            guard claimLeadRead(epoch) else { return }
            leadReadFailed = true
            // A background poll failure keeps the page phase and the last applied lead;
            // manual reads and revoked credentials keep the existing failure path.
            if !polling || (error as? PlayExperienceError) == .unauthorized { fail(error, session: session, generation: request) }
        }
    }
    private func claimLeadRead(_ epoch: UInt64) -> Bool {
        guard epoch >= leadReadApplied else { return false }
        leadReadApplied = epoch; return true
    }
    public func performLead(_ action: PlayLeadAction, text: String? = nil, context: PlayInteractionContext? = nil) async {
        guard action != .unlockChapter, accepts(context), service.enabled.contains(.leader), canWrite, !leaderOutcomeUnknown, let session = loadedSession, case .activity(let activity) = scope,
              lead?.allows(action, accountID: session.accountID) == true else { return }
        let request = generation; phase = .submitting; leaderOutcomeUnknown = true
        let leaderKey = PlayRunStorageKey.make(session: session, scope: scope); unknownLeaderKeys.insert(leaderKey)
        do {
            try await service.lead(activityID: activity, action: action, text: text, token: session.token)
            try check(session, request); leaderOutcomeUnknown = false; unknownLeaderKeys.remove(leaderKey); phase = .needsReadback
            await load(); await loadLead(context: interactionContext)
        } catch {
            if case PlayExperienceError.rejected = error { leaderOutcomeUnknown = false; unknownLeaderKeys.remove(leaderKey) }
            if case PlayExperienceError.disabled = error { leaderOutcomeUnknown = false; unknownLeaderKeys.remove(leaderKey) }
            fail(error, session: session, generation: request)
        }
    }
    /// WP-02: the chapter release this owner and session still has open. Its outcome is read back, never replaced.
    public var pendingUnlock: PlayLeadUnlockCommand? {
        guard let session = loadedSession else { return nil }
        return unlockCommands[PlayRunStorageKey.make(session: session, scope: scope)]
    }
    /// `leadUnlock`: freeze `{commandId, expectedChapterId, targetChapterId}` from the current team read, send it once,
    /// and on an unknown outcome only re-read `unlock-chapter-receipt` with the same command id.
    public func unlockChapter(context: PlayInteractionContext? = nil) async {
        guard accepts(context), service.enabled.contains(.leader), !leadToolBusy, phase == .ready || phase == .unknown,
              let session = loadedSession, session == currentSession(), case .activity(let activity) = scope else { return }
        let key = PlayRunStorageKey.make(session: session, scope: scope)
        var command: PlayLeadUnlockCommand
        if let open = unlockCommands[key] { command = open }
        else {
            guard let lead, lead.allows(.unlockChapter, accountID: session.accountID) else { return }
            guard let fresh = PlayLeadUnlockCommand(activityID: activity, expectedChapterID: lead.currentChapterID, targetChapterID: lead.nextChapterID) else {
                leadNotice = .noNextChapter; return
            }
            command = fresh; unlockCommands[key] = fresh
        }
        let request = generation
        leadToolBusy = true; defer { leadToolBusy = false }
        do {
            let data = command.receiptOnly ? try await service.unlockChapterReceipt(command, token: session.token)
                                           : try await service.unlockChapter(command, token: session.token)
            try check(session, request)
            guard command.confirms(data) else { throw PlayExperienceError.unknownResult }
            unlockCommands[key] = nil; leaderOutcomeUnknown = false; unknownLeaderKeys.remove(key); leadNotice = .unlockApplied
        } catch let refusal as PlayCommandRefusal where refusal.intentNotExecuted {
            guard currentSession() == session, generation == request else { return }
            leaderOutcomeUnknown = false; unknownLeaderKeys.remove(key); leadNotice = .unlockNotExecuted
        } catch PlayExperienceError.rejected(let code, let message) where code != 520 && code != 401 {
            guard currentSession() == session, generation == request else { return }
            // A definite refusal of a new command ends it; 409 (command id bound to other input) and receipt reads keep it.
            if code != 409 && !command.receiptOnly { unlockCommands[key] = nil }
            leaderOutcomeUnknown = unlockCommands[key]?.receiptOnly == true
            leadNotice = .server(message)
        } catch {
            guard currentSession() == session, generation == request else { return }
            if (error as? PlayExperienceError) == .unauthorized { onUnauthorized(session); return }
            if (error as? PlayExperienceError) == .disabled { return }
            // Unknown: keep the original identity and only query its receipt from now on.
            command.receiptOnly = true; unlockCommands[key] = command
            leaderOutcomeUnknown = true; unknownLeaderKeys.insert(key); leadNotice = .unlockPending
            return
        }
        await loadLead(context: interactionContext)
    }
    /// The server said the expected chapter moved, so the original intent did not run. The leader ends it explicitly.
    public func endUnlockIntent() {
        guard let session = loadedSession, leadNotice == .unlockNotExecuted else { return }
        unlockCommands[PlayRunStorageKey.make(session: session, scope: scope)] = nil; leadNotice = nil
    }
    /// `leadReleaseStation`: the leader lets one stuck member skip one station (0 points). Rules are all server side.
    public func releaseStation(_ request: PlayLeadProgress.SkipRequest, context: PlayInteractionContext? = nil) async {
        guard accepts(context), service.enabled.contains(.leader), !leadToolBusy, let session = loadedSession, session == currentSession(),
              case .activity(let activity) = scope, lead?.isLeader == true, lead?.skipRequests.contains(request) == true else { return }
        let generationAtStart = generation
        leadToolBusy = true; defer { leadToolBusy = false }
        do {
            try await service.releaseStation(activityID: activity, memberID: request.memberID, nodeID: request.nodeID, token: session.token)
            try check(session, generationAtStart); leadNotice = .released
        } catch PlayExperienceError.rejected(_, let message) {
            guard currentSession() == session, generation == generationAtStart else { return }
            leadNotice = .server(message)
        } catch {
            guard currentSession() == session, generation == generationAtStart else { return }
            if (error as? PlayExperienceError) == .unauthorized { onUnauthorized(session); return }
            leadNotice = .releaseNotSent
        }
        await loadLead(context: interactionContext)
    }
    public func restoreRun() async {
        #if DEBUG
        NSLog("[E2E] restoreRun mode=%@ media=%@ runPersistence=%@ loaded=%@ busy=%@", String(describing: gameplayMode),
              String(hasCurrentMediaSnapshot), String(service.enabled.contains(.runPersistence)),
              String(loadedSession != nil && loadedSession == currentSession()), String(runStorageBusy))
        #endif
        guard gameplayMode == .cityOrientation, hasCurrentMediaSnapshot,
              service.enabled.contains(.runPersistence), let session = loadedSession, session == currentSession(), !runStorageBusy else { return }
        runStorageBusy = true; defer { runStorageBusy = false }
        let request = generation, key = PlayRunStorageKey.make(session: session, scope: scope)
        await reconcileRun(session: session, request: request, key: key)
    }
    private func reconcileRun(session: PlayExperienceSession, request: UInt64, key: String) async {
        do {
            let local = try await pausedStorage.read(key: key); try check(session, request)
            if let value = local.value { guard value.owner.matches(session) else { throw PlayExperienceError.persistenceUnavailable } }
            // Network read failure may retain a verified local record; local failures never fall back.
            let remote: PlayPausedRead?
            do { remote = try await service.readPaused(scope: scope, token: session.token) }
            catch {
                try check(session, request)
                if error as? PlayExperienceError == .unauthorized { onUnauthorized(session); invalidate(); return }
                remote = nil
            }
            try check(session, request)
            let tombstone = max(local.value?.tombstone ?? 0, remote?.endedAt ?? 0)
            let candidate = PlayPausedRecord.reconcile(local: local.value?.record, remote: remote)
            let reconciled = candidate.flatMap { $0.savedAt > tombstone ? $0 : nil }
            let remoteConfirms: Bool
            if let old = local.value, old.pendingRemote {
                if let record = old.record { remoteConfirms = remote?.record == record || (remote?.endedAt ?? 0) >= record.savedAt }
                else { remoteConfirms = (remote?.endedAt ?? 0) >= old.tombstone && old.tombstone > 0 }
            } else { remoteConfirms = true }
            // Settle the exact pending operation first, then apply newer authoritative facts.
            // Each step is generation-CAS; a crash between them still retains safe local state.
            var lease = local
            if let old = local.value, old.pendingRemote, remoteConfirms {
                let settled = try PlayPausedSnapshot(owner: old.owner, record: old.record, tombstone: old.tombstone)
                lease = try await pausedStorage.write(settled, replacing: lease, key: key); try check(session, request)
            }
            let value: PlayPausedSnapshot
            if let old = lease.value, old.pendingRemote { value = old }
            else { value = try .init(owner: .init(session: session), record: reconciled, tombstone: tombstone) }
            if value != lease.value { lease = try await pausedStorage.write(value, replacing: lease, key: key); try check(session, request) }
            pausedLease = lease; pausedOwner = session
            clock.restore(value.record); localRecoveryFailed = false; publishLiveActivity()
            remoteRunSaveFailed = value.pendingRemote
        } catch {
            #if DEBUG
            NSLog("[E2E] reconcileRun failed: %@", LogFieldRedaction.redacted(String(describing: error)))
            #endif
            guard currentSession() == session, generation == request else { return }
            localRecoveryFailed = true; issue = .persistenceUnavailable; clock.restore(nil); pausedLease = nil; pausedOwner = nil
        }
    }
    public func startRun(now: TimeInterval) {
        #if DEBUG
        NSLog("[E2E] startRun canManage=%@ owner=%@ lease=%@ pending=%@ busy=%@ recoveryFailed=%@ phase=%@", String(canManageRun),
              String(loadedSession != nil && currentSession() == loadedSession && pausedOwner == loadedSession), String(pausedLease != nil),
              String(pausedLease?.value?.pendingRemote == true), String(runStorageBusy), String(localRecoveryFailed), String(describing: clock.phase))
        #endif
        // OWN-10.3.b: an unsupported verdict refuses this content's start; unconfirmed does not.
        guard compatibility?.blocksStart != true else { return }
        guard canManageRun, let loadedSession, currentSession() == loadedSession, pausedOwner == loadedSession, pausedLease != nil, pausedLease?.value?.pendingRemote != true, !runStorageBusy, !localRecoveryFailed else { return }
        try? clock.start(monotonicNow: now)
        publishLiveActivity()
    }
    public func pauseRun(now: TimeInterval, savedAt: Int64) async {
        guard canManageRun, let session = loadedSession, currentSession() == session, pausedOwner == session, let old = pausedLease, old.value?.pendingRemote != true, !runStorageBusy,
              let record = try? clock.pause(monotonicNow: now, savedAt: savedAt) else { return }
        publishLiveActivity()
        runStorageBusy = true; defer { runStorageBusy = false }
        let request = generation, key = PlayRunStorageKey.make(session: session, scope: scope)
        do {
            try check(session, request)
            let value = try PlayPausedSnapshot(owner: .init(session: session), record: record, tombstone: old.value?.tombstone ?? 0, pendingRemote: true)
            let saved = try await pausedStorage.write(value, replacing: old, key: key); try check(session, request)
            pausedLease = saved; localRecoveryFailed = false
        } catch {
            guard currentSession() == session, generation == request else { return }
            localRecoveryFailed = true; remoteRunSaveFailed = true; issue = .persistenceUnavailable; return
        }
        do {
            guard let saved = pausedLease else { throw PlayExperienceError.persistenceUnavailable }
            let attempt = try PlayPreparedDispatch(service: service, scope: scope, session: session, paused: saved, store: pausedStorage,
                isCurrent: { [weak self] in guard let self else { return false }; return self.generation == request && self.currentSession() == session })
            runAttempt = attempt
            let service = self.service, taskID = UUID(); runTaskID = taskID
            let task = Task { _ = try await service.dispatch(attempt) }; runTask = task
            defer { attempt.retire(); if runTaskID == taskID { runTask = nil; runAttempt = nil } }
            try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            try check(session, request); await reconcileRun(session: session, request: request, key: key)
        }
        catch {
            guard currentSession() == session, generation == request else { return }
            if error as? PlayExperienceError == .unauthorized { onUnauthorized(session); invalidate(); return }
            remoteRunSaveFailed = true
        }
    }
    /// One atomic local tombstone replaces the record before the dormant remote clear.
    public func endRun(now: TimeInterval, savedAt: Int64) async {
        guard canManageRun, let session = loadedSession, currentSession() == session, pausedOwner == session, let old = pausedLease, old.value?.pendingRemote != true, savedAt > 0, !runStorageBusy else { return }
        runStorageBusy = true; defer { runStorageBusy = false }
        let request = generation, key = PlayRunStorageKey.make(session: session, scope: scope)
        do {
            try check(session, request)
            let value = try PlayPausedSnapshot(owner: .init(session: session), record: nil, tombstone: max(savedAt, old.value?.tombstone ?? 0), pendingRemote: true)
            let saved = try await pausedStorage.write(value, replacing: old, key: key); try check(session, request)
            pausedLease = saved; clock.end(monotonicNow: now); localRecoveryFailed = false
            publishLiveActivity()
        } catch {
            guard currentSession() == session, generation == request else { return }
            localRecoveryFailed = true; remoteRunSaveFailed = true; issue = .persistenceUnavailable; return
        }
        do {
            guard let saved = pausedLease else { throw PlayExperienceError.persistenceUnavailable }
            let attempt = try PlayPreparedDispatch(service: service, scope: scope, session: session, paused: saved, store: pausedStorage,
                isCurrent: { [weak self] in guard let self else { return false }; return self.generation == request && self.currentSession() == session })
            runAttempt = attempt
            let service = self.service, taskID = UUID(); runTaskID = taskID
            let task = Task { _ = try await service.dispatch(attempt) }; runTask = task
            defer { attempt.retire(); if runTaskID == taskID { runTask = nil; runAttempt = nil } }
            try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            try check(session, request); await reconcileRun(session: session, request: request, key: key)
        }
        catch {
            guard currentSession() == session, generation == request else { return }
            if error as? PlayExperienceError == .unauthorized { onUnauthorized(session); invalidate(); return }
            remoteRunSaveFailed = true
        }
    }
    public func invalidate() {
        completionAttempt?.retire(); completionAttempt = nil; runAttempt?.retire(); runAttempt = nil
        completionTask?.cancel(); completionTask = nil; completionTaskID = UUID()
        runTask?.cancel(); runTask = nil; runTaskID = UUID()
        pausedLease = nil; pausedOwner = nil; retryReadbackVerified = false
        thoughtSyncNonce = UUID(); thoughtSyncInFlight = false; pendingThoughtKeys = []; thoughtClaimSessionID = nil; thoughtSyncPhase = .idle
        chapterStories = [:]; storyVariables = [:]; storyVoices = [:]; storyThoughts = []
        compatibility = nil; contentVersion = nil
        generation &+= 1; loadedSession = nil; authorityMode = nil; snapshot = nil; castPayload = .null; extras = [:]; reward = nil; aiScores = [:]; hint = nil; cachedCompletion = nil
        ending = nil; leaderboard = nil; lead = nil; leadReadFailed = false; advancedReadyNodeIDs = []; clock.restore(nil); phase = .idle
        submitRecovery = nil; arrivalFailure = nil
    }
    private func landed(_ review: PlayCompletionIntent, snapshot: PlaySnapshot) -> Bool {
        // Legacy records without mode stay unresolved; another mode's same node
        // ID and arrival bit cannot establish the result of the earlier write.
        guard let mode = review.gameplayMode, mode == PlayGameplayMode(serverValue: snapshot.result.mode) else { return false }
        if let routeSessionID = review.routeSessionID, snapshot.route?.sessionID != routeSessionID { return false }
        guard let node = snapshot.visibleNodes.first(where: { $0.id == review.nodeID }) else { return false }
        if snapshot.result.mode == 2 {
            switch review.evidence { case .scan: return node.arrived == true; case .photo: return node.selfReported == true; default: return false }
        }
        return snapshot.isDone(node)
    }
    private func check(_ session: PlayExperienceSession, _ request: UInt64) throws {
        guard !Task.isCancelled, currentSession() == session, generation == request else { throw PlayExperienceError.staleSession }
    }
    /// Live mode-2 read: merge unlocked chapters into the encrypted archive. Never re-sends a visit.
    /// An unplayable ticket reads `/api/play/history` instead. Failures here do not fail the play load.
    private func refreshStoryArchive(snapshot: PlaySnapshot, session: PlayExperienceSession, generation request: UInt64) async {
        guard snapshot.result.mode == PlayGameplayMode.freeExploration.rawValue else { return }
        if snapshot.result.playable == false {
            await loadExpiredStory(session: session, topicID: snapshot.result.topicID, topicName: snapshot.result.topicName, generation: request)
            return
        }
        guard let store = storyArchiveStore,
              let built = FreeExplorationStoryArchive(snapshot: snapshot, chapterStories: chapterStories, owner: PlayRecoveryOwner(session: session)) else { return }
        let key = PlayRunStorageKey.make(session: session, scope: scope)
        let merged: FreeExplorationStoryArchive
        if let existing = try? await store.readStoryArchive(key: key) { merged = existing.merging(built) }
        else { merged = built }
        guard generation == request, currentSession() == session else { return }
        try? await store.writeStoryArchive(merged, key: key)
    }
    private func loadExpiredStory(session: PlayExperienceSession, topicID: Int?, topicName: String?, generation request: UInt64) async {
        guard let store = storyArchiveStore, let topicID, topicID > 0 else { return }
        let key = PlayRunStorageKey.make(session: session, scope: scope)
        let known = (try? await store.readStoryArchive(key: key))?.lockedPlaces ?? []
        let activityID: Int? = { if case .activity(let id) = scope { return id }; return nil }()
        do {
            let history = try await service.freeExplorationHistory(topicID: topicID, activityID: activityID, token: session.token)
            guard generation == request, currentSession() == session else { return }
            let archive = FreeExplorationStoryArchive(history: history, owner: PlayRecoveryOwner(session: session), topicID: topicID, topicName: topicName, knownPlaces: known)
            try await store.writeStoryArchive(archive, key: key)
            guard generation == request, currentSession() == session else { return }
            storyArchive = archive
            storyArchiveSource = .expired
        } catch {
            await showCachedStory(session: session, generation: request)
        }
    }
    private func showCachedStory(session: PlayExperienceSession, generation request: UInt64) async {
        guard let store = storyArchiveStore else { return }
        let key = PlayRunStorageKey.make(session: session, scope: scope)
        guard let cached = try? await store.readStoryArchive(key: key), !cached.isEmpty else { return }
        guard generation == request, currentSession() == session else { return }
        storyArchive = cached
        storyArchiveSource = .offline
    }
    private func fail(_ error: Error, session: PlayExperienceSession, generation request: UInt64) {
        guard generation == request else { return }
        guard currentSession() == session else { invalidate(); return }
        if error is CancellationError { issue = .unknownResult }
        else { issue = error as? PlayExperienceError ?? .unknownResult }
        if issue == .unauthorized { onUnauthorized(session); invalidate(); return }
        phase = unresolved ? .unknown : .failed
    }
}
