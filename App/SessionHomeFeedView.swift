import SwiftUI

@MainActor struct SessionHomeFeedView:View {
    @EnvironmentObject private var session:AppSession
    var onSignIn:(()->Void)? = nil
    var onStartRoam:(()->Void)? = nil
    @State private var router = AppRouter()
    /// R8-PC-A1-1 MP-first: the 首页 city is a local label only (MP `onManualCityChange`), never the global roam centre.
    /// mp-home r3: kept on the device like MP `homeCity.saveLastCity` / `readLastCity`, so the pick survives relaunch.
    @AppStorage("homeIndex.manualCity") private var homeCityStored: String = ""
    private var homeCityLabel: String? { homeCityStored.isEmpty ? nil : homeCityStored }
    /// One hero namespace for the Explore stack: feed cards are zoom sources, the pushed detail is the destination.
    @Namespace private var hero
    @State private var activeContinuationScope:PlaySessionScope?=nil
    @State private var continuationCoordinator = HomeContinuationCoordinator()
    @State private var continuationCards:[HomeIndexParityPresentation.ContinuationCard]=[]
    @State private var continuationReadAvailability:HomeContinuationReadAvailability = .unauthenticated
    @State private var todayTicket:HomeTodayCandidate?=nil
    @State private var showsTodayTickets=false
    /// P-021 / P-026: 首页 searches in place with the system search field; one model for list and map.
    @State private var search = GlobalSearchSession()
    @QuestifyReduceMotion private var reduceMotion
    @State private var showsTemplates=false
    @State private var showsCreate=false
    @State private var showsSquare=false
    /// Plan audit H-17: the 动态 entry shows only while the owner-bound community read gate is open
    /// (`communityFeatures().read`, the same gate `SquareBrowserView` reads); closed / unread → no dead entry (P27).
    @State private var squareCommunityOpen=false
    @State private var showsOfficialEvents=false
    @State private var showsProjectEditor=false
    @State private var showsClubApplication=false
    @State private var showsMerchantApplication=false
    @State private var showsMiniGames = false
    @State private var showsSearchMap = false
    /// mp-nav r3: a link / notification page pushed on this stack (see `HomeLanding`).
    @State private var landingRoute: MPParityRoute?
    @Environment(RootPresentationCoordinator.self) private var presentation: RootPresentationCoordinator?
    @Environment(\.locale) private var locale
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @StateObject private var cityConsent = HomeCityLocationConsentModel()
    var body:some View {
        navigationRoot
        .id(session.homeFeedReader.scope)
        // Plan audit H-02a: no 继续探索 read on 首页 — the MP wxml renders no continuation card (#29) and HomeFeedView draws none.
        .task(id:session.ticketWalletReader.scope) { await reloadTodayTicket() }
        .task(id:session.homeFeedReader.scope) { await cityConsent.refresh(session) }
        .task(id:session.sessionRevision) { await cityConsent.refresh(session) }
        .cyToast(message: $cityConsent.toast)
        .onChange(of:session.homeFeedReader.scope) { _,_ in resetForHomeScopeChange() }
        .onChange(of:session.officialEventReader.scope) { _,_ in showsOfficialEvents=false }
        .onChange(of:session.sessionRevision) { _,_ in resetForSessionRevisionChange() }
        .cySheet(isPresented:$showsProjectEditor) { Group {
            NavigationStack {
                ProjectEditLaunchView().toolbar {
                    ToolbarItem(placement:.cancellationAction) {
                        Button("action.close") { showsProjectEditor=false }
                            .accessibilityIdentifier("projectEditor.close")
                    }
                }
            }.id(session.sessionRevision)
            .themeDomain(.topicEditor)
        }.cySheet(detents: [.large])
        }
        .cySheet(isPresented:$showsCreate) {
            NavigationStack {
                DiscoveryTemplateBrowserView(reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) }, authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext,
                    publishDestination: { AnyView(SessionPublishingModesView().environmentObject(session).id(session.publishingSession?.epoch)) },
                    searchDestination: { AnyView(SessionLinkedSearchView().environmentObject(session)) },
                    inboxDestination: { AnyView(SessionMessagingHome(session: session)) })
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) {
                            Button("action.close") { showsCreate=false }
                                .accessibilityIdentifier("create.close")
                        }
                    }
            }
            .id(session.templateAuthoringViewIdentity)
            .cyPlayerSheetGlass()
        }
        .cySheet(isPresented:$showsTemplates) {
            NavigationStack {
                // PC-A-2-6: 浏览模板 keeps 发布 like the 发布 tab entry.
                DiscoveryTemplateBrowserView(reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) }, authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext,
                    publishDestination: { AnyView(SessionPublishingModesView().environmentObject(session).id(session.publishingSession?.epoch)) },
                    searchDestination: { AnyView(SessionLinkedSearchView().environmentObject(session)) },
                    inboxDestination: { AnyView(SessionMessagingHome(session: session)) }).id(session.templateAuthoringViewIdentity)
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) {
                            Button("action.close") { showsTemplates=false }
                                .accessibilityIdentifier("templates.close")
                        }
                    }
            }
            .cyPlayerSheetGlass()
        }
    }
    /// Plan audit H-17: one gate read per reader scope; any failure keeps the entry hidden.
    private func loadSquareCommunityGate() async {
        let features: SquareCommunityFeatures? = try? await session.squareReader.communityFeatures()
        squareCommunityOpen = features?.read == true
    }
    /// verify-r1 2.5: the former header ⋯ items, shown in the 更多玩法 menu under the greeting.
    private var homeMoreMenuContent: AnyView {
        AnyView(Group {
            if squareCommunityOpen {
                Button("square.title",systemImage:"square.grid.2x2") { showsSquare=true }
                    .accessibilityIdentifier("homeFeed.openSquare")
            }
            Button("official.title",systemImage:"sparkles") { showsOfficialEvents=true }
                .accessibilityIdentifier("homeFeed.openOfficialEvents")
            // Templates stay reachable for guests: browse-only, so the capability is the discovery read (`isConfigured`).
            if session.isConfigured {
                // mp-nav r3: templates are the MP 发布 tab (pages/template/index, switchTab); the sheet copy is only for hosts without a tab switch.
                Button("discovery.browseTemplates",systemImage:"square.stack.3d.up") { if rootTabSwitch.isAvailable { rootTabSwitch(.publish) } else { showsTemplates=true } }
                    .accessibilityIdentifier("homeFeed.openTemplates")
            }
            Button("projectEdit.title", systemImage:"square.and.pencil") { showsProjectEditor=true }
                .accessibilityIdentifier("homeFeed.openProjectEditor")
        })
    }
    /// Opens a landed link page as the only page above 首页, so back returns to the feed (MP home button).
    private func openHomeLanding() {
        guard let presentation, let landing = presentation.homeLanding else { return }
        presentation.homeLanding = nil
        search.isPresented = false
        activeContinuationScope = nil
        showsOfficialEvents = false
        showsClubApplication = false
        showsSearchMap = false
        router.resetHome()
        switch landing.target {
        case .page(let route):
            landingRoute = route
        case .topic(let id):
            landingRoute = nil
            router.pushHome(.topic(id))
        case .tab:
            landingRoute = nil
        }
    }
    private var navigationRoot: some View {
        NavigationStack(path:$router.homePath) {
            // Unzoned content needs a separately verified event/backend timezone.
            // Market and interface language alone do not establish one.
            HomeFeedView(
                reader:session.homeFeedReader,
                unavailableMessageKey: session.homeReadAvailability.messageKey,
                viewerNickname: session.account?.nickname,
                viewerAvatar: session.account?.avatar,
                viewerIsMerchant: session.account?.role == "merchant",
                selectedCity: homeCityLabel ?? session.roamArea?.label,
                showsHeroBanners: true,
                continuationCards: continuationCards,
                continuationReadAvailability: continuationReadAvailability,
                onActionBanner: handleActionBanner,
                onContinuation: handleContinuation,
                onRetryContinuation: { Task { await reloadContinuationCards() } },
                todayTicket: todayTicket,
                onOpenTodayTicket: { showsTodayTickets=true },
                onStartRoam: onStartRoam,
                // R7-PC-A1-1 (r1 PC-A-1-3): MP `onManualCityChange` — the 首页 city menu is live.
                onSelectCity: { city, nationwide in selectHomeCity(city, nationwide: nationwide) },
                onLocateCity: session.account == nil ? nil : { relocateHomeCity() },
                cityLocationConsent: cityConsent.asks ? (agree: { agreeAndLocateHomeCity() }, decline: { cityConsent.decline() }) : nil,
                // R7-PC-A5-1 (r1 PC-A-5-1): the hero map button opens the city map, the field opens the list search.
                onOpenUnifiedSearch: { mode in if mode == .map { showsSearchMap = true } else { search.isPresented = true } },
                cityRail: AnyView(CitySessionHomeRail(onOpenMap: { onStartRoam?() })),
                aiShowcase: AnyView(SessionHomeAIShowcase())
            ) { router.pushHome($0) }
                .cyHeroNamespace(hero)
                // P-021: results cover the feed while the field is active; VoiceOver reads only the visible layer.
                .accessibilityHidden(search.isPresented)
                .overlay { searchResults }
                .animation(reduceMotion ? nil : .default, value: search.isPresented)
                .globalSearchField(search)
                .onChange(of: search.isPresented) { _, presented in if !presented { search.reset() } }
                // Design hand-off r1 PL-11: 消息 is the first trailing action on every tab root.
                .modifier(SessionMessagingToolbarEntry(session: session))
                // verify-r1 2.5 / N-12 (owner Q9): the 首页 bar is 消息 then map. Search is the system field under the
                // title (P-021); the map button opens the map presentation of the same search (P-026).
                .toolbar {
                    ToolbarItem(placement:.topBarTrailing) {
                        Button { showsSearchMap = true } label: {
                            Label { Text(verbatim: UnifiedSearchExperience.PresentationMode.map.title(locale: locale)) } icon: { Image(systemName: "map") }
                        }
                            .labelStyle(.iconOnly).frame(minWidth:44,minHeight:44)
                            .accessibilityHint(Text("homeSearch.mapHint"))
                            .accessibilityIdentifier("homeFeed.openGlobalSearch")
                    }
                }
                .environment(\.homeMoreMenuContent, homeMoreMenuContent)
                .task(id: session.squareReader.scope) { await loadSquareCommunityGate() }
                .navigationDestination(for:AppRoute.self) { route in
                    Group {
                        switch route.homeFeedDestination {
                        case .activity(let id): ActivityDetailView(id:id,reader:session,playReaderForActivity:{ session.playReader(for:.activity($0)) },registrationEnabled:true)
                                .cyHeroDestinationWithFallback(HomeFeedDestination.activity(id), in: hero)
                        case .topic(let id): SessionTopicDetailView(id: id, session: session)
                                .cyHeroDestinationWithFallback(HomeFeedDestination.topic(id), in: hero)
                        case nil: EmptyView()
                        }
                    }
                    .cyPushedChrome()
                }
                .navigationDestination(item:$activeContinuationScope) { scope in
                    continuationDestination(scope)
                        .cyPushedChrome()
                }
                // mp-nav r3: MP banners navigateTo /pages/activity/list/index and /pages/club/apply/index (full pages): push.
                .navigationDestination(isPresented:$showsOfficialEvents) {
                    OfficialEventsBrowserView(reader:session.officialEventReader,actions:session.officialActionCoordinator,onLogin:{
                        showsOfficialEvents=false
                        onSignIn?()
                    },topicLinks:OfficialTopicLinks(reader:session.topicReader,destination:{ AnyView(SessionTopicDetailView(id:$0,session:session)) }))
                        .id(session.officialEventReader.scope)
                        .cyPushedChrome()
                }
                .navigationDestination(isPresented:$showsClubApplication) {
                    clubApplicationPage
                }
                .navigationDestination(item: $landingRoute) { route in
                    MPParityDestination(route: route)
                        .cyPushedChrome()
                }
                // mp-nav r3: 动态 is MP pages/square/list/index (navigateTo): a push with system back, no 关闭, no nested stack.
                .navigationDestination(isPresented:$showsSquare) {
                    SessionSquareBrowserView(session: session, onClose: nil, onSignIn: { showsSquare = false; onSignIn?() }, embedsNavigationStack: false)
                        .id(session.squareReader.scope)
                        .cyPushedChrome()
                }
                // mp-nav r3: today's ticket opens the MP 票夹 page (subpackageMember/signup/index, navigateTo): a push like 我的 → 票夹.
                .navigationDestination(isPresented:$showsTodayTickets) {
                    SessionTicketWalletHost(isPushed: true).environmentObject(session)
                        .cyPushedChrome()
                }
                // mp-nav r3: the 小游戏 banner opens a page like the other 首页 banners (activity list, club apply): push, system back.
                .navigationDestination(isPresented: $showsMiniGames) {
                    ScrollView { ExternalGameLibrarySection(store: ExternalGameStore()).padding(.horizontal, CYSpacing.pageHorizontal) }
                        .navigationTitle(Text(verbatim: HomeIndexParityPresentation.miniGamesBanner.title(locale: locale)))
                        .navigationBarTitleDisplayMode(.inline)
                        .accessibilityIdentifier("homeIndex.miniGames")
                        .cyPushedChrome()
                }
                // mp-nav r3: MP pages/searchmap/index is a page (map search, not play): push it with an inline title.
                .navigationDestination(isPresented:$showsSearchMap) {
                    SessionLinkedSearchView(initialQuery: mapQuery, startsOnMap: true, initialArea: homeMapArea, onSignIn: { showsSearchMap = false; onSignIn?() })
                        .environmentObject(session)
                        .cyPushedChrome()
                }
        }
        .onChange(of: presentation?.homeLanding, initial: true) { _, _ in openHomeLanding() }
        .cySheet(isPresented:$showsMerchantApplication) { merchantApplicationSheet.themeDomain(.merchant).cySheet(detents: [.large]) }
    }
    @ViewBuilder private func continuationDestination(_ scope: PlaySessionScope) -> some View {
        if session.playExperience(for: scope) != nil {
            SessionPlayRuntimeView(session: session, destination: .journey(scope))
                .environment(\.playThemeAuxiliaryProvider, session.playThemeAuxiliaryProvider)
        } else {
            switch scope {
            case .activity(let id): ActivityDetailView(id:id,reader:session,playReaderForActivity:{ session.playReader(for:.activity($0)) },registrationEnabled:true)
            case .topic(let id): SessionTopicDetailView(id: id, session: session)
            }
        }
    }
    /// R7-PC-A1-2 (r1 PC-A-1-5): MP `/pages/club/apply/index` — the club host application, the same screen the
    /// deep link opens, not the club browser.
    private var clubApplicationPage: some View {
        MPReviewedPageScreen(page: "pages/club/apply/index", query: [:])
            .environmentObject(session)
            .id(session.sessionRevision)
            .cyPushedChrome()
    }
    private var merchantApplicationSheet: some View {
        NavigationStack {
            MerchantOnboardingView(
                session: session,
                coordinator: session.merchantOnboardingCoordinator
            )
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button("action.close") { showsMerchantApplication = false }
                }
            }
        }.id(session.sessionRevision)
    }
    private func resetForHomeScopeChange() {
        router.resetHome()
        activeContinuationScope=nil
        continuationCoordinator.reset()
        continuationCards=[]
        continuationReadAvailability = .unauthenticated
        search.isPresented = false
        search.reset()
        showsTemplates=false
        showsSquare=false
        showsOfficialEvents=false
        showsProjectEditor=false
        showsClubApplication=false
        showsMerchantApplication=false
        showsSearchMap=false
    }
    private func resetForSessionRevisionChange() {
        activeContinuationScope=nil
        continuationCoordinator.reset()
        continuationCards=[]
        continuationReadAvailability = .unauthenticated
        showsProjectEditor=false
        showsClubApplication=false
        showsMerchantApplication=false
    }
    // MARK: In-place search (P-021)

    /// Settings / Mail pattern: the system field sits in the 首页 bar; while it is active, history, suggestions and
    /// results cover the feed in place. The feed stays mounted underneath, so Cancel returns to it as it was.
    @ViewBuilder private var searchResults: some View {
        if search.isPresented {
            SessionGlobalSearchView(searchSession: search, onSignIn: { search.isPresented = false; onSignIn?() })
                .environment(\.globalTemplateSearch, .session(session))
                .cyGroupedBackground()
                .transition(.opacity)
                .id(session.searchMapReader.scope)
        }
    }
    /// The map presentation of the same query (P-026): the keyword typed so far travels with it.
    private var mapQuery: GlobalSearchQuery? {
        let keyword = search.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return keyword.isEmpty ? nil : GlobalSearchQuery(keyword: keyword)
    }
    /// Function audit P2-3: the area the 首页 map opens on — the area already chosen for roam/search, else the centre of
    /// the 首页 city label (`HomeCityCentre`). Nil (unknown city) keeps the 选择区域 prompt. Reads no location.
    private var homeMapArea: RoamSearchArea? {
        if let area = session.roamArea { return area }
        guard let city = homeCityLabel, let centre = HomeCityCentre.coordinate(for: city) else { return nil }
        return RoamSearchArea(coordinate: centre, label: city)
    }
    /// Function audit P2-3b, MP `getHomeCityLocation` after 同意: record consent, then one foreground fix (the tap is the
    /// permission ask) matched on the device to the nearest supported 首页 city. The coordinate is not sent anywhere;
    /// no fix or no city within range keeps the current label.
    private func agreeAndLocateHomeCity() {
        cityConsent.agree(session)
        let capture = session.cityCaptureFix()
        Task {
            guard let fix = try? await capture() else { return }
            guard let city = HomeCityCentre.nearest(to: fix.coordinate) else { return }
            homeCityStored = city
        }
    }
    /// MP `onTapHomeCity` (pages/index/index.js:1438): the city menu's 使用当前位置 asks the consent read first, then
    /// takes the same one foreground fix as 同意 (matched on the device; the coordinate is never sent).
    private func relocateHomeCity() {
        Task {
            guard await cityConsent.userAsksToLocate(session) else { return }
            let capture = session.cityCaptureFix()
            guard let fix = try? await capture() else { return }
            guard let city = HomeCityCentre.nearest(to: fix.coordinate) else { return }
            homeCityStored = city
        }
    }
    /// MP `onManualCityChange` (pages/index/index.js:1430-1435): 仅本地展示 — store the city name for the 首页 label only.
    /// It does not move `session.roamArea` (search map / roam centre). 全国 keeps the current label.
    private func selectHomeCity(_ city: String?, nationwide: Bool) {
        guard !nationwide, let city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        homeCityStored = city
    }
    private func handleActionBanner(_ banner: HomeIndexParityPresentation.ActionBanner) {
        switch banner.id {
        case "activity_list":
            // R7-PC-A1-2: MP `/pages/activity/list/index` — the activity list, not a feed-tab flip.
            showsOfficialEvents = true
        case "club_apply":
            if session.account == nil { onSignIn?() } else { showsClubApplication = true }
        case "merchant_apply" where PlayerLaunch.merchantCenterEnabled: // Lane G: hidden in Release
            if session.account == nil { onSignIn?() } else { showsMerchantApplication = true }
        case "mini_games":
            if session.account == nil { onSignIn?() } else { showsMiniGames = true }
        default:
            break
        }
    }
    private func handleContinuation(_ card: HomeIndexParityPresentation.ContinuationCard) {
        Task {
            let decision = await continuationCoordinator.verifyNavigation(
                for: card,
                currentOwnerScope: { session.currentHomeContinuationOwnerScope },
                canEnterRuntime: { session.playExperience(for: $0) != nil },
                hasDurableOrLivePause: { await session.hasResumablePlayState(for: $0) }
            )
            continuationCards = continuationCoordinator.cards
            continuationReadAvailability = continuationCoordinator.readAvailability
            switch decision {
            case .enterRuntime(let scope):
                activeContinuationScope = scope
            case .openDetail(let destination):
                router.pushHome(destination)
            case .staleRejected:
                await reloadContinuationCards()
            }
        }
    }
    /// Ticket-within-24h from the wallet read. Not configured, signed out, failed or cancelled => nil (card stays "start a roam").
    /// There is no club-event input: the club home read carries id/title/cover/clubId with no start date, so "today" is unknown.
    private func reloadTodayTicket() async {
        let reader = session.ticketWalletReader
        guard reader.isConfigured, reader.isAuthenticated else { todayTicket = nil; return }
        do {
            let snapshot = try await reader.ticketWallet()
            guard !Task.isCancelled else { return }
            todayTicket = HomeTodayCandidate.nextTicket(from: snapshot.tickets, now: Date())
            QuestWidgetBoardPublisher.nextTicket(todayTicket)
        } catch is CancellationError { return } catch { todayTicket = nil }
    }
    private func reloadContinuationCards() async {
        let reader = session.playerJourneyReader
        let cards = await continuationCoordinator.reload(
            ownerScope: session.currentHomeContinuationOwnerScope,
            isAuthenticated: session.isSignedIn && session.account != nil && reader.isAuthenticated,
            isJourneyReadConfigured: reader.isConfigured,
            currentOwnerScope: { session.currentHomeContinuationOwnerScope },
            loadParticipations: { try await reader.participations() },
            loadPausedRuns: { records in await session.loadPausedContinueRuns(participations: records) }
        )
        continuationCards = cards
        continuationReadAvailability = continuationCoordinator.readAvailability
    }
}

