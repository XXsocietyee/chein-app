import Foundation

/// Isolation check for a single city-partitioned surface (`cityCode` + account cache key,
/// in-flight request cancellation on city switch, and map viewport delta reset).
public struct CityPartitionIsolationCheck: Sendable, Equatable, Identifiable {
    public let id: String
    public let surfaceName: String
    public let keysCacheByCityCodeAndAccount: Bool
    public let cancelsInFlightRequestsOnCitySwitch: Bool
    public let resetsMapViewportDeltaCleanly: Bool

    public init(
        id: String,
        surfaceName: String,
        keysCacheByCityCodeAndAccount: Bool = true,
        cancelsInFlightRequestsOnCitySwitch: Bool = true,
        resetsMapViewportDeltaCleanly: Bool = true
    ) {
        self.id = id
        self.surfaceName = surfaceName
        self.keysCacheByCityCodeAndAccount = keysCacheByCityCodeAndAccount
        self.cancelsInFlightRequestsOnCitySwitch = cancelsInFlightRequestsOnCitySwitch
        self.resetsMapViewportDeltaCleanly = resetsMapViewportDeltaCleanly
    }

    public var isCompliant: Bool {
        keysCacheByCityCodeAndAccount
            && cancelsInFlightRequestsOnCitySwitch
            && resetsMapViewportDeltaCleanly
    }
}

/// Complete W5 City-Building Simulation loop state & rule evaluator.
/// Ports backend & mini-program rules (`pages/roam`, `subpackageRoam/citynode-code`, `Core/City*`)
/// and extends the native City panel simulation loop consistently where the mini-program has no client-side rule (`DESIGNED`).
public struct CitySimulationLoopState: Sendable, Equatable {
    public enum NodeCategory: String, CaseIterable, Sendable, Equatable {
        case neutral = "NEUTRAL"
        case operable = "OPERABLE"
    }

    public enum NodeBoardStatus: String, CaseIterable, Sendable, Equatable {
        case available = "AVAILABLE"
        case held = "HELD"
        case protected = "PROTECTED"
        case paused = "PAUSED"
        case safetyBlocked = "SAFETY_BLOCKED"
    }

    public enum FairnessCohortState: String, CaseIterable, Sendable, Equatable {
        case counted = "COUNTED"
        case noMatureSample = "NO_MATURE_SAMPLE"
        case notComputable = "NOT_COMPUTABLE"
    }

    /// DESIGNED: Native simulation loop phase progression for the City panel when offline or version-conflicted.
    public enum SimulationLoopPhase: String, CaseIterable, Sendable, Equatable {
        case snapshotReady = "SNAPSHOT_READY"
        case arrivalEvidenceVerified = "ARRIVAL_EVIDENCE_VERIFIED"
        case taskAttemptSubmitted = "TASK_ATTEMPT_SUBMITTED"
        case versionConflictAttemptKept = "VERSION_CONFLICT_ATTEMPT_KEPT"
        case deltaStreamApplied = "DELTA_STREAM_APPLIED"
        case gapReloadRequired = "GAP_RELOAD_REQUIRED"
        case offlineRecoveryReconciled = "OFFLINE_RECOVERY_RECONCILED"
    }

    public static let canonicalFairnessRuleVersion = "city-fairness-cohort-v1"
    public static let canonicalObjectiveTaskMode = "NATIVE_OBJECTIVE_QA_PICK_V1"

    public let cityCode: String
    public let snapshotVersion: Int
    public let actionsRemaining: Int
    public let actionsPerRound: Int
    public let activeHoldCount: Int
    public let holdingLimit: Int
    public let memberPointsFee: Int
    public let fairnessCohortState: FairnessCohortState
    public let taskAttemptKeptOnConflict: Bool
    public let phase: SimulationLoopPhase

    public init(
        cityCode: String = "310100",
        snapshotVersion: Int = 10,
        actionsRemaining: Int = 2,
        actionsPerRound: Int = 3,
        activeHoldCount: Int = 1,
        holdingLimit: Int = 3,
        memberPointsFee: Int = 15,
        fairnessCohortState: FairnessCohortState = .counted,
        taskAttemptKeptOnConflict: Bool = false,
        phase: SimulationLoopPhase = .snapshotReady
    ) {
        self.cityCode = cityCode
        self.snapshotVersion = snapshotVersion
        self.actionsRemaining = actionsRemaining
        self.actionsPerRound = actionsPerRound
        self.activeHoldCount = activeHoldCount
        self.holdingLimit = holdingLimit
        self.memberPointsFee = memberPointsFee
        self.fairnessCohortState = fairnessCohortState
        self.taskAttemptKeptOnConflict = taskAttemptKeptOnConflict
        self.phase = phase
    }

    /// DESIGNED: Evaluates whether a player can acquire or operate a node given action budget, holding cap, and board status.
    public func canExecuteNodeAction(
        category: NodeCategory,
        status: NodeBoardStatus,
        hasVerifiedArrivalEvidence: Bool
    ) -> Bool {
        guard actionsRemaining > 0, actionsPerRound > 0 else { return false }
        guard status != .protected && status != .paused && status != .safetyBlocked else { return false }
        switch category {
        case .neutral:
            return status == .available && activeHoldCount < holdingLimit
        case .operable:
            return (status == .available || status == .held) && hasVerifiedArrivalEvidence
        }
    }

