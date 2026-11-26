import SwiftUI

// Roam signature kit: explicit roam phases, the fog-of-war layer, the "new area revealed" toast,
// the three-detent nearby sheet with parallax cards, and the pin that follows the selected card.
// Presentation only: nothing here reads location or starts a roam. Spec: docs/release/motion-spec-roam.md.

// MARK: - RoamPhase

/// What the player sees, one case per visual state. Mapped one-to-one from the controller's `RoamLivePhase`;
/// views `switch` over it exhaustively so a new controller phase cannot silently fall through.
enum RoamPhase: Equatable, CaseIterable {
    case idle        // ready to go (GO is offered)
    case starting    // acquiring a fix / recovering
    case walking     // roam is running
    case paused      // roam is paused, can resume
    case finishing   // settling the walk
    case finished
    case blocked     // location denied, recovery needed, or unavailable

    init(_ live: RoamLivePhase) {
        switch live {
        case .ready: self = .idle
        case .acquiring, .recovering: self = .starting
        case .active: self = .walking
        case .paused: self = .paused
        case .finishing: self = .finishing
        case .finished: self = .finished
        case .recoveryRequired, .locationDenied, .unavailable: self = .blocked
        }
    }

    /// The fog edge animates only while walking; every other phase shows the static edge.
    var animatesFog: Bool { self == .walking }

    /// How far the fog has been pushed back by this phase, as the base reveal radius scale.
    var fogRadiusScale: CGFloat {
        switch self {
        case .idle, .blocked: return 0.82
        case .starting: return 0.9
        case .walking: return 1
        case .paused: return 0.94
        case .finishing, .finished: return 1.08
        }
    }

    var statusSymbol: String {
        switch self {
        case .idle: return "location.circle"
        case .starting: return "location.magnifyingglass"
        case .walking: return "figure.walk"
        case .paused: return "pause.circle"
        case .finishing: return "flag.checkered"
        case .finished: return "checkmark.circle"
        case .blocked: return "location.slash"
        }
    }
}

/// Small status glyph for the HUD: pulses softly while walking, static otherwise (and under Reduce Motion).
struct CYRoamStatusDot: View {
    let phase: RoamPhase
    @QuestifyReduceMotion private var reduceMotion
    @State private var pulse = false

    private var tint: Color {
        switch phase {
        case .walking: return CYColor.successText
        case .starting, .finishing: return CYColor.infoText
        case .paused: return CYColor.warningText
        case .blocked: return CYColor.dangerText
        case .idle, .finished: return CYColor.textTertiary
        }
    }

    var body: some View {
        Circle().fill(tint).frame(width: 10, height: 10)
            .overlay {
                if phase == .walking && !reduceMotion {
                    Circle().stroke(tint.opacity(pulse ? 0 : 0.6), lineWidth: 2).scaleEffect(pulse ? 2.4 : 1)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
            }
            .accessibilityHidden(true)
    }
}

/// Design hand-off r1 PL-14: the roam state as a labelled tag (icon + word), replacing the colour-only dot.
struct CYRoamStatusTag: View {
    let phase: RoamPhase

    var body: some View {
        switch phase {
        case .idle: CYStatusTag(.ready)
        case .starting: CYStatusTag(.locating)
        case .walking: CYStatusTag(.recording)
        case .paused: CYStatusTag(.paused)
        case .finishing: CYStatusTag("statusTag.finishing", state: .neutral, tableName: "DesignR1")
        case .finished: CYStatusTag(.ended)
        case .blocked: CYStatusTag("statusTag.blocked", state: .warning, tableName: "DesignR1")
        }
    }
}

// MARK: - Go button rings

/// Slow breathing ring around the GO circle while walking (one looping decoration; Reduce Motion = a still ring).
struct CYGoWalkingRing: View {
    @QuestifyReduceMotion private var reduceMotion
    @State private var breathe = false

