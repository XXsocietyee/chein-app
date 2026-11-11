#if DEBUG
import SwiftUI

/// Roam hero fixtures. Each mounts the REAL kit (`CYGoPressStyle`, `CYFogLayer`, `CYRevealToast`, `CYRoamNearbySheet`,
/// `CYRoamNearbyCard`, `CYRoamPin`) on the static placeholder map with synthetic, clearly labelled data; nothing ships in Release.
/// Reach with `--design-fixture roam-<name>`; add `--uitesting-reduce-motion` for the Reduce Motion fallback (static fog edge).
///
/// | name | shows |
/// |---|---|
/// | `roam-go` | idle: GO with the breathing ring; press and hold for the feel, release to start walking |
/// | `roam-walking` | walking: slow breathing ring, animated fog edge, player dot |
/// | `roam-reveal` | walking + "new area revealed" toast, percent counting up, fog edge pushes out (loops every 5 s) |
/// | `roam-sheet-half` | nearby sheet at half detent, second card selected, its pin highlighted |
/// | `roam-paused` | paused: static fog edge, resume glyph on the circle |
/// | `roam-fog-engine` | fog engine stages: mask scrim + hatch for unconfirmed cells, 480 ms radial wipes along a replayed walk, coverage badge |
/// | `roam-fog-unknown` | same layer with coverage unknown: the badge prints an em dash, never 0 |
enum RoamFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "roam-go": return wrap(RoamFixtureStage(initial: .idle))
        case "roam-walking": return wrap(RoamFixtureStage(initial: .walking))
        case "roam-reveal": return wrap(RoamFixtureStage(initial: .walking, loopReveal: true))
        case "roam-sheet-half": return wrap(RoamFixtureStage(initial: .idle, sheet: .half, selected: "b"))
        case "roam-paused": return wrap(RoamFixtureStage(initial: .paused))
        case "roam-fog-engine": return wrap(RoamFogEngineFixture(unknown: nil))
        case "roam-fog-unknown": return wrap(RoamFogEngineFixture(unknown: .permissionMissing))
        default: return nil
        }
    }

    private static let rows: [(id: String, title: String, category: String, meters: Double, symbol: String)] = [
        ("a", "Dongmen Night Market", "market", 240, "cart"),
        ("b", "Laojie Teahouse", "tea", 380, "cup.and.saucer"),
        ("c", "Binjiang Park Stage", "event", 520, "music.note"),
        ("d", "Lane 9 Bookshop", "books", 610, "book"),
        ("e", "Harbor Roof", "viewpoint", 790, "binoculars"),
    ]

    private static func category(_ id: String, locale: Locale) -> String {
        switch id {
        case "market": return appLocalized("roam.nearby.cat.market", locale: locale)
        case "tea": return appLocalized("roam.nearby.cat.tea", locale: locale)
        case "event": return appLocalized("roam.nearby.cat.event", locale: locale)
        case "books": return appLocalized("roam.nearby.cat.books", locale: locale)
        default: return appLocalized("roam.nearby.cat.viewpoint", locale: locale)
        }
    }

    /// Category and distance are localized for the in-app language (catalog keys + a locale-aware `MeasurementFormatter`).
    static func items(locale: Locale) -> [CYRoamNearbyItem] {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitStyle = .medium
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        return rows.map { row in
            let category = Self.category(row.category, locale: locale)
            let distance = formatter.string(from: Measurement(value: row.meters, unit: UnitLength.meters))
            return CYRoamNearbyItem(id: row.id, title: row.title, meta: appLocalized("roam.nearby.meta \(category) \(distance)", locale: locale), symbol: row.symbol)
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.preferredColorScheme(.dark).background(Color.black.ignoresSafeArea()))
    }
}

private struct RoamFixtureStage: View {
    var initial: RoamPhase
    var sheet: CYRoamSheetDetent = .peek
    var selected: String?
    var loopReveal = false
    @State private var phase: RoamPhase
    @State private var detent: CYRoamSheetDetent
    @State private var selectedID: String?
    @State private var toast = false
    @State private var tick = 0
    @State private var percent: Int? = 38
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    private var items: [CYRoamNearbyItem] { RoamFixtures.items(locale: locale) }

