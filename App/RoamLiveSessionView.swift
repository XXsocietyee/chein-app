import CoreLocation
import MapKit
import SwiftUI
import UIKit
import Combine
#if canImport(QuestifyCore)
import QuestifyCore
#endif

@MainActor private final class RoamLiveViewModel: ObservableObject {
    let controller: RoamLiveSessionController
    let finishedHistory: RoamFinishedHistoryReader
    @Published private var revision = 0
    /// Port of `utils/roam-sync-status.js`: 2 consecutive transport errors or offline path shows sync banner.
    private(set) var syncStatus = RoamSyncStatusTracker()
    private var lastObservedPresenceError = false
    /// Frozen when the walk finishes. The settle chip reads this; a later clear of places does not erase it.
    var finishAddress = RoamFinishAddress.Snapshot()
    init(_ controller: RoamLiveSessionController, offlineExample: Bool) {
        self.controller = controller
        finishedHistory = controller.makeFinishedHistoryReader(offlineExample: offlineExample)
        controller.onChange = { [weak self] in
            self?.captureFinishAddress()
            self?.updateSyncStatus()
            self?.revision &+= 1
        }
    }
    func updateSyncStatus() {
        let transportOffline = controller.presenceError || isTransportError(controller.placesReadError) || isTransportError(controller.error)
        if transportOffline {
            if !lastObservedPresenceError { syncStatus.recordOutcome(netFail: true) }
        } else if controller.phase == .active && controller.error == nil {
            syncStatus.recordOutcome(netFail: false, code: 200)
        }
        lastObservedPresenceError = controller.presenceError
    }
    func syncReachability(isOffline: Bool) {
        syncStatus.recordSystemConnectivity(isConnected: !isOffline)
        revision &+= 1
    }
    private func isTransportError(_ error: Error?) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return HTTPRequestRetrySupport.isTransientTransportError(urlError)
    }
    func captureFinishAddress() {
        guard controller.phase != .finished else { return }
        let next = RoamFinishAddress.snapshot(phase: controller.phase, places: controller.places, confirmedPOIIDs: controller.record?.confirmedPOIIDs ?? [])
        if next != finishAddress { finishAddress = next }
    }
}
@MainActor struct RoamLiveSessionView: View {
    @Environment(\.openURL) private var openURL
    let offlineExample: Bool
    let localHistoryReader: (any RoamExperienceReading)?
    let albumMetadataReader: RoamAlbumMetadataReader?
    /// Real map + fog behind the HUD. nil, or `PersonalFogFeature.liveRevealEnabled == false`, keeps the static backdrop.
    private(set) var fogMap: RoamLiveFogMap? = nil
    func withFogMap(_ value: RoamLiveFogMap?) -> Self { var copy = self; copy.fogMap = value; return copy }
    @StateObject private var browse: RoamPausedBrowsePresentation
    @StateObject private var model: RoamLiveViewModel
    /// MP shop strip BL-70 「N 人打过卡」 (`_loadShopStripVisitors`, sourceType 2 = registered merchant).
    @StateObject private var shopVisitors = RoamShopVisitorsModel()
    @Environment(\.socialRoamCapabilities) private var socialCapabilities
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// ROAM-9b: the system setting, or the MP in-roam 减少动态效果 (`PlayReducedMotionPreference`, pages/roam/index.js:880).
    private var reduceMotion: Bool { _ = playReducedMotion; return systemReduceMotion || PlayReducedMotionPreference.isEnabled(in: .standard) }
    @AppStorage(PlayReducedMotionPreference.storageKey) private var playReducedMotion = false
    /// ROAM-9b: MP `roam_fog_off` (stored true = fog layer off) and `cy_map_kind`.
    @AppStorage(RoamFogPreference.storageKey) private var fogOff = false
    @AppStorage(FreeMapKind.storageKey) private var mapKindRaw = FreeMapKind.black.rawValue
    @State private var showTools = false
    /// ROAM-9a: MP `_runners` (pages/roam/index.js:2827-2842); a failed read keeps the previous rows.
    @Environment(\.playRoamGapService) private var roamGap
    @State private var runners: [RoamNearbyRunner] = []
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    /// Location-purpose consent is asked once, on the first GO, by the inline card; the stored answer seeds this state and
    /// still feeds `owner.start(purposeAccepted:)`, which stays the source of truth.
    @AppStorage("roamLivePurposeAcceptedV1") private var storedPurposeAccepted = false
    @State private var purposeAccepted = false
    @State private var presenceAccepted = false
    @State private var confirmFinish = false
    @State private var showingLocationPriming = false
    @State private var locationPrimingAllowed = false
    /// ROAM-2: pages/roam `openCheckinView` after a confirmed visit → 城市贴纸 / 今日城市签.
    @State private var checkin: RoamCheckinTarget?
    /// MP 主题半屏 (`openTopicView`): a registered shop carrying a topic.
    @State private var topicShop: RoamLiveTopicShop?
    @State private var revealTick = 0
    @State private var revealToastShown = false
    @State private var revealToastTask: Task<Void, Never>?
    @State private var nearbyExpanded = true
    /// B04: once the walk is settled and archived the screen becomes the mini-program finish report.
    @State private var finishReport: RoamFinishReport?
    /// Start tapped, waiting for the controller; a refused start clears it.
    @State private var goCommitted = false
    /// P-040: the session list is a persistent system sheet over the map (Apple Maps / Fitness pattern).
    @State private var sessionSheetShown = false
    @State private var sessionDetent: PresentationDetent = .fraction(0.3)
    /// ROAM-r11-3: the place marker the player tapped.
    @State private var selectedPlaceID: Int?
    /// MP BL-02 (`utils/roam-idle.js`): display-only stationary detector; never touches time, distance or reveal.
    @State private var idle = RoamLiveIdleDetector()
    /// ROAM-r11-1: the official event carried in from 去漫游 (MP onLoad `eventId` / `missionCode`).
    @ObservedObject private var officialHandoff = RoamOfficialEventHandoff.shared
    @Environment(\.roamOfficialArrival) private var officialArrival
    @Environment(\.roamPresenceVisibility) private var roamPresenceVisibility
    @Environment(\.roamClearLocal) private var roamClearLocal
    @Environment(\.roamDiscoverDestinations) private var discoverDestinations
    init(controller: RoamLiveSessionController, offlineExample: Bool = false, localHistoryReader: (any RoamExperienceReading)? = nil, albumMetadataReader: RoamAlbumMetadataReader? = nil, browsePresentation: RoamPausedBrowsePresentation? = nil) {
        self.offlineExample = offlineExample; self.localHistoryReader = localHistoryReader; self.albumMetadataReader = albumMetadataReader
        _browse = StateObject(wrappedValue: browsePresentation ?? RoamPausedBrowsePresentation())
        _model = StateObject(wrappedValue: RoamLiveViewModel(controller, offlineExample: offlineExample))
    }
    private var owner: RoamLiveSessionController { model.controller }
    private func browseReader(for kind: RoamPausedBrowseKind) -> (any RoamExperienceReading)? {
        if kind == .album, let albumMetadataReader { return albumMetadataReader }
        return localHistoryReader
    }
    private var currentBrowseReader: (any RoamExperienceReading)? {
        browseReader(for: browse.target?.context.kind ?? .history)
    }
    /// ROAM-4 / P-040 (hand-off PL-20, MP B1 实时漫游地图): the map is the screen. A map fills it and the metrics,
    /// status, nearby and trace lists sit in one persistent system sheet with the Apple Maps detents.
    private var sessionContent: some View {
        liveMapGround
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                InGameChannelToolbarButton(
                    scope: .roam(district: fogMap?.area.label ?? "nearby"),
                    titleKey: "ingame.channel.roam",
                    accessibilityID: "ingame.channel.roamLive.entry",
                    reloadTrigger: fogMap?.area.label ?? ""
                )
            }
            // MP pbar 更多 (roam-more): one entry for 附近正在走的人 / 玩法说明 / 设置; the rules are a row inside it.
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTools = true } label: { Label("roamTools.more.title", systemImage: "ellipsis.circle") }
                    .accessibilityIdentifier("roam.live.tools")
            }
        }
        .onAppear { sessionSheetShown = true }
        .onDisappear { sessionSheetShown = false }
        .sheet(isPresented: $sessionSheetShown) { sessionSheet }
        .task(id: runnersReadKey) { await readRunners() }
        .cyPageTitle("roam.experience.live")
    }
    /// The persistent sheet. Every other presentation of the session hangs off it: the view presenting this sheet
    /// cannot present a second one, the sheet can.
    private var sessionSheet: some View {
        NavigationStack {
            sessionList
                // Mini-program pbar: one main control (start / pause / continue) with 结束 beside it.
                .safeAreaInset(edge: .bottom) { actionBar }
                .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.fraction(0.3), .medium, .large], selection: $sessionDetent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        // ROAM-r11-7: 首次发现商家 card after the first visit to a shop.
        .sheet(item: firstDiscoveryBinding) { place in
            if let discoverDestinations { RoamFirstDiscoverySheet(place: place, destinations: discoverDestinations) }
        }
        .sheet(isPresented: $showTools) {
            RoamSessionToolsSheetView(runners: runners, presenceEnabled: owner.presenceEnabled, ownExplorePercent: owner.explorationPercent,
                                      fogOn: fogOnBinding, mapKind: mapKindBinding, reduceMotion: reducedMotionBinding,
                                      onSetPresence: presenceSwitch, onClearLocal: roamClearLocal)
        }
        .sheet(isPresented: $showingLocationPriming, onDismiss: {
            guard locationPrimingAllowed else { return }
            locationPrimingAllowed = false
            Task {
                await SessionOfflineSyncModel.shared.performWriteOptIn(
                    environmentSession: offlineWriteSession.session,
                    routes: ["/api/roam/reveal", "/api/compliance/consents"]
                ) {
                    await owner.start(purposeAccepted: purposeAccepted, presenceAccepted: presenceAccepted)
                }
            }
        }) { Group {
            CYPermissionPrimerScreen(kind: .location, onPrimary: {
                CYPermissionSystemPrompt.notePrimed(.location)
                locationPrimingAllowed = true
                showingLocationPriming = false
            }, onSecondary: { showingLocationPriming = false })
        }.cySheet(detents: [.large]) }
        // Was the custom `PlayAreaRoamFinishModal`; same copy, same identifier, system dialog.
        .confirmationDialog(Text(verbatim: PlayAreaPopupCopy.text("结束本次漫游?", "End this roam?", locale: locale)),
                            isPresented: $confirmFinish, titleVisibility: .visible) {
            Button(role: .destructive) {
                confirmFinish = false
                Task { await owner.finish() }
            } label: {
                Text(verbatim: PlayAreaPopupCopy.text("结束漫游", "End roam", locale: locale))
            }
            .accessibilityIdentifier("roam.live.finish.confirm")
            Button(role: .cancel) { confirmFinish = false } label: {
                Text(verbatim: PlayAreaPopupCopy.text("取消", "Cancel", locale: locale))
            }
        } message: {
            Text(verbatim: PlayAreaPopupCopy.text(
                "足迹和探店都会保存,结算后可领足迹卡。本次漫游立即结算,结束后不能继续这一次漫游。",
                "Your footprints and shop visits are saved. After settlement you can collect the footprint card. This roam settles now and can't be continued.",
                locale: locale))
        }
        .sheet(item: $checkin) { target in Group { RoamCheckinSheet(target: target) }.cySheet(detents: [.large]) }
        .sheet(item: $topicShop) { target in
            RoamLiveTopicSheet(target: target, service: roamGap, topicDestination: discoverDestinations?.topic)
        }
        .background {
            if let target = browse.target {
                RoamPausedBrowseSheetOwner(presentation: browse, target: target,
                    owner: owner, reader: browseReader(for: target.context.kind)).id(target.id)
            }
        }
    }
    private var fogOnBinding: Binding<Bool> {
        Binding(get: { !fogOff }, set: { fogOff = RoamFogPreference.setFogOff(!$0, in: .standard) })
    }
    private var mapKindBinding: Binding<FreeMapKind> {
        Binding(get: { FreeMapKind(rawValue: mapKindRaw) ?? .black },
                set: { kind in _ = FreeMapKind.save(kind, in: .standard); mapKindRaw = kind.rawValue })
    }
    private var reducedMotionBinding: Binding<Bool> {
        Binding(get: { _ = playReducedMotion; return PlayReducedMotionPreference.isEnabled(in: .standard) },
                set: { on in PlayReducedMotionPreference.set(on, in: .standard); playReducedMotion = on })
    }
    /// MP `_fetchRunners` runs only while `presenceVisible` and walking; off clears the rows (`_clearNearbyRunners`).
    private var runnersReadKey: Bool { owner.presenceEnabled && owner.phase == .active && roamGap != nil }
    private func readRunners() async {
        guard runnersReadKey, let roamGap else { runners = []; return }
        while !Task.isCancelled {
            // MP sends the GCJ-02 player point with radius ROAM_POI_RADIUS_M (3000), at most every RUNNERS_MS (45 s).
            if let fix = owner.lastFix, let point = try? RuntimeLocationProjection.gcj02(fix) {
                let reply = await roamGap.fetchNearbyRunners(latitude: point.coordinate.latitude,
                                                             longitude: point.coordinate.longitude, radius: 3000)
                guard !Task.isCancelled else { return }
                // Not ok: keep the previous batch. Ok with no one: an empty batch still lands.
                if case .ok(let data, _) = reply {
                    if case .array(let rows) = data { runners = RoamNearbyRunner.normalized(rows) } else { runners = [] }
                }
            }
            try? await Task.sleep(nanoseconds: 45_000_000_000)
        }
    }
    /// Map ground (static fog backdrop when the live reveal is off).
    @ViewBuilder private var liveMapGround: some View {
        if PersonalFogFeature.liveRevealEnabled, let fogMap {
            RoamFogMapView(area: fogMap.area, items: fogMap.items, fillsHeight: true, fog: fogMap.presentation,
                           reveal: fogMap.reveal, enabled: PersonalFogFeature.liveRevealEnabled && !fogOff,
                           onBaked: fogMap.onBaked, onSelect: { _ in })
                .ignoresSafeArea()
        } else {
            // ROAM-r11-3: the session's nearby places as markers tinted by node level (普通 / 精选 / 官方合作 / 主题路线),
            // independent of the fog flag. Tapping one opens the 附近 list. MP pages/roam/index.wxml:301-433,
            // index.js:2575 (`buildNodeLevelMarkerStyle`), node-level-style.js.
            Map(initialPosition: .userLocation(fallback: .automatic), selection: $selectedPlaceID) {
                UserAnnotation()
                ForEach(owner.places.filter { $0.coordinate != nil }) { place in
                    if let point = place.coordinate, let photo = RoamLivePhotoPin.url(for: place) {
                        // ROAM-r11-3: a participating shop with a cover is a photo pin (MP photo-pins.js `pinPhoto`,
                        // `isParticipating`); the cover loads through the media allowlist.
                        Annotation(place.name.isEmpty ? appLocalized("roam.unnamed", locale: locale) : place.name,
                                   coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)) {
                            RoamLivePhotoPin(url: photo, tint: RoamLivePlaceLevel.tint(place.nodeLevel))
                        }
                        .tag(place.id)
                    } else if let point = place.coordinate {
                        Marker(place.name.isEmpty ? appLocalized("roam.unnamed", locale: locale) : place.name,
                               systemImage: RoamLivePlaceLevel.symbol(place.nodeLevel),
                               coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
                            .tint(RoamLivePlaceLevel.tint(place.nodeLevel))
                            .tag(place.id)
                    }
                }
            }
                // MP maps set show-location="{{false}}": no locate-me button (fix-r11 N-r11-2). Compass + scale stay.
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onChange(of: selectedPlaceID) { _, id in
                    guard id != nil else { return }
                    nearbyExpanded = true
                    if sessionDetent == .fraction(0.3) { sessionDetent = .medium }
                }
                .accessibilityIdentifier("roam.live.map")
        }
    }
    private var firstDiscoveryBinding: Binding<RoamPlace?> {
        Binding(get: { discoverDestinations == nil ? nil : owner.firstShopDiscovery },
                set: { if $0 == nil, owner.firstShopDiscovery != nil { owner.consumeFirstShopDiscovery() } })
    }
    /// ROAM-r11-5: the server-confirmed presence change also switches this walk's presence reports.
    private var presenceSwitch: (@MainActor (Bool) async -> Bool?)? {
        guard let roamPresenceVisibility, [.active, .paused].contains(owner.phase), owner.presenceAvailable else { return nil }
        return { visible in
            let saved = await roamPresenceVisibility(owner.record?.sessionID, visible)
            if let saved {
                owner.setPresenceSharing(saved)
                if !saved { runners = [] }
            }
            return saved
        }
    }
    /// ROAM-r11-1: MP 官方活动 · 到达验证 overlay, shown only in an event context.
    @ViewBuilder private var officialArrivalSection: some View {
        if let deps = officialArrival, let target = officialHandoff.target {
            RoamOfficialArrivalSection(deps: deps, target: target, sessionID: owner.record?.sessionID, fix: owner.lastFix,
                                       finished: owner.phase == .finished,
                                       explored: (owner.record?.distanceMeters ?? 0) > 0 || !(owner.record?.confirmedPOIIDs.isEmpty ?? true),
                                       onClose: { officialHandoff.clear() })
        }
    }
    private var sessionList: some View {
        List {
            if owner.phase != .unavailable { hud }
            officialArrivalSection
            if offlineExample { RoamExperienceNotice(offline: true) }
            if model.syncStatus.isOffline {
                Section {
                    CYStatusOfflineBanner(
                        messageKey: RoamSyncStatusTracker.offlineKey,
                        serious: true,
                        onRetry: {
                            if owner.canRetryNearbyRead {
                                Task { await owner.retryNearbyRead() }
                            }
                        }
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            // Mini-program pcard (goal line, then 用时 / 地盘 / 距离): the HUD now sits over the map (ROAM-4).
            if owner.phase == .unavailable {
                Section {
                    Label("roam.live.notApproved", systemImage: "lock.shield")
                    Text("roam.live.notApprovedHint").cyText(.body).foregroundStyle(.secondary)
                }
            } else {
                status
                if let medals = RoamFinishedMedalsPresentation(controller: owner) {
                    RoamFinishedMedalsSection(presentation: medals)
                }
                if let story = RoamFinishedStoryPresentation(controller: owner) {
                    RoamFinishedStorySection(presentation: story)
                }
                if let track = owner.finishedRouteTrack {
                    RoamLiveRouteOverviewSection(track: track, paused: false, finished: true)
                }
                if owner.canContinueUnstartedRoam {
                    Section {
                        Button("roam.unstarted.continue", systemImage: "arrow.uturn.backward") { owner.continueUnstartedRoam() }
                            .accessibilityIdentifier("roam.unstarted.continue")
                    }
                }
                if owner.phase == .finished, let saved = owner.completedHistory, model.finishedHistory.identity != nil {
                    Section("roam.finishedHistory.title") {
                        NavigationLink {
                            RoamHistoryDetailView(reader: model.finishedHistory, timestamp: saved.timestamp)
                        } label: {
                            Label("roam.finishedHistory.thisWalk", systemImage: "book.closed")
                        }.accessibilityIdentifier("roam.finishedHistory.record.open")
                        NavigationLink {
                            RoamHistoryView(reader: model.finishedHistory)
                        } label: {
                            Label("roam.experience.history", systemImage: "clock.arrow.circlepath")
                        }.accessibilityIdentifier("roam.finishedHistory.history.open")
                    }
                }
                if [.ready, .locationDenied, .paused].contains(owner.phase) {
                    Section {
                        if !purposeAccepted { consentCard }
                        if owner.phase == .locationDenied {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("roam.poi.location.denied.title", systemImage: "location.slash").cyText(.bodyMedium)
                                Text("roam.poi.location.denied.message2").cyText(.bodyCompact).foregroundStyle(.secondary)
                                Button("roam.poi.location.openSettings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                }.frame(minHeight: 44).accessibilityIdentifier("roam.live.openSettings")
                                    .accessibilityLabel(Text("roam.poi.location.openSettings"))
                                    .accessibilityValue(Text("roam.poi.location.denied.title"))
                                    .accessibilityHint(Text("roam.poi.location.denied.message2"))
                            }.accessibilityIdentifier("roam.live.locationDenied")
                        }
                        if owner.presenceAvailable {
                            Toggle("roam.live.presenceConsent", isOn: $presenceAccepted).tint(.green)
                        }
                    } footer: {
                        // Disclosure of what nearby players see; kept because it is a consent.
                        if owner.presenceAvailable { Text("roam.live.presencePrivacy") }
                    }
                }
                if owner.phase == .active {
                    if owner.continuesInBackground {
                        // OWN-D-07: say plainly that location keeps running after Home, and how to stop it.
                        Section {
                            Label("roam.live.backgroundLocationOn", systemImage: "location.fill")
                                .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                            Text("roam.live.backgroundLocationHint").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("roam.live.backgroundLocation")
                    }
                    Section {
                        Label(owner.presenceEnabled ? "roam.live.presenceOn" : "roam.live.presenceOff",
                              systemImage: owner.presenceEnabled ? "person.wave.2" : "person.crop.circle")
                        if owner.presenceError { Text("roam.live.presenceFailed").foregroundStyle(.secondary) }
                    }
                    if let memory = owner.placeMemory {
                        RoamPlaceMemorySection(placeName: memory.placeName, text: memory.text) {
                            owner.dismissPlaceMemory(id: memory.id)
                        }
                        .onAppear {
                            MiniProgramAnalytics.track(analytics, "roam_poi_meaning_shown", bizType: "roam", pagePath: "/pages/roam/index")
                        }
                    }
                    nearby
                    trace
                }
                if owner.phase == .paused { trace }
                pauseAndBrowse
                if owner.phase == .recoveryRequired {
                    Section {
                        Text("roam.live.recoveryHint")
                        Button("roam.live.recover", systemImage: "arrow.clockwise") {
                            Task {
                                await SessionOfflineSyncModel.shared.performWriteOptIn(
                                    environmentSession: offlineWriteSession.session,
                                    routes: ["/api/roam/reveal", "/api/compliance/consents"]
                                ) {
                                    if owner.record == nil { owner.prepare() }
                                    await owner.recover()
                                }
                            }
                        }
                            .disabled(owner.busy).accessibilityIdentifier("roam.live.recover")
                    }
                }
            }
            CYScreenOfflineWriteSection(
                routes: ["/api/roam/reveal", "/api/compliance/consents"],
                session: offlineWriteSession.session
            )
            if let error = owner.error {
                Section {
                    Label { Text(errorText(error)) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CYColor.warningText) }
                        .accessibilityIdentifier("roam.live.error")
                }
            }
        }
        .listStyle(.insetGrouped)
        // Identify the list only; the inset actions keep their own accessible identities.
        // As on the hub (73a06a74f), iOS 27 exposes this screen-level identifier only on an accessibility container.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roam.live.session")
    }
    /// First GO only: one inline card instead of a toggle the player must find first. Agreeing records the consent and
    /// starts the roam through the same path as the Go button (location priming still comes first when undecided).
    private var consentCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label("roam.live.consentCard.title", systemImage: "location.fill").cyText(.bodyMedium)
            Text("roam.live.consentCard.body").cyText(.bodyCompact).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // PL-20 / PL-25 (HIG Privacy): one button that leads to the system location prompt.
            Button {
                purposeAccepted = true; storedPurposeAccepted = true
                if !owner.busy, owner.record == nil { beginStart() }
            } label: {
                Text("primer.location.allow", tableName: "DesignR1").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(owner.busy)
            .accessibilityIdentifier("roam.live.consent")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roam.live.consentCard")
    }
    private func beginStart() {
        if CLLocationManager().authorizationStatus == .notDetermined { showingLocationPriming = true; return }
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/roam/reveal", "/api/compliance/consents"]
            ) {
                await owner.start(purposeAccepted: purposeAccepted, presenceAccepted: presenceAccepted)
            }
        }
    }
    private var sessionObservers: some View {
        // A ZStack keeps one identity: swapping in the report must not run the session's onDisappear (pause).
        ZStack {
            if let finishReport {
                RoamFinishReportView(report: finishReport, history: model.finishedHistory)
            } else {
                sessionContent
            }
        }
        .onAppear {
            ActiveSessionStore.shared.setRoamScreenVisible(true)
            purposeAccepted = storedPurposeAccepted; owner.setForeground(scenePhase == .active); owner.prepare(); model.captureFinishAddress(); browse.appear()
        }
        .onDisappear { nearbyExpanded = true; browse.parentHidden(); owner.pause() }
        .onDisappear { ActiveSessionStore.shared.setRoamScreenVisible(false) }
        .onChange(of: owner.phase) { _, phase in
            if phase != .active { nearbyExpanded = true; idle.reset() }
            browse.retireIfStale(owner: owner, reader: currentBrowseReader)
        }
        .onChange(of: owner.lastFix) { _, fix in
            if owner.phase == .active, let fix { idle.update(fix.coordinate, at: fix.measuredAt) } else { idle.reset() }
        }
        .onChange(of: scenePhase) { _, value in
            if value != .active { browse.retire() }
            owner.setForeground(value == .active)
        }
        .onChange(of: owner.localBrowseIdentity) { _, _ in browse.retireIfStale(owner: owner, reader: currentBrowseReader) }
        .onChange(of: owner.record?.clientSessionKey) { _, _ in browse.retireIfStale(owner: owner, reader: currentBrowseReader) }
        .onChange(of: localHistoryReader?.identity) { _, _ in browse.retireIfStale(owner: owner, reader: currentBrowseReader) }
        .onChange(of: localHistoryReader.map { ObjectIdentifier($0) }) { _, _ in browse.retireIfStale(owner: owner, reader: currentBrowseReader) }
        .onChange(of: albumMetadataReader?.scope) { _, _ in browse.retireIfStale(owner: owner, reader: currentBrowseReader) }
        .onChange(of: albumMetadataReader.map { ObjectIdentifier($0) }) { _, _ in browse.retireIfStale(owner: owner, reader: currentBrowseReader) }
    }
    /// Split out of `body`: the closure made the modifier chain too large for the type checker.
    private func settledSessionChanged(_ id: Int?) {
        if id == nil {
            finishReport = nil
        } else {
            QuestWidgetBoardPublisher.roamHistory((try? model.finishedHistory.history()) ?? [])
            if var report = RoamFinishReport(controller: owner, history: model.finishedHistory) {
                report.currentAddress = model.finishAddress.text(chinese: AppLanguage.interfaceIsChinese(locale))
                finishReport = report
            } else {
                finishReport = nil
            }
        }
        // Presentation only: the summary follows the existing settled-and-archived state; the queue dedupes a re-delivery.
        if id != nil {
            let result = owner.settlement?.result
            MiniProgramAnalytics.track(analytics, "roam_finish", bizType: "roam",
                bizID: MiniProgramAnalytics.bizID(owner.completedHistory?.serverSessionID), pagePath: "/pages/roam/index",
                properties: ["shops": .integer(Int64(result?.sessionShops ?? 0)), "pois": .integer(Int64(result?.newPois ?? 0))])
        }
    }
    var body: some View {
        sessionObservers
        // Design hand-off r1 PL-20: no tab bar during a session; the map and the session controls own the screen.
        .cyHideTabBar()
        // PL-20: a medium impact on pause and on resume.
        .cyHaptic(.impactMedium, trigger: owner.phase == .paused)
        .task(id: owner.phase) { await pulseWhileActive() }
        .modifier(G6RoamNPCPromptModifier(walking: roamPhase == .walking, finished: roamPhase == .finished, uniqueTiles: owner.record?.allTiles.count, sessionID: owner.record?.sessionID ?? 0))
        // P-040: the settle moment is a system success haptic (the summary itself is the finish report).
        .sensoryFeedback(.success, trigger: RoamSummaryCelebration.settledSessionID(owner)) { old, new in new != nil && new != old }
        .onChange(of: RoamSummaryCelebration.settledSessionID(owner), initial: true) { _, id in settledSessionChanged(id) }
        .overlay(alignment: .top) {
            if revealToastShown {
                CYRevealToast(percent: RoamLiveCoveragePresentation(controller: owner).percentage)
                    .padding(.top, CYSpacing.sm)
                    .transition(reduceMotion ? .opacity : .cyRevealToast)
            }
        }
        .onChange(of: owner.record?.allTiles.count) { old, new in
            // Presentation only: a higher tile count than before means new ground; the toast follows it.
            guard let old, let new, new > old else { return }
            revealTick += 1
            withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance) { revealToastShown = true }
            revealToastTask?.cancel()
            revealToastTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                guard !Task.isCancelled else { return }
                withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { revealToastShown = false }
            }
        }
        .background {
            RoamPausedBrowseLifetimeAnchor(presentation: browse).frame(width: 0, height: 0)
        }
    }
    private func pulseWhileActive() async {
        guard owner.phase == .active else { return }
        while !Task.isCancelled && owner.phase == .active {
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            // OWN-D-07.c: a walk holding background location keeps pulsing after Home; otherwise only in the foreground.
            guard !Task.isCancelled, scenePhase == .active || owner.continuesInBackground else { return }
            await owner.pulse()
        }
    }
    private var roamPhase: RoamPhase { RoamPhase(owner.phase) }
    /// Mini-program pcard as a system list section: the goal line with the phase, then 用时 / 地盘 / 距离 (公里)
    /// as `LabeledContent` rows. Built inline so every controller change redraws it.
    @ViewBuilder private var hud: some View {
        let active = owner.phase == .active
        // Design pass roam (P1/P2): one hero number (distance, rolling) and a quiet row for 用时 / 地盘 under it,
        // instead of three equal list rows. Same readings and identifiers as the MP pcard (用时 / 地盘 / 距离).
        Section {
            // i18n r1 locale: miles in the US, km in CN (same unit key as before).
            RoamLiveHeroDistance(value: hudDistance, unit: LocaleDisplay.usesMiles(locale) ? "unit.mile.abbr" : "roam.live.stat.distance", live: active)
                .accessibilityIdentifier("roam.live.distance")
            TimelineView(.animation(minimumInterval: RoamLiveTick.interval(reduceMotion: reduceMotion), paused: owner.phase != .active || !owner.foreground)) { _ in
                RoamLiveSecondaryStats(seconds: owner.record == nil ? nil : owner.localForegroundElapsedSeconds,
                                       coverage: RoamLiveCoveragePresentation(controller: owner))
            }
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text(active ? "roam.live.goal" : phaseText)
                    .accessibilityIdentifier("roam.live.phase")
                Spacer(minLength: 8)
                // PL-14: a labelled status, never a symbol alone. New ground bounces the symbol (P-040).
                // MP BL-02 maptip: 原地停留中 while walking (not paused) and under 3 m for 60 s; status only, no action.
                TimelineView(.animation(minimumInterval: 5, paused: !active)) { context in
                    let still = active && idle.isIdle(at: context.date)
                    Label {
                        Text(still ? "roam.live.idle" : phaseText)
                    } icon: {
                        Image(systemName: still ? "mappin" : roamPhase.statusSymbol)
                            .symbolEffect(.bounce, value: revealTick)
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier("roam.live.statusTag")
                }
            }
            .textCase(nil)
        }
    }
    private var hudDistance: String {
        guard let meters = owner.record?.distanceMeters, meters.isFinite, meters >= 0 else { return "—" }
        return LocaleDisplay.roadNumber(kilometers: meters / 1000, locale: locale).formatted(.number.precision(.fractionLength(1)).locale(locale))
    }
    /// Bottom bar of the session sheet. Every button keeps its identifier and controller call (P-040: system buttons,
    /// a tap on 开始 instead of hold-to-start).
    @ViewBuilder private var actionBar: some View {
        let canStart = [.ready, .locationDenied, .paused].contains(owner.phase)
        let canFinish = [.active, .paused].contains(owner.phase) && owner.record != nil
        if owner.phase != .unavailable && (canStart || owner.phase == .active || canFinish) {
            HStack(spacing: 12) {
                if owner.phase == .active {
                    Button { owner.pause() } label: {
                        Label("roam.live.pause", systemImage: "pause.fill").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("roam.live.pause")
                } else if canStart, owner.record == nil {
                    // PL-20 / PL-25: 开始 appears only once location use is allowed. Before that the consent card's
                    // single 允许使用位置 button is the only primary on the screen.
                    if purposeAccepted {
                        Button { commitGo() } label: {
                            Label("roam.w208.intro.start", systemImage: "figure.walk")
                                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(owner.busy || goCommitted)
                        .accessibilityIdentifier("roam.live.start")
                    }
                } else if canStart, owner.record?.finishRequested == false {
                    Button {
                        Task {
                            await SessionOfflineSyncModel.shared.performWriteOptIn(
                                environmentSession: offlineWriteSession.session,
                                routes: ["/api/roam/reveal", "/api/compliance/consents"]
                            ) {
                                await owner.resume(purposeAccepted: purposeAccepted, presenceAccepted: presenceAccepted)
                            }
                        }
                    } label: {
                        Label("roam.live.resume", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!purposeAccepted || owner.busy).accessibilityIdentifier("roam.live.resume")
                }
                if canFinish {
                    // Same confirmation dialog and identifier; a secondary system button beside the primary one.
                    Button(role: .destructive) { confirmFinish = true } label: {
                        Label("roam.live.finish", systemImage: "flag.checkered")
                            .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(owner.busy).accessibilityIdentifier("roam.live.finish")
                }
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
    }
    /// 开始 tapped: start through the same path as before. A refused start re-enables the button.
    private func commitGo() {
        if CLLocationManager().authorizationStatus == .notDetermined { showingLocationPriming = true; return }
        goCommitted = true
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/roam/reveal", "/api/compliance/consents"]
            ) {
                await owner.start(purposeAccepted: purposeAccepted, presenceAccepted: presenceAccepted)
            }
            if owner.phase != .active { goCommitted = false }
        }
    }
    @ViewBuilder private var pauseAndBrowse: some View {
        if owner.localBrowseIdentity != nil {
            Section {
                ForEach(RoamPausedBrowseKind.allCases, id: \.self) { kind in
                    let entryID = browse.entryID
                    let reader = browseReader(for: kind)
                    let context = RoamPausedBrowseContext.capture(kind: kind, owner: owner, reader: reader)
                    if let context {
                        Button {
                            browse.open(context, entryID: entryID, owner: owner, reader: reader)
                        } label: {
                            Label(LocalizedStringKey(kind.titleKey), systemImage: kind.symbol)
                        }
                        .accessibilityIdentifier(kind.accessibilityID)
                    }
                }
            } header: { Text("roam.live.more") }
        }
    }
    @ViewBuilder private var status: some View {
        let settled = owner.settlement.map { $0.hasCompleteSettlement } ?? false
        if owner.busy || owner.record != nil || settled {
            Section {
                if owner.busy { CYSkeleton() }
                if let record = owner.record {
                    LabeledContent("roam.live.tiles", value: String(record.allTiles.count - record.pendingTiles.count))
                    if !record.pendingTiles.isEmpty { LabeledContent("roam.live.pendingTiles", value: String(record.pendingTiles.count)) }
                    if owner.pendingActionCount > 0 { Text("roam.live.unknownVisit").foregroundStyle(.secondary) }
                }
                if let fact = owner.settlement, fact.hasCompleteSettlement {
                    LabeledContent("roam.live.confirmedXP", value: String(fact.result!.totalXp!))
                    LabeledContent("roam.live.confirmedShops", value: String(fact.result!.sessionShops!))
                    if owner.phase != .finished { Text("roam.live.archivePending").foregroundStyle(.secondary) }
                }
            } header: { Text("roam.live.sessionStatus") }
        }
    }
    private var phaseText: LocalizedStringKey {
        switch owner.phase {
        case .ready: return "roam.live.ready"
        case .acquiring: return "roam.live.acquiring"
        case .active: return "roam.live.active"
        case .paused: return "roam.live.paused"
        case .recovering, .recoveryRequired: return "roam.live.needsRecovery"
        case .finishing: return "roam.live.finishing"
        case .finished: return "roam.live.finished"
        case .locationDenied: return "roam.live.locationProblem"
        case .unavailable: return "roam.live.notApproved"
        }
    }
    @ViewBuilder private var trace: some View {
        if let track = owner.currentRouteTrack, owner.phase == .paused || track.count > 1 {
            RoamLiveRouteOverviewSection(track: track, paused: owner.phase == .paused)
        }
    }
    private var shopVisitorSources: [RoamPlayerExtrasService.VisitorSource] {
        owner.registeredShops.prefix(8).map { RoamPlayerExtrasService.VisitorSource(sourceType: 2, sourceID: $0.id) }
    }
    @ViewBuilder private var nearby: some View {
        nearbySection
            .task(id: shopVisitorSources) {
                guard let socialCapabilities, !shopVisitorSources.isEmpty else { return }
                await shopVisitors.load(shopVisitorSources, client: socialCapabilities.client)
            }
    }
    @ViewBuilder private var nearbySection: some View {
        Section("roam.live.nearby") {
            if owner.nearbyReadFailed {
                if owner.placesReadError != nil {
                    Label("roam.liveRead.placesFailed", systemImage: "exclamationmark.triangle")
                        .accessibilityIdentifier("roam.liveRead.placesFailed")
                }
                if owner.registeredShopsReadError != nil {
                    Label("roam.liveRead.shopsFailed", systemImage: "exclamationmark.triangle")
                        .accessibilityIdentifier("roam.liveRead.shopsFailed")
                }
                Text("roam.liveRead.failed").cyText(.body).foregroundStyle(.secondary)
                    .accessibilityIdentifier("roam.liveRead.failed")
                if owner.canRetryNearbyRead {
                    Button("action.retry") { Task { await owner.retryNearbyRead() } }
                        .accessibilityIdentifier("roam.liveRead.retry")
                }
            } else if owner.places.isEmpty && owner.registeredShops.isEmpty {
                Text("roam.live.noPlaces").foregroundStyle(.secondary)
            }
            if !owner.places.isEmpty || !owner.registeredShops.isEmpty {
                RoamNearbyVisibilityButton(expanded: $nearbyExpanded)
            }
            ForEach(owner.registeredShops) { shop in
                if nearbyExpanded || owner.busy || owner.error != nil || owner.registeredShopUnresolved(shop) || owner.registeredShopConfirmed(shop) {
                    VStack(alignment: .leading, spacing: 8) {
                        if shop.addressName.isEmpty { Text("roam.unnamed").cyText(.cardTitle) } else { Text(verbatim: shop.addressName).cyText(.cardTitle) }
                        if let meters = shop.distance, meters.isFinite, meters > 0 {
                            Text("roam.live.topic.meters \(Int(meters.rounded()))").cyText(.meta).foregroundStyle(.secondary)
                                .accessibilityIdentifier("roam.live.shop.distance")
                        }
                        RoamShopVisitorsStack(source: RoamPlayerExtrasService.VisitorSource(sourceType: 2, sourceID: shop.id),
                                              visitors: shopVisitors.visitors[RoamPlayerExtrasService.VisitorSource(sourceType: 2, sourceID: shop.id)])
                        if let topic = RoamLiveTopicShop(shop: shop), roamGap != nil {
                            Button { topicShop = topic } label: {
                                Label("roam.live.topic.entry", systemImage: "map")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("roam.live.topic.entry")
                        }
                        if owner.registeredShopUnresolved(shop) { Text("roam.live.unknownVisit").cyText(.meta) }
                        else if owner.registeredShopConfirmed(shop) { Label("roam.live.arrivalConfirmed", systemImage: "checkmark.circle") }
                        else {
                            Button("roam.live.visitShop") {
                                Task {
                                    await owner.visitRegisteredShop(shop)
                                    if owner.registeredShopConfirmed(shop) {
                                        checkin = RoamCheckinTarget(place: shop.addressName.isEmpty ? nil : shop.addressName, at: Date())
                                    }
                                }
                            }
                                .buttonStyle(.borderless)
                                .disabled(owner.busy || owner.registeredShopGap(shop) != 0)
                            if let gap = owner.registeredShopGap(shop), gap > 0 { Text("roam.live.walkCloser \(gap)").cyText(.meta).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical, 4)
                }
            }
            ForEach(owner.places) { place in
                if nearbyExpanded || owner.busy || owner.error != nil || owner.actionUnresolved(place, shop: false) || owner.actionUnresolved(place, shop: true)
                    || owner.actionConfirmed(place, shop: false) || owner.actionConfirmed(place, shop: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        RoamTitle(place.name).cyText(.cardTitle)
                        if let text = owner.merchantDescription(for: place) {
                            RoamLiveMerchantDescriptionRow(text: text)
                        }
                        arrivalButton(place, shop: false)
                        if place.type == 2 { arrivalButton(place, shop: true) }
                    }.padding(.vertical, 4)
                }
            }
        }
    }
    private func arrivalButton(_ place: RoamPlace, shop: Bool) -> some View {
        VStack(alignment: .leading) {
            if owner.actionUnresolved(place, shop: shop) { Text("roam.live.unknownVisit").cyText(.meta) }
            else if owner.actionConfirmed(place, shop: shop) { Label("roam.live.arrivalConfirmed", systemImage: "checkmark.circle") }
            else {
                Button(shop ? "roam.live.visitShop" : "roam.live.discover") {
                    Task {
                        let before = owner.actionConfirmed(place, shop: false)
                        if shop { await owner.visitShop(place) } else { await owner.discover(place) }
                        if owner.actionConfirmed(place, shop: shop) {
                            checkin = RoamCheckinTarget(place: place.name.isEmpty ? nil : place.name, at: Date())
                        }
                        if !shop, !before, owner.actionConfirmed(place, shop: false) {
                            MiniProgramAnalytics.track(analytics, "roam_poi_found", bizType: "roam",
                                bizID: MiniProgramAnalytics.bizID(place.id), pagePath: "/pages/roam/index")
                        }
                    }
                }
                    .disabled(owner.busy || owner.gapMeters(place, shop: shop) != 0)
                if let gap = owner.gapMeters(place, shop: shop), gap > 0 {
                    Text("roam.live.walkCloser \(gap)").cyText(.meta).foregroundStyle(.secondary)
                }
            }
        }
    }
    private func errorText(_ error: Error) -> LocalizedStringKey {
        if error as? RoamLiveFailure == .locationQuality { return "roam.live.locationQuality" }
        if error as? RoamLiveFailure == .outOfRange { return "roam.live.outOfRange" }
        if error as? RoamLiveFailure == .journalUnavailable { return "roam.live.storageError" }
        if error as? RoamLiveFailure == .unresolvedVisit { return "roam.live.unknownVisit" }
        if error as? RoamExperienceFailure == .incompleteSettlement { return "roam.live.incomplete" }
        return "roam.live.operationError"
    }
}
/// A display-only projection of the current controller's accepted in-memory samples.
/// Saved tile totals and timestamps do not establish this local-area estimate.
struct RoamLiveCoveragePresentation: Equatable {
    let percentage: Int?
    @MainActor init(controller: RoamLiveSessionController) {
        guard controller.isAvailable, controller.foreground,
              [.active, .paused].contains(controller.phase),
              let record = controller.record, !record.finishRequested, record.pendingWrite == nil,
              !controller.track.isEmpty else { percentage = nil; return }
        percentage = controller.explorationPercent
    }
    func value(locale: Locale) -> String {
        percentage.map { "\($0)%" } ?? RoamLiveCoverageCopy(locale: locale).unknown
    }
}

struct RoamLiveCoverageCopy {
    let title: String
    let unknown: String
    let hint: String
    init(locale: Locale) {
        title = appLocalized("roamLive.r3.coverage.title", locale: locale)
        unknown = "—"
        hint = appLocalized("roamLive.r3.coverage.hint", locale: locale)
    }
}

/// HUD tile 地盘: the explored percentage, or — when it isn't known.
@MainActor struct RoamLiveCoverageRow: View {
    let presentation: RoamLiveCoveragePresentation
    var body: some View {
        RoamLiveStatTile(value: presentation.percentage.map { "\($0)%" } ?? "—", label: "roam.live.stat.turf")
            .accessibilityIdentifier("roam.live.localCoverage")
    }
}

/// Design pass roam (P1 one glance, one number): the walk's distance as the hero value. Small label above, the
/// number large and monospaced with its unit on the baseline; it rolls as it grows (P2).
struct RoamLiveHeroDistance: View {
    let value: String
    var unit: LocalizedStringKey = "roam.live.stat.distance"
    var live: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: CYSpacing.xs) {
                if live {
                    Image(systemName: "figure.walk.motion")
                        .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                Text("roam.live.hero.distance")
                    .cyText(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                Text(verbatim: value)
                    .cyText(.data2XL, monospacedDigit: true)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .snappy, value: value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .cyText(.label)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("roam.live.hero.distance"))
        .accessibilityValue(Text(verbatim: value + " ") + Text(unit))
    }
}

/// Design pass roam: the quiet row under the hero — 用时 and 地盘 side by side, stacked when they do not fit (P12).
struct RoamLiveSecondaryStats: View {
    let seconds: Int?
    let coverage: RoamLiveCoveragePresentation
    private var timeValue: String {
        guard let seconds, seconds >= 0 else { return "—" }
        return RoamLiveElapsedCopy(locale: Locale(identifier: "en")).value(seconds: seconds)
    }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: CYSpacing.lg) { columns }
            VStack(alignment: .leading, spacing: CYSpacing.sm) { columns }
        }
    }
    @ViewBuilder private var columns: some View {
        RoamLiveStatColumn(value: timeValue, label: "roam.live.stat.time")
            .accessibilityIdentifier("roam.live.foregroundElapsed")
        RoamLiveStatColumn(value: coverage.percentage.map { "\($0)%" } ?? "—", label: "roam.live.stat.turf")
            .accessibilityIdentifier("roam.live.localCoverage")
    }
}

/// One secondary reading: small label above, monospaced value below.
struct RoamLiveStatColumn: View {
    let value: String
    let label: LocalizedStringKey
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).cyText(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(verbatim: value)
                .cyText(.numericBody, monospacedDigit: true)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .snappy, value: value)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(verbatim: value))
    }
}

