import Foundation

/// U08-02 and the TEAM backpack client. Built beside `AppSession.swift` so that file does not grow.
@MainActor extension AppSession {
    func playFinishRouteReader() -> ProductionPlayFinishRouteReader? {
        guard let api = regionalConfiguration?.apiConfiguration else { return nil }
        let service = PlayExperienceService(configuration: api, transport: runtimeHTTPTransport, enabled: [.reads])
        return ProductionPlayFinishRouteReader(service: service, token: { [weak self] in self?.token })
    }

    /// Server flag `finishNearbyRoute`. Missing, refused, or false stays off, so the card is not shown.
    func finishNearbyRouteEnabled() async -> Bool {
        guard let api = regionalConfiguration?.apiConfiguration,
              currentRuntimeDependencyContext?.market == .china,
              ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/config/features"),
              let captured = token, AuthRequestBuilder.isValidToken(captured) else { return false }
        let reader = LaunchFeatureFlagsReader(configuration: api, transport: runtimeHTTPTransport, approved: true,
                                              currentIdentity: { captured })
        guard case .loaded(let flags) = await reader.load(token: captured) else { return false }
        return flags.isOn("finishNearbyRoute")
    }

    func playTeamBackpack(activityID: Int) -> PlayTeamBackpackCoordinator? {
        guard activityID > 0, let api = regionalConfiguration?.apiConfiguration else { return nil }
        let service = PlayExperienceService(configuration: api, transport: runtimeHTTPTransport, enabled: [.reads, .playerCommands])
        let token: @MainActor () -> String? = { [weak self] in self?.token }
        return PlayTeamBackpackCoordinator(activityID: activityID,
                                           reader: PlayTeamBackpackHTTP(service: service, token: token),
                                           client: PlayTeamItemCommandClient(service: service),
                                           token: token)
    }
}
