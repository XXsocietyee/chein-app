import Foundation

/// A build/deployment boundary, never inferred from language, IP, currency or storefront.
public enum RegionalMarket: String, CaseIterable, Hashable, Sendable {
    case china = "CN"
    case unitedStates = "US"

    /// The market's own language. One-app (owner 2026-11-27): no longer the first-launch default;
    /// with no stored choice the UI follows the phone (`AppLanguage.deviceDefault`).
    public var defaultLanguage: AppLanguage {
        self == .china ? .simplifiedChinese : .english
    }
    /// Preserve every existing preference, including explicit System and its legacy fallback.
    /// With no stored choice, follow the phone's preferred language (zh* → zh-Hans, otherwise English),
    /// whatever the build market. The derived default is never written back.
    public func language(storedValue: String?,
                         preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        storedValue.map(AppLanguage.init(storedValue:)) ?? AppLanguage.deviceDefault(preferredLanguages: preferredLanguages)
    }
}

public enum RegionalConfigurationError: Error, Equatable {
    case missingMarket, unsupportedMarket, unapprovedBackend
}

public enum RegionalCapability: String, CaseIterable, Hashable {
    case usernamePassword, domesticChinaPhone, internationalPhone, emailLogin
    case signInWithApple, signInWithGoogle
    case physicalEventPayment, digitalContentPayment, merchantPayout
}

public enum RegionalCapabilityAvailability: Equatable {
    case notRequested, implementationPending, backendNotConfigured, verificationPending, available
}

/// An input-format contract only. It does not imply a working login endpoint/provider.
public enum RegionalPhoneContract: Equatable {
    case chinaDomestic11Digits, internationalE164
}

public struct RegionalConfiguration {
    public let market: RegionalMarket
    public let apiConfiguration: APIConfiguration?
    private let verifiedCapabilities: Set<RegionalCapability>

    /// Exact, market-scoped endpoint approvals must come from reviewed deployment configuration.
    /// Do not populate the allowlist from the endpoint itself or a user-editable language setting.
    /// Empty endpoint is an intentional offline/unconfigured state, even if approvals exist.
    public init(market: RegionalMarket, baseURL: String? = nil,
                approvedBaseURLs: [RegionalMarket: Set<String>] = [:],
                verifiedCapabilities: Set<RegionalCapability> = []) throws {
        self.market = market
        self.verifiedCapabilities = verifiedCapabilities
        let value = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty {
            apiConfiguration = nil
        } else {
            guard let url = URL(string: value) else { throw APIError.invalidConfiguration }
            let configuration = try APIConfiguration(baseURL: url)
            // Exact origin + port + path comparison: no suffix/subdomain or cross-market fallback.
            guard approvedBaseURLs[market]?.contains(value) == true else {
                throw RegionalConfigurationError.unapprovedBackend
            }
            apiConfiguration = configuration
        }
    }

    /// Missing/unknown build metadata fails closed; do not default a live backend to CN or US.
    public static func market(buildValue: String?) throws -> RegionalMarket {
        guard let value = buildValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { throw RegionalConfigurationError.missingMarket }
        guard let market = RegionalMarket(rawValue: value) else {
            throw RegionalConfigurationError.unsupportedMarket
        }
        return market
    }

    public var phoneContract: RegionalPhoneContract {
        market == .china ? .chinaDomestic11Digits : .internationalE164
    }
    /// Product planning only. This list must never directly drive enabled controls or requests.
    public var desiredCapabilities: Set<RegionalCapability> {
        switch market {
        case .china:
            return [.usernamePassword, .domesticChinaPhone, .signInWithApple,
                    .physicalEventPayment, .digitalContentPayment, .merchantPayout]
        case .unitedStates:
            return [.internationalPhone, .emailLogin, .signInWithApple, .signInWithGoogle,
                    .physicalEventPayment, .digitalContentPayment, .merchantPayout]
        }
    }
    /// CN SMS is the only mounted native bootstrap contract. The retained password
    /// route requires a mini-program WeChat code; a capability flag cannot supply it.
    /// Provider/deployment verification is still required before enabling SMS.
    public var implementedCapabilities: Set<RegionalCapability> {
        market == .china ? [.domesticChinaPhone] : []
    }
    public func availability(of capability: RegionalCapability) -> RegionalCapabilityAvailability {
        guard desiredCapabilities.contains(capability) else { return .notRequested }
        guard implementedCapabilities.contains(capability) else { return .implementationPending }
        guard apiConfiguration != nil else { return .backendNotConfigured }
        guard verifiedCapabilities.contains(capability) else { return .verificationPending }
        return .available
    }
    public var availableCapabilities: Set<RegionalCapability> {
        Set(RegionalCapability.allCases.filter { availability(of: $0) == .available })
    }
    /// Use before constructing/injecting the legacy CN-only AuthChannelService/coordinator.
    public var canUseDomesticChinaPhone: Bool {
        availability(of: .domesticChinaPhone) == .available
    }