/// One HUD reading: a short label and its value, as in the mini-program pstat.
struct RoamLiveStatTile: View {
    let value: String
    let label: LocalizedStringKey
    var body: some View {
        // P-040: a system `LabeledContent` row (Fitness summary) instead of a big-number tile.
        LabeledContent {
            Text(verbatim: value).monospacedDigit()
                // PL-20 / PL-48: live numbers roll instead of jumping.
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
        } label: {
            Text(label)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RoamLiveElapsedCopy {
    let locale: Locale
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var title: String { appLocalized("roamLive.r3.elapsed.title", locale: locale) }
    var unknown: String { "—" }
    var hint: String { appLocalized("roamLive.r3.elapsed.hint", locale: locale) }
    func value(seconds: Int?) -> String {
        guard let seconds, seconds >= 0 else { return unknown }
        let minutes = seconds / 60, remainder = seconds % 60
        return "\(minutes < 10 ? "0" : "")\(minutes):\(remainder < 10 ? "0" : "")\(remainder)"
    }
}
/// HUD tile 用时: mm:ss of this walk's foreground time, or — when it isn't known.
struct RoamLiveElapsedRow: View {
    let seconds: Int?
    var body: some View {
        let known = seconds.map { $0 >= 0 } ?? false
        RoamLiveStatTile(value: known ? RoamLiveElapsedCopy(locale: Locale(identifier: "en")).value(seconds: seconds) : "—",
                         label: "roam.live.stat.time")
            .accessibilityIdentifier("roam.live.foregroundElapsed")
    }
}

/// Only displays fields of the complete, current settlement after the existing archive succeeds.
/// A missing field is not evidence that no medal was awarded.
struct RoamFinishedMedalsPresentation: Equatable {
    let journey: String?
    let shop: String?
    @MainActor init?(controller: RoamLiveSessionController) {
        guard controller.phase == .finished, controller.isAvailable, controller.foreground,
              !controller.busy, controller.record == nil,
              controller.makeFinishedHistoryReader().identity != nil,
              let reference = controller.completedHistory,
              let fact = controller.settlement, fact.hasCompleteSettlement,
              fact.sessionID == reference.serverSessionID, let result = fact.result else { return nil }
        journey = Self.provided(result.medal)
        shop = Self.provided(result.shopMedal?.name)
    }
    private static func provided(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}

struct RoamFinishedMedalsCopy {
    let title: String
    let journey: String
    let shop: String
    let unavailable: String
    let hint: String
    init(locale: Locale) {
        title = appLocalized("roamLive.r3.medals.title", locale: locale)
        journey = appLocalized("roamLive.r3.medals.journey", locale: locale)
        shop = appLocalized("roamLive.r3.medals.shop", locale: locale)
        unavailable = appLocalized("roamLive.r3.medals.unavailable", locale: locale)
        hint = appLocalized("roamLive.r3.medals.hint", locale: locale)
    }
}

struct RoamFinishedMedalsSection: View {
    let presentation: RoamFinishedMedalsPresentation
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            LabeledContent {
                Text(verbatim: presentation.journey ?? "—")
            } label: { Label("roam.live.medal.journey", systemImage: "medal") }
                .accessibilityIdentifier("roam.live.finishedMedals.journey")
            LabeledContent {
                Text(verbatim: presentation.shop ?? "—")
            } label: { Label("roam.live.medal.shop", systemImage: "storefront") }
                .accessibilityIdentifier("roam.live.finishedMedals.shop")
        } header: { Text("roam.live.medal.title") }
    }
}

struct RoamPlaceMemoryCopy {
    let title: String
    let close: String
    init(locale: Locale) {
        title = appLocalized("roamLive.r3.placeMemory.title", locale: locale)
        close = appLocalized("roamLive.r3.placeMemory.close", locale: locale)
    }
}
struct RoamPlaceMemorySection: View {
    let placeName: String
    let text: String
    let close: () -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            if !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(verbatim: placeName).cyText(.cardTitle)
            }
            Text(verbatim: text).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("roam.live.placeMemory.text")
            Button(action: close) { Text("roam.live.placeMemory.close") }
                .accessibilityIdentifier("roam.live.placeMemory.close")
        } header: { Text("roam.live.placeMemory.title") }
    }
}

