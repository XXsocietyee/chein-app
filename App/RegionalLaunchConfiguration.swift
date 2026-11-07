import Foundation

/// Deployment metadata is independent of language. No endpoint has been approved yet.
enum RegionalLaunchConfiguration {
    static let defaultReviewedPlaceholderBaseURL = "https://api.example.com"
    static let defaultReviewedBundleIdentifier = "com.questify.ios"
    static let defaultReviewedRealm = "cn-reviewed"

    /// Shipped artifact deliberately has no reviewed deployment. Deployment integration replaces
    /// this typed composition input, never the runtime URL allowlist or a server feature flag.
    @MainActor static var composition: AppCompositionRoot {
        // Only a separately reviewed, source-owned deployment may replace nil.
        // Build metadata validates that choice; it never creates an approval.
        makeComposition(reviewed: nil, build: .current)
    }

    static func reviewedDeployment(
        build: BuildMetadata = .current,
        fallbackBaseURL: String = defaultReviewedPlaceholderBaseURL,
        fallbackBundleIdentifier: String = defaultReviewedBundleIdentifier,
        fallbackRealm: String = defaultReviewedRealm
    ) throws -> ReviewedAppDeployment {
        let market: RegionalMarket
        if let rawMarket = build.market?.trimmingCharacters(in: .whitespacesAndNewlines), !rawMarket.isEmpty {
            market = try RegionalConfiguration.market(buildValue: rawMarket)
        } else {
            market = .china
        }
        let resolvedBaseURL: String
        if let rawBase = build.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBase.isEmpty {
            resolvedBaseURL = rawBase
        } else {
            resolvedBaseURL = fallbackBaseURL
        }
        let resolvedBundle: String
        if let rawBundle = build.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBundle.isEmpty {
            resolvedBundle = rawBundle
        } else {
            resolvedBundle = fallbackBundleIdentifier
        }
        let resolvedRealm: String
        if let rawRealm = build.realm?.trimmingCharacters(in: .whitespacesAndNewlines), !rawRealm.isEmpty {
            resolvedRealm = rawRealm
        } else {
            resolvedRealm = fallbackRealm
        }
        return try ReviewedAppDeployment(
            market: market,
            baseURL: resolvedBaseURL,
            approvedBaseURLs: [market: [resolvedBaseURL]],
            verifiedCapabilities: market == .china ? [.domesticChinaPhone] : [],
            bundleIdentifier: resolvedBundle,
            realm: resolvedRealm,
            reads: [.homeAndSearch, .manualMap, .publicMapLayers, .publicTopicTemplateCatalogAndDetail],
            contentDetails: .activityAndTopic,
            productionGatesEnabled: true
        )
    }

    @MainActor static func reviewedComposition(
        build: BuildMetadata = .current,
        fallbackBaseURL: String = defaultReviewedPlaceholderBaseURL,
        storage: AppScopedStorageFactory? = nil,
        makeTransport: @escaping () -> any HTTPTransport = { URLSessionTransport() }
    ) -> AppCompositionRoot {
        guard let deployment = try? reviewedDeployment(build: build, fallbackBaseURL: fallbackBaseURL) else {
            return .init(deployment: .incompatibleBuild, storage: storage, makeTransport: makeTransport)
        }
        let effectiveBuild = BuildMetadata(
            market: deployment.regional.market.rawValue,
            baseURL: deployment.regional.apiConfiguration?.baseURL.absoluteString,
            bundleIdentifier: deployment.storageScope.bundleIdentifier,
            realm: deployment.storageScope.realm
        )
        return makeComposition(reviewed: deployment, build: effectiveBuild, storage: storage, makeTransport: makeTransport)
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
        let candidate: ReviewedAppDeployment?
        if let reviewed {
            candidate = reviewed
        } else if let rawBase = build.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBase.isEmpty,
                  let rawMarket = build.market?.trimmingCharacters(in: .whitespacesAndNewlines), !rawMarket.isEmpty,
                  let rawBundle = build.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBundle.isEmpty,
                  let rawRealm = build.realm?.trimmingCharacters(in: .whitespacesAndNewlines), !rawRealm.isEmpty {
            candidate = try? reviewedDeployment(build: .init(market: rawMarket, baseURL: rawBase, bundleIdentifier: rawBundle, realm: rawRealm))
        } else {
            candidate = nil
        }
        guard let reviewed = candidate else {
            return .init(deployment: .unconfigured, storage: storage, makeTransport: makeTransport)
        }
        do {
            try validate(reviewed, build: build)
            return .init(deployment: .reviewed(reviewed), storage: storage, makeTransport: makeTransport)
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
    static func language(_ stored:String?)->AppLanguage {
        market?.language(storedValue:stored) ?? stored.map(AppLanguage.init(storedValue:)) ?? .system
    }
}
