import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Ticket holder kit (E1). Spec: docs/release/motion-spec-tickets.md.
// Pass shape with notches and perforation holes, status ribbon, drag tilt with a moving highlight,
// foil sheen sweep, stacked depth, screen brightness boost and the code reveal. Everything that moves
// is gated on Reduce Motion through `@QuestifyReduceMotion`; the fallback is static or a short fade.

// MARK: - Shape

/// Rounded pass with a semicircular notch cut from both sides at `notchY` and, optionally, a row of
/// perforation holes along the same line. Draw with `.clipShape(shape, style: FillStyle(eoFill: true))`
/// so the notches and holes are real cut-outs (the page shows through). `notchY < 0` is a plain card.
struct CYTicketPassShape: Shape {
    var notchY: CGFloat
    var radius: CGFloat = CYRadius.xl
    var notch: CGFloat = 11
    /// Hole diameter along the tear line; 0 draws no holes.
    var perforation: CGFloat = 0
    var perforationGap: CGFloat = 7

    var animatableData: CGFloat {
        get { notchY }
        set { notchY = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        guard notchY >= 0, rect.height > (radius + notch) * 2 else { return p }
        let y = min(max(notchY, radius + notch), rect.height - radius - notch)
        p.addEllipse(in: CGRect(x: rect.minX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        p.addEllipse(in: CGRect(x: rect.maxX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        if perforation > 0 {
            let inset = notch + 12
            var x = rect.minX + inset
            let end = rect.maxX - inset
            while x + perforation <= end {
                p.addEllipse(in: CGRect(x: x, y: y - perforation / 2, width: perforation, height: perforation))
                x += perforation + perforationGap
            }
        }
        return p
    }
}

// MARK: - Status ribbon

/// The six pass states a ribbon can show. Colour is never the only signal: each has its own symbol and text.
enum CYPassState: Equatable {
    case valid, pending, used, expired, cancelled, unknown

    var systemImage: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .used: return "checkmark.seal.fill"
        case .expired: return "calendar.badge.exclamationmark"
        case .cancelled: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    var tone: CYStatusTone {
        switch self {
        case .valid: return .success
        case .pending: return .warning
        case .cancelled: return .danger
        case .used, .expired, .unknown: return .neutral
        }
    }
    /// Cards for passes that can no longer be used sit back (dimmed) in the holder.
    var isRetired: Bool { self == .expired || self == .cancelled }
}

/// The pass status as a `CYStatusChip` (existing tones and symbols) on a solid capsule so it reads over cover art.
/// Text is `.caption` (12 pt) scaling with Dynamic Type and never shrunk below it; at accessibility sizes it may wrap.
/// One VoiceOver element labelled with the status text. Place it inside the band's padding, never on the pass edge.
struct CYPassStatusChip: View {
    let state: CYPassState
    let text: LocalizedStringKey
    var identifier = "ticketPass.status"
    @Environment(\.cyPalette) private var palette

    var body: some View {
        CYStatusChip(text, tone: state.tone, systemImage: state.systemImage)
            .background(palette.bgElevated, in: Capsule(style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(text))
            .accessibilityIdentifier(identifier)
    }
}

/// Diagonal corner ribbon (top trailing) with the state text and symbol. At accessibility text sizes it
/// becomes a flat chip in the same corner so the text never clips. Put it in an `.overlay(alignment: .topTrailing)`
/// of a view that is clipped to the pass shape.
struct CYStatusRibbon: View {
    let state: CYPassState
    let text: Text
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            chip.padding(CYSpacing.md)
        } else {
            ribbon
        }
    }

    private var chip: some View {
        HStack(spacing: CYSpacing.xs) {
            Image(systemName: state.systemImage).accessibilityHidden(true)
            text
        }
        .cyText(.caption)
        .foregroundStyle(foreground)
        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xs + 1)
        .background(fill, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var ribbon: some View {
        HStack(spacing: CYSpacing.xs) {
            Image(systemName: state.systemImage).accessibilityHidden(true)
            text.textCase(.uppercase).kerning(1.1)
        }
        .cyText(.micro)
        .foregroundStyle(foreground)
        .lineLimit(1).minimumScaleFactor(0.7)
        .frame(width: 168, height: 24)
        .background(fill)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.28)).frame(height: 1) }
        .rotationEffect(.degrees(45))
        .offset(x: 46, y: 28)
        .accessibilityElement(children: .combine)
    }

    private var fill: Color {
        switch state.tone {
        case .success: return palette.success
        case .warning: return palette.warning
        case .danger: return palette.danger
        case .neutral, .info: return palette.bgRaised
        case .rare: return palette.rare
        }
    }
    private var foreground: Color {
        switch state.tone {
        case .neutral, .info: return palette.textPrimary
        default: return Color.black.opacity(0.88)
        }
    }
}

// MARK: - Tilt

extension View {
    /// Press and hold, then drag: the pass tilts up to `maxDegrees` on both axes with a specular highlight that
    /// slides against the tilt, then springs flat on release. A quick drag still scrolls the list. Reduce Motion:
    /// no tilt, no highlight, the hold still gives a light tick.
    func cyPassTilt(maxDegrees: Double = 7) -> some View { modifier(CYPassTilt(maxDegrees: maxDegrees)) }
}

private struct CYPassTilt: ViewModifier {
    let maxDegrees: Double
    @GestureState private var drag: CGSize? = nil
    @State private var grabbed = false
    @QuestifyReduceMotion private var reduceMotion

    private var tilt: CGSize {
        guard let drag, !reduceMotion else { return .zero }
        let reach: CGFloat = 150
        return CGSize(width: max(-1, min(1, drag.width / reach)), height: max(-1, min(1, drag.height / reach)))
    }

    func body(content: Content) -> some View {
        let t = tilt
        content
            .overlay {
                if !reduceMotion {
                    RadialGradient(colors: [.white.opacity(0.26), .white.opacity(0.06), .clear],
                                   center: UnitPoint(x: 0.5 - t.width * 0.45, y: 0.5 - t.height * 0.45),
                                   startRadius: 0, endRadius: 340)
                        .blendMode(.plusLighter)
                        .opacity(grabbed ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
            .rotation3DEffect(.degrees(-Double(t.height) * maxDegrees), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
            .rotation3DEffect(.degrees(Double(t.width) * maxDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .scaleEffect(grabbed && !reduceMotion ? 1.02 : 1)
            .animation(reduceMotion ? CYMotion.reduced : (grabbed ? CYMotion.press : CYMotion.release), value: t)
            .animation(reduceMotion ? CYMotion.reduced : CYMotion.release, value: grabbed)
            .gesture(
                LongPressGesture(minimumDuration: 0.14, maximumDistance: 12)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .updating($drag) { value, state, _ in
                        switch value {
                        case .first: state = .zero
                        case .second(_, let d): state = d?.translation ?? .zero
                        }
                    }
                    .onChanged { value in
                        if case .second(_, _) = value, !grabbed { grabbed = true }
                    }
                    .onEnded { _ in grabbed = false }
            )
            .onChange(of: drag == nil) { _, released in if released { grabbed = false } }
            .cyHaptic(.impactLight, trigger: grabbed) { old, new in !old && new }
    }
}

// MARK: - Foil sheen

extension View {
    /// A diagonal silver highlight sweeps across the view (0.6 s) every time `trigger` changes.
    /// Reduce Motion: a 0.18 s glow instead of a sweep. Apply before the clip shape so the band stays inside the pass.
    func cyFoilSheen<T: Equatable>(trigger: T) -> some View { modifier(CYTicketFoilSheen(trigger: trigger)) }
}

private struct CYTicketFoilSheen<T: Equatable>: ViewModifier {
    let trigger: T
    @State private var phase: CGFloat = -1
    @State private var glow: Double = 0
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack {
                        if !reduceMotion {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white.opacity(0.10), location: 0.42),
                                .init(color: .white.opacity(0.42), location: 0.5),
                                .init(color: .white.opacity(0.10), location: 0.58),
                                .init(color: .clear, location: 1.0),
                            ], startPoint: .leading, endPoint: .trailing)
                            .frame(width: w * 0.7, height: geo.size.height * 2.4)
                            .rotationEffect(.degrees(22))
                            .offset(x: phase * w * 1.3 - w * 0.5, y: -geo.size.height * 0.7)
                        }
                        Color.white.opacity(glow)
                    }
                    .blendMode(.plusLighter)
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .onChange(of: trigger) { _, _ in sweep() }
    }

    private func sweep() {
        if reduceMotion {
            withAnimation(.easeOut(duration: CYMotion.Duration.quick)) { glow = 0.22 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeIn(duration: CYMotion.Duration.quick)) { glow = 0 }
            }
        } else {
            phase = -1
            withAnimation(.easeInOut(duration: 0.6)) { phase = 1.4 }
        }
    }
}

// MARK: - Stack depth

extension View {
    /// Two offset sleeves behind the pass so it reads as the top of a stack in a holder. Layout reserves the extra
    /// height. Pass the clip `shape` so the sleeves share the pass silhouette (notches included).
    func cyPassStack(depth: Int = 2, radius: CGFloat = CYRadius.xl) -> some View {
        modifier(CYPassStack(depth: max(0, min(depth, 3)), radius: radius))
    }
}

private struct CYPassStack: ViewModifier {
    let depth: Int
    let radius: CGFloat
    @Environment(\.cyPalette) private var palette
    private let step: CGFloat = 7

    func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    ForEach(Array((1...max(depth, 1)).reversed()), id: \.self) { level in
                        if level <= depth {
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(level == 1 ? palette.bgRaised : palette.bgElevated)
                                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 1))
                                .padding(.horizontal, step * CGFloat(level) * 1.6)
                                .offset(y: step * CGFloat(level))
                                .opacity(level == 1 ? 0.95 : 0.7)
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .padding(.bottom, step * CGFloat(depth))
    }
}

// MARK: - Scroll highlight

extension View {
    /// A soft band of light that slides across the pass as the list scrolls (CoreMotion-free parallax).
    /// Reduce Motion: no band. Apply before the clip shape.
    func cyScrollSheen() -> some View { modifier(CYScrollSheen()) }
}

private struct CYScrollSheen: ViewModifier {
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.overlay {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(0.07), location: 0.45),
                    .init(color: .white.opacity(0.16), location: 0.5),
                    .init(color: .white.opacity(0.07), location: 0.55),
                    .init(color: .clear, location: 1.0),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.plusLighter)
                .visualEffect { view, proxy in
                    let frame = proxy.frame(in: .scrollView)
                    let travel = proxy.size.width * 0.9
                    let progress = frame.midY / max(proxy.bounds(of: .scrollView)?.height ?? 800, 1)
                    return view.offset(x: (0.5 - progress) * travel)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Brightness boost

extension View {
    /// Raises the screen to full brightness while `active` (0.35 s ramp; instant under Reduce Motion) and restores the
    /// previous level on deactivate, disappear or background. Nothing else in the app touches brightness.
    func cyBrightnessBoost(_ active: Bool = true) -> some View { modifier(CYBrightnessBoost(active: active)) }
}

@MainActor private struct CYBrightnessBoost: ViewModifier {
    let active: Bool
    @State private var saved: CGFloat?
    @State private var ramp: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onAppear { if active { boost() } }
            .onDisappear { restore() }
            .onChange(of: active) { _, now in now ? boost() : restore() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { if active { boost() } } else { restore() }
            }
    }

    #if canImport(UIKit)
    @MainActor private var screen: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.screen
    }
    #endif

    @MainActor private func boost() {
        #if canImport(UIKit)
        guard let screen else { return }
        if saved == nil { saved = screen.brightness }
        ramp?.cancel()
        if reduceMotion {
            screen.brightness = 1
            return
        }
        let from = screen.brightness
        ramp = Task { @MainActor in
            let steps = 14
            for i in 1...steps {
                guard !Task.isCancelled else { return }
                screen.brightness = from + (1 - from) * CGFloat(i) / CGFloat(steps)
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
        #endif
    }

    @MainActor private func restore() {
        #if canImport(UIKit)
        ramp?.cancel(); ramp = nil
        if let saved {
            screen?.brightness = saved
            self.saved = nil
        }
        #endif
    }
}

// MARK: - Code reveal

extension View {
    /// Entrance for a code or pass tile: fade, scale from 0.92 and a 10 pt blur that clears on the entrance spring,
    /// then one silver sweep. Reduce Motion: a 0.18 s fade, no sweep. A success tick plays when the tile lands.
    func cyCodeReveal() -> some View { modifier(CYCodeReveal()) }
}

private struct CYCodeReveal: ViewModifier {
    @State private var shown = false
    @State private var sweep = 0
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content
            .cyFoilSheen(trigger: sweep)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.92)
            .blur(radius: shown || reduceMotion ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance) { shown = true }
                guard !reduceMotion else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(380))
                    sweep += 1
                }
            }
            .cyHaptic(.success, trigger: shown) { old, new in !old && new }
    }
}

// MARK: - Optional hero destination

/// `cyHeroDestination` when the host supplied a namespace, otherwise nothing. Pairs with `CYOptionalHeroSource`.
struct CYOptionalHeroDestination<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID?
    @ViewBuilder func body(content: Content) -> some View {
        if let namespace { content.cyHeroDestination(id, in: namespace) } else { content }
    }
}
