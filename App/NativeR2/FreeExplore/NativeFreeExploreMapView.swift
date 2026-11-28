import MapKit
import SwiftUI

/// Native r2 自由探索 play home (spec §5/§6, Apple Maps pattern): a full-screen MapKit `Map` with one `Annotation`
/// per store (done / next / locked), the stores joined in backend order by a `MapPolyline`, and a bottom sheet
/// (`.height(120)` / `.medium` / `.large`, background interaction on) whose first row is the next-stop card.
///
/// Same reads and writes as `FreeExplorationExperienceView`: the coordinator's `load()`, `loadFreeExplorationEnding()`
/// and the arrival service's `/api/play/arrive`. "Next" is local only: the first store in backend order that is
/// not done and not unavailable. 跳过 moves to the following one without a request; free explore has no
/// server-side order (`pages/play/index.wxml:614-617`), so nothing is skipped on the server.
@MainActor struct NativeFreeExploreMapView: View {
    @Bindable var model: PlayExperienceCoordinator
    let storeDestination: (Int) -> AnyView
    var rewardCollectionDestination: ((PlayRewardBadgeTarget) -> AnyView)? = nil
    var castConfig: CastConfig? = nil
    var castEnding: PlayWireValue = .null
    /// Policy-gated external maps (步行前往); nil shows the gated state, as the store page does.
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    var mediaScope = UUID()
    /// One-shot when-in-use location for 我已到达; the play host passes `RuntimeNativeLocationProvider`.
    var arrivalLocation: (any RoamDeviceLocationProviding)? = nil

    @State private var position: MapCameraPosition = .automatic
    @State private var mapSelection: Int?
    @State private var skipped: [Int] = []
    @State private var focusedStore: Int?
    @State private var chapterFilter: Int?
    @State private var showsSheet = false
    @State private var detent: PresentationDetent = .medium
    @State private var pendingStore: Int?
    @State private var selectedStore: Int?
    @State private var arrivalStore: Int?
    @State private var showChapterPicker = false
    /// Design pass roam (P4): the 已完成 (n) fold of the stop list.
    @State private var showsDoneStops = false
    @State private var showEmergencyHelp = false
    @State private var arrival: PlayArrivalService?
    /// Motion r1: the store path draws on when the map appears.
    @State private var draw = NativeR2DrawOn()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    /// P-070: foreground-only position for the distance to each store (never asks for permission, reads nothing
    /// from the network; the same observer city orientation uses, without a run so it never reads in the background).
    @StateObject private var location = CityOrientationLocationObserver()

    var body: some View {
        map
            .ignoresSafeArea(edges: .bottom)
            // MP maps set show-location="{{false}}": no locate-me button (fix-r11 N-r11-2).
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .toolbar { toolbar }
            .sheet(isPresented: $showsSheet, onDismiss: openPendingStore) { sheet.cySheetBackdropExempt() }
            .navigationDestination(item: $selectedStore) { id in storeDestination(id) }
            .onAppear {
                if arrival == nil { arrival = PlayArrivalService(runtime: model, location: arrivalLocation) }
                if selectedStore == nil { showsSheet = true }
                location.start()
                // Native r2 M4: Dynamic Island shows the session as free explore (next stop from the same snapshot).
                QuestLiveActivityCenter.shared.setPlayContext(mode: .explore, nextDistanceMeters: nextDistance)
            }
            .onDisappear {
                showsSheet = false; arrival?.cancel(); location.stop()
                QuestLiveActivityCenter.shared.clearPlayContext()
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { location.start() } }
            // P-070: the Dynamic Island and the next-stop card share the distance to the next store.
            .onChange(of: nextDistance) { _, meters in
                QuestLiveActivityCenter.shared.setPlayContext(mode: .explore, nextDistanceMeters: meters)
            }
            // P-070: entering the arrival radius of the next store pops an arrival island with 我已到达 up front.
            .onChange(of: nextInArrivalRange) { old, new in
                guard !old, new, let node = nextStore else { return }
                announceArrival(node)
            }
            .onChange(of: selectedStore) { _, id in
                // Back from a store page: the card returns to the first open store (the visited one may be done now).
                if id == nil { focusedStore = nil; showsSheet = true }
            }
            .onChange(of: mapSelection) { _, id in
                guard let id else { return }
                focusedStore = id
                if detent == .height(120) { detent = .medium }
            }
            .onChange(of: model.identity) { _, _ in reset() }
            .onChange(of: model.gameplayMode) { _, mode in if mode != nil && mode != .freeExploration { reset() } }
            .accessibilityIdentifier("playFree.overview")
    }

