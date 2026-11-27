import SwiftUI

@main
struct QuestifyApp: App {
    @StateObject private var sessionContainer = AppSessionContainer()
    @AppStorage(AppLanguage.storageKey) private var storedLanguage = RegionalLaunchConfiguration.language(nil).rawValue
    init() {
        MPNotificationTapRouter.shared.attach()
        QuestLiveActivityCenter.shared.endOrphanedActivities()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-reset-language") {
            UserDefaults.standard.set(AppLanguage.system.rawValue,forKey:"preferences.language")
            UserDefaults.standard.removeObject(forKey:"roamLivePurposeAcceptedV1") // tests start on the first-GO consent card
        }
        if ProcessInfo.processInfo.arguments.contains("--uitesting-first-launch-language") {
            UserDefaults.standard.removeObject(forKey:"preferences.language")
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let designFixture = AppStoreScreenshotHarness.mountedFixtureID(arguments: ProcessInfo.processInfo.arguments) ?? fixtureArgument("--design-fixture") {
                    DesignFixtureRegistry.make(designFixture)
                } else if ProcessInfo.processInfo.arguments.contains("--owner-draft-fixture") {
                    OwnerDraftFixtureHost(mode: fixtureArgument("--owner-draft-fixture") ?? "ready")
                } else if ProcessInfo.processInfo.arguments.contains("--ops-safety-fixture") {
                    OpsSafetyFixtureHost(scenario: fixtureArgument("--ops-safety-fixture") ?? "theme")
                } else if ProcessInfo.processInfo.arguments.contains("--group-poll-fixture") {
                    GroupPollFixtureRoot(scenario: fixtureArgument("--group-poll-fixture") ?? "success")
                } else if ProcessInfo.processInfo.arguments.contains("--native-navigation-fixture") {
                    NativeNavigationFixtureView(mode: fixtureArgument("--native-navigation-fixture") ?? "error")
                } else if ProcessInfo.processInfo.arguments.contains("--native-verification-fixture") {
                    NativeVerificationFixtureView(scenario: fixtureArgument("--native-verification-fixture") ?? "success")
                } else if ProcessInfo.processInfo.arguments.contains("--merchant-npc-fixture") {
                    NavigationStack { MerchantNPCFixtureView() }
                } else if ProcessInfo.processInfo.arguments.contains("--merchant-ai-commerce-fixture") {
                    MerchantAICommerceFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--publisher-lifecycle-fixture") {
                    PublisherLifecycleFixtureRoot()
                } else if ProcessInfo.processInfo.arguments.contains("--retained-images-fixture") {
                    RetainedImageFixtureView(mode: fixtureArgument("--retained-images-fixture") ?? "success")
                } else if ProcessInfo.processInfo.arguments.contains("--square-governance-fixture") {
                    SquareGovernanceFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--shop-npc-fixture") {
                    ShopNPCFixtureView(enabled: fixtureArgument("--shop-npc-fixture") == "enabled")
                } else if ProcessInfo.processInfo.arguments.contains("--club-community-fixture") {
                    ClubCommunityFixtureRoot()
                } else if ProcessInfo.processInfo.arguments.contains("--public-merchant-home-fixture") {
                    PublicMerchantHomeFixtureView(scenario: fixtureArgument("--public-merchant-home-fixture") ?? "profile")
                } else if ProcessInfo.processInfo.arguments.contains("--door-referral-fixture") {
                    DoorReferralFixtureView()
                } else if ProcessInfo.processInfo.arguments.contains("--merchant-marketing-fixture") {
                    MerchantMarketingFixtureHost(scenario: fixtureArgument("--merchant-marketing-scenario") ?? "normal", initialSurface: MerchantMarketingCoordinator.Surface(rawValue: fixtureArgument("--merchant-marketing-fixture") ?? "dashboard") ?? .dashboard)
                } else if ProcessInfo.processInfo.arguments.contains("--im-expanded-fixture") {
                    IMExpandedFixtureRoot(scenario: ProcessInfo.processInfo.arguments.last ?? "dormant")
                } else if ProcessInfo.processInfo.arguments.contains("--ui-coupon-management") {
                    CouponManagementFixtureHost()
                } else if WalletCommerceFixtureHost.selected {
                    WalletCommerceFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--ui-publishing-modes") {
                    PublishingModesFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--nearby-team-fixture") {
                    NearbyTeamFixtureRoot()
                } else if ProcessInfo.processInfo.arguments.contains("--official-action-fixture") {
                    OfficialActionFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--second-registration-fixture") {
                    SecondRegistrationFixtureHost(scenario: fixtureArgument("--second-registration-fixture") ?? "mature")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-engagement-fixture") {
                    MerchantEngagementFixtureHostView()
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-business-fixture") {
                    MerchantBusinessFixtureHostView()
                } else if ProcessInfo.processInfo.arguments.contains("--merchant-city-template-handoff-fixture") {
                    MerchantCityTemplateHandoffFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-content-fixture") {
                    MerchantContentFixtureScenarioView()
                } else if ProcessInfo.processInfo.arguments.contains("--cooperation-flow-fixture") {
                    CoopFlowFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-club-governance") {
                    ClubGovernanceFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--ui-template-authoring") {
                    TemplateAuthoringFixtureHostView()
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-order-lifecycle-fixture") {
                    OrderLifecycleFixtureHostView()
                } else if RoamSubpageFixtureHost.selected {
                    RoamSubpageFixtureHost()
                } else if RoamExperienceFixtureHostView.selected {
                    RoamExperienceFixtureHostView()
                } else if RoamHomeFixtureHostView.selected {
                    RoamHomeFixtureHostView()
                } else if let scenario=ActivityFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) {
                    ActivityFixtureRootView(scenario:scenario)
                } else if let merchant=MerchantFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) {
                    MerchantFixtureRootView(scenario:merchant)
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-operations-fixture") {
                    MerchantOperationsFixtureHostView()
                } else if let onboarding=MerchantOnboardingFixtureRoot.selected(arguments:ProcessInfo.processInfo.arguments) {
                    MerchantOnboardingFixtureRoot(name:onboarding)
                } else if let club=ClubFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) {
                    ClubFixtureRootView(scenario:club)
                } else if let clubOperations = ClubOperationsFixtureHostView.selected(arguments: ProcessInfo.processInfo.arguments) {
                    ClubOperationsFixtureHostView(scenario: clubOperations)
                } else if let clubManagement=ClubManagementFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) {
                    ClubManagementFixtureRootView(scenario:clubManagement)
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-invite-reward-review") {
                    ProfileInviteRewardReviewFixtureHost(scenario: fixtureArgument("--profile-invite-reward-review-scenario") ?? "complete")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-participation-schedule") {
                    ProfileParticipationScheduleFixtureHost(scenario: fixtureArgument("--profile-participation-schedule-scenario") ?? "near")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-order-filters") {
                    ProfileOrderFilterFixtureHost(empty: ProcessInfo.processInfo.arguments.contains("--profile-order-filters-empty"))
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-orders") {
                    ProfileSelfOrdersFixtureHost(scenario: fixtureArgument("--profile-self-orders-scenario") ?? "content")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-complaint") {
                    ProfileComplaintPreparationFixtureView(scenario: fixtureArgument("--profile-complaint-scenario") ?? "content")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-local-cover") {
                    ProfileLocalCoverFixtureHost()
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-favorite-removal") {
                    ProfileFavoriteRemovalFixtureHost(scenario: fixtureArgument("--profile-favorite-removal-scenario") ?? "content")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-edit-return") {
                    ProfileSelfEditFixtureHost(scenario: fixtureArgument("--profile-self-edit-scenario") ?? "own")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-medals") {
                    ProfileSelfMedalsFixtureHost(scenario: fixtureArgument("--profile-self-medals-scenario") ?? "content")
                } else if MemberParityFixture.isSelected {
                    MemberParityFixtureRouter()
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-growth") {
                    ProfileSelfGrowthFixtureHost(scenario: fixtureArgument("--profile-self-growth-scenario") ?? "content")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-projects") {
                    ProfileSelfProjectsFixtureHost(scenario: fixtureArgument("--profile-self-projects-scenario") ?? "content")
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-profile-author-posts-refresh") {
                    ProfileAuthorPostsRefreshFixtureHost(scenario: fixtureArgument("--profile-author-posts-scenario") ?? "content")
                } else if let profileEdit=ProfileEditFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) {
                    ProfileEditFixtureHost(scenario:profileEdit)
                } else if let clubAction=ClubActionFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) {
                    ClubActionFixtureRootView(scenario:clubAction)
                } else if let registration=RegistrationFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) {
                    RegistrationFixtureHostView(scenario:registration)
                } else if ProcessInfo.processInfo.arguments.contains("--uitesting-map-core-entry") {
                    MapCoreEntryFixtureHost()
                } else if let module=ModuleFixture.selected {
                    ModuleFixtureRootView(module:module)
                } else if let session=sessionContainer.session {
                    SessionRootView(session:session)
                        .safeAreaInset(edge: .bottom) {
                            if let fixture = sessionContainer.couponRuntime {
                                CouponRuntimeEvidence(fixture: fixture, session: session)
                            }
                            if let fixture = sessionContainer.integratedAcceptance {
                                IntegratedNativeAcceptanceEvidence(fixture: fixture, session: session)
                            }
                        }
                }
                #else
                if let session=sessionContainer.session {
                    SessionRootView(session:session)
                }
                #endif
            }
            .cyPresentationBackdropHost()
            .modifier(AppLanguageEnvironment(stored: storedLanguage))
            .tint(CYColor.brand)
            .islandRoot()
            #if DEBUG
            .modifier(FixtureThemeDomainModifier(isFixture: sessionContainer.session == nil))
            #endif
        }
    }
}

