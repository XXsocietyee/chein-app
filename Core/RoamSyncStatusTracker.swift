import Foundation

/// Exact port of `chengyinhub-xcx/utils/roam-sync-status.js`.
/// Shows the offline banner only after `failThreshold` consecutive transport failures (`netFail`)
/// or when system connectivity is down; ignores HTTP/business conclusions so API validation errors
/// do not falsely claim offline state.
public struct RoamSyncStatusTracker: Equatable, Sendable {
    public static let failThreshold = 2
    public static let offlineKey = "roam.sync.offline"

    public private(set) var consecutiveFailures: Int = 0
    public private(set) var systemConnected: Bool = true
    public private(set) var isOffline: Bool = false

    public init(systemConnected: Bool = true) {
        self.systemConnected = systemConnected
        self.isOffline = !systemConnected
    }

    /// Updates state from a completed roam request (`netFail == true` only for transport errors).
    @discardableResult
    public mutating func recordOutcome(netFail: Bool, code: Int? = nil) -> Bool {
        if netFail {
            consecutiveFailures += 1
            if consecutiveFailures >= Self.failThreshold || !systemConnected {
                isOffline = true
            }
            return isOffline
        }
        if code == 200 {
            consecutiveFailures = 0
            if isOffline && systemConnected {
                isOffline = false
            }
        }
        return isOffline
    }

    /// Updates state from `NWPathMonitor` / system connectivity changes.
    @discardableResult
    public mutating func recordSystemConnectivity(isConnected: Bool) -> Bool {
        systemConnected = isConnected
        if !isConnected {
            isOffline = true
        } else {
            consecutiveFailures = 0
            isOffline = false
        }
        return isOffline
    }

    public mutating func reset() {
        consecutiveFailures = 0
        systemConnected = true
        isOffline = false
    }
}