    /// Absent capabilities stay hidden. Only an available capability is shown.
    public func isFeatureShown(_ capability: RegionalCapability) -> Bool {
        availability(of: capability) == .available
    }

    /// A control for `path` is shown only when this deployment can call it.
    /// A route the China host refuses stays hidden even if its capability was verified.
    /// Password login, bank withdrawal, and virtual goods stay hidden.
    public func showsRoute(_ path: String) -> Bool {
        guard ChinaReviewedRouteCapability.offersFeature(path, baseURL: apiConfiguration?.baseURL) else { return false }
        // A money route whose own Release switch is on (DEBUG/TEST off the production host) is shown; Release keeps it hidden.
        if let capability = ChinaReviewedRouteCapability.hidingCapability(for: path), !ReleaseMoneyWriteSwitch.opens(path) {
            return isFeatureShown(capability)
        }
        return true
    }
}

/// Explicit reviewed hosts. The shipped composition selects China only through
/// `admitsShippedChina`. The US market has no approved host and must not be given an invented one.
public enum ReviewedMarketLaunch {
    public static let chinaProductionBaseURL = "https://www.chengyinhub.com/prod-api/"
    /// China is the only key. A missing US entry is the disabled reviewed path.
    public static let approvedBaseURLs: [RegionalMarket: Set<String>] = [
        .china: [chinaProductionBaseURL]
    ]
    /// Domestic China phone is verified only for this China deployment.
    public static let chinaVerifiedCapabilities: Set<RegionalCapability> = [.domesticChinaPhone]

    /// True only for the reviewed China host plus a usable bundle and realm.
    /// A United States market, an empty build, and any other host return false.
    public static func admitsShippedChina(market: RegionalMarket, baseURL: String, bundleIdentifier: String, realm: String) -> Bool {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundle = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let realm = realm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard market == .china, base == chinaProductionBaseURL else { return false }
        return (try? storageScope(market: market, baseURL: base, bundleIdentifier: bundle, realm: realm)) != nil
    }

    /// US launch r1 (owner 2026-11-27): the US storefront runs on the same reviewed production backend.
    /// The backend has no market split, so the US build is admitted onto the China backend deployment
    /// (same host, same realm rules, same verified capabilities); the storefront market stays US for
    /// presentation (phone country default, locale, merchant center off). Any other host returns false.
    public static func admitsShippedUnitedStates(market: RegionalMarket, baseURL: String, bundleIdentifier: String, realm: String) -> Bool {
        guard market == .unitedStates else { return false }
        return admitsShippedChina(market: .china, baseURL: baseURL, bundleIdentifier: bundleIdentifier, realm: realm)
    }

    public static func configuration(market: RegionalMarket, baseURL: String) throws -> RegionalConfiguration {
        let value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard market == .china, approvedBaseURLs[market]?.contains(value) == true else {
            throw RegionalConfigurationError.unapprovedBackend
        }
        guard let url = URL(string: value), url.absoluteString == value else {
            throw RegionalConfigurationError.unapprovedBackend
        }
        return try RegionalConfiguration(
            market: market,
            baseURL: value,
            approvedBaseURLs: approvedBaseURLs,
            verifiedCapabilities: chinaVerifiedCapabilities
        )
    }

    public static func storageScope(
        market: RegionalMarket = .china,
        baseURL: String = chinaProductionBaseURL,
        bundleIdentifier: String,
        realm: String
    ) throws -> RegionalSessionStorageScope {
        let configuration = try self.configuration(market: market, baseURL: baseURL)
        return try RegionalSessionStorageScope(
            configuration: configuration,
            bundleIdentifier: bundleIdentifier,
            realm: realm
        )
    }
}