#if DEBUG
/// Fixture roots skip the session roots, so they apply the same merchant-light, player-dark rule here.
/// A test that sets its own appearance through launch arguments keeps it.
private struct FixtureThemeDomainModifier: ViewModifier {
    let isFixture: Bool
    private var domain: ThemeDomain? {
        let arguments = ProcessInfo.processInfo.arguments
        guard isFixture, !arguments.contains("--uitesting-dark"), !arguments.contains("--uitesting-light") else { return nil }
        return arguments.joined(separator: " ").lowercased().contains("merchant") ? .merchant : .player
    }
    func body(content: Content) -> some View {
        if let domain { content.themeDomain(domain).cyScreenStyle() } else { content }
    }
}
#endif

/// Preserve the app-scoped production session without constructing it in fixture mode.
@MainActor
final class AppSessionContainer: ObservableObject {
    let session: AppSession?
    #if DEBUG
    let integratedAcceptance: IntegratedNativeAcceptanceFixture?
    let couponRuntime: CouponRuntimeFixture?
    #endif

    init(composition: AppCompositionRoot? = nil, arguments: [String] = ProcessInfo.processInfo.arguments) {
        #if DEBUG
        AppStoreScreenshotHarness.applyStoredLanguage(arguments: arguments)
        if AppStoreScreenshotHarness.mountedFixtureID(arguments: arguments) != nil {
            integratedAcceptance = nil
            couponRuntime = nil
            session = nil
            return
        }
        let fixture = composition == nil ? IntegratedNativeAcceptanceFixture.selected(arguments: arguments) : nil
        integratedAcceptance = fixture
        let coupon = composition == nil ? CouponRuntimeFixture.selected(arguments) : nil
        couponRuntime = coupon
        if let coupon {
            let acceptedSession = coupon.composition().makeSession()
            session = acceptedSession; coupon.session = acceptedSession
            return
        }
        if let fixture {
            let acceptedSession = fixture.makeComposition().makeSession()
            session = acceptedSession
            fixture.session = acceptedSession
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--owner-draft-fixture") || ProcessInfo.processInfo.arguments.contains("--group-poll-fixture") || ProcessInfo.processInfo.arguments.contains("--native-navigation-fixture") || ProcessInfo.processInfo.arguments.contains("--native-verification-fixture") || ProcessInfo.processInfo.arguments.contains("--merchant-npc-fixture") || ProcessInfo.processInfo.arguments.contains("--publisher-lifecycle-fixture") || ProcessInfo.processInfo.arguments.contains("--retained-images-fixture") || ProcessInfo.processInfo.arguments.contains("--square-governance-fixture") || ProcessInfo.processInfo.arguments.contains("--shop-npc-fixture") || ProcessInfo.processInfo.arguments.contains("--club-community-fixture") || ProcessInfo.processInfo.arguments.contains("--public-merchant-home-fixture") || ProcessInfo.processInfo.arguments.contains("--door-referral-fixture") || ProcessInfo.processInfo.arguments.contains("--merchant-marketing-fixture") || ProcessInfo.processInfo.arguments.contains("--im-expanded-fixture") || ProcessInfo.processInfo.arguments.contains("--ui-coupon-management") || WalletCommerceFixtureHost.selected || ProcessInfo.processInfo.arguments.contains("--ui-publishing-modes") ||
           ProcessInfo.processInfo.arguments.contains("--nearby-team-fixture") ||
           ProcessInfo.processInfo.arguments.contains("--official-action-fixture") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-club-governance") ||
           ProcessInfo.processInfo.arguments.contains("--ui-template-authoring") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-order-lifecycle-fixture") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-engagement-fixture") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-business-fixture") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-content-fixture") ||
           ProcessInfo.processInfo.arguments.contains("--cooperation-flow-fixture") ||
           RoamExperienceFixtureHostView.selected || RoamHomeFixtureHostView.selected || RoamSubpageFixtureHost.selected || ActivityFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) != nil ||
           MerchantFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) != nil || ModuleFixture.selected != nil ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-merchant-operations-fixture") ||
           MerchantOnboardingFixtureRoot.selected(arguments:ProcessInfo.processInfo.arguments) != nil ||
           ClubFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) != nil ||
           ClubActionFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) != nil ||
           ClubOperationsFixtureHostView.selected(arguments: ProcessInfo.processInfo.arguments) != nil ||
           ClubManagementFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) != nil ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-invite-reward-review") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-participation-schedule") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-order-filters") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-orders") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-complaint") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-local-cover") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-favorite-removal") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-edit-return") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-medals") ||
           MemberParityFixture.isSelected ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-growth") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-self-projects") ||
           ProcessInfo.processInfo.arguments.contains("--uitesting-profile-author-posts-refresh") ||
           ProfileEditFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) != nil ||
           RegistrationFixtureScenario.selected(arguments:ProcessInfo.processInfo.arguments) != nil {
            session=nil
            return
        }
        #endif
        session=(composition ?? RegionalLaunchConfiguration.composition).makeSession()
    }
}

