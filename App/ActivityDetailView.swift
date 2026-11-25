import SwiftUI
import MapKit

@MainActor
struct ActivityDetailView: View {
    let id: Int
    let reader: any ActivityReading
    var playReaderForActivity: ((Int)->PlaySessionReader)? = nil
    var registrationEnabled = false
    var peopleProfile: ActivityPeopleProfileContext? = nil
    var requiredClubDestination: ((Int, @escaping () -> Bool) -> AnyView)? = nil
    var hostCancelAccess: (any ActivityHostCancelAccess)? = nil
    /// DEBUG design fixtures open the "More info" disclosure on first appearance; production always starts collapsed.
    var startsWithMoreInfoOpen = false
    /// MP `pages/activity/baoming` link: open the registration sheet once the detail loads and sign-up is the action.
    var opensRegistrationOnLoad = false
    /// MP `baoming?ticketId=` (R7-PC-C2-3): preselect this ticket in the auto-opened sheet.
    var registrationTicketID: Int? = nil
    var body: some View {
        if let session = reader as? AppSession {
            SessionActivityDetailView(id: id, session: session,
                playReaderForActivity: playReaderForActivity, registrationEnabled: registrationEnabled,
                hostCancelAccess: hostCancelAccess, opensRegistrationOnLoad: opensRegistrationOnLoad,
                registrationTicketID: registrationTicketID)
        } else {
            ActivityDetailContentView(id: id, reader: reader,
                playReaderForActivity: playReaderForActivity, registrationEnabled: registrationEnabled,
                peopleProfile: peopleProfile, requiredClubDestination: requiredClubDestination,
                hostCancelAccess: hostCancelAccess, startsWithMoreInfoOpen: startsWithMoreInfoOpen,
                opensRegistrationOnLoad: opensRegistrationOnLoad, registrationTicketID: registrationTicketID)
        }
    }
}

@MainActor private struct SessionActivityDetailView: View {
    let id: Int
    @ObservedObject var session: AppSession
    var playReaderForActivity: ((Int)->PlaySessionReader)?
    var registrationEnabled: Bool
    var hostCancelAccess: (any ActivityHostCancelAccess)? = nil
    var opensRegistrationOnLoad = false
    var registrationTicketID: Int? = nil
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    /// R8-PC-C1-1: without a tab switch (a pushed deep link) the guest 立即报名 presents sign-in instead of doing nothing.
    @State private var showsGuestLogin = false
    var body: some View {
        Group {
            // Sign-in belongs on 立即报名. The detail read itself runs with a nil token.
            if session.account == nil {
                sessionDetail(guestSignIn: { if rootTabSwitch.isAvailable { rootTabSwitch(.mine) } else { showsGuestLogin = true } })
            } else {
                sessionDetail(guestSignIn: nil)
            }
        }
        .sheet(isPresented: $showsGuestLogin) {
            Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .onChange(of: session.account == nil) { _, signedOut in if !signedOut { showsGuestLogin = false } }
        .appNavigationTitle("activity.details")
        .navigationBarTitleDisplayMode(.inline)
        .cyPushedChrome(domain: .player)
        .cyDomainPageBackground()
        .cyHideTabBar()
    }

    @ViewBuilder private func sessionDetail(guestSignIn: (() -> Void)?) -> some View {
        let activityIdentity = session.activityPresentationIdentity
        let clubIdentity = session.clubIdentity
        ActivityDetailContentView(id: id, reader: session,
            playReaderForActivity: playReaderForActivity,
            topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) },
            registrationEnabled: registrationEnabled,
            peopleProfile: .init(reader: session.socialAccountReader, squareReader: session.squareReader, actions: session.socialActionCoordinator),
            requiredClubDestination: { clubID, selectionCurrent in
                AnyView(CoopRelationClubProfileHost(id: clubID, base: session, isCurrent: { [weak session] in
                    guard let session else { return false }
                    return selectionCurrent() && session.account != nil &&
                        session.activityPresentationIdentity == activityIdentity && session.clubIdentity == clubIdentity
                }))
            },
            hostCancelAccess: hostCancelAccess ?? session.activityHostCancelAccess,
            opensRegistrationOnLoad: guestSignIn == nil && opensRegistrationOnLoad,
            registrationTicketID: registrationTicketID,
            guestSignIn: guestSignIn)
            .environment(\.inGameChannelHost, session.inGameChannelHost)
            .id(session.contentDetailRevision)
    }
}

