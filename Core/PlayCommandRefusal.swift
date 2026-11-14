import Foundation

/// U05-01 / UG-09. A non-200 reply from a basic play command (`answer`, `checkin`, `arrive`,
/// `photo`, `sensor-result`) as defined by the backend `PlayCommandErrorContract`. Only the
/// machine fields decide what happens next; the Chinese `msg` is shown, never parsed.
public struct PlayCommandRefusal: Error, Equatable {
    public let code: Int
    public let message: String?
    public let errorCode: String?
    /// Sub-reason of the aggregated `ARRIVE_FIRST` answer refusal.
    public let reasonCode: String?
    /// Arrive refusals repeat `errorCode` here (`arrivalReasonCode`).
    public let arrivalReasonCode: String?
    public let retryable: Bool
    public let refreshRequired: Bool
    public let newActionIdRequired: Bool
    public let intentTerminal: Bool
    /// Only true on replies that prove no business side effect.
    public let intentNotExecuted: Bool
    /// `PENDING` / `UNKNOWN` from a real receipt lookup. Neither is a failure.
    public let receiptState: String?
    /// Node ids from the frozen station's contract-approved replacement list. Strings on the wire.
    public let approvedFallbacks: [Int]
    public let appealable: Bool
    /// WP-02 guard appeal binding (`arrival-guard-view.js`): positive decimal ids, and the appeal type the server named.
    public let guardLogID: String?
    public let routeSessionID: String?
    public let appealBizType: String?

    public init?(envelope: PlayWireValue) {
        guard envelope.object != nil, let code = envelope["code"].tolerantInteger, code != 200 else { return nil }
        self.code = code
        message = envelope["msg"].text.flatMap { $0.isEmpty ? nil : String($0.prefix(200)) }
        func token(_ key: String) -> String? {
            guard let raw = envelope[key].text, raw.range(of: "^[A-Z][A-Z0-9_]{1,63}$", options: .regularExpression) != nil else { return nil }
            return raw
        }
        errorCode = token("errorCode"); reasonCode = token("reasonCode"); arrivalReasonCode = token("arrivalReasonCode")
        retryable = envelope["retryable"].bool == true || envelope["canRetry"].bool == true
        refreshRequired = envelope["refreshRequired"].bool == true
        newActionIdRequired = envelope["newActionIdRequired"].bool == true
        intentTerminal = envelope["intentTerminal"].bool == true
        intentNotExecuted = envelope["intentNotExecuted"].bool == true
        receiptState = envelope["receiptState"].text.flatMap { ["PENDING", "UNKNOWN"].contains($0) ? $0 : nil }
        var fallbacks: [Int] = []
        for row in envelope["approvedFallbacks"].array ?? [] {
            if let id = row.tolerantInteger, id > 0, !fallbacks.contains(id) { fallbacks.append(id) }
        }
        approvedFallbacks = Array(fallbacks.prefix(8))
        appealable = envelope["appealable"].bool == true
        func positive(_ key: String) -> String? {
            ClubEditionEmptyReason.idText(envelope[key]).flatMap { PlayGuardAppealReference.positiveID($0) ? $0 : nil }
        }
        guardLogID = positive("guardLogId"); routeSessionID = positive("routeSessionId")
        appealBizType = envelope["appealBizType"].text == "play_arrive_guard" ? "play_arrive_guard" : nil
    }

    /// The contract fields are present. An older server sends only `code` + `msg`; that reply
    /// keeps the existing "result not confirmed" handling.
    public var carriesContract: Bool {
        errorCode != nil || intentTerminal || intentNotExecuted || newActionIdRequired || refreshRequired || receiptState != nil
    }
    /// The original action is settled as not applied: a terminal receipt was written, or the
    /// server proved nothing happened. A new attempt needs a new action id.
    public var settlesAsFailed: Bool {
        receiptState == nil && code != 520 && errorCode != Self.actionReused
            && (intentTerminal || newActionIdRequired || intentNotExecuted)
    }
    /// The action id is already bound to a different input. The backend deliberately does not say
    /// whether the original landed, so this is a conflict, never a settled failure.
    public static let actionReused = "INTENT_ACTION_REUSED"
    /// Still unknown: the server itself says the receipt is pending or missing.
    public var isPending: Bool { code == 520 || receiptState != nil }
    public var arrivalReason: PlayArrivalFailureReason? {
        PlayArrivalFailureReason(code: arrivalReasonCode ?? (errorCode == "ARRIVE_FIRST" ? reasonCode : errorCode))
    }
}