    var body: some View {
        Circle()
            .strokeBorder(Color.white.opacity(reduceMotion ? 0.4 : (breathe ? 0.08 : 0.5)), lineWidth: 3)
            .scaleEffect(reduceMotion ? 1.12 : (breathe ? 1.3 : 1.04))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { breathe = true }
            }
            .accessibilityHidden(true)
    }
}

/// Ring that tightens inward while the GO circle is held down.
struct CYGoHoldRing: View {
    let pressed: Bool
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        Circle()
            .strokeBorder(Color.white.opacity(pressed ? 0.75 : 0), lineWidth: 3)
            .scaleEffect(pressed ? 1.04 : 1.26)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: pressed)
            .accessibilityHidden(true)
    }
}

// MARK: - Fog of war

/// Fog over the map: unexplored = a dark, soft vignette; explored = clear holes with a soft edge, a big one around the
/// player and smaller ones along the trail. One `Canvas`, one `TimelineView` (the only animated layer); the edge drifts
/// slowly while `animated`. Reduce Motion or `animated == false` draws the same frame once, static.
/// `revealTick` bumps push the edge outward with a spring and settle back, `explored` (0...1) widens the base radius.
struct CYFogLayer: View {
    var explored: Double? = nil
    var trail: [CGPoint] = []
    var player = CGPoint(x: 0.5, y: 0.46)
    var revealTick = 0
    var radiusScale: CGFloat = 1
    var animated = true
    @QuestifyReduceMotion private var reduceMotion
    @State private var boost: CGFloat = 1

    private var drifts: Bool { animated && !reduceMotion }

    /// Native r2: no fog vignette (decorative). Draws nothing; the map shows as is. Coverage numbers stay in Core.
    var body: some View {
        EmptyView()
    }
}

private struct CYFogCanvas: View, Animatable {
    var scale: CGFloat
    var time: Double
    var explored: Double
    var trail: [CGPoint]
    var player: CGPoint
    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            let full = CGRect(origin: .zero, size: size)
            let base = min(size.width, size.height)
            let wobble = CGFloat(sin(time * 0.9)) * base * 0.012
            let playerRadius = base * (0.30 + 0.16 * CGFloat(explored)) * scale + wobble
            let center = CGPoint(x: size.width * player.x, y: size.height * player.y)
            ctx.drawLayer { layer in
                layer.fill(Path(full), with: .color(Color(red: 0.03, green: 0.04, blue: 0.06).opacity(0.84)))
                layer.blendMode = .destinationOut
                let soft = Gradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.92), location: 0.5),
                    .init(color: .black.opacity(0.35), location: 0.82),
                    .init(color: .clear, location: 1)
                ])
                func hole(_ g: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
                    g.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                               with: .radialGradient(soft, center: c, startRadius: 0, endRadius: r))
                }
                for (i, point) in trail.enumerated() {
                    let drift = CGFloat(sin(time * 0.6 + Double(i))) * base * 0.006
                    hole(&layer, CGPoint(x: size.width * point.x, y: size.height * point.y), base * 0.13 * scale + drift)
                }
                hole(&layer, center, playerRadius)
            }
            // Lantern edge: a 2 pt gold stroke plus a 14 pt blurred copy where the fog starts. Breathes on a 2.2 s cycle;
            // `time` is 0 when motion is reduced, which holds it at the resting value (static edge).
            let breath = 1 + 0.15 * sin(time * 2 * .pi / 2.2)
            let rim = Path(ellipseIn: CGRect(x: center.x - playerRadius * 0.9, y: center.y - playerRadius * 0.9,
                                             width: playerRadius * 1.8, height: playerRadius * 1.8))
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 14))
                layer.stroke(rim, with: .color(CYNight.lantern.opacity(0.45 * breath)), lineWidth: 8)
            }
            ctx.stroke(rim, with: .color(CYNight.lantern.opacity(0.8 * breath)), lineWidth: 2)
        }
    }
}

