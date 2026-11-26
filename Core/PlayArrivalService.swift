import Foundation
import Observation

/// One located arrival. Station taps after the run has started carry no coordinates
/// and use `PlayCompletionEvidence.stationArrival` on the same `/api/play/arrive` channel.
/// This is not `PlayArrivalReading`: that name is the durable receipt in `PlayCommandRefusal`.
public struct PlayArrivalFix: Equatable {
    public let longitude: Double
    public let latitude: Double
    public let accuracyMeters: Double
    public let measuredAt: Date
    public init(gcj02 fix: RoamDeviceFix) throws {
        guard fix.datum == .gcj02, fix.coordinate.longitude.isFinite, fix.coordinate.latitude.isFinite,
              abs(fix.coordinate.longitude) <= 180, abs(fix.coordinate.latitude) <= 90,
              fix.accuracyMeters.isFinite, fix.accuracyMeters >= 0 else { throw APIError.invalidRequest }
        longitude = fix.coordinate.longitude
        latitude = fix.coordinate.latitude
        accuracyMeters = fix.accuracyMeters
        measuredAt = fix.measuredAt
    }
}

/// Machine-readable arrival refusal (`errorCode`), from the server or the local precheck.
public struct PlayArrivalRejection: Equatable {
    public enum Reason: Equatable {
        case tooFar, accuracyLow, locationMissing, scanRequired
        /// A settled arrival refusal whose code is not one of the four policy codes.
        case server(String)
        public var localizationKey: String {
            switch self {
            case .tooFar: return "playArrival.rejected.ARRIVE_TOO_FAR"
            case .accuracyLow: return "playArrival.rejected.ARRIVE_ACCURACY_LOW"
            case .locationMissing: return "playArrival.rejected.ARRIVE_LOCATION_MISSING"
            case .scanRequired: return "playArrival.rejected.VISIT_SCAN_REQUIRED"
            case .server: return "playArrival.rejected"
            }
        }
    }
    public let reason: Reason
    /// Rounded to 10 m. Present for a free-exploration TOO_FAR or a local precheck.
    public let distanceMeters: Int?
    /// Verbatim server text, never instructions or navigation.
    public let message: String?
    /// True when no request was sent because the shared policy already failed.
    public let checkedLocally: Bool
    public init(local reason: Reason, distance: Double?) {
        self.reason = reason
        distanceMeters = distance.flatMap(PlayArrivalPolicy.roundedDistanceMeters)
        message = nil
        checkedLocally = true
    }
    public init(server reason: Reason, message: String?, distanceMeters: Int?) {
        self.reason = reason
        self.distanceMeters = distanceMeters
        self.message = message
        checkedLocally = false
    }
    /// The four policy codes are refusals checked before any arrival is recorded.
    /// The existing completion journal is what clears them; this service does not open a second path.
    public var provesNoCommit: Bool {
        switch reason {
        case .tooFar, .accuracyLow, .locationMissing, .scanRequired: return true
        case .server: return false
        }
    }
}

/// Projects a one-shot fix for arrival without editing `RuntimeLocationProjection`.
/// That helper rejects accuracy above 100 m. Arrival policy allows up to 200 m, so a
/// fix the provider already marked GCJ-02 (and no older than 30 s) is used as-is.
/// A WGS-84 fix in the 100–200 m band cannot be projected here and is a local accuracy failure.
enum PlayArrivalProjection {
    static func gcj02(_ fix: RoamDeviceFix, now: Date) throws -> RoamDeviceFix {
        guard now >= fix.measuredAt, now.timeIntervalSince(fix.measuredAt) <= 30 else { throw APIError.invalidRequest }
        if fix.datum == .gcj02 {
            guard fix.accuracyMeters.isFinite, fix.accuracyMeters >= 0,
                  fix.accuracyMeters <= PlayArrivalPolicy.startMaxAccuracyMeters else { throw APIError.invalidRequest }
            return fix
        }
        return try RuntimeLocationProjection.gcj02(fix, now: now)
    }

    static func isUnprojectableAccuracy(_ fix: RoamDeviceFix) -> Bool {
        fix.datum != .gcj02 && fix.accuracyMeters > 100 && fix.accuracyMeters <= PlayArrivalPolicy.startMaxAccuracyMeters
    }
}

