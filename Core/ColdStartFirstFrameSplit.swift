import Foundation

/// Device-free cold-start split for an iPhone 12-class (A14) main thread.
///
/// `iphone12Milliseconds` is a class weight for that lane, not an Instruments sample.
/// `measure` walks the lanes on a virtual clock: every critical lane finishes, the
/// first-frame marker is that clock, then the deferred lanes run. The cold-start
/// budget is the critical side only. Folding the deferred side back onto that clock
/// has to miss the budget, so the split is what keeps a cold start inside 1.5s.
public enum ColdStartLane: String, Sendable, CaseIterable, Equatable {
    /// `UNUserNotificationCenter` delegate. Apple requires it before launch finishes.
    case notificationDelegate
    /// Control Center handler. A launch intent can run before the first frame.
    case controlCenterRoute
    /// Session graph the home reader is built with. Stays eager so home data does not change.
    case homeSessionGraph
    /// Home resume, today ticket, city consent, and account bootstrap. Scheduled on appear.
    case homeFeedRequiredReads
    /// `QuestLiveActivityCenter.endOrphanedActivities`. Not home data.
    case orphanedLiveActivities
    /// `QuestPlanActivityCenter.start`. Not home data.
    case planActivityObservation
    /// `ExternalGameStore` registry read inside the approved-catalog refresh.
    case externalGameCatalog
    /// `NWPathMonitor` started by `PersonalLocationShareHost`. Not the home feed.
    case personalLocationMonitor
    /// Roam (MapKit), publish, club, and mine tab bodies.
    case nonHomeTabBodies
}

public enum ColdStartPhase: String, Sendable, Equatable {
    case critical
    case deferred
}

public struct ColdStartLaneWeight: Sendable, Equatable {
    public let lane: ColdStartLane
    public let phase: ColdStartPhase
    /// Main-thread milliseconds on an iPhone 12-class (A14) device.
    public let iphone12Milliseconds: Int
}

public struct ColdStartFirstFrameMeasurement: Sendable, Equatable {
    public let criticalMilliseconds: Int
    public let deferredMilliseconds: Int
    /// Virtual clock when the last critical lane finished. Deferred work starts here or later.
    public let frameAtMilliseconds: Int
    public let deferredStarts: [ColdStartLane: Int]
    public let withinBudget: Bool
    public let deferredAfterFrame: Bool
    public let requiredDataCritical: Bool
    /// Critical plus deferred is over the budget, so the split is load-bearing.
    public let foldedBackExceedsBudget: Bool

    public var keepsIPhone12ColdStart: Bool {
        withinBudget && deferredAfterFrame && requiredDataCritical && foldedBackExceedsBudget
    }
}

public enum ColdStartFirstFrameSplit {
    /// Time-to-first-frame budget for an iPhone 12-class device.
    public static let budgetMilliseconds = 1500

    /// Reads the first screen still performs on the appear turn. They stay critical.
    public static let firstScreenRequired: Set<ColdStartLane> = [.homeSessionGraph, .homeFeedRequiredReads]

    public static let lanes: [ColdStartLaneWeight] = [
        ColdStartLaneWeight(lane: .notificationDelegate, phase: .critical, iphone12Milliseconds: 15),
        ColdStartLaneWeight(lane: .controlCenterRoute, phase: .critical, iphone12Milliseconds: 5),
        ColdStartLaneWeight(lane: .homeSessionGraph, phase: .critical, iphone12Milliseconds: 640),
        ColdStartLaneWeight(lane: .homeFeedRequiredReads, phase: .critical, iphone12Milliseconds: 180),
        ColdStartLaneWeight(lane: .orphanedLiveActivities, phase: .deferred, iphone12Milliseconds: 280),
        ColdStartLaneWeight(lane: .planActivityObservation, phase: .deferred, iphone12Milliseconds: 240),
        ColdStartLaneWeight(lane: .externalGameCatalog, phase: .deferred, iphone12Milliseconds: 300),
        ColdStartLaneWeight(lane: .personalLocationMonitor, phase: .deferred, iphone12Milliseconds: 90),
        ColdStartLaneWeight(lane: .nonHomeTabBodies, phase: .deferred, iphone12Milliseconds: 700),
    ]

    /// Sums the class weights on a virtual clock. No device, no wall clock, no network.
    public static func measure(lanes: [ColdStartLaneWeight] = lanes) -> ColdStartFirstFrameMeasurement {
        var now = 0
        var critical = 0
        for lane in lanes where lane.phase == .critical {
            now += lane.iphone12Milliseconds
            critical += lane.iphone12Milliseconds
        }
        let frame = now
        var deferred = 0
        var starts: [ColdStartLane: Int] = [:]
        for lane in lanes where lane.phase == .deferred {
            starts[lane.lane] = now
            now += lane.iphone12Milliseconds
            deferred += lane.iphone12Milliseconds
        }
        let weightsLegal = lanes.allSatisfy { (1...budgetMilliseconds).contains($0.iphone12Milliseconds) }
        let unique = Set(lanes.map(\.lane)).count == lanes.count
        let requiredCritical = firstScreenRequired.allSatisfy { required in
            lanes.contains { $0.lane == required && $0.phase == .critical }
        }
        let afterFrame = !starts.isEmpty && starts.values.allSatisfy { $0 >= frame }
        return ColdStartFirstFrameMeasurement(
            criticalMilliseconds: critical,
            deferredMilliseconds: deferred,
            frameAtMilliseconds: frame,
            deferredStarts: starts,
            withinBudget: weightsLegal && unique && critical > 0 && critical <= budgetMilliseconds,
            deferredAfterFrame: afterFrame,
            requiredDataCritical: requiredCritical,
            foldedBackExceedsBudget: critical + deferred > budgetMilliseconds
        )
    }
}
