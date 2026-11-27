import SwiftUI
import MapKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// 漫游 tab root (P 210:8322, owner Q9): the map is the door to City Monopoly. A full-bleed muted dark
// MapKit map, 迷雾 / 领地 layer chips, the stat line in the header subtitle (→ the board home N01),
// and the 附近 sheet (detents 96 / medium / large) with the hold-to-start button docked on it.
// The shipped 走起 / 漫游护照 page stays one tap away (header ⋯ → 漫游护照与工具) so nothing it
// offered is lost.

struct CityRoamRootDependencies {
    var captureFix: (@MainActor () async throws -> RoamDeviceFix)?
    /// The area the player chose in 漫游 (used when there is no fix yet).
    var fallbackCenter: RoamCoordinate?
    var photoUploader: CityClaimPhotoUploading?
    /// The live roam session (hold to start).
    var liveDestination: (() -> AnyView)?
    /// The same retained live controller the live page drives; only read when `CityLiveOnMap.isEnabled`.
    var liveController: (@MainActor () -> RoamLiveSessionController)? = nil
    /// The shipped roam list page with its passport and tools.
    var passportDestination: (() -> AnyView)?
    var onChooseArea: (() -> Void)?
    /// DEBUG design fixtures only: a ready photo reference and an automatic submit for the claim sheet.
    var fixtureClaim: CityClaimFixture? = nil
}

struct CityClaimFixture { let photoRef: String; let autoSubmit: Bool }

/// Which sheet the root shows over the map.
enum CitySheetRoute: Identifiable, Equatable {
    case property(String)
    case claim(String)
    case challenge(String)
    case shield(String)
    case upgrade(String)
    var id: String {
        switch self {
        case .property(let id): return "property-" + id
        case .claim(let id): return "claim-" + id
        case .challenge(let id): return "challenge-" + id
        case .shield(let id): return "shield-" + id
        case .upgrade(let id): return "upgrade-" + id
        }
    }
    var placeID: String {
        switch self {
        case .property(let id), .claim(let id), .challenge(let id), .shield(let id), .upgrade(let id): return id
        }
    }
}

struct CityRoamRootView: View {
    @ObservedObject var store: CityBoardStore
    let dependencies: CityRoamRootDependencies
    /// Opens this sheet once the first load lands (deep links and design fixtures).
    var initialRoute: CitySheetRoute? = nil

