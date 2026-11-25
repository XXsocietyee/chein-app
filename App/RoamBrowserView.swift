import SwiftUI

/// Read-only roaming browser. Integration injects a live reader and an explicitly selected area.
/// The screen never prompts for location permission, reads GPS, follows the user, or starts a roam.
@MainActor
struct RoamBrowserView: View {
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.locale) private var locale
    @State private var trackedRoamStart = false
    let reader: any RoamReading
    var nearbyEventsReader: RoamNearbyEventsReader? = nil
    var nearbyPlayersReader: RoamNearbyPlayersReader? = nil
    var onChooseArea: (() -> Void)? = nil
    var onOpenAccount: (() -> Void)? = nil
    var experienceReader: (any RoamExperienceReading)? = nil
    var albumMetadataReader: RoamAlbumMetadataReader? = nil
    var tileMemoryReader: RoamTileMemoryReader? = nil
    var sessionFactReader: RoamSessionFactReader? = nil
    var cityDestination: (() -> AnyView)? = nil
    var territoryDestination: (() -> AnyView)? = nil
    var nearbyTeamsDestination: (() -> AnyView)? = nil
    var stampDestination: (() -> AnyView)? = nil
    var liveDestination: (() -> AnyView)? = nil
    var posterDestination: ((RoamNodeDetail) -> AnyView)? = nil
    var eventDestination: ((RoamEventDestination) -> AnyView)? = nil
    var nearbyEventDestination: ((RoamEventDestination) -> AnyView)? = nil
    var playerProfileDestination: ((Int) -> AnyView)? = nil
    var couponWalletDestination: (() -> AnyView)? = nil
    /// 官方线路 (preset routes) read; nil hides the intro card.
    var officialRouteReader: OfficialRouteReader? = nil
    var mediaScope: UUID = UUID()
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    /// Mini-program 开始漫游 / 漫游护照 home. All optional: hosts without them keep the plain browser.
    var entryReader: (any RoamEntryNearbyReading)? = nil
    var entryTeams: ((RoamSearchArea) async -> [NearbyTeam]?)? = nil
    var myTeamsDestination: (() -> AnyView)? = nil
    var nearbyTeamDestination: ((NearbyTeamID) -> AnyView)? = nil
    /// Passport tools: 那年今日 / 月度回顾 and the private 探索目标 / 时光胶囊 / 导出.
    var toolsReader: (any RoamPassportToolsReading)? = nil
    var passportToolsReader: (any RoamPassportToolsReading)? = nil
    var privateToolsReader: (any RoamPrivateToolsServing)? = nil
    /// Existing account-scoped topic detail; nil keeps unconfigured hosts unavailable.
    var anniversaryRouteDestination: ((String) -> AnyView)? = nil
    /// B03 开始漫游 permission notice: a static OS location-status reader (never prompts). nil hides the notice.
    var locationSettings: (any RoamLocationSettingsProviding)? = nil
    /// ROAM-3: opened as the 漫游护照与工具 sheet over the City map root. The sheet has no second map, GO or
    /// large 漫游 title: it opens on the passport tab under an inline sheet title with one ✕.
    var presentedAsSheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var appliedSheetDefaults = false
    @State private var homeTab: RoamHomeTab = .start
    @State private var celebrations = CYCelebrationCenter()
    @State private var entryCard: RoamNearbyEventsEntrySelection?
    @State private var recoveryEntry = RoamHomeRecoveryEntry()
    @Environment(\.scenePhase) private var recoveryScenePhase
    @StateObject private var shopVisitors = RoamShopVisitorsModel()
    private var recoveryReadOwner: RoamHomeRecoveryOwner? { experienceReader.map { RoamHomeRecoveryOwner(reader: $0) } }
    private var recoveryBanner: RoamHomeRecoveryBanner? { recoveryEntry.banner(reader: experienceReader) }
    @State private var layer: RoamLayer = .places
    @State private var radiusM = 3000
    @State private var placeFilter: RoamPlaceFilter = .all
    @State private var eventFilter: RoamEventFilter = .all
    @State private var showsMap = true
    @State private var query = ""
    @State private var items: [RoamMapItem] = []
    @State private var selected: RoamMapItem?
    @State private var loadedKey: RequestKey?
    @State private var readOwner = ManualMapReadTaskOwner()
    /// Fetch lifecycle (docs/release/state-machines/views.md); rows live in `items`, `loadedKey` guards a stale key.
    @State private var phase: CYPhase<Void, RoamScreenIssue> = .idle
    private var loading: Bool { phase.isLoading }
    private var issue: RoamScreenIssue? { phase.failure }
    /// Guard: only an in-flight fetch falls back to idle; a failure stays visible.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    @State private var generation = 0
    @State private var retainedRead = RoamRetainedRead()
    @State private var toolbarRoute: RoamBrowserToolbarRoute?
    @State private var peekCount: Int?
    @State private var introTeamsLive: Int?
    @State private var confirmingUnsavedExit = false
    @State private var roamToastMessage: String?
    /// ROAM-13: the 本城推荐 card being resolved to its server place (MP `onEntryCityPlaceTap`).
    @State private var cityGuideOpen: RoamCityGuideOpen?
    /// Map-first layout: map fills the screen, the segmented tabs / search / lists live in the bottom sheet.
    /// DEBUG screenshots can start expanded with `--design-detent medium|large`; Release always starts collapsed.
    private static var initialDetent: CYPanelDetent {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "--design-detent"), a.indices.contains(i + 1) {
            switch a[i + 1] { case "medium": return .medium; case "large": return .large; default: break }
        }
        #endif
        return .compact
    }
    private var mapMode: Bool { showsMap && cameraScope != nil && !presentedAsSheet }

    private var effectiveReader: any RoamReading {
        if layer == .events, let nearbyEventsReader { return nearbyEventsReader }
        if layer == .players, let nearbyPlayersReader { return nearbyPlayersReader }
        return reader
    }
    private var entryScope: RoamNearbyEventsEntryScope? {
        entryReader.flatMap { RoamNearbyEventsEntryScope(reader: $0) }
    }
    private func eventDetailDestination(for item: RoamMapItem) -> ((RoamEventDestination) -> AnyView)? {
        if case .event = item { return nearbyEventDestination ?? eventDestination }
        return eventDestination
    }
    private var radiusOptions: [Int] {
        nearbyPlayersReader != nil && layer == .players ? [1000, 3000] : [1000, 3000, 5000, 10000, 20000]
    }
    private var effectiveRadiusM: Int {
        nearbyPlayersReader != nil && layer == .players ? min(radiusM, RoamNearbyPlayersReadRoute.maximumRadius) : radiusM
    }
    private struct RequestKey: Hashable {
        let readerID: ObjectIdentifier
        let identity: RoamReadIdentity?
        let area: RoamSearchArea?
        let layer: RoamLayer
        let radius: Int
        let configured: Bool
    }
    private var requestKey: RequestKey {
        let reader = effectiveReader
        return RequestKey(readerID: ObjectIdentifier(reader), identity: reader.identity, area: reader.searchArea, layer: layer, radius: effectiveRadiusM, configured: reader.isConfigured)
    }
    private var cameraScope: RoamMapCameraScope? {
        let reader = effectiveReader
        return RoamMapCameraScope(readerID: ObjectIdentifier(reader), identity: reader.identity,
            area: reader.searchArea, isConfigured: reader.isConfigured)
    }
    private struct PresentationKey: Hashable {
        let request: RequestKey
        let generation: Int
        let query: String
        let placeFilter: RoamPlaceFilter
        let eventFilter: RoamEventFilter
    }
    private var presentationKey: PresentationKey {
        PresentationKey(request: requestKey, generation: generation, query: query,
            placeFilter: placeFilter, eventFilter: eventFilter)
    }
    private var visibleItems: [RoamMapItem] {
        guard loadedKey == requestKey, !loading, issue == nil else { return [] }
        return items.filter { item in
            switch item {
            case .place(let place): if !placeFilter.includes(place) { return false }
            case .event(let event): if eventFilter != .all && event.kind != eventFilter.rawValue { return false }
            default: break
            }
            return query.isEmpty || item.title.localizedCaseInsensitiveContains(query)
        }
    }
    private var retentionScope: RoamRetainedRead.Scope? {
        let reader = effectiveReader
        return .init(readerID: ObjectIdentifier(reader), identity: reader.identity, area: reader.searchArea,
              layer: layer, radius: effectiveRadiusM, query: query, placeFilter: placeFilter,
              eventFilter: eventFilter, isConfigured: reader.isConfigured)
    }
    private var readSnapshot: RoamRetainedRead.Snapshot? { retainedRead.snapshot(in: retentionScope) }
    private var retainedRows: [RoamMapItem] {
        guard let snapshot = readSnapshot, snapshot.isRetained else { return [] }
        return snapshot.items.filter { item in
            switch item {
            case .place(let place): if !placeFilter.includes(place) { return false }
            case .event(let event): if eventFilter != .all && event.kind != eventFilter.rawValue { return false }
            default: break
            }
            return query.isEmpty || item.title.localizedCaseInsensitiveContains(query)
        }
    }
    var body: some View {
        let reader = effectiveReader
        NavigationStack {
            Group {
                if mapMode {
                    results
                } else {
                    VStack(spacing: 0) {
                        RoamHomeTabPicker(selection: $homeTab).padding(.horizontal).padding(.top, 6)
                        if homeTab == .passport {
                            passportView
                        } else {
                            ZStack {
                                if !reader.isConfigured {
                                    statusWithStartHeader(.notConfigured)
                                } else if reader.identity == nil {
                                    statusWithStartHeader(.unauthorized)
                                } else if reader.searchArea == nil {
                                    statusWithStartHeader(.areaRequired)
                                } else {
                                    results
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .sheet(item: $entryCard) { selection in Group {
                RoamEntryActivitySheet(card: selection.card, eventDestination: nearbyEventDestination ?? eventDestination,
                    teamDestination: nearbyTeamDestination, readOnly: nearbyEventDestination != nil,
                    isCurrent: { selection.mayRemainOpen(in: entryScope) })
            }.cySheet(detents: [.large]) }
            .onChange(of: entryScope) { _, _ in entryCard = nil }
            .onChange(of: recoveryReadOwner) { _, _ in
                recoveryEntry.reload(reader: experienceReader, hasDestination: liveDestination != nil)
            }
            .onChange(of: liveDestination != nil) { _, _ in
                recoveryEntry.reload(reader: experienceReader, hasDestination: liveDestination != nil)
            }
            .onChange(of: homeTab) { _, tab in
                if tab == .start { recoveryEntry.reload(reader: experienceReader, hasDestination: liveDestination != nil) }
            }
            .onAppear {
                if presentedAsSheet && !appliedSheetDefaults { appliedSheetDefaults = true; homeTab = .passport }
                guard !trackedRoamStart else { return }
                trackedRoamStart = true
                MiniProgramAnalytics.track(analytics, "roam_start", bizType: "roam", pagePath: "/pages/roam/index")
            }
            .onChange(of: recoveryScenePhase) { _, phase in
                recoveryEntry.setForeground(phase == .active, reader: experienceReader, hasDestination: liveDestination != nil)
            }
            .navigationDestination(item: $recoveryEntry.target) { target in
                Group {
                    if recoveryEntry.matches(target, reader: experienceReader, hasDestination: liveDestination != nil), let liveDestination {
                        liveDestination()
                    } else {
                        CYEmptyState(systemImage: "arrow.clockwise", "roamEvent.changed")
                    }
                }
                .cyPushedChrome()
            }
            // verify-r1 2.5 / N-12: the same root header as the other tabs (large title on the left), not a centred one.
            // ROAM-3: as a sheet, the system inline sheet title + ✕ instead of a second large 漫游 root title.
            .modifier(RoamBrowserHeader(asSheet: presentedAsSheet, onClose: { dismiss() }))
            .toolbar(mapMode ? .hidden : .automatic, for: .navigationBar)
            .modifier(RoamSearchableUnlessMap(enabled: !mapMode, text: $query))
            .task(id: requestKey) {
                guard !Task.isCancelled else { return }
                readOwner.activate(); await load()
            }
            .onAppear {
                readOwner.activate()
                recoveryEntry.appear(reader: experienceReader, foreground: recoveryScenePhase == .active, hasDestination: liveDestination != nil)
            }
            .onDisappear {
                recoveryEntry.disappear()
                retainedRead.clear(); selected = nil; readOwner.deactivate(); generation += 1; settleLoading()
            }
            .onChange(of: requestKey) { _, _ in selected = nil }
            .onChange(of: query) { _, _ in selected = nil }
            .onChange(of: placeFilter) { _, _ in selected = nil }
            .onChange(of: eventFilter) { _, _ in selected = nil }
            .onChange(of: retentionScope) { _, scope in retainedRead.retainOnly(scope: scope) }
            .task(id: cityGuideOpen) { await resolveCityGuidePlace() }
            .sheet(item: $selected) { item in
                RoamItemDetailView(item: item, reader: reader, mediaScope: mediaScope, makeExternalMaps: makeExternalMaps, stampDestination: stampDestination, posterDestination: posterDestination, eventDestination: eventDetailDestination(for: item), playerProfileDestination: playerProfileDestination, couponWalletDestination: couponWalletDestination)
                    .cyDomainSheet(detents: [.half, .full])
            }
            .cyModalOverlay(isPresented: confirmingUnsavedExit) {
                PlayUnsavedEditModal(
                    onKeepEditing: { confirmingUnsavedExit = false },
                    onDiscard: {
                        confirmingUnsavedExit = false
                        selected = nil
                    }
                )
            }
            .cyToast(verbatimMessage: $roamToastMessage)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu { Label("roam.toolbar.more", systemImage: "ellipsis.circle") }
                }
            }
            .navigationDestination(item: $toolbarRoute) { route in
                Group {
                    switch route {
                    case .experience:
                        if let experienceReader {
                            RoamExperienceHubView(reader: experienceReader, albumMetadataReader: albumMetadataReader, tileMemoryReader: tileMemoryReader, sessionFactReader: sessionFactReader, stampDestination: stampDestination, liveDestination: liveDestination, toolsReader: passportToolsReader ?? toolsReader, privateToolsReader: privateToolsReader, anniversaryRouteDestination: anniversaryRouteDestination)
                        }
                    case .city: cityDestination?()
                    case .territory: territoryDestination?()
                    case .nearbyTeams: nearbyTeamsDestination?()
                    }
                }
                .cyPushedChrome()
            }
        }
        // Hosts the stamp slam (a stamp made in the pushed camera, or in the item sheet, which re-hosts the overlay).
        .cyCelebrations(celebrations)
    }
    private var passportView: some View {
        RoamHomePassportView(reader: experienceReader, albumMetadataReader: albumMetadataReader,
            stampDestination: stampDestination, liveDestination: liveDestination,
            toolsReader: passportToolsReader ?? toolsReader, discoverDestination: nearbyTeamsDestination,
            officialRouteReader: officialRouteReader,
            anniversaryRouteDestination: anniversaryRouteDestination,
            privateToolsReader: privateToolsReader,
            collectionObjectDestination: { AnyView(SessionObjectCardsView()) })
    }
    /// The ONE overflow menu: area, list/map display, account, passport tools, city, nearby teams, refresh.
    private func overflowMenu<L: View>(@ViewBuilder label: () -> L) -> some View {
        let reader = effectiveReader
        return Menu {
            if let onChooseArea {
                Button("roam.area.title", systemImage: "mappin.and.ellipse", action: onChooseArea)
                    .accessibilityIdentifier("roam.chooseArea")
            }
            if !presentedAsSheet {
                Button { showsMap.toggle() } label: {
                    Label(LocalizedStringKey(showsMap ? "roam.listOnly" : "roam.showMap"), systemImage: showsMap ? "list.bullet" : "map")
                }.accessibilityIdentifier("roam.display.toggle")
            }
            if let onOpenAccount {
                Button("tabBar.passport", systemImage: "book.closed", action: onOpenAccount)
                    .accessibilityIdentifier("roam.account.open")
            }
            if experienceReader != nil {
                Button { toolbarRoute = .experience } label: {
                    Label("roam.experience.title", systemImage: "book.closed")
                }.accessibilityIdentifier("roam.experience.open")
            }
            // Design hand-off r1 PL-16 (owner Q-A): one CITY home. N01 城市大富翁 (the territory board) is the CITY entry;
            // the older 城市经营 page (A10) is retired as a home and stays reachable from N01's 更多 menu.
            if territoryDestination != nil {
                Button { toolbarRoute = .territory } label: {
                    Label {
                        Text(verbatim: ChannelCopy.text("城市大富翁", "City Monopoly", locale: locale))
                    } icon: {
                        Image(systemName: "building.2")
                    }
                }
                .accessibilityIdentifier("roam.more.city")
            } else if cityDestination != nil {
                Button { toolbarRoute = .city } label: { Label("city.read.title", systemImage: "building.2") }
                    .accessibilityIdentifier("roam.more.city")
            }
            if nearbyTeamsDestination != nil {
                Button { toolbarRoute = .nearbyTeams } label: { Label("nearby.title", systemImage: "person.3") }
                    .accessibilityIdentifier("roam.more.nearbyTeams")
            }
            Button { startLoad() } label: { Label("action.retry", systemImage: "arrow.clockwise") }
                .disabled(loading || !reader.isConfigured || reader.identity == nil || reader.searchArea == nil)
                .accessibilityIdentifier("roam.refresh")
        } label: { label() }
        .accessibilityLabel(Text("roam.toolbar.more"))
        .accessibilityIdentifier("roam.more")
    }
    private var searchField: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            TextField("roam.search", text: $query).textFieldStyle(.plain).submitLabel(.search)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .accessibilityIdentifier("roam.search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(CYColor.textTertiary)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                    .buttonStyle(.plain).accessibilityLabel(Text("roam.search.clear"))
            }
        }
        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
        .background(Color.white.opacity(0.09), in: Capsule(style: .continuous))
        .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.sm)
    }
    /// Collapsed sheet line: "Nearby activities N" (em dash while the count is unknown).
    private func peekLine(count: Int?) -> some View {
        HStack(spacing: CYSpacing.sm) {
            Text(entryReader != nil ? "roam.w208.entry.title" : "roam.browse.header")
                .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
            Spacer(minLength: 0)
            Group { if let count { Text(count, format: .number) } else { Text(verbatim: "—").accessibilityLabel(Text("roam.peek.countUnknown")) } }
                .cyText(.bodyMedium, monospacedDigit: true).foregroundStyle(CYColor.textSecondary)
            Image(systemName: "chevron.up").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
        }
        .padding(.horizontal, CYSpacing.xl).frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roam.sheet.peek")
    }
    @ViewBuilder private var mapPanel: some View {
        let renderedKey = presentationKey
        let renderedItems = visibleItems
        VStack(spacing: 0) {
            RoamHomeTabPicker(selection: $homeTab).padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.sm)
            if homeTab == .passport {
                passportView
            } else {
                searchField
                resultsList(renderedKey: renderedKey, renderedItems: renderedItems)
            }
        }
    }
    private var hasStartHeader: Bool { nearbyTeamsDestination != nil || entryReader != nil || recoveryBanner != nil || locationSettings != nil }
    /// 开始漫游 tab body above the browser: intro cards, recovery notice and the 附近活动 peek.
    @ViewBuilder private var startHeader: some View {
        // Mini-program order: the permission shell sits above the intro cards.
        if let locationSettings { RoamHomeLocationNotice(provider: locationSettings) }
        if nearbyTeamsDestination != nil || liveDestination != nil {
            // MP intro: three tickets (NO.01–03). 官方路线 lives on the 漫游护照 tab as a play card (MP _loadOfficialRoutes).
            RoamHomeIntroCards(start: startDestination, nearby: nearbyTeamsDestination, myTeams: myTeamsDestination ?? nearbyTeamsDestination,
                               teamsLive: introTeamsLive)
        }
        if let recoveryBanner, let experienceReader {
            let rendered = recoveryEntry.revision
            RoamHomeRecoveryBannerView(banner: recoveryBanner, onContinue: liveDestination == nil ? nil : {
                recoveryEntry.continueToExistingDestination(reader: experienceReader, hasDestination: liveDestination != nil, rendered: rendered)
            }) {
                if let sessionFactReader { return AnyView(RoamRecoveryView(reader: sessionFactReader).id(sessionFactReader.scope)) }
                return AnyView(RoamRecoveryView(reader: experienceReader))
            }
        }
        if let entryReader {
            RoamEntryPeekView(reader: entryReader, teams: entryTeams, onSignIn: onOpenAccount, onOpenMap: nearbyTeamsDestination,
                onChooseArea: onChooseArea, onBeginRead: { entryCard = nil }, onOpenSelection: { entryCard = $0 }, onCount: { peekCount = $0 }, onTeamsLive: { introTeamsLive = $0 },
                cityStrip: RoamCityGuideStrip.resolve(latitude: entryReader.searchArea?.coordinate.latitude, longitude: entryReader.searchArea?.coordinate.longitude),
                cityPlaces: loadedPlaces,
                onOpenCityPlace: { cityGuideOpen = RoamCityGuideOpen(place: $0) },
                onOpen: { _ in })
        }
    }
    private func startDestination() -> AnyView {
        if let liveDestination { return liveDestination() }
        return AnyView(RoamPreflightRulesView())
    }
    @ViewBuilder private func statusWithStartHeader(_ issue: RoamScreenIssue) -> some View {
        if hasStartHeader {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    startHeader
                    RoamStatusView(issue: issue, onSignIn: onOpenAccount)
                }.padding()
            }
        } else {
            RoamStatusView(issue: issue, onSignIn: onOpenAccount)
        }
    }
    /// Browser controls as list rows under the 附近 section: area, layer, radius and the layer's filter.
    @ViewBuilder private var controls: some View {
        let reader = effectiveReader
        if reader.isOfflineExample {
            Label("roam.offlineExample", systemImage: "testtube.2")
                .cyText(.caption).foregroundStyle(CYColor.warningText).accessibilityIdentifier("roam.fixture.notice")
        }
        if let area = reader.searchArea {
            Label {
                if area.label.isEmpty { Text("roam.suppliedArea") } else { Text(verbatim: area.label) }
            } icon: { Image(systemName: "mappin.and.ellipse") }
        }
        let roamDistrict = reader.searchArea?.label ?? ""
        InGameChannelRowButton(
            scope: .roam(district: roamDistrict),
            titleKey: "ingame.channel.roam",
            subtitleKey: "ingame.channel.roamSubtitle",
            accessibilityID: "ingame.channel.roam.entry",
            reloadTrigger: roamDistrict
        )
        Picker("roam.layer", selection: $layer) {
            ForEach(RoamLayer.allCases, id: \.self) { value in
                Text(LocalizedStringKey("roam.layer." + String(value.rawValue))).tag(value)
            }
        }
        .accessibilityIdentifier("roam.layer")
        Picker("roam.radius", selection: Binding(get: { effectiveRadiusM }, set: { radiusM = $0 })) {
            ForEach(radiusOptions, id: \.self) { radius in
                Text(verbatim: "\(radius / 1000) km").tag(radius)
            }
        }
        .accessibilityIdentifier("roam.radius")
        if layer == .places {
            Picker("roam.placeFilter", selection: $placeFilter) {
                ForEach(RoamPlaceFilter.allCases, id: \.self) { value in
                    Text(LocalizedStringKey("roam.filter." + String(value.rawValue))).tag(value)
                }
            }.pickerStyle(.segmented).labelsHidden()
        } else if layer == .events {
            Picker("roam.eventFilter", selection: $eventFilter) {
                ForEach(RoamEventFilter.allCases, id: \.self) { value in
                    Text(LocalizedStringKey("roam.filter." + String(value.rawValue))).tag(value)
                }
            }.pickerStyle(.segmented).labelsHidden()
        }
    }
    private var results: some View {
        let renderedKey = presentationKey
        let renderedItems = visibleItems
        // Map-first: full-bleed map, glass area pill, the white GO circle, and the existing list
        // (intro cards, controls, rows) in a three-detent panel. List-only keeps the plain list.
        return Group {
            if mapMode, let scope = cameraScope {
                let count = entryReader != nil ? peekCount : (loadedKey == requestKey && !loading && issue == nil ? renderedItems.count : nil)
                CYMapScaffold(detent: Self.initialDetent, peek: AnyView(peekLine(count: count)), map: {
                    // Keeps its camera state through loading, errors and empty filters; pins follow visibleItems.
                    if reader.isOfflineExample { CYMapStreetGrid() } else { roamMap(scope: scope, key: renderedKey, items: renderedItems) }
                }, controls: {
                    // Title top-left; the ONE overflow menu top-right (area, list, account, passport tools, refresh).
                    HStack(alignment: .center) {
                        Text("roam.title").cyText(.pageTitle).foregroundStyle(.white)
                            .lineLimit(2).layoutPriority(1)
                            .shadow(color: .black.opacity(0.5), radius: 6).accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        overflowMenu { CYGlassLabel(systemImage: "ellipsis") }
                    }
                }, floating: {
                    // Mini-program layout: rules (info) · GO · open map. Three floating controls, no more.
                    HStack(spacing: CYSpacing.xxl) {
                        NavigationLink { RoamPreflightRulesView().cyPushedChrome() } label: { CYGlassLabel(systemImage: "info") }
                            .buttonStyle(.plain).accessibilityLabel(Text("roam.preflightRules.availability"))
                            .accessibilityIdentifier("roam.rules")
                        NavigationLink { startDestination().cyPushedChrome() } label: { CYGoLabel() }
                            .buttonStyle(CYGoPressStyle())
                            .accessibilityLabel(Text("roam.w208.intro.start"))   // ROAM-12: 走起, not a spelled-out "G O"
                            .accessibilitySortPriority(10)   // the one primary action is read before rules / open map
                            .accessibilityIdentifier("roam.go")
                        if let nearbyTeamsDestination {
                            NavigationLink { nearbyTeamsDestination().cyPushedChrome() } label: { CYGlassLabel(systemImage: "map") }
                                .buttonStyle(.plain).accessibilityLabel(Text("nearby.title"))
                                .accessibilityIdentifier("roam.openMap")
                        } else {
                            CYGlassLabel(systemImage: "map").opacity(0).accessibilityHidden(true)
                        }
                    }
                }, panel: { mapPanel })
            } else {
                resultsList(renderedKey: renderedKey, renderedItems: renderedItems)
            }
        }
    }
    private func roamMap(scope: RoamMapCameraScope, key: PresentationKey, items: [RoamMapItem]) -> some View {
        RoamMapView(area: scope.area, items: items, selectedID: selected?.id,
            interactionID: AnyHashable(key), fillsHeight: true, onSelect: { item in
            select(item, key: key, snapshot: items)
        }).id(scope)
        .modifier(RoamMapWeather(area: scope.area))
    }
    private func resultsList(renderedKey: PresentationKey, renderedItems: [RoamMapItem]) -> some View {
        List {
            // Mini-program order: intro tickets and 附近活动 first, then the nearby map browser.
            if hasStartHeader { Section { startHeader } }
            Section { controls } header: { Text("roam.browse.header") }
            if loading || loadedKey != requestKey {
                CYSkeleton().accessibilityIdentifier("roam.loading")
            } else if let issue {
                RoamStatusView(issue: issue, retry: { startLoad() }, onSignIn: onOpenAccount)
            } else if visibleItems.isEmpty {
                VStack(spacing: CYSpacing.sm) {
                    CYEmptyState(systemImage: "map", "roam.empty", actionTitle: "action.retry") { startLoad() }
                    Text(LocalizedStringKey(query.isEmpty && placeFilter == .all && eventFilter == .all ? "roam.emptyHint" : "roam.filteredEmptyHint"))
                        .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal, CYSpacing.xxl)
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("roam.empty")
            } else if showsMap && !visibleItems.contains(where: { $0.coordinate != nil }) {
                Label("roam.noCoordinates", systemImage: "mappin.slash")
                    .foregroundStyle(.secondary)
            }
            if let snapshot = readSnapshot {
                Section {
                    LabeledContent("roamRetained.readAt") {
                        Text(snapshot.readAt, format: .dateTime.year().month().day().hour().minute())
                            .fixedSize(horizontal: false, vertical: true)
                    }.accessibilityIdentifier("roamRetained.readAt")
                    if snapshot.isRetained {
                        Label("roamRetained.previous", systemImage: "clock.arrow.circlepath")
                            .fixedSize(horizontal: false, vertical: true)
                        Text("roamRetained.readOnly").cyText(.bodyCompact).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("roamRetained.notice")
                        ForEach(retainedRows) { item in
                            // Static rows have no gesture, detail link, map action or selection.
                            RoamItemRow(item: item, navigable: false)
                                .accessibilityHint(Text("roamRetained.readOnly"))
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("roamRetained.row.\(item.id)")
                        }
                    }
                }
            }
            ForEach(visibleItems) { item in
                Button {
                    select(item, key: renderedKey, snapshot: renderedItems)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        RoamItemRow(item: item, showsCurrentReadStatus: true)
                        RoamPlaceVisitorsLine(item: item, model: shopVisitors)
                    }
                }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("roam.row.\(item.id)")
            }
        }
        .modifier(RoamShopVisitorsLoad(items: visibleItems, model: shopVisitors))
        .modifier(RoamMapListStyle(plain: mapMode))
        .listRowBackground(Color.clear)
        .scrollContentBackground(.hidden)
        .background(mapMode ? cyMapPanelColor : CYColor.bgPage)
        .contentMargins(.bottom, mapMode ? 24 : 0, for: .scrollContent)
        .refreshable { await load() }
        .accessibilityIdentifier("roam.content")
    }
    // Both map members and ordinary rows resolve against the same current read.
    // Closures from a previous refresh/filter/session may not reopen stale detail.
    private func select(_ item: RoamMapItem, key: PresentationKey, snapshot: [RoamMapItem]) {
        let reader = effectiveReader
        guard reader.isConfigured, reader.identity != nil, reader.searchArea != nil,
              key == presentationKey, loadedKey == key.request,
              !loading, issue == nil, snapshot == visibleItems,
              visibleItems.contains(item) else { return }
        selected = item
    }
    private var loadedPlaces: [RoamPlace] {
        items.compactMap { if case .place(let place) = $0 { return place } else { return nil } }
    }
    /// MP `readStripPlace`: a loaded place with the exact seed tag first, then a wide public read
    /// (MP radius 100 km, Core cap 20 km) matched by the same tag, never by name. Failure = MP toast 这个地点暂时打不开，请重试.
    /// The app reads at the current search area (the MP reads at the catalog city centre).
    private func resolveCityGuidePlace() async {
        guard let request = cityGuideOpen else { return }
        defer { if cityGuideOpen == request { cityGuideOpen = nil } }
        if let row = loadedPlaces.first(where: { $0.carriesCityGuideSeed(request.place.seed) }) {
            selected = .place(row); return
        }
        let area = reader.searchArea
        // Core caps `/api/roam/pois` at 20 km (RoamService.validate); the MP asks for 100 km.
        let rows = try? await reader.roamPlaces(radiusM: 20_000)
        guard !Task.isCancelled, cityGuideOpen == request, reader.searchArea == area else { return }
        if let row = rows?.first(where: { $0.carriesCityGuideSeed(request.place.seed) }) {
            selected = .place(row)
        } else {
            roamToastMessage = appLocalized("roam.cityGuide.openFailed", locale: locale)
        }
    }
    private func startLoad() {
        selected = nil; loadedKey = nil; generation += 1
        readOwner.start { await performLoad() }
    }
    private func load() async {
        selected = nil; loadedKey = nil; generation += 1
        await readOwner.run { await performLoad() }
    }
    private func performLoad() async {
        let reader = effectiveReader
        generation += 1
        let operation = generation
        let key = requestKey
        let retainedTicket = retainedRead.begin(scope: retentionScope)
        selected = nil; items = []; phase = .idle; loadedKey = nil
        guard reader.isConfigured, reader.identity != nil, reader.searchArea != nil else { return }
        phase = .loading
        defer { if operation == generation { settleLoading() } }
        do {
            let result: [RoamMapItem]
            switch key.layer {
            case .places: result = try await reader.roamPlaces(radiusM: key.radius).map(RoamMapItem.place)
            case .routes: result = try await reader.roamRouteNodes(radiusM: key.radius).map(RoamMapItem.route)
            case .events: result = try await reader.roamEvents(radiusM: key.radius).items.map(RoamMapItem.event)
            case .players: result = try await reader.roamPlayers(radiusM: key.radius).map(RoamMapItem.player)
            }
            try Task.checkCancellation()
            guard operation == generation, key == requestKey else { return }
            items = RoamMapItem.unique(result); phase = .loaded(()); loadedKey = key
            if let retainedTicket { retainedRead.finish(retainedTicket, items: items, readAt: Date()) }
        } catch is CancellationError {
            if let retainedTicket { retainedRead.cancel(retainedTicket) }
        }
        catch {
            guard operation == generation, key == requestKey else { return }
            if let retainedTicket { retainedRead.fail(retainedTicket, error: error) }
            phase = .failed(RoamScreenIssue(error: error), retry: nil); loadedKey = key
        }
    }
}

