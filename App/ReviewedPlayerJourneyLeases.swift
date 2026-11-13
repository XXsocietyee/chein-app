import Foundation

extension ReviewedProductionGateLeases {
    /// Player journey reader for the shipped China composition. Production gates alone do not mint it.
    static func playerJourneySource(enabled: Bool, market: RegionalMarket, configuration: APIConfiguration,
                                    transport: any HTTPTransport, store: any JourneyRequestStoring = JourneyMemoryRequestStore()) -> JourneyLoopSource? {
        guard enabled, market == .china, admits(configuration), let host = configuration.baseURL.host else { return nil }
        return try? JourneyLoopSource(configuration: configuration, transport: transport, store: store,
                                       endpointClass: .production, productionLease: JourneyProductionLease(host: host))
    }

    /// P7–P9, landing, seats, and the public catalog. Affiliate and city pass are not granted.
    static func playerPWaveReader(enabled: Bool, market: RegionalMarket, configuration: APIConfiguration,
                                  transport: any HTTPTransport) -> PWaveReader? {
        guard enabled, market == .china, admits(configuration), let host = configuration.baseURL.host else { return nil }
        let capabilities = PWaveCapability(granted: PWaveProductionReadLease.grantedFeatures)
        return try? PWaveReader(configuration: configuration, transport: transport, endpointClass: .production,
                                capabilities: capabilities, productionLease: PWaveProductionReadLease(host: host))
    }

    static func publicCatalogHost(enabled: Bool, market: RegionalMarket, configuration: APIConfiguration,
                                  transport: any HTTPTransport) -> PublicCatalogHost? {
        guard let reader = playerPWaveReader(enabled: enabled, market: market, configuration: configuration, transport: transport) else {
            return nil
        }
        return PublicCatalogHost(reader: reader)
    }

    private static func admits(_ configuration: APIConfiguration) -> Bool {
        configuration.baseURL.absoluteString == ReviewedMarketLaunch.chinaProductionBaseURL
    }
}

extension AppCompositionRoot {
    func playerJourneySource(store: any JourneyRequestStoring = JourneyMemoryRequestStore()) -> JourneyLoopSource? {
        guard let reviewed, let api = reviewed.regional.apiConfiguration else { return nil }
        return ReviewedProductionGateLeases.playerJourneySource(enabled: reviewed.playerWritesEnabled,
                                                                market: reviewed.regional.market, configuration: api,
                                                                transport: makeTransport(), store: store)
    }

    func playerPWaveReader() -> PWaveReader? {
        guard let reviewed, let api = reviewed.regional.apiConfiguration else { return nil }
        return ReviewedProductionGateLeases.playerPWaveReader(enabled: reviewed.playerWritesEnabled,
                                                              market: reviewed.regional.market, configuration: api,
                                                              transport: makeTransport())
    }

    func publicCatalogHost() -> PublicCatalogHost? {
        guard let reviewed, let api = reviewed.regional.apiConfiguration else { return nil }
        return ReviewedProductionGateLeases.publicCatalogHost(enabled: reviewed.playerWritesEnabled,
                                                              market: reviewed.regional.market, configuration: api,
                                                              transport: makeTransport())
    }
}
