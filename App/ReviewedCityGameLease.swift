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
    /// The board coordinator and play-surface read built under this lease; dropped with it.
    let holder = CityGameHolder()
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
        holder.model?.invalidate(); holder.model = nil; holder.playRead = nil
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
    nonisolated static var cityGameRegion: String? {
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
    @ObservationIgnored var playRead: (identity: String, reader: CityPlayerReader)?
}

extension AppCompositionRoot {
    /// The CITY board capability for this viewer; nil hides the board, its rules, team and fairness entries.
    func cityGameLease(_ context: RuntimeDependencyContext) -> CityGameCapabilityLease? {
        guard reviewed?.playerWritesEnabled == true, reviewed?.regional.market == .china else { return nil }
        return productionGateLeases.cityGame(context)
    }

    /// Records the owner-approved player-writes switch; with it on, the CITY lease also issues the
    /// board rules read and the team participation grants (the board read joins `cityPlayerReadApproval`).
    mutating func notePlayerWrites(_ granted: Bool) {
        productionGateLeases.notePlayerWrites(granted)
        guard granted else { return }
        let gates = productionGateLeases
        cityPlayerRulesApproval = { [gates] context in gates.cityGame(context)?.rulesApproval }
        cityParticipationRuntimeGrants = { [gates] context, revision in gates.cityGame(context)?.participationGrants(revision: revision) }
    }
}

// MARK: - AppSession CITY board factories

