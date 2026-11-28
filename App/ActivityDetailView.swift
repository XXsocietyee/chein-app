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
    /// R7-PC-B1-13: a topic session pick names the ticket (MP pages/topic/index/index.js:1312-1351 `preferredTicketName`);
    /// it is resolved inside the loaded activity by name when no id is given.
    var registrationTicketName: String? = nil
    var body: some View {
        if let session = reader as? AppSession {
            SessionActivityDetailView(id: id, session: session,
                playReaderForActivity: playReaderForActivity, registrationEnabled: registrationEnabled,
                hostCancelAccess: hostCancelAccess, opensRegistrationOnLoad: opensRegistrationOnLoad,
                registrationTicketID: registrationTicketID, registrationTicketName: registrationTicketName)
        } else {
            ActivityDetailContentView(id: id, reader: reader,
                playReaderForActivity: playReaderForActivity, registrationEnabled: registrationEnabled,
                peopleProfile: peopleProfile, requiredClubDestination: requiredClubDestination,
                hostCancelAccess: hostCancelAccess, startsWithMoreInfoOpen: startsWithMoreInfoOpen,
                opensRegistrationOnLoad: opensRegistrationOnLoad, registrationTicketID: registrationTicketID,
                registrationTicketName: registrationTicketName)
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
    var registrationTicketName: String? = nil
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
        .cySheet(isPresented: $showsGuestLogin) {
            Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .onChange(of: session.account == nil) { _, signedOut in if !signedOut { showsGuestLogin = false } }
        .appNavigationTitle("activity.details")
        .navigationBarTitleDisplayMode(.inline)
        .cyPushedChrome(domain: .player)
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
            registrationTicketName: registrationTicketName,
            guestSignIn: guestSignIn,
            viewerAccountID: session.account?.id)
            .environment(\.inGameChannelHost, session.inGameChannelHost)
            .id(session.contentDetailRevision)
    }
}

