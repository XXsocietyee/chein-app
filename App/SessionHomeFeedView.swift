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
    @State private var showsGlobalSearch=false
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
            TicketWalletView(reader:session.ticketWalletReader,onClose:{ showsTodayTickets=false },makeTeamCoordinator:{ session.makeTeamCoordinator() },orderLifecycleCoordinator:session.orderLifecycleCoordinator).id(session.ticketWalletReader.scope)
                .cyPlayerSheetGlass()
        }
        .onChange(of:session.homeFeedReader.scope) { _,_ in resetForHomeScopeChange() }
        .onChange(of:session.officialEventReader.scope) { _,_ in showsOfficialEvents=false }
        .onChange(of:session.sessionRevision) { _,_ in resetForSessionRevisionChange() }
        .sheet(isPresented:$showsGlobalSearch) {
            NavigationStack {
                SessionGlobalSearchView(onSignIn:{ showsGlobalSearch=false;onSignIn?() })
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) {
                            Button("action.close") { showsGlobalSearch=false }
                                .accessibilityIdentifier("globalSearch.close")
                        }
                    }
            }.id(session.searchMapReader.scope)
            .cyPlayerSheetGlass()
        }
        .sheet(isPresented:$showsProjectEditor) {
            NavigationStack {
                ProjectEditLaunchView().toolbar {
                    ToolbarItem(placement:.cancellationAction) {
                        Button("action.close") { showsProjectEditor=false }
                            .accessibilityIdentifier("projectEditor.close")
                    }
                }
            }.id(session.sessionRevision)
            .themeDomain(.topicEditor)
            .presentationCornerRadius(CYRadius.sheet)
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
                DiscoveryTemplateBrowserView(reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) }, authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext).id(session.templateAuthoringViewIdentity)
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
                onOpenUnifiedSearch: { _ in showsGlobalSearch = true }
            ) { router.pushHome($0) }
                .cyHeroNamespace(hero)
                .toolbar {
                    ToolbarItem(placement:.topBarLeading) { LanguageSwitcher() }
                    // Two actions at most: search, then everything else in one menu.
                    ToolbarItemGroup(placement:.topBarTrailing) {
                        // W1-1: Publish left the tab bar. The "+" opens the former Publish tab content, only when a
                        // publishing session exists (signed in with a token); absent capability hides the entry.
                        if session.publishingSession != nil {
                            Button("homeFeed.create",systemImage:"plus") { showsCreate=true }
                                .labelStyle(.iconOnly).frame(minWidth:44,minHeight:44)
                                .accessibilityIdentifier("homeFeed.openCreate")
                        }
                        Button("searchMap.title",systemImage:"magnifyingglass") { showsGlobalSearch=true }
                            .labelStyle(.iconOnly).frame(minWidth:44,minHeight:44)
                            .accessibilityIdentifier("homeFeed.openGlobalSearch")
                        Menu {
                            Button("square.title",systemImage:"square.grid.2x2") { showsSquare=true }
                                .accessibilityIdentifier("homeFeed.openSquare")
                            Button("official.title",systemImage:"sparkles") { showsOfficialEvents=true }
                                .accessibilityIdentifier("homeFeed.openOfficialEvents")
                            // Templates lived on the Publish tab and must stay reachable for guests: it is browse-only, so the
                            // capability is the discovery read (`isConfigured`), not a publishing session. Hidden when unconfigured.
                            if session.isConfigured {
                                Button("discovery.browseTemplates",systemImage:"square.stack.3d.up") { showsTemplates=true }
                                    .accessibilityIdentifier("homeFeed.openTemplates")
                            }
                            Button("projectEdit.title", systemImage:"square.and.pencil") { showsProjectEditor=true }
                                .accessibilityIdentifier("homeFeed.openProjectEditor")
                        } label: {
                            Label("homeFeed.more", systemImage:"ellipsis.circle")
                                .labelStyle(.iconOnly).frame(minWidth:44,minHeight:44)
                        }
                        .accessibilityIdentifier("homeFeed.moreMenu")
                    }
                }
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
        .sheet(isPresented:$showsClubApplication) { clubApplicationSheet.cyPlayerSheetGlass() }
        .sheet(isPresented:$showsMerchantApplication) { merchantApplicationSheet.themeDomain(.merchant).presentationCornerRadius(CYRadius.sheet) }
        .sheet(isPresented: $showsMiniGames) {
            NavigationStack {
                ScrollView { ExternalGameLibrarySection(store: ExternalGameStore()).padding(.horizontal, CYSpacing.pageHorizontal) }
                    .navigationTitle(Text(verbatim: HomeIndexParityPresentation.miniGamesBanner.title(locale: locale)))
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
        showsGlobalSearch=false
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