/// The player dot at the centre of the revealed area.
struct CYRoamPlayerDot: View {
    var walking = true
    @QuestifyReduceMotion private var reduceMotion
    @State private var ping = false
    var body: some View {
        ZStack {
            if walking && !reduceMotion {
                Circle().fill(CYColor.infoText.opacity(ping ? 0 : 0.35)).frame(width: 18, height: 18).scaleEffect(ping ? 3 : 1)
            }
            Circle().fill(CYColor.infoText).frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        }
        .onAppear {
            guard walking, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { ping = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Reveal toast

/// Percent that counts up from its previous value (0.6 s ease-out). `nil` is unknown and shows an em dash.
struct CYCountUpPercent: View {
    let percent: Int?
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown: Double = 0
    @State private var last: Int?

    var body: some View {
        Group {
            if percent == nil {
                Text(verbatim: "—")
            } else {
                CYCountText(value: shown)
            }
        }
        .onAppear { settle(animated: true) }
        .onChange(of: percent) { _, _ in settle(animated: true) }
    }

    private func settle(animated: Bool) {
        guard let target = percent else { last = nil; return }
        let start = Double(last ?? 0)
        last = target
        if reduceMotion || !animated { shown = Double(target); return }
        shown = start
        withAnimation(.easeOut(duration: 0.6)) { shown = Double(target) }
    }
}

private struct CYCountText: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View { Text(verbatim: "\(Int(value.rounded()))%").monospacedDigit() }
}

/// "New area revealed" capsule with the explored percent counting up. The host shows and hides it
/// (`if shown { CYRevealToast(...).transition(.cyRevealToast) }`); it never dismisses itself.
struct CYRevealToast: View {
    let percent: Int?
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "sparkles").foregroundStyle(CYColor.brand)
            Text("roam.fog.revealed").cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
            Text(verbatim: "·").foregroundStyle(CYColor.textTertiary)
            CYCountUpPercent(percent: percent).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
        }
        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .background(Color.black.opacity(0.5), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(percent.map { Text("roam.fog.toast.a11y \($0)") } ?? Text("roam.fog.toast.a11yUnknown"))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension AnyTransition {
    /// Toast in/out: rises 12 pt with a fade; Reduce Motion hosts should swap to `.opacity`.
    static var cyRevealToast: AnyTransition {
        .asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity)
    }
}

// MARK: - Pin

/// Map pin that grows and rings once when its card is selected.
struct CYRoamPin: View {
    let symbol: String
    var selected = false
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        CYMapMarker(symbol: symbol, selected: selected)
            .background { CYRingPulse(trigger: selected ? 1 : 0, idle: false).opacity(selected ? 1 : 0) }
            .scaleEffect(selected && !reduceMotion ? 1.12 : 1)
            .shadow(color: .black.opacity(0.4), radius: selected ? 8 : 3, y: 2)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: selected)
            .accessibilityHidden(true)
    }
}

// MARK: - Nearby sheet

struct CYRoamNearbyItem: Identifiable, Equatable {
    let id: String
    let title: String
    let meta: String
    let symbol: String
    var seed: String { id + title }
}

enum CYRoamSheetDetent: CaseIterable {
    case peek, half, full
    func height(in total: CGFloat, peekHeight: CGFloat) -> CGFloat {
        switch self {
        case .peek: return peekHeight
        case .half: return max(total * 0.5, peekHeight + 120)
        case .full: return total * 0.9
        }
    }
}

/// Nearby sheet over a full-bleed map: peek (grabber + one line) / half / full. Dragging follows the finger, then
/// springs to the detent nearest the flick's projected end. Content stays mounted but hidden at peek.
struct CYRoamNearbySheet<Peek: View, Content: View>: View {
    @Binding var detent: CYRoamSheetDetent
    let peek: Peek
    let content: Content
    @GestureState private var drag: CGFloat = 0
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var peekLine: CGFloat = 84

