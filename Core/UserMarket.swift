import Foundation

/// US launch r1, lane one-app (owner decision 2026-11-27): ONE App Store app
/// (`com.chengyinhub.chengyinApp`) serves China and the United States. The build's `QuestifyMarket`
/// (`QUESTIFY_MARKET`, CN in Release) is only the fallback. The per-user market is decided at runtime,
/// first match wins:
/// 1. the account's stored region, when the backend returns one;
/// 2. the country code of the phone the user signed in with (+86 → CN, +1 → US);
/// 3. the device region (`Locale.current.region`);
/// 4. the build market (`QUESTIFY_MARKET`), else China.
/// The result picks presentation and the pay channel only (CN: WeChat Pay / Alipay and +86, unchanged;
/// US: Apple Pay / Stripe and +1). Both markets use the same reviewed backend deployment and host.
public enum UserMarketResolver {
    public static func resolve(accountRegion: String?, signInPhone: String?, deviceRegion: String?,
                               buildDefault: RegionalMarket?) -> RegionalMarket {
        if let market = market(region: accountRegion) { return market }
        if let market = market(phone: signInPhone) { return market }
        if let market = market(region: deviceRegion) { return market }
        return buildDefault ?? .china
    }

    /// A region code: `CN` / `CHN` → China, `US` / `USA` → United States, anything else unknown.
    public static func market(region: String?) -> RegionalMarket? {
        switch (region ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "CN", "CHN": return .china
        case "US", "USA": return .unitedStates
        default: return nil
        }
    }

    /// A dial code or a sign-in wire value: `+86…` (or the bare China 11 digits the CN flow sends) → China,
    /// `+1…` → United States, anything else unknown.
    public static func market(phone: String?) -> RegionalMarket? {
        let value = (phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("+86") { return .china }
        if value.hasPrefix("+1") { return .unitedStates }
        if value.count == 11, value.hasPrefix("1"), value.allSatisfy({ $0.isASCII && $0.isNumber }) { return .china }
        return nil
    }
}

/// US launch presentation. The shipped app runs both storefronts on the China deployment, so
/// `operationalMarket` is China for a US player. These helpers read the storefront first.
public enum USLaunchPresentation {
    /// Storefront wins. A nil storefront keeps the deployment market (China screens stay on China).
    public static func market(storefront: RegionalMarket?, deployment: RegionalMarket?) -> RegionalMarket? {
        storefront ?? deployment
    }

    /// P33: the United States leads with Sign in with Apple, then phone (+1). China, and an unknown
    /// market, keep WeChat (when it is offered), then phone (+86), then Apple.
    public static func signInLeadsWithApple(storefront: RegionalMarket?, deployment: RegionalMarket?) -> Bool {
        market(storefront: storefront, deployment: deployment) == .unitedStates
    }
}
