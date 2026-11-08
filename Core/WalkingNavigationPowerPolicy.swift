import Foundation

/// Pure power/connectivity policy for walking guidance. It only chooses how often a foreground
/// fix is polled and what is retained; it never relaxes fix accuracy, route validation or
/// authority expiry, and it holds no clock, location or network dependency.
public struct WalkingNavigationPowerPolicy: Equatable, Sendable {
    public struct Condition: Equatable, Sendable {
        public let lowPower: Bool
        public let offline: Bool
        public init(lowPower: Bool = false, offline: Bool = false) { self.lowPower = lowPower; self.offline = offline }
        public var degraded: Bool { lowPower || offline }
    }
    public let normalInterval: TimeInterval
    public let degradedInterval: TimeInterval
    public init(normalInterval: TimeInterval = 3, degradedInterval: TimeInterval = 10) {
        let normal = normalInterval.isFinite && (1...60).contains(normalInterval) ? normalInterval : 3
        let degraded = degradedInterval.isFinite && (1...60).contains(degradedInterval) ? degradedInterval : 10
        self.normalInterval = normal; self.degradedInterval = max(normal, degraded)
    }
    public func fixInterval(_ condition: Condition) -> TimeInterval { condition.degraded ? degradedInterval : normalInterval }
    /// The resume reference (no coordinates) is kept under every condition.
    public func keepsCheckpoint(_ condition: Condition) -> Bool { true }
    /// Offline never discards the last validated route.
    public func keepsCachedRoute(_ condition: Condition) -> Bool { true }
    /// A replacement route needs the network.
    public func allowsReplan(_ condition: Condition) -> Bool { !condition.offline }
    public func showsWeakState(_ condition: Condition) -> Bool { condition.offline }
}