    init(detent: Binding<CYRoamSheetDetent>, @ViewBuilder peek: () -> Peek, @ViewBuilder content: () -> Content) {
        _detent = detent
        self.peek = peek()
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.height
            let lowest = CYRoamSheetDetent.peek.height(in: total, peekHeight: peekLine)
            let height = min(max(detent.height(in: total, peekHeight: peekLine) - drag, lowest * 0.9), total * 0.96)
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Capsule().fill(Color.white.opacity(0.3)).frame(width: 40, height: 5).padding(.top, CYSpacing.sm)
                    peek.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 4)
                    .updating($drag) { value, state, _ in state = value.translation.height }
                    .onEnded { value in
                        let projected = detent.height(in: total, peekHeight: peekLine) - value.predictedEndTranslation.height
                        let next = CYRoamSheetDetent.allCases.min {
                            abs($0.height(in: total, peekHeight: peekLine) - projected) < abs($1.height(in: total, peekHeight: peekLine) - projected)
                        } ?? detent
                        withAnimation(reduceMotion ? CYMotion.reduced : cyRoamSheetSnap) { detent = next }
                    })
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("map.panel.size"))
                .accessibilityAdjustableAction { direction in
                    let all = CYRoamSheetDetent.allCases
                    guard let i = all.firstIndex(of: detent) else { return }
                    let next = direction == .increment ? min(i + 1, all.count - 1) : max(i - 1, 0)
                    withAnimation(reduceMotion ? CYMotion.reduced : cyRoamSheetSnap) { detent = all[next] }
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(detent == .peek ? 0 : 1)
                    .allowsHitTesting(detent != .peek)
                    .accessibilityHidden(detent == .peek)
                    .animation(reduceMotion ? nil : CYMotion.standard, value: detent)
            }
            .frame(height: height, alignment: .top)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                    .fill(cyMapPanelColor)
                    .shadow(color: .black.opacity(0.4), radius: 18, y: -4)
                    .ignoresSafeArea(edges: .bottom)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .cyHaptic(.impactLight, trigger: detent)
        }
    }
}

/// Nearby card: art parallaxes against the scroll, the card eases up into view, the selected card is outlined
/// and tinted (its pin grows on the map). Under Reduce Motion there is no parallax and no offset.
struct CYRoamNearbyCard: View {
    let item: CYRoamNearbyItem
    var selected = false
    var onTap: () -> Void = {}
    @QuestifyReduceMotion private var reduceMotion

    private var hue: Double { Double(item.seed.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) % 360 }) / 360 }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CYSpacing.md) {
                art
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: item.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                    Text(verbatim: item.meta).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "mappin.circle.fill" : "chevron.right")
                    .foregroundStyle(selected ? CYColor.brand : CYColor.textTertiary)
            }
            .padding(CYSpacing.md)
            .background(selected ? CYColor.brandSoft : CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                .strokeBorder(selected ? CYColor.brandStrong : Color.clear, lineWidth: selected ? 2 : 0))
            .animation(reduceMotion ? nil : CYMotion.standard, value: selected)
        }
        .buttonStyle(CYPressableStyle())
        .modifier(CYRoamCardParallax(enabled: !reduceMotion))
        .cyHaptic(.selection, trigger: selected) { old, new in !old && new }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var art: some View {
        RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
            .fill(LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.55),
                                          Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.28)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { Image(systemName: item.symbol).font(.title3.weight(.semibold)).foregroundStyle(Color.white.opacity(0.9)).modifier(CYRoamArtParallax(enabled: !reduceMotion)) }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct CYRoamCardParallax: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.scrollTransition(.interactive.threshold(.visible(0.1))) { view, phase in
                view.opacity(phase.isIdentity ? 1 : 0.5)
                    .offset(y: phase.value * 14)
                    .scaleEffect(phase.isIdentity ? 1 : 0.96)
            }
        } else {
            content
        }
    }
}

private struct CYRoamArtParallax: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.scrollTransition(.interactive) { view, phase in view.offset(y: phase.value * -10) }
        } else {
            content
        }
    }
}
