#if DEBUG
import SwiftUI

/// DEBUG motion lab (E1): loops the key transitions on an 8 s cycle with a visible timeline, so motion can be judged
/// from screen recordings (stills cannot show it). Synthetic content, never ships in Release.
/// `--design-fixture e1-motion-hero | e1-motion-list | e1-motion-scroll`. Add `--uitesting-reduce-motion` to see the fallback.
struct E1MotionLabFixture: View {
    enum Mode { case hero, list, scroll }
    let mode: Mode

    private static let cycle: Double = 8
    @State private var cycleStart = Date()
    @State private var step = 0
    @State private var path: [Int] = []
    @State private var pressed = false
    @State private var loading = true
    @State private var items = [0, 1, 2, 3, 4, 5]
    @State private var stagger = CYStaggerGate()
    @State private var showEmpty = false
    @State private var emptyKey = 0
    @Namespace private var hero
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette

    private var events: [(t: Double, label: String, haptic: String?)] {
        switch mode {
        case .hero: return [(0.0, "idle", nil), (0.8, "press: scale 0.97, spring 120 ms", nil), (1.4, "tap: push, zoom from card", "selection"),
                            (4.6, "swipe back: zoom returns", nil), (6.0, "idle", nil)]
        case .list: return [(0.0, "skeleton", nil), (1.6, "cross-fade 0.25 s + stagger (max 6, once)", nil), (4.4, "insert row", "success"),
                            (6.0, "delete row", "impact light"), (7.2, "reset", nil)]
        case .scroll: return [(0.0, "large header at rest", nil), (0.8, "scroll up: parallax + sticky blur bar", nil),
                              (3.2, "scroll back: stretch", nil), (5.0, "empty state entrance", nil), (7.4, "reset", nil)]
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            lab
                .navigationDestination(for: Int.self) { index in
                    LabDetail(index: index).cyHeroDestination(index, in: hero)
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { timeline }
        .task { await run() }
        .themeDomain(.player)
        .cyDomainPageBackground()
        .preferredColorScheme(.dark)
    }

    // MARK: stage

    @ViewBuilder private var lab: some View {
        switch mode {
        case .hero:
            ScrollView {
                VStack(spacing: CYSpacing.lg) {
                    ForEach(0..<3, id: \.self) { i in
                        NavigationLink(value: i) {
                            CYImageCard("Lantern Walk \(i + 1)", meta: "1.2 km · Open until 23:00")
                                .cyHeroSource(i, in: hero)
                                .cyPressEffect(pressed && i == 0, reduceMotion: reduceMotion)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CYSpacing.pageHorizontal)
            }
            .navigationTitle("Routes").navigationBarTitleDisplayMode(.inline)
        case .list:
            ScrollView {
                CYContentSwap(isLoading: loading) {
                    CYLoadingStateView(rows: 4).padding(CYSpacing.lg)
                } content: {
                    LazyVStack(spacing: CYSpacing.md) {
                        ForEach(Array(items.enumerated()), id: \.element) { index, id in
                            CYListRow(verbatim: "Activity \(id + 1)", meta: "Sat 19:00 · Old Town", card: true) { CYRowIcon(systemImage: "figure.walk") }
                                .cyStaggeredAppear(index: index, gate: stagger)
                                .cyRowTransition()
                        }
                    }
                    .cyAnimation(value: items)
                    .padding(CYSpacing.pageHorizontal)
                }
            }
            .navigationTitle("Activities").navigationBarTitleDisplayMode(.inline)
        case .scroll:
            if showEmpty {
                CYEmptyState(systemImage: "map", "No routes yet", detail: "New routes appear here")
                    .id(emptyKey)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: CYSpacing.md) {
                            CYCoverArt(seed: "Motion lab hero").cyHeroParallax(height: 220).id("top")
                            ForEach(0..<9, id: \.self) { i in
                                CYListRow(verbatim: "Row \(i + 1)", meta: "scroll-driven reveal", card: true) { CYRowIcon(systemImage: "mappin") }
                                    .cyScrollReveal().id(i)
                            }
                        }
                        .padding(.horizontal, CYSpacing.pageHorizontal)
                    }
                    .cyStickyHeader {
                        Text(verbatim: "Sticky header").cyText(.sectionTitle).padding(.vertical, CYSpacing.sm)
                    }
                    .onChange(of: step) { _, s in
                        if s == 1 { withAnimation(.easeInOut(duration: 2.2)) { proxy.scrollTo(8, anchor: .bottom) } }
                        if s == 2 { withAnimation(.easeInOut(duration: 1.6)) { proxy.scrollTo("top", anchor: .top) } }
                    }
                }
            }
        }
    }

    // MARK: timeline

    private var timeline: some View {
        TimelineView(.animation) { context in
            let t = min(context.date.timeIntervalSince(cycleStart), Self.cycle)
            let current = events.last(where: { $0.t <= t }) ?? events[0]
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(verbatim: String(format: "t = %.1f s", t)).monospacedDigit()
                    Spacer()
                    Text(verbatim: reduceMotion ? "REDUCE MOTION: ON (fade/instant)" : "Reduce Motion: off")
                }
                .cyText(.caption, weight: .semibold)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18)).frame(height: 6)
                        Capsule().fill(.white).frame(width: geo.size.width * t / Self.cycle, height: 6)
                        ForEach(events.indices, id: \.self) { i in
                            Circle().fill(events[i].haptic == nil ? Color.white.opacity(0.6) : Color.yellow)
                                .frame(width: 10, height: 10)
                                .offset(x: geo.size.width * events[i].t / Self.cycle - 5)
                        }
                    }
                }
                .frame(height: 12)
                HStack(spacing: 6) {
                    Text(verbatim: current.label).cyText(.bodyMedium)
                    if let h = current.haptic { Text(verbatim: "haptic: \(h)").cyText(.caption, weight: .bold).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(.yellow)).foregroundStyle(.black) }
                }
                Text(verbatim: "DEBUG motion lab: synthetic content").cyText(.caption).opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.88))
        }
    }

    // MARK: choreography

    private func sleep(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    private func run() async {
        while !Task.isCancelled {
            cycleStart = Date()
            switch mode {
            case .hero:
                path = []; pressed = false
                await sleep(0.8); pressed = true
                await sleep(0.6); pressed = false; CYHaptics.selection.play(); path = [0]
                await sleep(3.2); path = []
                await sleep(3.4)
            case .list:
                loading = true; items = [0, 1, 2, 3, 4, 5]; stagger = CYStaggerGate()
                await sleep(1.6); loading = false
                await sleep(2.8); items.insert(6, at: 2); CYHaptics.success.play()
                await sleep(1.6); items.remove(at: 4); CYHaptics.impactLight.play()
                await sleep(2.0)
            case .scroll:
                showEmpty = false; step = 0
                await sleep(0.8); step = 1
                await sleep(2.4); step = 2
                await sleep(1.8); showEmpty = true; emptyKey += 1
                await sleep(2.4); showEmpty = false
                await sleep(0.6)
            }
        }
    }
}

private struct LabDetail: View {
    let index: Int
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYCoverArt(seed: "Lantern Walk \(index + 1)").cyHeroParallax(height: 280)
                Text(verbatim: "Lantern Walk \(index + 1)").cyText(.sectionTitle)
                Text(verbatim: "Synthetic detail used by the motion lab to show the zoom transition.").cyText(.body)
            }
            .padding(.bottom, CYSpacing.lg)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
