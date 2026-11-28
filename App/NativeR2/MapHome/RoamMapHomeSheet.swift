import SwiftUI
import MapKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The map home's bottom panel content: search, 漫游 actions, the 附近 list and the cards pushed over it.
@MainActor struct RoamMapHomeSheet: View {
    @Bindable var model: RoamMapHomeModel
    let dependencies: RoamMapHomeDependencies

    var body: some View {
        NavigationStack(path: $model.path) {
            RoamMapHomeSheetRoot(model: model, dependencies: dependencies)
                .navigationDestination(for: RoamMapHomeRoute.self) { route in
                    destination(route)
                }
        }
        .cyFullScreenCover(isPresented: $model.showsLive) {
            NavigationStack {
                if let live = dependencies.liveDestination {
                    // MP P-32 live strip: the same entry read (activity cards + nearby teams) rides into the live map.
                    live()
                        .environment(\.roamLiveCards, RoamLiveCardsFeed(cards: model.cards(reader: dependencies.entryReader), teams: model.teams,
                                                                        event: dependencies.eventDestination, team: dependencies.nearbyTeamDestination))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button { model.showsLive = false } label: { Label("action.close", systemImage: "xmark") }
                                    .accessibilityIdentifier("roam.mapHome.live.close")
                            }
                        }
                }
            }
        }
        .cyFullScreenCover(isPresented: $model.showsCityBoard) {
            if let board = dependencies.cityBoardDestination {
                board()
                    .overlay(alignment: .topTrailing) {
                        Button { model.showsCityBoard = false } label: {
                            Label("action.close", systemImage: "xmark").labelStyle(.iconOnly)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .padding()
                        .accessibilityIdentifier("roam.mapHome.cityBoard.close")
                    }
            }
        }
        .cySheet(isPresented: $model.showsPassport) {
            dependencies.passportDestination?()
                .presentationDragIndicator(.visible)
        }
    }

    private func pin(_ id: String) -> RoamMapHomePin? {
        let center = (dependencies.entryReader?.searchArea ?? dependencies.roamReader.searchArea)?.coordinate
        return model.allPins(reader: dependencies.entryReader, center: center).first { $0.id == id }
    }

    @ViewBuilder private func destination(_ route: RoamMapHomeRoute) -> some View {
        switch route {
        case .pin(let id):
            if let pin = pin(id) {
                RoamMapHomePlaceCard(pin: pin, model: model, dependencies: dependencies)
            } else {
                ContentUnavailableView("nativeR2.mapHome.card.gone", systemImage: "mappin.slash")
            }
        case .placeDetail(let id):
            if let item = pin(id)?.roamItem, let make = dependencies.placeDetailDestination {
                make(item)
            } else {
                ContentUnavailableView("nativeR2.mapHome.card.gone", systemImage: "mappin.slash")
            }
        case .event(let target):
            if let make = dependencies.eventDestination {
                make(target)
            } else {
                ContentUnavailableView("nativeR2.mapHome.card.gone", systemImage: "calendar.badge.exclamationmark")
            }
        case .officialRoutes:
            if let reader = dependencies.officialRouteReader {
                RoamMapHomeRoutesList(reader: reader, model: model)
            }
        case .officialRoute(let id):
            if let reader = dependencies.officialRouteReader {
                RoamMapHomeRouteCard(reader: reader, routeID: id, model: model)
            }
        case .nearbyTeams:
            dependencies.nearbyTeamsDestination?()
        case .myTeams:
            dependencies.myTeamsDestination?()
        case .team(let teamID):
            dependencies.nearbyTeamDestination?(teamID)
        }
    }
}

/// The sheet's root list (Maps home sheet). Peek shows the search field only.
@MainActor private struct RoamMapHomeSheetRoot: View {
    @Bindable var model: RoamMapHomeModel
    let dependencies: RoamMapHomeDependencies
    @State private var location: RoamLocationSettingsSnapshot?
    /// MP `_entryLocating` / the 开启定位 fail branch: one locate at a time; a non-denied failure shows a retry line.
    @State private var locating = false
    @State private var locateFailed = false
    /// MP `unfinishedRoam` / `recoveryError`: the same local journal read the roam browser's 走起 tab uses.
    @State private var recoveryEntry = RoamHomeRecoveryEntry()
    /// MP `entryStripTab` ('near' | 'city'): the entry-peek tabs 附近活动 / 本城推荐.
    @State private var showsCityTab = false
    /// MP `onEntryCityPlaceTap` toast when the card's seeded place is not in the loaded read.
    @State private var cityOpenFailed = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    private var recoveryBanner: RoamHomeRecoveryBanner? { recoveryEntry.banner(reader: dependencies.experienceReader) }
    private var hasLiveDestination: Bool { dependencies.liveDestination != nil }

