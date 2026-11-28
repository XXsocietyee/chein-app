import SwiftUI

@MainActor final class NearbyTeamScreenModel: ObservableObject {
    let coordinator: NearbyTeamCoordinator
    @Published private(set) var running = false
    init(_ coordinator: NearbyTeamCoordinator) { self.coordinator = coordinator }
    func run(_ work: () async -> Void) async { guard !running else { return }; running = true; await work(); running = false }
    func prepare(_ action: NearbyTeamAction) { coordinator.prepare(action); objectWillChange.send() }
    func confirmReviewed(_ snapshot: NearbyTeamReview) async {
        if case let .handle(team, applicant, approved) = snapshot.action, AccountPublishContractLane.isInstalled {
            let outcome = await AccountPublishContractLane.handleApplicant(memberID: String(applicant.rawValue), teamID: String(team.rawValue), approved: approved)
            coordinator.adoptContractHandle(snapshot, sent: outcome != .failed && outcome != .unavailable)
            objectWillChange.send()
            return
        }
        await coordinator.confirm(snapshot)
        objectWillChange.send()
    }
    func cancel() { coordinator.cancelReview(); objectWillChange.send() }
    var review: Binding<NearbyTeamReview?> { .init(get: { self.coordinator.review }, set: { if $0 == nil { self.cancel() } }) }
}
/// Host supplies an account-scoped coordinator and optional manual map context. No device-location APIs.
@MainActor struct NearbyTeamsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @State private var ownedReadVisible = false
    @State private var ownedReadVisit = UUID()
    @StateObject private var discovery = NearbyMapDiscoveryModel()
    @State private var discoveryFilter = NearbyMapDiscoveryFilter()
    @State private var discoverySelection: NearbyMapDiscoverySelection?
    @State private var submittedContext: NearbyQueryContext?
    @StateObject private var model: NearbyTeamScreenModel
    @State private var latitude = ""
    @State private var longitude = ""
    /// RNEAR-1: MP nearby locates the device (one foreground fix, GCJ-02) instead of asking for typed coordinates.
    @State private var locating = false
    @State private var locateFailure: LocalizedStringKey?
    /// RNEAR-6: MP nearby starts at 1 km when the host gave no area.
    @State private var radius = 1000
    @State private var showingRange = false
    @State private var showingMapStyle = false
    @State private var mapStyle: PlayNearbyMapStyle = .paper
    @State private var toastMessage: String?
    @State private var tab = 0
    @State private var viewMode = NearbyTeamViewMode.map
    @State private var focusedTeamID: NearbyTeamID?
    @State private var mine = NearbyMineLoad()
    @State private var recruiting = NearbyRecruitingLoad.idle
    /// RTEAMS-3c: pending join counts per led recruiting team (MP my-teams index.js:139-155 `pending`).
    @State private var leaderPending: [Int: NearbyLeaderApplicantFact] = [:]
    let initialContext: NearbyQueryContext?
    let joinedTeams: [OwnedTeam]
    let onSignIn: (() -> Void)?
    let joinedTeamsStatus: NearbyOwnedTeamsStatus
    let retryJoinedTeams: (() -> Void)?
    let discoverySources: NearbyMapDiscoverySources?
    let navigate: (NearbyTeamDestination) -> Void
    /// RTEAMS-3: MP my-teams nav action 加入码 (`team/join?entry=code`); nil hides it.
    let joinCodeDestination: (() -> AnyView)?
    /// `initialRadius`/`focusTeamID`/`initialTab` mirror the xcx `?radius=&teamId=` and my-teams entry options.
    init(coordinator: NearbyTeamCoordinator, context: NearbyQueryContext? = nil, joinedTeams: [OwnedTeam] = [],
         initialTab: Int = 0, initialRadius: Int? = nil, focusTeamID: NearbyTeamID? = nil, onSignIn: (() -> Void)? = nil,
         joinedTeamsStatus: NearbyOwnedTeamsStatus = .loaded, retryJoinedTeams: (() -> Void)? = nil,
         discoverySources: NearbyMapDiscoverySources? = nil,
         joinCodeDestination: (() -> AnyView)? = nil,
         navigate: @escaping (NearbyTeamDestination) -> Void = { _ in }) {
        self.joinCodeDestination = joinCodeDestination
        _model = StateObject(wrappedValue: NearbyTeamScreenModel(coordinator)); initialContext = context; self.joinedTeams = joinedTeams; self.navigate = navigate
        self.onSignIn = onSignIn; self.joinedTeamsStatus = joinedTeamsStatus; self.retryJoinedTeams = retryJoinedTeams
        self.discoverySources = discoverySources
        if let context {
            _submittedContext = State(initialValue: .init(latitude: context.latitude, longitude: context.longitude,
                radius: initialRadius.flatMap { NearbyQueryContext.radii.contains($0) ? $0 : nil } ?? context.radius))
        }
        _tab = State(initialValue: initialTab == 1 ? 1 : 0); _focusedTeamID = State(initialValue: focusTeamID)
        if let initialRadius, NearbyQueryContext.radii.contains(initialRadius) { _radius = State(initialValue: initialRadius) }
        else if let context { _radius = State(initialValue: context.radius) }
    }
    private var coordinator: NearbyTeamCoordinator { model.coordinator }
    var body: some View {
        Group {
            // RNEAR-2 (MP nearby wxml:14-18): map first, full bleed, with the team list in a draggable in-view panel
            // (compact / medium / large). In-view, not a system sheet, so the review / range / style / discovery sheets keep working.
            if mapFirst, let center = mapCenter {
                CYMapScaffold(detent: .medium, peek: AnyView(mapPeek)) {
                    teamMap(center, fills: true)
                } controls: { EmptyView() } floating: { EmptyView() } panel: {
                    ScrollView { listContent }
                }
            } else {
                ScrollView { listContent }
            }
        }
        .refreshable { if coordinator.authenticated && !model.running { await refresh() } }
        // RNEAR-3 / RTEAMS-2: one inline bar title, no page-type header in the content.
        .cyPageTitle(tab == 1 ? String.LocalizationValue(stringLiteral: "nearby.mine") : String.LocalizationValue(stringLiteral: "nearby.title"))
            .toolbar {
                // Native restyle (native-ios-r1 §3.1): refresh is pull-to-refresh only (`.refreshable` above calls the same refresh()).
                if tab == 0 { ToolbarItem(placement: .topBarTrailing) { NearbyTeamViewModePicker(mode: $viewMode) } }
                if tab == 1 {
                    // MP my-teams nav: 加入码 opens the existing join entry; 地图 opens the existing team map.
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let joinCodeDestination {
                            NavigationLink { joinCodeDestination() } label: { Label("gap.team.joinCode", systemImage: "number") }
                                .accessibilityIdentifier("nearby.mine.joinCode")
                        }
                        Button {
                            radius = NearbyTeamPresentation.recruitingRadius
                            viewMode = .map
                            tab = 0
                        } label: {
                            Label("nearby.mine.map", systemImage: "map").labelStyle(.titleAndIcon)
                        }
                        .accessibilityIdentifier("nearby.mine.map")
                    }
                }
            }
            .cySheet(item: model.review) { review in
                NearbyTeamReviewView(model: model, snapshot: review)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.clear)
            }
            .cySheet(isPresented: $showingRange) {
                PlayAreaNearbyRangeSheet(radii: NearbyQueryContext.radii, selected: radius, onSelect: { picked in
                    radius = picked
                    showingRange = false
                    toastMessage = PlayCloseCopy.text("已切换范围 \(picked / 1000) km", "Range updated to \(LocaleDisplay.radius(meters: Double(picked), locale: locale) ?? "\(picked / 1000) km")", locale)
                }, onClose: { showingRange = false })
            }
            .cySheet(isPresented: $showingMapStyle) {
                PlayAreaNearbyMapStyleSheet(selected: mapStyle, onSelect: { picked in
                    mapStyle = picked
                    showingMapStyle = false
                    toastMessage = PlayCloseCopy.text("已切换地图样式：\(picked.title(locale: locale))", "Map style: \(picked.title(locale: locale))", locale)
                }, onClose: { showingMapStyle = false })
            }
            .clubIslandStatus(verbatimMessage: $toastMessage, surface: "team-nearby")
            .task {
                guard !Task.isCancelled else { return }
                coordinator.resume()
                if tab == 1 {
                    await loadMine()
                    return
                }
                if let context = initialContext {
                    latitude = String(context.latitude); longitude = String(context.longitude)
                    submitManualContext(.init(latitude: context.latitude, longitude: context.longitude, radius: radius))
                    await model.run { await coordinator.loadNearby(.init(latitude: context.latitude, longitude: context.longitude, radius: radius)) }
                } else if RoamDeviceFixGCJ.isAuthorized {
                    // RNEAR-1: already allowed → locate straight away like the MP; otherwise wait for 使用当前位置.
                    await locateAndSearch()
                }
            }
            .onChange(of: tab) { _, value in if value == 1 { Task { await loadMine() } } }
            .onAppear { ownedReadVisible = true; ownedReadVisit = UUID(); reloadDiscovery(force: true) }
            .onChange(of: discoveryInput) { previous, next in
                if previous.placesID != next.placesID || previous.eventsID != next.eventsID ||
                   previous.placesIdentity != next.placesIdentity || previous.eventsIdentity != next.eventsIdentity {
                    discoverySelection = nil; discoveryFilter = .init()
                }
                reloadDiscovery()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && ownedReadVisible { reloadDiscovery(force: true) }
                else { discovery.cancel() }
            }
            .onChange(of: joinedTeamsStatus) { _, _ in ownedReadVisit = UUID(); recruitAfterOwnedRead() }
            .onChange(of: joinedTeams) { _, _ in ownedReadVisit = UUID(); recruitAfterOwnedRead() }
            .onChange(of: mine.loading) { _, loading in if !loading { recruitAfterOwnedRead() } }
            .onDisappear { ownedReadVisible = false; ownedReadVisit = UUID(); discovery.cancel(); coordinator.leave() }
            .cySheet(item: $discoverySelection, onDismiss: {
                if ownedReadVisible { reloadDiscovery(force: true) }
            }) { selection in Group {
                if scenePhase == .active, let sources = discoverySources,
                   selection.scope == currentDiscoveryScope(selection.item), discovery.mayRemainOpen(selection) {
                    sources.destination(selection.item)
                } else { RoamStatusView(issue: .unauthorized) }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }
    /// Tab 0 in map mode with a centre: the map fills the screen and the list rides in the panel.
    private var mapFirst: Bool { tab == 0 && viewMode == .map && mapCenter != nil }
    @ViewBuilder private var listContent: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            // MP my-teams wxml:16 `team-recovery-panel` (待确认的队伍操作 / read errors) sits right under the title,
            // above .mt-stats and the 我的 / 附近招募 segment.
            notice
            if tab == 1 { mineStats }
            Picker("nearby.section", selection: $tab) {
                Text("nearby.title").tag(0); Text("nearby.mine").tag(1)
            }.cyAdaptiveSegmented().accessibilityIdentifier("nearby.section")
            if tab == 0 {
                let renderedDiscovery = discovery.snapshotID
                contextControls
                if discoverySources != nil {
                    NearbyMapDiscoveryControls(filter: $discoveryFilter, items: currentDiscoveryItems)
                    NearbyMapDiscoveryStatusView(model: discovery, filter: discoveryFilter) { reloadDiscovery(force: true) }
                }
                if discoverySources == nil || discoveryFilter.includesTeams {
                NearbyTeamCountLine(loaded: discoverySources == nil ? (coordinator.authenticated && !model.running && coordinator.context != nil && coordinator.messageKey == nil) : nearbyCurrentReadSucceeded, count: visibleTeams.count)
                if model.running { CYLoadingStateView(rows: 1, label: "nearby.loading") }
                if let issue = NearbyLoadIssue(messageKey: coordinator.messageKey), !model.running {
                    NearbyLoadIssueCard(issue: issue, onSignIn: onSignIn) { Task { await refresh() } }
                } else if !model.running && coordinator.authenticated && coordinator.context != nil && coordinator.messageKey == nil && visibleTeams.isEmpty && (discoverySources == nil || nearbyCurrentReadSucceeded) && !discoveryEmptyShown {
                    CYEmptyState(systemImage: "person.3", "nearby.empty", detail: "nearby.w208.listEmpty", messageIdentifier: "nearby.list.empty")
                }
                }
                if viewMode == .map {
                    if let center = mapCenter, !mapFirst { teamMap(center, fills: false) }
                    ForEach(orderedTeams) { team in teamCard(team) }
                } else {
                    if discoverySources == nil || discoveryFilter.includesTeams && nearbyCurrentReadSucceeded {
                        NearbyTeamListHeader(radius: displayedRadius, count: visibleTeams.count)
                    }
                    ForEach(visibleTeams) { team in
                        NearbyTeamListRow(team: team, expanded: focusedTeamID == team.id) { focusedTeamID = focusedTeamID == team.id ? nil : team.id }
                        if focusedTeamID == team.id { teamCard(team) }
                    }
                }
                ForEach(discoveryItems) { item in
                    NearbyMapDiscoveryRow(item: item) { openDiscovery(item, rendered: renderedDiscovery) }
                }
                if discoveryEmptyShown {
                    // MP subpackageRoam/nearby wxml:71: one cy-empty 附近暂无节点, never a second team empty above it.
                    CYEmptyState(systemImage: "map", LocalizedStringKey("nearby.map.empty"), tableName: "NearbyMapDiscovery", messageIdentifier: "nearby.discovery.empty")
                }
                NearbyTeamCornerBar(radius: displayedRadius,
                                    mineCount: joinedTeamsStatus.isLoaded ? NearbyTeamBridge.activeCount(NearbyTeamBridge.myRows(joined: joinedTeams, applications: coordinator.myApplications)) : 0) { tab = 1 }
                if discoverySources == nil || discoveryFilter.includesTeams { applicantSection }
            } else { mineSection }
        }.padding()
    }
    private func teamMap(_ center: RoamSearchArea, fills: Bool) -> some View {
        let renderedDiscovery = discovery.snapshotID
        return NearbyTeamMapSection(center: center, teams: visibleTeams, focusedID: focusedTeamID,
            items: discoveryItems, selectedExtraID: discoverySelection?.item.id,
            onSelectExtra: { openDiscovery($0, rendered: renderedDiscovery) }, fillsHeight: fills) { id in
                guard scenePhase == .active, visibleTeams.contains(where: { $0.id == id }) else { return }
                focusedTeamID = id
            }
    }
    /// Collapsed panel line: the same 附近的队伍 · N 支在招募 count the list shows.
    private var mapPeek: some View {
        NearbyTeamCountLine(loaded: discoverySources == nil ? (coordinator.authenticated && !model.running && coordinator.context != nil && coordinator.messageKey == nil) : nearbyCurrentReadSucceeded, count: visibleTeams.count)
            .padding(.horizontal, CYSpacing.xl).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
    private var discoveryInput: NearbyMapDiscoveryInput { .init(sources: discoverySources, query: submittedContext) }
    private var currentDiscoveryItems: [RoamMapItem] {
        guard ownedReadVisible, scenePhase == .active else { return [] }
        return discovery.currentItems(sources: discoverySources, query: submittedContext)
    }
    private var discoveryItems: [RoamMapItem] { currentDiscoveryItems.filter(discoveryFilter.includes) }
    private var discoveryEmptyShown: Bool {
        guard discoverySources != nil, discoveryFilter.layer != .team, discoveryItems.isEmpty, discovery.placesPhase == .loaded else { return false }
        return discoveryFilter.layer == .shop || discovery.eventsPhase == .loaded
    }
    private var displayedRadius: Int { (discoverySources != nil ? submittedContext : coordinator.context)?.radius ?? radius }
    private var nearbyCurrentReadSucceeded: Bool {
        scenePhase == .active && !model.running && submittedContext?.valid == true &&
            coordinator.context == submittedContext && NearbyLoadIssue(messageKey: coordinator.messageKey) == nil
    }
    private var visibleTeams: [NearbyTeam] {
        guard discoverySources != nil else { return coordinator.teams }
        return discoveryFilter.includesTeams && nearbyCurrentReadSucceeded ? coordinator.teams : []
    }
    private func submitManualContext(_ query: NearbyQueryContext) {
        guard discoverySources != nil, query.valid else { return }
        submittedContext = query; discoverySources?.selectManualArea(query); reloadDiscovery()
    }
    private func reloadDiscovery(force: Bool = false) {
        guard discoverySources != nil else { return }
        discovery.load(sources: discoverySources, query: submittedContext, active: ownedReadVisible && scenePhase == .active, force: force)
    }
    private func currentDiscoveryScope(_ item: RoamMapItem) -> NearbyMapDiscoveryScope? {
        let reader: (any RoamReading)?
        switch item { case .place: reader = discoverySources?.places; case .event: reader = discoverySources?.events; default: return nil }
        return .init(reader: reader, query: submittedContext)
    }
    private func openDiscovery(_ item: RoamMapItem, rendered: UUID) {
        guard discoverySelection == nil, discoveryFilter.includes(item),
              let selected = discovery.select(item, rendered: rendered, active: ownedReadVisible && scenePhase == .active),
              selected.scope == currentDiscoveryScope(item) else { return }
        discoverySelection = selected
    }
    private func recruitAfterOwnedRead() {
        let offered = ownedReadVisit
        // Independent sources can finish in either order. Never turn an unknown private list into empty.
        guard joinedTeamsStatus.isLoaded, tab == 1, mine.loaded, !mine.loading, !mine.failed, recruiting == .idle else { return }
        Task {
            guard !Task.isCancelled, ownedReadVisible, scenePhase == .active, ownedReadVisit == offered,
                  !model.running, !mine.loading, !mine.failed, recruiting == .idle,
                  NearbyTeamBridge.myRows(joined: joinedTeams, applications: coordinator.myApplications).isEmpty else { return }
            await loadRecruiting()
        }
    }
    /// Only real states reach the player: example marker, an unresolved action, and messages from the server.
    @ViewBuilder private var notice: some View {
        let hasMessage = coordinator.messageKey != nil || !coordinator.serverMessage.isEmpty
        if coordinator.synthetic || coordinator.uncertain || hasMessage {
            VStack(alignment: .leading, spacing: 8) {
                if coordinator.synthetic { CYStatusChip("nearby.fixture", tone: .neutral, systemImage: "testtube.2") }
                if coordinator.uncertain { CYStatusChip("nearby.unknown", tone: .warning, systemImage: "exclamationmark.triangle") }
                if let key = coordinator.messageKey {
                    Text(LocalizedStringKey(key)).accessibilityIdentifier("nearby.message")
                }
                if !coordinator.serverMessage.isEmpty { Text(verbatim: coordinator.serverMessage).accessibilityIdentifier("nearby.serverMessage") }
            }.cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                // N-RTEAMS (r10): system GroupBox instead of the drawn domain card (MP my-teams / nearby wxml notice block).
                .groupBoxWrapped()
        }
    }
    /// Mini-program 范围 control. Coordinates are only typed in when the host gave no map point.
    private var contextControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if initialContext == nil {
                Text("nearby.context.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                CYPillButton(LocalizedStringKey(locating ? "nearby.locating" : "nearby.useLocation"), style: .primary, systemImage: "location.fill", fullWidth: false) {
                    Task { await locateAndSearch() }
                }
                .disabled(locating || model.running).accessibilityIdentifier("nearby.useLocation")
                if let locateFailure {
                    Text(locateFailure).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("nearby.locateFailed")
                }
                #if DEBUG
                // Manual coordinates stay a DEBUG-only tool for fixtures and simulators.
                TextField("nearby.latitude", text: $latitude).textFieldStyle(.roundedBorder).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("nearby.latitude")
                TextField("nearby.longitude", text: $longitude).textFieldStyle(.roundedBorder).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("nearby.longitude")
                #endif
            }
            HStack {
                Button { showingRange = true } label: {
                    Text(verbatim: LocaleDisplay.isChinese(locale) ? "\(radius / 1000) km" : (LocaleDisplay.radius(meters: Double(radius), locale: locale) ?? "\(radius / 1000) km"))
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                }
                .accessibilityIdentifier("nearby.radius")
                .accessibilityLabel(Text(verbatim: PlayAreaPopupCopy.text("范围", "Range", locale: locale)))
                Button { showingMapStyle = true } label: {
                    Text(verbatim: mapStyle.title(locale: locale))
                        .cyText(.caption)
                        .foregroundStyle(CYColor.textSecondary)
                }
                .accessibilityIdentifier("nearby.mapStyle")
                .accessibilityLabel(Text(verbatim: PlayCloseCopy.text("地图样式", "Map style", locale)))
                Spacer(minLength: 8)
                CYPillButton("nearby.search", style: .secondary, systemImage: "magnifyingglass", fullWidth: false) { Task { await refresh() } }
                    .disabled(model.running).accessibilityIdentifier("nearby.search")
            }
        }
    }
    /// One foreground fix through the standard permission flow (RoamDeviceFixGCJ), then the same search as before.
    private func locateAndSearch() async {
        guard !locating else { return }
        locating = true; locateFailure = nil
        defer { locating = false }
        do {
            let fix = try await RoamDeviceFixGCJ.currentGCJ02Fix(provider: RuntimeNativeLocationProvider(enabled: true))
            latitude = String(fix.coordinate.latitude); longitude = String(fix.coordinate.longitude)
            await refresh()
        } catch is CancellationError {
            return
        } catch {
            locateFailure = error as? RoamActionFailure == .locationDenied ? "nearby.locationDenied" : "nearby.locationFailed"
        }
    }
    private func refresh() async {
        if tab == 1 { await loadMine(); return }
        guard let lat = Double(latitude), let lng = Double(longitude) else {
            if discoverySources != nil { submittedContext = nil; discovery.cancel() }
            await model.run { await coordinator.loadNearby(.init(latitude: .nan, longitude: .nan)) }; return
        }
        let query = NearbyQueryContext(latitude: lat, longitude: lng, radius: radius)
        if query.valid { submitManualContext(query); reloadDiscovery(force: true) }
        else if discoverySources != nil { submittedContext = nil; discovery.cancel() }
        await model.run { await coordinator.loadNearby(query) }
    }
    /// The manually selected query point only; there is no device-location fallback or self marker.
    private var mapCenter: RoamSearchArea? {
        guard let source = (discoverySources != nil ? submittedContext : coordinator.context ?? initialContext),
              let coordinate = RoamCoordinate(latitude: source.latitude, longitude: source.longitude) else { return nil }
        return RoamSearchArea(coordinate: coordinate, label: "")
    }
    /// A tapped marker (or deep-link team) is shown first, like the xcx team card over the map.
    private var orderedTeams: [NearbyTeam] {
        guard let focusedTeamID, let focused = visibleTeams.first(where: { $0.id == focusedTeamID }) else { return visibleTeams }
        return [focused] + visibleTeams.filter { $0.id != focusedTeamID }
    }
    /// my-teams reads 附近招募 around the same manual point at a fixed 3 km. No location fallback.
    private var recruitingContext: NearbyQueryContext? {
        if let lat = Double(latitude), let lng = Double(longitude) { return .init(latitude: lat, longitude: lng, radius: NearbyTeamPresentation.recruitingRadius) }
        return initialContext.map { .init(latitude: $0.latitude, longitude: $0.longitude, radius: NearbyTeamPresentation.recruitingRadius) }
    }
    /// my-teams `reload`; when the viewer has no rows, `loadOpen` runs automatically.
    /// MP my-teams: a guest sees only 登录后查看 + 登录 (PG-004); no mine read, so no 队伍获取失败 under the gate.
    private func loadMine() async {
        guard coordinator.authenticated else { mine.loading = false; mine.failed = false; return }
        mine.loading = true; mine.failed = false
        await model.run { await coordinator.loadMine() }
        mine.loading = false; mine.loaded = true
        mine.failed = NearbyLoadIssue(messageKey: coordinator.messageKey) != nil && coordinator.myApplications.isEmpty && joinedTeams.isEmpty
        if !mine.failed && joinedTeamsStatus.isLoaded && NearbyTeamBridge.myRows(joined: joinedTeams, applications: coordinator.myApplications).isEmpty { await loadRecruiting() }
    }
    private func loadRecruiting() async {
        guard let context = recruitingContext, context.valid else { recruiting = .noArea; return }
        recruiting = .loading
        submitManualContext(context)
        await model.run { await coordinator.loadNearby(context) }
        if NearbyLoadIssue(messageKey: coordinator.messageKey) != nil || coordinator.context != context { recruiting = .failed }
        else { radius = context.radius; recruiting = .loaded }
    }
    private func teamCard(_ team: NearbyTeam) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                if NearbyTeamPresentation.heading(team).isEmpty { Text("nearby.untitled").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) } else { Text(verbatim: NearbyTeamPresentation.heading(team)).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
                Spacer(minLength: 8)
                NearbyTeamBadgeView(badge: NearbyTeamBadge(mode: team.mode))
            }
            if !team.activityName.isEmpty, !team.title.isEmpty { Text(verbatim: team.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
            NearbyTeamSubLine(team: team)
            NearbyTeamMembersLine(team: team)
            if !team.memberAvatars.isEmpty { NearbyTeamFaces(count: team.memberAvatars.count) }
            NearbyTeamNotice(mode: team.mode)
            CYStatusChip(LocalizedStringKey(team.viewerStatus.key), tone: team.viewerStatus == .pending ? .warning : .neutral, systemImage: team.viewerStatus == .pending ? "clock" : "person.3")
            switch team.mode {
            case "leader":
                Text("nearby.w208.leaderSub \(team.joinedCount) \(team.maxMembers) \(NearbyTeamPresentation.remainingSeats(team))").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                CYPillButton(verbatim: String(localized: LocalizedStringResource("nearby.applicants", table: "Localizable", locale: locale)) + " · \(team.pendingCount)", style: .secondary, systemImage: "person.badge.plus") { Task { await model.run { await coordinator.loadApplicants(teamID: team.id) } } }
                    .disabled(model.running)
            case "joined": routeButton("nearby.enter", destination: .team(team.id))
            case "pending": expiry(team.applyExpireTime); actionButton(.withdraw(team.id))
            case "rejected": Text("nearby.rejected.foot").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            case "apply": actionButton(.apply(team.id))
            case "buy":
                // xcx falls back to the topic page when the team has no activity session.
                if let destination = NearbyTeamBridge.purchaseDestination(team) ?? team.topicID.flatMap({ $0 > 0 ? NearbyTeamDestination.topic($0) : nil }) {
                    routeButton("nearby.w208.buyTicket", destination: destination)
                }
            default: EmptyView()
            }
            NearbyTeamReportButton(teamID: team.id.rawValue, leader: team.mode == "leader" || team.viewerStatus == .leader)
        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            // N-RTEAMS (r10): the team card is a system GroupBox, not the drawn domain card (MP nearby / my-teams team card).
            .groupBoxWrapped()
            .accessibilityElement(children: .contain).accessibilityIdentifier("nearby.team.\(team.id.rawValue)")
    }
    @ViewBuilder private var applicantSection: some View {
        if let teamID = coordinator.applicantsTeamID {
            Text("nearby.applicants").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
            if coordinator.applicants.isEmpty { CYEmptyState(systemImage: "person.badge.plus", "nearby.applicants.empty") }
            ForEach(coordinator.applicants) { applicant in
                VStack(alignment: .leading, spacing: 10) {
                    if applicant.name.isEmpty { Text("nearby.player").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) } else { Text(verbatim: applicant.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                    CYStatusChip("nearby.applicant.ticket", tone: .info, systemImage: "ticket")
                    if let date = applicant.appliedAt?.date() { LabeledContent("nearby.appliedAt") { Text(date, style: .relative) } }
                    expiry(applicant.applyExpireTime)
                    if !applicant.message.isEmpty { Text(verbatim: "“\(applicant.message)”").fixedSize(horizontal: false, vertical: true) }
                    actionButton(.handle(team: teamID, applicant: applicant.id, approved: true))
                    actionButton(.handle(team: teamID, applicant: applicant.id, approved: false), style: .secondary)
                }.padding().accessibilityIdentifier("nearby.applicant.\(applicant.id.rawValue)")
            }
        }
    }
    /// Same successful current-account read gate as `mineSection`'s `mineReady`.
    private var mineReadyForStats: Bool {
        !model.running && !mine.loading && coordinator.authenticated && coordinator.hasLoadedMine && coordinator.messageKey == nil && joinedTeamsStatus.isLoaded && !mine.failed
    }
    /// MP my-teams `.mt-stats`: 带队 / 已通过 / 审核中 / 未通过 counts sit under the page title, above the
    /// 我的 | 附近招募 segment. A row of four zeros repeats the empty state, so the counts stay hidden.
    @ViewBuilder private var mineStats: some View {
        let rows = NearbyTeamBridge.myRows(joined: joinedTeamsStatus.isLoaded ? joinedTeams : [], applications: coordinator.myApplications)
        let groups = NearbyTeamBridge.myGroups(rows, viewerAccountID: coordinator.session?.accountID)
        let everyStatIsZero = NearbyMyTeamGroup.Kind.statsOrder.allSatisfy { NearbyMyTeamGroup.count($0, in: groups) == 0 }
        if !everyStatIsZero && mineReadyForStats {
            HStack(spacing: 8) {
                ForEach(NearbyMyTeamGroup.Kind.statsOrder, id: \.self) { kind in
                    VStack(spacing: 2) {
                        Text(verbatim: String(NearbyMyTeamGroup.count(kind, in: groups))).cyText(.sectionTitle).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                        Text(LocalizedStringKey(kind.statKey)).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    }.frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("nearby.mine.stat.\(kind.rawValue)")
                }
            }.padding(.vertical, 8)
        }
    }
    private var mineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // RTEAMS-4: MP cy-access-gate — 登录后查看 + 登录, not a red error chip with 重试.
            if !coordinator.authenticated {
                CYEmptyState(systemImage: "person.crop.circle", "nearby.mine.signInTitle",
                             actionTitle: onSignIn == nil ? nil : "nearby.mine.signIn", actionIdentifier: "nearby.mine.signIn",
                             actionStyle: .primary, action: onSignIn)
                    .accessibilityIdentifier("nearby.mine.signedOut")
            }
            switch joinedTeamsStatus {
            case .loading:
                CYLoadingStateView(rows: 1, label: "team.loading").accessibilityIdentifier("nearby.mine.owned.loading")
            case .failed where !coordinator.authenticated:
                EmptyView()
            case .failed(let key):
                CYEmptyState(systemImage: "exclamationmark.triangle", LocalizedStringKey(key), messageIdentifier: "nearby.mine.owned.error",
                             actionTitle: "action.retry", actionIdentifier: "nearby.mine.owned.retry", kind: .failure, action: retryJoinedTeams)
            case .loaded: EmptyView()
            }
            if mine.loading { CYLoadingStateView(rows: 1, label: "nearby.w208.mine.loading") }
            else if model.running { CYLoadingStateView(rows: 1, label: "nearby.loading") }
            if mine.failed && !model.running, let mineIssue = NearbyLoadIssue(messageKey: coordinator.messageKey), !mineIssue.offersRetry {
                NearbyLoadIssueCard(issue: mineIssue, onSignIn: onSignIn) {}
            } else if mine.failed && !model.running {
                CYEmptyState(systemImage: "exclamationmark.triangle", "nearby.w208.mine.failedTitle", messageIdentifier: "nearby.w208.mine.failed",
                             actionTitle: "action.retry", actionIdentifier: "nearby.w208.mine.retry", kind: .failure) { Task { await loadMine() } }
            }
            let rows = NearbyTeamBridge.myRows(joined: joinedTeamsStatus.isLoaded ? joinedTeams : [], applications: coordinator.myApplications)
            let groups = NearbyTeamBridge.myGroups(rows, viewerAccountID: coordinator.session?.accountID)
            let mineReady = !model.running && !mine.loading && coordinator.authenticated && coordinator.hasLoadedMine && coordinator.messageKey == nil && joinedTeamsStatus.isLoaded && !mine.failed
            if rows.isEmpty && mine.loaded && mineReady {
                CYEmptyState(systemImage: "person.3", "nearby.w208.mine.empty", messageIdentifier: "nearby.mine.empty",
                             actionTitle: "nearby.mine.findOnMap", actionIdentifier: "nearby.mine.findOnMap", actionStyle: .primary) { radius = NearbyTeamPresentation.recruitingRadius; tab = 0 }
                NearbyRecruitingSection(state: recruiting, teams: recruiting == .loaded ? NearbyTeamPresentation.recruiting(coordinator.teams) : [],
                                        retry: { Task { await loadRecruiting() } }) { id in
                    radius = NearbyTeamPresentation.recruitingRadius; focusedTeamID = id; viewMode = .map; tab = 0
                }
            }
            ForEach(groups) { group in
                Text(LocalizedStringKey(group.kind.titleKey)).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("nearby.mine.group.\(group.kind.rawValue)")
                ForEach(group.rows) { row in mineRow(row, leading: group.kind == .leading) }
            }
        }
        .task(id: leaderPendingKey) { await loadLeaderPending() }
    }
    /// Re-read when the led-team list or the session changes (MP `_loadPending(lead)` after every list load).
    private var leaderPendingKey: String {
        guard joinedTeamsStatus.isLoaded, let account = coordinator.session?.accountID else { return "" }
        return String(account) + ":" + joinedTeams.map { String($0.id) + "." + String($0.status.rawValue) }.joined(separator: ",")
    }
    private func loadLeaderPending() async {
        leaderPending = [:]
        guard joinedTeamsStatus.isLoaded else { return }
        for team in joinedTeams {
            guard !Task.isCancelled else { return }
            if let fact = await coordinator.leaderApplicantFact(team: team), !Task.isCancelled { leaderPending[team.id] = fact }
        }
    }
    /// MP card line: `N 条入队申请`, or `申请数没读到` when the read failed; zero draws nothing.
    @ViewBuilder private func leaderPendingLine(_ teamID: Int) -> some View {
        switch leaderPending[teamID] {
        case .count(let n) where n > 0:
            Text("nearby.mine.pendingApplications \(n)").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("nearby.mine.pending.\(teamID)")
        case .unread:
            Text("nearby.mine.pendingUnread").cyText(.bodyCompact).foregroundStyle(CYColor.textTertiary)
                .accessibilityIdentifier("nearby.mine.pending.\(teamID)")
        default:
            EmptyView()
        }
    }
    @ViewBuilder private func mineRow(_ row: NearbyTeamOwnedRow, leading: Bool) -> some View {
        switch row {
        case .joined(let team):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    NearbyTeamFaces(count: NearbyTeamPresentation.faceCount(real: 0, members: team.joinedCount))
                    if team.title.isEmpty { Text("nearby.w208.mine.untitled").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) } else { Text(verbatim: team.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                    Spacer(minLength: 8)
                    NearbyTeamBadgeView(badge: leading ? .leader : .joined, captain: leading)
                }
                if let start = NearbyTeamPresentation.startText(team.expireTime) { Text("nearby.w208.mine.start \(start)").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                else { Text(leading ? "nearby.mine.badge.leading" : "nearby.mine.badge.approved").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                NearbyMineMembersText(joined: team.joinedCount, maximum: team.maxMembers)
                if leading { leaderPendingLine(team.id) }
                routeButton("nearby.enter", destination: .team(.init(team.id)))
            }.accessibilityElement(children: .contain)
                .accessibilityIdentifier("nearby.joined.\(team.id)")
        case .application(let application):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    NearbyTeamFaces(count: NearbyTeamPresentation.faceCount(real: application.leaderAvatar.isEmpty ? 0 : 1, members: application.joinedCount))
                    if application.title.isEmpty { Text("nearby.w208.mine.untitled").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) } else { Text(verbatim: application.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                    Spacer(minLength: 8)
                    NearbyTeamBadgeView(badge: application.status == .pending ? .pending : .rejected)
                }
                if application.status == .pending, !application.activityName.isEmpty { Text(verbatim: application.activityName).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                NearbyMineMembersText(joined: application.joinedCount, maximum: application.maxMembers)
                CYStatusChip(LocalizedStringKey(application.status.key), tone: application.status == .pending ? .warning : .danger)
                if !application.leaderName.isEmpty { LabeledContent("nearby.leader") { Text(verbatim: application.leaderName) } }
                if application.status == .pending { expiry(application.applyExpireTime); actionButton(.withdraw(application.id)) }
                else { Text("nearby.rejected.foot").cyText(.meta).foregroundStyle(CYColor.textTertiary); CYPillButton("nearby.lookNearby", style: .secondary) { radius = NearbyTeamPresentation.recruitingRadius; tab = 0 } }
            }.accessibilityElement(children: .contain)
                        .accessibilityIdentifier("nearby.application.\(application.id.rawValue)")
        }
    }
    /// Hidden when this build cannot send team actions, instead of a button that leads nowhere.
    @ViewBuilder private func actionButton(_ action: NearbyTeamAction, style: CYPillStyle = .primary) -> some View {
        if coordinator.canSubmit {
            CYPillButton(LocalizedStringKey(action.key), style: style) { model.prepare(action) }
                .disabled(model.running || !coordinator.allowed(action)).accessibilityIdentifier("nearby.\(action.operation).\(action.teamID.rawValue)")
        }
    }
    private func routeButton(_ key: LocalizedStringKey, destination: NearbyTeamDestination) -> some View {
        CYPillButton(key) { navigate(destination) }
    }
    @ViewBuilder private func expiry(_ value: NearbyServerTime?) -> some View {
        if let minutes = value?.remainingMinutes(now: Date()) {
            LabeledContent("nearby.expiry") { Text(verbatim: "\(minutes < 60 ? minutes : minutes / 60)"); Text(minutes < 60 ? "nearby.minutes" : "nearby.hours") }
        } else if let value, case .text(let raw) = value, value.date() != nil {
            // Preserve the server text: offset-free timestamps have no verified
            // source time zone. This is not a server application-status verdict.
            LabeledContent("nearby.expiry.deadline") {
                Text(verbatim: raw).fixedSize(horizontal: false, vertical: true)
            }
        } else { Text("nearby.expiry.rule").font(.footnote) }
    }
}
@MainActor private struct NearbyTeamReviewView: View {
    @ObservedObject var model: NearbyTeamScreenModel
    let snapshot: NearbyTeamReview
    @Environment(\.locale) private var locale
    @State private var note: String

