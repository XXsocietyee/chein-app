#if DEBUG
import SwiftUI

/// Debug-only registry behind the launch argument `--design-fixture <name>`.
/// Screen workers: add ONE `case` per fixture in `make(_:)` that returns your `App/DesignFixtures/<Screen>Fixture.swift` view.
/// Fixtures use synthetic, clearly-labelled data and never ship in Release.
enum DesignFixtureRegistry {
    @MainActor static func make(_ name: String) -> AnyView {
        switch name {
        case "kit": return AnyView(KitGalleryFixture(domain: .player))
        case "kit-2": return AnyView(KitGalleryFixture(domain: .player, lower: true))
        case "kit-merchant-2": return AnyView(KitGalleryFixture(domain: .merchant, lower: true))
        case "kit-merchant": return AnyView(KitGalleryFixture(domain: .merchant))
        case "d2-home": return AnyView(D2Fixture(screen: .home))
        case "d2-search": return AnyView(D2Fixture(screen: .search))
        case "d2-search-results": return AnyView(D2Fixture(screen: .searchResults))
        case "d2-square": return AnyView(D2Fixture(screen: .square))
        case "d2-play": return AnyView(D2Fixture(screen: .play))
        case "d2-city": return AnyView(D2Fixture(screen: .city))
        case "d2-npc": return AnyView(D2Fixture(screen: .npc))
        case "d2-inbox": return AnyView(D2Fixture(screen: .inbox))
        case "d2-me": return AnyView(D2Fixture(screen: .me))
        case "d2-roam": return AnyView(D2Fixture(screen: .roam))
        case "welcome": return AnyView(WelcomeFixture())
        case "welcome-menu": return AnyView(WelcomeMenuFixture())
        case "consent": return AnyView(ConsentFixture())
        case "login-player": return AnyView(LoginFixture())
        case "d4-directory": return AnyView(D4ClubFixture(.directory))
        case "d4-detail": return AnyView(D4ClubFixture(.detail(owner: false)))
        case "d4-owner-detail": return AnyView(D4ClubFixture(.detail(owner: true)))
        case "d4-channels": return AnyView(D4ClubFixture(.channels(list: true)))
        case "d4-channel-chat": return AnyView(D4ClubFixture(.channels(list: false)))
        case "d4-tab-posts": return AnyView(D4ClubFixture(.tab(.posts)))
        case "d4-tab-events": return AnyView(D4ClubFixture(.tab(.events)))
        case "d4-tab-overview": return AnyView(D4ClubFixture(.tab(.overview)))
        case "d4-members": return AnyView(D4ClubFixture(.members))
        case "d4-confirm": return AnyView(D4ClubFixture(.confirm))
        case "d4-settings": return AnyView(D4MeFixture(screen: .settings))
        case "d4-growth": return AnyView(D4MeFixture(screen: .growth))
        case "d4-leaderboard": return AnyView(D4MeFixture(screen: .leaderboard))
        case "d4-badges": return AnyView(D4MeFixture(screen: .badges))
        case "d4-join-confirm": return AnyView(D4ClubFixture(.joinConfirm))
        case "d4-badges-empty": return AnyView(D4MeFixture(screen: .badgesEmpty))
        case "d4-badges-error": return AnyView(D4MeFixture(screen: .badgesError))
        case "d4-stamps": return AnyView(D4MeFixture(screen: .stamps))
        case "d4-stamps-empty": return AnyView(D4MeFixture(screen: .stampsEmpty))
        case "d4-enroll": return AnyView(D4ClubOpsFixture(screen: .enroll))
        case "d4-gov": return AnyView(D4ClubOpsFixture(screen: .governance))
        case "d4-ops": return AnyView(D4ClubOpsFixture(screen: .operations(create: false)))
        case "d4-ops-create": return AnyView(D4ClubOpsFixture(screen: .operations(create: true)))
        // D5 merchant console (synthetic data, light, real views under .roleTheme(.merchant))
        case "merchant-home": return merchantConsoleFixture(.home)
        case "merchant-home-unknown": return merchantConsoleFixture(.homeUnknown)
        case "merchant-orders": return merchantConsoleFixture(.orders)
        case "merchant-projects": return merchantConsoleFixture(.projects)
        case "merchant-customers": return merchantConsoleFixture(.customers)
        case "merchant-finance": return merchantConsoleFixture(.finance)
        case "merchant-coupons": return merchantCouponFixture()
        case "d6-play": return AnyView(D6MapFixture(kind: .play))
        case "d6-play-loading": return AnyView(D6MapFixture(kind: .playLoading))
        case "d6-roam": return AnyView(D6MapFixture(kind: .roam))
        case "d6-search": return AnyView(D6MapFixture(kind: .search))
        case "d6-live": return AnyView(D6MapFixture(kind: .live))
        // REAL RoamLiveSessionView on the synthetic RoamLiveFixture controller (offline example, no GPS/network).
        case "d6-real-live": return AnyView(D6RealLiveHost())
        // D7 creator / publish (PublishDesignFixtures)
        case let n where PublishDesignFixtures.make(n) != nil: return PublishDesignFixtures.make(n)!
        default:
            if let e4 = MainActor.assumeIsolated({ E4Fixtures.make(name) }) { return e4 }
            if let d3 = MainActor.assumeIsolated({ OrdersWalletFixtures.make(name) }) { return d3 }
            return AnyView(Text(verbatim: "Unknown design fixture: \(name)").padding())
        }
    }
}