    init(initial: RoamPhase, sheet: CYRoamSheetDetent = .peek, selected: String? = nil, loopReveal: Bool = false) {
        self.initial = initial; self.sheet = sheet; self.selected = selected; self.loopReveal = loopReveal
        _phase = State(initialValue: initial)
        _detent = State(initialValue: sheet)
        _selectedID = State(initialValue: selected)
    }

    private let pinSpots: [String: CGPoint] = ["a": CGPoint(x: 0.30, y: 0.30), "b": CGPoint(x: 0.66, y: 0.26), "c": CGPoint(x: 0.50, y: 0.58),
                                                "d": CGPoint(x: 0.22, y: 0.56), "e": CGPoint(x: 0.78, y: 0.52)]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CYMapPlaceholder(fog: false)
                CYFogLayer(explored: 0.38, trail: [CGPoint(x: 0.34, y: 0.62), CGPoint(x: 0.42, y: 0.74), CGPoint(x: 0.6, y: 0.7)],
                           revealTick: tick, radiusScale: phase.fogRadiusScale, animated: phase.animatesFog)
                    .ignoresSafeArea()
                ForEach(items) { item in
                    if let spot = pinSpots[item.id] {
                        CYRoamPin(symbol: item.symbol, selected: selectedID == item.id)
                            .position(x: geo.size.width * spot.x, y: geo.size.height * spot.y)
                    }
                }
                CYRoamPlayerDot(walking: phase == .walking).position(x: geo.size.width * 0.5, y: geo.size.height * 0.46)
                VStack {
                    HStack {
                        Text(verbatim: "Roam").font(.largeTitle.weight(.heavy)).foregroundStyle(.white)
                        Spacer()
                        CYRoamStatusDot(phase: phase)
                    }.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.xxl)
                    if toast {
                        CYRevealToast(percent: percent).transition(reduceMotion ? .opacity : .cyRevealToast)
                    }
                    Spacer()
                }
                goButton.position(x: geo.size.width * 0.5, y: geo.size.height * (sheet == .peek ? 0.74 : 0.30))
                    .opacity(detent == .peek ? 1 : 0)
                CYRoamNearbySheet(detent: $detent) {
                    Text(verbatim: appLocalized("roam.nearby.header \(items.count)", locale: locale)).font(.headline).foregroundStyle(CYColor.textPrimary)
                } content: {
                    ScrollView {
                        LazyVStack(spacing: CYSpacing.sm) {
                            ForEach(items) { item in
                                CYRoamNearbyCard(item: item, selected: selectedID == item.id) { selectedID = item.id }
                            }
                        }.padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                    }
                }
            }
        }
        .task(id: loopReveal) {
            guard loopReveal else { return }
            var step = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                percent = 38 + step * 3; tick += 1
                withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance) { toast = true }
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { toast = false }
                try? await Task.sleep(for: .seconds(1.4))
                step = (step + 1) % 4
            }
        }
    }

    /// Exhaustive over `RoamPhase`: the circle artwork and what a tap does.
    @ViewBuilder private var goButton: some View {
        Button { advance() } label: {
            switch phase {
            case .idle: CYGoLabel()
            case .starting: CYGoLabel(symbol: "location.fill")
            case .walking: CYGoLabel(symbol: "figure.walk")
            case .paused: CYGoLabel(symbol: "play.fill")
            case .finishing: CYGoLabel(symbol: "flag.checkered")
            case .finished: CYGoLabel(symbol: "checkmark")
            case .blocked: CYGoLabel(symbol: "location.slash")
            }
        }
        .buttonStyle(CYGoPressStyle(walking: phase == .walking))
        .accessibilityLabel(Text("GO"))
    }

    private func advance() {
        switch phase {
        case .idle, .paused: phase = .walking
        case .walking: phase = .paused
        case .starting, .finishing, .finished, .blocked: break
        }
    }
}

