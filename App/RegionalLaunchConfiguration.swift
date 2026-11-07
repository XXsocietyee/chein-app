import Foundation

/// Deployment metadata is independent of language. No endpoint has been approved yet.
enum RegionalLaunchConfiguration {
    /// Shipped artifact deliberately has no reviewed deployment. Deployment integration replaces
    /// this typed composition input, never the runtime URL allowlist or a server feature flag.
    @MainActor static var composition: AppCompositionRoot {
        // Only a separately reviewed, source-owned deployment may replace nil.
        // Build metadata validates that choice; it never creates an approval.
        makeComposition(reviewed: nil, build: .current)
    }

    static func reviewedDeployment(
        build: BuildMetadata = .current,
        reads: Set<ReviewedAppDeployment.ReadGrant> = [.homeAndSearch, .publicMapLayers, .publicTopicTemplateCatalogAndDetail],
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
            productionGatesEnabled: true,
            allowLoginRoleFallbackOnRolelessUserInfo: allowLoginRoleFallbackOnRolelessUserInfo
        )
    }

    @MainActor static func reviewedComposition(
        build: BuildMetadata = .current,
        reads: Set<ReviewedAppDeployment.ReadGrant> = [.homeAndSearch, .publicMapLayers, .publicTopicTemplateCatalogAndDetail],
        allowLoginRoleFallbackOnRolelessUserInfo: Bool = true,
        storage: AppScopedStorageFactory? = nil,
        makeTransport: @escaping () -> any HTTPTransport = { URLSessionTransport() }
    ) -> AppCompositionRoot {
        guard let deployment = try? reviewedDeployment(
            build: build,
            reads: reads,
            allowLoginRoleFallbackOnRolelessUserInfo: allowLoginRoleFallbackOnRolelessUserInfo
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
