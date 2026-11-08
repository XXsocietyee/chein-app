import Foundation

/// Client-side contact-frequency limiter (W16.4). One contact per peer per window; a block ends contact at once.
/// The clock is injected; this type never reads the real time and never touches the network or storage.
public struct ContactFrequencyLimiter {
    public enum Decision: Equatable {
        case allowed
        case insideWindow(retryAfter: TimeInterval)
        case blocked
    }
    public let window: TimeInterval
    private let now: () -> Date
    private var lastContact: [Int64: Date] = [:]
    private var blockedPeers: Set<Int64> = []

    public init(window: TimeInterval, now: @escaping () -> Date) {
        self.window = max(0, window); self.now = now
    }

    /// Records the contact only when it is allowed.
    public mutating func attempt(peerID: Int64) -> Decision {
        guard !blockedPeers.contains(peerID) else { return .blocked }
        let current = now()
        if let last = lastContact[peerID] {
            let elapsed = current.timeIntervalSince(last)
            if elapsed >= 0, elapsed < window { return .insideWindow(retryAfter: window - elapsed) }
        }
        lastContact[peerID] = current
        return .allowed
    }

    /// A block ends contact immediately and forgets the previous contact time.
    public mutating func block(peerID: Int64) { blockedPeers.insert(peerID); lastContact[peerID] = nil }

    /// Unblocking only lifts the refusal; it does not grant a free contact beyond a fresh window.
    public mutating func unblock(peerID: Int64) { blockedPeers.remove(peerID) }
}
