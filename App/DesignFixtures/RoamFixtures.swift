#if DEBUG
import SwiftUI

/// Roam hero fixtures. Each mounts the REAL kit (`CYGoPressStyle`, `CYFogLayer`, `CYRevealToast`, `CYRoamNearbySheet`,
/// `CYRoamNearbyCard`, `CYRoamPin`) on the static placeholder map with synthetic, clearly labelled data; nothing ships in Release.
/// Reach with `--design-fixture roam-<name>`; add `--uitesting-reduce-motion` for the Reduce Motion fallback (static fog edge).
///
/// | name | shows |
/// |---|---|
/// | `roam-go` | idle: 72 pt GO pill; hold 600 ms (ring fills in three segments, ticks at 200/400 ms), release early cancels, commit shrinks the pill into the bottom-right puck with a wave across the map; Reduce Motion: tap + confirm |
/// | `roam-go-demo` | `roam-go` scripted for video: early release (cancel), full hold, commit, walking, loop (Reduce Motion: tap-equivalent commit) |
/// | `roam-walking` | walking: bottom-right puck, lantern fog edge breathing on a 2.2 s cycle (static under Reduce Motion), player dot |
/// | `roam-reveal` | walking + "new area revealed" toast, percent counting up, fog edge pushes out (loops every 5 s) |
/// | `roam-sheet-half` | nearby sheet at half detent, second card selected, its pin highlighted |
/// | `roam-paused` | paused: static fog edge, resume glyph on the circle |
/// | `roam-fog-engine` | fog engine, dark basemap, ~25 %: haze scrim, feathered clear ground with warm frontier glow, dashed shimmer outline on 3 unconfirmed cells, player dot, 480 ms wipes along a replayed walk |
/// | `roam-fog-unknown` | coverage unknown, nothing loaded: whole map fogged, no player, the badge prints an em dash, never 0 |
/// | `roam-fog-high` | ~80 % explored with unconfirmed pockets (static) |
/// | `roam-fog-light` | the replay state on a light basemap |
enum RoamFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "roam-go": return wrap(RoamFixtureStage(initial: .idle))
        case "roam-go-demo": return wrap(RoamFixtureStage(initial: .idle, goDemo: true))
        case "roam-walking": return wrap(RoamFixtureStage(initial: .walking))
        case "roam-reveal": return wrap(RoamFixtureStage(initial: .walking, loopReveal: true))
        case "roam-sheet-half": return wrap(RoamFixtureStage(initial: .idle, sheet: .half, selected: "b"))
        case "roam-paused": return wrap(RoamFixtureStage(initial: .paused))
        case "roam-fog-engine": return wrap(RoamFogEngineFixture(unknown: nil))
        case "roam-fog-unknown": return wrap(RoamFogEngineFixture(unknown: .permissionMissing))
        case "roam-fog-high": return wrap(RoamFogEngineFixture(high: true))
        case "roam-fog-light": return wrap(RoamFogEngineFixture(light: true))
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
    var goDemo = false
    @State private var phase: RoamPhase
    @State private var wave = 0
    @State private var demoPress = false
    @Namespace private var goNamespace
    @State private var detent: CYRoamSheetDetent
    @State private var selectedID: String?
    @State private var toast = false
    @State private var tick = 0
    @State private var percent: Int? = 38
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    private var items: [CYRoamNearbyItem] { RoamFixtures.items(locale: locale) }

    init(initial: RoamPhase, sheet: CYRoamSheetDetent = .peek, selected: String? = nil, loopReveal: Bool = false, goDemo: Bool = false) {
        self.initial = initial; self.sheet = sheet; self.selected = selected; self.loopReveal = loopReveal; self.goDemo = goDemo
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
                goControl(geo).opacity(detent == .peek ? 1 : 0)
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
        .task(id: goDemo) {
            guard goDemo else { return }
            while !Task.isCancelled {
                phase = .idle
                try? await Task.sleep(for: .milliseconds(1400))
                if reduceMotion {
                    try? await Task.sleep(for: .milliseconds(800))
                    commitGo()
                } else {
                    demoPress = true; try? await Task.sleep(for: .milliseconds(330)); demoPress = false   // early release cancels
                    try? await Task.sleep(for: .milliseconds(1200))
                    demoPress = true                                                                       // full hold commits at 600 ms
                }
                try? await Task.sleep(for: .milliseconds(5200))
                demoPress = false
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

    private func commitGo() {
        withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance) { phase = .walking }
        tick += 1
        wave += 1
    }

    /// Idle: the hold pill. Walking: the puck it shrinks into. Other phases keep the round glyph button.
    @ViewBuilder private func goControl(_ geo: GeometryProxy) -> some View {
        let bottom = geo.size.height * (1 - (sheet == .peek ? 0.74 : 0.30)) - 50
        VStack {
            Spacer()
            HStack(spacing: 0) {
                switch phase {
                case .idle:
                    Spacer(minLength: 0)
                    CYGoHoldPill(demoPress: demoPress) { commitGo() }.matchedGeometryEffect(id: "go", in: goNamespace)
                    Spacer(minLength: 0)
                case .walking:
                    Spacer(minLength: 0)
                    CYGoPuck().matchedGeometryEffect(id: "go", in: goNamespace)
                default:
                    Spacer(minLength: 0)
                    goButton
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, CYSpacing.lg).padding(.bottom, bottom)
        }
        .overlay(alignment: .bottomTrailing) {
            Color.clear.frame(width: 44, height: 44)
                .overlay { CYGoWave(trigger: wave).frame(width: 1600, height: 1600) }
                .padding(.trailing, CYSpacing.lg).padding(.bottom, bottom)
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
        case .idle, .paused: commitGo()
        case .walking: phase = .paused
        case .starting, .finishing, .finished, .blocked: break
        }
    }
}

/// Light stand-in basemap for the fog fixtures (the dark one is `CYMapStreetGrid`). DEBUG only.
private struct FogLightBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.95, green: 0.94, blue: 0.91)))
            ctx.fill(Path(CGRect(x: size.width * 0.52, y: size.height * 0.10, width: size.width * 0.34, height: size.height * 0.14)), with: .color(Color(red: 0.84, green: 0.90, blue: 0.80)))
            ctx.fill(Path(CGRect(x: 0, y: size.height * 0.58, width: size.width * 0.30, height: size.height * 0.16)), with: .color(Color(red: 0.84, green: 0.90, blue: 0.80)))
            var water = Path()
            water.move(to: CGPoint(x: size.width, y: size.height * 0.30)); water.addCurve(to: CGPoint(x: 0, y: size.height * 0.86), control1: CGPoint(x: size.width * 0.6, y: size.height * 0.34), control2: CGPoint(x: size.width * 0.5, y: size.height * 0.8))
            ctx.stroke(water, with: .color(Color(red: 0.76, green: 0.86, blue: 0.92)), lineWidth: 40)
            var x: CGFloat = 10; var i = 0
            while x < size.width + 60 {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 14, y: size.height))
                ctx.stroke(p, with: .color(.white), lineWidth: i % 4 == 0 ? 9 : 4); x += 62; i += 1
            }
            var y: CGFloat = 20; i = 0
            while y < size.height + 60 {
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y - 16))
                ctx.stroke(p, with: .color(.white), lineWidth: i % 3 == 0 ? 9 : 4); y += 58; i += 1
            }
        }
        .ignoresSafeArea().accessibilityHidden(true)
    }
}

