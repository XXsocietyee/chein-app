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
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: drawer == .peek ? 160 : 0) }
            .overlay(alignment: .bottom) {
                CityNearbyDrawer(detent: $drawer, places: store.places, origin: center, phase: store.phase,
                    holdEnabled: dependencies.liveDestination != nil,
                    onHold: { path.append(CityRoamPush.live) },
                    onSelect: { open($0) },
                    onRetry: { Task { await reload() } },
                    onChooseArea: dependencies.onChooseArea)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CityRoamPush.self) { push in
                switch push {
                case .live: dependencies.liveDestination?().cyPushedChrome()
                case .board: CityBoardView(store: store, onOpen: { open($0) }, onMine: { path.append(CityRoamPush.mine) }, onLedger: { path.append(CityRoamPush.ledger) }).cyPushedChrome()
                case .mine: CityMyPropertiesView(store: store, onOpen: { open($0) }, onShield: { route = .shield($0.id) }, onUpgrade: { route = .upgrade($0.id) }).cyPushedChrome()
                case .ledger: CityRentLedgerView(store: store).cyPushedChrome()
                }
            }
            .sheet(item: $route) { route in
                CitySheetHost(route: route, store: store, captureFix: dependencies.captureFix, photoUploader: dependencies.photoUploader,
                              fixtureClaim: dependencies.fixtureClaim,
                              onRoute: { self.route = $0 },
                              onMoment: { next in self.route = nil; self.moment = next },
                              onDismiss: { self.route = nil })
            }
            .fullScreenCover(item: $moment) { next in
                CityMomentHost(route: next, store: store, onDone: { moment = nil }, onMine: { moment = nil; path.append(CityRoamPush.mine) })
            }
            .sheet(isPresented: $showsPassport) {
                dependencies.passportDestination?()
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: selection) { _, id in if let id { open(id) } }
            .onChange(of: route) { _, value in if value == nil { selection = nil } }
            .task {
                await locateAndLoad()
                if let initialRoute, store.place(id: initialRoute.placeID) != nil { route = initialRoute }
            }
            .onChange(of: store.places) { _, _ in Task { await CityNotifications.sync(store: store, locale: locale) } }
            .onChange(of: store.lost) { _, lost in
                guard let first = lost.first else { return }
                store.acknowledgeLost()
                if route == nil && moment == nil { moment = .placeLost(first, compensation: nil) }
                Task { await CityNotifications.placeLost(first, locale: locale) }
            }
            .cityMonopolyHaptics(store.haptic, reduceMotion: reduceMotion)
        }
    }

    private var map: some View {
        CityMapLayer(places: store.places, mode: mode, position: $position, selection: $selection,
                     center: center.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
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
                    Text(verbatim: copy("漫游", "Roam")).font(CYTypography.pageTitle).foregroundStyle(palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Button { path.append(CityRoamPush.board) } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: statLine).font(CYTypography.meta.monospacedDigit())
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
                .font(CYTypography.label)
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
            withAnimation(reduceMotion ? CityTokens.reducedFade : CityTokens.sheetSpring) {
                position = .region(MKCoordinateRegion(center: place.clCoordinate, latitudinalMeters: 900, longitudinalMeters: 900))
            }
        }
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

    @GestureState private var dragOffset: CGFloat = 0
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
                    CityHoldButton(title: copy("按住 0.8 秒开始漫游", "Hold 0.8 s to start roaming"),
                                   holdingTitle: copy("松手取消", "Release to cancel"), enabled: holdEnabled, onCommit: onHold)
                    HStack {
                        Text(verbatim: copy("附近 · \(visible.count)", "Nearby · \(visible.count)"))
                            .font(CYTypography.sectionTitle).foregroundStyle(palette.textPrimary).accessibilityAddTraits(.isHeader)
                        Spacer()
                        if detent != .large {
                            Button { set(.large) } label: {
                                HStack(spacing: 2) { Text(verbatim: copy("全部", "All")); Image(systemName: "chevron.right").imageScale(.small) }
                                    .font(CYTypography.meta).foregroundStyle(palette.textSecondary).frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    content
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: max(96, height - dragOffset), alignment: .top)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                    .fill(reduceTransparency ? AnyShapeStyle(palette.bgElevated) : AnyShapeStyle(palette.bgElevated.opacity(0.96)))
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
            .frame(maxWidth: .infinity, minHeight: 24)
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
                                            Text(verbatim: text).font(CYTypography.caption.monospacedDigit()).foregroundStyle(palette.textTertiary)
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
        case .peek: return 176
        case .medium: return total * 0.5
        case .large: return total * 0.86
        }
    }

    private func set(_ next: CityDrawerDetent) {
        withAnimation(reduceMotion ? CityTokens.reducedFade : CityTokens.sheetSpring) { detent = next }
    }
}

struct CityEmptyLine: View {
    let symbol: String
    let text: String
    @Environment(\.cyPalette) private var palette
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: symbol).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            Text(verbatim: text).font(CYTypography.bodyCompact).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.md)
        .background(palette.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