/// Only the currently owned, fully archived settlement may provide this display text.
struct RoamFinishedStoryPresentation: Equatable {
    let text: String
    @MainActor init?(controller: RoamLiveSessionController) {
        guard controller.phase == .finished, controller.isAvailable, controller.foreground,
              !controller.busy, controller.record == nil,
              controller.makeFinishedHistoryReader().identity != nil,
              let reference = controller.completedHistory,
              let fact = controller.settlement, fact.hasCompleteSettlement,
              fact.sessionID == reference.serverSessionID,
              let text = fact.result?.routeStory else { return nil }
        self.text = text
    }
}
struct RoamFinishedStoryCopy {
    let title: String
    let hint: String
    init(locale: Locale) {
        title = appLocalized("roamLive.r3.story.title", locale: locale)
        hint = appLocalized("roamLive.r3.story.hint", locale: locale)
    }
}
struct RoamFinishedStorySection: View {
    let presentation: RoamFinishedStoryPresentation
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            Text(verbatim: presentation.text).cyText(.body).italic()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("roam.live.finishedStory.text")
        } header: { Text("roam.live.story.title") }
    }
}

struct RoamLiveMerchantDescriptionCopy {
    let title: String
    init(locale: Locale) {
        title = locale.language.languageCode?.identifier == "zh" ? "商家介绍" : "About this merchant"
    }
}
struct RoamLiveMerchantDescriptionRow: View {
    let text: String
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("roam.live.merchant.about")
                .cyText(.meta).foregroundStyle(.secondary)
            Text(verbatim: text).fixedSize(horizontal: false, vertical: true)
        }.accessibilityIdentifier("roam.live.merchantDescription")
    }
}