/// 「我已到达」 and free-exploration place visits. Location is read once, prechecked with
/// `PlayArrivalPolicy`, then written through the coordinator's existing `review` + `submit`
/// completion channel (`/api/play/arrive`). This type does not open a second HTTP client.
/// An unknown result is re-read, never re-sent.
@available(macOS 14.0, *)
@MainActor @Observable public final class PlayArrivalService {
    public enum Kind: Equatable { case stationTap, start, freeVisit }
    public enum Phase: Equatable {
        case idle, locating, submitting, succeeded, rejected(PlayArrivalRejection), unknown, unavailable, locationUnavailable
    }
    public private(set) var phase: Phase = .idle
    public private(set) var nodeID: Int?
    private let runtime: PlayExperienceCoordinator
    private let location: (any RoamDeviceLocationProviding)?
    private let now: () -> Date
    @ObservationIgnored private var generation: UInt64 = 0

    public init(runtime: PlayExperienceCoordinator, location: (any RoamDeviceLocationProviding)?, now: @escaping () -> Date = Date.init) {
        self.runtime = runtime
        self.location = location
        self.now = now
    }

    public var isBusy: Bool { phase == .locating || phase == .submitting }

    /// Which arrival the node offers now; nil hides the control. Never infers a write grant.
    public func offer(for nodeID: Int) -> Kind? {
        guard let snapshot = runtime.snapshot, snapshot.availability == .active,
              let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }),
              !snapshot.isDone(node), !snapshot.isLocked(node), node.done == false else { return nil }
        switch runtime.gameplayMode {
        case .cityOrientation?:
            let task = PlayNodeTask.resolve(mode: snapshot.result.mode, node: node)
            let needsArrival = task == .arrive || (task == .answer && node.needGPS == true && node.needScan != true && node.arrived != true)
            guard needsArrival else { return nil }
            return Self.runStarted(snapshot) ? .stationTap : .start
        case .freeExploration?:
            guard snapshot.isStoryLocked(node), node.visitCheck != .scan, node.visitCheck != .online,
                  FreeExplorationPresentation.evidenceTask(for: node, in: snapshot) == .merchantScan else { return nil }
            return .freeVisit
        case nil: return nil
        }
    }

    /// The server checks the start geofence only while the run has no progress yet.
    static func runStarted(_ snapshot: PlaySnapshot) -> Bool {
        if let done = snapshot.displayedDoneCount, done > 0 { return true }
        return snapshot.visibleNodes.contains { snapshot.isDone($0) || $0.arrived == true }
    }

    /// START-r11-1: alternate stations the 换个方式开局 sheet offers for this start, or nil when it is not offered.
    /// MP pages/play/utils/run-start-mode.js:51-54, :28-31 (`startChoices`: alt stations with a name, then 桌面完成).
    public func startChoices(for nodeID: Int) -> [PlayAltStation]? {
        guard offer(for: nodeID) == .start, runtime.runStartModesAvailable(nodeID: nodeID),
              let snapshot = runtime.snapshot else { return nil }
        return snapshot.result.altStations.filter { !($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// `start` is the 换个方式开局 choice: DESK sends no location (MP `_deskStart` skips the fix, index.js:6254);
    /// ALT sends the fix plus `altStationId`, and the server checks the 300 m radius around that station.
    public func arrive(nodeID: Int, context: PlayInteractionContext?, start: PlayRunStartRequest? = nil) async {
        guard !isBusy, phase != .unknown, let kind = offer(for: nodeID) else { return }
        if start != nil, kind != .start { return }
        generation &+= 1
        let request = generation
        self.nodeID = nodeID
        guard runtime.canSubmitArrival else { phase = .unavailable; return }
        let evidence: PlayCompletionEvidence
        if kind == .stationTap || start?.mode == .desk {
            evidence = .stationArrival
        } else {
            guard let located = await locatedFix(kind: kind, nodeID: nodeID, request: request, precheckDistance: start == nil) else { return }
            evidence = .location(longitude: located.longitude, latitude: located.latitude, coordinateSystem: "GCJ02",
                                  accuracyMeters: located.accuracyMeters, measuredAt: located.measuredAt)
        }
        guard request == generation, offer(for: nodeID) == kind else { phase = .idle; return }
        let review: PlayCompletionReview
        do { review = try runtime.review(nodeID: nodeID, evidence: evidence, context: context, start: start) }
        catch { phase = .unavailable; return }
        phase = .submitting
        await runtime.submit(review)
        if runtime.phase == .reviewing { runtime.cancelReview() }
        guard request == generation else { return }
        if let failure = runtime.arrivalFailure, failure.nodeID == nodeID {
            phase = .rejected(Self.rejection(from: failure))
            return
        }
        if runtime.unresolved || runtime.phase == .unknown || runtime.phase == .failed {
            phase = .unknown
            await reread()
            return
        }
        if let snapshot = runtime.snapshot, let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }) {
            let landed = snapshot.result.mode == 2 ? snapshot.isVisited(node) || node.arrived == true : snapshot.isDone(node) || node.arrived == true
            phase = landed ? .succeeded : .unavailable
        } else {
            phase = .unavailable
        }
    }

    /// Unknown outcome: read authoritative progress again. Never re-sends the arrival.
    public func reread() async {
        guard phase == .unknown, let nodeID else { return }
        let request = generation
        await runtime.load()
        guard request == generation, !runtime.unresolved else { return }
        guard let snapshot = runtime.snapshot, let node = snapshot.result.nodes.first(where: { $0.id == nodeID }) else { phase = .idle; return }
        let landed = snapshot.result.mode == 2 ? snapshot.isVisited(node) || node.arrived == true : snapshot.isDone(node) || node.arrived == true
        phase = landed ? .succeeded : .idle
    }

    public func cancel() {
        generation &+= 1
        if phase == .locating { location?.stop() }
        if phase != .unknown { phase = .idle }
    }

    /// `precheckDistance` is false for an ALT start: the radius is around the alt station and the server judges it.
    private func locatedFix(kind: Kind, nodeID: Int, request: UInt64, precheckDistance: Bool = true) async -> PlayArrivalFix? {
        guard let location else { phase = .locationUnavailable; return nil }
        phase = .locating
        let fix: RoamDeviceFix
        do {
            let raw = try await location.currentFix()
            if PlayArrivalProjection.isUnprojectableAccuracy(raw) {
                phase = .rejected(.init(local: .accuracyLow, distance: nil))
                return nil
            }
            fix = try PlayArrivalProjection.gcj02(raw, now: now())
        } catch {
            if request == generation { phase = .locationUnavailable }
            return nil
        }
        guard request == generation else { return nil }
        guard offer(for: nodeID) == kind, let node = runtime.snapshot?.visibleNodes.first(where: { $0.id == nodeID }) else {
            phase = .idle
            return nil
        }
        if precheckDistance, let latitude = node.latitude, let longitude = node.longitude {
            let distance = PlayArrivalPolicy.distanceMeters(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                                                            toLatitude: latitude, toLongitude: longitude)
            let verdict = kind == .start
                ? PlayArrivalPolicy.start(distanceMeters: distance, accuracyMeters: fix.accuracyMeters)
                : PlayArrivalPolicy.visit(distanceMeters: distance, accuracyMeters: fix.accuracyMeters, configuredRadiusMeters: node.visitRadius)
            switch verdict {
            case .pass: break
            case .tooFar: phase = .rejected(.init(local: .tooFar, distance: distance)); return nil
            case .accuracyLow: phase = .rejected(.init(local: .accuracyLow, distance: nil)); return nil
            }
        }
        do { return try PlayArrivalFix(gcj02: fix) }
        catch { phase = .locationUnavailable; return nil }
    }

    static func rejection(from failure: PlayArrivalFailure) -> PlayArrivalRejection {
        let reason: PlayArrivalRejection.Reason
        switch failure.reason {
        case .tooFar: reason = .tooFar
        case .accuracyLow: reason = .accuracyLow
        case .locationMissing, .accuracyMissing, .locationInvalid, .accuracyInvalid: reason = .locationMissing
        case .methodUnavailable: reason = .scanRequired
        default: reason = .server(failure.reason?.rawValue ?? "UNKNOWN")
        }
        return PlayArrivalRejection(server: reason, message: failure.message, distanceMeters: nil)
    }
}