    @State private var mode: CityMapLayerMode = .territory
    @State private var position: MapCameraPosition = .automatic
    @State private var selection: String?
    @State private var route: CitySheetRoute?
    @State private var moment: CityMomentRoute?
    @State private var drawer: CityDrawerDetent = .peek
    @State private var path = NavigationPath()
    @State private var fix: RoamDeviceFix?
    @State private var showsPassport = false
    /// The tapped pin's centre in the window, for the pin → deed flight.
    @State private var pinOrigin: (id: String, point: CGPoint)?
    /// The cityTerritory inbox card's deep link (open this place's property sheet on the map).
    @ObservedObject private var links = CityDeepLinks.shared
    /// Hold to start → the live controls over this map (flagged, see `CityLiveOnMap`).
    @State private var liveOnMap = false
    @State private var liveSession: CityLiveMapSession?
    @Namespace private var liveSpace
    @AppStorage(CityLiveOnMap.purposeKey) private var livePurposeAccepted = false
    @Environment(\.offlineWriteSession) private var offlineWriteSession

    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var center: RoamCoordinate? { fix?.coordinate ?? store.center ?? dependencies.fallbackCenter }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                map
                header
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: drawer == .peek && !isPropertyOpen && !liveOnMap ? 196 : 0) }
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    CityNearbyDrawer(detent: $drawer, places: store.places, origin: center, phase: store.phase,
                        holdEnabled: dependencies.liveDestination != nil,
                        onHold: { startLive() },
                        onSelect: { open($0) },
                        onRetry: { Task { await reload() } },
                        onChooseArea: dependencies.onChooseArea,
                        liveSpace: reduceMotion ? nil : liveSpace,
                        holdHidden: liveOnMap)
                    // The 附近 drawer slides away while a property is open over the map, or a walk runs on it.
                    .offset(y: drawerAway ? 320 : 0)
                    .opacity(drawerAway ? 0 : 1)
                    .allowsHitTesting(!drawerAway)
                    .animation(reduceMotion ? CityTokens.reducedFade : CYMotion.sheet, value: drawerAway)
                    if liveOnMap, let liveSession {
                        CityLiveMapControls(session: liveSession, space: reduceMotion ? nil : liveSpace,
                                            onEnded: { endLive(openLivePage: $0) })
                    }
                }
            }
            .overlay {
                if case .property(let id) = route, let place = store.place(id: id) {
                    CityPropertyDrawer(place: place, store: store, origin: pinOrigin?.id == id ? pinOrigin?.point : nil,
                                       captureFix: dependencies.captureFix,
                                       onRoute: { self.route = $0 }, onClose: { self.route = nil })
                        .id(id)
                        .transition(.identity)
                }
            }
            .cyHideTabBar(isPropertyOpen || liveOnMap)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CityRoamPush.self) { push in
                switch push {
                case .live: dependencies.liveDestination?().cyPushedChrome()
                case .board: CityBoardView(store: store, onOpen: { open($0) }, onMine: { path.append(CityRoamPush.mine) }, onLedger: { path.append(CityRoamPush.ledger) }).cyPushedChrome()
                case .mine: CityMyPropertiesView(store: store, onOpen: { open($0) }, onShield: { route = .shield($0.id) }, onUpgrade: { route = .upgrade($0.id) }).cyPushedChrome()
                case .ledger: CityRentLedgerView(store: store).cyPushedChrome()
                }
            }
            .sheet(item: sheetRoute) { route in
                CitySheetHost(route: route, store: store, captureFix: dependencies.captureFix, photoUploader: dependencies.photoUploader,
                              fixtureClaim: dependencies.fixtureClaim,
                              onRoute: { self.route = $0 },
                              onMoment: { next in self.route = nil; self.moment = next },
                              onMine: { self.route = nil; path.append(CityRoamPush.mine) },
                              onDismiss: { self.route = nil })
            }
            .cyFullScreenCover(item: $moment) { next in
                CityMomentHost(route: next, store: store, onDone: { moment = nil }, onMine: { moment = nil; path.append(CityRoamPush.mine) })
            }
            .cySheet(isPresented: $showsPassport) {
                dependencies.passportDestination?()
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selection) { _, id in if let id { open(id) } }
            .onChange(of: route) { _, value in if value == nil { selection = nil } }
            .onAppear { reattachLive() }
            .task {
                await locateAndLoad()
                if let initialRoute, store.place(id: initialRoute.placeID) != nil { route = initialRoute }
                await openDeepLink()
            }
            .onChange(of: links.pendingProperty) { _, id in if id != nil, store.phase != .idle { Task { await openDeepLink() } } }
            .onChange(of: store.places) { _, places in
                QuestWidgetBoardPublisher.cityPlaces(places)
                Task { await CityNotifications.sync(store: store, locale: locale) }
            }
            .onChange(of: store.lost) { _, lost in
                guard let first = lost.first else { return }
                store.acknowledgeLost()
                if route == nil && moment == nil { moment = .placeLost(first, compensation: nil) }
                Task { await CityNotifications.placeLost(first, locale: locale) }
            }
            .cityMonopolyHaptics(store.haptic, reduceMotion: reduceMotion)
        }
    }

    private var isPropertyOpen: Bool { if case .property = route { return true }; return false }
    private var drawerAway: Bool { isPropertyOpen || liveOnMap }

    // MARK: Live on the map (flagged)

    /// Hold committed. With the flag off, or when the live page has something to ask first (consent, location
    /// priming, recovery), this is the old push. Otherwise the capsule becomes the live controls on this map.
    private func startLive() {
        guard CityLiveOnMap.isEnabled, let makeController = dependencies.liveController else {
            path.append(CityRoamPush.live); return
        }
        let session = liveSession ?? CityLiveMapSession(controller: makeController())
        liveSession = session
        guard session.canRunInPlace(purposeAccepted: livePurposeAccepted) else { path.append(CityRoamPush.live); return }
        route = nil
        withAnimation(reduceMotion ? CityTokens.reducedFade : CYMotion.hero) { liveOnMap = true }
        let owner = session.controller
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(environmentSession: offlineWriteSession.session,
                                                                   routes: CityLiveOnMap.writeRoutes) {
                switch owner.phase {
                case .ready: await owner.start(purposeAccepted: true)
                case .paused: await owner.resume(purposeAccepted: true)
                default: break
                }
            }
            // A start refused before it left `.ready` never changes the phase: fold back here.
            if !session.isRunning { endLive(openLivePage: owner.phase != .ready) }
        }
    }

    /// Ending reverses the move: the controls fold into the capsule and the drawer comes back. The live page opens
    /// afterwards only when it has something to show (the finish report, recovery, a denied location).
    private func endLive(openLivePage: Bool) {
        guard liveOnMap else { return }
        withAnimation(reduceMotion ? CityTokens.reducedFade : CYMotion.hero) { liveOnMap = false }
        guard openLivePage else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 450))
            path.append(CityRoamPush.live)
        }
    }

    /// Back on the root (e.g. from the live page, which pauses the walk when it closes): observe the controller again
    /// and show a running walk's controls in place.
    private func reattachLive() {
        guard CityLiveOnMap.isEnabled, let makeController = dependencies.liveController else { return }
        let session = liveSession ?? CityLiveMapSession(controller: makeController())
        if liveSession == nil { liveSession = session } else { session.attach() }
        if session.isRunning && !liveOnMap { liveOnMap = true }
    }
    /// Every route but `.property` is a system sheet; the property opens in `CityPropertyDrawer` over the map.
    private var sheetRoute: Binding<CitySheetRoute?> {
        Binding(get: { isPropertyOpen ? nil : route }, set: { route = $0 })
    }

    private var map: some View {
        CityMapLayer(places: store.places, mode: mode, position: $position, selection: $selection,
                     center: center.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                     onPinPoint: { id, point in pinOrigin = (id, point) })
            .ignoresSafeArea()
            .overlay(alignment: .trailing) {
                VStack(spacing: CYSpacing.md) {
                    CityGlassCircle(systemImage: "location", label: copy("回到我的位置", "Back to my location")) {
                        Task { await locateAndLoad(recenter: true) }
                    }
                }
                .padding(.trailing, CYSpacing.pageHorizontal)
                .padding(.bottom, 120)
            }
            .accessibilityIdentifier("city.roam.map")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: copy("漫游", "Roam")).cyText(.pageTitle).foregroundStyle(palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Button { path.append(CityRoamPush.board) } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: statLine).cyText(.meta, monospacedDigit: true)
                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).accessibilityHidden(true)
                        }
                        .foregroundStyle(palette.textSecondary)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: copy("城市大富翁，", "City Monopoly, ") + statLine))
                    .accessibilityIdentifier("city.roam.board")
                }
                Spacer(minLength: CYSpacing.sm)
                HStack(spacing: CYSpacing.sm) {
                    CityGlassCircle(systemImage: "building.2", label: copy("城市大富翁", "City Monopoly")) { path.append(CityRoamPush.board) }
                    if dependencies.passportDestination != nil {
                        CityGlassCircle(systemImage: "book.closed", label: copy("漫游护照与工具", "Roam passport and tools")) { showsPassport = true }
                            .accessibilityIdentifier("city.roam.passport")
                    }
                }
            }
            HStack(spacing: CYSpacing.sm) {
                ForEach(CityMapLayerMode.allCases) { item in
                    chip(item)
                }
            }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.top, CYSpacing.sm)
        .padding(.bottom, CYSpacing.md)
        .background(alignment: .top) {
            LinearGradient(colors: [palette.bgPage.opacity(0.85), palette.bgPage.opacity(0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
    }

    private func chip(_ item: CityMapLayerMode) -> some View {
        let selected = mode == item
        return Button {
            withAnimation(reduceMotion ? CityTokens.reducedFade : CityTokens.pressSpring) { mode = item }
        } label: {
            Text(verbatim: item == .fog ? copy("迷雾", "Fog") : copy("领地", "Territory"))
                .cyText(.label)
                .foregroundStyle(selected ? palette.actionPrimaryFg : palette.textPrimary)
                .padding(.horizontal, CYSpacing.lg).frame(minHeight: 36)
                .background(selected ? AnyShapeStyle(palette.actionPrimaryBg) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityIdentifier("city.roam.layer.\(item.rawValue)")
    }

    private var statLine: String {
        var parts: [String] = []
        if let holdings = store.holdings { parts.append(copy("持有 \(holdings.count) / \(holdings.limit)", "Holding \(holdings.count) / \(holdings.limit)")) }
        if let rent = store.todayRent { parts.append(copy("今天 +\(rent)", "Today +\(rent)")) }
        if let balance = store.points?.balance { parts.append(copy.points(balance)) }
        return parts.isEmpty ? copy("城市大富翁", "City Monopoly") : parts.joined(separator: " · ")
    }

    private func open(_ place: CityPlace) { open(place.id) }
    private func open(_ id: String) {
        guard store.place(id: id) != nil else { return }
        route = .property(id)
        if let place = store.place(id: id) {
            // Keep the pin in view above the property drawer: centre the camera a quarter-span south of it.
            let span = 900.0 / 111_320
            let centre = CLLocationCoordinate2D(latitude: place.clCoordinate.latitude - span * 0.27, longitude: place.clCoordinate.longitude)
            withAnimation(reduceMotion ? CityTokens.reducedFade : CityTokens.sheetSpring) {
                position = .region(MKCoordinateRegion(center: centre, latitudinalMeters: 900, longitudinalMeters: 900))
            }
        }
    }

    /// The inbox card's link: back to the map (pop pushes, close the open sheet or moment), then the place's property
    /// sheet over the SAME map. A place outside the loaded window is located through its property read first.
    private func openDeepLink() async {
        guard let id = links.consume() else { return }
        path = NavigationPath()
        moment = nil
        route = nil
        guard let place = await store.locate(territoryId: id) else { return }
        open(place.id)
    }

    private func locateAndLoad(recenter: Bool = false) async {
        if let captureFix = dependencies.captureFix, let latest = try? await captureFix() { fix = latest }
        guard let center else { return }
        if recenter || position == .automatic {
            position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
                                                  latitudinalMeters: 1600, longitudinalMeters: 1600))
        }
        await store.load(center: center)
    }

    private func reload() async {
        guard let center else { await locateAndLoad(); return }
        await store.load(center: center)
    }
}

enum CityRoamPush: Hashable { case live, board, mine, ledger }

// MARK: - 附近 drawer

enum CityDrawerDetent { case peek, medium, large }

/// The 附近 sheet: a drawer above the tab bar (a system sheet would cover the tab bar on a tab
/// root). Detents 96 / medium / large; the map stays live under it. Drag or tap the grabber.
struct CityNearbyDrawer: View {
    @Binding var detent: CityDrawerDetent
    let places: [CityPlace]
    let origin: RoamCoordinate?
    let phase: CityBoardStore.Phase
    let holdEnabled: Bool
    let onHold: () -> Void
    let onSelect: (CityPlace) -> Void
    let onRetry: () -> Void
    var onChooseArea: (() -> Void)?
    /// The live-on-map namespace: the hold capsule grows into the pause pill (nil = no matched move).
    var liveSpace: Namespace.ID? = nil
    /// While a walk runs on the map the capsule lives in the controls; its slot keeps the drawer's height.
    var holdHidden = false

    @GestureState private var dragOffset: CGFloat = 0
    /// Height of the hold button + 附近 heading block, so the resting detent always shows the top of the first row.
    @State private var headBlock: CGFloat = 120
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var visible: [CityPlace] { places.filter { $0.ownership != .fogged } }

    var body: some View {
        GeometryReader { proxy in
            let height = heightFor(detent, in: proxy.size.height)
            VStack(spacing: 0) {
                grabber
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                    if holdHidden {
                        Color.clear.frame(height: 52).accessibilityHidden(true)
                    } else {
                        CityHoldButton(title: copy("按住 0.8 秒开始漫游", "Hold 0.8 s to start roaming"),
                                       holdingTitle: copy("松手取消", "Release to cancel"), enabled: holdEnabled, onCommit: onHold)
                            .cityMatched(CityLiveOnMap.capsuleID, in: liveSpace)
                    }
                    HStack {
                        Text(verbatim: copy("附近 · \(visible.count)", "Nearby · \(visible.count)"))
                            .cyText(.sectionTitle).foregroundStyle(palette.textPrimary).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if detent != .large {
                            Button { set(.large) } label: {
                                HStack(spacing: 2) { Text(verbatim: copy("全部", "All")); Image(systemName: "chevron.right").imageScale(.small) }
                                    .cyText(.meta).foregroundStyle(palette.textSecondary).frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headBlock = $0 }
                    content
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: max(96, height - dragOffset), alignment: .top)
            .background {
                // Material over the live map at the partial detents, opaque when expanded (xrefs-1 Adopt 11).
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                    .fill(reduceTransparency || detent == .large ? AnyShapeStyle(palette.bgElevated) : AnyShapeStyle(.regularMaterial))
                    .shadow(color: .black.opacity(0.4), radius: 16, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(reduceMotion ? CityTokens.reducedFade : CityTokens.sheetSpring, value: detent)
        }
        .frame(height: nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("city.roam.nearby")
    }

    private var grabber: some View {
        Capsule().fill(palette.textTertiary.opacity(0.6)).frame(width: 36, height: 5)
            .frame(minWidth: CYSpacing.minTouchTarget, maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4)
                .updating($dragOffset) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let dy = value.translation.height + value.velocity.height * 0.1
                    if dy < -60 { set(detent == .peek ? .medium : .large) } else if dy > 60 { set(detent == .large ? .medium : .peek) }
                })
            .onTapGesture { set(detent == .peek ? .medium : .peek) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: copy("附近列表", "Nearby list")))
            .accessibilityValue(Text(verbatim: detent == .peek ? copy("已收起", "Collapsed") : copy("已展开", "Expanded")))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { set(detent == .peek ? .medium : .peek) }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .unavailable:
            CityEmptyLine(symbol: "map", text: copy("城市大富翁在这个版本里没有开放。", "City Monopoly is not open in this build."))
        case .failed(let code):
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CityEmptyLine(symbol: "wifi.exclamationmark", text: CityReasonCopy.text(code, chinese: copy.chinese))
                CYPillButton(verbatim: copy("重试", "Retry"), style: .secondary, fullWidth: false, action: onRetry)
            }
        case .idle:
            VStack(spacing: CYSpacing.sm) { ForEach(0..<3, id: \.self) { _ in CYSkeleton().frame(height: 72) } }
        case .loading where visible.isEmpty:
            VStack(spacing: CYSpacing.sm) { ForEach(0..<3, id: \.self) { _ in CYSkeleton().frame(height: 72) } }
        default:
            if visible.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CityEmptyLine(symbol: "mappin.slash", text: copy("附近 3 公里内还没有棋盘地点。换个街区看看。", "No board places within 3 km. Try another area."))
                    if let onChooseArea { CYPillButton(verbatim: copy("选择区域", "Choose area"), style: .secondary, fullWidth: false, action: onChooseArea) }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: CYSpacing.sm) {
                        ForEach(visible) { place in
                            Button { onSelect(place) } label: {
                                CityDeedCard(place: place, size: .row, trailing: place.ownership == .open ? .price : .status)
                                    .overlay(alignment: .bottomTrailing) {
                                        if let text = copy.distance(place.distance(from: origin)) {
                                            Text(verbatim: text).cyText(.caption, monospacedDigit: true).foregroundStyle(palette.textTertiary)
                                                .padding(.trailing, CYSpacing.md).padding(.bottom, 6)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("city.nearby.\(place.id)")
                        }
                    }
                    .padding(.bottom, 120)
                }
                .scrollDisabled(detent == .peek)
            }
        }
    }

    private func heightFor(_ detent: CityDrawerDetent, in total: CGFloat) -> CGFloat {
        switch detent {
        // Grabber 24 + the head block + 12 + the top 44 pt of the first row, so a place always peeks above the tab bar.
        case .peek: return 24 + headBlock + CYSpacing.md + 44
        case .medium: return max(total * 0.5, 24 + headBlock + CYSpacing.md + 72 * 2 + CYSpacing.sm)
        case .large: return total * 0.86
        }
    }

    private func set(_ next: CityDrawerDetent) {
        withAnimation(reduceMotion ? CityTokens.reducedFade : CityTokens.sheetSpring) { detent = next }
    }
}

/// mp-states r3: the one empty pattern — a system ContentUnavailableView (symbol + the sentence), not a raised card.
struct CityEmptyLine: View {
    let symbol: String
    let text: String
    var body: some View {
        ContentUnavailableView {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        } description: {
            Text(verbatim: text)
        }
        .accessibilityElement(children: .combine)
    }
}
