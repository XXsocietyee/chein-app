import Foundation
import Observation

/// The CITY board capability for one signed-in viewer of the shipped China composition.
/// Minted only by `ReviewedProductionGateLeases.cityGame(_:)`: the owner approved the
/// non-money player writes (2026-11-12), and every CITY write spends member game points
/// (`ums_member.point`) charged to the confirming member, never money (backend
/// `docs/delivery/app-gaps-a/MAPPING.md`). It holds the read, rules, participation and
/// fairness approvals the existing CITY clients ask for, all bound to one region.
@MainActor final class CityGameCapabilityLease {
    static let lifetime: TimeInterval = 3600
    let lease: CityGameProductionLease
    let context: RuntimeDependencyContext
    let readApproval: CityPlayerReadApproval
    let rulesApproval: CityPlayerRulesApproval
    let issuedAt = Date()
    private var participation: [UInt64: CityParticipationRuntimeGrants] = [:]
    private let issuer = CityParticipationGrantIssuer()
    private var fairness: [String: CityFairnessReadApproval] = [:]

    init?(context: RuntimeDependencyContext, lease: CityGameProductionLease) {
        let expires = Date().addingTimeInterval(Self.lifetime)
        guard context.market == .china, context.role == context.session.role, ["player", "club"].contains(context.role),
              context.baseURL.host?.lowercased() == lease.host,
              let read = try? CityPlayerReadApproval(context: context, regionID: lease.regionID, expiresAt: expires),
              let rules = try? CityPlayerRulesApproval(context: context, regionID: lease.regionID, expiresAt: expires) else { return nil }
        self.context = context; self.lease = lease; readApproval = read; rulesApproval = rules
    }

    var capabilities: ReformWorldCapabilities { .cityGame(lease) }

    func matches(_ live: RuntimeDependencyContext) -> Bool {
        live.session == context.session && readApproval.matches(live) && rulesApproval.matches(live)
    }

    func revoke() {
        readApproval.revoke(); rulesApproval.revoke()
        participation.values.forEach { $0.revoke() }; participation.removeAll()
        fairness.values.forEach { $0.revoke() }; fairness.removeAll()
        issuer.revokeAll()
    }

    /// One grant collection per viewer revision; the scoped transport compares it by identity.
    func participationGrants(revision: UInt64) -> CityParticipationRuntimeGrants? {
        if let existing = participation[revision], !existing.isRevoked { return existing }
        let issuer = issuer
        guard let grants = try? CityParticipationRuntimeGrants(context: context, revision: revision, regionID: lease.regionID,
                expiresAt: issuedAt.addingTimeInterval(Self.lifetime),
                state: { issuer.state($0) },
                invitation: { issuer.invitation($0, region: $1, code: $2) },
                command: { issuer.command($0) },
                receipt: { issuer.receipt($0) },
                approve: { issuer.approve($0) }) else { return nil }
        issuer.scope = grants.scope
        participation[revision] = grants
        return grants
    }

    /// Fairness reads for the board the player is looking at (`rulesVersion` is the board's rule version).
    func fairnessApproval(_ scope: CityFairnessScope) -> CityFairnessReadApproval? {
        guard scope.regionID == lease.regionID else { return nil }
        let key = [scope.boardID, scope.seasonID, scope.rulesVersion].joined(separator: "|")
        if let existing = fairness[key], existing.matches(context) { return existing }
        guard let approval = try? CityFairnessReadApproval(context: context, scope: scope,
                expiresAt: issuedAt.addingTimeInterval(Self.lifetime)) else { return nil }
        fairness[key] = approval
        return approval
    }
}

/// Issues the exact participation grants the scoped transport checks by identity. A command
/// grant exists only after the player confirmed that exact command in the form.
@MainActor final class CityParticipationGrantIssuer {
    var scope: CityParticipationCommandScope?
    private var stateGrant: CityParticipationReadGrant?
    private var invitations: [String: CityParticipationInvitationGrant] = [:]
    private var receipts: [String: CityOriginalReceiptReadGrant] = [:]
    private var commandGrant: CityParticipationCommandGrant?

    func state(_ requested: CityParticipationReadScope) -> CityParticipationReadGrant? {
        if let stateGrant, stateGrant.scope == requested, !stateGrant.isRevoked { return stateGrant }
        let grant = CityParticipationReadGrant(scope: requested)
        stateGrant = grant
        return grant
    }

    func invitation(_ requested: CityParticipationCommandScope, region: String, code: String) -> CityParticipationInvitationGrant? {
        guard requested == scope else { return nil }
        if let existing = invitations[code], existing.scope == requested, existing.regionID == region, !existing.isRevoked { return existing }
        guard invitations.count < 16 else { return nil }
        let grant = CityParticipationInvitationGrant(scope: requested, regionID: region, code: code)
        invitations[code] = grant
        return grant
    }

    func receipt(_ reference: CityOriginalReceiptReference) -> CityOriginalReceiptReadGrant? {
        if let existing = receipts[reference.requestID], existing.reference == reference, !existing.isRevoked { return existing }
        let grant = CityOriginalReceiptReadGrant(reference: reference)
        receipts[reference.requestID] = grant
        return grant
    }

    func command(_ requested: CityParticipationCommandScope) -> CityParticipationCommandGrant? {
        guard let commandGrant, commandGrant.scope == requested, !commandGrant.isRevoked else { return nil }
        return commandGrant
    }

    /// The form's confirm button: the player approves this exact command, nothing else.
    func approve(_ command: CityParticipationCommand) -> Bool {
        guard let scope, let grant = try? CityParticipationCommandGrant(scope: scope, command: command) else { return false }
        commandGrant?.revoke()
        commandGrant = grant
        return true
    }

    func revokeAll() {
        stateGrant?.revoke(); stateGrant = nil
        invitations.values.forEach { $0.revoke() }; invitations.removeAll()
        receipts.values.forEach { $0.revoke() }; receipts.removeAll()
        commandGrant?.revoke(); commandGrant = nil
    }
}

extension ReviewedProductionGateLeases {
    /// The build's CITY region. Empty (the default in Config/Base.xcconfig) means no CITY board.
    static var cityGameRegion: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "QuestifyCityGameRegion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Lease for the shipped China production host only.
    static func cityGameLease(context: RuntimeDependencyContext, region: String?) -> CityGameProductionLease? {
        guard context.market == .china, let region,
              context.baseURL.absoluteString == ReviewedMarketLaunch.chinaProductionBaseURL,
              let host = context.baseURL.host else { return nil }
        return CityGameProductionLease(host: host, regionID: region)
    }
}

/// The session's current CITY board coordinator, observable so the play surface and the
/// fairness entry follow it without a session publish during a render.
@MainActor @Observable final class CityGameHolder {
    var model: CityGameCoordinator?
}