struct RoamItemRow: View {
    let item: RoamMapItem
    var navigable = true
    // Explicit opt-in by the current authorized result list. Retained rows and
    // other callers cannot accidentally display old account facts as current.
    var showsCurrentReadStatus = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Photo-led row: generated category art stands in until the place carries a photo.
            CYCoverArt(seed: String(describing: item.id), symbol: item.symbol, showsDebugLabel: false)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                RoamTitle(item.title).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                Text(item.kindLabel).cyText(.caption).foregroundStyle(CYColor.textTertiary)
                if showsCurrentReadStatus, case .place(let place) = item {
                    RoamPlaceReadStatusLabel(status: place.readStatus).cyText(.meta)
                }
                if let address = item.address, !address.isEmpty { Text(verbatim: address).cyText(.bodyCompact) }
                if let distance = item.distance, distance >= 0, distance.isFinite {
                    RoamDistanceLabel(meters: distance)
                }
                if item.coordinate == nil { Label("roam.noCoordinates", systemImage: "mappin.slash").cyText(.meta) }
            }
            Spacer(minLength: 0)
            if navigable { Image(systemName: "chevron.right").foregroundStyle(CYColor.textTertiary).font(.caption) }
        }
        .padding(.vertical, 8).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Toolbar menu destinations; the menu cannot host NavigationLinks directly.
private enum RoamBrowserToolbarRoute: Hashable, Identifiable {
    case experience, city, territory, nearbyTeams
    var id: Self { self }
}

/// System `.searchable` only outside the map layout; on the map the sheet pins its own search field.
private struct RoamSearchableUnlessMap: ViewModifier {
    let enabled: Bool
    @Binding var text: String
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "roam.search") } else { content }
    }
}

/// ROAM-3: tab-root header on the page, inline sheet title + one ✕ cancellation item in the sheet.
private struct RoamBrowserHeader: ViewModifier {
    let asSheet: Bool
    let onClose: () -> Void
    @ViewBuilder func body(content: Content) -> some View {
        if asSheet {
            content
                .appNavigationTitle("roam.passportSheet.title").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onClose) { Label("action.close", systemImage: "xmark") }
                            .labelStyle(.iconOnly).accessibilityIdentifier("roam.passportSheet.close")
                    }
                }
        } else {
            content.cyRootHeader(.roam)
        }
    }
}

private struct RoamMapListStyle: ViewModifier {
    let plain: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if plain { content.listStyle(.plain) } else { content }
    }
}