struct RoamNearbyVisibilityCopy {
    let hide, show, expanded, collapsed, hint: String
    init(locale: Locale) {
        hide = appLocalized("roamLive.r3.nearbyVisibility.hide", locale: locale)
        show = appLocalized("roamLive.r3.nearbyVisibility.show", locale: locale)
        expanded = appLocalized("roamLive.r3.nearbyVisibility.expanded", locale: locale)
        collapsed = appLocalized("roamLive.r3.nearbyVisibility.collapsed", locale: locale)
        hint = appLocalized("roamLive.r3.nearbyVisibility.hint", locale: locale)
    }
}
struct RoamNearbyVisibilityButton: View {
    @Binding var expanded: Bool
    @Environment(\.locale) private var locale
    func toggle() { expanded = !expanded }
    var body: some View {
        Button(action: toggle) {
            Label(expanded ? "roam.live.nearby.hide" : "roam.live.nearby.show", systemImage: expanded ? "chevron.up" : "chevron.down")
        }
        .accessibilityIdentifier("roam.live.nearby.visibility")
    }
}

struct RoamLiveRouteOverviewCopy {
    let pausedHint, finishedHint, missing, onePoint, recordedPoints: String
    init(locale: Locale) {
        pausedHint = appLocalized("roamLive.r3.routeOverview.pausedHint", locale: locale)
        finishedHint = appLocalized("roamLive.r3.routeOverview.finishedHint", locale: locale)
        missing = appLocalized("roamLive.r3.routeOverview.missing", locale: locale)
        onePoint = appLocalized("roamLive.r3.routeOverview.onePoint", locale: locale)
        recordedPoints = appLocalized("roamLive.r3.routeOverview.recordedPoints", locale: locale)
    }
}
struct RoamLiveRouteOverviewSection: View {
    let track: [RoamHistoryPoint]
    let paused: Bool
    var finished = false
    @Environment(\.locale) private var locale
    var hasDrawableRoute: Bool { track.count > 1 }
    var body: some View {
        Section("roam.live.route.title") {
            if hasDrawableRoute {
                let sketch = RoamRouteSketch(track: track, places: [])
                Canvas { context, size in
                    var path = Path()
                    for (index, point) in sketch.track.enumerated() {
                        let value = CGPoint(x: point.x * size.width, y: point.y * size.height)
                        if index == 0 { path.move(to: value) } else { path.addLine(to: value) }
                    }
                    context.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }.frame(height: 180).accessibilityHidden(true)
                    .accessibilityIdentifier("roam.live.routeOverview.points")
            } else {
                Text("roam.live.route.empty")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("roam.live.routeOverview.unavailable")
            }
        }.accessibilityIdentifier("roam.live.routeOverview")
    }
}


