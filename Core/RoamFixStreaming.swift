import Foundation

/// Roam fog spec stage 4 (core only). Foreground location stream boundary: WGS-84 fixes in, the caller projects once.
/// No concrete provider here and no background modes; `liveRevealEnabled` is on since gap #24 (1128 plan).
public struct RoamFixStreamPolicy: Equatable {
    public let distanceFilterMeters: Double
    public let desiredAccuracyMeters: Double
    public init(distanceFilterMeters: Double, desiredAccuracyMeters: Double) {
        self.distanceFilterMeters = distanceFilterMeters; self.desiredAccuracyMeters = desiredAccuracyMeters
    }
    public static let walking = RoamFixStreamPolicy(distanceFilterMeters: 25, desiredAccuracyMeters: 10)
    public static let thermalSerious = RoamFixStreamPolicy(distanceFilterMeters: 60, desiredAccuracyMeters: 100)
}

@MainActor public protocol RoamFixStreaming: AnyObject {
    var authorization: WalkingLocationAuthorization { get }
    func fixes(policy: RoamFixStreamPolicy) -> AsyncThrowingStream<RoamDeviceFix, Error>
    func stop()
}

/// Gate for the live fix stream. Every switch is off; the UI shows the blocked reason instead of a working Start.
public enum RoamFixStreamGate {
    public enum Decision: Equatable { case allowed, blocked(Reason) }
    public enum Reason: Equatable { case featureOff, permissionMissing, permissionNotDetermined, appInactive }

    public static func decide(authorization: WalkingLocationAuthorization, appActive: Bool,
                              liveRevealEnabled: Bool = PersonalFogFeature.liveRevealEnabled) -> Decision {
        guard liveRevealEnabled else { return .blocked(.featureOff) }
        guard appActive else { return .blocked(.appInactive) }
        switch authorization {
        case .authorized: return .allowed
        case .denied: return .blocked(.permissionMissing)
        case .notDetermined: return .blocked(.permissionNotDetermined)
        }
    }
}