    private var area: RoamSearchArea? { dependencies.entryReader?.searchArea ?? dependencies.roamReader.searchArea }
    private var entryState: RoamEntryPeekState? { dependencies.entryReader.map { model.entry.visibleState(reader: $0) } }
    private var pins: [RoamMapHomePin] {
        let rows = model.listPins(from: model.allPins(reader: dependencies.entryReader, center: area?.coordinate))
        // MP 附近活动 strip lists the entry read's activities and places; teams live on the nearby page (ticket NO.02).
        guard model.category == .all else { return rows }
        return rows.filter { $0.category == .activities || $0.category == .places }
    }
    private var isSearching: Bool { !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var locationDenied: Bool {
        guard let location else { return false }
        return !location.servicesEnabled || location.authorization == .denied || location.authorization == .restricted
    }
    private var isLoading: Bool {
        entryState == .loading || model.placesPhase == .loading || (model.category == .routes && model.stopsPhase == .loading)
    }
    private var readFailed: Bool {
        entryState == .failed || model.placesPhase == .failed || (model.category == .routes && model.stopsPhase == .failed)
    }

    var body: some View {
        List {
            if isSearching {
                searchSections
            } else {
                // MP pages/roam/index order: location permission (需要定位才能开始漫游 · 去设置) and the
                // 上次漫游需要确认 card sit above the intro tickets; then the tickets; then 附近活动.
                if area == nil {
                    if locationDenied { locationSection } else { areaSection }
                }
                recoverySection
                roamSection
                nearbySection
                moreSection
            }
        }
        .listStyle(.insetGrouped)
        // mp-nav r3 (OWNER RULE 2): the 漫游 tab root carries the same large top-left title as the other four roots.
        .cyRootHeader(.roam)
        .searchable(text: $model.query, isPresented: $model.searchActive,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("nativeR2.mapHome.search.prompt"))
        .onChange(of: model.searchActive) { _, active in if active { model.detent = .large } }
        // P-037: submit searches the map's area and drops the results as pins on the home map (Maps' search).
        .onSubmit(of: .search) { submitSearch() }
        .onChange(of: model.query) { _, text in
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { model.clearSearch() }
        }
        .onChange(of: model.searchPhase) { _, phase in announceSearch(phase) }
        .refreshable { model.reloadGeneration += 1 }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { mapMenu }
        }
        .task { await syncLocation(automatic: true) }
        .onAppear {
            recoveryEntry.appear(reader: dependencies.experienceReader, foreground: scenePhase == .active, hasDestination: hasLiveDestination)
        }
        .onDisappear { recoveryEntry.disappear() }
        .onChange(of: scenePhase) { _, phase in
            recoveryEntry.setForeground(phase == .active, reader: dependencies.experienceReader, hasDestination: hasLiveDestination)
            // MP `_syncRoamPermission` on onShow: back from Settings, re-read the status (and locate if now allowed).
            if phase == .active { Task { await syncLocation(automatic: true) } }
        }
        // Closing the live cover can finish or leave a walk: re-read so 继续漫游 / 走起 is current.
        .onChange(of: model.showsLive) { _, showing in
            if !showing { recoveryEntry.reload(reader: dependencies.experienceReader, hasDestination: hasLiveDestination) }
        }
        .accessibilityIdentifier("roam.mapHome.sheet")
    }

    // MARK: Sections