enum RoamPausedBrowseKind: CaseIterable, Hashable {
    case history, settings, album
    var symbol: String { switch self { case .history: return "clock.arrow.circlepath"; case .settings: return "location.slash"; case .album: return "rectangle.stack" } }
    var titleKey: String { switch self { case .history: return "roam.live.more.history"; case .settings: return "roam.live.more.settings"; case .album: return "roam.live.more.album" } }
    var accessibilityID: String { switch self { case .history: return "roam.live.pausedHistory.open"; case .settings: return "roam.live.pausedSettings.open"; case .album: return "roam.live.pausedAlbum.open" } }
}
struct RoamPausedBrowseContext: Equatable {
    let kind: RoamPausedBrowseKind
    let controllerID: ObjectIdentifier
    let identity: RoamExperienceIdentity
    let clientSessionKey: String
    let readerID: ObjectIdentifier?
    var albumReadScope: UUID? = nil
    @MainActor static func capture(kind: RoamPausedBrowseKind, owner: RoamLiveSessionController,
                                  reader: (any RoamExperienceReading)?) -> Self? {
        guard let identity = owner.localBrowseIdentity, let key = owner.record?.clientSessionKey else { return nil }
        if kind != .settings {
            guard let reader, reader.identity == identity else { return nil }
            return .init(kind: kind, controllerID: ObjectIdentifier(owner), identity: identity, clientSessionKey: key, readerID: ObjectIdentifier(reader), albumReadScope: (reader as? RoamAlbumMetadataReader)?.scope)
        }
        return .init(kind: kind, controllerID: ObjectIdentifier(owner), identity: identity, clientSessionKey: key, readerID: nil)
    }
}
@MainActor struct RoamPausedBrowseTarget: Identifiable {
    let id: UUID
    let context: RoamPausedBrowseContext
    let historyReader: RoamPausedLocalHistoryReader?
    let albumScope: RoamStampAlbumReadOnlyScope?
}
@MainActor final class RoamPausedBrowsePresentation: @preconcurrency ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private(set) var target: RoamPausedBrowseTarget?
    private(set) var entryID = UUID()
    private var visible = false
    private var attached = false
    private var lifetimeID: UUID?
    func appear() {
        let returning = !visible
        if returning { entryID = UUID() }
        visible = true; attached = true
        if returning { objectWillChange.send() }
    }
    func parentHidden() { visible = false; if target == nil { retire(publishing: false) } }
    func attachLifetime() -> UUID {
        // Replacing a native host expires its authority before the new host can appear.
        if lifetimeID != nil { disappear() }
        let id = UUID(); lifetimeID = id; return id
    }
    func isCurrentLifetime(_ id: UUID) -> Bool { lifetimeID == id }
    func dismantleLifetime(_ id: UUID) {
        guard isCurrentLifetime(id) else { return }
        lifetimeID = nil; disappear()
    }
    func parentDisappeared(departing: Bool, coveredByPresentation: Bool) {
        if !departing && coveredByPresentation && target != nil { parentHidden() }
        else { disappear() }
    }
    func disappear() { visible = false; attached = false; retire(publishing: false) }
    func retire() { retire(publishing: true) }
    private func retire(publishing: Bool) {
        let album = target?.albumScope
        target = nil; entryID = UUID()
        // Native teardown may run inside GraphHost.invalidate. Revoke synchronously,
        // without notifying that dying graph (including the observable album scope).
        // Both readers already check this target's exact UUID before and after reads.
        if publishing { album?.retire(); objectWillChange.send() }
    }
    func open(_ rendered: RoamPausedBrowseContext, entryID: UUID, owner: RoamLiveSessionController,
              reader: (any RoamExperienceReading)?) {
        guard attached, visible, self.entryID == entryID, target == nil,
              rendered == RoamPausedBrowseContext.capture(kind: rendered.kind, owner: owner, reader: reader) else { return }
        owner.pause()
        guard attached, visible, self.entryID == entryID, target == nil, owner.phase == .paused,
              rendered == RoamPausedBrowseContext.capture(kind: rendered.kind, owner: owner, reader: reader) else { return }
        let id = UUID()
        let history: RoamPausedLocalHistoryReader?
        if rendered.kind == .history, let reader {
            history = .init(base: reader, expected: rendered.identity, isCurrent: { [weak self, weak owner] in
                guard let self, let owner, let current = self.target, current.id == id else { return false }
                return self.matches(current, owner: owner, reader: reader)
            })
        } else { history = nil }
        let album: RoamStampAlbumReadOnlyScope?
        if rendered.kind == .album, let reader {
            album = .init(reader: reader, identity: rendered.identity, isCurrent: { [weak self, weak owner] in
                guard let self, let owner, let current = self.target, current.id == id else { return false }
                return self.matches(current, owner: owner, reader: reader)
            })
        } else { album = nil }
        target = .init(id: id, context: rendered, historyReader: history, albumScope: album)
        objectWillChange.send()
    }
    func matches(_ offered: RoamPausedBrowseTarget, owner: RoamLiveSessionController,
                 reader: (any RoamExperienceReading)?) -> Bool {
        attached && target?.id == offered.id && owner.phase == .paused &&
        offered.context == RoamPausedBrowseContext.capture(kind: offered.context.kind, owner: owner, reader: reader)
    }
    func retireIfStale(owner: RoamLiveSessionController, reader: (any RoamExperienceReading)?) {
        if let target, !matches(target, owner: owner, reader: reader) { retire() }
    }
    func close(id: UUID) { if target?.id == id { retire() } }
    func binding(for offered: RoamPausedBrowseTarget?, owner: RoamLiveSessionController, reader: (any RoamExperienceReading)?) -> Binding<RoamPausedBrowseTarget?> {
        return Binding(get: {
            guard let offered, self.matches(offered, owner: owner, reader: reader) else { return nil }
            return offered
        }, set: { value in
            if value == nil, let offered { self.close(id: offered.id) }
        })
    }
}
/// Only the two existing local reads are delegated. This presentation grants no remote capability.
@MainActor final class RoamPausedLocalHistoryReader: RoamExperienceReading {
    private let base: any RoamExperienceReading
    private let expected: RoamExperienceIdentity
    private let isCurrent: () -> Bool
    init(base: any RoamExperienceReading, expected: RoamExperienceIdentity, isCurrent: @escaping () -> Bool) {
        self.base = base; self.expected = expected; self.isCurrent = isCurrent
    }
    var identity: RoamExperienceIdentity? { isCurrent() && base.identity == expected ? expected : nil }
    var isConfigured: Bool { false }
    var isOfflineExample: Bool { base.isOfflineExample }
    func history() throws -> [RoamHistoryRecord] {
        guard identity != nil else { throw CancellationError() }
        let result = try base.history()
        guard identity != nil else { throw CancellationError() }
        return result
    }
    func localWalkStatus() throws -> RoamLocalWalkStatus {
        guard identity != nil else { throw CancellationError() }
        let result = try base.localWalkStatus()
        guard identity != nil else { throw CancellationError() }
        return result
    }
    func sessionFact(_ query: RoamRecoveryQuery) async throws -> RoamSessionFact { throw APIError.notConfigured }
    func album(page: Int, pageSize: Int) async throws -> RoamAlbumPage { throw APIError.notConfigured }
    func tilePage(afterID: Int, limit: Int) async throws -> RoamTileMemoryPage { throw APIError.notConfigured }
    func shopBadge() async throws -> RoamShopBadge? { throw APIError.notConfigured }
}
struct RoamPausedBrowseCopy {
    let title, hint, history, settings, album: String
    init(locale: Locale) {
        title = appLocalized("roamLive.r3.pausedBrowse.title", locale: locale)
        hint = appLocalized("roamLive.r3.pausedBrowse.hint", locale: locale)
        history = appLocalized("roamLive.r3.pausedBrowse.history", locale: locale)
        settings = appLocalized("roamLive.r3.pausedBrowse.settings", locale: locale)
        album = appLocalized("roamLive.r3.pausedBrowse.album", locale: locale)
    }
    func label(_ kind: RoamPausedBrowseKind) -> String {
        switch kind { case .history: return history; case .settings: return settings; case .album: return album }
    }
}