    // MARK: Stores

    private var snapshot: PlaySnapshot? { model.hasCurrentMediaSnapshot ? model.snapshot : nil }

    /// Backend order, never shuffled (`pages/play/index.wxml:618-619`).
    private var stores: [PlayNode] {
        guard let snapshot, let presentation = FreeExplorationPresentation(snapshot: snapshot) else { return [] }
        return presentation.stores.filter { chapterFilter == nil || $0.chapterID == chapterFilter }
    }

    private var nextStore: PlayNode? {
        guard let snapshot else { return nil }
        if let focusedStore, let node = stores.first(where: { $0.id == focusedStore }) { return node }
        let candidates = stores.filter { !snapshot.isDone($0) && !snapshot.isLocked($0) }
        return candidates.first { !skipped.contains($0.id) } ?? candidates.first
    }

    /// Metres from the last foreground fix to `node`, rounded to 10 m so the card does not jitter.
    private func distance(to node: PlayNode) -> Double? {
        guard let meters = location.distance(toLatitude: node.latitude, longitude: node.longitude) else { return nil }
        return (meters / 10).rounded() * 10
    }

    private var nextDistance: Double? { nextStore.flatMap { distance(to: $0) } }

    /// Same 50 m radius city orientation highlights; it only offers 我已到达, the server still decides.
    private var nextInArrivalRange: Bool {
        guard let nextDistance else { return false }
        return nextDistance <= PlayArrivalPolicy.stationHighlightMeters
    }

    private func displayName(_ node: PlayNode) -> String {
        if let name = node.name, !name.isEmpty { return name }
        return appLocalized("playFree.store.untitled", locale: locale)
    }