    init(model: NearbyTeamScreenModel, snapshot: NearbyTeamReview) {
        self.model = model
        self.snapshot = snapshot
        _note = State(initialValue: snapshot.note ?? "")
    }

    private var isDestructiveAction: Bool {
        switch snapshot.action {
        case .withdraw, .handle(_, _, false): return true
        default: return false
        }
    }

    private var consequenceKeys: [String] {
        switch snapshot.action {
        case .handle(_, _, false):
            return ["nearby.consequence.reject.1", "nearby.consequence.reject.2"]
        default:
            return []
        }
    }

    var body: some View {
        if case .apply = snapshot.action {
            PlayNearbyApplyNoteModal(
                teamName: snapshot.team?.title ?? "",
                note: $note,
                busy: model.running || !model.coordinator.canSubmit,
                onCancel: { model.cancel() },
                onConfirm: {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await model.run { await model.coordinator.confirm(snapshot, note: trimmed) } }
                }
            )
        } else {
            reviewSheetBody
        }
    }

    /// N-RTEAMS (r10): the review as a system sheet: NavigationStack + Form, inline title, a ✕ cancellation item
    /// and system buttons (MP subpackageRoam/my-teams/index.wxml review / handle modal).
    private var reviewSheetBody: some View {
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: snapshot.team?.title ?? snapshot.application?.title ?? "")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let applicant = snapshot.applicant, !applicant.name.isEmpty {
                        Label {
                            Text(verbatim: applicant.name)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "person.crop.circle")
                        }
                        .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(model.coordinator.synthetic ? "nearby.review.consequence" : "nearby.review.liveConsequence")
                }
                if !consequenceKeys.isEmpty {
                    Section {
                        ForEach(Array(consequenceKeys.enumerated()), id: \.offset) { idx, key in
                            Label {
                                Text(LocalizedStringKey(key)).fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: idx == consequenceKeys.count - 1 ? "exclamationmark.triangle" : "info.circle")
                                    .foregroundStyle(idx == consequenceKeys.count - 1 ? CYColor.dangerText : Color.secondary)
                            }
                        }
                    }
                }
                Section {
                    confirmActionButton
                    Button("nearby.cancel") { model.cancel() }
                        .frame(maxWidth: .infinity)
                        .disabled(model.running)
                        .accessibilityIdentifier("nearby.cancel")
                }
            }
            .navigationTitle(appLocalized(String.LocalizationValue(stringLiteral: snapshot.action.key), locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { model.cancel() } label: { Label("action.close", systemImage: "xmark") }
                        .labelStyle(.iconOnly)
                        .disabled(model.running)
                }
            }
        }
        .interactiveDismissDisabled(model.running)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder private var confirmActionButton: some View {
        let button = Button(model.coordinator.synthetic ? "nearby.simulate" : "nearby.submitReviewed") {
            Task { await model.run { await model.confirmReviewed(snapshot) } }
        }
        .disabled(model.running || !model.coordinator.canSubmit)
        .accessibilityIdentifier("nearby.confirm")
        if isDestructiveAction {
            button.frame(maxWidth: .infinity).foregroundStyle(.red)
        } else {
            button.frame(maxWidth: .infinity).fontWeight(.semibold)
        }
    }
}

private extension View {
    /// N-RTEAMS (r10): wraps the receiver in a system `GroupBox` (system grouped fill, system corner radius).
    func groupBoxWrapped() -> some View { GroupBox { self } }
}