@MainActor private struct RoamPausedBrowseSheetOwner: View {
    let presentation: RoamPausedBrowsePresentation
    let target: RoamPausedBrowseTarget
    let owner: RoamLiveSessionController
    let reader: (any RoamExperienceReading)?
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .sheet(item: presentation.binding(for: target, owner: owner, reader: reader),
                   onDismiss: { presentation.close(id: target.id) }) { offered in Group {
                NavigationStack {
                    if presentation.matches(offered, owner: owner, reader: reader) {
                        Group {
                            switch offered.context.kind {
                            case .history:
                                if let local = offered.historyReader { RoamHistoryView(reader: local) }
                            case .settings: RoamLocationSettingsDestination()
                            case .album:
                                if let reader, let scope = offered.albumScope, scope.matches(reader) {
                                    RoamStampAlbumView(reader: reader, readOnlyScope: scope)
                                }
                            }
                        }
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("action.done") { presentation.close(id: offered.id) }
                        } }
                    }
                }
            }.cySheet(detents: [.large]) }
    }
}
/// Native attachment distinguishes a covering sheet from the source leaving its hierarchy.
@MainActor struct RoamPausedBrowseLifetimeAnchor: UIViewControllerRepresentable {
    let presentation: RoamPausedBrowsePresentation
    func makeUIViewController(context: Context) -> RoamPausedBrowseLifetimeController {
        RoamPausedBrowseLifetimeController(presentation: presentation)
    }
    func updateUIViewController(_ controller: RoamPausedBrowseLifetimeController, context: Context) {}
    static func dismantleUIViewController(_ controller: RoamPausedBrowseLifetimeController, coordinator: ()) {
        controller.presentation?.dismantleLifetime(controller.lifetimeID)
    }
}
@MainActor final class RoamPausedBrowseLifetimeController: UIViewController {
    weak var presentation: RoamPausedBrowsePresentation?
    let lifetimeID: UUID
    private var departing = false
    init(presentation: RoamPausedBrowsePresentation) {
        self.presentation = presentation; lifetimeID = presentation.attachLifetime()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { return nil }
    private var ancestry: [UIViewController] {
        var result: [UIViewController] = [], next: UIViewController? = self
        while let value = next { result.append(value); next = value.parent }
        return result
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let presentation, presentation.isCurrentLifetime(lifetimeID) else { return }
        departing = false; presentation.appear()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        departing = ancestry.contains { $0.isMovingFromParent || $0.isBeingDismissed }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let presentation, presentation.isCurrentLifetime(lifetimeID) else { return }
        let source = ancestry
        presentation.parentDisappeared(
            departing: departing || source.contains { $0.isMovingFromParent || $0.isBeingDismissed },
            coveredByPresentation: source.contains { $0.presentedViewController != nil })
    }
}

/// The live HUD clock ticks every second; with Reduce Motion on it refreshes less often.
enum RoamLiveTick {
    static func interval(reduceMotion: Bool) -> TimeInterval { reduceMotion ? 5 : 1 }
}

/// ROAM-2: the MP `openCheckinView` half sheet. Name, 已打卡 HH:mm · 在这儿留下点什么, then the two citystamp rows.
struct RoamCheckinTarget: Identifiable {
    let id = UUID()
    let place: String?
    let at: Date
}
@MainActor struct RoamCheckinSheet: View {
    let target: RoamCheckinTarget
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("roam.checkin.sub \(target.at.formatted(date: .omitted, time: .shortened))")
                        .cyText(.bodyCompact).foregroundStyle(.secondary)
                        .accessibilityIdentifier("roam.checkin.sub")
                    RoamCheckinStampRows(place: target.place)
                }
            }
            .navigationTitle(target.place.map { Text(verbatim: $0) } ?? Text("roamSub.w208.stamp.defaultPlace")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("action.close", systemImage: "xmark") }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("roam.checkin.sheet")
    }
}

