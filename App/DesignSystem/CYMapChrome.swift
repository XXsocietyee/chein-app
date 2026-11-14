import SwiftUI

// Map chrome for the immersive player screens (play / roam / search map). Presentation only:
// glass controls, the white GO circle, a persistent detent sheet and a static placeholder map
// used by debug fixtures and empty states. Real screens keep MapKit underneath.

/// Artwork of a round glass control (also used as a NavigationLink / Menu label).
struct CYGlassLabel: View {
    let systemImage: String
    @ScaledMetric(relativeTo: .body) private var scaled: CGFloat = 48
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var size: CGFloat { min(scaled, 60) }
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(.body).weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.black.opacity(reduceTransparency ? 0.94 : 0.62), in: Circle())
            .background(reduceTransparency ? AnyShapeStyle(Color.black) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(contrast == .increased ? 0.5 : 0.14), lineWidth: contrast == .increased ? 1.5 : 1))
            .contentShape(Circle())
    }
}

/// Round 44pt (scaled) glass control floating over a map. Max three per screen (owner rule).
struct CYGlassButton: View {
    private let systemImage: String
    private let label: LocalizedStringKey
    private let action: () -> Void

    init(systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) { CYGlassLabel(systemImage: systemImage) }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Glass capsule container (search field, title pill, stat strip).
struct CYGlassCapsule<Content: View>: View {
    private let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(.horizontal, CYSpacing.lg)
            .frame(minHeight: 48)
            .background(reduceTransparency ? AnyShapeStyle(Color(white: 0.09)) : AnyShapeStyle(.ultraThinMaterial), in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(contrast == .increased ? 0.5 : 0.14), lineWidth: contrast == .increased ? 1.5 : 1))
    }
}

/// The white GO circle artwork (also used as a NavigationLink label).
struct CYGoLabel: View {
    private let title: LocalizedStringKey
    private let symbol: String?
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .largeTitle) private var scaled: CGFloat = 96
    private var size: CGFloat { min(scaled, 112) }
    /// `symbol` replaces the word with a glyph (the walking state shows a walking figure).
    init(_ title: LocalizedStringKey = "GO", symbol: String? = nil) { self.title = title; self.symbol = symbol }
    var body: some View {
        Group {
            if let symbol {
                Image(systemName: symbol).font(.system(.title).weight(.heavy))
            } else {
                Text(title).font(.system(.title, design: .default).weight(.heavy).italic())
            }
        }
            .minimumScaleFactor(0.6).lineLimit(1)
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(Color.white, in: Circle())
            .overlay(Circle().strokeBorder(Color.black.opacity(contrast == .increased ? 0.6 : 0), lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
            .contentShape(Circle())
    }
}

/// The mini-program's white GO circle: the single primary action of a map screen.
struct CYGoButton: View {
    private let title: LocalizedStringKey
    private let action: () -> Void
    init(_ title: LocalizedStringKey = "GO", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    var body: some View {
        Button(action: action) { CYGoLabel(title) }
            .buttonStyle(CYGoPressStyle())
            .accessibilityLabel(Text(title))
            .accessibilitySortPriority(10)   // the one primary map action is reached before the list panel
    }
}

/// Dark static stand-in for a map (roads, water, a fog vignette). Debug fixtures and offline state only.
struct CYMapPlaceholder: View {
    var fog = true
    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.075, blue: 0.085)
            Canvas { ctx, size in
                var water = Path()
                water.move(to: CGPoint(x: -20, y: size.height * 0.62))
                water.addCurve(to: CGPoint(x: size.width + 20, y: size.height * 0.30),
                               control1: CGPoint(x: size.width * 0.35, y: size.height * 0.78),
                               control2: CGPoint(x: size.width * 0.62, y: size.height * 0.20))
                ctx.stroke(water, with: .color(Color(red: 0.10, green: 0.18, blue: 0.26)), lineWidth: 34)
                let road = Color.white.opacity(0.10)
                for i in 0..<9 {
                    var p = Path()
                    let y = size.height * (0.06 + CGFloat(i) * 0.115)
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y + size.height * 0.05 * (i.isMultiple(of: 2) ? 1 : -1)))
                    ctx.stroke(p, with: .color(road), lineWidth: i.isMultiple(of: 3) ? 5 : 2)
                }
                for i in 0..<6 {
                    var p = Path()
                    let x = size.width * (0.08 + CGFloat(i) * 0.18)
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + size.width * 0.12, y: size.height))
                    ctx.stroke(p, with: .color(road), lineWidth: i.isMultiple(of: 2) ? 4 : 2)
                }
            }
            if fog {
                RadialGradient(colors: [.clear, .black.opacity(0.72)], center: .center, startRadius: 120, endRadius: 520)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#if DEBUG
/// DEBUG-only street-grid stand-in for a tile-less simulator map, so layout can be judged. Never in Release.
struct CYMapStreetGrid: View {
    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.14, blue: 0.155)
            Canvas { ctx, size in
                let block = Color(red: 0.16, green: 0.175, blue: 0.19)
                let street = Color(red: 0.30, green: 0.32, blue: 0.35)
                let avenue = Color(red: 0.42, green: 0.40, blue: 0.30)
                ctx.fill(Path(CGRect(x: size.width * 0.52, y: size.height * 0.12, width: size.width * 0.34, height: size.height * 0.16)), with: .color(Color(red: 0.12, green: 0.24, blue: 0.17)))
                ctx.fill(Path(CGRect(x: 0, y: size.height * 0.5, width: size.width * 0.26, height: size.height * 0.2)), with: .color(block))
                let step: CGFloat = 64
                var x: CGFloat = -10
                var i = 0
                while x < size.width + step {
                    var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + 14, y: size.height))
                    ctx.stroke(p, with: .color(i % 4 == 0 ? avenue : street), lineWidth: i % 4 == 0 ? 7 : 3); x += step; i += 1
                }
                var y: CGFloat = 20
                i = 0
                while y < size.height + step {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y - 18))
                    ctx.stroke(p, with: .color(i % 3 == 0 ? avenue : street), lineWidth: i % 3 == 0 ? 7 : 3); y += step * 0.9; i += 1
                }
                var diag = Path(); diag.move(to: CGPoint(x: 0, y: size.height * 0.9)); diag.addLine(to: CGPoint(x: size.width, y: size.height * 0.25))
                ctx.stroke(diag, with: .color(avenue), lineWidth: 9)
            }
            VStack { Text(verbatim: "DEBUG placeholder map (simulator has no tiles)")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.white.opacity(0.4)).padding(.top, 150); Spacer() }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
