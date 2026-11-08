import Foundation

/// Pure client-side send gate for a direct message (DEC-03).
/// An existing non-friend session stays sendable; it is refused only when blocked, banned or self-rejected.
/// A brand-new stranger DM is never opened by this gate. No network, no storage, no clock.
public struct DirectMessageSendGate: Equatable, Sendable {
    public struct Facts: Equatable, Sendable {
        public var hasExistingSession: Bool
        public var isFriend: Bool
        /// Either direction of a block between the two members.
        public var blocked: Bool
        public var banned: Bool
        /// The viewer's own DM-reject preference for this conversation.
        public var selfRejected: Bool
        public init(hasExistingSession: Bool, isFriend: Bool = false, blocked: Bool = false, banned: Bool = false, selfRejected: Bool = false) {
            self.hasExistingSession = hasExistingSession; self.isFriend = isFriend
            self.blocked = blocked; self.banned = banned; self.selfRejected = selfRejected
        }
    }
    public enum Refusal: Equatable, Sendable { case banned, blocked, selfRejected, noSession }
    public enum Decision: Equatable, Sendable { case allowed, refused(Refusal) }

    public init() {}

    /// Priority: banned > blocked > self-rejected > no session. Friendship never overrides a refusal.
    public func decide(_ facts: Facts) -> Decision {
        if facts.banned { return .refused(.banned) }
        if facts.blocked { return .refused(.blocked) }
        if facts.selfRejected { return .refused(.selfRejected) }
        guard facts.hasExistingSession || facts.isFriend else { return .refused(.noSession) }
        return .allowed
    }
}
