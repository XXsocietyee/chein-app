import SwiftUI

/// Place inside the root's existing NavigationStack. This view never uses entry role as access.
@MainActor
struct ClubHomeView<Reader: ClubReading & ObservableObject>: View {
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
    @State private var locality = MerchantClubDiscoveryState()
    /// Card or inline Join pill tapped; both open the gated detail, which still owns the membership action.
    @State private var openedClubID: Int? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    private var discoveryScope: ClubDiscoveryScope { reader.clubDiscoveryScope }
    /// Source talent/list top tabs 帖文 / 俱乐部; it opens on 俱乐部 and loads the feed only when chosen.
    @State private var topTab = ClubTabPresentation.TopTab.club
    private var screenTitle: LocalizedStringKey { community == nil ? "club.title" : "club.tab.title" }
    var body: some View {
        VStack(spacing: 0) {
        if community != nil {
            Picker("club.title", selection: $topTab) {
                ForEach(ClubTabPresentation.TopTab.allCases, id: \.self) { Text(LocalizedStringKey($0.key)).tag($0) }
            }.pickerStyle(.segmented)
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.sm)
                .accessibilityIdentifier("clubTab.topTabs")
                .cyHaptic(.selection, trigger: topTab)
        }
        if topTab == .feed, let community {
            ClubCommunityFeedView(context: community, identity: reader.clubIdentity)
        } else {
        ClubReadScreen(reader: reader, accessibilityPrefix: "club.home", onSignIn: onSignIn,
                       load: { try await loadTab() }) { loaded in
            let home = loaded.home
            let page = loaded.page
            List {
                Section {
                    CYHeroHeader(screenTitle)
                }
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                // Mini-program club tab: 「创建你自己的俱乐部」 stays pinned above the list; merchants never see it.
                if !discoveryScope.isMerchantViewer, let operations = management?.operations {
                    Section {
                        let prompt = Text("club.tab.createPrompt")
                            .font(CYTypography.bodyMedium)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        let create = ClubOperationsEntryButton(target: .create, identity: reader.clubIdentity, access: operations.access, coordinator: operations.coordinator, hostApplication: management?.governance)
                            .buttonStyle(.questifyPrimary)
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: CYSpacing.sm) { prompt; create }
                        } else {
                            HStack(spacing: CYSpacing.md) { prompt; Spacer(minLength: CYSpacing.sm); create.fixedSize() }
                        }
                    }
                }
                // Core page model facts: shown only when the server sent `leaderStatus`; counts it omitted stay an em dash.
                if let page, !discoveryScope.isMerchantViewer, page.leader != .hidden {
                    Section {
                        Text("club.tab.leaderQuota \(page.leader.ownedCount.text) \(page.leader.maxOwned.text)")
                            .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
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
                    Section {
                        // 你的俱乐部 (row cards), then 发现 (photo cards with the inline Join pill).
                        if !home.owned.isEmpty || !home.joined.isEmpty {
                            clubSectionHeader("club.home.yours")
                            clubRows(home.owned, identifier: "club.home.owned", section: .owned, page: page)
                            clubRows(home.joined, identifier: "club.home.joined", section: .joined, page: page)
                        }
                        if !nearby.isEmpty {
                            clubSectionHeader("club.home.discover")
                            clubRows(nearby, identifier: "club.home.nearby", section: .nearby, page: page)
                        }
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
                    } label: {
                        CYListRow("club.directory", trailing: .chevron) { CYRowIcon(systemImage: "magnifyingglass") }
                    }
                        .accessibilityIdentifier("club.openDirectory")
                    if !discoveryScope.isMerchantViewer {
                        NavigationLink {
                            ClubOwnedView(reader: reader, onSignIn: onSignIn, actionCoordinator: actionCoordinator, management:management, community:community, publicRoster:publicRoster)
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
                    }
                    ForEach(Array(home.events.enumerated()), id: \.offset) { _, event in
                        if let topicDestination, event.id > 0 {
                            NavigationLink { topicDestination(event.id) } label: { eventRow(event, page: page) }
                                .accessibilityIdentifier("club.event.\(event.id)")
                        } else if let onTopicDestination {
                            Button { onTopicDestination(event.id) } label: { eventRow(event, page: page) }
                                .buttonStyle(.cyPressable)
                                .accessibilityIdentifier("club.event.\(event.id)")
                        } else { eventRow(event, page: page) }
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
        }
        .onChange(of: requestedClubID?.wrappedValue, initial: true) { _, id in
            guard let id else { return }
            openedClubID = id; requestedClubID?.wrappedValue = nil
        }
        .cyHeroScreen()
        .environment(\.clubEnrollmentProfile, management?.governance?.enrollmentProfile)
        .environment(\.clubCustomerTopics, management?.governance?.customerTopics ?? .init())
        .environment(\.clubPostPlayHost, ClubPostPlayHost.session(reader as? AppSession))
        .environment(\.clubEditDetailBody, { id in try await reader.clubDetailBody(id: id) })
        .task(id: discoveryScope) {
            if locality.phase(in: discoveryScope) != .ready { await loadLocality() }
        }
        .onDisappear { locality.leaveScreen() }
    }
    private var playerEmpty: some View {
        let keys = ClubTabPresentation.emptyKeys(merchant: false)
        return CYEmptyState(systemImage: "person.3", LocalizedStringKey(keys.title), messageIdentifier: "clubTab.empty")
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
                    systemImage: "exclamationmark.triangle",
                    "club.locality.unavailable",
                    messageIdentifier: "club.home.locality.unavailable",
                    actionTitle: "action.retry",
                    actionIdentifier: "club.home.locality.retry",
                    kind: .failure
                ) { Task { await loadLocality() } }
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
                    messageIdentifier: "club.home.nearby.empty"
                )
            }
            clubRows(rows, identifier: "club.home.nearby", section: .nearby, page: page)
        } header: {
            if locality.phase(in: discoveryScope) == .ready {
                Text("club.locality.ready")
                    .font(CYTypography.sectionTitle)
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
    private func clubSectionHeader(_ title: LocalizedStringKey) -> some View {
        CYSectionHeader(title)
            .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.xs, trailing: CYSpacing.pageHorizontal))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private func clubRows(_ rows: [ClubRecord], identifier: String,
                                       section: ClubTabPresentation.Section, page: ClubTabPageModel?) -> some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, club in
            let action = club.cardAction(viewerIsMerchant: discoveryScope.isMerchantViewer)
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if section == .nearby {
                    CYClubPhotoCard(name: club.name, place: clubPlace(club), coverURL: QuestifyCardArtwork.safeURL(club.cover),
                                    memberCount: club.sourceMemberCount, seed: "\(club.id)", prominent: index == 0,
                                    action: action, onOpen: { openedClubID = club.id }, onJoin: { openedClubID = club.id },
                                    identifier: identifier + ".\(club.id)")
                } else {
                    CYClubRowCard(name: club.name, logoURL: QuestifyCardArtwork.safeURL(club.logo), memberCount: club.sourceMemberCount,
                                  seed: "\(club.id)", action: action, onOpen: { openedClubID = club.id },
                                  identifier: identifier + ".\(club.id)")
                }
                ClubTabTagLine(club: club, section: section,
                               topicCount: section == .nearby ? nil : page?.rows.first { $0.id == club.id && $0.section == section }?.topicCount)
            }
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
        return VStack(alignment: .leading, spacing: CYSpacing.xxs) {
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
                    .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
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
        let page = raw.map { ClubTabPageModel.project(homeBody: $0, merchant: discoveryScope.isMerchantViewer) }
        return ClubTabLoaded(home: home, page: page.flatMap { $0.phase == .ready || $0.phase == .empty ? $0 : nil })
    }
}