/// U05-01. Stable arrival refusal reasons (backend `PlayCommandErrorContract` / `ArriveLocationGuard`).
/// Each maps to its own sentence and next step; nothing is inferred from the message text.
public enum PlayArrivalFailureReason: String, CaseIterable, Equatable {
    /// No coordinates reached the server (location permission refused or off).
    case locationMissing = "ARRIVE_LOCATION_MISSING"
    case accuracyMissing = "ARRIVE_ACCURACY_MISSING"
    case accuracyInvalid = "ARRIVE_ACCURACY_INVALID"
    case locationInvalid = "ARRIVE_LOCATION_INVALID"
    case accuracyLow = "ARRIVE_ACCURACY_LOW"
    case tooFar = "ARRIVE_TOO_FAR"
    case locationStale = "ARRIVE_LOCATION_STALE"
    case notRecorded = "ARRIVE_NOT_RECORDED"
    /// The stop has no coordinates configured; another try will not help.
    case coordinatesNotConfigured = "ARRIVE_COORD_NOT_CONFIGURED"
    case guardThrottle = "ARRIVE_GUARD_THROTTLE"
    case guardSpeed = "ARRIVE_GUARD_SPEED"
    case guardWindow = "ARRIVE_GUARD_WINDOW_DISTANCE"
    /// GPS cannot stand in for this stop's proof (store scan or the stop's task).
    case methodUnavailable = "STORE_SCAN_REQUIRED"
    case taskRequired = "TASK_REQUIRED"
    /// The stop was taken off the route (U05-02).
    case stopClosed = "NODE_DELISTED"
    case routeLocked = "ROUTE_LOCKED"
    case leaderRequired = "TEAM_LEAD_REQUIRED"

    init?(code: String?) {
        guard let code, let value = Self(rawValue: code) else { return nil }
        self = value
    }

    public enum Action: String, Equatable { case relocate, refresh, scanInstead, contactOrganizer, appealGuard, waitForLeader }

    /// Next steps. `retryable` from the server decides whether a new location attempt is offered;
    /// a poor fix never widens the fence and GPS never replaces a merchant scan.
    public func actions(retryable: Bool, appealable: Bool, nodeHasScan: Bool) -> [Action] {
        var actions: [Action] = []
        switch self {
        case .locationMissing, .accuracyMissing, .accuracyInvalid, .locationInvalid, .accuracyLow, .tooFar, .locationStale, .guardThrottle:
            if retryable { actions.append(.relocate) }
            if nodeHasScan { actions.append(.scanInstead) }
        case .notRecorded: actions.append(.relocate)
        case .guardSpeed, .guardWindow: if appealable { actions.append(.appealGuard) }
        case .coordinatesNotConfigured, .stopClosed: actions.append(.contactOrganizer)
        case .methodUnavailable, .taskRequired: if nodeHasScan { actions.append(.scanInstead) }
        case .routeLocked: actions.append(.refresh)
        case .leaderRequired: actions.append(.waitForLeader)
        }
        return actions
    }
}

/// U05-01/02 presentation for one stop. Replacement stops are only the server's approved ids that
/// exist in this run's current read and are not done; the client never marks arrival or skips.
public struct PlayArrivalFailure: Equatable {
    public struct Replacement: Equatable, Identifiable { public let id: Int; public let name: String }
    public let nodeID: Int
    public let reason: PlayArrivalFailureReason?
    public let message: String?
    public let actions: [PlayArrivalFailureReason.Action]
    public let replacements: [Replacement]
    public let refreshRequired: Bool
    /// WP-02: set only for an appealable `play_arrive_guard` refusal of a request with a known action id.
    public let guardReference: PlayGuardAppealReference?

    public init(nodeID: Int, refusal: PlayCommandRefusal, snapshot: PlaySnapshot?, arrivalRequestID: String? = nil) {
        self.nodeID = nodeID
        guardReference = refusal.appealable && refusal.appealBizType != nil
            ? PlayGuardAppealReference(guardLogID: refusal.guardLogID, routeSessionID: refusal.routeSessionID, nodeID: nodeID, arrivalRequestID: arrivalRequestID)
            : nil
        reason = refusal.arrivalReason
        message = refusal.message
        let node = snapshot?.visibleNodes.first { $0.id == nodeID }
        let hasScan = node?.needScan == true || node?.validationMethod == 4
        var actions = reason?.actions(retryable: refusal.retryable, appealable: refusal.appealable, nodeHasScan: hasScan) ?? []
        if refusal.refreshRequired, !actions.contains(.refresh) { actions.insert(.refresh, at: 0) }
        self.actions = actions
        refreshRequired = refusal.refreshRequired
        replacements = refusal.approvedFallbacks.compactMap { id in
            guard id != nodeID, let snapshot, let row = snapshot.visibleNodes.first(where: { $0.id == id }),
                  !snapshot.isDone(row), !snapshot.isLocked(row), let name = row.name, !name.isEmpty else { return nil }
            return Replacement(id: id, name: String(name.prefix(24)))
        }
    }
}

