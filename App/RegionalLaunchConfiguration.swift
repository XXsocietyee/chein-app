import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Deployment metadata is independent of language. The only reviewed host is the China
/// registry in `ReviewedMarketLaunch`. The United States registry has no host.
enum RegionalLaunchConfiguration {
    /// Selects the reviewed China deployment when the build matches it. An empty build and
    /// every United States build stay unconfigured and call no backend.
    @MainActor static var composition: AppCompositionRoot {
        #if DEBUG
        if let e2e = E2ETestHostOverride.selected() {
            ReviewedAreaSwitch.installReleaseMoneyDerivation(host: e2e.reviewed?.regional.apiConfiguration?.baseURL.host)
            // F-14: requests are rewritten to TEST, which serves the topic edit-request and publish-status routes.
            TestHostOnlyRouteAdmission.testHostActive = true
            return e2e
        }
        #endif
        let shipped = shippedComposition(build: .current)
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: shipped.reviewed?.regional.apiConfiguration?.baseURL.host)
        return shipped
    }

    /// China selection uses `ReviewedAppDeployment` through `reviewedComposition` and the
    /// host already named by Config and `ReviewedMarketLaunch`. The reviewed production gate
    /// bundle is on (`productionGatesEnabled`): Apple and SMS sign-in, the legal catalog, and
    /// wallet, orders, favorites and coupons reads. Owner approval 2026-11-12 also turns on
    /// `playerWritesEnabled` for the non-money player writes. The money-write derivation is installed
    /// from this host. Password login, virtual goods, and non-money merchant writes stay off.
    @MainActor static func shippedComposition(
        build: BuildMetadata = .current,
        storage: AppScopedStorageFactory? = nil,
        makeTransport: @escaping () -> any HTTPTransport = { URLSessionTransport() }
    ) -> AppCompositionRoot {
        let market = try? RegionalConfiguration.market(buildValue: build.market)
        let base = build.baseURL ?? ""
        let bundle = build.bundleIdentifier ?? ""
        let realm = build.realm ?? ""
        // US launch r1: a US build on the reviewed production host composes the same backend deployment
        // (backend market CN). `storefrontMarket` keeps the build's US market for presentation.
        guard let market, ReviewedMarketLaunch.admitsShippedChina(
            market: market, baseURL: base, bundleIdentifier: bundle, realm: realm
        ) || ReviewedMarketLaunch.admitsShippedUnitedStates(
            market: market, baseURL: base, bundleIdentifier: bundle, realm: realm
        ) else {
            return makeComposition(reviewed: nil, build: .current)
        }
        let pinned = BuildMetadata(
            market: RegionalMarket.china.rawValue,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle.trimmingCharacters(in: .whitespacesAndNewlines),
            realm: realm.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return reviewedComposition(
            build: pinned,
            reads: [
                .homeAndSearch, .manualMap, .publicMapLayers, .publicTopicTemplateCatalogAndDetail,
                .officialPublicEventCatalogAndDetail, .playNodesAndRouteState
            ],
            // Owner approval 2026-11-12 (E2E-20261112 F2): signed-in player topic/activity/route detail.
            contentDetails: .activityAndTopic,
            storage: storage,
            makeTransport: makeTransport
        )
    }

    static func reviewedDeployment(
        build: BuildMetadata = .current,
        reads: Set<ReviewedAppDeployment.ReadGrant> = [.homeAndSearch, .publicMapLayers, .publicTopicTemplateCatalogAndDetail],
        contentDetails: SignedInContentDetailReadApproval? = nil,
        allowLoginRoleFallbackOnRolelessUserInfo: Bool = true
    ) throws -> ReviewedAppDeployment {
        guard let market = try? RegionalConfiguration.market(buildValue: build.market) else {
            throw ValidationIssue.marketMissingOrUnsupported
        }
        guard let rawBase = build.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBase.isEmpty else {
            throw ValidationIssue.endpointMismatch
        }
        guard let rawBundle = build.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBundle.isEmpty,
              let rawRealm = build.realm?.trimmingCharacters(in: .whitespacesAndNewlines), !rawRealm.isEmpty else {
            throw ValidationIssue.storageScopeMismatch
        }
        return try ReviewedAppDeployment(
            market: market,
            baseURL: rawBase,
            approvedBaseURLs: [market: [rawBase]],
            verifiedCapabilities: market == .china ? [.domesticChinaPhone] : [],
            bundleIdentifier: rawBundle,
            realm: rawRealm,
            reads: reads,
            contentDetails: contentDetails,
            productionGatesEnabled: true,
            playerWritesEnabled: true,
            allowLoginRoleFallbackOnRolelessUserInfo: allowLoginRoleFallbackOnRolelessUserInfo
        )
    }

    @MainActor static func reviewedComposition(
        build: BuildMetadata = .current,
        reads: Set<ReviewedAppDeployment.ReadGrant> = [.homeAndSearch, .publicMapLayers, .publicTopicTemplateCatalogAndDetail],
        contentDetails: SignedInContentDetailReadApproval? = nil,
        allowLoginRoleFallbackOnRolelessUserInfo: Bool = true,
        storage: AppScopedStorageFactory? = nil,
        makeTransport: @escaping () -> any HTTPTransport = { URLSessionTransport() }
    ) -> AppCompositionRoot {
        guard let deployment = try? reviewedDeployment(
            build: build,
            reads: reads,
            contentDetails: contentDetails,
            allowLoginRoleFallbackOnRolelessUserInfo: allowLoginRoleFallbackOnRolelessUserInfo
        ) else {
            return .init(deployment: .incompatibleBuild, storage: storage, makeTransport: makeTransport)
        }
        return makeComposition(reviewed: deployment, build: build, storage: storage, makeTransport: makeTransport)
    }

    /// Selectable reviewed deployment. The shipped `composition` does not call this.
    /// Password login, bank withdrawal, and virtual goods stay off: `productionGatesEnabled` is false.
    static func reviewedMarketDeployment(
        market: RegionalMarket,
        baseURL: String,
        bundleIdentifier: String,
        realm: String,
        reads: Set<ReviewedAppDeployment.ReadGrant> = []
    ) throws -> ReviewedAppDeployment {
        let regional = try ReviewedMarketLaunch.configuration(market: market, baseURL: baseURL)
        return try ReviewedAppDeployment(
            market: regional.market,
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs,
            verifiedCapabilities: regional.availableCapabilities,
            bundleIdentifier: bundleIdentifier,
            realm: realm,
            reads: reads,
            productionGatesEnabled: false
        )
    }

    @MainActor static func reviewedMarketComposition(
        market: RegionalMarket,
        baseURL: String,
        bundleIdentifier: String,
        realm: String,
        reads: Set<ReviewedAppDeployment.ReadGrant> = [],
        storage: AppScopedStorageFactory? = nil,
        makeTransport: @escaping () -> any HTTPTransport = { URLSessionTransport() }
    ) -> AppCompositionRoot {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = BuildMetadata(market: market.rawValue, baseURL: trimmed, bundleIdentifier: bundleIdentifier, realm: realm)
        guard let deployment = try? reviewedMarketDeployment(
            market: market,
            baseURL: trimmed,
            bundleIdentifier: bundleIdentifier,
            realm: realm,
            reads: reads
        ) else {
            return .init(deployment: .incompatibleBuild, storage: storage, makeTransport: makeTransport)
        }
        return makeComposition(reviewed: deployment, build: build, storage: storage, makeTransport: makeTransport)
    }

    struct BuildMetadata {
        let market: String?
        let baseURL: String?
        let bundleIdentifier: String?
        let realm: String?
        static var current: Self {
            .init(market: Bundle.main.object(forInfoDictionaryKey: "QuestifyMarket") as? String,
                baseURL: Bundle.main.object(forInfoDictionaryKey: "QuestifyAPIBaseURL") as? String,
                bundleIdentifier: Bundle.main.bundleIdentifier,
                realm: Bundle.main.object(forInfoDictionaryKey: "QuestifySessionRealm") as? String)
        }
    }
    enum ValidationIssue: Error, Equatable {
        case marketMissingOrUnsupported, marketMismatch, endpointMismatch, storageScopeMismatch
    }
    /// Pure validation happens before a session can open a vault or dispatch a request.
    /// Exact endpoint, region, bundle and deployment realm are all independently bound.
    static func validate(_ deployment: ReviewedAppDeployment, build: BuildMetadata) throws {
        guard let market = try? RegionalConfiguration.market(buildValue: build.market) else {
            throw ValidationIssue.marketMissingOrUnsupported
        }
        guard market == deployment.regional.market else { throw ValidationIssue.marketMismatch }
        guard let endpoint = deployment.regional.apiConfiguration?.baseURL.absoluteString,
              build.baseURL == endpoint else { throw ValidationIssue.endpointMismatch }
        guard let scope = try? RegionalSessionStorageScope(configuration: deployment.regional,
            bundleIdentifier: build.bundleIdentifier, realm: build.realm), scope == deployment.storageScope else {
            throw ValidationIssue.storageScopeMismatch
        }
    }
    @MainActor static func makeComposition(reviewed: ReviewedAppDeployment?, build: BuildMetadata,
        storage: AppScopedStorageFactory? = nil,
        makeTransport: @escaping () -> any HTTPTransport = { URLSessionTransport() }) -> AppCompositionRoot {
        guard let reviewed else {
            return .init(deployment: .unconfigured, storage: storage, makeTransport: makeTransport)
        }
        do {
            try validate(reviewed, build: build)
            let guarded: () -> any HTTPTransport = {
                ChinaReviewedProductionTransport(
                    underlying: ReadRetryHTTPTransport(
                        underlying: makeTransport(),
                        isOnline: { SharedNetworkReachabilityState.shared.isOnline }
                    )
                )
            }
            return .init(deployment: .reviewed(reviewed), storage: storage, makeTransport: guarded)
        } catch {
            return .init(deployment: .incompatibleBuild, storage: storage, makeTransport: makeTransport)
        }
    }
    static var market:RegionalMarket? {
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if let i=args.firstIndex(of:"--uitesting-market"),args.indices.contains(i+1) {
            return try? RegionalConfiguration.market(buildValue:args[i+1])
        }
        #endif
        return try? RegionalConfiguration.market(buildValue:Bundle.main.object(forInfoDictionaryKey:"QuestifyMarket") as? String)
    }
    static var configuration:RegionalConfiguration? {
        guard let market else { return nil }
        // A reviewed registry, never an allowlist synthesized from a runtime URL.
        let approved:[RegionalMarket:Set<String>]=[:]
        return try? RegionalConfiguration(market:market,
            baseURL:Bundle.main.object(forInfoDictionaryKey:"QuestifyAPIBaseURL") as? String,
            approvedBaseURLs:approved,verifiedCapabilities:[])
    }
    /// US launch r1, one-app (owner 2026-11-27): one App Store binary serves both markets, so this is the
    /// per-user market decided at runtime (`UserMarketMemory`: account region → sign-in phone country code →
    /// device region → the build's `QuestifyMarket` as the fallback). It drives presentation and the pay
    /// channel only: phone country default, the market label, Apple Pay / Stripe (US) vs WeChat Pay / Alipay
    /// (CN). Backend gates keep reading the deployment's market, China, on the one shared production backend.
    static var storefrontMarket:RegionalMarket? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-market") { return market }
        #endif
        return UserMarketMemory.resolve(buildDefault:market)
    }
    static func language(_ stored:String?)->AppLanguage {
        // One-app: no stored choice follows the phone (zh* → zh-Hans, else English); an explicit choice wins.
        market?.language(storedValue:stored) ?? stored.map(AppLanguage.init(storedValue:)) ?? AppLanguage.deviceDefault()
    }
}