/// Fog engine stages 2 and 3 on the Shanghai People's Square walk (`FogFixtures`): a real `FogCellBitmap` rasterized by
/// `FogMaskRasterizer` and drawn by `FogOverlayLayer` over the DEBUG street-grid backdrop, with soft edges, a dark-theme
/// scrim, hatch on unconfirmed cells and `RevealChoreographer` wipes. The coordinates are literal fixtures, not a person's trail.
private struct RoamFogEngineFixture: View {
    let unknown: FogCoverageReading.UnknownReason?
    private static let center = RoamCoordinate(latitude: 31.2375, longitude: 121.4783)!
    /// The first two legs of the walk (the third is ~2 km away and off this window).
    private static let walkCodes: [String] = FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk).filter {
        (FogGeohash.bounds(of: $0)?.south ?? 0) > 31.225
    }
    private static let seedCount = 8
    /// Ahead of the walker, not yet confirmed by the server.
    private static let pendingCodes: [String] = [(31.2304, 121.4845), (31.2304, 121.4856), (31.2313, 121.4845)]
        .compactMap { RoamCoordinate(latitude: $0.0, longitude: $0.1).flatMap { RoamExperienceMath.tileKey($0) } }
        .filter { !RoamFogEngineFixture.walkCodes.contains($0) }

    @State private var confirmed = (try? FogFixtures.bitmap(Array(RoamFogEngineFixture.walkCodes.prefix(RoamFogEngineFixture.seedCount)))) ?? FogCellBitmap()
    @State private var pending = (try? FogFixtures.bitmap(RoamFogEngineFixture.pendingCodes)) ?? FogCellBitmap()
    @State private var revision = 1
    @State private var choreo: RevealChoreographer?
    @QuestifyReduceMotion private var reduceMotion

    private var reading: FogCoverageReading {
        if let unknown { return .unknown(unknown) }
        // Denominator: the fixture window's cells, a stand-in for the selected search-area grid.
        return .known(confirmed: confirmed.count, pending: pending.count, areaCells: Self.walkCodes.count + Self.pendingCodes.count + 24)
    }

    var body: some View {
        ZStack(alignment: .top) {
            CYMapStreetGrid()
            GeometryReader { geometry in
                let viewport = FogWindowGeometry.viewport(center: Self.center, pointSize: geometry.size, groundMetersPerPoint: 5)
                FogViewportLayer(fog: FogPresentation(confirmed: confirmed, pending: pending, revision: revision, coverage: reading, datum: .gcj02),
                                 viewport: viewport, size: geometry.size, reveal: choreo, style: .darkFixture)
            }.ignoresSafeArea()
            VStack {
                HStack {
                    Text(verbatim: "Fog engine").font(.title2.weight(.heavy)).foregroundStyle(.white)
                    Spacer()
                    CYFogCoverageBadge(reading: CYFogCoverageReading(reading))
                }.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.xxl)
                Spacer()
            }
        }
        .cyHaptic(.success, trigger: choreo?.hapticSuccessSerial ?? 0, where: { old, new in new > old })
        .cyHaptic(.impactLight, trigger: choreo?.hapticLightSerial ?? 0, where: { old, new in new > old })
        .task {
            let rm = reduceMotion
            let driver = RevealChoreographer(reduceMotion: { rm }, lowPower: { FogPowerState.constrained })
            choreo = driver
            var step = Self.seedCount
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                guard step < Self.walkCodes.count, let cell = Self.cell(Self.walkCodes[step]),
                      let origin = RoamCoordinate(latitude: (cell.south + cell.north) / 2, longitude: (cell.west + cell.east) / 2) else {
                    // End of the replay: start over from the seed.
                    step = Self.seedCount
                    confirmed = (try? FogFixtures.bitmap(Array(Self.walkCodes.prefix(Self.seedCount)))) ?? FogCellBitmap()
                    revision += 1
                    continue
                }
                bake(driver.enqueue(FogRevealEvent(cells: [cell], origin: origin, at: Date())))
                try? await Task.sleep(for: .milliseconds(600))
                bake(driver.settle())
                step += 1
            }
        }
    }

    private func bake(_ cells: [FogRenderCell]) {
        guard !cells.isEmpty else { return }
        for cell in cells { try? confirmed.insert(FogCell(grid: .legacyRoamTile, code: cell.code)) }
        revision += 1
    }

    private static func cell(_ code: String) -> FogRenderCell? {
        FogGeohash.bounds(of: code).map { FogRenderCell(code: code, south: $0.south, west: $0.west, north: $0.north, east: $0.east, state: .confirmed, datum: .gcj02) }
    }
}
#endif
