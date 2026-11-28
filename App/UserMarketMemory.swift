import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// US launch r1, one-app (owner 2026-11-27): the device-local inputs of the per-user market
/// (`UserMarketResolver`). Two hints are kept in UserDefaults; neither is a credential:
/// - the account's region, written only when the signed-in `/api/user/info` returns a recognizable one;
/// - the dial code of the phone the user last signed in with (`+86` / `+1`), cleared by an Apple sign-in.
/// Every new sign-in drops the previous account's region until the new profile is read.
enum UserMarketMemory {
    static let accountRegionKey = "preferences.userMarket.accountRegion"
    static let signInDialCodeKey = "preferences.userMarket.signInDialCode"

    static func resolve(buildDefault: RegionalMarket?, defaults: UserDefaults = .standard,
                        deviceRegion: String? = Locale.current.region?.identifier) -> RegionalMarket {
        UserMarketResolver.resolve(accountRegion: defaults.string(forKey: accountRegionKey),
                                   signInPhone: defaults.string(forKey: signInDialCodeKey),
                                   deviceRegion: deviceRegion, buildDefault: buildDefault)
    }

    /// Only a recognizable region (`CN` / `US`) is kept; anything else leaves the stored hint as it is.
    static func recordAccountRegion(_ region: String?, defaults: UserDefaults = .standard) {
        guard let market = UserMarketResolver.market(region: region) else { return }
        defaults.set(market.rawValue, forKey: accountRegionKey)
    }

    /// Legal pages follow the storefront. A US player must not be shown the China source as if it were US law.
    /// The catalog then returns `.missing(.regionalTextNotProvided)` — a placeholder, not legal copy.
    static func legalDocumentMarket(deployment: RegionalMarket?) -> RegionalMarket? {
        USLaunchPresentation.market(storefront: RegionalLaunchConfiguration.storefrontMarket, deployment: deployment)
    }

    /// A phone sign-in stores its dial code; an Apple sign-in (`nil`) clears it, so the device region decides.
    static func recordSignIn(phoneCountry: PhoneCountryCode?, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: accountRegionKey)
        if let phoneCountry {
            defaults.set(phoneCountry.dialCode, forKey: signInDialCodeKey)
        } else {
            defaults.removeObject(forKey: signInDialCodeKey)
        }
    }
}
