#if DEBUG
import SwiftUI
import AuthenticationServices

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
        // Wave 3 B2: Today card tap with a self-playing synthetic finger (loops every 2.6 s).
        case "wave-today-roam": return AnyView(WaveTodayFixture(kind: .roam))
        case "wave-today-ticket": return AnyView(WaveTodayFixture(kind: .ticket))
        case "wave-today-club": return AnyView(WaveTodayFixture(kind: .club))
        case "e5b-unlock": return AnyView(E5bMomentFixture(kind: .unlock))
        case "e5b-stamp": return AnyView(E5bMomentFixture(kind: .stamp))
        case "e5b-checkin": return AnyView(E5bMomentFixture(kind: .checkIn))
        case "e5b-badge-wall": return AnyView(E5bBadgeWallFixture())
        case "a11y-roam-ax5": return AnyView(A11yRoamAX5Fixture())
        case "a11y-badges-ax5": return AnyView(A11yPassportAX5Fixture())
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
        case "ia-passport": return AnyView(IAPassportFixture(count: 3, badges: [PassportBadge(id: 0, name: "Night Owl"), PassportBadge(id: 1, name: "First Roam"), PassportBadge(id: 2, name: nil)]))
        case "ia-passport-no-badges": return AnyView(IAPassportFixture(count: 3, badges: []))
        case "ia-passport-unknown": return AnyView(IAPassportFixture(count: nil))
        case "ia-passport-ax5": return AnyView(IAPassportFixture(count: 3, badges: [PassportBadge(id: 0, name: "Night Owl"), PassportBadge(id: 1, name: "First Roam")]).environment(\.dynamicTypeSize, .accessibility5))
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
        case "d4-ops-facts": return AnyView(D4ClubOpsFixture(screen: .operationsFacts(unknown: false)))
        case "d4-ops-facts-unknown": return AnyView(D4ClubOpsFixture(screen: .operationsFacts(unknown: true)))
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
        // E2 play / city / stamps / badges (E2Fixtures + aliases of D4 stamp and badge hosts)
        case let n where n.hasPrefix("e2-") && E2FixtureKind(rawValue: String(n.dropFirst(3))) != nil:
            return AnyView(E2Fixture(kind: E2FixtureKind(rawValue: String(n.dropFirst(3)))!))
        case "e2-stamp-album": return AnyView(D4MeFixture(screen: .stamps))
        case "e2-badges": return AnyView(D4MeFixture(screen: .badges))
        case "e2-city": return AnyView(D2Fixture(screen: .city))
        case "e2-npc": return AnyView(D2Fixture(screen: .npc))
        // D7 creator / publish (PublishDesignFixtures)
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
        default:
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
            if let preview = MainActor.assumeIsolated({ IMRecipientPreviewFixtures.make(name) }) { return preview }
            // Workshop v2, WP-07, WP-08, and the other screens whose types compile on this base (CurFixtures5).
            if let cur5 = MainActor.assumeIsolated({ CurFixtures5.make(name) }) { return cur5 }
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
        view.designOverride = .init(nickname: "Mia Chen", level: 7, query: query)
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
#endif