#endif

/// Pin used by placeholder maps: white label callout like the mini-program search map.
struct CYMapCallout: View {
    let text: String
    var selected = false
    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black)
                .lineLimit(2)
                .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous).strokeBorder(Color.black.opacity(selected ? 0.9 : 0), lineWidth: 2))
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(.white).offset(y: -1)
        }
    }
}

private struct CYMapSheetModifier<Sheet: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    @ViewBuilder let sheet: () -> Sheet
    @Environment(\.dynamicTypeSize) private var type
    @State private var selection: PresentationDetent = .height(236)

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            sheet()
                .presentationDetents(detents, selection: $selection)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .cyPlayerSheetGlass()
                .interactiveDismissDisabled()
                .onAppear { if type.isAccessibilitySize { selection = .medium } }
        }
    }
}

extension View {
    /// Persistent bottom sheet over a full-bleed map: detents, map stays interactive behind, never dismissed.
    /// Use for node / task / result information; the screen's primary action lives inside it.
    /// At accessibility text sizes it opens at the medium detent so the primary action is visible.
    func cyMapSheet<Sheet: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.height(236), .medium, .large],
        @ViewBuilder content: @escaping () -> Sheet
    ) -> some View {
        modifier(CYMapSheetModifier(isPresented: isPresented, detents: detents, sheet: content))
    }
}

// MARK: - Map scaffold (real screens)

/// Spring every map sheet / panel snaps with (response 0.42, damping 0.82: one soft settle, no wobble).
let cyRoamSheetSnap = Animation.spring(response: 0.42, dampingFraction: 0.82)

/// Fill of the map panel; content inside the panel stays clear so header and list share one surface.
let cyMapPanelColor = Color.black

/// Panel height as a fraction of the available height. The grabber drags between them.
/// With a `peek` line the compact detent is only the grabber + that one line.
enum CYPanelDetent: CaseIterable { case compact, medium, large
    var fraction: CGFloat { switch self { case .compact: 0.30; case .medium: 0.58; case .large: 0.94 } }
}

/// Full-bleed map (any view) + glass controls on top + a bottom panel with three detents holding the
/// screen's list. `floating` sits just above the panel (the white GO circle / the one primary action).
/// Used by real screens whose existing sheets (details, entries) must keep working, so the panel is
/// in-view and never a second system sheet. The list inside keeps scrolling; only the grabber drags.
///
/// `peek`: when given, the compact detent is a small bar (grabber + this one line) and the panel
/// content stays mounted but hidden there; `floating` is only shown at the compact detent.
struct CYMapScaffold<Map: View, Controls: View, Floating: View, Panel: View>: View {
    private let map: Map, controls: Controls, floating: Floating, panel: Panel
    private let peek: AnyView?
    private let allowed: [CYPanelDetent]
    @State private var detent: CYPanelDetent
    @GestureState private var drag: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// E2E-20261113b N3: inside a tab the panel's visible content ends above the floating tab bar; its fill still runs under it.
    @Environment(\.cyTabBarClearance) private var tabBarClearance
    @ScaledMetric(relativeTo: .body) private var peekLine: CGFloat = 52
    /// Grabber row: a 44 pt drag/adjust target (the bar itself stays 40 x 5).
    private let grabberHeight: CGFloat = 44