/// City centres for every `HomeHeroCityNames.manualOptions` city. WGS-84, city-hall level.
/// A fix at a city's own centre maps back to that city. The coordinate is never sent.
enum HomeCityCentre {
    private static let table: [String: (Double, Double)] = [
        "上海": (31.2304, 121.4737), "北京": (39.9042, 116.4074), "杭州": (30.2741, 120.1551),
        "成都": (30.5728, 104.0668), "深圳": (22.5431, 114.0579), "广州": (23.1291, 113.2644),
        "重庆": (29.5630, 106.5516), "武汉": (30.5928, 114.3055), "西安": (34.3416, 108.9398),
        "南京": (32.0603, 118.7969), "苏州": (31.2989, 120.5853), "天津": (39.3434, 117.3616),
        "长沙": (28.2282, 112.9388), "郑州": (34.7466, 113.6254), "青岛": (36.0671, 120.3826),
        "厦门": (24.4798, 118.0894), "昆明": (25.0389, 102.7183), "沈阳": (41.8057, 123.4315),
        "济南": (36.6512, 117.1201), "合肥": (31.8206, 117.2272),
    ]
    static func coordinate(for city: String) -> RoamCoordinate? {
        let key = city.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "市", with: "")
        guard let pair = table[key] else { return nil }
        return RoamCoordinate(latitude: pair.0, longitude: pair.1)
    }
    /// The supported city whose centre is nearest, if within `maxKilometres` (great-circle). Nil otherwise.
    static func nearest(to point: RoamCoordinate, maxKilometres: Double = 100) -> String? {
        var best: String?
        var bestKm = maxKilometres
        for (city, pair) in table {
            let km = distanceKilometres(point.latitude, point.longitude, pair.0, pair.1)
            if km <= bestKm {
                bestKm = km
                best = city
            }
        }
        return best
    }
    static func distanceKilometres(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let radians = Double.pi / 180
        let dLat = (lat2 - lat1) * radians
        let dLon = (lon2 - lon1) * radians
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * radians) * cos(lat2 * radians) * sin(dLon / 2) * sin(dLon / 2)
        return 6_371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
