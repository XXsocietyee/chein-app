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

/// Fog engine stages 2 and 3 on a replayed walk over a synthetic grid (no location, no Core types, switches off).
private struct RoamFogEngineFixture: View {
    let unknown: CYFogCoverageReading.UnknownReason?
    private static let cols = 16, rows = 24
    private static let path: [CYFogPoint] = [(7, 12), (8, 12), (8, 11), (9, 11), (10, 11), (10, 10), (11, 10), (11, 9), (12, 9), (12, 8), (13, 8), (13, 7)].map { CYFogPoint(x: $0.0, y: $0.1) }
    private static let seedCells: Set<CYFogPoint> = Set((5...8).flatMap { x in (11...13).map { CYFogPoint(x: x, y: $0) } })
    @State private var confirmed: Set<CYFogPoint> = RoamFogEngineFixture.seedCells
    @State private var pending: Set<CYFogPoint> = [CYFogPoint(x: 4, y: 14), CYFogPoint(x: 5, y: 14), CYFogPoint(x: 4, y: 15)]
    @State private var choreo = CYRevealChoreographer()
    @State private var mask = CYFogMaskRasterizer.rasterize(confirmed: RoamFogEngineFixture.seedCells, pending: [], cols: 16, rows: 24, revision: 0)
    @State private var revision = 0
    @QuestifyReduceMotion private var reduceMotion

    private var reading: CYFogCoverageReading {
        if let unknown { return .unknown(unknown) }
        return .known(confirmed: confirmed.count, pending: pending.subtracting(confirmed).count, areaCells: Self.cols * Self.rows / 2)
    }

    var body: some View {
        ZStack(alignment: .top) {
            CYMapPlaceholder(fog: false)
            CYFogOverlayLayer(mask: mask, grid: (Self.cols, Self.rows), wipes: choreo.active)
                .ignoresSafeArea()
                .animation(reduceMotion ? .easeOut(duration: 0.2) : nil, value: mask.revision)
            VStack {
                HStack {
                    Text(verbatim: "Fog engine").font(.title2.weight(.heavy)).foregroundStyle(.white)
                    Spacer()
                    CYFogCoverageBadge(reading: reading)
                }.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.xxl)
                Spacer()
            }
        }
        .onAppear { rebuild() }
        .cyHaptic(.success, trigger: choreo.successSerial)
        .cyHaptic(.impactLight, trigger: choreo.lightSerial)
        .task {
            var step = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                let next = Self.path[step % Self.path.count]
                // The fix point is the cell centre, normalized.
                let origin = CGPoint(x: (CGFloat(next.x) + 0.5) / CGFloat(Self.cols), y: (CGFloat(next.y) + 0.5) / CGFloat(Self.rows))
                let baked = choreo.enqueue([next], origin: origin, now: Date().timeIntervalSinceReferenceDate, reduceMotion: reduceMotion)
                if !baked.isEmpty { confirmed.formUnion(baked); rebuild() }
                try? await Task.sleep(for: .milliseconds(600))
                let done = choreo.settle(at: Date().timeIntervalSinceReferenceDate)
                if !done.isEmpty { confirmed.formUnion(done); rebuild() }
                step += 1
                if step % Self.path.count == 0 { confirmed = Self.seedCells; rebuild() }
            }
        }
    }

    private func rebuild() {
        revision += 1
        mask = CYFogMaskRasterizer.rasterize(confirmed: confirmed, pending: pending, cols: Self.cols, rows: Self.rows, revision: revision)
    }
}
#endif