extension AppSession {
    private var cityGameHolder: CityGameHolder? {
        currentRuntimeDependencyContext.flatMap { composition.cityGameLease($0) }?.holder
    }
    private var retainedCityGame: CityGameCoordinator? {
        get { cityGameHolder?.model }
        set { cityGameHolder?.model = newValue }
    }
    private var cityGamePlayRead: (identity: String, reader: CityPlayerReader)? {
        get { cityGameHolder?.playRead }
        set { cityGameHolder?.playRead = newValue }
    }
    /// The CITY board coordinator for one real read. Nil without the CITY lease, for another
    /// region, or when a joined member's recovery journal cannot be opened (no write without it).
    func makeCityGameCoordinator(read: CityReadSnapshot) -> CityGameCoordinator? {
        guard let context = currentRuntimeDependencyContext, let lease = composition.cityGameLease(context), lease.matches(context),
              read.board.regionId == lease.lease.regionID, let api = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        if let existing = retainedCityGame, existing.read == read, existing.phase != .invalidated { return existing }
        retainedCityGame?.invalidate(); retainedCityGame = nil
        let viewer = cityParticipationRuntimeRevision
        let current: () -> Bool = { [weak self, weak lease] in
            guard let self, let lease, self.cityParticipationRuntimeRevision == viewer, let live = self.currentRuntimeDependencyContext,
                  ContentDraftContextFence.matches(context, live), context.session == live.session,
                  self.composition.cityGameLease(live) === lease, lease.matches(live) else { return false }
            return true
        }
        var journal: CityActionRecoveryJournal?
        if read.membership == .joined {
            guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                  let opened = try? CityActionRecoveryJournal(directory: root.appendingPathComponent("CityGameActions", isDirectory: true),
                                                             namespace: context.session.namespace) else { return nil }
            journal = opened
        }
        guard let service = try? CityGameHTTPService(configuration: api, token: context.session.token, lease: lease.lease,
                transport: composition.makeTransport(), isCurrent: current, onUnauthorized: { [weak self] in
                    guard let self, current() else { return }
                    self.expireIfMatching(error: APIError.unauthorized, stamp: context.session.epoch, credential: context.session.token)
                }) else { return nil }
        let model = CityGameCoordinator(read: read, service: service, capabilities: lease.capabilities,
                                        memberId: String(context.session.accountID), isCurrent: current, journal: journal)
        retainedCityGame = model
        return model
    }
    /// Factory for the CITY entry surface; nil keeps the board section hidden.
    var cityGameFactory: (@MainActor (CityReadSnapshot) -> CityGameCoordinator?)? {
        guard let context = currentRuntimeDependencyContext, composition.cityGameLease(context) != nil else { return nil }
        return { [weak self] read in self?.makeCityGameCoordinator(read: read) }
    }
    /// Starts the CITY read the play surface's board is built on. Call from a view `.task`.
    func loadCityGamePlayRead() async {
        guard let context = currentRuntimeDependencyContext, composition.cityGameLease(context) != nil else { cityGamePlayRead = nil; return }
        let identity = cityPlayerReadIdentity
        if cityGamePlayRead?.identity != identity { cityGamePlayRead = (identity, makeCityPlayerReader()) }
        guard let reader = cityGamePlayRead?.reader else { return }
        if case .available = reader.state {} else { await reader.load() }
        guard cityGamePlayRead?.reader === reader, case .available(let read) = reader.state,
              let model = makeCityGameCoordinator(read: read), model.phase == .idle || model.phase == .unknown else { return }
        await model.load()
    }
    /// The board for `PlayExperienceView.cityGameModel`, built on the real CITY read. Nil hides it.
    var playCityGame: CityGameCoordinator? {
        guard let host = cityGamePlayRead, host.identity == cityPlayerReadIdentity,
              case .available(let read) = host.reader.state,
              let model = cityGameHolder?.model, model.read == read, model.phase != .invalidated else { return nil }
        return model
    }
    /// Fairness for the board the player last loaded; the scope uses the board's own rule version.
    func makeCityFairnessReaderFactory() -> (@MainActor () -> CityFairnessReader)? {
        guard let context = currentRuntimeDependencyContext, let lease = composition.cityGameLease(context),
              let game = retainedCityGame, let snapshot = game.snapshot,
              let scope = try? CityFairnessScope(boardID: snapshot.boardId, regionID: game.read.board.regionId,
                                                 seasonID: snapshot.seasonId, rulesVersion: snapshot.rules.ruleVersion),
              let approval = lease.fairnessApproval(scope) else { return nil }
        let viewer = cityParticipationRuntimeRevision
        let current: () -> Bool = { [weak self, weak lease, weak approval] in
            guard let self, let lease, let approval, self.cityParticipationRuntimeRevision == viewer,
                  let live = self.currentRuntimeDependencyContext, self.composition.cityGameLease(live) === lease,
                  approval.matches(live) else { return false }
            return true
        }
        let transport = composition.makeTransport()
        return { [weak self] in
            CityFairnessReader(approval: approval, transport: transport, isCurrent: current, onUnauthorized: {
                guard let self, current() else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: context.session.epoch, credential: context.session.token)
            })
        }
    }
    /// Standalone unified CITY HTTP client under the reviewed CITY lease (for `/api/city-game/dice/{roll,audit}`).
    func makeUnifiedCityGameHTTPService() -> CityGameHTTPService? {
        guard let context = currentRuntimeDependencyContext, let lease = composition.cityGameLease(context), lease.matches(context),
              let api = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let viewer = cityParticipationRuntimeRevision
        let current: () -> Bool = { [weak self, weak lease] in
            guard let self, let lease, self.cityParticipationRuntimeRevision == viewer, let live = self.currentRuntimeDependencyContext,
                  ContentDraftContextFence.matches(context, live), context.session == live.session,
                  self.composition.cityGameLease(live) === lease, lease.matches(live) else { return false }
            return true
        }
        return try? CityGameHTTPService(configuration: api, token: context.session.token, lease: lease.lease,
            transport: composition.makeTransport(), isCurrent: current, onUnauthorized: { [weak self] in
                guard let self, current() else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: context.session.epoch, credential: context.session.token)
            })
    }
    /// Merged Roam + CITY territory service under the reviewed CITY lease.
    func makeRoamTerritoryService() -> RoamTerritoryService? {
        guard let context = currentRuntimeDependencyContext, let lease = composition.cityGameLease(context), lease.matches(context),
              let api = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let viewer = cityParticipationRuntimeRevision
        let current: () -> Bool = { [weak self, weak lease] in
            guard let self, let lease, self.cityParticipationRuntimeRevision == viewer, let live = self.currentRuntimeDependencyContext,
                  ContentDraftContextFence.matches(context, live), context.session == live.session,
                  self.composition.cityGameLease(live) === lease, lease.matches(live) else { return false }
            return true
        }
        return try? RoamTerritoryService(configuration: api, token: context.session.token, lease: lease.lease,
            transport: composition.makeTransport(), isCurrent: current, onUnauthorized: { [weak self] in
                guard let self, current() else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: context.session.epoch, credential: context.session.token)
            })
    }
    /// City Monopoly + attributes v2 service (CITY-MONOPOLY-SPEC §6.2) under the reviewed CITY lease. Points only.
    func makeCityMonopolyService() -> CityMonopolyService? {
        guard let context = currentRuntimeDependencyContext, let lease = composition.cityGameLease(context), lease.matches(context),
              let api = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let viewer = cityParticipationRuntimeRevision
        let current: () -> Bool = { [weak self, weak lease] in
            guard let self, let lease, self.cityParticipationRuntimeRevision == viewer, let live = self.currentRuntimeDependencyContext,
                  ContentDraftContextFence.matches(context, live), context.session == live.session,
                  self.composition.cityGameLease(live) === lease, lease.matches(live) else { return false }
            return true
        }
        return try? CityMonopolyService(configuration: api, token: context.session.token, lease: lease.lease,
            transport: composition.makeTransport(), isCurrent: current, onUnauthorized: { [weak self] in
                guard let self, current() else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: context.session.epoch, credential: context.session.token)
            })
    }
}