/// Fog engine stages 2 and 3 on the Shanghai People's Square walk (`FogFixtures`): a real `FogCellBitmap` rasterized by
/// `FogMaskRasterizer`, feathered by `FogMaskImages` and drawn by `FogOverlayLayer` over a DEBUG basemap (dark or light):
/// haze scrim with vignette and noise, clear explored ground with a warm frontier glow, dashed shimmering outline on
/// unconfirmed cells, a pulsing player dot and `RevealChoreographer` wipes. Three states:
/// - replay (default): ~25 % explored, three unconfirmed cells, the walk keeps extending;
/// - `unknown`: nothing loaded, the badge prints an em dash and the whole map is fogged;
/// - `high`: ~80 % explored with a few unconfirmed pockets (static).
/// The coordinates are literal fixtures, not a person's trail.
private struct RoamFogEngineFixture: View {
    var unknown: FogCoverageReading.UnknownReason? = nil
    var high = false
    var light = false
    private static let center = RoamCoordinate(latitude: 31.2354, longitude: 121.4790)!
    private static let ground = 3.0
    /// The first two legs of the walk (the third is ~2 km away and off this window).
    private static let walkCodes: [String] = FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk).filter {
        (FogGeohash.bounds(of: $0)?.south ?? 0) > 31.225
    }
    private static let seedCount = 8
    private static let replayArea = 32
    /// Ahead of the walker, not yet confirmed by the server.
    private static let pendingCodes: [String] = [(31.2304, 121.4843), (31.2304, 121.4857), (31.2313, 121.4843)]
        .compactMap { RoamCoordinate(latitude: $0.0, longitude: $0.1).flatMap { RoamExperienceMath.tileKey($0) } }
        .filter { !RoamFogEngineFixture.walkCodes.contains($0) }

    /// A superellipse of cells around the centre with ~6 % pockets; the first four pockets are unconfirmed.
    private static let highSets: (confirmed: [String], pending: [String], area: Int) = {
        var area = Set<String>(), confirmed: [String] = [], pockets: [String] = []
        var lat = center.latitude - 0.0105
        while lat <= center.latitude + 0.0105 {
            var lng = center.longitude - 0.0058
            while lng <= center.longitude + 0.0058 {
                defer { lng += 0.0009 }
                guard let c = RoamCoordinate(latitude: lat, longitude: lng), let code = RoamExperienceMath.tileKey(c), area.insert(code).inserted else { continue }
                let nx = (lng - center.longitude) / 0.0058, ny = (lat - center.latitude) / 0.0105
                guard pow(abs(nx), 3) + pow(abs(ny), 3) < 1 else { continue }
                let hash = code.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
                if hash % 100 < 6 { pockets.append(code) } else { confirmed.append(code) }
            }
            lat += 0.0009
        }
        return (confirmed, Array(pockets.sorted().prefix(4)), area.count)
    }()

    @State private var confirmed: FogCellBitmap
    @State private var pending: FogCellBitmap
    @State private var revision = 1
    @State private var choreo: RevealChoreographer?
    @State private var player: RoamCoordinate?
    @QuestifyReduceMotion private var reduceMotion

    init(unknown: FogCoverageReading.UnknownReason? = nil, high: Bool = false, light: Bool = false) {
        self.unknown = unknown; self.high = high; self.light = light
        if unknown != nil {
            _confirmed = State(initialValue: FogCellBitmap()); _pending = State(initialValue: FogCellBitmap()); _player = State(initialValue: nil)
        } else if high {
            _confirmed = State(initialValue: (try? FogFixtures.bitmap(Self.highSets.confirmed)) ?? FogCellBitmap())
            _pending = State(initialValue: (try? FogFixtures.bitmap(Self.highSets.pending)) ?? FogCellBitmap())
            _player = State(initialValue: Self.center)
        } else {
            _confirmed = State(initialValue: (try? FogFixtures.bitmap(Array(Self.walkCodes.prefix(Self.seedCount)))) ?? FogCellBitmap())
            _pending = State(initialValue: (try? FogFixtures.bitmap(Self.pendingCodes)) ?? FogCellBitmap())
            let last = FogGeohash.bounds(of: Self.walkCodes[Self.seedCount - 1])
            _player = State(initialValue: last.flatMap { RoamCoordinate(latitude: ($0.south + $0.north) / 2, longitude: ($0.west + $0.east) / 2) })
        }
    }

    private var reading: FogCoverageReading {
        if let unknown { return .unknown(unknown) }
        // Denominator: the fixture window's cells, a stand-in for the selected search-area grid.
        return .known(confirmed: confirmed.count, pending: pending.count, areaCells: high ? Self.highSets.area : Self.replayArea)
    }

    var body: some View {
        ZStack(alignment: .top) {
            if light { FogLightBackdrop() } else { CYMapStreetGrid() }
            GeometryReader { geometry in
                let viewport = FogWindowGeometry.viewport(center: Self.center, pointSize: geometry.size, groundMetersPerPoint: Self.ground)
                FogViewportLayer(fog: FogPresentation(confirmed: confirmed, pending: pending, revision: revision, coverage: reading, datum: .gcj02, player: player),
                                 viewport: viewport, size: geometry.size, reveal: choreo, style: .reveal(light ? .day : .night))
            }.ignoresSafeArea()
            VStack {
                HStack {
                    Text(verbatim: "Fog engine").font(.title2.weight(.heavy)).foregroundStyle(light ? Color.black : Color.white)
                    Spacer()
                    CYFogCoverageBadge(reading: CYFogCoverageReading(reading))
                }.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.xxl)
                Spacer()
            }
        }
        .cyHaptic(.success, trigger: choreo?.hapticSuccessSerial ?? 0, where: { old, new in new > old })
        .cyHaptic(.impactLight, trigger: choreo?.hapticLightSerial ?? 0, where: { old, new in new > old })
        .task {
            guard unknown == nil, !high else { return }
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
                player = origin
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
