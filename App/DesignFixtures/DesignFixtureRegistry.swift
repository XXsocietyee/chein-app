#if DEBUG
import SwiftUI
import AuthenticationServices

/// Debug-only registry behind the launch argument `--design-fixture <name>`.
/// Screen workers: add ONE `case` per fixture in `make(_:)` that returns your `App/DesignFixtures/<Screen>Fixture.swift` view.
/// Fixtures use synthetic, clearly-labelled data and never ship in Release.
enum DesignFixtureRegistry {
    @MainActor static func make(_ name: String) -> AnyView {
        switch name {
        case let name where name == "native-gallery" || name.hasPrefix("native-gallery-"):
            return AnyView(NativeGalleryFixture(route: name))
        case "design-kit": return AnyView(DesignKitFixture())
        // ui/h-code-r3-player: the shared in-place result kit (App/DesignFixtures/R3InPlaceKitFixtures.swift).
        case "r3-inplace": return AnyView(R3InPlaceKitFixture())
        case "r3-inplace-light": return AnyView(R3InPlaceKitFixture(domain: .topicEditor))
        // ui/r4-play-flow: play HUD and 战报 (App/DesignFixtures/R4PlayFlowFixtures.swift).
        case let r4 where r4.hasPrefix("r4-play-") || r4 == "r4-report-unscored":
            if let view = R4PlayFlowFixtures.make(r4) { return view }
            return AnyView(Text(verbatim: "Unknown fixture \(r4)"))
        case "kit": return AnyView(KitGalleryFixture(domain: .player))
        // City Monopoly kit and flows (App/DesignFixtures/CityKitFixtures.swift).
        case let city where city.hasPrefix("city-"): return CityKitFixtures.make(city)
        case "kit-2": return AnyView(KitGalleryFixture(domain: .player, lower: true))
        case "kit-merchant-2": return AnyView(KitGalleryFixture(domain: .merchant, lower: true))
        case "kit-merchant": return AnyView(KitGalleryFixture(domain: .merchant))
        case "d2-home": return AnyView(D2Fixture(screen: .home))
        case "d2-home-offline": return AnyView(D2Fixture(screen: .homeOffline))
        case "d2-search": return AnyView(D2Fixture(screen: .search))
        case "d2-search-results": return AnyView(D2Fixture(screen: .searchResults))
        case "d2-search-empty": return AnyView(D2Fixture(screen: .searchEmpty))
        case "d2-search-failed": return AnyView(D2Fixture(screen: .searchFailed))
        case "d2-search-offline": return AnyView(D2Fixture(screen: .searchOffline))
        case "d2-square": return AnyView(D2Fixture(screen: .square))
        case "d2-square-empty": return AnyView(D2Fixture(screen: .squareEmpty))
        case "d2-play": return AnyView(D2Fixture(screen: .play))
        case "d2-city": return AnyView(D2Fixture(screen: .city))
        case "d2-npc": return AnyView(D2Fixture(screen: .npc))
        case "d2-inbox": return AnyView(D2Fixture(screen: .inbox))
        case "d2-inbox-empty": return AnyView(D2Fixture(screen: .inboxEmpty))
        case "d2-inbox-error": return AnyView(D2Fixture(screen: .inboxError))
        case "d2-inbox-signed-out": return AnyView(D2Fixture(screen: .inboxSignedOut))
        case "d2-inbox-loading": return AnyView(D2Fixture(screen: .inboxLoading))
        case "nearby-empty": return AnyView(NearbyTeamFixtureRoot(emptyMine: true).themeDomain(.player))
        case "d2-me": return AnyView(D2Fixture(screen: .me))
        case "d2-roam": return AnyView(D2Fixture(screen: .roam))
        // Wave 3 B2: Today card tap with a self-playing synthetic finger (loops every 2.6 s).
        case "wave-today-roam": return AnyView(WaveTodayFixture(kind: .roam))
        case "wave-today-ticket": return AnyView(WaveTodayFixture(kind: .ticket))
        case "wave-today-club": return AnyView(WaveTodayFixture(kind: .club))
        case "e5b-unlock": return AnyView(E5bMomentFixture(kind: .unlock))
        case "e5b-stamp": return AnyView(E5bMomentFixture(kind: .stamp))
        case "e5b-checkin": return AnyView(E5bMomentFixture(kind: .checkIn))
        case "e5b-badge-wall": return AnyView(E5bBadgeWallFixture())
        case "a11y-roam-ax5": return AnyView(A11yRoamAX5Fixture())
        case "a11y-badges-ax5": return AnyView(A11yBadgesAX5Fixture())
        case "a11y-passport-ax5": return AnyView(A11yPassportAX5Fixture())
        case "e5b-join": return AnyView(E5bJoinFixture())
        // Activity detail collapse (W3-3): synthetic ActivityFixtureReader data, pinned pill on.
        case "activity-collapsed": return AnyView(NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .reviews), registrationEnabled: true) })
        case "activity-expanded": return AnyView(NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .reviews), registrationEnabled: true, startsWithMoreInfoOpen: true) })
        case "activity-unknown": return AnyView(NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .tickets), registrationEnabled: true) })
        // Four-tab IA (W1-1 / W1-4 / W3-6): synthetic data only.
        case "ia-tabs": return AnyView(IATabsFixture())
        case "ia-explore-create": return AnyView(IAExploreCreateFixture(hasPublishingSession: true))
        case "ia-explore-no-create": return AnyView(IAExploreCreateFixture(hasPublishingSession: false))
        case "ia-passport": return AnyView(IAPassportFixture(count: 3, badges: [PassportBadge(id: 0, name: iaFixtureText("Night Owl", "夜猫子")), PassportBadge(id: 1, name: iaFixtureText("First Roam", "第一次漫游")), PassportBadge(id: 2, name: iaFixtureText("Market Regular", "菜场常客"))], badgeTotal: 12))
        case "ia-passport-no-badges": return AnyView(IAPassportFixture(count: 3, badges: []))
        case "ia-passport-unknown": return AnyView(IAPassportFixture(count: nil))
        case "ia-passport-ax5": return AnyView(IAPassportFixture(count: 3, badges: [PassportBadge(id: 0, name: iaFixtureText("Night Owl", "夜猫子")), PassportBadge(id: 1, name: iaFixtureText("First Roam", "第一次漫游"))]).environment(\.dynamicTypeSize, .accessibility5))
        case "ia-deeplinks": return AnyView(IADeepLinksFixture())
        case "welcome": return AnyView(WelcomeFixture())
        case "welcome-menu": return AnyView(WelcomeMenuFixture())
        case "onboarding-1": return AnyView(OnboardingFixture(step: .welcome))
        case "onboarding-2": return AnyView(OnboardingFixture(step: .roam))
        case "onboarding-3": return AnyView(OnboardingFixture(step: .stamps))
        case "onboarding-4": return AnyView(OnboardingFixture(step: .clubs))
        case "onboarding-5": return AnyView(OnboardingFixture(step: .consent))
        case "onboarding-zh-1": return AnyView(OnboardingFixture(step: .welcome, zhHans: true))
        case "onboarding-zh-2": return AnyView(OnboardingFixture(step: .roam, zhHans: true))
        case "onboarding-zh-3": return AnyView(OnboardingFixture(step: .stamps, zhHans: true))
        case "onboarding-zh-4": return AnyView(OnboardingFixture(step: .clubs, zhHans: true))
        case "onboarding-zh-5": return AnyView(OnboardingFixture(step: .consent, zhHans: true))
        case "onboarding-ax": return AnyView(OnboardingFixture(step: .consent, accessibility: true))
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
        // r4 · club workbench head (`170:1744`): the owner fixture on the 管理 tab (counts unread → "—").
        case "d4-tab-manage": return AnyView(D4ClubFixture(.tab(.manage)))
        case "d4-members": return AnyView(D4ClubFixture(.members))
        case "d4-confirm": return AnyView(D4ClubFixture(.confirm))
        case "d4-settings": return AnyView(D4MeFixture(screen: .settings))
        case "d4-growth": return AnyView(D4MeFixture(screen: .growth))
        case "d4-growth-failure": return AnyView(D4MeFixture(screen: .growthFailure))
        case "d4-growth-offline": return AnyView(D4MeFixture(screen: .growthOffline))
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
        case "d4-ops-facts": return AnyView(D4ClubOpsFixture(screen: .operationsFacts(unknown: false)))
        case "d4-ops-facts-unknown": return AnyView(D4ClubOpsFixture(screen: .operationsFacts(unknown: true)))
        case "d4-event-ops": return AnyView(D4ClubOpsFixture(screen: .eventOps(emptySeries: false)))
        case "d4-event-ops-empty": return AnyView(D4ClubOpsFixture(screen: .eventOps(emptySeries: true)))
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
        // mp-roam r3: 漫游记录 (subpackageRoam/history) content / empty / error states for the sweep.
        case "r3-roam-history": return AnyView(NavigationStack { RoamHistoryView(reader: RoamExperienceFixtureReader(scenario: .content), toolsReader: RoamPassportToolsFixtureReader(scenario: .content)) })
        case "r3-roam-history-empty": return AnyView(NavigationStack { RoamHistoryView(reader: RoamExperienceFixtureReader(scenario: .empty)) })
        case "r3-roam-history-error": return AnyView(NavigationStack { RoamHistoryView(reader: RoamExperienceFixtureReader(scenario: .failure)) })
        // mp-roam r3: 本次漫游 (scene-roam-session) content / not-found / error states for the sweep.
        case "r3-roam-session": return AnyView(NavigationStack { RoamHistoryDetailView(reader: RoamExperienceFixtureReader(scenario: .content), timestamp: 1_700_000_000_000) })
        case "r3-roam-session-missing": return AnyView(NavigationStack { RoamHistoryDetailView(reader: RoamExperienceFixtureReader(scenario: .content), timestamp: 1) })
        case "r3-roam-session-error": return AnyView(NavigationStack { RoamHistoryDetailView(reader: RoamExperienceFixtureReader(scenario: .failure), timestamp: 1_700_000_000_000) })
        // mp-roam r3: 集邮册 (scene-roam-stamp-album) empty / error states for the sweep (content = e2-stamp-album).
        case "r3-roam-stamp-album-empty": return AnyView(NavigationStack { RoamStampAlbumView(reader: RoamExperienceFixtureReader(scenario: .empty)) })
        case "r3-roam-stamp-album-error": return AnyView(NavigationStack { RoamStampAlbumView(reader: RoamExperienceFixtureReader(scenario: .failure)) })
        // mp-roam r3: 官方线路 (subpackageRoam/official-routes) list / empty / error on the shipping map-home list.
        case "r3-roam-routes": return RoamR3RoutesFixture.make(.content)
        case "r3-roam-routes-empty": return RoamR3RoutesFixture.make(.empty)
        case "r3-roam-routes-error": return RoamR3RoutesFixture.make(.failure)
        case "r3-roam-route": return RoamR3RoutesFixture.makeDetail(.content)
        case "r3-roam-route-error": return RoamR3RoutesFixture.makeDetail(.failure)
        case "r3-roam-route-notfound": return RoamR3RoutesFixture.makeDetail(.notFound)
        // mp-roam r3: 地点详情 (subpackageRoam/poi-detail → scene-roam-poi-detail) node card / error / unavailable / missing.
        case "r3-roam-poi": return RoamR3PoiFixture.make(.content)
        case "r3-roam-poi-error": return RoamR3PoiFixture.make(.failure)
        case "r3-roam-poi-unavailable": return RoamR3PoiFixture.make(.unavailable)
        case "r3-roam-poi-missing": return RoamR3PoiFixture.make(.missing)
        case "d6-search": return AnyView(D6MapFixture(kind: .search))
        case "d6-live": return AnyView(D6MapFixture(kind: .live))
        // REAL RoamLiveSessionView on the synthetic RoamLiveFixture controller (offline example, no GPS/network).
        case "d6-real-live": return AnyView(D6RealLiveHost())
        // E2 play / city / stamps / badges (E2Fixtures + aliases of D4 stamp and badge hosts)
        case let n where n.hasPrefix("e2-") && E2FixtureKind(rawValue: String(n.dropFirst(3))) != nil:
            return AnyView(E2Fixture(kind: E2FixtureKind(rawValue: String(n.dropFirst(3)))!))
        case "e2-stamp-album": return AnyView(D4MeFixture(screen: .stamps))
        case "e2-badges": return AnyView(D4MeFixture(screen: .badges))
        case "e2-city": return AnyView(D2Fixture(screen: .city))
        case "e2-npc": return AnyView(D2Fixture(screen: .npc))
        // D7 creator / publish (PublishDesignFixtures)
        case "rep3-activity-detail", "rep3-activity-detail-error":
            return E1Fixture.make(name) ?? AnyView(EmptyView())
        case "rep3-task-play", "rep3-task-play-offline":
            return E2FixtureKind(rawValue: name).map { AnyView(E2Fixture(kind: $0)) } ?? AnyView(EmptyView())
        case let n where PublishDesignFixtures.make(n) != nil: return PublishDesignFixtures.make(n)!
        case let n where n.hasPrefix("e1-") && E1Fixture.make(n) != nil: return E1Fixture.make(n)!
        // W1-5 pass card lab: ui-pass-card[-pending|-used|-expired|-empty|-error] (cases live in E1Fixtures.swift)
        case let n where n.hasPrefix("ui-pass-card") && E1Fixture.make(n) != nil: return E1Fixture.make(n)!
        case let n where n.hasPrefix("e3-") && E3Fixtures.make(n) != nil: return E3Fixtures.make(n)!
        // HERO collection album (AlbumFixtures): album-kit, album-stamps[-empty], album-badges[-new|-locked], album-cards, album-unlock
        case let n where n.hasPrefix("album-") && AlbumFixtures.make(n) != nil: return AlbumFixtures.make(n)!
        // Glass carousel (CarouselFixtures): carousel-events, carousel-tickets, carousel-empty, carousel-loading, carousel-ax
        case let n where n.hasPrefix("carousel-") && CarouselFixtures.make(n) != nil: return CarouselFixtures.make(n)!
        // Club photo cards (ClubCardFixtures): clubcards-home, clubcards-directory, clubcards-states, clubcards-strip, clubcards-ax
        case let n where n.hasPrefix("clubcards-") && ClubCardFixtures.make(n) != nil: return ClubCardFixtures.make(n)!
        // HERO roam (RoamFixtures): roam-go, roam-walking, roam-reveal, roam-sheet-half, roam-paused
        case let n where n.hasPrefix("roam-") && RoamFixtures.make(n) != nil: return RoamFixtures.make(n)!
        case let n where n.hasPrefix("member-popup-") && MemberAreaPopupFixtures.make(n) != nil:
            return MemberAreaPopupFixtures.make(n)!
        // Pop-up parity fixtures (PopupsSocialFixtures): popups-*
        case let n where n.hasPrefix("popups-") && PopupsSocialFixtures.make(n) != nil: return PopupsSocialFixtures.make(n)!
        default:
            if let r3prb = MainActor.assumeIsolated({ FixR3PlayRoamBFixtures.make(name) }) { return r3prb }
            if let t5 = MainActor.assumeIsolated({ T5PageFixtures.make(name) }) { return t5 }
            if let gap = MainActor.assumeIsolated({ CoreGapPageFixtures.make(name) }) { return gap }
            if let e4 = MainActor.assumeIsolated({ E4Fixtures.make(name) }) { return e4 }
            if let e4p = MainActor.assumeIsolated({ E4PurchaseFixtures.make(name) }) { return e4p }
            if let e4l = MainActor.assumeIsolated({ E4LoadingFixtures.make(name) }) { return e4l }
            if let e4c = MainActor.assumeIsolated({ E4CelebrationFixtures.make(name) }) { return e4c }
            if let perm = MainActor.assumeIsolated({ E2PermissionPrimerFixtures.make(name) }) { return perm }
            if let d3 = MainActor.assumeIsolated({ OrdersWalletFixtures.make(name) }) { return d3 }
            if let e5 = MainActor.assumeIsolated({ E5Fixtures.make(name) }) { return e5 }
            if let e5c = MainActor.assumeIsolated({ E5cFixtures.make(name) }) { return e5c }
            if let qr = MainActor.assumeIsolated({ QRScanFixtures.make(name) }) { return qr }
            // G1 / G7-G8 / parity-b player views on a synthetic transport (GParityFixtures): g-<view>[-<non-happy state>]
            if let g = MainActor.assumeIsolated({ GParityFixtures.make(name) }) { return g }
            // Handovers 59–62: error sentences, permission primers, compliance pages, search filters.
            if let cur6 = MainActor.assumeIsolated({ CurFixtures6.make(name) }) { return cur6 }
            if let preview = MainActor.assumeIsolated({ IMRecipientPreviewFixtures.make(name) }) { return preview }
            if name.hasPrefix("cur9-"), let cur9 = Cur9Fixtures.make(name) { return cur9 }
            if name.hasPrefix("cur4-"), let cur4 = Cur4Fixtures.make(name) { return cur4 }
            if name.hasPrefix("play-popup-"), let popup = PlayAreaPopupFixtures.make(name) { return popup }
            if name.hasPrefix("play-close-popup-"), let popup = PlayAreaPopupCloseFixtures.make(name) { return popup }
            // Batch-7 screens whose view types compile on this base (CurFixtures3): cur3-<view>[-<state>][-zh]
            if let cur3 = MainActor.assumeIsolated({ CurFixtures3.make(name) }) { return cur3 }
            if name.hasPrefix("cur3-"), let cur3 = Cur3Fixtures.make(name) { return cur3 }
            if name.hasPrefix("merchant-popup-"),
               let popupFixture = MainActor.assumeIsolated({ MerchantAreaPopupFixtures.make(name) }) {
                return popupFixture
            }
            if name.hasPrefix("merchant-close-popup-"),
               let popupFixture = MainActor.assumeIsolated({ MerchantAreaPopupCloseFixtures.make(name) }) {
                return popupFixture
            }
            // parity-a, G6, mount-g45, be-gap and external-game screens (CurFixtures2): cur2-<view>[-<non-happy state>]
            if let cur2 = MainActor.assumeIsolated({ CurFixtures2.make(name) }) { return cur2 }
            // Workshop v2, WP-07, WP-08, and the other screens whose types compile on this base (CurFixtures5).
            if let cur5 = MainActor.assumeIsolated({ CurFixtures5.make(name) }) { return cur5 }
            if name.hasPrefix("cur7-"), let cur7 = Cur7Fixtures.make(name) { return cur7 }
            if name.hasPrefix("cur8-"), let cur8 = CurFixtures8.make(name) { return cur8 }
            if name.hasPrefix("ugc-"), let ugc = UGCSafetyFixtures.make(name) { return ugc }
            if name.hasPrefix("premerge-"), let premerge = PremergeChineseFixtures.make(name) { return premerge }
            if name.hasPrefix("hfeat-"), let hfeat = NewFeatureFixtures.make(name) { return hfeat }
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
        case "e4-auth-phone": return wrap(E4AuthPhoneFixture(stage: .codeSent))
        case "e4-auth-phone-error": return wrap(E4AuthPhoneFixture(stage: .wrongCode))
        case "e4-login": return wrap(E4LoginFixture(error: nil, working: false))
        case "e4-login-error": return wrap(E4LoginFixture(error: "auth.loginRejected", working: false))
        case "e4-settings": return wrap(E4SettingsFixture(query: ""))
        case "e4-settings-search": return wrap(E4SettingsFixture(query: Locale.current.language.languageCode?.identifier == "zh" ? "隐私" : "privacy"))
        case "e4-deregister": return wrap(E4ComplianceFixture(kind: .deregisterReview))
        case "e4-deregister-blocked": return wrap(E4ComplianceFixture(kind: .deregisterBlocked))
        case "e4-marketing": return wrap(E4ComplianceFixture(kind: .marketing))
        case "e4-tickets": return wrap(TicketWalletFixtureHostView())
        // mp-mine r3 (Next round 3): MP signup empty / error / no-permission shells, one action each.
        case "e4-tickets-empty": return wrap(TicketWalletFixtureHostView(scenario: .empty))
        case "e4-tickets-error": return wrap(TicketWalletFixtureHostView(scenario: .failure))
        case "e4-tickets-guest": return wrap(TicketWalletFixtureHostView(scenario: .guest))
        case "e4-profile-edit": return wrap(ProfileEditFixtureHost(scenario: "success"))
        case "e4-profile-edit-error": return wrap(ProfileEditFixtureHost(scenario: "rejected"))
        case "e4-settings-support": return wrap(SettingsFixtureHostView())
        case "e4-about":
            return wrap(NavigationStack { SettingsAboutView(market: RegionalLaunchConfiguration.market, appInformation: .current(), legalReader: SettingsFixtureLegalReader(scenario: "content")) })
        case "e4-privacy": return wrap(OwnMediaFixtureHost(scenario: "ready"))
        case "e4-favorites": return wrap(TopicUnlikeFixtureHost(scenario: "ready"))
        case "e4-collection": return wrap(AccountCollectionFixtureHostView())
        case "e4-creator-apply": return wrap(PublisherLifecycleFixtureRoot(creatorOnly: true))
        case "e4-complaint": return wrap(ProfileComplaintPreparationFixtureView(scenario: "content"))
        // mp-mine r3 (01:10 sweep): the 我的 root in MP structure, on 关于 (当前权益), not a card + benefits without tabs.
        case "e4-member": return wrap(D2MeFixture(initialTab: .about))
        case "e4-participants": return wrap(ParticipantFixtureHostView())
        case "e4-self-projects": return wrap(ProfileSelfProjectsFixtureHost(scenario: "content"))
        case "e4-self-growth": return wrap(ProfileSelfGrowthFixtureHost(scenario: "content"))
        case "e4-self-medals": return wrap(ProfileSelfMedalsFixtureHost(scenario: "content", showsTestControls: false))
        case "e4-template-mine": return wrap(TemplateAuthoringFixtureHostView())
        case "e4-wallet-income": return wrap(WalletCommerceFixtureHost(designPage: "income"))
        case "e4-wallet-income-empty": return wrap(WalletCommerceFixtureHost(designPage: "income", stateArguments: ["--wallet-paged-ledger-empty"]))
        case "e4-wallet-points": return wrap(WalletCommerceFixtureHost(designPage: "points"))
        case "e4-wallet-points-empty": return wrap(WalletCommerceFixtureHost(designPage: "points", stateArguments: ["--wallet-paged-ledger-empty"]))
        case "e4-wallet-points-error": return wrap(WalletCommerceFixtureHost(designPage: "points", stateArguments: ["--wallet-paged-ledger-recover"]))
        case "e4-wallet-balance": return wrap(WalletCommerceFixtureHost(designPage: "balance"))
        // mp-mine r3 (Next round 3): ledger empty and error (first read fails, 重试 recovers) for the sweep.
        case "e4-wallet-balance-empty": return wrap(WalletCommerceFixtureHost(designPage: "balance", stateArguments: ["--wallet-ledger-empty"]))
        case "e4-wallet-balance-error": return wrap(WalletCommerceFixtureHost(designPage: "balance", stateArguments: ["--wallet-ledger-recover"]))
        case "e4-wallet-assets": return wrap(WalletCommerceFixtureHost(designPage: "assets"))
        case "e4-wallet-analysis": return wrap(WalletCommerceFixtureHost(designPage: "analysis"))
        case "e4-wallet-bank": return wrap(WalletCommerceFixtureHost(designPage: "bank"))
        case "e4-wallet-withdrawals": return wrap(WalletCommerceFixtureHost(designPage: "withdrawals"))
        case "e4-wallet-tasks": return wrap(WalletCommerceFixtureHost(designPage: "tasks"))
        default: return T12T13DesignFixtures.make(name)
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player))
    }
}
#endif

