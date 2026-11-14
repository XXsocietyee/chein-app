import SwiftUI

/// G4/G5 mount (receipt `mount-g45`). One per-session bundle for the player capability views the
/// cloud-g-social-roam branch built. Kept out of AppSession.swift (line ratchet); injected once at the root.
/// Nil (signed out, unconfigured, fixtures, previews) hides every entry that reads it.
@MainActor struct SocialRoamCapabilities {
    let client: PlayerCapabilityClient
    let accountID: Int
    /// `GET api/v1/community/me/posts|bookmarks`; nil while community read is not configured.
    let squareMine: SquareService?
    let token: String
    /// Community read is open: unified search may ask for `post` rows.
    let communityOpen: Bool
    /// `api/merchant/public-home`, used only to resolve a play node's owner to its `mms_merchant.id`.
    let merchantHome: any PublicMerchantHomeReading
}

extension AppSession {
    func socialRoamCapabilities() -> SocialRoamCapabilities? {
        guard let client = playerCapabilityClient(), let account, account.id > 0, let token else { return nil }
        let communityOpen = squareReader.isConfigured
        let square = communityOpen
            ? regionalConfiguration?.apiConfiguration.map { SquareService(configuration: $0, transport: compositionTransport) } : nil
        return SocialRoamCapabilities(client: client, accountID: account.id, squareMine: square, token: token,
                                      communityOpen: communityOpen, merchantHome: readOnlyPublicMerchantHomeContext.reader)
    }
}

private struct SocialRoamCapabilitiesKey: EnvironmentKey {
    static var defaultValue: SocialRoamCapabilities? { nil }
}

extension EnvironmentValues {
    var socialRoamCapabilities: SocialRoamCapabilities? {
        get { self[SocialRoamCapabilitiesKey.self] }
        set { self[SocialRoamCapabilitiesKey.self] = newValue }
    }
}

/// Root injection. Re-evaluated on every session publish, so sign-out or an account switch drops the bundle at once.
struct SocialRoamCapabilityRoot: ViewModifier {
    @ObservedObject var session: AppSession

    func body(content: Content) -> some View {
        content
            .environment(\.socialRoamCapabilities, session.socialRoamCapabilities())
            .environment(\.gameplayPresetClient, session.gameplayPresetClient())
            .environment(\.wp09APIHost, session.regionalConfiguration?.apiConfiguration?.baseURL.host)
    }
}
