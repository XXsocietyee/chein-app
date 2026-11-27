import SwiftUI

@MainActor struct SessionHomeFeedView:View {
    @EnvironmentObject private var session:AppSession
    var onSignIn:(()->Void)? = nil
    var onStartRoam:(()->Void)? = nil
    @State private var router = AppRouter()
    /// R8-PC-A1-1 MP-first: the 首页 city is a local label only (MP `onManualCityChange`), never the global roam centre.
    @State private var homeCityLabel: String?
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
    @State private var showsOfficialEvents=false
    @State private var showsProjectEditor=false
    @State private var showsClubApplication=false
    @State private var showsMerchantApplication=false
    @State private var showsMiniGames = false
    @State private var showsSearchMap = false
    @Environment(\.locale) private var locale
    @StateObject private var cityConsent = HomeCityLocationConsentModel()
    var body:some View {
        navigationRoot
        .id(session.homeFeedReader.scope)
        .task(id:session.playerJourneyReader.scope) { await reloadContinuationCards() }
        .task(id:session.ticketWalletReader.scope) { await reloadTodayTicket() }
        .task(id:session.homeFeedReader.scope) { await cityConsent.refresh(session) }
        .task(id:session.sessionRevision) { await cityConsent.refresh(session) }
        .cyToast(message: $cityConsent.toast)
        .cySheet(isPresented:$showsTodayTickets) {
            SessionTicketWalletHost(onClose:{ showsTodayTickets=false }).environmentObject(session)
                .cyPlayerSheetGlass()
        }
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
        .cySheet(isPresented:$showsOfficialEvents) {
            NavigationStack {
            OfficialEventsBrowserView(reader:session.officialEventReader,actions:session.officialActionCoordinator,onClose:{ showsOfficialEvents=false },onLogin:{
                showsOfficialEvents=false
                onSignIn?()
            },topicLinks:OfficialTopicLinks(reader:session.topicReader,destination:{ AnyView(SessionTopicDetailView(id:$0,session:session)) }))
            }.id(session.officialEventReader.scope)
            .cyPlayerSheetGlass()
        }
        .cySheet(isPresented:$showsSquare) { SessionSquareBrowserView(session: session, onClose: { showsSquare = false }, onSignIn: { showsSquare = false; onSignIn?() }).id(session.squareReader.scope).cyPlayerSheetGlass() }
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
    /// verify-r1 2.5: the former header ⋯ items, shown in the 更多玩法 menu under the greeting.
    private var homeMoreMenuContent: AnyView {
        AnyView(Group {
            Button("square.title",systemImage:"square.grid.2x2") { showsSquare=true }
                .accessibilityIdentifier("homeFeed.openSquare")
            Button("official.title",systemImage:"sparkles") { showsOfficialEvents=true }
                .accessibilityIdentifier("homeFeed.openOfficialEvents")
            // Templates stay reachable for guests: browse-only, so the capability is the discovery read (`isConfigured`).
            if session.isConfigured {
                Button("discovery.browseTemplates",systemImage:"square.stack.3d.up") { showsTemplates=true }
                    .accessibilityIdentifier("homeFeed.openTemplates")
            }
            Button("projectEdit.title", systemImage:"square.and.pencil") { showsProjectEditor=true }
                .accessibilityIdentifier("homeFeed.openProjectEditor")
        })
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
                cityLocationConsent: cityConsent.asks ? (agree: { cityConsent.agree(session) }, decline: { cityConsent.decline() }) : nil,
                // R7-PC-A5-1 (r1 PC-A-5-1): the hero map button opens the city map, the field opens the list search.
                onOpenUnifiedSearch: { mode in if mode == .map { showsSearchMap = true } else { search.isPresented = true } },
                cityRail: AnyView(CitySessionHomeRail(onOpenMap: { onStartRoam?() }))
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
        }
        .onChange(of:activeContinuationScope) { _,next in if next == nil { Task { await reloadContinuationCards() } } }
        .onChange(of:router.homePath) { _,next in if next.isEmpty { Task { await reloadContinuationCards() } } }
        .cySheet(isPresented:$showsClubApplication) { clubApplicationSheet.cyPlayerSheetGlass() }
        .cySheet(isPresented:$showsMerchantApplication) { merchantApplicationSheet.themeDomain(.merchant).cySheet(detents: [.large]) }
        .cySheet(isPresented: $showsSearchMap) {
            NavigationStack {
                SessionLinkedSearchView(initialQuery: mapQuery, startsOnMap: true, onSignIn: { showsSearchMap = false; onSignIn?() })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("action.close") { showsSearchMap = false }
                                .accessibilityIdentifier("homeFeed.searchMap.close")
                        }
                    }
            }
            .environmentObject(session)
            .cyPlayerSheetGlass()
        }
        .cySheet(isPresented: $showsMiniGames) {
            NavigationStack {
                ScrollView { ExternalGameLibrarySection(store: ExternalGameStore()).padding(.horizontal, CYSpacing.pageHorizontal) }
                    .navigationTitle(Text(verbatim: HomeIndexParityPresentation.miniGamesBanner.title(locale: locale)))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("action.close") { showsMiniGames = false }
                                .accessibilityIdentifier("miniGames.close")
                        }
                    }
            }
            .accessibilityIdentifier("homeIndex.miniGames")
            .cyPlayerSheetGlass()
        }
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
    private var clubApplicationSheet: some View {
        NavigationStack {
            MPReviewedPageScreen(page: "pages/club/apply/index", query: [:])
                .environmentObject(session)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) {
                        Button("action.close") { showsClubApplication = false }
                            .accessibilityIdentifier("clubApplication.close")
                    }
                }
        }.id(session.sessionRevision)
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
    /// MP `onManualCityChange` (pages/index/index.js:1430-1435): 仅本地展示 — store the city name for the 首页 label only.
    /// It does not move `session.roamArea` (search map / roam centre). 全国 keeps the current label.
    private func selectHomeCity(_ city: String?, nationwide: Bool) {
        guard !nationwide, let city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        homeCityLabel = city
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

/// City centres for the 首页 city menu (`HomeCitySwitchState.defaultSupportedCities`). WGS-84, city-hall level.
enum HomeCityCentre {
    private static let table: [String: (Double, Double)] = [
        "上海": (31.2304, 121.4737), "北京": (39.9042, 116.4074), "杭州": (30.2741, 120.1551),
        "成都": (30.5728, 104.0668), "深圳": (22.5431, 114.0579), "广州": (23.1291, 113.2644),
    ]
    static func coordinate(for city: String) -> RoamCoordinate? {
        let key = city.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "市", with: "")
        guard let pair = table[key] else { return nil }
        return RoamCoordinate(latitude: pair.0, longitude: pair.1)
    }
}