    private func distanceText(_ meters: Double) -> Text {
        Text(Measurement(value: meters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
    }

    private func announceArrival(_ node: PlayNode) {
        guard IslandCenter.isEnabled else {
            AccessibilityNotification.Announcement(appLocalized("nativeR2.freeExplore.map.arrival", locale: locale)
                                                   + " " + displayName(node)).post()
            return
        }
        let id = node.id
        let canArrive = arrival?.offer(for: id) != nil
        let action: IslandAction
        if canArrive {
            action = IslandAction(title: .key("playArrival.action"), systemImage: "location.fill", prominent: true) { arrivalStore = id }
        } else {
            action = IslandAction(title: .key("nativeR2.freeExplore.map.open"), systemImage: "storefront", prominent: true) { open(id) }
        }
        IslandCenter.shared.show(IslandItem(kind: .arrival, title: .key("nativeR2.freeExplore.map.arrival"),
                                            subtitle: .verbatim(displayName(node)), actions: [action],
                                            open: { if canArrive { arrivalStore = id } else { open(id) } },
                                            lifetime: .seconds(6), dedupeKey: "freeExplore.arrival", startsExpanded: true))
    }

    private enum StopState { case done, next, locked, open }

    private func state(of node: PlayNode, in snapshot: PlaySnapshot) -> StopState {
        if snapshot.isDone(node) { return .done }
        if node.id == nextStore?.id { return .next }
        if snapshot.isLocked(node) || snapshot.isStoryLocked(node) { return .locked }
        return .open
    }

    private static func coordinate(_ node: PlayNode) -> CLLocationCoordinate2D? {
        guard let latitude = node.latitude, let longitude = node.longitude, latitude != 0, longitude != 0,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: Map

    private struct MappedStop: Identifiable {
        let node: PlayNode
        let coordinate: CLLocationCoordinate2D
        var id: Int { node.id }
    }

    private var mappedStops: [MappedStop] {
        stores.compactMap { node in Self.coordinate(node).map { MappedStop(node: node, coordinate: $0) } }
    }

    private var map: some View {
        Map(position: $position, selection: $mapSelection) {
            UserAnnotation()
            if mappedStops.count > 1 {
                MapPolyline(coordinates: NativeR2RoutePath.prefix(mappedStops.map(\.coordinate), progress: draw.progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
            }
            if let snapshot {
                ForEach(mappedStops) { stop in
                    // P-066: the pin carries the store's name (untitled fallback) for the map label and VoiceOver.
                    Annotation(displayName(stop.node), coordinate: stop.coordinate, anchor: .center) {
                        stopPin(state(of: stop.node, in: snapshot), name: displayName(stop.node))
                            .accessibilityIdentifier("playFree.store.\(stop.node.id)")
                    }
                    .tag(stop.node.id)
                }
            }
        }
        .task(id: mappedStops.count) { await draw.run(reduceMotion: reduceMotion) }
    }

    /// `name` is set on the map, where the pin is the whole element; list rows already show the name.
    private func stopPin(_ state: StopState, font: Font = .title, name: String? = nil) -> some View {
        let symbol: String
        let color: Color
        switch state {
        case .done: symbol = "checkmark.circle.fill"; color = Color.green
        case .next: symbol = "location.circle.fill"; color = Color.accentColor
        case .locked: symbol = "lock.circle.fill"; color = Color.secondary
        case .open: symbol = "mappin.circle.fill"; color = Color.red
        }
        return Image(systemName: symbol)
            .font(font)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.white, color)
            .nativeR2SymbolReplace()
            .accessibilityLabel(name.map { Text(verbatim: $0 + ", ") + Text(LocalizedStringKey(Self.stateKey(state))) }
                                ?? Text(LocalizedStringKey(Self.stateKey(state))))
    }

    private static func stateKey(_ state: StopState) -> String {
        switch state {
        case .done: return "nativeR2.freeExplore.map.state.done"
        case .next: return "nativeR2.freeExplore.map.next"
        case .locked: return "playFree.story.locked"
        case .open: return "nativeR2.freeExplore.map.state.open"
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { Task { await model.load() } } label: { Label("playx.refresh", systemImage: "arrow.clockwise") }
                .disabled(!model.available || model.phase == .submitting || model.phase == .loading)
                .accessibilityIdentifier("playFree.refresh")
        }
        ToolbarItem(placement: .topBarTrailing) {
            // Mini-program mode 2 keeps 切换章节 in the tools layer.
            PlayToolsMenu(showsChapters: snapshot.map { !FreeExplorationStoryFacts(snapshot: $0).isPerkOnly && $0.result.chapters.count > 1 } == true,
                          showsEmergency: model.snapshot != nil,
                          openChapters: { showChapterPicker = true }, openEmergency: { showEmergencyHelp = true })
        }
    }

    // MARK: Sheet

    private var sheet: some View {
        NavigationStack {
            sheetList
                .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.height(120), .medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        .cySheet(item: arrivalItem) { item in
            if let arrival {
                NativeFreeExploreArrivalSheet(model: model, arrival: arrival, nodeID: item.id,
                                              onOpenStore: { open(item.id) })
            }
        }
        .cySheet(isPresented: $showEmergencyHelp) { PlayEmergencyHelpSheet() }
        .cySheet(isPresented: $showChapterPicker) {
            if let snapshot {
                PlayChapterPickerSheet(rows: PlayChapterPickRow.rows(snapshot), current: chapterFilter) { picked in
                    chapterFilter = picked; focusedStore = nil; skipped = []
                }
            }
        }
    }

    private struct ArrivalItem: Identifiable { let id: Int }
    private var arrivalItem: Binding<ArrivalItem?> {
        Binding(get: { arrivalStore.map(ArrivalItem.init(id:)) }, set: { arrivalStore = $0?.id })
    }

    private var sheetList: some View {
        List {
            if model.phase == .loading && model.snapshot == nil {
                Section { ProgressView("playx.loading").frame(maxWidth: .infinity) }
            }
            if let issue = model.issue { Section { PlayExperienceIssueView(issue: issue) } }
            if !model.available {
                ContentUnavailableView("playx.disabled.title", systemImage: "nosign", description: Text("playx.disabled"))
            }
            if let snapshot {
                if snapshot.availability == .registrationRequired {
                    Section { Label("playFree.registrationRequired", systemImage: "ticket") }
                } else if stores.isEmpty {
                    ContentUnavailableView("playFree.stores.empty", systemImage: "storefront")
                } else {
                    nextStopSection(snapshot)
                    progressSection(snapshot)
                    allStopsSection(snapshot)
                }
                rewardSection
                if model.unresolved {
                    Section {
                        Label(LocalizedStringKey(model.hasModeRecoveryBlock ? "playMode.recoveryBlocked" : "playFree.proof.pending"),
                              systemImage: "hourglass")
                    }
                }
                endingSection(snapshot)
            }
            NativeFreeExploreArchiveSections(model: model)
        }
        .listStyle(.insetGrouped)
        .refreshable { if model.available && model.phase != .submitting { await model.load() } }
    }

    // MARK: Next-stop card

    @ViewBuilder private func nextStopSection(_ snapshot: PlaySnapshot) -> some View {
        if let node = nextStore {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    // Design pass roam (P1): the distance to the next store leads, large and rolling (P2).
                    if let meters = distance(to: node) {
                        distanceText(meters)
                            .cyText(.dataXL, monospacedDigit: true)
                            .contentTransition(.numericText(value: meters))
                            .animation(reduceMotion ? nil : .default, value: meters)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .accessibilityIdentifier("nativeR2.freeExplore.next.distance")
                    }
                    FreeExplorationStoreName(name: node.name).font(.title3.weight(.semibold))
                    Text(LocalizedStringKey(FreeExplorationPresentation.state(of: node, in: snapshot).titleKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let hook = node.hookText, !hook.isEmpty {
                        Text(verbatim: hook).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if node.crowded == true {
                        Label("playx.merchant.crowd.queue", systemImage: "person.3")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("nativeR2.freeExplore.next")
                // P3: the one primary action comes first; 步行前往 / 跳过 sit under it, quieter.
                primaryAction(node)
                HStack {
                    NativeFreeExploreWalkButton(destination: .init(name: node.name ?? "", address: node.addressHidden == true ? nil : node.address,
                                                                   latitude: node.latitude, longitude: node.longitude),
                                                scope: mediaScope, makeModel: makeExternalMaps)
                    Button {
                        skip(node)
                    } label: {
                        Label("nativeR2.freeExplore.map.skip", systemImage: "forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(openStores(snapshot).count < 2)
                    .accessibilityIdentifier("nativeR2.freeExplore.skip")
                }
                .controlSize(.regular)
            } header: {
                Text("nativeR2.freeExplore.map.next")
            }
        } else if FreeExplorationPresentation(snapshot: snapshot)?.isFullyRedeemed == true {
            Section {
                Label("nativeR2.freeExplore.map.allDone", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(CYColor.successText)
            }
        }
    }

    @ViewBuilder private func primaryAction(_ node: PlayNode) -> some View {
        if arrival?.offer(for: node.id) != nil {
            Button { arrivalStore = node.id } label: {
                Label("playArrival.action", systemImage: "location.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("playArrival.action")
        } else {
            Button { open(node.id) } label: {
                Text("nativeR2.freeExplore.map.open").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("nativeR2.freeExplore.open")
        }
    }

    // MARK: Progress

    @ViewBuilder private func progressSection(_ snapshot: PlaySnapshot) -> some View {
        let facts = FreeExplorationStoryFacts(snapshot: snapshot)
        let presentation = FreeExplorationPresentation(snapshot: snapshot)
        Section {
            if let done = presentation?.redeemed, let total = presentation?.total {
                ProgressView(value: Double(done), total: Double(max(total, 1))) {
                    Text("nativeR2.freeExplore.map.progress")
                } currentValueLabel: {
                    Text(verbatim: "\(done)/\(total)").monospacedDigit()
                }
                .accessibilityIdentifier("playFree.redeemed.count")
            }
            if !facts.isPerkOnly, let unlocked = facts.storyUnlocked, let total = facts.storyTotal {
                LabeledContent("nativeR2.freeExplore.map.storyUnlocked") {
                    Text(verbatim: "\(unlocked)/\(total)").monospacedDigit()
                }
                .accessibilityIdentifier("playFree.story.unlocked.count")
            }
            if let expiry = snapshot.result.expiresAt { LabeledContent("play.expiresAt") { Text(verbatim: expiry) } }
        } footer: {
            if let note = snapshot.result.timeNote { Text(verbatim: note) }
        }
    }

    // MARK: All stops

    private func allStopsSection(_ snapshot: PlaySnapshot) -> some View {
        // Design pass roam (P4): what is left stays in view; finished stores fold into 已完成 (n).
        let pending = stores.filter { !snapshot.isDone($0) }
        let done = stores.filter { snapshot.isDone($0) }
        return Section {
            ForEach(pending) { node in stopRow(node, snapshot) }
            if !done.isEmpty {
                DisclosureGroup(isExpanded: $showsDoneStops) {
                    ForEach(done) { node in stopRow(node, snapshot) }
                } label: {
                    Label {
                        Text("design.roam.doneSection \(done.count)")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .accessibilityIdentifier("nativeR2.freeExplore.doneStops")
            }
        } header: {
            Text("nativeR2.freeExplore.map.allStops")
        } footer: {
            if stores.contains(where: { Self.coordinate($0) == nil }) {
                Text("nativeR2.freeExplore.map.noCoordinates")
            }
        }
    }

    @ViewBuilder private func stopRow(_ node: PlayNode, _ snapshot: PlaySnapshot) -> some View {
        HStack {
        Button { open(node.id) } label: {
            LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(LocalizedStringKey(FreeExplorationPresentation.state(of: node, in: snapshot).titleKey))
                    if let meters = distance(to: node) {
                        distanceText(meters).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        FreeExplorationStoreName(name: node.name)
                        if let title = node.gameTitle, !title.isEmpty {
                            Text(verbatim: title).font(.footnote).foregroundStyle(.secondary)
                        }
                        if let status = node.openStatus, !status.isEmpty {
                            Text(verbatim: status).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    stopPin(state(of: node, in: snapshot), font: .body)
                }
            }
        }
        .buttonStyle(.borderless)
        .tint(.primary)
        .accessibilityIdentifier("playFree.store.\(node.id)")
        // P-070: 我已到达 is a visible button on the row when the store offers it (was only a swipe action).
        if arrival?.offer(for: node.id) != nil {
            Button { arrivalStore = node.id } label: {
                Label("playArrival.action", systemImage: "location.fill").labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("playArrival.action.\(node.id)")
        }
        }
        .swipeActions(edge: .trailing) {
            if arrival?.offer(for: node.id) != nil {
                Button("playArrival.action") { arrivalStore = node.id }.tint(.accentColor)
            }
        }
        .contextMenu {
            Button("nativeR2.freeExplore.map.showOnMap", systemImage: "map") { focus(node) }
        }
    }

    // MARK: Rewards and ending

    @ViewBuilder private var rewardSection: some View {
        if let reward = model.reward {
            Section {
                if let drop = PlayRewardDrop.fromReward(reward) {
                    Label(drop.toastMessage(locale: locale), systemImage: "sparkles")
                        .accessibilityIdentifier("playFree.reward.drop")
                }
                if let dispatched = PlayRandomDispatchedTask.fromResponse(reward) {
                    Label(dispatched.revealTitle(locale: locale), systemImage: "shippingbox.fill")
                        .accessibilityIdentifier("playFree.reward.dispatchedTask")
                }
                PlayRewardBadgeRows(targets: PlayRewardBadgeTarget.targets(in: reward), destination: rewardCollectionDestination)
                    .id(PlayRewardBadgeTarget.targets(in: reward))
            }
        }
    }

    @ViewBuilder private func endingSection(_ snapshot: PlaySnapshot) -> some View {
        if !FreeExplorationStoryFacts(snapshot: snapshot).isPerkOnly,
           FreeExplorationPresentation(snapshot: snapshot)?.isFullyRedeemed == true {
            Section {
                ForEach(snapshot.visibleNodes.filter(snapshot.isDone)) { node in
                    Label { FreeExplorationStoreName(name: node.name) } icon: { Image(systemName: "checkmark.seal") }
                }
                Button("playFree.ending.read") { Task { await model.loadFreeExplorationEnding() } }
                if let ending = model.ending {
                    if !ending.opener.isEmpty { Text(verbatim: ending.opener) }
                    ForEach(Array(ending.fragments.enumerated()), id: \.offset) { _, fragment in
                        VStack(alignment: .leading) {
                            Text(verbatim: fragment.name).font(.headline)
                            if let text = fragment.text, !text.isEmpty { Text(verbatim: text) }
                        }
                    }
                    if let castConfig {
                        CastEndingSection(config: castConfig, result: CastEndingResult(raw: castEnding))
                    }
                }
            } header: {
                Text("playFree.redeemed.title")
            }
        }
    }

    // MARK: Actions

    private func openStores(_ snapshot: PlaySnapshot) -> [PlayNode] {
        stores.filter { !snapshot.isDone($0) && !snapshot.isLocked($0) }
    }

    private func skip(_ node: PlayNode) {
        guard let snapshot else { return }
        let candidates = openStores(snapshot)
        guard candidates.count > 1 else { return }
        if !skipped.contains(node.id) { skipped.append(node.id) }
        if candidates.allSatisfy({ skipped.contains($0.id) }) { skipped = [node.id] }
        let index = candidates.firstIndex(where: { $0.id == node.id }) ?? -1
        let following = candidates[(index + 1)...].first { !skipped.contains($0.id) } ?? candidates.first { !skipped.contains($0.id) }
        focusedStore = following?.id
        if let following { focus(following) }
    }

    private func focus(_ node: PlayNode) {
        focusedStore = node.id
        if let coordinate = Self.coordinate(node) {
            withAnimation(reduceMotion ? nil : .default) { position = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600)) }
        }
    }

    /// The store page is pushed under the map; the sheet steps aside first and comes back on return.
    private func open(_ id: Int) {
        guard model.hasCurrentMediaSnapshot, model.gameplayMode == .freeExploration else { return }
        arrivalStore = nil
        pendingStore = id
        showsSheet = false
    }

    private func openPendingStore() {
        guard let id = pendingStore else { return }
        pendingStore = nil
        selectedStore = id
    }

    private func reset() {
        selectedStore = nil; pendingStore = nil; arrivalStore = nil
        focusedStore = nil; skipped = []; chapterFilter = nil; mapSelection = nil
    }
}

/// 步行前往: the same policy-gated `PlatformExternalMaps` the store page uses, behind a reviewed confirmation.
@MainActor struct NativeFreeExploreWalkButton: View {
    let destination: PlatformMapDestination
    let scope: UUID
    var makeModel: (@MainActor () -> PlatformExternalMaps)? = nil
    @State private var model: PlatformExternalMaps?
    @State private var review = false
    var body: some View {
        Button { review = true } label: {
            Label("nativeR2.freeExplore.map.walk", systemImage: "figure.walk").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(model == nil || model?.state == .gated || model?.state == .opening)
        .accessibilityIdentifier("platform.map.open")
        .confirmationDialog("platform.map.review", isPresented: $review, titleVisibility: .visible) {
            Button("platform.map.open") {
                let selected = destination
                Task { await model?.openReviewedDestination(selected) }
            }
            Button("platform.cancel", role: .cancel) {}
        } message: {
            Text(verbatim: destination.copyText)
        }
        .onAppear {
            if model == nil { model = makeModel?() }
            model?.select(destination)
        }
        .onChange(of: destination) { _, next in review = false; model?.select(next) }
        .onChange(of: scope) { _, _ in review = false; model?.invalidate(); model = makeModel?(); model?.select(destination) }
        .onDisappear { review = false; model?.invalidate(); model = nil }
    }
}

/// Offline or expired chapters (`FreeExplorationArchiveCards`), as plain list sections.
@MainActor struct NativeFreeExploreArchiveSections: View {
    let model: PlayExperienceCoordinator
    @Environment(\.locale) private var locale
    var body: some View {
        if let archive = model.storyArchive {
            Section {
                if let unlocked = archive.storyUnlocked, let total = archive.storyTotal {
                    LabeledContent("nativeR2.freeExplore.map.storyUnlocked") {
                        Text(verbatim: "\(unlocked)/\(total)").monospacedDigit()
                    }
                }
                ForEach(archive.places) { place in
                    VStack(alignment: .leading, spacing: 6) {
                        FreeExplorationStoreName(name: place.name).font(.headline)
                        if let time = place.visitTimeText {
                            Text("playFree.story.visitedOn \(LocaleDisplay.civil(time, locale: locale))").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(Array(place.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(verbatim: paragraph)
                        }
                    }
                    .accessibilityIdentifier("playFree.archive.place.\(place.id)")
                }
                ForEach(archive.lockedPlaces) { place in
                    LabeledContent {
                        Label("playFree.story.locked", systemImage: "lock.fill")
                            .accessibilityLabel(Text("playFree.story.locked.a11y"))
                    } label: {
                        FreeExplorationStoreName(name: place.name)
                    }
                }
            } header: {
                Text(LocalizedStringKey(model.storyArchiveSource == .expired ? "playFree.archive.expired" : "playFree.archive.offline"))
            }
        }
    }
}
