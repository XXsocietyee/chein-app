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
enum RoamFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "roam-go": return wrap(RoamFixtureStage(initial: .idle))
        case "roam-walking": return wrap(RoamFixtureStage(initial: .walking))
        case "roam-reveal": return wrap(RoamFixtureStage(initial: .walking, loopReveal: true))
        case "roam-sheet-half": return wrap(RoamFixtureStage(initial: .idle, sheet: .half, selected: "b"))
        case "roam-paused": return wrap(RoamFixtureStage(initial: .paused))
        default: return nil
        }
    }

    static let items: [CYRoamNearbyItem] = [
        CYRoamNearbyItem(id: "a", title: "Dongmen Night Market", meta: "Market · 240 m", symbol: "cart"),
        CYRoamNearbyItem(id: "b", title: "Laojie Teahouse", meta: "Tea · 380 m", symbol: "cup.and.saucer"),
        CYRoamNearbyItem(id: "c", title: "Binjiang Park Stage", meta: "Event tonight · 520 m", symbol: "music.note"),
        CYRoamNearbyItem(id: "d", title: "Lane 9 Bookshop", meta: "Books · 610 m", symbol: "book"),
        CYRoamNearbyItem(id: "e", title: "Harbor Roof", meta: "Viewpoint · 790 m", symbol: "binoculars"),
    ]

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
                ForEach(RoamFixtures.items) { item in
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
                    Text(verbatim: "Nearby · \(RoamFixtures.items.count)").font(.headline).foregroundStyle(CYColor.textPrimary)
                } content: {
                    ScrollView {
                        LazyVStack(spacing: CYSpacing.sm) {
                            ForEach(RoamFixtures.items) { item in
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
#endif