/// Identity of the signed-in account for the one-shot merchant-mode request. A refresh with the same values does not retry.
private struct MerchantModeBoot: Equatable {
    let accountID: Int?
    let revision: UInt64
    let role: String
    let userType: Int?
    let isSignedIn: Bool
    let isConfigured: Bool
}

/// Only the normal root starts account restoration.
@MainActor
struct SessionRootView: View {
    @Environment(\.scenePhase) private var personalShareScenePhase
    @ObservedObject var session: AppSession
    @StateObject private var merchantRootCoordinator = MerchantRootModeCoordinator()
    @State private var browsingAsGuest=false
    @State private var selectedTab=RootTab.home
    /// W3-6: one-shot presentation requests from a chein:// link; the owning screen clears them when it consumes them.
    @State private var deepLinkTicketPass=false
    @State private var deepLinkClubID: Int?
    @State private var showsAreaPicker=false
    @State private var presentation = RootPresentationCoordinator()
    @State private var reachability = NetworkReachability()
    @State private var homeTabBarVisibility = CYTabBarVisibility()
    @State private var roamTabBarVisibility = CYTabBarVisibility()
    @State private var publishTabBarVisibility = CYTabBarVisibility()
    @State private var clubTabBarVisibility = CYTabBarVisibility()
    @State private var mineTabBarVisibility = CYTabBarVisibility()
    @State private var isTabBarHidden = false
    /// L1 P-004: sign-in opens as one sheet over the current tab; the optional action resumes after it.
    @State private var showsRootSignIn = false
    @State private var resumeAfterSignIn: (@MainActor () -> Void)?
    #if DEBUG
    @State private var showsScannerFixture = false
    #endif

    @ViewBuilder private var homeTab: some View {
                    SessionHomeFeedView(onSignIn:{ requestSignIn() },onStartRoam:{ selectedTab = .roam })
                        .environment(\.cyTabBarVisibility, homeTabBarVisibility)
    }

    /// 漫游 tab root. Native r2 (`NativeR2Flags.mapHome`, default on): the Apple-Maps-style map home, with the
    /// City board as a map mode. Flag off: the City Monopoly map (owner Q9, P 210:8322); hold to start opens the live roam.
    @ViewBuilder private var roamTab: some View {
        if NativeR2Flags.mapHome {
                    RoamMapHomeView(dependencies: roamMapHomeDependencies)
                        .environment(\.roamPOIActions, session.makeRoamPOIActions())
                        .environment(\.roamReceivedStampReader, session.roamReceivedStampReader)
                        .environment(\.roamPassportHistoryReader, session.roamPassportHistoryReader)
                        .environment(\.roamPlaceExtrasProvider, { poiID in poiID > 0 ? RoamPlaceExtrasProduction(poiID: poiID, session: session) : nil })
                        .environment(\.inGameChannelHost, session.inGameChannelHost)
                        .themeDomain(.player)
                        .environment(\.cyTabBarVisibility, roamTabBarVisibility)
        } else {
                    SessionCityRoamRoot(liveDestination: { AnyView(RoamLiveSessionView(controller: session.makeRoamLiveSessionController(), localHistoryReader: session.roamExperienceReader, albumMetadataReader: session.roamAlbumMetadataReader).environment(\.inGameChannelHost, session.inGameChannelHost).environment(\.roamOfficialArrival, RoamOfficialArrivalDeps(reader: session.officialEventReader, actions: session.officialActionCoordinator))) },
                                        passportDestination: { AnyView(roamBrowser) }, onChooseArea: { showsAreaPicker = true })
                        .environment(\.cyTabBarVisibility, roamTabBarVisibility)
        }
    }

    private var roamLiveDestination: AnyView {
        AnyView(RoamLiveSessionView(controller: session.makeRoamLiveSessionController(), localHistoryReader: session.roamExperienceReader, albumMetadataReader: session.roamAlbumMetadataReader).environment(\.inGameChannelHost, session.inGameChannelHost).environment(\.roamOfficialArrival, RoamOfficialArrivalDeps(reader: session.officialEventReader, actions: session.officialActionCoordinator)))
    }

