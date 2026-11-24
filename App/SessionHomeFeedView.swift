import SwiftUI

@MainActor struct SessionHomeFeedView:View {
    @EnvironmentObject private var session:AppSession
    var onSignIn:(()->Void)? = nil
    var onStartRoam:(()->Void)? = nil
    @State private var router = AppRouter()
    /// One hero namespace for the Explore stack: feed cards are zoom sources, the pushed detail is the destination.
    @Namespace private var hero
    @State private var activeContinuationScope:PlaySessionScope?=nil
    @State private var continuationCoordinator = HomeContinuationCoordinator()
    @State private var continuationCards:[HomeIndexParityPresentation.ContinuationCard]=[]
    @State private var continuationReadAvailability:HomeContinuationReadAvailability = .unauthenticated
    @State private var todayTicket:HomeTodayCandidate?=nil
    @State private var showsTodayTickets=false
    /// Continuity r1: search is a state of 首页, not a sheet. See `searchLayer`.
    @State private var search = HomeInPageSearch()
    @State private var searchSource = HomeSearchSourceBox()
    @QuestifyReduceMotion private var reduceMotion
    @State private var showsTemplates=false
    @State private var showsCreate=false
    @State private var showsSquare=false
    @State private var showsOfficialEvents=false
    @State private var showsProjectEditor=false
    @State private var showsClubApplication=false
    @State private var showsMerchantApplication=false
    @State private var showsMiniGames = false
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
        .sheet(isPresented:$showsTodayTickets) {
            SessionTicketWalletHost(onClose:{ showsTodayTickets=false }).environmentObject(session)
                .cyPlayerSheetGlass()
        }
        .onChange(of:session.homeFeedReader.scope) { _,_ in resetForHomeScopeChange() }
        .onChange(of:session.officialEventReader.scope) { _,_ in showsOfficialEvents=false }
        .onChange(of:session.sessionRevision) { _,_ in resetForSessionRevisionChange() }
        .sheet(isPresented:$showsProjectEditor) { Group {
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
        .sheet(isPresented:$showsOfficialEvents) {
            OfficialEventsBrowserView(reader:session.officialEventReader,actions:session.officialActionCoordinator,onClose:{ showsOfficialEvents=false },onLogin:{
                showsOfficialEvents=false
                onSignIn?()
            },topicLinks:OfficialTopicLinks(reader:session.topicReader,destination:{ AnyView(SessionTopicDetailView(id:$0,session:session)) })).id(session.officialEventReader.scope)
            .cyPlayerSheetGlass()
        }
        .sheet(isPresented:$showsSquare) { SessionSquareBrowserView(session: session, onClose: { showsSquare = false }, onSignIn: { showsSquare = false; onSignIn?() }).id(session.squareReader.scope).cyPlayerSheetGlass() }
        .sheet(isPresented:$showsCreate) {
            NavigationStack {
                DiscoveryTemplateBrowserView(reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) }, authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext,
                    publishDestination: { AnyView(SessionPublishingModesView().environmentObject(session).id(session.publishingSession?.epoch)) })
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
        .sheet(isPresented:$showsTemplates) {
            NavigationStack {
                // PC-A-2-6: 浏览模板 keeps 发布 like the 发布 tab entry.
                DiscoveryTemplateBrowserView(reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) }, authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext,
                    publishDestination: { AnyView(SessionPublishingModesView().environmentObject(session).id(session.publishingSession?.epoch)) }).id(session.templateAuthoringViewIdentity)
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
                selectedCity: session.roamArea?.label,
                showsHeroBanners: true,
                continuationCards: continuationCards,
                continuationReadAvailability: continuationReadAvailability,
                onActionBanner: handleActionBanner,
                onContinuation: handleContinuation,
                onRetryContinuation: { Task { await reloadContinuationCards() } },
                todayTicket: todayTicket,
                onOpenTodayTicket: { showsTodayTickets=true },
                onStartRoam: onStartRoam,
                cityLocationConsent: cityConsent.asks ? (agree: { cityConsent.agree(session) }, decline: { cityConsent.decline() }) : nil,
                onOpenUnifiedSearch: { _ in openSearch() },
                cityRail: AnyView(CitySessionHomeRail(onOpenMap: { onStartRoam?() }))
            ) { router.pushHome($0) }
                .cyHeroNamespace(hero)
                .environment(\.homeSearchSource, HomeSearchSourceContext(box: searchSource, isHidden: search.mounted && search.placed && search.source != nil, returnFocus: search.returnFocus))
                // Design hand-off r1 PL-11: 消息 is the first trailing action on every tab root.
                .modifier(SessionMessagingToolbarEntry(session: session))
                // verify-r1 2.5 / N-12 (owner Q9): the 首页 bar is 消息 then search. Language is in 我的 → 设置; ＋ is the
                // 发布 tab; the former ⋯ items are in the 更多玩法 menu under the greeting.
                .toolbar {
                    ToolbarItem(placement:.topBarTrailing) {
                        Button("searchMap.title",systemImage:"magnifyingglass") { openSearch() }
                            .labelStyle(.iconOnly).frame(minWidth:44,minHeight:44)
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
        // Search covers the whole 首页 stack, bar and large title included, so the title fades with the page.
        .overlay { searchLayer }
        .onChange(of:activeContinuationScope) { _,next in if next == nil { Task { await reloadContinuationCards() } } }
        .onChange(of:router.homePath) { _,next in if next.isEmpty { Task { await reloadContinuationCards() } } }
        .sheet(isPresented:$showsClubApplication) { clubApplicationSheet.cyPlayerSheetGlass() }
        .sheet(isPresented:$showsMerchantApplication) { merchantApplicationSheet.themeDomain(.merchant).cySheet(detents: [.large]) }
        .sheet(isPresented: $showsMiniGames) {
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
    private var clubApplicationSheet: some View {
        NavigationStack {
            ClubHomeView(
                reader: session,
                onSignIn: { showsClubApplication = false; onSignIn?() },
                actionCoordinator: session.clubActionCoordinator,
                management: session.clubManagementContext,
                community: session.clubCommunityContext,
                topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) },
                authorSquare: session.squareReader
            )
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button("action.close") { showsClubApplication = false }
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
        search = HomeInPageSearch(returnFocus: search.returnFocus)
        showsTemplates=false
        showsSquare=false
        showsOfficialEvents=false
        showsProjectEditor=false
        showsClubApplication=false
        showsMerchantApplication=false
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
    // MARK: In-page search (continuity r1)

    /// One element, not two: the 首页 field the user tapped rises into the search top row (the 首页 copy hides the
    /// instant the search copy covers it), the page and large title fade under an opaque ground in the first 30 %,
    /// 取消 slides in from the trailing edge, and history, suggestions and 筛选 fade in after 50 %. 取消 runs the
    /// same progress back to 0. Results push inside this layer's own stack, as they did inside the old sheet.
    @ViewBuilder private var searchLayer: some View {
        if search.mounted {
            let travels = search.source != nil
            ZStack {
                CYColor.bgPage.ignoresSafeArea()
                    .modifier(GlobalSearchProgressFade(progress: search.progress, start: 0, end: travels ? 0.3 : 1))
                NavigationStack {
                    SessionGlobalSearchView(onSignIn: { search = HomeInPageSearch(returnFocus: search.returnFocus); onSignIn?() })
                        .environment(\.globalTemplateSearch, .session(session))
                        .toolbar(.hidden, for: .navigationBar)
                        .modifier(HomeSearchClearStackBackground())
                }
                .id(session.searchMapReader.scope)
            }
            // No travel (Reduce Motion, iOS 17, field scrolled away): the whole state cross-fades in place.
            .modifier(GlobalSearchProgressFade(progress: travels ? 1 : search.progress, start: 0, end: 1))
            .environment(\.globalSearchInPageHost, GlobalSearchInPageHost(
                source: search.source, progress: search.progress,
                onCancel: closeSearch, onFieldPlaced: searchFieldPlaced))
            // Input is never blocked: while closing, touches fall through to the feed.
            .allowsHitTesting(search.progress == 1)
            .accessibilityAddTraits(.isModal)
        }
    }
    private var searchMotion: Animation { reduceMotion ? CYMotion.reduced : CYMotion.standard }
    private func openSearch() {
        search.generation += 1
        if search.mounted {
            // Re-opened mid-close: retarget the same progress, no remount.
            withAnimation(searchMotion) { search.progress = 1 }
            return
        }
        let frame = searchSource.frame
        var travels = !reduceMotion && frame.width > 1
        if #unavailable(iOS 18.0) { travels = false }
        search.source = travels ? frame : nil
        search.placed = false
        search.progress = 0
        search.mounted = true
    }
    /// The search field has its resting frame: hide the 首页 copy under it and start the move.
    private func searchFieldPlaced(_ rest: CGRect) {
        guard search.mounted, !search.placed else { return }
        // A field scrolled out of view has no box worth travelling from.
        if let source = search.source, source.maxY < rest.minY { search.source = nil }
        search.placed = true
        withAnimation(searchMotion) { search.progress = 1 }
        // VoiceOver: the in-page layer is a new screen (`.isModal`), not a system presentation, so nothing moves the
        // VoiceOver cursor off the hidden 首页 field. A screen change lands it on the layer's first element, the field.
        AccessibilityNotification.ScreenChanged(nil).post()
    }
    private func closeSearch() {
        guard search.mounted else { return }
        search.generation += 1
        let generation = search.generation
        withAnimation(searchMotion, completionCriteria: .logicallyComplete) {
            search.progress = 0
        } completion: {
            guard search.generation == generation else { return }
            search = HomeInPageSearch(returnFocus: search.returnFocus + 1)
        }
    }
    private func handleActionBanner(_ banner: HomeIndexParityPresentation.ActionBanner) {
        switch banner.id {
        case "club_apply":
            if session.account == nil { onSignIn?() } else { showsClubApplication = true }
        case "merchant_apply":
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

/// 首页's search state. `progress` is the one animated value; everything else is bookkeeping.
private struct HomeInPageSearch {
    var mounted = false
    /// The search field has measured itself and stands over the 首页 field.
    var placed = false
    var progress: CGFloat = 0
    var source: CGRect?
    var generation = 0
    var returnFocus = 0
}

/// iOS 18: the layer's stack draws no ground of its own, so the feed shows until the search ground fades in.
/// iOS 17 never travels (see `openSearch`), so the stack's own ground fades with the layer.
private struct HomeSearchClearStackBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.containerBackground(.clear, for: .navigation)
        } else {
            content
        }
    }
}