    @ViewBuilder private var areaSection: some View {
        Section {
            ContentUnavailableView {
                Label("nativeR2.mapHome.area.required", systemImage: "mappin.and.ellipse")
            } description: {
                Text("nativeR2.mapHome.area.required.detail")
            } actions: {
                if dependencies.locateArea != nil {
                    Button { Task { await locate(automatic: false) } } label: {
                        CYBusyLabel(busy: locating) { Text("nativeR2.city.enableLocation") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(locating)
                    .accessibilityIdentifier("roam.mapHome.locate")
                }
                if let onChooseArea = dependencies.onChooseArea {
                    Button("roam.area.title", action: onChooseArea)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("roam.mapHome.area")
                }
            }
            if locateFailed {
                Text("nearby.locationFailed")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("roam.mapHome.locate.failed")
            }
        }
    }

    /// MP `goStart`: a guest signs in first (登录后继续) and the walk starts after sign-in; 暂不登录 leaves the page as is.
    private func startRoam() {
        let model = model
        if let gate = dependencies.signInToStart { gate { model.showsLive = true } } else { model.showsLive = true }
    }

    /// MP `_syncRoamPermission`: read the system status; when location is already allowed and no area is set yet,
    /// locate silently (MP `enableEntryLocation(true)`: no prompt, no error on failure).
    private func syncLocation(automatic: Bool) async {
        guard let settings = dependencies.locationSettings else { return }
        location = try? await settings.readStatus()
        guard area == nil, let status = location, status.servicesEnabled,
              status.authorization == .whenInUse || status.authorization == .always else { return }
        await locate(automatic: automatic)
    }

    /// MP `enableEntryLocation`: one fix becomes the search area; the map recentres and the entry read reloads
    /// through the area change. A tap that fails shows 没有取到定位，请重试; denied re-reads the status so the
    /// 需要定位 · 去设置 section replaces this one.
    private func locate(automatic: Bool) async {
        guard let locateArea = dependencies.locateArea, !locating else { return }
        locating = true
        defer { locating = false }
        do {
            _ = try await locateArea()
            locateFailed = false
        } catch is CancellationError {
            return
        } catch {
            if let settings = dependencies.locationSettings { location = try? await settings.readStatus() }
            if !automatic && !locationDenied { locateFailed = true }
        }
    }

    /// MP `cy-state-shell kind="no-permission"`: 需要定位才能开始漫游 + 去设置, at the top of the page.
    @ViewBuilder private var locationSection: some View {
        Section {
            ContentUnavailableView {
                Label("nativeR2.mapHome.location.denied", systemImage: "location.slash")
            } actions: {
                if let settings = dependencies.locationSettings {
                    Button("nativeR2.mapHome.location.openSettings") { Task { _ = await settings.openAppSettings() } }
                        .buttonStyle(.bordered)
                }
                if let onChooseArea = dependencies.onChooseArea {
                    Button("roam.area.title", action: onChooseArea)
                        .accessibilityIdentifier("roam.mapHome.area")
                }
            }
        }
    }

    /// MP `cy-error` 上次漫游需要确认 · 确认漫游记录 (`recoverRoam`), above the tickets.
    @ViewBuilder private var recoverySection: some View {
        if recoveryBanner == .needsCheck, let reader = dependencies.experienceReader {
            Section {
                Label(LocalizedStringKey(RoamHomeRecoveryBanner.needsCheck.titleKey), systemImage: "exclamationmark.circle")
                    .accessibilityIdentifier(RoamHomeRecoveryBanner.needsCheck.accessibilityID)
                NavigationLink { RoamRecoveryView(reader: reader) } label: { Text("roam.w208.recovery.check") }
                    .accessibilityIdentifier("roam.home.recovery.check")
            }
        }
    }

    @ViewBuilder private var roamSection: some View {
        Section {
            if dependencies.liveDestination != nil {
                // MP ticket NO.01: 继续漫游 when a walk is unfinished, else 走起 with 走到哪，雾散到哪 under it.
                let resumes = recoveryBanner == .recovered
                LabeledContent {
                    Button("nativeR2.mapHome.start.action", action: startRoam)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("roam.go")
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(resumes ? "roam.w208.recovery.continue" : "nativeR2.mapHome.start"))
                            if !resumes {
                                Text("roam.w208.intro.start.sub").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "figure.walk")
                    }
                }
            }
            if dependencies.nearbyTeamsDestination != nil {
                // MP ticket NO.02 (`openNearbyMap`): 打开地图 · 寻找组队 → subpackageRoam/nearby, with the live line
                // 附近 N 支队伍在组队 (`introTeamsLive`) only from a team read that returned rows. The native-only
                // 找队伍 filter row is gone: MP has three tickets, and the nearby page is where teams are found.
                Button { model.push(.nearbyTeams) } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("roam.w208.intro.map")
                            Text("roam.w208.intro.map.sub").font(.footnote).foregroundStyle(.secondary)
                            if !model.teams.isEmpty {
                                Text("roam.w208.intro.live \(model.teams.count)")
                                    .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                                    .accessibilityIdentifier("roam.home.intro.live")
                            }
                        }
                    } icon: {
                        Image(systemName: "map")
                    }
                }
                .accessibilityIdentifier("roam.home.intro.map")
            }
            if dependencies.myTeamsDestination != nil {
                // MP ticket NO.03: 我的队伍 with its sub line.
                Button { model.push(.myTeams) } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("nativeR2.mapHome.myTeams")
                            Text("roam.w208.intro.teams.sub").font(.footnote).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                }
                .accessibilityIdentifier("roam.mapHome.myTeams")
            }
        } header: {
            // MP `introTabs[0]` 开始漫游: the tickets group is named after the MP tab, not the 漫游 title it sits under.
            Text("nativeR2.mapHome.section.roam")
        }
    }

    @ViewBuilder private var nearbySection: some View {
        Section {
            if showsCityTab, let strip = cityStrip {
                // MP entry-peek city tab: the 本城推荐 cards (cy-roam-city-strip), same cards as the roam browser.
                RoamCityGuideCards(strip: strip, places: model.places, onOpen: openCityPlace)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                if cityOpenFailed {
                    Label("roam.cityGuide.openFailed", systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                nearbyRows
            }
        } header: {
            // MP entry-peek head: 附近活动 tab, then the 本城推荐 / `<城市> · N 处推荐` tab when a city strip exists.
            // This replaces the native r2 all/activities/places/routes/teams picker (MP structure wins).
            if let strip = cityStrip {
                Picker(selection: $showsCityTab) {
                    Text("roam.w208.entry.title").tag(false)
                    cityTabLabel(strip).tag(true)
                } label: { Text("roam.w208.entry.title") }
                .cyAdaptiveSegmented()
                .textCase(nil)
                .accessibilityIdentifier("city.roam.nearby")
            } else {
                // P29: the 附近活动 header states how many places / activities are nearby (OpenTable "331 restaurants").
                HStack {
                    Text("roam.w208.entry.title")
                    Spacer()
                    if !pins.isEmpty {
                        Text(pins.count, format: .number).monospacedDigit()
                            .accessibilityIdentifier("roam.mapHome.nearby.count")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("city.roam.nearby")
            }
        } footer: {
            if dependencies.roamReader.isOfflineExample {
                Label("nativeR2.mapHome.offline", systemImage: "wifi.slash")
            } else if !pins.isEmpty, readFailed {
                Label("nativeR2.mapHome.partialFailure", systemImage: "exclamationmark.triangle")
            }
        }
    }

    /// MP 附近活动 tab body: loaded rows, skeleton, sign-in / denied / cy-error / empty states.
    @ViewBuilder private var nearbyRows: some View {
        if !pins.isEmpty {
            ForEach(pins) { pin in RoamMapHomePinRow(pin: pin) }
        } else if isLoading {
            ProgressView { Text("nativeR2.mapHome.loading") }
                .frame(maxWidth: .infinity)
        } else if entryState == .login, model.places.isEmpty {
            ContentUnavailableView {
                Label("nativeR2.mapHome.signIn.title", systemImage: "person.crop.circle")
            } actions: {
                if let onOpenAccount = dependencies.onOpenAccount {
                    Button("nativeR2.mapHome.signIn", action: onOpenAccount).buttonStyle(.bordered)
                }
            }
        } else if entryState == .denied, model.places.isEmpty {
            ContentUnavailableView("nativeR2.mapHome.denied", systemImage: "lock")
        } else if readFailed {
            ContentUnavailableView {
                Label("nativeR2.mapHome.nearby.failed", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("action.retry") { model.reloadGeneration += 1 }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("roam.home.peek.refresh")
            }
        } else if area != nil {
            // MP entry-peek__state: 附近暂无活动 · 打开地图寻找附近活动, the tap opens subpackageRoam/nearby.
            ContentUnavailableView {
                Label("roam.w208.entry.empty", systemImage: "mappin.slash")
            } actions: {
                if dependencies.nearbyTeamsDestination != nil {
                    Button("roam.w208.entry.emptyHint") { model.push(.nearbyTeams) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("roam.mapHome.nearby.openMap")
                }
            }
        }
    }

    /// MP `stripFor(nearestCity || defaultCity())` at the sheet's area.
    private var cityStrip: RoamCityGuideStrip? {
        RoamCityGuideStrip.resolve(latitude: area?.coordinate.latitude, longitude: area?.coordinate.longitude)
    }

    /// MP `entryCityLabel`: `<城市> · N 处推荐` when the map faces a catalog city, else 本城推荐.
    private func cityTabLabel(_ strip: RoamCityGuideStrip) -> Text {
        strip.inCity ? Text("roam.cityGuide.tab.inCity \(appLocalized(String.LocalizationValue(strip.city.name), locale: locale)) \(strip.items.count)") : Text("roam.cityGuide.tab.default")
    }

    /// MP `onEntryCityPlaceTap`: open the loaded place that carries the card's seed tag (never matched by name).
    private func openCityPlace(_ item: RoamCityGuidePlace) {
        if let row = model.places.first(where: { $0.carriesCityGuideSeed(item.seed) }) {
            cityOpenFailed = false
            model.open(pinID: "place-" + String(row.id))
        } else {
            cityOpenFailed = true
        }
    }

    @ViewBuilder private var moreSection: some View {
        Section {
            if dependencies.passportDestination != nil {
                Button { model.showsPassport = true } label: {
                    Label("nativeR2.mapHome.passport", systemImage: "book.closed")
                }
                .accessibilityIdentifier("city.roam.passport")
            }
            if dependencies.officialRouteReader != nil {
                NavigationLink(value: RoamMapHomeRoute.officialRoutes) {
                    Label("nativeR2.mapHome.officialRoutes", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                .accessibilityIdentifier("roam.mapHome.officialRoutes")
            }
            if dependencies.cityBoardDestination != nil {
                Button { model.showsCityBoard = true } label: {
                    Label("nativeR2.mapHome.cityBoard", systemImage: "square.grid.3x3")
                }
                .accessibilityIdentifier("city.roam.board")
            }
        }
    }

    private var canSearchMap: Bool {
        guard let reader = dependencies.searchReader else { return false }
        return reader.isConfigured && area != nil
    }

    private func submitSearch() {
        guard canSearchMap else { model.detent = .medium; return }
        model.submitSearch(reader: dependencies.searchReader, area: area)
        model.detent = .medium
    }

    /// VoiceOver hears the result of a submitted search; the pins appear on the map at the same time.
    private func announceSearch(_ phase: RoamMapHomeLoadPhase) {
        switch phase {
        case .loaded:
            let count = model.searchPins(center: area?.coordinate).count
            let key = count == 0 ? "nativeR2.mapHome.search.announce.none" : "nativeR2.mapHome.search.announce.count"
            let format = appLocalized(String.LocalizationValue(key), locale: locale)
            AccessibilityNotification.Announcement(String(format: format, count)).post()
        case .failed:
            AccessibilityNotification.Announcement(appLocalized("nativeR2.mapHome.search.failed", locale: locale)).post()
        default:
            break
        }
    }

    @ViewBuilder private var searchSections: some View {
        Section {
            if pins.isEmpty, model.searchPhase == .loading {
                ProgressView { Text("nativeR2.mapHome.loading") }
                    .frame(maxWidth: .infinity)
            } else if pins.isEmpty, model.hasSubmittedSearch, model.searchPhase == .failed {
                ContentUnavailableView {
                    Label("nativeR2.mapHome.search.failed", systemImage: "wifi.slash")
                } actions: {
                    Button("action.retry") { submitSearch() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("roam.mapHome.search.retry")
                }
            } else if pins.isEmpty {
                ContentUnavailableView.search(text: model.query)
            } else {
                ForEach(pins) { pin in RoamMapHomePinRow(pin: pin) }
            }
        } footer: {
            if model.hasSubmittedSearch, model.searchPhase == .failed, !pins.isEmpty {
                Label("nativeR2.mapHome.search.failed", systemImage: "exclamationmark.triangle")
            }
        }
        if canSearchMap {
            Section {
                // Was a push of the search map explorer (a second map in the sheet). Now: results land as pins here.
                Button(action: submitSearch) {
                    LabeledContent {
                        if model.searchPhase == .loading, model.hasSubmittedSearch {
                            ProgressView()
                        } else {
                            Text(verbatim: model.query)
                        }
                    } label: {
                        Label("nativeR2.mapHome.searchMap", systemImage: "magnifyingglass")
                    }
                }
                .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("roam.search")
            } footer: {
                if model.hasSubmittedSearch, model.searchUnauthorized, let onOpenAccount = dependencies.onOpenAccount {
                    Button("nativeR2.mapHome.signIn", action: onOpenAccount)
                }
            }
        }
    }

    // MARK: Toolbar menus

    /// Maps' "Choose Map": map style, range, the City board mode and the search area.
    private var mapMenu: some View {
        Menu {
            Picker("nativeR2.mapHome.mapModes", selection: $model.satellite) {
                Label("nativeR2.mapHome.mapStyle.explore", systemImage: "map").tag(false)
                Label("nativeR2.mapHome.mapStyle.satellite", systemImage: "globe.asia.australia").tag(true)
            }
            .accessibilityIdentifier("roam.layer")
            Picker("nativeR2.mapHome.range", selection: $model.radius) {
                ForEach(RoamMapHomeModel.radiusOptions, id: \.self) { meters in
                    Text(Measurement(value: Double(meters) / 1000, unit: UnitLength.kilometers),
                         format: .measurement(width: .abbreviated)).tag(meters)
                }
            }
            .accessibilityIdentifier("roam.radius")
            if dependencies.cityBoardDestination != nil {
                Button { model.showsCityBoard = true } label: {
                    Label("nativeR2.mapHome.cityBoard", systemImage: "square.grid.3x3")
                }
            }
            if let onChooseArea = dependencies.onChooseArea {
                Button(action: onChooseArea) { Label("roam.area.title", systemImage: "mappin.and.ellipse") }
            }
        } label: {
            Label("nativeR2.mapHome.mapModes", systemImage: "square.stack.3d.up")
        }
        .accessibilityIdentifier("roam.mapHome.mapModes")
    }
}

/// One 附近 row: kind symbol, title, kind · distance (Maps' search result row).
@MainActor struct RoamMapHomePinRow: View {
    let pin: RoamMapHomePin
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// a11y-dt r3: one line each at normal sizes (Maps row); at AX sizes the title wraps to 2 lines and kind · distance stacks.
    private var lines: Int { dynamicTypeSize.isAccessibilitySize ? 2 : 1 }
    private var metaLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 4))
    }
    /// Walking minutes at about 80 m a minute (4.8 km/h), rounded up; nil past 3 km, where walking is not the hint.
    static func walkMinutes(_ meters: Double) -> Int? {
        guard meters >= 0, meters <= 3000 else { return nil }
        return max(1, Int((meters / 80).rounded(.up)))
    }

    var body: some View {
        NavigationLink(value: RoamMapHomeRoute.pin(pin.id)) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: pin.title).lineLimit(lines)
                    metaLayout {
                        Text(pin.kindKey)
                        if let meters = pin.distanceMeters {
                            if !dynamicTypeSize.isAccessibilitySize { Text(verbatim: "·").accessibilityHidden(true) }
                            Text(Measurement(value: meters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                            // P29: walk time next to the distance (about 80 m a minute), only within walking range.
                            if let minutes = RoamMapHomePinRow.walkMinutes(meters) {
                                if !dynamicTypeSize.isAccessibilitySize { Text(verbatim: "·").accessibilityHidden(true) }
                                Text("nativeR2.mapHome.walkMinutes \(minutes)")
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(lines)
                }
            } icon: {
                Image(systemName: pin.systemImage).foregroundStyle(pin.tint)
            }
        }
        .accessibilityIdentifier("city.nearby." + pin.id)
    }
}