#if DEBUG
/// Real PhoneSignInForm with stub values (no network, no coordinator). Labelled DEBUG.
/// The Apple button is shown here only to judge the layout; production gates it on a verified Apple configuration.
struct E4AuthPhoneFixture: View {
    enum Stage { case codeSent, wrongCode }
    let stage: Stage
    @State private var phone = "13812345678"
    @State private var code: String
    init(stage: Stage) {
        self.stage = stage
        _code = State(initialValue: stage == .codeSent ? "482" : "482913")
    }
    var body: some View {
        NavigationStack {
            PhoneSignInForm(phone: $phone, code: $code, smsSent: true,
                            issueKey: stage == .wrongCode ? "auth.channels.rejected" : nil,
                            cooldown: stage == .codeSent ? 42 : 0, canStart: false, hasSentBefore: true, showsApple: true,
                            onAgreement: {}, onPrivacy: {}) {
                SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                    .signInWithAppleButtonStyle(.white).frame(minHeight: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") {} } }
        }
    }
}

/// Real LoginView with stub username, error and working state injected through its DEBUG override.
struct E4LoginFixture: View {
    let error: String?
    let working: Bool
    @StateObject private var session = AppSession()
    var body: some View {
        var view = LoginView(intent: .player)
        view.designOverride = .init(showsPassword: false, username: "", errorKey: error, working: working)
        return view.environmentObject(session)
    }
}

/// Real SettingsView, signed in as a stub member (account card) and optionally with a search query.
struct E4SettingsFixture: View {
    let query: String
    @StateObject private var session = AppSession()
    var body: some View {
        var view = SettingsView()
        // Same member as d2-me / e4-member, in the UI language (00:10 sweep: "Mia Chen" Lv.7 beside 示例会员 Lv.3).
        view.designOverride = .init(nickname: iaFixtureText("Synthetic member", "示例会员"), level: 3, query: query)
        return view.environmentObject(session).environmentObject(NativeOriginalUnreadBadgeState())
    }
}

@MainActor private struct E4StubTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { throw APIError.httpStatus(503) }
}

/// Account deregistration and marketing consent: the REAL AccountComplianceSheet on a real (inert) coordinator,
/// with the view model's state stubbed by this host. No session, no network, nothing is written.
struct E4ComplianceFixture: View {
    enum Kind { case deregisterReview, deregisterBlocked, marketing }
    let kind: Kind
    @State private var model: ComplianceViewModel?
    private static let impactJSON = #"""
    {"schemaVersion":1,"actorId":1,"revision":"3f1c9a7be25d48a09c6d1e77b0a4f5c2d8e9a1b3c4d5e6f708192a3b4c5d6e7f",
     "items":[
      {"key":"POINTS","value":"1280","source":"wallet","effect":"Your points are removed and cannot be restored."},
      {"key":"ACTIVE_ORDERS","value":"0","source":"orders","effect":"No open orders, so nothing is held back."},
      {"key":"COLLECTIBLES","value":"14","source":"stamps","effect":"Stamps and badges are removed from the account."},
      {"key":"CLUB_MEMBERSHIPS","value":"3","source":"clubs","effect":"You leave all three clubs. Chats you wrote stay, without your name."}],
     "unknownCoverage":[]}
    """#
    @MainActor private func makeModel() -> ComplianceViewModel {
        let config = try! APIConfiguration(baseURL: URL(string: "https://fixture.example")!)
        let transport = E4StubTransport()
        let journal = ComplianceFileJournal(url: FileManager.default.temporaryDirectory.appendingPathComponent("e4-compliance-fixture.json"))
        let service = AccountComplianceService(configuration: config, transport: transport, journal: journal, current: { nil }, token: { nil })
        let coordinator = AccountComplianceCoordinator(service: service, auth: AuthChannelService(configuration: config, transport: transport),
                                                       effects: DormantComplianceRoamEffects(), current: { nil }, invalidateSession: { _ in })
        let m = ComplianceViewModel(coordinator, isDeregistration: kind != .marketing, isMarketing: kind == .marketing)
        var state = ComplianceState()
        switch kind {
        case .deregisterReview:
            state.step = .review
            state.localCancellationConsent = .none
            state.status = try? JSONDecoder().decode(ComplianceDeregistration.self, from: Data(("{\"status\":\"ELIGIBLE\",\"impact\":" + Self.impactJSON + "}").utf8))
        case .deregisterBlocked:
            state.step = .blocked
            state.localCancellationConsent = .none
            state.status = try? JSONDecoder().decode(ComplianceDeregistration.self, from: Data(#"{"status":"BLOCKED","blockers":["You still own one club. Hand it over or close it first.","A refund of 38.00 is still pending."]}"#.utf8))
        case .marketing:
            state.marketingLoaded = true; state.marketingCurrentConfirmed = true
            let rows = #"[{"merchantRowId":2,"merchantOwnerMemberId":3,"merchantName":"Old Town Tea House","inAppOptedIn":true,"couponOptedIn":false},{"merchantRowId":5,"merchantOwnerMemberId":9,"merchantName":"Riverside Bookshop","inAppOptedIn":false,"couponOptedIn":true}]"#
            state.marketing = (try? JSONDecoder().decode([ComplianceMarketingConsent].self, from: Data(rows.utf8))) ?? []
        }
        m.state = state
        return m
    }
    var body: some View {
        NavigationStack {
            if let model {
                AccountComplianceSheet(designModel: model, destination: kind == .marketing ? .marketing : .cancellation, market: .china,
                                       legalReader: SettingsFixtureLegalReader(scenario: "content"))
            }
        }
        .onAppear { if model == nil { model = makeModel() } }
    }
}
// MARK: core-gap page fixtures (kept in this file so no project file change is needed)

/// Order info, points history, invite history and nearby merchants over the Core page models.
/// DEBUG only, synthetic data. `--design-fixture core-order-info | core-order-info-unknown | core-points-history
/// | core-invite-history[-partial|-zero|-unavailable] | core-nearby-merchant | core-nearby-merchant-empty | core-club-tab-facts | core-club-tab-unknown`.
enum CoreGapPageFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "core-order-info": return AnyView(OrderLifecycleFixtureHostView(scenario: .paid))
        // The expired scenario carries no amount or times: every unknown is an em dash, never 0.
        case "core-order-info-unknown": return AnyView(OrderLifecycleFixtureHostView(scenario: .expired))
        case "core-points-history": return AnyView(WalletCommerceFixtureHost(designPage: "points"))
        case "core-invite-history": return AnyView(ProfileInviteRewardReviewFixtureHost(scenario: "complete"))
        case "core-invite-history-partial": return AnyView(ProfileInviteRewardReviewFixtureHost(scenario: "partial"))
        case "core-invite-history-zero": return AnyView(ProfileInviteRewardReviewFixtureHost(scenario: "zero"))
        case "core-invite-history-unavailable": return AnyView(ProfileInviteRewardReviewFixtureHost(scenario: "unavailable"))
        // Club tab over the raw home body: known facts, and a body that omits counts (em dash).
        case "core-club-tab-facts": return AnyView(ClubFixtureRootView(scenario: .tabFacts))
        case "core-club-tab-empty": return AnyView(ClubFixtureRootView(scenario: .empty))
        case "core-club-tab-unknown": return AnyView(ClubFixtureRootView(scenario: .tabUnknown))
        case "core-nearby-merchant": return AnyView(CoreGapNearbyFixtureHost(empty: false))
        case "core-nearby-merchant-empty": return AnyView(CoreGapNearbyFixtureHost(empty: true))
        default: return nil
        }
    }
}

@MainActor private final class CoreGapNearbyFixtureReader: CoopFlowReading {
    let session: CoopFlowSession? = try? CoopFlowSession(accountID: 101, epoch: 1, token: "synthetic-nearby")
    let empty: Bool
    init(empty: Bool) { self.empty = empty }
    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        if empty { return .array([]) }
        // One row with a distance, one without (no distance line), one literal 0 m.
        return .array([
            .object(["id": .id(1), "memberId": .id(41), "name": .string("Synthetic cafe"), "address": .string("1 Fixture Road"), "distance": .string("350")]),
            .object(["id": .id(2), "name": .string("Synthetic studio"), "address": .string("2 Fixture Road")]),
            .object(["id": .id(3), "memberId": .id(43), "name": .string("Synthetic arcade"), "distance": .string("0")])
        ])
    }
    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement { throw CoopFlowFailure.unavailable }
}
@MainActor private final class CoreGapNearbyFixtureLocation: RoamDeviceLocationProviding {
    func currentFix() async throws -> RoamDeviceFix { try RoamDeviceFix(coordinate: RoamCoordinate(latitude: 31.2, longitude: 121.4)!, accuracyMeters: 10, measuredAt: Date(), datum: .gcj02) }
    func stop() {}
}
@MainActor private struct CoreGapNearbyFixtureHost: View {
    @State private var model: NearbyMerchantCoordinator
    init(empty: Bool) {
        _model = State(initialValue: NearbyMerchantCoordinator(reader: CoreGapNearbyFixtureReader(empty: empty), location: CoreGapNearbyFixtureLocation(), approved: { true }))
    }
    var body: some View { NavigationStack { NearbyMerchantView(model: model) } }
}

// MARK: T5 fixtures (DEBUG only, strictly offline synthetic data)

enum T5PageFixtures {
    /// Fixture data follows the UI language (coordinator 19:15: no Chinese data in the English UI).
    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }
    private static let samplePass = PassProductCard(
        id: "t5-pass-1",
        name: tt("Hangzhou Old Town 3-Walk Pass", "杭州老城三游通票"),
        kind: .cityBundle,
        city: tt("Hangzhou", "杭州"),
        validity: .daysAfterPurchase(30),
        seats: 2,
        cashPriceText: "¥168.00",
        pointsPrice: 1200,
        topics: ["88", "89", "90"],
        giftAllowed: true,
        giftOnly: false,
        isExtraSeat: false,
        faceText: tt("HZ", "杭城通")
    )

    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "t5-baoming": return wrapPlayer(RegistrationFixtureHostView(scenario: .standard, hidesFixtureNotice: true))
        case "t5-baoming-error": return wrapPlayer(RegistrationFixtureHostView(scenario: .quoteError, hidesFixtureNotice: true))
        case "t5-pricing": return wrapMerchant(T5PublisherPricingFixtureHost(failed: false))
        case "t5-pricing-error": return wrapMerchant(T5PublisherPricingFixtureHost(failed: true))
        case "t5-partner": return wrapMerchant(T5PublisherPartnerFixtureHost(failed: false))
        case "t5-partner-error": return wrapMerchant(T5PublisherPartnerFixtureHost(failed: true))
        case "t5-order-center": return wrapPlayer(T5OrderCenterFixtureHost(failed: false))
        case "t5-order-center-error": return wrapPlayer(T5OrderCenterFixtureHost(failed: true))
        case "t5-free-explore": return wrapPlayer(T5FreeExploreFixtureHost(failed: false))
        case "t5-free-explore-error": return wrapPlayer(T5FreeExploreFixtureHost(failed: true))
        case "t5-pass-market":
            let content = PassMarketContent(
                products: [
                    samplePass,
                    PassProductCard(
                        id: "t5-pass-2",
                        name: tt("West Lake Weekend Pass", "西湖周末限时畅玩卡"),
                        kind: .timedPass,
                        city: tt("Hangzhou", "杭州"),
                        validity: .daysFromFirstPlay(7),
                        seats: nil,
                        cashPriceText: "¥88.00",
                        pointsPrice: nil,
                        topics: ["88"],
                        giftAllowed: false,
                        giftOnly: false,
                        isExtraSeat: false,
                        faceText: tt("7 days", "7日")
                    )
                ],
                orders: [],
                giftsBought: [],
                giftsReceived: []
            )
            return wrapPlayer(NavigationStack {
                PassMarketView(
                    state: PassMarketState(content: .ready(content), pointBalance: 1280, member: .plans(tt("¥19/mo", "¥19/月")), refreshFailed: false),
                    initialTab: .shop,
                    onReload: { _ in },
                    onOpenProduct: { _ in },
                    onOpenMembership: {},
                    onOpenLibrary: nil,
                    pointsDestination: nil
                )
            })
        case "t5-pass-market-points":
            // Integ verify: the balance card with a points destination, so the card → ledger zoom can be checked.
            return wrapPlayer(NavigationStack {
                PassMarketView(
                    state: PassMarketState(content: .ready(PassMarketContent(products: [samplePass], orders: [], giftsBought: [], giftsReceived: [])),
                                           pointBalance: 1280, member: .plans(tt("¥19/mo", "¥19/月")), refreshFailed: false),
                    initialTab: .shop,
                    onReload: { _ in },
                    onOpenProduct: { _ in },
                    onOpenMembership: {},
                    onOpenLibrary: nil,
                    pointsDestination: { AnyView(WalletLedgerPointsFixturePage()) }
                )
            })
        case "t5-pass-market-error":
            return wrapPlayer(NavigationStack {
                PassMarketView(
                    state: PassMarketState(content: .failed("Offline load error"), pointBalance: nil, member: nil, refreshFailed: false),
                    initialTab: .shop,
                    onReload: { _ in },
                    onOpenProduct: { _ in },
                    onOpenMembership: {},
                    onOpenLibrary: nil,
                    pointsDestination: nil
                )
            })
        case "t5-pass-detail":
            let checkout = [
                PassCheckoutRow(kind: .price, valueText: "¥168.00", note: nil, off: false),
                PassCheckoutRow(kind: .cash, valueText: "¥168.00", note: nil, off: false),
                PassCheckoutRow(kind: .points, valueText: "1200", note: "示例积分报价", off: false)
            ]
            let detail = PassDetailState(
                product: .ready(samplePass),
                forGift: false,
                buy: .buyable(
                    payModes: [PassPayMode(mode: .cash, amountText: "¥168.00"), PassPayMode(mode: .points, amountText: "1200 积分")],
                    cashReason: nil
                ),
                checkout: checkout,
                unlockSteps: [],
                giftShare: nil,
                groupQuote: nil,
                activateTopicID: "88"
            )
            return wrapPlayer(NavigationStack {
                PassDetailView(state: detail, onRetry: {}, onSetForGift: { _ in }, onOpenCheckout: { _, _ in }, onResultDone: { _ in })
            })
        case "t5-pass-detail-unavailable":
            let detail = PassDetailState(
                product: .ready(samplePass),
                forGift: false,
                buy: .unavailable(reason: "该渠道暂未开放（预览）"),
                checkout: [PassCheckoutRow(kind: .cash, valueText: "—", note: "暂不支持现金购买", off: true)],
                unlockSteps: [],
                giftShare: nil,
                groupQuote: nil,
                activateTopicID: nil
            )
            return wrapPlayer(NavigationStack {
                PassDetailView(state: detail, onRetry: {}, onSetForGift: { _ in }, onOpenCheckout: { _, _ in }, onResultDone: { _ in })
            })
        case "t5-pass-gift":
            return wrapPlayer(NavigationStack {
                PassGiftClaimView(state: PassGiftClaimState(phase: .ready, claiming: false), onClaim: {}, onOpenGifts: {})
            })
        case "t5-pass-gift-expired":
            return wrapPlayer(NavigationStack {
                PassGiftClaimView(state: PassGiftClaimState(phase: .failed(reason: "赠送链接已失效"), claiming: false), onClaim: {}, onOpenGifts: {})
            })
        case "t5-membership":
            let content = PassMembershipContent(
                active: true,
                untilText: "2026-12-31",
                themeCount: 24,
                plans: [
                    PassPlanCard(code: "Y", priceText: "¥198.00", line: .year(monthlyText: "¥16.50"), best: true),
                    PassPlanCard(code: "M", priceText: "¥28.00", line: .month, best: false)
                ],
                selectedPlan: "Y",
                buyBlock: nil,
                // fix-r3 member-a r2: server `overview.terms` rows (适用范围 + server refund text).
                terms: PlatformPassTermFacts(period: "365 天", refund: "开通后 7 天内未使用可整单退款", seat: "本人及 1 位同行")
            )
            return wrapPlayer(NavigationStack {
                PassMembershipView(phase: .ready(content), onRetry: {}, onSelectPlan: { _ in }, onOpenLibrary: {})
            })
        case "t5-membership-off":
            return wrapPlayer(NavigationStack {
                PassMembershipView(phase: .notEnabled, onRetry: {}, onSelectPlan: { _ in }, onOpenLibrary: nil)
            })
        case "t5-library":
            let cards = [
                PassLibraryCard(id: "88", title: "西湖夜游漫步", coverURL: nil, city: "杭州", kind: .city, minutes: 90, freeWithPass: true),
                PassLibraryCard(id: "89", title: "大运河灯火巡礼", coverURL: nil, city: "杭州", kind: .free, minutes: 60, freeWithPass: false)
            ]
            return wrapPlayer(NavigationStack {
                PassLibraryView(phase: .ready(cards), initialKind: .all, onLoad: { _ in }, onOpenTopic: { _ in })
            })
        case "t5-library-empty":
            return wrapPlayer(NavigationStack {
                PassLibraryView(phase: .ready([]), initialKind: .all, onLoad: { _ in }, onOpenTopic: nil)
            })
        case "t5-seats":
            let seats = JourneySeatsContent(
                headName: "西湖夜游漫步",
                headCoverURL: nil,
                me: JourneyPerson(name: "陈小北", avatarURL: nil),
                showsParty: true,
                occupied: 2,
                seatCount: 4,
                circles: [
                    JourneySeatCircle(no: 1, kind: .me, avatarURL: nil, initial: "陈", tappable: false),
                    JourneySeatCircle(no: 2, kind: .invited, avatarURL: nil, initial: nil, tappable: false),
                    JourneySeatCircle(no: 3, kind: .open, avatarURL: nil, initial: nil, tappable: true),
                    JourneySeatCircle(no: 4, kind: .open, avatarURL: nil, initial: nil, tappable: true)
                ],
                canInvite: true,
                openCount: 2,
                invited: [JourneyInvitedRow(invitationID: "inv-1", no: 2, kind: .invited, expiresText: "剩余23小时", canCancel: true)],
                multi: true,
                tiles: [],
                canGoToStart: true,
                actionError: nil,
                inviteShareURL: nil,
                stopCount: 6,
                estimatedMinutes: 90
            )
            return wrapPlayer(NavigationStack {
                JourneySeatsView(phase: .ready(seats), onRetry: {}, onInvite: {}, onCancel: { _ in }, onStart: {}, onEditMe: {})
            })
        case "t5-seats-error":
            return wrapPlayer(NavigationStack {
                JourneySeatsView(phase: .failed, onRetry: {}, onInvite: {}, onCancel: { _ in }, onStart: {}, onEditMe: {})
            })
        case "t5-settle":
            let report = JourneyReport(
                legacy: false,
                result: .legitimate,
                dateLabel: "2026-11-14",
                nodesText: "5/5",
                elapsedText: "48:20",
                score: 960,
                rank: 3,
                rankBasisCount: 5,
                penaltyText: nil,
                rewardItems: 2,
                runID: "run-1",
                topicID: "88",
                activityID: "12",
                coverURL: nil,
                nodes: [],
                finished: true,
                inProgress: false
            )
            return wrapPlayer(NavigationStack {
                JourneySettleView(
                    phase: .ready(report),
                    rank: JourneyRankState(),
                    rate: .idle,
                    shareURL: nil,
                    topicName: mpJourneyFixtureText("West Lake Night Walk", "西湖夜游漫步"),
                    onRetry: {},
                    onSignIn: {},
                    onLoadRank: {},
                    onRankScope: { _ in },
                    onRankPeriod: { _ in },
                    onSubmitRating: { _, _ in },
                    onDone: {}
                )
            })
        case "t5-settle-error":
            return wrapPlayer(NavigationStack {
                JourneySettleView(
                    phase: .failed(gone: false),
                    rank: JourneyRankState(),
                    rate: .idle,
                    shareURL: nil,
                    topicName: nil,
                    onRetry: {},
                    onSignIn: {},
                    onLoadRank: {},
                    onRankScope: { _ in },
                    onRankPeriod: { _ in },
                    onSubmitRating: { _, _ in },
                    onDone: {}
                )
            })
        default: return nil
        }
    }

    @MainActor private static func wrapPlayer<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground())
    }

    @MainActor private static func wrapMerchant<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.merchant).cyDomainPageBackground().preferredColorScheme(.light))
    }
}

private actor T5PublisherFixtureTransport: HTTPTransport {
    let failedPricing: Bool
    let failedPartner: Bool
    init(failedPricing: Bool = false, failedPartner: Bool = false) {
        self.failedPricing = failedPricing
        self.failedPartner = failedPartner
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.lastPathComponent ?? ""
        if failedPricing && path == "preview" {
            return (Data(#"{"code":500,"msg":"Offline pricing error"}"#.utf8), 500)
        }
        if failedPartner && (path == "detail" || path == "public-detail") {
            return (Data(#"{"code":500,"msg":"Offline partner error"}"#.utf8), 500)
        }
        let payload: String
        switch path {
        case "preview":
            payload = #"{"priceMin":12.5,"referencePrice":28.0,"cityReferenceSampleSize":6,"lineup":[{"toType":"club","toId":9,"shareMode":1,"shareRate":20}]}"#
        case "detail", "public-detail":
            payload = #"{"id":9,"name":"Old Town Explorers Club","description":"Partner organizer in synthetic offline fixture"}"#
        default:
            payload = "null"
        }
        return (Data("{\"code\":200,\"msg\":\"ok\",\"data\":\(payload)}".utf8), 200)
    }
}

@MainActor private final class T5PublisherFixtureJournal: OperationPendingJournal {
    var records: [String: OperationPendingRecord] = [:]
    func pending(ownerKey: String, targetKey: String) throws -> OperationPendingRecord? { records[ownerKey + targetKey] }
    func write(_ record: OperationPendingRecord) throws { records[record.ownerKey + record.targetKey] = record }
    func clear(_ record: OperationPendingRecord) throws { records.removeValue(forKey: record.ownerKey + record.targetKey) }
}

@MainActor private enum T5PublisherWiring {
    static func make(failedPricing: Bool = false, failedPartner: Bool = false) -> (PublisherLifecycleHTTP, PublisherLifecycleCoordinator) {
        let config = try! APIConfiguration(baseURL: URL(string: "https://example.com/offline/")!)
        let session = PublishingSession(namespace: "offline-t5", accountID: 7, epoch: UUID(), role: "member", region: .china)
        let credential = try! PublishingCredentials(session: session, token: "offline-token")
        let grant = try! OperationEndpointApproval(
            baseURL: config.baseURL,
            namespace: session.namespace,
            accountID: 7,
            paths: ["api/topic/pricing/preview", "api/club/detail", "api/merchant/public-detail"]
        )
        let client = PublisherLifecycleHTTP(
            configuration: config,
            transport: T5PublisherFixtureTransport(failedPricing: failedPricing, failedPartner: failedPartner),
            grants: .init(reads: grant),
            credentials: { credential }
        )
        let coordinator = PublisherLifecycleCoordinator(client: client, journal: T5PublisherFixtureJournal()) { resource, _ in
            PublisherAuthority(resource: resource, ownerAccountID: 7, revision: "offline-t5", beta: true, eligibleClubIDs: [9])
        }
        return (client, coordinator)
    }
}

@MainActor private struct T5PublisherPricingFixtureHost: View {
    private let client: PublisherLifecycleHTTP
    private let coordinator: PublisherLifecycleCoordinator
    init(failed: Bool) {
        (client, coordinator) = T5PublisherWiring.make(failedPricing: failed)
    }
    var body: some View {
        NavigationStack { PublisherPricingView(topicID: 4, client: client, coordinator: coordinator) }
    }
}

@MainActor private struct T5PublisherPartnerFixtureHost: View {
    private let client: PublisherLifecycleHTTP
    @State private var row: PublisherLineup?
    init(failed: Bool) {
        (client, _) = T5PublisherWiring.make(failedPartner: failed)
    }
    var body: some View {
        NavigationStack {
            if let row {
                PublisherPartnerView(topicID: 4, row: row, client: client)
            } else {
                CYLoadingStateView(rows: 2).padding(CYSpacing.pageHorizontal)
            }
        }
        .task {
            guard row == nil, let input = try? PublisherPricingInput(topicID: 4, subtype: .selfPlay, leadCost: nil, teamSize: nil),
                  let preview = try? await client.pricing(input) else { return }
            row = preview.lineup.first
        }
    }
}

private actor T5OrderCenterTransport: HTTPTransport {
    let failed: Bool
    init(failed: Bool) { self.failed = failed }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        // Fixture payload follows the UI language (coordinator 19:50: no Chinese data in the English UI).
        let zh = Locale.preferredLanguages.first?.hasPrefix("zh") == true
        if failed {
            let error = zh ? #"{"code":404,"msg":"订单不存在"}"# : #"{"code":404,"msg":"Order not found"}"#
            return (Data(error.utf8), 404)
        }
        let json = zh
            ? #"{"code":200,"msg":"ok","data":{"kind":"COMMERCE","id":"42","orderNo":"CY20260001","title":"杭州老城畅玩卡","statusText":"已支付","amountText":"168.00","createdAtText":"2026-11-14 10:00"}}"#
            : #"{"code":200,"msg":"ok","data":{"kind":"COMMERCE","id":"42","orderNo":"CY20260001","title":"Hangzhou Old Town Play Pass","statusText":"Paid","amountText":"168.00","createdAtText":"2026-11-14 10:00"}}"#
        return (Data(json.utf8), 200)
    }
}

@MainActor private struct T5OrderCenterFixtureHost: View {
    @StateObject private var model: OrderCenterEntryModel
    init(failed: Bool) {
        let service = OrderCenterDetailService(
            baseURL: URL(string: "https://example.com/offline/")!,
            transport: T5OrderCenterTransport(failed: failed),
            token: { "offline-fixture-valid-token-value" },
            enabled: { true }
        )
        _model = StateObject(wrappedValue: OrderCenterEntryModel(service: service))
    }
    var body: some View {
        NavigationStack { OrderCenterEntryView(model: model, initialOutTradeNo: "CY20260001") }
    }
}

@MainActor private struct T5FreeExploreFixtureHost: View {
    let failed: Bool
    @State private var model: FreeExploreBundleLaunchModel?
    @MainActor private final class Store: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    @MainActor private final class Wire: FreeExploreLaunchServing {
        let session: FreeExploreLaunchSession
        let failed: Bool
        var isCurrent = true
        var permitsReservationDispatch = false
        init(failed: Bool) throws {
            self.failed = failed
            session = try .init(baseURL: URL(string: "https://example.test")!, accountID: 7, market: "CN", namespace: "t5-fixture",
                                role: "player", epoch: 1, token: "synthetic-token")
        }
        private func decode<T: Decodable>(_ value: Any) throws -> T {
            try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
        }
        func catalog(topicID: FreeExploreLaunchID) async throws -> FreeExploreLaunchCatalog {
            if failed { throw FreeExploreLaunchFailure.response(status: 503, code: 503, businessCode: nil, message: nil) }
            return try decode(["topicId": 88, "topicName": mpJourneyFixtureText("Sample free-explore pass: Hefang Street tea trail", "示例自由探索套票：河坊街茶韵线"), "productType": 2, "saleEnabled": false, "reservationEnabled": true,
                               "items": [["chapterId": 3, "name": mpJourneyFixtureText("Old Town Tea Street chapter", "老城茶街章节"), "unitsPerHolder": 1,
                                          "stores": [["offerId": 29, "merchantName": mpJourneyFixtureText("Qinghefang sample teahouse", "清河坊示范茶馆"), "validEnd": "2026-12-31"]]]]])
        }
        func order(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchOrder {
            try decode(["registrationId": 41, "registrationNo": "CY2026112700041", "paymentStatus": 2, "registrationStatus": 2, "bundle": [
                "order": ["registrationId": 41, "holderMemberId": 7, "topicId": 88],
                "units": [["id": 17, "registrationId": 41, "holderMemberId": 7, "chapterId": 3, "status": "AVAILABLE"]],
                "reservations": []]])
        }
        func reserve(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation { throw FreeExploreLaunchFailure.disabled }
        func receipt(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation? { nil }
        func refundQuote(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchRefundQuote { throw FreeExploreLaunchFailure.disabled }
    }
    var body: some View {
        NavigationStack {
            if let model { FreeExploreBundleLaunchView(model: model) }
        }.task {
            guard model == nil, let wire = try? Wire(failed: failed), let topic = try? FreeExploreLaunchID(88),
                  let registration = try? FreeExploreLaunchID(41) else { return }
            model = try? FreeExploreBundleLaunchModel(topicID: topic, registrationID: registration, service: wire,
                                                      pending: FreeExploreLaunchPendingStore(storage: Store(), session: wire.session), dispatchAllowed: { true })
        }
    }
}

// MARK: T12 + T13 normal + non-happy design fixtures (kept in this file so no project file change is needed)

enum T12T13DesignFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "merchant-orders-empty": return merchant(MerchantFixtureRootView(scenario: .empty))
        case "merchant-projects-empty": return merchant(MerchantFixtureRootView(scenario: .inactive))
        case "merchant-finance-empty": return merchant(MerchantFixtureRootView(scenario: .retry))
        case "t12-aftercare":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .ready), journal: MerchantBusinessMemoryIntentStore(), query: .aftercare(.pending, page: 1)) })
        case "t12-aftercare-denied":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .denied), journal: MerchantBusinessMemoryIntentStore(), query: .aftercare(.pending, page: 1)) })
        case "t12-reviews":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .ready), journal: MerchantBusinessMemoryIntentStore(), query: .reviews(page: 1)) })
        case "t12-reviews-denied":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .denied), journal: MerchantBusinessMemoryIntentStore(), query: .reviews(page: 1)) })
        case "t12-ledger-batches":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .ready), journal: MerchantBusinessMemoryIntentStore(), query: .batches(page: 1)) })
        case "t12-ledger-batches-denied":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .denied), journal: MerchantBusinessMemoryIntentStore(), query: .batches(page: 1)) })
        case "t12-operators":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .ready), journal: MerchantBusinessMemoryIntentStore(), query: .operators) })
        case "t12-operators-denied":
            return merchant(NavigationStack { MerchantBusinessPage(reader: MerchantBusinessFixtureReader(scenario: .denied), journal: MerchantBusinessMemoryIntentStore(), query: .operators) })
        case "t12-operations":
            return merchant(NavigationStack { MerchantOperationsHomeView(reader: operationsReader(denied: false)) })
        case "t12-operations-denied":
            return merchant(NavigationStack { MerchantOperationsHomeView(reader: operationsReader(denied: true)) })
        case "t12-marketing":
            return merchant(MerchantMarketingFixtureHost(scenario: "normal"))
        case "t12-marketing-empty":
            return merchant(MerchantMarketingFixtureHost(scenario: "empty"))
        case "t12-coop-center":
            return merchant(MerchantCoopCenterFixtureHost(scenario: "normal"))
        case "t12-coop-center-empty":
            return merchant(MerchantCoopCenterFixtureHost(scenario: "empty"))
        case "t12-coop-invites":
            return merchant(NavigationStack { CooperationBrowserView(reader: CooperationFixtureReader(scenario: .content)) })
        case "t12-coop-invites-empty":
            return merchant(NavigationStack { CooperationBrowserView(reader: CooperationFixtureReader(scenario: .empty)) })
        case "t12-public-store":
            return merchant(NavigationStack { PublicMerchantHomeView(target: .ownerMemberID(PublicMerchantOwnerID(101)!), context: .init(reader: CoopRelationFixtureReader(scenario: "mixed"))) })
        case "t12-public-store-failed":
            return merchant(NavigationStack { PublicMerchantHomeView(target: .ownerMemberID(PublicMerchantOwnerID(101)!), context: .init(reader: CoopRelationFixtureReader(scenario: "retry"))) })
        case "t13-coop-profit":
            return merchant(NavigationStack { CoopFinanceProfitView(reader: T12T13CoopFlowReader(failed: false)) })
        case "t13-coop-profit-failed":
            return merchant(NavigationStack { CoopFinanceProfitView(reader: T12T13CoopFlowReader(failed: true)) })
        case "t13-withdraw-support":
            return player(NavigationStack { WithdrawalSupportLandingView(reader: walletReader(empty: false)) })
        case "t13-withdraw-support-empty":
            return player(NavigationStack { WithdrawalSupportLandingView(reader: walletReader(empty: true)) })
        case "t13-withdraw-history":
            return player(NavigationStack { WithdrawalHistoryView(reader: walletReader(empty: false)) })
        case "t13-withdraw-history-empty":
            return player(NavigationStack { WithdrawalHistoryView(reader: walletReader(empty: true)) })
        case "t13-organizer":
            return player(NavigationStack { OfficialOrganizerConsoleView(eventID: 88, access: T12T13OrganizerAccess(denied: false)) })
        case "t13-organizer-denied":
            return player(NavigationStack { OfficialOrganizerConsoleView(eventID: 88, access: T12T13OrganizerAccess(denied: true)) })
        case "t13-goals":
            return player(NavigationStack { RoamExplorationGoalsView(tools: RoamPrivateToolsFixture(scenario: .content)) })
        case "t13-goals-empty":
            return player(NavigationStack { RoamExplorationGoalsView(tools: RoamPrivateToolsFixture(scenario: .empty)) })
        default:
            return nil
        }
    }

    @MainActor private static func merchant<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.merchant).cyDomainPageBackground().themeDomain(.merchant).preferredColorScheme(.light))
    }

    @MainActor private static func player<V: View>(_ view: V) -> AnyView {
        // mp-journey r3 (sweep 19:15): player fixtures follow the system appearance, never a forced scheme.
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player))
    }

    @MainActor private static func operationsReader(denied: Bool) -> MerchantOperationsFixtureReader {
        let reader = MerchantOperationsFixtureReader()
        reader.denied = denied
        return reader
    }

    @MainActor private static func walletReader(empty: Bool) -> WalletCommerceReader {
        let scope = WalletCommerceScope(namespace: "t12t13-fixture", accountID: 9002, epoch: UUID())
        let configuration = try! APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let service = WalletCommerceService(configuration: configuration, transport: T12T13WithdrawalTransport(empty: empty))
        return WalletCommerceReader(service: service) { (scope: scope, token: "synthetic-token") }
    }
}

@MainActor private final class T12T13CoopFlowReader: ObservableObject, CoopFlowReading {
    @Published var session: CoopFlowSession? = try? CoopFlowSession(accountID: 101, epoch: 1, token: "synthetic-t13")
    let failed: Bool
    init(failed: Bool) { self.failed = failed }
    func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON {
        if failed { throw CoopFlowFailure.unavailable }
        return .object(["topics": .array([.object([
            "topicId": .id(8), "topicName": .string("示例主办方路线：钱塘江夜跑"),
            "myIncome": .number(128.50), "settled": .bool(true), "myIncomeArrived": .bool(true),
            "totalSales": .number(480), "verifiedSales": .number(420), "platformAmount": .number(42), "merchantTotal": .number(249.5)
        ])])])
    }
    func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement {
        throw CoopFlowFailure.unavailable
    }
}

private struct T12T13WithdrawalTransport: HTTPTransport {
    let empty: Bool
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        switch request.url?.path {
        case "/api/withdrawal/list":
            if empty { return (Data(#"{"code":200,"data":[]}"#.utf8), 200) }
            return (Data(#"{"code":200,"data":[{"id":50,"status":1,"receivedAmount":128.50,"createTime":"2026-10-01 10:00:00"}]}"#.utf8), 200)
        case "/api/user/info":
            if empty { return (Data(#"{"code":500}"#.utf8), 200) }
            return (Data(#"{"code":200,"data":{"balance":"128.50"}}"#.utf8), 200)
        case "/api/wallet/stages":
            if empty { return (Data(#"{"code":500}"#.utf8), 200) }
            return (Data(#"{"code":200,"data":{"pendingSettlement":20,"disputed":0,"withdrawable":128.5,"complaintPeriod":[],"amountsKnown":true}}"#.utf8), 200)
        default:
            return (Data(#"{"code":404}"#.utf8), 404)
        }
    }
}

@MainActor private final class T12T13OrganizerAccess: OfficialOrganizerAccess {
    let accountID: Int? = 808
    let enabled = true
    let denied: Bool
    init(denied: Bool) { self.denied = denied }
    func publishCheck(eventID: Int) async throws -> OfficialOrganizerCheckResult {
        denied ? .denied(nil) : .allowed(.init(known: true, blockers: [], risks: [], risksKnown: true))
    }
    func eventState(eventID: Int) async throws -> OfficialOrganizerEventState? {
        OfficialOrganizerEventState(status: OfficialOrganizerEventState.scheduled, control: .normal, title: "官方示例活动：良渚秋日探索")
    }
    func command(_ command: OfficialOrganizerCommand, mode: OfficialOrganizerCommandMode) async throws -> OfficialOrganizerReceipt? {
        OfficialOrganizerReceipt(requestId: command.requestId, state: .applied, message: "ok")
    }
}
/// mp-journey r3 (sweep 19:15): journey fixture data follows the UI language.
func mpJourneyFixtureText(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}
#endif
