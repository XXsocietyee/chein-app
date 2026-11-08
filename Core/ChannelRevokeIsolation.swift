import Foundation

public struct ChannelPageLease: Equatable, Sendable {
    public let channelID: Int
    public let conversationID: Int
    public let generation: UInt64
    public let identity: ChannelAccount4Identity
    public let capabilities: Set<ChannelCapability>
    public let consentedRulesVersion: Int?
    public init(channelID: Int, conversationID: Int, generation: UInt64, identity: ChannelAccount4Identity,
                capabilities: Set<ChannelCapability>, consentedRulesVersion: Int?) {
        self.channelID = channelID
        self.conversationID = conversationID
        self.generation = generation
        self.identity = identity
        self.capabilities = capabilities
        self.consentedRulesVersion = consentedRulesVersion
    }
}

public enum ChannelIsolatedAction: Equatable, Sendable {
    case channelRead, channelWrite, governance, lateJoin, historicalVoteRead, historicalVoteWrite, appeal
}

public struct ChannelIsolatedRequest: Equatable, Sendable {
    public let lease: ChannelPageLease
    public let action: ChannelIsolatedAction
    public init(lease: ChannelPageLease, action: ChannelIsolatedAction) {
        self.lease = lease
        self.action = action
    }
}

public enum ChannelIsolatedAdmission: Equatable, Sendable {
    case allowed
    case isolated
}

/// After leave/ban/revoke, old pages and late requests isolate. Left-group
/// historical votes stay read-only per the original GroupPoll exception.
public struct ChannelRevokeIsolation: Equatable, Sendable {
    public let channelID: Int
    public let identity: ChannelAccount4Identity
    public let revokedAtGeneration: UInt64?
    public let reason: ChannelRevokeReason?
    public let phase: ChannelGovernancePhase
    public init(channelID: Int, identity: ChannelAccount4Identity, revokedAtGeneration: UInt64?,
                reason: ChannelRevokeReason?, phase: ChannelGovernancePhase) {
        self.channelID = channelID
        self.identity = identity
        self.revokedAtGeneration = revokedAtGeneration
        self.reason = reason
        self.phase = phase
    }

    public func admit(_ request: ChannelIsolatedRequest) throws -> ChannelIsolatedAdmission {
        let lease = request.lease
        guard lease.channelID == channelID, lease.identity == identity else {
            throw ChannelAuthorizationError.account4Mismatch
        }
        if request.action == .historicalVoteRead {
            return try historicalVoteRead(lease: lease)
        }
        if request.action == .historicalVoteWrite {
            if reason == nil { return .allowed }
            throw ChannelAuthorizationError.historicalVoteWriteDenied
        }
        if request.action == .appeal {
            guard reason == .ban, phase == .banned || phase == .appealing else {
                throw ChannelAuthorizationError.revoked
            }
            return .allowed
        }
        guard let revokedAtGeneration else { return .allowed }
        if lease.generation <= revokedAtGeneration || request.action == .lateJoin {
            throw ChannelAuthorizationError.isolatedLateRequest
        }
        throw ChannelAuthorizationError.revoked
    }

    /// Existing GroupPoll result reads remain available to historical audience.
    public func historicalVoteAccess(poll: GroupPoll, membershipActive: Bool) throws -> ChannelIsolatedAdmission {
        guard poll.id > 0, poll.conversationId > 0 else { throw ChannelAuthorizationError.invalidCatalog }
        if membershipActive { return .allowed }
        return .allowed
    }

    private func historicalVoteRead(lease: ChannelPageLease) throws -> ChannelIsolatedAdmission {
        guard lease.conversationID > 0 else { throw ChannelAuthorizationError.invalidCatalog }
        if reason == nil { return .allowed }
        return .allowed
    }
}

/// WP-13 Core hook only: WP-11 owns the concrete channel cache keys. The App row does not use this yet.
public protocol ChannelRevokePurgeHook: AnyObject {
    /// Called once per revoke so the owner of channel caches can drop them.
    func purgeChannelCaches(channelID: Int, identity: ChannelAccount4Identity,
                            reason: ChannelRevokeReason, revokedAtGeneration: UInt64)
}

/// Delivers a revoke fact to a purge hook at most once per (channel, identity, generation).
public final class ChannelRevokePurgeDispatcher: @unchecked Sendable {
    private struct Key: Hashable {
        let channelID: Int
        let identity: ChannelAccount4Identity
        let generation: UInt64
    }
    private let lock = NSLock()
    private var delivered = Set<Key>()
    public init() {}

    /// Returns true when the hook ran. A non-revoked isolation or a repeated revoke does nothing.
    @discardableResult
    public func dispatch(_ isolation: ChannelRevokeIsolation, to hook: ChannelRevokePurgeHook) -> Bool {
        guard let reason = isolation.reason, let generation = isolation.revokedAtGeneration else { return false }
        let key = Key(channelID: isolation.channelID, identity: isolation.identity, generation: generation)
        lock.lock()
        let inserted = delivered.insert(key).inserted
        lock.unlock()
        guard inserted else { return false }
        hook.purgeChannelCaches(channelID: isolation.channelID, identity: isolation.identity,
                                reason: reason, revokedAtGeneration: generation)
        return true
    }
}

public extension ChannelRevokeIsolation {
    /// Write votes require current membership. After revoke the original exception
    /// keeps result reads and rejects new votes without wiping history.
    static func voteWriteAllowed(poll: GroupPoll, membershipActive: Bool) -> Bool {
        membershipActive && poll.isOpen() && poll.myOptionId == nil
    }
}