/// ROAM-r11-3: MP pages/roam/node-level-style.js STYLES (1 普通 ● / 2 精选 ◆ / 3 官方合作 ★ / 4 主题路线 ⬟) as
/// system marker symbols and tints. A missing level is 普通, as `getNodeLevelStyle` does.
/// ROAM-r11-3: round cover pin for a participating shop (MP photo-pins.js PIN_SIZE 40).
@MainActor struct RoamLivePhotoPin: View {
    let url: URL
    let tint: Color
    @State private var image: UIImage?
    /// MP `isParticipating` + `pinPhoto`: shops (type 2) with a cover; only allowlisted media origins.
    static func url(for place: RoamPlace) -> URL? {
        guard place.type == 2, let raw = place.coverImage?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              ObjectCardMediaPolicy.origin(raw) != nil else { return nil }
        return URL(string: raw)
    }
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "storefront.fill").foregroundStyle(.white).padding(8)
            }
        }
        .frame(width: 40, height: 40)
        .background(tint)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .accessibilityHidden(true)
        .task(id: url) { image = await PlayerFeedImages.image(for: url, maxPixel: 120) }
    }
}

enum RoamLivePlaceLevel {
    static func symbol(_ level: Int?) -> String {
        switch level ?? 1 {
        case 2: return "diamond.fill"
        case 3: return "star.fill"
        case 4: return "shield.fill"
        default: return "circle.fill"
        }
    }
    static func tint(_ level: Int?) -> Color {
        switch level ?? 1 {
        case 2: return .teal
        case 3: return .orange
        case 4: return .red
        default: return .blue
        }
    }
}

/// Port of MP `utils/roam-idle.js` (BL-02): movement under 3 m for 60 s reads as 原地停留中. Display only.
struct RoamLiveIdleDetector: Equatable {
    static let radiusMeters: Double = 3
    static let holdSeconds: TimeInterval = 60
    private(set) var anchor: RoamCoordinate?
    private(set) var since: Date?
    mutating func update(_ point: RoamCoordinate, at now: Date) {
        if let anchor, let since, now >= since,
           RoamExperienceMath.distanceMeters(anchor, point) < Self.radiusMeters {
            return
        }
        anchor = point
        since = now
    }
    mutating func reset() {
        anchor = nil
        since = nil
    }
    /// The device may stop sending fixes while standing still, so the hold is measured against the clock.
    func isIdle(at now: Date) -> Bool {
        guard anchor != nil, let since else { return false }
        return now.timeIntervalSince(since) >= Self.holdSeconds
    }
}