// MARK: e4 account and settings fixtures (kept in this file so no project file change is needed)

/// e4 account and settings pages: every fixture mounts the REAL view on the existing synthetic readers (labelled, DEBUG only).
/// Reachable with `--design-fixture e4-<name>`.
enum E4Fixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e4-profile-edit": return wrap(ProfileEditFixtureHost(scenario: "success"))
        case "e4-profile-edit-error": return wrap(ProfileEditFixtureHost(scenario: "rejected"))
        case "e4-settings-support": return wrap(SettingsFixtureHostView())
        case "e4-about":
            return wrap(NavigationStack { SettingsAboutView(market: RegionalLaunchConfiguration.market, appInformation: .current(), legalReader: SettingsFixtureLegalReader(scenario: "content")) })
        case "e4-privacy": return wrap(OwnMediaFixtureHost(scenario: "ready"))
        case "e4-favorites": return wrap(TopicUnlikeFixtureHost(scenario: "ready"))
        case "e4-collection": return wrap(AccountCollectionFixtureHostView())
        case "e4-complaint": return wrap(ProfileComplaintPreparationFixtureView(scenario: "content"))
        case "e4-member": return wrap(MemberHomeFixtureHost(scenario: "ready"))
        case "e4-participants": return wrap(ParticipantFixtureHostView())
        case "e4-self-projects": return wrap(ProfileSelfProjectsFixtureHost(scenario: "content"))
        case "e4-self-growth": return wrap(ProfileSelfGrowthFixtureHost(scenario: "content"))
        case "e4-self-medals": return wrap(ProfileSelfMedalsFixtureHost(scenario: "content"))
        case "e4-template-mine": return wrap(TemplateAuthoringFixtureHostView())
        case "e4-wallet-income": return wrap(WalletCommerceFixtureHost(designPage: "income"))
        case "e4-wallet-points": return wrap(WalletCommerceFixtureHost(designPage: "points"))
        case "e4-wallet-balance": return wrap(WalletCommerceFixtureHost(designPage: "balance"))
        case "e4-wallet-assets": return wrap(WalletCommerceFixtureHost(designPage: "assets"))
        case "e4-wallet-analysis": return wrap(WalletCommerceFixtureHost(designPage: "analysis"))
        case "e4-wallet-bank": return wrap(WalletCommerceFixtureHost(designPage: "bank"))
        case "e4-wallet-withdrawals": return wrap(WalletCommerceFixtureHost(designPage: "withdrawals"))
        case "e4-wallet-tasks": return wrap(WalletCommerceFixtureHost(designPage: "tasks"))
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player).preferredColorScheme(.dark))
    }
}
#endif