    private func roamEventDestination(_ target: RoamEventDestination) -> AnyView {
        switch target {
        case .activity(let id): return AnyView(ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true))
        case .topic(let id): return AnyView(SessionTopicDetailView(id: id, session: session))
        }
    }

    /// Native r2 map home: the readers and destinations the City root and `roamBrowser` already use.
    private var roamMapHomeDependencies: RoamMapHomeDependencies {
        let session = session
        let signIn: () -> Void = { requestSignIn() }
        let openAccount: () -> Void = { openAccountOrSignIn() }
        return RoamMapHomeDependencies(
            roamReader: session.roamReader,
            entryReader: session.roamEntryNearbyReader,
            entryTeams: { await session.roamEntryTeams(area: $0) },
            officialRouteReader: session.officialRouteReader,
            locationSettings: RoamSystemLocationSettingsProvider(),
            mediaScope: session.platformConsumers.scope,
            makeExternalMaps: session.platformConsumers.mapsFactory,
            liveDestination: { roamLiveDestination },
            passportDestination: { AnyView(roamBrowser) },
            cityBoardDestination: {
                AnyView(SessionCityRoamRoot(liveDestination: { roamLiveDestination }, passportDestination: { AnyView(roamBrowser) },
                                            onChooseArea: { showsAreaPicker = true }))
            },
            placeDetailDestination: { item in
                AnyView(RoamItemDetailView(item: item, reader: session.roamReader, mediaScope: session.platformConsumers.scope,
                    makeExternalMaps: session.platformConsumers.mapsFactory, stampDestination: { AnyView(SessionRoamStampCameraView()) },
                    posterDestination: { AnyView(SessionRoamPosterView(node: $0)) }, eventDestination: roamEventDestination,
                    playerProfileDestination: { memberID in
                        AnyView(SocialPublicProfileView(memberID: memberID, reader: session.socialAccountReader,
                            squareReader: session.squareReader, actions: nil).id(session.socialAccountReader.identity))
                    },
                    couponWalletDestination: session.makeRoamCouponWalletDestination(reader: session.roamReader)))
            },
            eventDestination: roamEventDestination,
            myTeamsDestination: { AnyView(SessionRoamNearbyTeamsView(initialTab: 1, onSignIn: signIn)) },
            nearbyTeamsDestination: { AnyView(SessionRoamNearbyTeamsView().environment(\.nearbyTeamsSignIn, signIn)) },
            nearbyTeamDestination: { AnyView(SessionRoamNearbyTeamsView(focusTeamID: $0, onSignIn: signIn)) },
            searchReader: session.searchMapReader,
            onChooseArea: { showsAreaPicker = true },
            onOpenAccount: openAccount)
    }

    /// The shipped roam page (走起, 漫游护照, tools). Owner Q9: the 漫游 root is the map; this page opens from it.
    @ViewBuilder private var roamBrowser: some View {
                    RoamBrowserView(reader:session.roamReader,nearbyEventsReader:session.roamNearbyEventsReader,nearbyPlayersReader:session.roamNearbyPlayersReader,onChooseArea:{ showsAreaPicker=true },onOpenAccount:{ openAccountOrSignIn() },experienceReader:session.roamExperienceReader, albumMetadataReader:session.roamAlbumMetadataReader, tileMemoryReader:session.roamTileMemoryReader, sessionFactReader:session.roamSessionFactReader, cityDestination: { AnyView(SessionCityPlayerView()) }, territoryDestination: { AnyView(SessionRoamTerritoryView()) }, nearbyTeamsDestination: { AnyView(SessionRoamNearbyTeamsView().environment(\.nearbyTeamsSignIn, { requestSignIn() })) }, stampDestination: { AnyView(SessionRoamStampCameraView()) }, liveDestination: { AnyView(RoamLiveSessionView(controller: session.makeRoamLiveSessionController(), localHistoryReader: session.roamExperienceReader, albumMetadataReader: session.roamAlbumMetadataReader).environment(\.inGameChannelHost, session.inGameChannelHost).environment(\.roamOfficialArrival, RoamOfficialArrivalDeps(reader: session.officialEventReader, actions: session.officialActionCoordinator))) }, posterDestination: { AnyView(SessionRoamPosterView(node: $0)) }, eventDestination: { target in
                        switch target {
                        case .activity(let id): return AnyView(ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true))
                        case .topic(let id): return AnyView(SessionTopicDetailView(id: id, session: session))
                        }
                    }, nearbyEventDestination: { target in
                        AnyView(RoamNearbyEventsDetailHost(target: target, session: session))
                    }, playerProfileDestination: { memberID in
                        AnyView(SocialPublicProfileView(memberID: memberID, reader: session.socialAccountReader,
                            squareReader: session.squareReader, actions: nil).id(session.socialAccountReader.identity))
                    }, couponWalletDestination: session.makeRoamCouponWalletDestination(reader: session.roamReader), officialRouteReader: session.officialRouteReader, mediaScope:session.platformConsumers.scope, makeExternalMaps:session.platformConsumers.mapsFactory, entryReader: session.roamEntryNearbyReader, entryTeams: { await session.roamEntryTeams(area: $0) }, myTeamsDestination: { AnyView(SessionRoamNearbyTeamsView(initialTab: 1, onSignIn: { requestSignIn() })) }, nearbyTeamDestination: { AnyView(SessionRoamNearbyTeamsView(focusTeamID: $0, onSignIn: { requestSignIn() })) }, toolsReader: session.roamPassportToolsReader, passportToolsReader: session.roamPassportToolsReader, privateToolsReader: session.roamPrivateToolsReader, anniversaryRouteDestination: { topicID in
                        guard let id = Int(topicID), id > 0, String(id) == topicID else {
                            return AnyView(TopicIssueView(issue: .unavailable))
                        }
                        return AnyView(SessionTopicDetailView(id: id, session: session))
                    }, locationSettings: RoamSystemLocationSettingsProvider(), presentedAsSheet: true)
                        .environment(\.roamPOIActions, session.makeRoamPOIActions())
                        .environment(\.roamReceivedStampReader, session.roamReceivedStampReader)
                        .environment(\.roamPassportHistoryReader, session.roamPassportHistoryReader)
                        .environment(\.roamPlaceExtrasProvider, { poiID in poiID > 0 ? RoamPlaceExtrasProduction(poiID: poiID, session: session) : nil })
                        .environment(\.inGameChannelHost, session.inGameChannelHost)
    }

    @ViewBuilder private var publishTab: some View {
                    NavigationStack { PublishTabRootView() }
                        .id(session.sessionRevision)
                        .environment(\.cyTabBarVisibility, publishTabBarVisibility)
    }

    @ViewBuilder private var clubTab: some View {
                    NavigationStack { ClubHomeView(reader:session,onSignIn:{ requestSignIn() },actionCoordinator:session.clubActionCoordinator,management:session.clubManagementContext, community:session.clubCommunityContext, publicRoster:session.clubPublicRosterReader, topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) }, requestedClubID: $deepLinkClubID, authorSquare: session.squareReader).modifier(SessionMessagingToolbarEntry(session: session)) }
                        .id(session.sessionRevision)
                        .environment(\.cyTabBarVisibility, clubTabBarVisibility)
    }

    @ViewBuilder private var mineTab: some View {
                    Group {
                        if let account=session.account { PassportView(account:account,privateHomeCoordinator:session.privateHomeCoordinator,nativeHomeReturnSelection:session.nativeHomeReturnSelection,onOpenGuideDestination:{ destination in selectedTab = destination == .roam ? .roam : .home },presentsTicketPass:$deepLinkTicketPass).id(session.sessionRevision) }
                        else { WelcomeView() }
                    }
                        .environment(\.cyTabBarVisibility, mineTabBarVisibility)
    }

    /// L1 P-004: present sign-in in place (no tab switch). Already signed in: run the action now.
    private func requestSignIn(then resume: (@MainActor () -> Void)? = nil) {
        guard session.account == nil else { resume?(); return }
        resumeAfterSignIn = resume
        showsRootSignIn = true
    }

    /// The passport / account entries: the 我的 tab when signed in, the in-place sign-in sheet otherwise.
    private func openAccountOrSignIn() {
        if session.account == nil { requestSignIn() } else { selectedTab = .mine }
    }

    /// The sheet closed. With an account, the waiting action resumes and VoiceOver hears that sign-in finished.
    private func finishRootSignIn() {
        let resume = resumeAfterSignIn
        resumeAfterSignIn = nil
        guard session.account != nil else { return }
        if IslandCenter.isEnabled {
            IslandCenter.shared.status(.key("nativeR2.shell.signedIn"), tone: .success)
        } else {
            AccessibilityNotification.Announcement(appLocalized("nativeR2.shell.signedIn", locale: Locale.current)).post()
        }
        resume?()
    }

    /// Native r2: the system tab bar (`TabView` + `Tab`, SF Symbols, system tint). No custom bar, pill or haptic.
    /// iOS 17 keeps the same five tabs through `.tabItem`. The UIKit identifier pass keeps `rootTabBar.tab.player.N`.
    @ViewBuilder private var playerTabs: some View {
        Group {
            if #available(iOS 18, *) {
                TabView(selection:$selectedTab) {
                    Tab("tabBar.home", systemImage: RootTab.home.nativeSystemImage, value: RootTab.home) { homeTab }
                    Tab("tabBar.roam", systemImage: RootTab.roam.nativeSystemImage, value: RootTab.roam) { roamTab }
                    Tab("tabBar.publish", systemImage: RootTab.publish.nativeSystemImage, value: RootTab.publish) { publishTab }
                    Tab("tabBar.club", systemImage: RootTab.club.nativeSystemImage, value: RootTab.club) { clubTab }
                    Tab("tabBar.mine", systemImage: RootTab.mine.nativeSystemImage, value: RootTab.mine) { mineTab }
                }
            } else {
                TabView(selection:$selectedTab) {
                    homeTab.tabItem { rootTabLabel(.home).accessibilityIdentifier("rootTabBar.tab.player.0") }.tag(RootTab.home)
                    roamTab.tabItem { rootTabLabel(.roam).accessibilityIdentifier("rootTabBar.tab.player.1") }.tag(RootTab.roam)
                    publishTab.tabItem { rootTabLabel(.publish).accessibilityIdentifier("rootTabBar.tab.player.2") }.tag(RootTab.publish)
                    clubTab.tabItem { rootTabLabel(.club).accessibilityIdentifier("rootTabBar.tab.player.3") }.tag(RootTab.club)
                    mineTab.tabItem { rootTabLabel(.mine).accessibilityIdentifier("rootTabBar.tab.player.4") }.tag(RootTab.mine)
                }
            }
        }
                // L1 P-002: no `.id(account)`; signing in keeps every tab's navigation and scroll state.
                .environment(\.rootTabSwitch, RootTabSwitch { selectedTab = $0 })
                .environment(\.rootSignIn, RootSignIn { requestSignIn(then: $0) })
                .cySheet(isPresented: $showsRootSignIn, onDismiss: { finishRootSignIn() }) {
                    LoginView(intent: .player).environmentObject(session)
                }
                .sensoryFeedback(.success, trigger: session.account?.id) { old, new in old == nil && new != nil }
                .environment(\.growthSessionProfile, session.account.map { GrowthSessionProfile(name: $0.nickname, avatar: $0.avatar) })
                .sessionOfflineBanner(reachability: reachability, session: session)
                .cyScreenStyle()
                .cyTabBarAccessibilityIdentifiers(["rootTabBar.tab.player.0", "rootTabBar.tab.player.1", "rootTabBar.tab.player.2", "rootTabBar.tab.player.3", "rootTabBar.tab.player.4"])
                .environment(\.cyTabBarHidden, isTabBarHidden)
                .onPreferenceChange(CYTabBarHiddenPreferenceKey.self) { isTabBarHidden = $0 }
                .environment(\.imRecipientPreviewLeases, session.imRecipientPreviewLeaseSource)
                .onChange(of: selectedTab) { _, tab in if !tab.isPlayerTab { selectedTab = .home } }
                .roleTheme(.player)
    }

    var body: some View {
        let _ = AccountPublishContractLane.install(session)
        let base = Group {
            if session.account != nil || browsingAsGuest {
                if let access = merchantRootCoordinator.activeMerchantAccess(accountID: session.account?.id, isSignedIn: session.isSignedIn, isConfigured: session.isConfigured, revision: session.sessionRevision) {
                    SessionMerchantRootContainerView(session: session, coordinator: merchantRootCoordinator, access: access, onReturnToConsumer: { destination in
                        merchantRootCoordinator.switchToConsumerMode()
                        if let destination { selectedTab = destination.isPlayerTab ? destination : .home }
                    })
                    .sessionOfflineBanner(reachability: reachability, session: session)
                } else {
                playerTabs
                }
            } else {
                WelcomeView(onBrowse:{ browsingAsGuest=true })
                    .cyScreenStyle()
                    .roleTheme(.player)
                    .sessionOfflineBanner(reachability: reachability, session: session)
            }
        }
        .onAppear { reachability.start() }
        return chain6(chain5(chain4(chain3(chain2(chain1(chain0(base)))))))
    }

    private func replayDeepLink() {
        guard let link = presentation.takeLink(tabsVisible: session.account != nil || browsingAsGuest, signedIn: session.account != nil) else { return }
        selectedTab = link.rootTab
        switch link {
        case .ticket: deepLinkTicketPass = true // pass sheet only; the ticket wallet reader keeps its own gating
        case .clubJoin(let id): deepLinkClubID = id // club detail only; joining still needs the detail's confirmation
        case .roamGo: break
        case .referral, .gift, .seat:
            // Intake only. The landing does not claim a seat, claim a gift, pay, or start a run.
            if let intake = link.journeyIntake { presentation.noteJourney(intake); session.openJourneyLanding(intake) }
        }
    }

    private func chain0<V: View>(_ v: V) -> some View {
        v
        .modifier(CloudB3RootModifier(session: session))
        .modifier(CloudSquareStubModifier(session: session))
        .modifier(TicketWalletCompletionRootModifier())
        .environment(\.merchantRootModeSwitch, merchantRootCoordinator.makeModeSwitch(session: session))
        .environment(presentation)
        .onChange(of: session.pendingDeepLink, initial: true) { _, _ in
            // W3-6: chein:// links resolve in one presentation, the owning root tab. The coordinator keeps one pending
            // link (last wins, five minutes) until the tabs, sign-in and any open Passport sheet allow it.
            if let link = session.consumeDeepLink() { presentation.enqueue(link); replayDeepLink() }
        }
        .onChange(of: presentation.hasBlockingSheet) { _, _ in replayDeepLink() }
        .onChange(of: presentation.consentActive) { _, _ in replayDeepLink() }
        .onChange(of: browsingAsGuest) { _, _ in replayDeepLink() }
        .onChange(of: session.account?.id) { _, accountID in
            replayDeepLink()
            merchantRootCoordinator.handleSessionChange(accountID: accountID, isSignedIn: session.isSignedIn, isConfigured: session.isConfigured, revision: session.sessionRevision)
        }
        .onChange(of: session.sessionRevision) { _, revision in
            merchantRootCoordinator.handleSessionChange(accountID: session.account?.id, isSignedIn: session.isSignedIn, isConfigured: session.isConfigured, revision: revision)
        }
        .task(id: MerchantModeBoot(
            accountID: session.account?.id,
            revision: session.sessionRevision,
            role: session.account?.role ?? "",
            userType: session.account?.userType,
            isSignedIn: session.isSignedIn,
            isConfigured: session.isConfigured
        )) {
            await merchantRootCoordinator.adoptSignedInAccount(
                reader: session,
                accountID: session.account?.id,
                role: session.account?.role ?? "",
                userType: session.account?.userType,
                isSignedIn: session.isSignedIn,
                isConfigured: session.isConfigured,
                revision: session.sessionRevision
            )
        }
        .background {
            if session.account != nil { RetainedImagePresenterHost(host: session.retainedImagePickerHost).frame(width: 0, height: 0) }
        }
        .modifier(ExternalGameCatalogLaunch())
        .environmentObject(session)
        .environment(\.passOrderWriteSession, session)
        .environment(\.profileIMStartWire, ProfileIMStartWire(
            baseURL: { session.currentRuntimeDependencyContext?.baseURL },
            token: { session.passReadToken() },
            send: { request in try await session.runtimeHTTPTransport.send(request) }
        ))
        .environment(\.challengePOIPhotoUploader, { session.makeChallengePOIPhotoUploader(poiID: $0) })
        .environment(\.playerContentImageUploader, session.makePlayerContentImageUploader())
        .environment(\.topicRouteGapService, { session.makeTopicRouteGapService() })
        .environment(\.merchantApplyShopService, { session.makeMerchantApplyShopService() })
        .environment(\.walletWithdrawPermission, {
            let reader = session.memberHomeReader
            guard reader.isSignedIn, reader.isConfigured, reader.roleInfoAvailable else { return nil }
            return try await reader.roleInfo().permission.withdrawable == true
        })
        .environment(\.roamShareSnapshotPublisher, { session.makeRoamShareSnapshotPublisher() })
        .environment(\.externalGameSession, ExternalGameSessionRead.bridge(session))
        .modifier(MPParityPassEnvironment(session: session))
        .modifier(SocialRoamCapabilityRoot(session: session)) // G4/G5 entries (mount-g45)
        .onAppear { MPNotificationTapRouter.shared.install(session) }
        .modifier(PassMarketPointsRootModifier(session: session))
        .modifier(NativeOriginalUnreadBadgeLifecycle(session: session))
        .environment(\.cityMerchantOperationsFactory, { session.makeCityMerchantOperationsController() })
        .environment(\.merchantLedgerInboxDestination, { AnyView(SessionMerchantLedgerInboxView(session: session, source: $0)) })
        .environment(\.orderTeamCreate, { activityID, registrationID in
            AnyView(SessionTeamCreateView(activityID: activityID, registrationID: registrationID))
        })
    }

    private func chain1<V: View>(_ v: V) -> some View {
        v
        .environment(\.merchantCityNodeHubDestination, { AnyView(session.merchantCityNodeHub()) })
        .environment(\.merchantGameNodeDestination, { $1.view(service: $0) })
        .environment(\.merchantCityTemplateHandoffFactory, {
            .init(reader: session.merchantOperationsReader, imageHost: session.retainedMerchantImages,
                  templateAssistFactory: { session.merchantTemplateAssistFlow(coordinator: $0) })
        })
        .environment(\.merchantCustomerContactFactory, { session.merchantCustomerContactFlow($0, sourceIsCurrent: $1) })
        .environment(\.personalLocationShareHost, session.personalLocationShareHost)
        .onChange(of: personalShareScenePhase, initial: true) { _, phase in
            session.personalLocationShareHost.sceneChanged(phase)
        }
        .environment(\.nativeAttributeAuthorProjectFactory, session.nativeAttributeAuthorProjectFactory)
        .environment(\.projectCategoryReader, session)
            .environment(\.projectNodePlaceReader, session.searchMapReader)
    }

    private func chain2<V: View>(_ v: V) -> some View {
        v
        .environment(\.projectChapterAudioPlayback, session.platformConsumers.audioFactory)
        .environment(\.projectNodeTemplateCreationFactory, {
            .init(coordinator: session.templateAuthoringEditor(), sessionRevision: session.sessionRevision, metadataReader: session,
                  imageSelectionApproved: { session.retainedImagePickerHost.nativeSelectionEnabled })
        })
        .environment(\.clubBadgeHostFactory, { session.clubBadgeHost(clubID: $0) })
        .environment(\.clubOperationsFactory, {
            let management = session.clubManagementContext
            return management.operations.map { ($0, management.governance) }
        })
        .environment(\.playerGapService, session.playerGapService)
        .environment(\.playRoamGapService, session.playRoamGapService)
        // r8 A2-03b: 发消息 opens the chat in place from every SocialPublicProfileView host (square, club, activity…).
        .environment(\.socialConversationDestination, session.socialConversationDestination)
        .environment(\.analyticsEventClient, session.analyticsEventClient)
        .environment(\.verificationCodeFactory, { session.makeVerificationCodeCoordinator(target: $0) })
        .environment(\.cityNodeReceiptFactory, { session.makeCityNodeReceiptReader() })
        .environment(\.withdrawalSupportReader, session.withdrawalSupportReader)
        .environment(\.coopWalletReader, session.walletCommerceReader)
        .environment(\.squareRelatedTopic, .init(squareScope: session.squareReader.scope, reader: session.topicReader))
        .environment(\.ugcSafetyContext, session.makeUGCSafetyContext())
        // R8-PC-D9-1: chat 举报对方 (MP cy-report-sheet MEMBER).
        .environment(\.communityMemberReportContext, session.makeCommunityMemberReportContext())
    }

    private func chain3<V: View>(_ v: V) -> some View {
        chain3_7(chain3_6(chain3_5(chain3_4(chain3_3(chain3_2(chain3_1(chain3_0(v))))))))
    }

    private func chain3_0<V: View>(_ v: V) -> some View {
        let destination: (@MainActor () -> AnyView)?
        if session.regionalConfiguration?.showsRoute("/api/withdrawal/create") == true {
            destination = { AnyView(SessionBankWithdrawalView()) }
        } else {
            destination = nil
        }
        return v.environment(\.bankWithdrawalDestination, destination)
    }

    private func chain3_1<V: View>(_ v: V) -> some View {
        let session = session
        var readiness: (@MainActor () async -> RegistrationPaymentReadiness?)?
        var payExecutor: RegistrationPayExecutor?
        if PayoutReceiverBridge.paymentsOpen(session) {
            readiness = { await PayoutReceiverBridge.paymentReadiness(session) }
            payExecutor = { registrationID, channel, verifiedReadiness in
                await RegistrationPayBridge.pay(
                    session,
                    registrationID: registrationID,
                    channel: channel,
                    readiness: verifiedReadiness,
                    quoteUsable: true,
                    quoteFresh: true,
                    consented: true
                )
            }
        }
        return v
        .environment(\.couponCodeFactory, { session.makeCouponCodeCoordinator(historyID: $0) })
        .environment(\.registrationPaymentReadiness, readiness)
        .environment(\.registrationPayExecutor, payExecutor)
    }

    private func chain3_2<V: View>(_ v: V) -> some View {
        v
        .environment(\.merchantPersonalIncomeDestination, { AnyView(SessionMerchantPersonalIncomeView(session: session, source: $0)) })
    }

    private func chain3_3<V: View>(_ v: V) -> some View {
        v
        .environment(\.merchantLedgerAssetsDestination, { AnyView(SessionMerchantLedgerAssetsView(session: session, source: $0)) })
        // fix/r3-merchant-coop-a: MerchantDeniedState offers 申请入驻 only when access/me has no active merchant.
        .environment(\.merchantCoopProfitDestination, { AnyView(CoopFinanceProfitView(reader: session.cooperationFlowReader).cyPushedChrome(domain: .merchant)) })
        // MC7-06-9: 收入明细 coop-share rows → pages/coop/settlement-detail/index?source=ledger&id= (Cursor's route).
        .environment(\.merchantCoopSettlementDetailDestination, { id in
            AnyView(CoopSettlementDetailRoute(reader: session.cooperationFlowReader, query: ["source": "ledger", "id": String(id)])
                .cyPushedChrome(domain: .merchant))
        })
        // Lane G: no 申请入驻 (merchant onboarding) from a denied state in Release.
        .environment(\.merchantGateActions, PlayerLaunch.merchantCenterEnabled ? MerchantGateActions(
            hasMerchantIdentity: { (try? await session.merchantAccess())?.active == true },
            applicationDestination: { AnyView(MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)) }) : nil)
    }

    private func chain3_4<V: View>(_ v: V) -> some View {
        v
        .environment(\.merchantAcceptedProjectDestination, { AnyView(SessionMerchantAcceptedProjectView(session: session, source: $0)) })
    }

    private func chain3_5<V: View>(_ v: V) -> some View {
        v
        .environment(\.merchantOfficialRecruitmentDestination, { AnyView(SessionMerchantOfficialRecruitmentView(session: session, source: $0)) })
    }

    private func chain3_6<V: View>(_ v: V) -> some View {
        v
        .environment(\.merchantCoopCenterDestination, { session.merchantCoopCenterDestination(initialTab: $0, focusTopicID: $1) })
    }

    private func chain3_7<V: View>(_ v: V) -> some View {
        v
        .environment(\.cooperationNearbyDestination, { AnyView(SessionNearbyMerchantsView(session: session)) })
        .modifier(MerchantCoopR8SessionEnvironment(session: session))
        // MC8-30-6: coop/list 再邀别人 opens 找商家 scoped to that topic.
        .environment(\.cooperationTopicNearbyDestination, { AnyView(SessionNearbyMerchantsView(session: session, topic: $0)) })
    }

    private func chain4<V: View>(_ v: V) -> some View {
        v
        .environment(\.cooperationRelationDiscovery, { AnyView(SessionCoopRelationDiscoveryView(session: session, reader: $0)) })
        .environment(\.coopFlowPreviewWrite, CoopFlowPreviewWriteFactory.live(session))
        // MC7-32-5: after 联系对方 succeeds, the preview opens the returned conversation.
        .environment(\.coopConversationDestination, { id in
            AnyView(MessagingHistoryView(conversationID: id, reader: session.messagingReader,
                sender: session.messageSender(for: id), mediaReader: session.socialMessageMediaReader,
                expanded: session.imExpandedNavigation))
        })
        .environment(\.merchantCoopInboxDestination, {
            // MC8-32-1/-4: the workbench inbox passes the topic destination so 进入项目 / 主题详情 are links.
            AnyView(CooperationBrowserView(reader: session.cooperationReader, peerReader: session.cooperationFlowReader,
                                           operationScope: "MERCHANT",
                                           topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) },
                                           embedsNavigationStack: false)
                .environment(\.coopTopicPublishDestination, { scope in
                    // MC8-31-3: 先发布主题 → pages/publish/fabu/index (`?scope=MERCHANT` on the merchant surface).
                    AnyView(MPReviewedPageScreen(page: "pages/publish/fabu/index", query: scope.map { ["scope": $0] } ?? [:]).environmentObject(session))
                }))
        })
        .environment(\.merchantInboxSources, MerchantInboxSources(
            accountKey: session.account.map { String($0.id) } ?? "",
            conversations: { try await session.messagingReader.messagingConversations() },
            receivedInvites: { try await session.cooperationReader.inviteList().received },
            inboxDestination: { AnyView(SessionMessagingHome(session: session)) },
            inviteDestination: { id in
                AnyView(CooperationInviteDetailView(key: CooperationInviteKey(id: id, direction: .received),
                                                    reader: session.cooperationReader, peerReader: session.cooperationFlowReader))
            },
            markConversationRead: { id in
                do { try await session.imExpandedWriter.markInboxConversationRead(conversationID: id) }
                catch APIError.notConfigured {}
                catch {}
            }))
        .environment(\.merchantDeskManualCode, MerchantDeskManualCodeAction { code in
            guard let configuration = session.regionalConfiguration?.apiConfiguration, let token = session.token else {
                throw MerchantBusinessFailure.disabled
            }
            return try await MerchantDeskManualCodeClient(configuration: configuration, transport: session.runtimeHTTPTransport, gate: .live)
                .resolve(code: code, token: token)
        })
        .environment(\.complianceSignupDestination, { AnyView(SessionComplianceSignupView(session: session)) })
        .environment(\.merchantCouponManagementDestination, { AnyView(SessionCouponManagementView()) })
        .environment(\.merchantOpsWp03Bridge, MerchantOpsWp03Bridge(
            baseURL: session.regionalConfiguration?.apiConfiguration?.baseURL,
            token: session.token,
            host: session.regionalConfiguration?.apiConfiguration?.baseURL.host,
            accountID: session.account?.id ?? 0,
            transport: session.runtimeHTTPTransport))
        .environment(\.registrationMySignupsDestination, { AnyView(SessionPlayerJourneyView(destination: .participations)) })
        .environment(\.objectCardMedia, session.makeObjectCardImageLoader())
        .task { await session.bootstrap() }
        .onAppear { session.setPrivateHomePresentationActive(true) }
        .onAppear { session.setOwnerDraftPresentationActive(true) }
        .onAppear { session.setWorkshopOwnedPresentationActive(true) }
    }

    private func chain5<V: View>(_ v: V) -> some View {
        v
        .onDisappear { session.setPrivateHomePresentationActive(false) }
        .onDisappear { session.setOwnerDraftPresentationActive(false) }
        .onDisappear { session.setWorkshopOwnedPresentationActive(false) }
        .onOpenURL { session.receiveNativeURL($0) }
        .modifier(DebugOpenURLLaunchArgument(session: session))
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { session.receiveUniversalLink($0) }
        // One presentation at a time: the consent gate goes first, native entry and the area picker queue behind it.
        .cySheet(item: Binding(get: { presentation.allowsSecondaryRootSheet ? session.nativeEntry : nil }, set: { if $0 == nil, presentation.allowsSecondaryRootSheet { session.dismissNativeEntry() } })) { entry in
            NativeEntryLandingView(entry: entry, session: session, goHome: { browsingAsGuest = true; selectedTab = .home })
                .cyPlayerSheetGlass()
        }
        .cySheet(isPresented:Binding(get: { showsAreaPicker && presentation.allowsSecondaryRootSheet && session.nativeEntry == nil }, set: { showsAreaPicker = $0 })) { Group {
            RoamAreaPicker(onSelect:{ session.roamArea=$0 })
                .cyPlayerSheetGlass()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .usageConsentLaunchGate(signedIn: session.account != nil, market: session.operationalMarket, presentation: presentation, onDecline: { browsingAsGuest = true })
    }

    private func chain6<V: View>(_ v: V) -> some View {
        v
        .sessionExpiryNotice(session: session, onContinueAsGuest: { browsingAsGuest = true })
        #if DEBUG
        .cySheet(isPresented: $showsScannerFixture) { Group {
            NativeQRScanner { _ in }
                .cyPlayerSheetGlass()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--uitesting-scanner") {
                showsScannerFixture = true
            }
        }
        #endif
    }


    /// iOS 17 fallback label: the same title key and SF Symbol as the iOS 18 `Tab`.
    private func rootTabLabel(_ tab: RootTab) -> some View {
        Label(LocalizedStringKey(tab.playerTitleKey), systemImage: tab.nativeSystemImage)
    }
}

#if DEBUG
private func fixtureArgument(_ flag: String) -> String? {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1), !args[index + 1].hasPrefix("--") else { return nil }
    return args[index + 1]
}
#endif