/// `ActivityDetailFailure.notFound` is 活动不存在 (`activity.detail.missing`). Other failures keep retry.
private enum ActivityDetailLoadIssue: Equatable { case missing, other }

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
    var registrationTicketName: String? = nil
    /// Guest 立即报名. Nil for a signed-in reader, which opens the registration sheet instead.
    var guestSignIn: (() -> Void)? = nil
    /// R9-PC-C1-2: signed-in viewer, so the host still sees 取消活动并退款 (disabled) while refunds are money-off.
    var viewerAccountID: Int? = nil
    @State private var openedRegistrationOnLoad = false
    @Environment(\.locale) private var locale
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
    @State private var showsPlay = false
    @State private var showsOwnOrders = false
    /// One load lifecycle instead of `access` / `loading` / `failed` (docs/release/state-machines/views.md).
    @State private var phase: CYPhase<ActivityDetailAccess, ActivityDetailLoadIssue> = .idle
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
            case .failed(let issue, _):
                // R9-PC-CN-1: system ContentUnavailableView for the missing and failed reads.
                if issue == .missing {
                    ContentUnavailableView {
                        Label { Text("activity.detail.missing") } icon: { Image(systemName: "calendar.badge.exclamationmark") }
                    } actions: {
                        Button { dismiss() } label: { Text("activity.cancelled.backToList") }
                            .buttonStyle(.bordered)
                    }
                    .accessibilityIdentifier("activity.detail.missing")
                } else {
                    ContentUnavailableView {
                        Label {
                            Text("activity.detail.openFailed")
                                .accessibilityIdentifier("activity.detail.error")
                        } icon: { Image(systemName: "exclamationmark.triangle") }
                    } actions: {
                        // mp-states r3: scene-play-activity-detail cy-error 活动详情无法打开 · 重新读取.
                        Button { loads.start { await load() } } label: { Text("parityB.alt.reload") }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("activity.detail.retry")
                    }
                }
            case .loaded(let access):
                switch access {
                case .clubRequired(_, let message):
                    clubGate(message)
                case .allowed(let detail):
                    if NativeR2Flags.cityOrientation, detail.summary.linkedTopicID != nil {
                        cityEventDetail(detail)
                    } else {
                        detailContent(detail)
                    }
                case .cancelled(let canViewOwnOrders):
                    // MP activity detail: a cancelled activity shows the cancelled state; 查看订单 only for the player's own orders.
                    // R9-PC-C1-1: MP onCancelledAction pushes /subpackageMember/order/order (index.js:436-441).
                    ActivityCancelledStateView(canViewOwnOrders: canViewOwnOrders,
                                               onViewOrders: { showsOwnOrders = true }, onBack: { dismiss() })
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
        .cySheet(isPresented: $showsShare) {
            if let access, case .allowed(let detail) = access {
                CatalogShareCardView(content: shareContent(detail), tint: .sunset)
                    .themeDomain(.player)
                    .cySheet()
            }
        }
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
                    .cyPushedChrome(domain: .player)
            } else {
                ContentUnavailableView("social.changed", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .cySheet(isPresented: $showsReview) {
            NavigationStack { ContextualReviewComposer(target: .activity(id), owner: (reader as? AppSession)?.contextualReviews?.coordinator(.activity(id))) { loads.start { await load() } } }
                .themeDomain(.player)
                .cySheet()
        }
        .cySheet(isPresented:$showsRegistration, onDismiss: { tileOpenedSheet = false }) {
            Group {
            if let access,case .allowed(let detail)=access {
                SessionRegistrationSheet(activity:detail)
                    .environment(\.registrationPreselectedTicketID, registrationTicketID ?? Self.ticketID(named: registrationTicketName, in: detail))
            }
            }
            .environment(\.registrationPreselectedTicketID, registrationTicketID)
            .themeDomain(.player)
            .cySheet(detents: [.large])
        }
        .navigationDestination(isPresented: $showsOwnOrders) {
            SubscribeMessageTapEntry(route: .playerOrderList)
                .cyPushedChrome(domain: .player)
        }
        .navigationDestination(isPresented: $showsPlay) {
            // E2E-20261113b N3: a registered player's "Continue exploring" opens the play session for this activity.
            // N5: the full runtime (advanced prerequisites, hint ladder, TEAM backpack) when this session can build it;
            // the basic reader otherwise.
            if let session = reader as? AppSession, session.playExperience(for: .activity(id)) != nil {
                SessionPlayRuntimeView(session: session, destination: .journey(.activity(id)))
            } else if let playReaderForActivity { PlaySessionView(reader: playReaderForActivity(id)) }
        }
        .cySheet(isPresented:$showsTicketWallet, onDismiss: { tileOpenedSheet = false }) {
            // Source: a registered viewer's CTA opens the ticket wallet (subpackageMember/signup).
            if let session = reader as? AppSession {
                SessionTicketWalletHost(onClose:{ showsTicketWallet=false })
                    .environmentObject(session)
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
            : summary.minimumAmount.flatMap { $0 >= 0 ? LocaleDisplay.money($0, locale: locale) : nil }  // owner decision 9: ¥12.50
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
        ProgressView { Text("activity.loading") }
    }

    private func clubGate(_ message: String?) -> some View {
        ContentUnavailableView {
            Label {
                Text("activity.clubRequired")
                    .accessibilityIdentifier("activity.detail.clubGate")
            } icon: { Image(systemName: "lock") }
        } description: {
            if let message, !message.isEmpty {
                Text(verbatim: message)
            } else {
                Text("activity.clubRequiredHint")
            }
        } actions: {
            if let access { requiredClubAction(access) }
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
                .buttonStyle(.borderedProminent)
                .disabled(requiredClubDestination == nil || renderedScope == nil || !gateIsVisible || requiredClubSelection != nil)
                .accessibilityIdentifier("activity.requiredClub.open")
                .accessibilityLabel(Text("activity.requiredClub.open"))
        }
        if requiredClubDestination == nil || renderedScope == nil || (clubID ?? 0) <= 0 {
            Text("activity.requiredClub.unavailable").font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("activity.requiredClub.unavailable")
        }
    }
    /// First fold in MP order: hero, cancellation, meta (分类 / 集合点 / 已报名 / 主题路线), about, people, plays, tickets,
    /// reviews; then the native channel row and one "More info" row.
    /// Everything else (plays, journeys) sits behind the disclosure; host cancel stays its own section.
    private func detailContent(_ detail:ActivityDetail) -> some View {
        List {
            Section {
                // E1ActivityHero draws its own surface (E1ActivityDetailParts.swift); no cell behind them.
                E1ActivityHero(summary:detail.summary)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            // mp-home r3 (MP scene-play-activity-detail index.wxml:23-27): the cancelled notice sits right under the hero.
            if detail.isCancelled {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label { Text("activity.cancelled.title") } icon: { Image(systemName: "xmark.octagon").foregroundStyle(.red) }
                            .font(.headline)
                        if let reason = detail.cancelReason { Text("activity.cancelled.reason \(reason)").fixedSize(horizontal: false, vertical: true) }
                        Text("activity.cancelled.hint").font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("activity.detail.cancelled")
                }
            }
            // mp-home r3 continue (OWNER RULE: MP order wins): MP scene-play-activity-detail index.wxml:29-38 —
            // activity-meta (分类 / 集合点 / 已报名 / 主题路线) comes right after the hero and the cancelled notice. The
            // native info card, the directions / review rows and the static map were extras the MP page lacks: 集合点
            // opens Maps (MP `openLocation`), 写评价 lives with the reviews.
            ActivityDetailMetaSection(facts: ActivityDetailHeaderFacts(detail: detail), onOpenLocation: directionsAction(detail))
                .id(E1ActivityAnchor.overview.rawValue)
            // MP 主题路线 is the last fact row (index.wxml:37), so it follows the facts directly.
            if let topicID = detail.summary.linkedTopicID, let topicDestination {
                Section {
                    NavigationLink { topicDestination(topicID) } label: {
                        Label("activity.viewTopic", systemImage: "map")
                    }.accessibilityIdentifier("activity.openTopic")
                }
            }
            // R7-PC-C1-7, MP scene-play-activity-detail index.wxml:41-44: 关于这场活动 sits in the first fold, above the people.
            if let text=ActivityPresentation.nonempty(detail.summary.description) {
                Section("activity.about") {
                    Text(verbatim:text)
                        .fixedSize(horizontal:false,vertical:true)
                        .textSelection(.enabled)
                }
            }
            ActivityPeopleSection(people: detail.people, onOpenProfile: profileAction(detail),
                                  organizerShopName: detail.organizerShopName, organizerShopLogo: detail.organizerShopLogo)
            // mp-home r3 (MP index.wxml:61-78): 关联玩法模板 is on the page between the people and 票种, not behind More info.
            // Only this successful, current allowed response supplies these rows.
            if gateScope != nil, detail.summary.id == id {
                ActivityAssociatedPlaysSection(plays: detail.associatedPlays)
            }
            Section {
                if detail.tickets.isEmpty {
                    // Source empty ticket copy: title plus host explanation.
                    Text("activity.source.noTickets")
                        .foregroundStyle(.secondary)
                }
                ForEach(detail.tickets) { ticket in
                    ActivityTicketCard(ticket:ticket)
                }
            } header: { E1IconHeader(systemImage: "ticket", title: CoreLoopCopy(locale: locale).t("票种", "Tickets")) }
            .id(E1ActivityAnchor.tickets.rawValue)
            // Mini-program order: reviews (count, 写评价, 还没有评价) follow the tickets on the first fold.
            ActivityReviewsSection(reviews: detail.reviews)
                .id(E1ActivityAnchor.details.rawValue)
            Section {
                if canReview(detail) {
                    Button { showsReview = true } label: {
                        // R10-PC-C-N4: a system Label row, not CYListRow + CYRowIcon.
                        Label("context.review.title", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("activity.openReview")
                }
            } footer: {
                // Mini-program `activity-points`, directly under the reviews.
                Label {
                    Text("activity.reviewPointsNote")
                        .accessibilityIdentifier("activity.detail.readOnly")
                } icon: { Image(systemName:"star").accessibilityHidden(true) }
                .fixedSize(horizontal:false,vertical:true)
            }
            // Native extra (no MP section): the in-game channel for joined players, after the MP sections.
            if primaryAction != .signUp, !detail.isCancelled {
                Section {
                    InGameChannelRowButton(
                        scope: .activity(id: id),
                        titleKey: "ingame.channel.activity",
                        subtitleKey: "ingame.channel.activitySubtitle",
                        accessibilityID: "ingame.channel.activity.entry",
                        reloadTrigger: primaryAction
                    )
                }
            }
            Section {
                Button {
                    withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { showsMoreInfo.toggle() }
                } label: {
                    HStack {
                        Text(showsMoreInfo ? "activity.more.hide" : "activity.more.show")
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Image(systemName: showsMoreInfo ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
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
        .listStyle(.insetGrouped)
        .refreshable { await loads.run { await load() } }
        .accessibilityIdentifier("activity.detail.content")
        .cyTracksHeroScroll($heroScrolledAway)
        // PC-B-1-8 / PC-C-1-9 (type-and-chrome §3): the hero is an inset list row, not a full-bleed image, so the page keeps
        // the system back and its edge swipe; share / 举报 stay in the bar beside it.
        .cyPushedChrome(domain: .player)
        // E2E-20261113b N3: the List did not inset for the pinned action, so the last section ("More info", which holds
        // the play row) ended under it. Reserve the pinned action's height below the content.
        // +36 for the going stack (design pass explore P6) above the pill.
        .contentMargins(.bottom, showsFooter(detail) ? 148 : 0, for: .scrollContent)
        .safeAreaInset(edge:.bottom,spacing:0) {
            // This view exists only for .allowed details. Preserve the caller's
            // existing gate; the unchanged registration sheet owns further checks.
            if showsFooter(detail) { registrationAction(detail) }
        }
    }
    // MARK: native r2 city orientation (NativeR2Flags.cityOrientation)

    /// S2 event detail for a topic-linked (playable) activity. Same reads, sheets and gates as `detailContent`;
    /// the footer pill becomes one bottom-toolbar `.borderedProminent` button built from the same rules.
    private func cityEventDetail(_ detail: ActivityDetail) -> some View {
        CityOrientationEventDetailList(
            detail: detail,
            priceLine: pinnedSummary(detail),
            cta: registrationEnabled ? cityEventCTA(detail) : nil,
            onDirections: directionsAction(detail),
            onReview: canReview(detail) ? { showsReview = true } : nil,
            topicDestination: detail.summary.linkedTopicID.flatMap { topicID in topicDestination.map { AnyView($0(topicID)) } },
            people: AnyView(cityEventPeople(detail)),
            reviews: AnyView(ActivityReviewsSection(reviews: detail.reviews)),
            channel: (primaryAction != .signUp && !detail.isCancelled)
                ? AnyView(InGameChannelRowButton(scope: .activity(id: id), titleKey: "ingame.channel.activity",
                                                 subtitleKey: "ingame.channel.activitySubtitle",
                                                 accessibilityID: "ingame.channel.activity.entry", reloadTrigger: primaryAction))
                : nil
        ) {
            moreInfoSections(detail)
            if let hostCancelAccess {
                ActivityHostCancelSection(detail: detail, access: hostCancelAccess) {
                    await load()
                }
            }
        }
        .cySheet(isPresented: $showsHostCancelFromFooter) {
            if let access = hostCancelAccess {
                ActivityHostCancelSheet(detail: detail, access: access) {
                    showsHostCancelFromFooter = false
                    await load()
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
    /// mp-home r3 continue: MP 主理人 / N 人已报名 / 关联玩法模板, mounted by the city list between 关于 and 票种.
    @ViewBuilder private func cityEventPeople(_ detail: ActivityDetail) -> some View {
        ActivityPeopleSection(people: detail.people, onOpenProfile: profileAction(detail),
                              organizerShopName: detail.organizerShopName, organizerShopLogo: detail.organizerShopLogo)
        if gateScope != nil, detail.summary.id == id {
            ActivityAssociatedPlaysSection(plays: detail.associatedPlays)
        }
    }
    /// `registrationAction` rules, in the same order: host cancel, blocked sign-up, sign-up (guest sign-in first),
    /// unavailable, then wallet / continue. The registration sheet keeps the paid gate it already has.
    private func cityEventCTA(_ detail: ActivityDetail) -> CityOrientationEventCTA {
        if let access = hostCancelAccess, !detail.isCancelled,
           ActivityHostCancelRules.isHost(hostMemberID: detail.hostMemberID, accountID: access.accountID) {
            return CityOrientationEventCTA(titleKey: "nativeR2.city.event.hostCancel", identifier: "activity.hostCancel.footer",
                                           enabled: access.enabled, destructive: true) { showsHostCancelFromFooter = true }
        }
        if primaryAction == .signUp, let block = detail.signUpBlock(now: Date()) {
            return CityOrientationEventCTA(titleKey: block.titleKey, identifier: "activity.openRegistration.blocked", enabled: false) {}
        }
        if primaryAction == .signUp {
            return CityOrientationEventCTA(titleKey: primaryAction.titleKey, identifier: "activity.openRegistration", enabled: true) {
                if let guestSignIn { guestSignIn() } else { tileOpenedSheet = true; showsRegistration = true }
            }
        }
        if primaryAction == .unavailable {
            return CityOrientationEventCTA(titleKey: primaryAction.titleKey, identifier: "activity.primaryAction", enabled: false) {}
        }
        let action = primaryAction
        let walletAvailable = reader is AppSession
        let canPlay = action == .continueExploring && playReaderForActivity != nil
        return CityOrientationEventCTA(titleKey: action.titleKey, identifier: "activity.primaryAction",
                                       enabled: !(action == .cancelled || (!walletAvailable && !canPlay))) {
            if canPlay { showsPlay = true }
            else if action != .cancelled, walletAvailable { tileOpenedSheet = true; showsTicketWallet = true }
        }
    }
    /// Secondary sections behind the "More info" disclosure.
    @ViewBuilder private func moreInfoSections(_ detail: ActivityDetail) -> some View {
        // Meta rows and 关联玩法模板 are in the first fold (mp-home r3).
        // Only this successful, current allowed response supplies these rows.
        // A scope/reader/activity/reread invalidation immediately removes them.
        if let playReaderForActivity {
            Section {
                NavigationLink { PlaySessionView(reader:playReaderForActivity(id)) } label: {
                    Label("play.openSession", systemImage: "figure.walk")
                }.accessibilityIdentifier("activity.openPlay")
            }
        }
        if let topicID = detail.summary.linkedTopicID, topicID > 0,
           let session = reader as? AppSession,
           let card = session.characterCardReadback(topicID: topicID, activityID: id, scope: .activity(id)) {
            Section {
                NavigationLink { CharacterCardReadbackView(session: session, model: card) } label: {
                    Label("play.character.card", systemImage: "person.text.rectangle")
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
                    Label("playx.title", systemImage: "figure.walk.circle")
                }.accessibilityIdentifier("activity.openPlayExperience")
                NavigationLink { SessionPlayRuntimeView(session: session, destination: .director(id)) } label: {
                    Label("playx.director.title", systemImage: "person.3.sequence")
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
    /// `includeGoing: false` when the going stack right under the line already shows the count (no duplicate "24 going").
    private func pinnedSummary(_ detail: ActivityDetail, includeGoing: Bool = true) -> Text? {
        let amount = detail.summary.minimumAmount
        var parts: [Text] = []
        if let amount, amount == 0 { parts.append(Text(verbatim: CoreLoopCopy(locale: locale).t("免费", "Free"))) }
        else if let amount, amount > 0 { let yuan = LocaleDisplay.money(amount, locale: locale)  // owner decision 9: ¥12.50
            parts.append(Text("activity.pinned.price \(yuan)")) }
        if includeGoing, let count = ActivityDetailHeaderFacts(detail: detail).registrationCount { parts.append(Text("activity.pinned.going \(count)")) }
        guard var line = parts.first else { return nil }
        for part in parts.dropFirst() { line = line + Text(verbatim: " · ") + part }
        return line
    }
    /// mp-home r3 (19:50 sweep, OWNER RULE 2 no dead controls): the MP `actionFor` 「—」 state is not a button, so with no
    /// host footer the bar is hidden instead of showing an empty disabled pill.
    private func showsFooter(_ detail: ActivityDetail) -> Bool {
        guard registrationEnabled else { return false }
        guard primaryAction == .unavailable else { return true }
        let hostID: Int? = hostCancelAccess?.accountID ?? viewerAccountID
        return !detail.isCancelled && ActivityHostCancelRules.isHost(hostMemberID: detail.hostMemberID, accountID: hostID)
    }
    private func registrationAction(_ detail: ActivityDetail) -> some View { CYFooterBar {
        // mp-home r3 (MP scene-play-activity-detail index.wxml:147-153): the footer is the one main button (share is in
        // the toolbar). Price lives on 票种 and the going count on 已报名 + the people section, so neither repeats here.
        VStack(spacing: 8) {
            if let access = hostCancelAccess, !detail.isCancelled,
               ActivityHostCancelRules.isHost(hostMemberID: detail.hostMemberID, accountID: access.accountID) {
                // R7-PC-C1-4 (r1 PC-C-1-5): MP host footer is 取消活动并退款, not 立即报名.
                Button(role: .destructive) { showsHostCancelFromFooter = true } label: {
                    Text(verbatim: CoreLoopCopy(locale: locale).t("取消活动并退款", "Cancel event & refund"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!access.enabled)
                .accessibilityIdentifier("activity.hostCancel.footer")
                .cySheet(isPresented: $showsHostCancelFromFooter) {
                    ActivityHostCancelSheet(detail: detail, access: access) {
                        showsHostCancelFromFooter = false
                        await load()
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            } else if hostCancelAccess == nil, !detail.isCancelled,
                      ActivityHostCancelRules.isHost(hostMemberID: detail.hostMemberID, accountID: viewerAccountID) {
                // R9-PC-C1-2: MP host footer (scene-play-activity-detail/index.wxml:149-151, `isOwner` index.js:338) is
                // 取消活动并退款, never 立即报名. The refund write is money (TEST-only), so in Release it is shown disabled.
                VStack(spacing: CYSpacing.xxs) {
                    Button(role: .destructive) {} label: {
                        Text(verbatim: CoreLoopCopy(locale: locale).t("取消活动并退款", "Cancel event & refund"))
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .accessibilityIdentifier("activity.hostCancel.footer.unavailable")
                    Text("activity.hostCancel.refundUnavailable")
                        .cyText(.meta)
                        .foregroundStyle(.secondary)
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
        catch let error as ActivityDetailFailure where error == .notFound {
            if generation == operation, !Task.isCancelled { phase = .failed(.missing, retry: nil) }
        }
        catch { if generation == operation, !Task.isCancelled { phase = .failed(.other, retry: nil) } }
    }
}

/// Source detail meta rows. Unknown values stay an em dash, never zero. System text styles only.
@MainActor private struct ActivityDetailMetaSection: View {
    let facts: ActivityDetailHeaderFacts
    /// MP `openLocation`: the 集合点 row opens Maps when the activity has coordinates.
    var onOpenLocation: (() -> Void)? = nil
    var body: some View {
        Section {
            LabeledContent {
                Text(verbatim: facts.categoryText ?? "—")
            } label: { factLabel("activityParity.header.category", systemImage: "tag") }
            .font(.body)
            .accessibilityIdentifier("activity.detail.category")
            if let onOpenLocation {
                Button(action: onOpenLocation) { meetingPointRow.foregroundStyle(.primary) }
                    .accessibilityHint(Text("activity.meetingPoint.openMaps"))
                    .accessibilityIdentifier("activity.detail.meetingPoint")
            } else {
                meetingPointRow
                    .accessibilityIdentifier("activity.detail.meetingPoint")
            }
            LabeledContent {
                if let count = facts.registrationCount { Text("activityParity.header.registeredCount \(count)") }
                else { Text(verbatim: "—") }
            } label: { factLabel("activityParity.header.registered", systemImage: "person.2") }
            .font(.body)
            .accessibilityIdentifier("activity.detail.registeredCount")
        }
    }

    private var meetingPointRow: some View {
        LabeledContent {
            switch facts.meetingPoint {
            case .named(let place): Text(verbatim: place)
            case .mapOnly: Text("activityParity.header.meetingPointOnMap")
            case .unconfirmed: Text(verbatim: "—")
            }
        } label: { factLabel("activityParity.header.meetingPoint", systemImage: "mappin.and.ellipse") }
        .font(.body)
    }

    /// P28: each MP fact reads as a leading SF Symbol + label, the system `Label` row style.
    private func factLabel(_ key: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(key)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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

extension ActivityDetailContentView {
    /// R7-PC-B1-13: the first ticket whose trimmed name equals the topic-page pick (MP index.js:629-639 matches by name).
    static func ticketID(named name: String?, in detail: ActivityDetail) -> Int? {
        let wanted = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !wanted.isEmpty else { return nil }
        return detail.tickets.first { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == wanted }?.id
    }
}
