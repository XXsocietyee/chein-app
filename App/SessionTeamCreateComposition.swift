import Foundation

/// Team creation for one owned registration. The accessor lives outside `AppSession.swift`
/// so the session file stays on the line ratchet. A closed write lease still returns a coordinator:
/// the screen stays up and `TeamHTTPService` returns `.notSent` before any request.
@MainActor extension AppSession {
    func teamCreateCoordinator(registrationID: Int) -> TeamCoordinator {
        let journal = TeamDefaultsJournal(defaults: composition.storage.defaults)
        let registration = registrationID
        let loader: (Int, TeamSession) async throws -> TeamCreationContext = { [weak self] ownerID, _ in
            guard let self else { throw TeamFailure.stale }
            let detail: OrderLifecycleDetail
            do { detail = try await self.orderLifecycleReader.detail(id: registration) }
            catch { throw TeamFailure.notConfigured }
            guard let source = detail.teamCreationSource, source.context.ownerID == ownerID else { throw TeamFailure.invalidContract }
            return source.context
        }
        let current: () -> TeamSession? = { [weak self] in self?.teamCreateSession() }
        let service: any TeamServing
        if let approval = teamCreateApproval(), let api = try? APIConfiguration(baseURL: approval.baseURL) {
            service = TeamHTTPService(configuration: api, transport: runtimeHTTPTransport, approval: approval,
                                      journal: journal, currentSession: current, creationLoader: loader)
        } else if let api = regionalConfiguration?.apiConfiguration {
            service = TeamHTTPService(configuration: api, transport: runtimeHTTPTransport, approval: nil,
                                      journal: journal, currentSession: current, creationLoader: loader)
        } else {
            service = TeamReadOnlyService(currentSession: current, creationLoader: loader)
        }
        return TeamCoordinator(service: service, journal: journal, currentSession: current, onUnauthorized: { [weak self] captured in
            guard let self, self.teamCreateSession() == captured else { return }
            self.expireIfMatching(error: APIError.unauthorized, stamp: captured.epoch, credential: self.token)
        })
    }

    /// Account, epoch and token fence this session. The private viewer revision stays inside `AppSession.swift`.
    func teamCreateSession() -> TeamSession? {
        guard let account, let token, let storageScope, let market = operationalMarket else { return nil }
        return try? TeamSession(account: account, epoch: gate.currentStamp, region: market.rawValue,
                                storageNamespace: storageScope.service, token: token, viewerRevision: 0)
    }

    func teamCreateApproval() -> OperationEndpointApproval? {
        guard let context = currentRuntimeDependencyContext,
              let team = composition.playerWriteGrant(context)?.team,
              team.paths.contains("api/team/create") else { return nil }
        return team
    }
}