    init(detent: CYPanelDetent = .medium, allowed: [CYPanelDetent] = CYPanelDetent.allCases, peek: AnyView? = nil,
         @ViewBuilder map: () -> Map, @ViewBuilder controls: () -> Controls,
         @ViewBuilder floating: () -> Floating, @ViewBuilder panel: () -> Panel) {
        self.map = map(); self.controls = controls(); self.floating = floating(); self.panel = panel()
        self.allowed = allowed
        self.peek = peek
        _detent = State(initialValue: detent)
    }
    private var effective: CYPanelDetent { peek == nil && type.isAccessibilitySize && detent == .compact ? .medium : detent }
    private func height(_ d: CYPanelDetent, total: CGFloat) -> CGFloat {
        if d == .compact, peek != nil { return min(grabberHeight + min(peekLine, 120), total * 0.3) }
        return total * d.fraction
    }
    private var pool: [CYPanelDetent] { allowed.isEmpty ? CYPanelDetent.allCases : allowed }
    private var isPeeking: Bool { peek != nil && effective == .compact }

    var body: some View {
        GeometryReader { geo in
            let base = height(effective, total: geo.size.height)
            let low = peek == nil ? geo.size.height * 0.22 : height(.compact, total: geo.size.height)
            let panelHeight = min(max(base - drag, low), geo.size.height * 0.96)
            ZStack(alignment: .bottom) {
                map.frame(maxWidth: .infinity, maxHeight: .infinity).clipped().ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    controls.padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm)
                        .padding(.bottom, CYSpacing.sm)
                        // Title and glass controls sit on a soft scrim so white text keeps 4.5:1 over any map tile.
                        .background(alignment: .top) {
                            LinearGradient(colors: [.black.opacity(0.62), .black.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom)
                                .padding(.bottom, -CYSpacing.lg).ignoresSafeArea(edges: .top).allowsHitTesting(false).accessibilityHidden(true)
                        }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                floating.padding(.bottom, panelHeight + CYSpacing.lg)
                    .opacity(peek != nil && !isPeeking ? 0 : 1)
                    .allowsHitTesting(!(peek != nil && !isPeeking))
                    .accessibilityHidden(peek != nil && !isPeeking)
                    .animation(reduceMotion ? nil : cyRoamSheetSnap, value: isPeeking)
                    .cyHaptic(.impactLight, trigger: effective)
                VStack(spacing: 0) {
                    grabber(total: geo.size.height)
                    ZStack(alignment: .top) {
                        panel.frame(maxWidth: .infinity, maxHeight: .infinity).frame(height: isPeeking ? geo.size.height * 0.58 : nil)
                            .opacity(isPeeking ? 0 : 1)
                            .allowsHitTesting(!isPeeking)
                            .accessibilityHidden(isPeeking)
                        if isPeeking, let peek {
                            peek.contentShape(Rectangle())
                                .accessibilityElement(children: .combine)
                                .onTapGesture { withAnimation(reduceMotion ? nil : cyRoamSheetSnap) { detent = .medium } }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint(Text("map.panel.size"))
                        }
                    }
                    .clipped()
                }
                .padding(.bottom, tabBarClearance)
                .frame(height: panelHeight + tabBarClearance, alignment: .top)
                .background(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                        .fill(cyMapPanelColor)
                        .shadow(color: .black.opacity(0.4), radius: 18, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    /// Spoken value of the grabber: which of the three sizes the panel is at.
    private func detentName(_ d: CYPanelDetent) -> LocalizedStringKey {
        switch d { case .compact: "map.panel.size.compact"; case .medium: "map.panel.size.medium"; case .large: "map.panel.size.large" }
    }

    private func grabber(total: CGFloat) -> some View {
        Capsule().fill(Color.white.opacity(0.5)).frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: grabberHeight)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4)
                .updating($drag) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let target = height(effective, total: total) - value.translation.height
                    withAnimation(reduceMotion ? nil : cyRoamSheetSnap) { detent = pool.min { abs(height($0, total: total) - target) < abs(height($1, total: total) - target) } ?? .medium }
                })
            .accessibilityElement()
            .accessibilityLabel(Text("map.panel.size"))
            .accessibilityValue(Text(detentName(effective)))
            .accessibilityAdjustableAction { direction in
                guard let i = pool.firstIndex(of: detent) else { return }
                let next = direction == .increment ? min(i + 1, pool.count - 1) : max(i - 1, 0)
                withAnimation(reduceMotion ? nil : cyRoamSheetSnap) { detent = pool[next] }
            }
    }
}