/// UG-09. Identity every basic command must carry (`GET /api/play/action-context`).
/// Shared runtimes add `runtimeInstance` + `authorityEpoch`; a personal run has neither.
public struct PlayBasicActionContext: Equatable {
    public let routeSessionID: Int
    public let expectedRouteVersion: Int
    public let runtimeInstance: String?
    public let authorityEpoch: Int?
    public init(raw: PlayWireValue) throws {
        guard let session = raw["routeSessionId"].tolerantInteger, session >= 0,
              let version = raw["expectedRouteVersion"].tolerantInteger, version >= 0 else { throw PlayExperienceError.malformed }
        let instance = raw["runtimeInstance"].text
        let epoch = raw["authorityEpoch"].tolerantInteger
        // Both shared-runtime fields or neither.
        guard (instance == nil) == (epoch == nil), instance.map({ !$0.isEmpty && $0.count <= 96 }) ?? true else { throw PlayExperienceError.malformed }
        routeSessionID = session; expectedRouteVersion = version; runtimeInstance = instance; authorityEpoch = epoch
    }
}

/// U05-03. What the player sees about the last basic submission of this run, kept apart from
/// the coarse coordinator phase: checking, still pending, applied, definitely failed, conflict.
public enum PlaySubmitRecoveryState: Equatable {
    /// Reading the original receipt with the same action id.
    case checking(nodeID: Int)
    /// The server has no settled receipt yet (`PENDING` / `UNKNOWN`). Not a failure.
    case pending(nodeID: Int)
    /// The original receipt confirms the write applied (this process or after a restart).
    case confirmed(nodeID: Int)
    /// The original action settled as not applied; a new attempt uses a new action id.
    case failed(nodeID: Int, refusal: PlayCommandRefusal)
    /// The run moved on (version / session changed); refresh before any new attempt.
    case conflict(nodeID: Int)
    public var nodeID: Int {
        switch self {
        case .checking(let id), .pending(let id), .confirmed(let id), .conflict(let id): return id
        case .failed(let id, _): return id
        }
    }
}

/// §23.2 / §27.3. Only a real successful arrival receipt carries `arrivalReading{level,log}`.
/// The level is a story intensity, never converted into points or rewards.
public struct PlayArrivalReading: Equatable {
    public let level: Int
    public let log: String
    public init?(receipt: PlayWireValue) {
        let raw = receipt["arrivalReading"]
        guard raw.object != nil, let level = raw["level"].tolerantInteger, (0...3).contains(level),
              let log = raw["log"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !log.isEmpty else { return nil }
        self.level = level; self.log = String(log.prefix(600))
    }
}

/// U05-02. Route-level notice from `/api/play/route-state` `status` (mini-program `_routeNoticeForState`).
public enum PlayRouteNotice: String, Equatable {
    case configWithdrawn, ended, switchedToFallback, unsynced
    public init?(route: PlayRouteState?) {
        guard let route else { return nil }
        switch route.status?.uppercased() {
        case "UNAVAILABLE", "WITHDRAWN", "CONFIG_WITHDRAWN": self = .configWithdrawn
        case "ENDED", "CANCELLED", "EXPIRED": self = .ended
        case "FALLBACK": self = .switchedToFallback
        default:
            if route.isBranch, route.nodeStates.isEmpty { self = .unsynced } else { return nil }
        }
    }
}

/// U05-02 for the shared (organiser) runtime player view: a paused station's reason, expected
/// resumption and the approved replacement exactly as the server projects them. No replacement
/// means no skip; a completion through a replacement keeps its own history label.
public struct PlayStationPauseNotice: Equatable {
    public let reasonCode: String?
    public let reason: String?
    public let resumeEta: String?
    public let replacementNodeID: Int?
    public let replacementName: String?
    public let replacementMessage: String?
    public init?(state: String?, pause: PlayWireValue, fallback: PlayWireValue) {
        guard state == "PAUSED" else { return nil }
        reasonCode = pause["reasonCode"].text.flatMap { $0.isEmpty ? nil : $0 }
        reason = pause["reason"].text.flatMap { $0.isEmpty ? nil : $0 }
        resumeEta = pause["resumeEta"].text.flatMap { $0.isEmpty ? nil : $0 }
        if let target = fallback["targetNodeId"].tolerantInteger, target > 0,
           let message = fallback["playerMessage"].text, !message.isEmpty {
            replacementNodeID = target
            replacementName = fallback["targetNodeName"].text.flatMap { $0.isEmpty ? nil : $0 }
            replacementMessage = message
        } else { replacementNodeID = nil; replacementName = nil; replacementMessage = nil }
    }
    public var hasApprovedReplacement: Bool { replacementNodeID != nil }
}