@MainActor private struct ActivityDetailContentView: View {
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analyticsEventClient) private var analytics
    let id: Int
    let reader: any ActivityReading
    var playReaderForActivity: ((Int)->PlaySessionReader)? = nil
    var topicDestination: ((Int) -> AnyView)? = nil
    var registrationEnabled=false
    var peopleProfile: ActivityPeopleProfileContext? = nil
    var requiredClubDestination: ((Int, @escaping () -> Bool) -> AnyView)? = nil
    var hostCancelAccess: (any ActivityHostCancelAccess)? = nil
    var startsWithMoreInfoOpen = false
    var opensRegistrationOnLoad = false
    var registrationTicketID: Int? = nil
    /// Guest 立即报名. Nil for a signed-in reader, which opens the registration sheet instead.
    var guestSignIn: (() -> Void)? = nil
    @State private var openedRegistrationOnLoad = false
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    /// Collapsed by default: the 12 secondary sections live behind one disclosure row.
    @State private var showsMoreInfo = false
    @State private var loadedPeopleSnapshotID: UUID?
    @State private var loadedProfileIdentity: SocialAccountIdentity?
    @State private var profileSelection: ActivityPersonProfileSelection?
    @State private var requiredClubSelection: ActivityRequiredClubSelection?
    @State private var gateReadID: UUID?
    @State private var gateActivityID: Int?
    @State private var latestGateActivityID: Int?
    @State private var gateReaderID: ObjectIdentifier?
    @State private var gateReaderIdentity: String?
    @State private var latestGateReaderID: ObjectIdentifier?
    @State private var gatePresentationID = UUID()
    @State private var gateIsVisible = false
    @State private var showsReview = false
    @State private var showsRegistration=false
    @State private var showsTicketWallet=false
    @State private var showsHostCancelFromFooter=false
    /// Continuity r1 (+): the footer pill is the zoom source of the registration / ticket-wallet sheet it opens. The first
    /// tile (`performPrimaryAction`) opens the same sheets; it sets this so they keep the plain slide-up. Cleared on dismiss.
    @State private var tileOpenedSheet = false
    @Namespace private var footerHero
    @State private var showsPlay = false
    /// One load lifecycle instead of `access` / `loading` / `failed` (docs/release/state-machines/views.md).
    @State private var phase: CYPhase<ActivityDetailAccess, Void> = .idle
    private var access: ActivityDetailAccess? { phase.value }
    @State private var heroScrolledAway = false
    /// verify-r1 1.3: no 活动详情 over the hero; the activity's name appears inline once the hero has scrolled away.
    private var navigationTitleText: String {
        if let access, case .allowed(let detail) = access {
            return heroScrolledAway ? (ActivityPresentation.nonempty(detail.summary.name) ?? "") : ""
        }
        return appLocalized("activity.details", locale: locale)
    }
    @State private var generation=0
    @State private var loads = SignedInContentDetailLoadOwner()
    @State private var showsShare = false
    @Environment(\.timeZone) private var shareTimeZone
    private var gateScope: ActivityRequiredClubScope? {
        guard gateActivityID == id, latestGateActivityID == id,
              gateReaderID == ObjectIdentifier(reader), latestGateReaderID == ObjectIdentifier(reader),
              gateReaderIdentity == reader.activityPresentationIdentity else { return nil }
        return .init(activityID: id, readerID: ObjectIdentifier(reader), identity: reader.activityPresentationIdentity,
                     readID: gateReadID, presentationID: gatePresentationID, isConfigured: reader.isConfigured)
    }
    var body: some View {
        // Group with nil access produces EmptyView, which cannot host the initial task.
        // Keep one concrete root for the task and navigation title through every state.
        ZStack {
            switch phase {
            case .idle, .loading, .empty:
                loadingState
            case .failed:
                ScrollView {
                    VStack(spacing: CYSpacing.lg) {
                        CYStateArt(kind: .failure)
                        Text("activity.loadFailed")
                            .cyText(.sectionTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("activity.detail.error")
                        CYPillButton("action.retry") { loads.start { await load() } }
                            .accessibilityIdentifier("activity.detail.retry")
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.vertical, CYSpacing.xl)
                }
            case .loaded(let access):
                switch access {
                case .clubRequired(_, let message):
                    clubGate(message)
                case .allowed(let detail):
                    detailContent(detail)
                case .cancelled(let canViewOwnOrders):
                    // MP activity detail: a cancelled activity shows the cancelled state; 查看订单 only for the player's own orders.
                    ActivityCancelledStateView(canViewOwnOrders: canViewOwnOrders && rootTabSwitch.isAvailable,
                                               onViewOrders: { rootTabSwitch(.mine) }, onBack: { dismiss() })
                        .accessibilityIdentifier("activity.detail.cancelled")
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .toolbar {
            if let access, case .allowed(let detail) = access {
                ToolbarItem(placement: .topBarTrailing) {
                    UGCSafetyMenuButton(
                        presentation: UGCReportPresentationTarget(
                            target: .activity(activityID: detail.summary.id),
                            subjectTitle: detail.summary.name,
                            authorMemberID: detail.people.host?.memberID,
                            authorName: detail.people.host?.name
                        )
                    )
                    .accessibilityIdentifier("activity.safety.menu")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsShare = true
                        MiniProgramAnalytics.track(analytics, "content_share", bizType: "activity", bizID: MiniProgramAnalytics.bizID(id), pagePath: "/pages/activity/detail/index")
                    } label: { Label("activity.share", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("activity.share")
                }
            }
        }
        .environment(\.ugcSafetySubjectID, id)
        .sheet(isPresented: $showsShare) {
            if let access, case .allowed(let detail) = access {
                CatalogShareCardView(content: shareContent(detail), tint: .sunset)
                    .themeDomain(.player)
                    .cySheet()
            }
        }
        .cyDomainPageBackground()
        .task(id:id) { await loads.run { await load() } }
        .onAppear { gateIsVisible = true; gatePresentationID = UUID(); if startsWithMoreInfoOpen { showsMoreInfo = true } }
        .onDisappear { loads.cancel(); generation += 1; if phase.isLoading { phase = .idle } }
        .onDisappear { gateIsVisible = false; gatePresentationID = UUID() }
        .onChange(of: id) { _, value in
            latestGateActivityID = value; gateReadID = nil; requiredClubSelection = nil
        }
        .onChange(of: ObjectIdentifier(reader)) { _, value in
            latestGateReaderID = value; gateReadID = nil; requiredClubSelection = nil
        }
        .onChange(of: reader.activityPresentationIdentity) { _, _ in gateReadID = nil; requiredClubSelection = nil }
        .navigationDestination(item: $requiredClubSelection) { selection in
            if selection.mayRemainOpen(access: access, in: gateScope), let requiredClubDestination {
                requiredClubDestination(selection.clubID, {
                    requiredClubSelection?.id == selection.id && selection.mayRemainOpen(access: access, in: gateScope)
                })
            } else {
                ContentUnavailableView("activity.requiredClub.changed", systemImage: "arrow.clockwise")
                    .accessibilityIdentifier("activity.requiredClub.stale")
            }
        }
        .onChange(of: peopleProfile?.reader.identity) { _, _ in
            profileSelection = nil; loadedProfileIdentity = nil
            loads.start { await load() }
        }
        .navigationDestination(item: $profileSelection) { selection in
            if let peopleProfile, let loadedPeopleSnapshotID, let access, case .allowed(let detail) = access,
               loadedProfileIdentity == peopleProfile.reader.identity,
               selection.matches(activityID: id, people: detail.people, identity: peopleProfile.reader.identity, snapshotID: loadedPeopleSnapshotID) {
                SocialPublicProfileView(memberID: selection.memberID, reader: peopleProfile.reader,
                                        squareReader: peopleProfile.squareReader, actions: peopleProfile.actions)
                    .id(selection)
            } else {
                ContentUnavailableView("social.changed", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .sheet(isPresented: $showsReview) {
            NavigationStack { ContextualReviewComposer(target: .activity(id), owner: (reader as? AppSession)?.contextualReviews?.coordinator(.activity(id))) { loads.start { await load() } } }
                .themeDomain(.player)
                .cySheet()
        }
        .sheet(isPresented:$showsRegistration, onDismiss: { tileOpenedSheet = false }) {
            Group {
            if let access,case .allowed(let detail)=access { SessionRegistrationSheet(activity:detail) }
            }
            .environment(\.registrationPreselectedTicketID, registrationTicketID)
            .modifier(ActivityFooterHeroDestination(active: !tileOpenedSheet, namespace: footerHero))
            .themeDomain(.player)
            .cySheet(detents: [.large])
        }
        .navigationDestination(isPresented: $showsPlay) {
            // E2E-20261113b N3: a registered player's "Continue exploring" opens the play session for this activity.
            // N5: the full runtime (advanced prerequisites, hint ladder, TEAM backpack) when this session can build it;
            // the basic reader otherwise.
            if let session = reader as? AppSession, session.playExperience(for: .activity(id)) != nil {
                SessionPlayRuntimeView(session: session, destination: .journey(.activity(id)))
            } else if let playReaderForActivity { PlaySessionView(reader: playReaderForActivity(id)) }
        }
        .sheet(isPresented:$showsTicketWallet, onDismiss: { tileOpenedSheet = false }) {
            // Source: a registered viewer's CTA opens the ticket wallet (subpackageMember/signup).
            if let session = reader as? AppSession {
                SessionTicketWalletHost(onClose:{ showsTicketWallet=false })
                    .environmentObject(session)
                    .modifier(ActivityFooterHeroDestination(active: !tileOpenedSheet, namespace: footerHero))
                    .themeDomain(.player)
                    .cySheet(detents: [.large])
            }
        }
    }
    /// Share card content: name, date, price / spots / category, and the place name only behind the composer's toggle.
    private func shareContent(_ detail: ActivityDetail) -> CYShareCardContent {
        let summary = detail.summary
        let price: String? = summary.minimumAmount == Decimal.zero
            ? appLocalized("share.card.free", locale: locale)
            : summary.minimumAmount.flatMap { $0 >= 0 ? MoneyDisplay.yuan($0) : nil }  // owner decision 9: ¥12.50
        let place = ActivityPresentation.nonempty(summary.addressName) ?? ActivityPresentation.nonempty(summary.address)
        // Spots left is the sum over tickets that report an inventory; no ticket reporting one stays unknown (em dash).
        let inventories = detail.tickets.compactMap(\.remainingInventory)
        let spotsLeft: String? = inventories.isEmpty ? nil : String(max(0, inventories.reduce(0, +)))
        return CYShareCardContent(
            kind: .activity,
            eyebrow: appLocalized("share.card.activity.eyebrow", locale: locale),
            title: ActivityPresentation.nonempty(summary.name) ?? "—",
            subtitle: QuestifyCardText.date(summary.startDate, locale: locale, displayTimeZone: shareTimeZone),
            place: place,
            stats: [
                CYShareStat(appLocalized("share.card.stat.price", locale: locale), price),
                CYShareStat(appLocalized("share.card.stat.spots", locale: locale), spotsLeft),
                CYShareStat(appLocalized("share.card.stat.category", locale: locale), summary.categoryNames.first),
            ],
            silhouette: summary.hasValidCoordinates ? [CGPoint(x: 0.5, y: 0.5)] : [],
            artSeed: summary.name,
            artSymbol: ["figure.walk", "music.note", "camera", "leaf", "building.2", "moon.stars", "map"][abs(summary.id) % 7],
            brand: appLocalized("share.card.brand", locale: locale))
    }
    private var loadingState: some View {
        ScrollView {
            CYSkeleton()
                .accessibilityHidden(true)
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
        }
        .accessibilityLabel(Text("activity.loading"))
    }

    private func clubGate(_ message: String?) -> some View {
        ScrollView {
            VStack(spacing: CYSpacing.lg) {
                CYStateArt(kind: CYStateKind(symbol: "lock"))
                Text("activity.clubRequired")
                    .cyText(.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("activity.detail.clubGate")
                if let message, !message.isEmpty {
                    Text(verbatim: message)
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("activity.clubRequiredHint")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let access { requiredClubAction(access) }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.xl)
        }
    }

    @ViewBuilder private func requiredClubAction(_ renderedAccess: ActivityDetailAccess) -> some View {
        let renderedScope = gateScope
        let clubID: Int? = {
            if case .clubRequired(let value, _) = renderedAccess { return value }
            return nil
        }()
        if let clubID, clubID > 0 {
            Button {
                guard gateIsVisible, requiredClubSelection == nil, requiredClubDestination != nil,
                      let selection = ActivityRequiredClubSelection(access: renderedAccess, currentAccess: access,
                          rendered: renderedScope, current: gateScope) else { return }
                requiredClubSelection = selection
            } label: {
                Label("activity.requiredClub.open", systemImage: "person.3")
                    .fixedSize(horizontal: false, vertical: true)
            }
                .buttonStyle(CYPillButtonStyle())
                .disabled(requiredClubDestination == nil || renderedScope == nil || !gateIsVisible || requiredClubSelection != nil)
                .accessibilityIdentifier("activity.requiredClub.open")
                .accessibilityLabel(Text("activity.requiredClub.open"))
        }
        if requiredClubDestination == nil || renderedScope == nil || (clubID ?? 0) <= 0 {
            Text("activity.requiredClub.unavailable").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("activity.requiredClub.unavailable")
        }
    }
    /// First fold: hero, three action tiles, info card, map, about, people, tickets, reviews, one "More info" row.
    /// Everything else (plays, journeys) sits behind the disclosure; host cancel stays its own section.
    private func detailContent(_ detail:ActivityDetail) -> some View {
        ScrollViewReader { proxy in
        List {
            Section {
                E1ActivityHero(summary:detail.summary)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                E1ActivityStatsRow(detail: detail)
                    .questifyCardListRow()
                E1ActivitySectionTabs(proxy: proxy)
                    .listRowInsets(EdgeInsets()).listRowBackground(palette.bgPage).listRowSeparator(.hidden)
                ActivityActionTiles(onDirections: directionsAction(detail),
                                    onReview: canReview(detail) ? { showsReview = true } : nil)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                E1ActivityInfoCard(detail:detail)
                    .questifyCardListRow()
                    .id(E1ActivityAnchor.overview.rawValue)
                if primaryAction != .signUp, !detail.isCancelled {
                    InGameChannelRowButton(
                        scope: .activity(id: id),
                        titleKey: "ingame.channel.activity",
                        subtitleKey: "ingame.channel.activitySubtitle",
                        accessibilityID: "ingame.channel.activity.entry",
                        reloadTrigger: primaryAction
                    )
                    .questifyCardSurface()
                    .questifyCardListRow()
                }
            }
            if detail.isCancelled {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYStatusChip("activity.cancelled.title", tone: .danger, systemImage: "xmark.octagon")
                        if let reason = detail.cancelReason { Text("activity.cancelled.reason \(reason)").fixedSize(horizontal: false, vertical: true) }
                        Text("activity.cancelled.hint").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .questifyCardSurface()
                    .questifyCardListRow()
                    .accessibilityIdentifier("activity.detail.cancelled")
                }
            }
            if detail.summary.hasValidCoordinates,
               let latitude=detail.summary.latitude, let longitude=detail.summary.longitude {
                Section("activity.location") {
                    let coordinate=CLLocationCoordinate2D(latitude:latitude,longitude:longitude)
                    // Static map: an interactive map inside a List traps VoiceOver focus.
                    Map(initialPosition:.region(CYMapRegion.region(center:coordinate,span:0.01)),interactionModes:[]) {
                        Marker(detail.summary.name,coordinate:coordinate)
                    }.frame(height:220)
                        .mapStyle(.standard(elevation:.flat,emphasis:.muted))
                        .environment(\.colorScheme,.light)
                        .background { CYMapPlaceholder(fog:false) }
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .accessibilityElement(children:.ignore)
                        .accessibilityLabel(Text("activity.location"))
                        .accessibilityValue(Text(verbatim:ActivityLocationAccessibility.value(name:detail.summary.name,addressName:detail.summary.addressName,address:detail.summary.address)))
                        .accessibilityAddTraits(.isImage)
                        .questifyCardSurface()
                        .questifyCardListRow()
                }
            }
            if let topicID = detail.summary.linkedTopicID, let topicDestination {
                Section {
                    NavigationLink { topicDestination(topicID) } label: {
                        CYListRow("activity.viewTopic", trailing: .none) { CYRowIcon(systemImage: "map") }
                    }.accessibilityIdentifier("activity.openTopic")
                }
            }
            // R7-PC-C1-7, MP scene-play-activity-detail index.wxml:41-44: 关于这场活动 sits in the first fold, above the people.
            if let text=ActivityPresentation.nonempty(detail.summary.description) {
                Section("activity.about") {
                    Text(verbatim:text)
                        .cyText(.body)
                        .fixedSize(horizontal:false,vertical:true)
                        .textSelection(.enabled)
                        .questifyCardSurface()
                        .questifyCardListRow()
                }
            }
            ActivityPeopleSection(people: detail.people, onOpenProfile: profileAction(detail), organizerShopName: detail.organizerShopName)
            Section {
                if detail.tickets.isEmpty {
                    // Source empty ticket copy: title plus host explanation.
                    Text("activity.source.noTickets")
                        .foregroundStyle(CYColor.textSecondary)
                }
                ForEach(detail.tickets) { ticket in
                    ActivityTicketCard(ticket:ticket)
                        .questifyCardListRow()
                }
            } header: { E1IconHeader(systemImage: "ticket", title: CoreLoopCopy(locale: locale).t("票种", "Tickets")) }
            .id(E1ActivityAnchor.tickets.rawValue)
            // Mini-program order: reviews (count, 写评价, 还没有评价) follow the tickets on the first fold.
            ActivityReviewsSection(reviews: detail.reviews)
                .id(E1ActivityAnchor.details.rawValue)
            Section {
                if canReview(detail) {
                    Button { showsReview = true } label: {
                        CYListRow("context.review.title", trailing: .none) { CYRowIcon(systemImage: "square.and.pencil") }
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("activity.openReview")
                }
                // Mini-program `activity-points`, directly under the reviews.
                Label {
                    Text("activity.reviewPointsNote")
                        .accessibilityIdentifier("activity.detail.readOnly")
                } icon: { Image(systemName:"star").accessibilityHidden(true) }
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal:false,vertical:true)
            }
            Section {
                Button {
                    withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { showsMoreInfo.toggle() }
                } label: {
                    HStack(spacing: CYSpacing.md) {
                        Text(showsMoreInfo ? "activity.more.hide" : "activity.more.show")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(CYColor.textSecondary)
                            .rotationEffect(.degrees(showsMoreInfo ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.cyPressable)
                .accessibilityIdentifier("activity.more.toggle")
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(Text(showsMoreInfo ? "activity.more.expanded" : "activity.more.collapsed"))
            }
            if showsMoreInfo { moreInfoSections(detail) }
            if let hostCancelAccess {
                ActivityHostCancelSection(detail: detail, access: hostCancelAccess) {
                    await load()
                }
            }
        }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(CYSpacing.xl)
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .accessibilityIdentifier("activity.detail.content")
        .cyTracksHeroScroll($heroScrolledAway)
        // PC-B-1-8 / PC-C-1-9 (type-and-chrome §3): the hero is an inset list row, not a full-bleed image, so the page keeps
        // the system back and its edge swipe; share / 举报 stay in the bar beside it.
        .cyPushedChrome(domain: .player)
        // E2E-20261113b N3: the List did not inset for the pinned action, so the last section ("More info", which holds
        // the play row) ended under it. Reserve the pinned action's height below the content.
        .contentMargins(.bottom, registrationEnabled ? 112 : 0, for: .scrollContent)
        .safeAreaInset(edge:.bottom,spacing:0) {
            // This view exists only for .allowed details. Preserve the caller's
            // existing gate; the unchanged registration sheet owns further checks.
            if registrationEnabled { registrationAction(detail) }
        }
    }
    /// Secondary sections behind the "More info" disclosure.
    @ViewBuilder private func moreInfoSections(_ detail: ActivityDetail) -> some View {
        // Source meta block (分类 / 集合点 / 已报名) sits after the cancellation notice.
        // Only this successful, current allowed response supplies these rows.
        // A scope/reader/activity/reread invalidation immediately removes them.
        if gateScope != nil, detail.summary.id == id {
            ActivityAssociatedPlaysSection(plays: detail.associatedPlays)
        }
        if let playReaderForActivity {
            Section {
                NavigationLink { PlaySessionView(reader:playReaderForActivity(id)) } label: {
                    CYListRow("play.openSession", trailing: .none) { CYRowIcon(systemImage: "figure.walk") }
                }.accessibilityIdentifier("activity.openPlay")
            }
        }
        if let topicID = detail.summary.linkedTopicID, topicID > 0,
           let session = reader as? AppSession,
           let card = session.characterCardReadback(topicID: topicID, activityID: id, scope: .activity(id)) {
            Section {
                NavigationLink { CharacterCardReadbackView(session: session, model: card) } label: {
                    CYListRow("play.character.card", trailing: .none) { CYRowIcon(systemImage: "person.text.rectangle") }
                }.accessibilityIdentifier("activity.openCharacterCard")
            }
        }
        if let topicID = detail.summary.linkedTopicID, topicID > 0,
           let provider = reader as? OrientScoreEntryProviding,
           let rounds = provider.orientScoreRoundsLoader(topicID: topicID, activityID: id) {
            OrientScoreEntryLink(rounds: rounds, session: reader as? AppSession)
        }
        if let session = reader as? AppSession, session.playExperience(for: .activity(id)) != nil {
            Section {
                NavigationLink { SessionPlayRuntimeView(session: session, destination: .journey(.activity(id))) } label: {
                    CYListRow("playx.title", trailing: .none) { CYRowIcon(systemImage: "figure.walk.circle") }
                }.accessibilityIdentifier("activity.openPlayExperience")
                NavigationLink { SessionPlayRuntimeView(session: session, destination: .director(id)) } label: {
                    CYListRow("playx.director.title", trailing: .none) { CYRowIcon(systemImage: "person.3.sequence") }
                }.accessibilityIdentifier("activity.openPlayDirector")
            }
        }
    }
    private func profileAction(_ detail: ActivityDetail) -> ((Int) -> Void)? {
        guard detail.summary.id == id, let peopleProfile, let snapshotID = loadedPeopleSnapshotID,
              loadedProfileIdentity == peopleProfile.reader.identity,
              peopleProfile.reader.identity.accountID != nil else { return nil }
        let identity = peopleProfile.reader.identity
        return { memberID in
            guard identity == peopleProfile.reader.identity,
                  loadedProfileIdentity == identity, loadedPeopleSnapshotID == snapshotID else { return }
            profileSelection = ActivityPersonProfileSelection(activityID: id, memberID: memberID,
                                                              people: detail.people, identity: identity, snapshotID: snapshotID)
        }
    }
    /// A review is offered only once the activity has started; an upcoming or undated activity has nothing to review yet.
    private func canReview(_ detail: ActivityDetail) -> Bool {
        guard let start = HomeFeedDate.parse(detail.summary.startDate, sourceTimeZone: nil)
                ?? HomeFeedDate.parse(detail.summary.startDate, sourceTimeZone: TimeZone(secondsFromGMT: 0)) else { return false }
        return start <= Date()
    }
    /// Directions only when the activity has a valid coordinate; otherwise the tile is hidden.
    private func directionsAction(_ detail: ActivityDetail) -> (() -> Void)? {
        guard detail.summary.hasValidCoordinates, let latitude = detail.summary.latitude, let longitude = detail.summary.longitude else { return nil }
        let name = detail.summary.name
        return {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
            item.name = name
            item.openInMaps()
        }
    }
    private var primaryAction: ActivityPrimaryAction {
        if let access, case .allowed(let detail) = access { return detail.primaryAction(now: Date()) }
        return .signUp
    }
    /// The pill and the first tile share one action: sign up opens the registration sheet, a registered viewer opens the wallet, cancelled does nothing.
    private var signUpBlocked: Bool {
        if let access, case .allowed(let detail) = access { return detail.signUpBlock(now: Date()) != nil }
        return false
    }
    private var primaryActionEnabled: Bool {
        if primaryAction == .unavailable || primaryAction == .cancelled { return false }
        return (primaryAction == .signUp && !signUpBlocked) || (primaryAction != .signUp && reader is AppSession)
    }
    private func performPrimaryAction() {
        if primaryAction == .unavailable || primaryAction == .cancelled { return }
        if primaryAction == .signUp {
            guard !signUpBlocked else { return }
            if let guestSignIn { guestSignIn(); return }
            tileOpenedSheet = true; showsRegistration = true
        } else if primaryAction == .continueExploring, playReaderForActivity != nil { showsPlay = true }
        else if reader is AppSession { tileOpenedSheet = true; showsTicketWallet = true }
    }
    /// "From ¥58 · 24 going"; an unknown price or count is an em dash, never 0.
    /// Known parts only: price and attendee count joined by a dot. Nil (line hidden) when neither is known.
    private func pinnedSummary(_ detail: ActivityDetail) -> Text? {
        let amount = detail.summary.minimumAmount
        var parts: [Text] = []
        if let amount, amount == 0 { parts.append(Text(verbatim: CoreLoopCopy(locale: locale).t("免费", "Free"))) }
        else if let amount, amount > 0 { let yuan = MoneyDisplay.yuan(amount)  // owner decision 9: ¥12.50
            parts.append(Text("activity.pinned.price \(yuan)")) }
        if let count = ActivityDetailHeaderFacts(detail: detail).registrationCount { parts.append(Text("activity.pinned.going \(count)")) }
        guard var line = parts.first else { return nil }
        for part in parts.dropFirst() { line = line + Text(verbatim: " · ") + part }
        return line
    }
    private func registrationAction(_ detail: ActivityDetail) -> some View { CYFooterBar {
        VStack(spacing: CYSpacing.xs) {
            if let summary = pinnedSummary(detail) {
                summary
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("activity.pinned.summary")
            }
            if let access = hostCancelAccess, !detail.isCancelled,
               ActivityHostCancelRules.isHost(hostMemberID: detail.hostMemberID, accountID: access.accountID) {
                // R7-PC-C1-4 (r1 PC-C-1-5): MP host footer is 取消活动并退款, not 立即报名.
                Button(role: .destructive) { showsHostCancelFromFooter = true } label: {
                    Text(verbatim: CoreLoopCopy(locale: locale).t("取消活动并退款", "Cancel event & refund"))
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .disabled(!access.enabled)
                .accessibilityIdentifier("activity.hostCancel.footer")
                .sheet(isPresented: $showsHostCancelFromFooter) {
                    ActivityHostCancelSheet(detail: detail, access: access) {
                        showsHostCancelFromFooter = false
                        await load()
                    }
                    .cyDomainSheet(detents: [.half, .full])
                }
            } else if primaryAction == .signUp, let block = detail.signUpBlock(now: Date()) {
                // PC-C-1-3: nothing can be bought; the pill is disabled and names the reason (MP noTicketText).
                CYPillButton(LocalizedStringKey(block.titleKey)) {}
                    .disabled(true)
                    .accessibilityIdentifier("activity.openRegistration.blocked")
            } else if primaryAction == .signUp {
                CYPillButton(LocalizedStringKey(primaryAction.titleKey)) {
                    if let guestSignIn { guestSignIn() } else { showsRegistration = true }
                }
                    .cyHeroSource(ActivityFooterHeroDestination.id, in: footerHero, cornerRadius: CYRadius.pill)
                    .accessibilityIdentifier("activity.openRegistration")
                    .accessibilityLabel(Text(LocalizedStringKey(primaryAction.titleKey)))
            } else if primaryAction == .unavailable {
                CYPillButton(LocalizedStringKey(primaryAction.titleKey)) {}
                    .disabled(true)
                    .accessibilityIdentifier("activity.primaryAction")
                    .accessibilityLabel(Text(LocalizedStringKey(primaryAction.titleKey)))
            } else {
                // A registered or cancelled activity never reopens the registration sheet.
                let action = primaryAction
                let walletAvailable = reader is AppSession
                CYPillButton(LocalizedStringKey(action.titleKey)) {
                    if action == .continueExploring, playReaderForActivity != nil { showsPlay = true }
                    else if action != .cancelled, walletAvailable { showsTicketWallet = true }
                }
                .cyHeroSource(ActivityFooterHeroDestination.id, in: footerHero, cornerRadius: CYRadius.pill)
                .disabled(action == .cancelled || (!walletAvailable && !(action == .continueExploring && playReaderForActivity != nil)))
                .accessibilityIdentifier("activity.primaryAction")
                .accessibilityLabel(Text(LocalizedStringKey(action.titleKey)))
            }
        }
    } }
    @MainActor private func load() async {
        generation += 1
        let operation=generation
        let capturedActivityID = id
        let capturedReaderID = ObjectIdentifier(reader), capturedReaderIdentity = reader.activityPresentationIdentity
        latestGateReaderID = capturedReaderID; latestGateActivityID = capturedActivityID
        gateReadID = nil; gateActivityID = nil; gateReaderID = nil; gateReaderIdentity = nil; requiredClubSelection = nil
        let profileIdentity = peopleProfile?.reader.identity
        phase = .loading;loadedProfileIdentity=nil
        profileSelection=nil;loadedPeopleSnapshotID=nil
        defer { if generation == operation, phase.isLoading { phase = .idle } }
        do {
            let result=try await reader.activityDetail(id:id)
            try Task.checkCancellation()
            if generation == operation, profileIdentity == peopleProfile?.reader.identity,
               latestGateReaderID == capturedReaderID, latestGateActivityID == capturedActivityID,
               capturedReaderIdentity == reader.activityPresentationIdentity {
                phase = .loaded(result); loadedProfileIdentity=profileIdentity; loadedPeopleSnapshotID=UUID()
                gateActivityID = capturedActivityID; gateReaderID = capturedReaderID
                gateReaderIdentity = capturedReaderIdentity; gateReadID = UUID()
                if guestSignIn == nil, opensRegistrationOnLoad, !openedRegistrationOnLoad, registrationEnabled, primaryAction == .signUp, !signUpBlocked {
                    openedRegistrationOnLoad = true; showsRegistration = true
                }
            }
        }
        catch is CancellationError { }
        catch { if generation == operation, !Task.isCancelled { phase = .failed((), retry: nil) } }
    }
}

/// Source detail meta rows. Unknown values use explicit unconfirmed copy, never zero.
@MainActor private struct ActivityDetailMetaSection: View {
    let facts: ActivityDetailHeaderFacts
    var body: some View {
        Section {
            LabeledContent("activityParity.header.category") {
                Text(verbatim: facts.categoryText ?? "—")
            }
            .accessibilityIdentifier("activity.detail.category")
            LabeledContent("activityParity.header.meetingPoint") {
                switch facts.meetingPoint {
                case .named(let place): Text(verbatim: place)
                case .mapOnly: Text("activityParity.header.meetingPointOnMap")
                case .unconfirmed: Text(verbatim: "—")
                }
            }
            .accessibilityIdentifier("activity.detail.meetingPoint")
            LabeledContent("activityParity.header.registered") {
                if let count = facts.registrationCount { Text("activityParity.header.registeredCount \(count)") }
                else { Text(verbatim: "—") }
            }
            .accessibilityIdentifier("activity.detail.registeredCount")
        }
    }
}

/// VoiceOver value for the embedded location map: venue name plus the address lines that add information.
enum ActivityLocationAccessibility {
    static func value(name: String, addressName: String?, address: String?) -> String {
        var parts: [String] = []
        for raw in [name, addressName, address] {
            let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, !parts.contains(text) { parts.append(text) }
        }
        return parts.joined(separator: ", ")
    }
}

/// Secondary action tiles under the poster: directions and review, each only when available. Sign up lives in the pinned pill
/// and Share in the top bar, so neither repeats here. Every tile is at least 44 pt tall.
private struct ActivityActionTiles: View {
    let onDirections: (() -> Void)?
    let onReview: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
        if onDirections != nil || onReview != nil {
            layout {
                if let onDirections {
                    tile(Text(verbatim: CYKitCopy(locale: locale)("Directions", "路线")), systemImage: "arrow.triangle.turn.up.right.circle", enabled: true, id: "activity.tile.directions", action: onDirections)
                }
                if let onReview {
                    tile(Text("context.review.title"), systemImage: "square.and.pencil", enabled: true, id: "activity.tile.review", action: onReview)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.sm)
        }
    }

    private func tile(_ title: Text, systemImage symbol: String, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CYSpacing.xs) {
                Image(systemName: symbol).font(.title3).accessibilityHidden(true)
                title.cyText(.meta).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(enabled ? CYColor.textPrimary : CYColor.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, CYSpacing.sm)
            .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.cyPressable)
        .disabled(!enabled)
        .accessibilityIdentifier(id)
    }
}

/// Continuity r1 (+): the registration / ticket-wallet sheet zooms out of the footer pill that opened it. Only one pill is
/// on screen at a time, so one id pairs it with whichever sheet it opened. Inactive (tile opener): the plain slide-up.
private struct ActivityFooterHeroDestination: ViewModifier {
    static let id = "footer.primary"
    let active: Bool
    let namespace: Namespace.ID
    @ViewBuilder func body(content: Content) -> some View {
        if active { content.cyHeroDestination(Self.id, in: namespace) } else { content }
    }
}
