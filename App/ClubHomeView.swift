import SwiftUI

/// Place inside the root's existing NavigationStack. This view never uses entry role as access.
@MainActor
struct ClubHomeView<Reader: ClubReading & ObservableObject>: View {
    /// The server said how many clubs this account owns and the limit, and there is no room left.
    static func atCreationLimit(_ page: ClubTabPageModel?) -> Bool {
        guard let page, page.leader != .hidden else { return false }
        switch page.leader.quota {
        case .full, .over: return true
        case .within, .unknown: return false
        }
    }
    @ObservedObject var reader: Reader
    var onSignIn: (() -> Void)? = nil
    var actionCoordinator: ClubActionCoordinator? = nil
    var management:ClubManagementContext? = nil
    var community: ClubCommunityContext? = nil
    var publicRoster: ClubPublicRosterReader? = nil
    /// Home events carry topic IDs. The session host supplies its existing gated destination.
    var topicDestination: ((Int) -> AnyView)? = nil
    /// Retained callback for hosts that own a value-based navigation path.
    var onTopicDestination: ((Int) -> Void)? = nil
    /// chein://club/<id>/join: open this club's detail once, then clear it. The detail keeps its own join confirmation.
    var requestedClubID: Binding<Int?>? = nil
    /// Kept for existing call sites; the 帖文 tab no longer mounts the author delete block (A8-05).
    var authorSquare: (any SquareReading)? = nil
    /// MP `talent/list?tab=feed` (A8-04): opens on 帖文 once; nil keeps 俱乐部.
    var initialTopTab: ClubTabPresentation.TopTab? = nil
    @State private var appliedInitialTopTab = false
    @State private var locality = MerchantClubDiscoveryState()
    /// Card or inline Join pill tapped; both open the gated detail, which still owns the membership action.
    @State private var openedClubID: Int? = nil
    /// Inline Join pill state per club id. `.join` runs the same coordinator path as `ClubActionPanel` (prepare, then
    /// confirm) without leaving the list; `.apply` needs a reviewed message and approval, so it still opens the detail.
    @State private var inlineJoin: [Int: InlineJoin] = [:]
    @State private var inlineOwnerID = UUID()
    private enum InlineJoin: Equatable { case working, joined, pending, notice(String) }
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    /// Club cards zoom into the detail they open; `cyHeroSource` ids are the club id.
    @Namespace private var hero
    private var discoveryScope: ClubDiscoveryScope { reader.clubDiscoveryScope }
    /// Source talent/list top tabs 帖文 / 俱乐部; it opens on 俱乐部 and loads the feed only when chosen.
    @State private var topTab = ClubTabPresentation.TopTab.club
    /// Design hand-off r1 PL-11: the title matches the tab (俱乐部), on both the 帖文 and 俱乐部 top tabs.
    private var screenTitle: LocalizedStringKey { "club.title" }
    var body: some View {
        VStack(spacing: 0) {
        if community != nil {
            // Mini-program talent/list: the title (system large title, `cyRootHeader(.club)`) stays for both tabs;
            // 帖文 / 俱乐部 is a native segmented picker (native-ios-r1 §4.4).
            Picker(selection: $topTab) {
                ForEach(ClubTabPresentation.TopTab.allCases, id: \.self) { tab in
                    Text(verbatim: appLocalized(String.LocalizationValue(tab.key), locale: locale)).tag(tab)
                }
            } label: {
                Text(screenTitle)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.sm)
            .zIndex(1)
            // One container: without it the label and id below landed on both tab buttons, so VoiceOver read
            // 帖文 as "俱乐部" too (combined-r4 verify).
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("clubTab.topTabs")
            .accessibilityLabel(Text("club.title"))
            .cyHaptic(.selection, trigger: topTab)
        }
        if topTab == .feed, let community {
            // 帖文: the existing community feed (like / comment / repost / share / follow). Not rebuilt.
            VStack(spacing: 0) {
                // A8-05: MP talent/list 帖文 has no author delete block and no placeholder dash above the feed; deleting
                // one's own posts lives on 我的帖文 / 帖文详情 (A4-02).
                MPPassExploreCard()
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.bottom, CYSpacing.sm)
                ClubCommunityFeedView(context: community, identity: reader.clubIdentity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
        ClubReadScreen(reader: reader, accessibilityPrefix: "club.home", onSignIn: onSignIn,
                       load: { try await loadTab() }) { loaded in
            let home = loaded.home
            let page = loaded.page
            List {
                // Mini-program club tab: 「创建你自己的俱乐部」 stays pinned above the list; merchants never see it.
                // verify-r1 2.3 / N-15: at or above the creation limit, do not offer what cannot be done. The quota line
                // below keeps the warning, and the owned clubs are the first rows of the list.
                if !discoveryScope.isMerchantViewer, let operations = management?.operations, !Self.atCreationLimit(page) {
                    Section {
                        let prompt = Text("club.tab.createPrompt")
                            .cyText(.bodyMedium)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        let create = ClubOperationsEntryButton(target: .create, identity: reader.clubIdentity, access: operations.access, coordinator: operations.coordinator, hostApplication: management?.governance)
                            .buttonStyle(.questifyPrimary)
                            .controlSize(.regular)
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: CYSpacing.sm) { prompt; create }
                        } else {
                            HStack(spacing: CYSpacing.md) { prompt; Spacer(minLength: CYSpacing.sm); create.fixedSize().layoutPriority(1) }
                        }
                    }
                }
                // Core page model facts: shown only when the server sent `leaderStatus`; counts it omitted stay an em dash.
                if let page, !discoveryScope.isMerchantViewer, page.leader != .hidden {
                    Section {
                        ClubLeaderQuotaLine(leader: page.leader)
                            .accessibilityIdentifier("clubTab.leaderQuota")
                    }
                }
                // Mini-program club tab is one list: created → joined → nearby (merchants: nearby only), no group headers.
                let nearby = locality.nearby(home.nearby, in: discoveryScope)
                if discoveryScope.isMerchantViewer {
                    localityStatus
                    merchantNearbySection(nearby, page: page)
                } else if ClubTabPresentation.isEmpty(home, nearby: nearby, merchant: false) {
                    Section { playerEmpty }
                } else {
                    // Source talent/list (2026-09-18): one list, created → joined → nearby, no group headers.
                    Section {
                        clubRows(home.owned, identifier: "club.home.owned", section: .owned, page: page)
                        clubRows(home.joined, identifier: "club.home.joined", section: .joined, page: page)
                        clubRows(nearby, identifier: "club.home.nearby", section: .nearby, page: page)
                    }
                }
                Section {
                    if let governance = management?.governance {
                        ClubGovernanceHomeEntries(feedContext: .init(viewerRevision: management?.viewerRevision ?? governance.viewerRevision,
                            readerIdentity: ObjectIdentifier(reader), destination: { id in
                                AnyView(ClubDetailView(id: id, reader: reader, onSignIn: onSignIn, publicRoster: publicRoster))
                            }), identity: reader.clubIdentity, access: governance.access, coordinator: governance.coordinator)
                    }
                    NavigationLink {
                        ClubDirectoryView(reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                            .cyPushedChrome()
                    } label: {
                        CYListRow("club.directory", trailing: .chevron) { CYRowIcon(systemImage: "magnifyingglass") }
                    }
                        .accessibilityIdentifier("club.openDirectory")
                    if !discoveryScope.isMerchantViewer {
                        NavigationLink {
                            ClubOwnedView(reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                                .cyPushedChrome()
                        } label: {
                            CYListRow("club.owned", trailing: .chevron) { CYRowIcon(systemImage: "person.crop.circle") }
                        }
                            .accessibilityIdentifier("club.openOwned")
                    }
                }
                Section {
                    CYSectionHeader("club.events")
                    if home.events.isEmpty {
                        CYEmptyState(systemImage: "flag.checkered", "club.emptyEvents", messageIdentifier: "club.home.events.empty")
                            .modifier(ClubNightGlass())
                    }
                    ForEach(Array(home.events.enumerated()), id: \.offset) { index, event in
                        Group {
                            if let topicDestination, event.id > 0 {
                                NavigationLink { topicDestination(event.id) } label: { eventRow(event, page: page) }
                                    .accessibilityIdentifier("club.event.\(event.id)")
                            } else if let onTopicDestination {
                                Button { onTopicDestination(event.id) } label: { eventRow(event, page: page) }
                                    .buttonStyle(.cyPressable)
                                    .accessibilityIdentifier("club.event.\(event.id)")
                            } else { eventRow(event, page: page) }
                        }
                        .modifier(ClubNightGlass())
                        .modifier(ClubRowReveal(index: index))
                    }
                }
            }
            .listStyle(.plain)
            // Ground and text must come from the same palette. `cyGroupedSurface` painted the scheme-adaptive page colour
            // while hero/row text read the domain palette, so a host whose system scheme differed from its domain
            // drew white titles on light grey.
            .scrollContentBackground(.hidden)
            .cyDomainPageBackground()
        }
        }
        }
        .navigationDestination(item: $openedClubID) { id in
            ClubDetailView(id: id, reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
                .cyHeroDestinationWithFallback(id, in: hero)
                .cyPushedChrome()
        }
        .onAppear {
            guard !appliedInitialTopTab else { return }
            appliedInitialTopTab = true
            if let initialTopTab, community != nil { topTab = initialTopTab }
        }
        .onChange(of: requestedClubID?.wrappedValue, initial: true) { _, id in
            guard let id else { return }
            openedClubID = id; requestedClubID?.wrappedValue = nil
        }
        .cyRootHeader(.club)
        .toolbar {
            // r9 A4-04b: MP talent/list/index.js:585-600 onShareAppMessage shares the hub page itself.
            ToolbarItem(placement: .topBarTrailing) {
                R9PublicShareButton(url: PublicContentShareLink.clubHub(tab: topTab.rawValue),
                                    copyText: PublicContentShareLink.clubHubCopyText(tab: topTab.rawValue),
                                    identifier: "clubTab.share")
            }
        }
        .environment(\.clubEnrollmentProfile, management?.governance?.enrollmentProfile)
        .environment(\.clubCustomerTopics, management?.governance?.customerTopics ?? .init())
        .environment(\.clubPostPlayHost, ClubPostPlayHost.session(reader as? AppSession))
        .environment(\.clubEditDetailBody, { id in try await reader.clubDetailBody(id: id) })
        .task(id: discoveryScope) {
            if locality.phase(in: discoveryScope) != .ready { await loadLocality() }
        }
        .onDisappear { locality.leaveScreen() }
        .onChange(of: discoveryScope) { _, _ in inlineJoin = [:] }
    }
    private var playerEmpty: some View {
        let keys = ClubTabPresentation.emptyKeys(merchant: false)
        return CYEmptyState(systemImage: "person.3", LocalizedStringKey(keys.title), messageIdentifier: "clubTab.empty")
            .modifier(ClubNightGlass())
    }
    /// Merchant-only status above the list. Ready state becomes the list's section header instead.
    @ViewBuilder private var localityStatus: some View {
        switch locality.phase(in: discoveryScope) {
        case .idle, .loading:
            Section {
                CYSkeleton()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("club.locality.loading"))
                    .accessibilityIdentifier("club.home.locality.loading")
            }
        case .unavailable:
            Section {
                CYEmptyState(
                    systemImage: "wifi.slash",
                    "club.locality.unavailable",
                    messageIdentifier: "club.home.locality.unavailable",
                    actionTitle: "action.retry",
                    actionIdentifier: "club.home.locality.retry",
                    kind: .offline
                ) { Task { await loadLocality() } }
                .modifier(ClubNightGlass())
            }
        case .ready:
            EmptyView()
        }
    }
    private func merchantNearbySection(_ rows: [ClubRecord], page: ClubTabPageModel?) -> some View {
        Section {
            if rows.isEmpty {
                CYEmptyState(
                    systemImage: "mappin.and.ellipse",
                    LocalizedStringKey(locality.phase(in: discoveryScope) == .ready ? "club.tab.empty.merchant" : "club.emptyNearby"),
                    messageIdentifier: "club.home.nearby.empty",
                    kind: locality.phase(in: discoveryScope) == .ready ? nil : .offline
                )
                .modifier(ClubNightGlass())
            }
            clubRows(rows, identifier: "club.home.nearby", section: .nearby, page: page)
        } header: {
            if locality.phase(in: discoveryScope) == .ready {
                Text("club.locality.ready")
                    .cyText(.sectionTitle)
                    .accessibilityIdentifier("club.home.locality.ready")
            }
        }
    }
    private func loadLocality() async {
        guard let request = locality.begin(in: discoveryScope) else { return }
        do {
            let result = try await reader.clubMerchantLocality()
            guard !Task.isCancelled else { return }
            locality.receive(result, for: request, current: discoveryScope)
        } catch {
            guard !Task.isCancelled else { return }
            locality.fail(request, current: discoveryScope)
        }
    }
    @ViewBuilder private func clubRows(_ rows: [ClubRecord], identifier: String,
                                       section: ClubTabPresentation.Section, page: ClubTabPageModel?) -> some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, club in
            let inline = inlineJoin[club.id]
            // Keep the Join / Apply pill mounted while the request is in flight. The card moves the avatar into its
            // own strip and then settles the pill; swapping in `.none` would drop the control and jump the footer.
            let membership = club.cardAction(viewerIsMerchant: discoveryScope.isMerchantViewer)
            let action: CYClubCardAction = {
                switch inline {
                case .joined: return .joined
                case .pending: return .pending
                default: return membership
                }
            }()
            let morph: CYMorphState = {
                switch inline {
                case .working: return .working
                case .joined, .pending: return .done
                default: return .idle
                }
            }()
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if section == .nearby {
                    CYClubPhotoCard(name: club.name, place: clubPlace(club), coverURL: QuestifyCardArtwork.safeURL(club.cover),
                                    memberCount: club.sourceMemberCount, seed: "\(club.id)", prominent: index == 0,
                                    action: action, morph: morph, onOpen: { openedClubID = club.id }, onJoin: { joinInline(club, action: action) },
                                    identifier: identifier + ".\(club.id)")
                        .cyHeroSource(club.id, in: hero)
                } else {
                    CYClubRowCard(name: club.name, logoURL: QuestifyCardArtwork.safeURL(club.logo), memberCount: club.sourceMemberCount,
                                  seed: "\(club.id)", action: action, morph: morph, onOpen: { openedClubID = club.id },
                                  identifier: identifier + ".\(club.id)",
                                  tags: AnyView(ClubTabTagLine(club: club, section: section,
                                                               topicCount: page?.rows.first { $0.id == club.id && $0.section == section }?.topicCount)))
                        .cyHeroSource(club.id, in: hero)
                }
                if inline == .working {
                    ProgressView("club.action.working").cyText(.meta).accessibilityIdentifier("club.home.join.working.\(club.id)")
                } else if case .notice(let key)? = inline {
                    Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("club.home.join.notice.\(club.id)")
                }
                CYScreenOfflineWriteBanner(
                    routes: ["/api/club/join"],
                    session: offlineWriteSession.session
                )
                if section == .nearby {
                    // Nearby photo cards have no card surface around their footer; their chips stay under it.
                    ClubTabTagLine(club: club, section: section, topicCount: nil)
                }
            }
            .modifier(ClubRowReveal(index: index))
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }
    /// Join in place: one tap from the list. Anything the coordinator cannot do from here falls back to the detail.
    private func joinInline(_ club: ClubRecord, action: CYClubCardAction) {
        let identity = reader.clubIdentity
        guard action == .join, let coordinator = actionCoordinator, coordinator.isConfigured, identity.isSignedIn,
              coordinator.identity == identity, inlineJoin[club.id] != .working else { openedClubID = club.id; return }
        let id = club.id, owner = inlineOwnerID
        let offlineSession = offlineWriteSession.session
        inlineJoin[id] = .working
        Task {
            do {
                let value = try await coordinator.prepare(clubID: id, action: .join, expectedIdentity: identity, ownerID: owner)
                guard coordinator.identity == identity else { coordinator.cancel(value); inlineJoin[id] = nil; return }
                _ = await SessionOfflineSyncModel.shared.performWriteOptIn(
                    environmentSession: offlineSession,
                    routes: ["/api/club/join"]
                ) {
                    await coordinator.confirm(value)
                }
                if case .received(let detail) = coordinator.readback(clubID: id), detail.id == id {
                    inlineJoin[id] = detail.isJoined ? .joined : detail.joinPending ? .pending : .notice("club.action.acknowledged")
                    return
                }
                switch coordinator.state(clubID: id) {
                case .acknowledged: inlineJoin[id] = .notice("club.action.acknowledged")
                case .outcomeUnknown: inlineJoin[id] = .notice("club.action.unknown")
                case .rejected: inlineJoin[id] = .notice("club.action.rejected")
                default: inlineJoin[id] = .notice("club.action.notSent")
                }
            } catch {
                inlineJoin[id] = .notice((error as? ClubActionBlock) == .eligibilityChanged ? "club.action.changed" : "club.action.prepareFailed")
            }
        }
    }
    /// Style · city, blank parts dropped; the member count lives in the footer strip.
    private func clubPlace(_ club: ClubRecord) -> String? {
        let place = [club.style, club.city].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " · ")
        return place.isEmpty ? nil : place
    }
    private func eventRow(_ event: ClubHomeEvent, page: ClubTabPageModel?) -> some View {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let signups = page?.events.first { $0.id == event.id }?.signupCount
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Group {
                if title.isEmpty {
                    CYListRow("club.untitledEvent", trailing: .none) { CYRowIcon(systemImage: "flag.checkered") }
                } else {
                    CYListRow(verbatim: title, trailing: .none) { CYRowIcon(systemImage: "flag.checkered") }
                }
            }
            .accessibilityElement(children: .combine)
            if let signups {
                Text("club.tab.eventSignups \(signups.text)")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("club.event.signups.\(event.id)")
            }
        }
    }
    /// Home facts plus the Core page model over the raw body. A reader without a raw body (capability off) yields no
    /// page model, so the tab renders exactly as before; a body that is not a usable home stays hidden too.
    private func loadTab() async throws -> ClubTabLoaded {
        async let body = reader.clubHomeBodyIfAvailable()
        let home = try await reader.clubHome()
        let raw = await body
        let merchant = discoveryScope.isMerchantViewer
        let page = try await PlayerFeedJSON.perform { raw.map { ClubTabPageModel.project(homeBody: $0, merchant: merchant) } }
        return ClubTabLoaded(home: home, page: page.flatMap { $0.phase == .ready || $0.phase == .empty ? $0 : nil })
    }
}

/// Flat elevated plate for list chrome (events, empty, offline). No perimeter stroke. Join cards keep their own face.
private struct ClubNightGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(CYSpacing.sm)
            .background {
                RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)
                    .fill(CYColor.bgElevated)
            }
    }
}

/// Rows rise in order. Reduce Motion shows them in place.
private struct ClubRowReveal: ViewModifier {
    let index: Int
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(CYMotion.entrance.delay(Double(min(index, 7)) * 0.04)) { shown = true }
                }
            }
    }
}