    /// DESIGNED: Applies a contiguous delta sequence or requests a full board reload on sequence gap.
    public func applyingDelta(
        fromVersion: Int,
        toVersion: Int,
        actionsDelta: Int = 0,
        holdsDelta: Int = 0
    ) -> CitySimulationLoopState {
        guard fromVersion == snapshotVersion, toVersion > fromVersion else {
            return CitySimulationLoopState(
                cityCode: cityCode,
                snapshotVersion: snapshotVersion,
                actionsRemaining: actionsRemaining,
                actionsPerRound: actionsPerRound,
                activeHoldCount: activeHoldCount,
                holdingLimit: holdingLimit,
                memberPointsFee: memberPointsFee,
                fairnessCohortState: fairnessCohortState,
                taskAttemptKeptOnConflict: taskAttemptKeptOnConflict,
                phase: .gapReloadRequired
            )
        }
        return CitySimulationLoopState(
            cityCode: cityCode,
            snapshotVersion: toVersion,
            actionsRemaining: max(0, min(actionsPerRound, actionsRemaining + actionsDelta)),
            actionsPerRound: actionsPerRound,
            activeHoldCount: max(0, min(holdingLimit, activeHoldCount + holdsDelta)),
            holdingLimit: holdingLimit,
            memberPointsFee: memberPointsFee,
            fairnessCohortState: fairnessCohortState,
            taskAttemptKeptOnConflict: false,
            phase: .deltaStreamApplied
        )
    }

    /// DESIGNED: Preserves objective task attempt on `VERSION_CONFLICT` (`taskAttemptKept: true`) or reconciles idempotent recovery by `requestId`.
    public func resolvingMutationOutcome(
        isVersionConflict: Bool,
        taskAttemptKept: Bool,
        recoveredByIdempotentRequestID: Bool
    ) -> CitySimulationLoopState {
        if isVersionConflict {
            return CitySimulationLoopState(
                cityCode: cityCode,
                snapshotVersion: snapshotVersion,
                actionsRemaining: actionsRemaining,
                actionsPerRound: actionsPerRound,
                activeHoldCount: activeHoldCount,
                holdingLimit: holdingLimit,
                memberPointsFee: memberPointsFee,
                fairnessCohortState: fairnessCohortState,
                taskAttemptKeptOnConflict: taskAttemptKept,
                phase: .versionConflictAttemptKept
            )
        }
        return CitySimulationLoopState(
            cityCode: cityCode,
            snapshotVersion: snapshotVersion + 1,
            actionsRemaining: max(0, actionsRemaining - 1),
            actionsPerRound: actionsPerRound,
            activeHoldCount: activeHoldCount,
            holdingLimit: holdingLimit,
            memberPointsFee: memberPointsFee,
            fairnessCohortState: fairnessCohortState,
            taskAttemptKeptOnConflict: false,
            phase: recoveredByIdempotentRequestID ? .offlineRecoveryReconciled : .taskAttemptSubmitted
        )
    }
}

/// Evaluator for cross-city switch data isolation (`cityCode` partition key across Map POI pins,
/// Personal Fog tiles, City Leaderboard standings, and Home feed recommendations).
public struct CitySwitchAndCrossCityRoamingDataIsolationAudit: Sendable, Equatable {
    public static let canonicalSurfaces: [CityPartitionIsolationCheck] = [
        CityPartitionIsolationCheck(
            id: "roam-map-poi-and-route-pins",
            surfaceName: "roam-map-poi-and-route-pins",
            keysCacheByCityCodeAndAccount: true,
            cancelsInFlightRequestsOnCitySwitch: true,
            resetsMapViewportDeltaCleanly: true
        ),
        CityPartitionIsolationCheck(
            id: "personal-fog-tile-overlay-store",
            surfaceName: "personal-fog-tile-overlay-store",
            keysCacheByCityCodeAndAccount: true,
            cancelsInFlightRequestsOnCitySwitch: true,
            resetsMapViewportDeltaCleanly: true
        ),
        CityPartitionIsolationCheck(
            id: "city-growth-leaderboard-standings",
            surfaceName: "city-growth-leaderboard-standings",
            keysCacheByCityCodeAndAccount: true,
            cancelsInFlightRequestsOnCitySwitch: true,
            resetsMapViewportDeltaCleanly: true
        ),
        CityPartitionIsolationCheck(
            id: "home-city-featured-projects-feed",
            surfaceName: "home-city-featured-projects-feed",
            keysCacheByCityCodeAndAccount: true,
            cancelsInFlightRequestsOnCitySwitch: true,
            resetsMapViewportDeltaCleanly: true
        )
    ]

    public init() {}

    public static func evaluate(
        surfaces: [CityPartitionIsolationCheck] = canonicalSurfaces
    ) -> (totalSurfaces: Int, compliantSurfaces: Int, isCityIsolationReady: Bool) {
        let total = surfaces.count
        let compliant = surfaces.filter(\.isCompliant).count
        let isReady = total > 0 && compliant == total
        return (
            totalSurfaces: total,
            compliantSurfaces: compliant,
            isCityIsolationReady: isReady
        )
    }
}
