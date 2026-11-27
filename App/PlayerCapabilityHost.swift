import SwiftUI

/// G4/G5 player capability routes ride the composition transport, so the shipped China composition
/// admits them through `ReviewedProductionFormMutationRoute.acceptsPlayerWrite` (play lease) and
/// `ChinaReviewedRouteCapability` (owner grant), and refuses them everywhere else.
extension AppSession {
    func playerCapabilityClient() -> PlayerCapabilityClient? {
        guard let context = currentRuntimeDependencyContext else { return nil }
        return PlayerCapabilityClient(context: context, transport: compositionTransport)
    }
}

enum PlayerCapabilityCopy {
    static func text(_ zh: String, _ en: String, _ locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }

    /// Server refusals are shown verbatim (the mini-program shows `res.msg`); otherwise the caller's fallback.
    static func failure(_ error: Error, fallback: String) -> String {
        if case PlayerCapabilityFailure.rejected(_, let message?) = error, !message.trimmingCharacters(in: .whitespaces).isEmpty {
            return message
        }
        if case PlayerCapabilityFailure.signedOut = error { return appLocalized("i18nR3.signInFirst", locale: .current) }
        return fallback
    }
}
