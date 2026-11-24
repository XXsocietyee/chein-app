import SwiftUI
import CoreMotion

// Onboarding night-light kit (Design Wave 3, B8). Everything here is presentation only and private to the first-launch
// flow (OB prefix) so it cannot collide with the shared light kit. Gating follows specs/design-wave3.md section 3.6:
// Reduce Motion = static / crossfade, Low Power or thermal >= serious = no shader, no particles, no gyro.

// MARK: - Locale-aware type

enum OBType {
    static func isChinese(_ locale: Locale) -> Bool { locale.language.languageCode?.identifier == "zh" }
}

// MARK: - Tilt (gyro, or a fake sweep under --uitesting-fake-tilt)

/// Roll/pitch in radians-ish (clamped to +-0.6). Real device: CMMotionManager at 30 Hz. DEBUG `--uitesting-fake-tilt`
/// sweeps roll -0.5 -> 0.5 over 3 s (ping-pong) because the simulator has no gyro.
@MainActor
final class OBTiltSource: ObservableObject {
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    private var motion: CMMotionManager?
    private var sweep: Task<Void, Never>?

    func start(reduceMotion: Bool) {
        stop()
        guard !reduceMotion, CYLightBudget.gyroAllowed else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting-fake-tilt") {
            sweep = Task { @MainActor [weak self] in
                let t0 = Date()
                while !Task.isCancelled {
                    let phase = (Date().timeIntervalSince(t0) / 3.0).truncatingRemainder(dividingBy: 1)
                    let tri = phase < 0.5 ? phase * 2 : 2 - phase * 2
                    self?.roll = -0.5 + tri
                    self?.pitch = 0.12 * sin(phase * 2 * .pi)
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
            return
        }
        #endif
        let mm = CMMotionManager()
        guard mm.isDeviceMotionAvailable else { return }
        mm.deviceMotionUpdateInterval = 1.0 / 30.0
        mm.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let a = m?.attitude else { return }
            let r = max(-0.6, min(0.6, a.roll)), p = max(-0.6, min(0.6, a.pitch))
            Task { @MainActor in self?.roll = r; self?.pitch = p }
        }
        motion = mm
    }

    func stop() {
        sweep?.cancel(); sweep = nil
        motion?.stopDeviceMotionUpdates(); motion = nil
        roll = 0; pitch = 0
    }
}

// MARK: - Ground

/// Deterministic film grain: drawn once per size (no timeline), blended over the ground.
struct OBGrain: View {
    private struct LCG: RandomNumberGenerator {
        var s: UInt64
        mutating func next() -> UInt64 { s = s &* 6364136223846793005 &+ 1442695040888963407; return s }
    }
    var body: some View {
        Canvas { ctx, size in
            var rng = LCG(s: 0xC17E_5EED)
            let count = Int(size.width * size.height / 90)
            for _ in 0..<count {
                let x = CGFloat.random(in: 0..<size.width, using: &rng)
                let y = CGFloat.random(in: 0..<size.height, using: &rng)
                let a = Double.random(in: 0.25...1, using: &rng)
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(a)))
            }
        }
        .blendMode(.overlay)
        .opacity(0.22)
        .allowsHitTesting(false)
    }
}

// MARK: - Lantern windows

/// Six lit windows of the fogged city. They fade and rise in between 200 and 1400 ms, drift slowly, flicker a little,
/// and shift with `roll`/`pitch` (parallax, deeper windows move more, 8 pt at depth 1).
struct OBLanternWindows: View {
    struct Spec { let x, y, w, h, depth, phase, delay: Double }
    static let specs: [Spec] = [
        Spec(x: 0.28, y: 0.30, w: 9, h: 13, depth: 0.6, phase: 0.0, delay: 0.20),
        Spec(x: 0.71, y: 0.27, w: 7, h: 10, depth: 1.0, phase: 1.3, delay: 0.42),
        Spec(x: 0.17, y: 0.57, w: 8, h: 12, depth: 0.8, phase: 2.1, delay: 0.64),
        Spec(x: 0.82, y: 0.56, w: 10, h: 14, depth: 0.5, phase: 3.4, delay: 0.86),
        Spec(x: 0.36, y: 0.79, w: 7, h: 10, depth: 1.0, phase: 4.2, delay: 1.06),
        Spec(x: 0.65, y: 0.75, w: 9, h: 13, depth: 0.7, phase: 5.0, delay: 1.26),
    ]

    let size: CGFloat
    var dragTilt: CGSize = .zero
    @ObservedObject var tilt: OBTiltSource
    var entrance: Bool = true
    var dim: Bool = false

    @QuestifyReduceMotion private var reduceMotion
    @State private var appeared = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<Self.specs.count, id: \.self) { i in
                    window(Self.specs[i], t: t)
                }
            }
            .frame(width: size, height: size)
        }
        .opacity(dim ? 0.3 : 1)
        .animation(CYMotion.resolve(.easeInOut(duration: 0.6), reduceMotion: reduceMotion), value: dim)
        .onAppear { appeared = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func window(_ s: Spec, t: Double) -> some View {
        // Slow elliptical orbit (period 14-22 s) that never stops, plus a gentle idle sway standing in for gyro parallax.
        let w = 0.28 + 0.06 * s.depth
        let driftX = reduceMotion ? 0 : cos(t * w + s.phase) * (7 + 6 * s.depth) + sin(t * 0.5 + s.phase) * 3 * s.depth
        let driftY = reduceMotion ? 0 : sin(t * w * 0.8 + s.phase * 1.3) * (5 + 5 * s.depth)
        let flicker = reduceMotion ? 1 : 0.82 + 0.18 * sin(t * 1.9 + s.phase * 2)
        let px = (tilt.roll * 8 + Double(dragTilt.width) * 6) * s.depth
        let py = (-tilt.pitch * 8 + Double(dragTilt.height) * 6) * s.depth
        let show = !entrance || appeared
        let delay = (reduceMotion || !entrance) ? 0 : s.delay
        return ZStack {
            Circle().fill(CYNight.glow(radius: s.w * 1.6)).frame(width: s.w * 5, height: s.w * 5)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: [CYNight.lanternHot, CYNight.lantern], startPoint: .top, endPoint: .bottom))
                .frame(width: s.w, height: s.h)
        }
        .opacity(show ? flicker : 0)
        .offset(y: show ? 0 : 14)
        .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: 0.7).delay(delay), value: show)
        .position(x: size * s.x + driftX + px, y: size * s.y + driftY + py)
    }
}

// MARK: - Wordmark bloom

/// 城瘾 blooms: scale lands with overshoot, lantern glow swells then settles at about 55 %. `intensity` 1 = full
/// (welcome, 1.4 s), 0.4 for the final-step mark. Reduce Motion: crossfade to the settled state, no blur copies.
struct OBWordmarkBloom: View {
    let fontSize: CGFloat
    var delay: Double = 1.4
    var intensity: Double = 1
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale
    @State private var land = false
    @State private var glow: Double = 0

    var body: some View {
        let heavy = !OBType.isChinese(locale)
        let word = Text(verbatim: "城瘾").font(.system(size: fontSize, weight: heavy ? .heavy : .semibold, design: .rounded))
        let blurCopies = !reduceMotion && !reduceTransparency && CYLightBudget.shadersAllowed
        ZStack {
            Circle().fill(CYNight.glow(radius: fontSize)).frame(width: fontSize * 3.6, height: fontSize * 3.6)
                .opacity(glow * intensity)
            if blurCopies {
                ForEach([22.0, 9.0], id: \.self) { r in
                    word.foregroundStyle(CYNight.lantern).blur(radius: r).opacity(0.7 * glow * intensity)
                }
            }
            word.foregroundStyle(.white)
                .scaleEffect(land ? 1 : (reduceMotion ? 1 : 0.55))
                .opacity(land ? 1 : 0)
        }
        .task {
            if reduceMotion {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(CYMotion.reduced) { land = true; glow = 0.55 }
                return
            }
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.58)) { land = true }
            withAnimation(.easeOut(duration: 0.5)) { glow = 1 }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.9)) { glow = 0.55 }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Wave (Metal distortion, CYOnboardingWave.metal)

struct OBWaveModifier: ViewModifier {
    var origin: CGPoint
    var trigger: Int
    var amp: Double = 10
    @State private var start: Date?
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: start == nil)) { tl in
            let t = start.map { min(tl.date.timeIntervalSince($0) / 0.8, 1) } ?? 1
            #if CY_METAL_SHADERS
            content.distortionEffect(
                ShaderLibrary.cyOnboardWave(.float2(origin), .float(t), .float(amp), .float(0.09), .float2(0, 0)),
                maxSampleOffset: CGSize(width: 14, height: 14),
                isEnabled: t < 1 && !reduceMotion && CYLightBudget.metalShadersAllowed)
            #else
            // No Metal Toolchain: the wave is compiled out and the onboarding light plays without the distortion.
            let _ = t
            content
            #endif
        }
        .onChange(of: trigger) { _, _ in
            start = .now
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(850))
                start = nil
            }
        }
    }
}

extension View {
    func obWave(origin: CGPoint, trigger: Int, amp: Double = 10) -> some View {
        modifier(OBWaveModifier(origin: origin, trigger: trigger, amp: amp))
    }
}

// MARK: - Burst (Canvas particles)

struct OBBurst: View {
    private struct P { var a, v, size, hue, spin: Double }
    var origin: UnitPoint = .center
    var count = 25
    var duration = 1.0
    var radius: Double = 150
    private let colors: [Color] = [CYNight.lantern, CYNight.lanternHot, .white]
    @QuestifyReduceMotion private var reduceMotion
    @State private var ps: [P] = []
    @State private var t0 = Date()

    var body: some View {
        if reduceMotion || !CYLightBudget.particlesAllowed {
            EmptyView()
        } else {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(t0) / duration
                Canvas { ctx, size in
                    guard t < 1 else { return }
                    let o = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
                    for p in ps {
                        let d = p.v * (1 - pow(1 - t, 3)) * radius
                        let pt = CGPoint(x: o.x + cos(p.a) * d, y: o.y + sin(p.a) * d + 60 * t * t)
                        var c = ctx
                        c.opacity = 1 - t
                        c.translateBy(x: pt.x, y: pt.y)
                        c.rotate(by: .radians(p.spin * t))
                        c.fill(Path(ellipseIn: CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size * 0.6)),
                               with: .color(colors[Int(p.hue * Double(colors.count)) % colors.count]))
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                ps = (0..<count).map { _ in P(a: .random(in: 0..<2 * .pi), v: .random(in: 0.4...1), size: .random(in: 3...6), hue: .random(in: 0..<1), spin: .random(in: -6...6)) }
                t0 = .now
            }
        }
    }
}

// MARK: - Seal shape

/// Serrated seal: 36 teeth.
struct OBSealShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2, inner = outer * 0.92
        var path = Path()
        let teeth = 36
        for i in 0..<(teeth * 2) {
            let angle = Double(i) / Double(teeth * 2) * 2 * .pi
            let r = i.isMultiple(of: 2) ? outer : inner
            let p = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Create-account pill that morphs green

/// Width never changes: the fill crossfades to `verify` and the label swaps to a checkmark in place (desdivj).
struct OBMorphPill: View {
    let titleKey: LocalizedStringKey
    let done: Bool
    let action: () -> Void
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 56

    var body: some View {
        // The check is the transition only. At rest, and always under Reduce Motion, the label stays.
        let showCheck = done && !reduceMotion
        Button(action: action) {
            ZStack {
                Text(titleKey)
                    .cyText(.cardTitle)
                    .multilineTextAlignment(.center)
                    .opacity(showCheck ? 0 : 1)
                    .scaleEffect(showCheck ? 0.8 : 1)
                Image(systemName: "checkmark")
                    .font(.system(.title3).weight(.heavy))
                    .opacity(showCheck ? 1 : 0)
                    .scaleEffect(showCheck ? 1 : 0.5)
            }
            .foregroundStyle(showCheck ? CYNight.ink0 : palette.actionPrimaryFg)
            .padding(.horizontal, CYSpacing.xxl)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Capsule(style: .continuous).fill(showCheck ? CYNight.verify : palette.actionPrimaryBg))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.cyPressable)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: showCheck)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(showCheck ? Text("onboarding.createAccount.done") : Text(verbatim: ""))
    }
}

// MARK: - Drag hint

/// Glass capsule under the disc: a fingertip loops left-right-left (1.8 s) with a fading trail. Reduce Motion: static.
struct OBDragHint: View {
    let titleKey: LocalizedStringKey
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
                let p = reduceMotion ? 0 : sin(tl.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.8)
                ZStack {
                    Capsule().fill(CYNight.lanternHot.opacity(0.28)).frame(width: 30, height: 4).offset(x: -p * 8 - 2)
                        .opacity(reduceMotion ? 0 : abs(p))
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .offset(x: p * 11)
                }
                .frame(width: 44, height: 24)
            }
            Text(titleKey)
                .cyText(.bodyMedium)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.sm)
        .obGlassCapsule()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(titleKey))
    }
}

extension View {
    /// Night glass capsule (glassFill + top-lit edge) for hints under the disc.
    func obGlassCapsule() -> some View {
        self
            .background(.ultraThinMaterial, in: Capsule())
            .background(Capsule().fill(CYNight.glassFill))
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [CYNight.glassEdgeTop, CYNight.glassEdgeBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

// MARK: - Night map

/// Fogged city at night, seen from above: indigo sky, a perspective street plane, near and far blocks.
/// Lantern gold is only the five avenues (discovery). Layers parallax a little with the disc tilt FogWindow
/// already tracks. Reduce Motion holds every layer still. No drift, no timeline. No violet, no Metal.
struct OBNightMap: View {
    var lit: Bool
    /// Drag tilt, about -1...1. Ignored under Reduce Motion.
    var dragTilt: CGSize = .zero
    var roll: Double = 0
    var pitch: Double = 0

    @QuestifyReduceMotion private var reduceMotion

    /// Same scale as the lantern windows (`drag * 6 + roll * 8`), so the streets sit just behind the panes.
    private var shift: CGSize {
        guard !reduceMotion else { return .zero }
        return CGSize(
            width: dragTilt.width * 6 + CGFloat(roll) * 8,
            height: dragTilt.height * 6 - CGFloat(pitch) * 8)
    }

    /// Ground-plane across-axis. Negative is west.
    private static let streetsU: [CGFloat] = [-1.15, -0.68, -0.24, 0.18, 0.58, 1.05]
    /// 0 at the horizon, 1 at the near edge. Spacing is even in depth; projection packs the far rows.
    private static let streetsV: [CGFloat] = [0.18, 0.34, 0.50, 0.66, 0.82, 1.02]
    /// (column, row) into the gaps between the street lines. Row 2 stays open for the main avenue.
    private static let blocks: [(Int, Int)] = [
        (0, 0), (2, 0), (4, 0),
        (1, 1), (3, 1),
        (0, 3), (2, 3), (4, 3),
        (1, 4), (3, 4),
    ]
    /// Five avenues in ground-plane (u, v). They follow the open streets between blocks, bent through midpoints.
    private static let avenues: [[CGPoint]] = [
        [CGPoint(x: -1.30, y: 0.57), CGPoint(x: -0.20, y: 0.54), CGPoint(x: 0.45, y: 0.61), CGPoint(x: 1.30, y: 0.56)],
        [CGPoint(x: -0.70, y: 0.04), CGPoint(x: -0.66, y: 0.36), CGPoint(x: -0.72, y: 0.70), CGPoint(x: -0.64, y: 1.10)],
        [CGPoint(x: 0.20, y: 0.06), CGPoint(x: 0.16, y: 0.40), CGPoint(x: 0.22, y: 0.74), CGPoint(x: 0.14, y: 1.08)],
        [CGPoint(x: -1.25, y: 0.34), CGPoint(x: -0.15, y: 0.36), CGPoint(x: 0.55, y: 0.33), CGPoint(x: 1.25, y: 0.35)],
        [CGPoint(x: -1.15, y: 0.82), CGPoint(x: -0.10, y: 0.80), CGPoint(x: 0.50, y: 0.84), CGPoint(x: 1.20, y: 0.81)],
    ]

    var body: some View {
        let shift = shift
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: CYNight.ink0, location: 0),
                    .init(color: CYNight.indigo, location: 0.20),
                    .init(color: CYNight.indigo, location: 0.58),
                    .init(color: CYNight.ink1, location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                drawCity(ctx, size: size, shift: shift)
            }
            Canvas { ctx, size in
                drawAvenues(ctx, size: size, shift: shift)
            }
            .opacity(lit ? 0.85 : 0.50)
            .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: 0.9), value: lit)
            // Lens falloff. Stays put while the streets shift, so the rim does not slide off the disc.
            Canvas { ctx, size in
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0.58),
                            .init(color: CYNight.ink0.opacity(0.42), location: 1),
                        ]),
                        center: CGPoint(x: size.width / 2, y: size.height / 2),
                        startRadius: 0,
                        endRadius: size.width * 0.58))
            }
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Perspective: far rows pack toward a horizon in the upper fifth; near rows spread past the disc.
    private func project(_ u: CGFloat, _ v: CGFloat, _ size: CGSize) -> CGPoint {
        let depth = min(1.15, max(0, v))
        let y = size.height * (0.16 + 0.90 * depth * depth)
        let half = size.width * (0.10 + 0.58 * depth)
        return CGPoint(x: size.width * 0.5 + u * half, y: y)
    }

    private func shifted(_ ctx: GraphicsContext, depth: CGFloat, _ shift: CGSize) -> GraphicsContext {
        var copy = ctx
        copy.translateBy(x: shift.width * depth, y: shift.height * depth)
        return copy
    }

    private func drawCity(_ ctx: GraphicsContext, size: CGSize, shift: CGSize) {
        var sky = shifted(ctx, depth: 0.18, shift)
        let haze = CGRect(x: -size.width * 0.12, y: size.height * 0.08, width: size.width * 1.24, height: size.height * 0.18)
        for i in 0..<4 {
            let inset = CGFloat(i) * size.height * 0.018
            sky.fill(Path(ellipseIn: haze.insetBy(dx: inset * 1.6, dy: inset)), with: .color(.white.opacity(0.016)))
        }

        var far = shifted(ctx, depth: 0.32, shift)
        var near = shifted(ctx, depth: 0.62, shift)
        for (column, row) in Self.blocks {
            let (path, roof) = block(column, row, size)
            if row >= 3 {
                near.fill(path, with: .color(CYNight.ink0.opacity(0.72)))
                near.stroke(roof, with: .color(.white.opacity(0.14)), lineWidth: max(0.8, size.width * 0.003))
            } else {
                far.fill(path, with: .color(CYNight.ink0.opacity(0.40)))
            }
        }

        var grid = shifted(ctx, depth: 0.46, shift)
        var streets = Path()
        for v in Self.streetsV {
            streets.move(to: project(-1.5, v, size))
            streets.addLine(to: project(1.5, v, size))
        }
        for u in Self.streetsU {
            streets.move(to: project(u, 0.02, size))
            streets.addLine(to: project(u, 1.14, size))
        }
        grid.stroke(streets, with: .color(.white.opacity(0.07)), lineWidth: max(0.6, size.width * 0.002))
    }

    private func block(_ column: Int, _ row: Int, _ size: CGSize) -> (path: Path, roof: Path) {
        let u0 = Self.streetsU[column], u1 = Self.streetsU[column + 1]
        let v0 = Self.streetsV[row], v1 = Self.streetsV[row + 1]
        let du = (u1 - u0) * 0.16
        let dv = (v1 - v0) * 0.18
        let nw = project(u0 + du, v0 + dv, size)
        let ne = project(u1 - du, v0 + dv, size)
        let se = project(u1 - du, v1 - dv, size)
        let sw = project(u0 + du, v1 - dv, size)
        var path = Path()
        path.move(to: nw)
        path.addLine(to: ne)
        path.addLine(to: se)
        path.addLine(to: sw)
        path.closeSubpath()
        var roof = Path()
        roof.move(to: nw)
        roof.addLine(to: ne)
        return (path, roof)
    }

    private func drawAvenues(_ ctx: GraphicsContext, size: CGSize, shift: CGSize) {
        var gold = shifted(ctx, depth: 0.84, shift)
        let glow = max(4, size.width * 0.02)
        let core = max(1.1, size.width * 0.0045)
        let blur = max(2.5, size.width * 0.012)
        let lampR = max(2.4, size.width * 0.013)
        for pts in Self.avenues {
            let projected = pts.map { project($0.x, $0.y, size) }
            let path = curve(projected)
            gold.drawLayer { layer in
                layer.addFilter(.blur(radius: blur))
                layer.stroke(path, with: .color(CYNight.lantern.opacity(0.90)), lineWidth: glow)
            }
            gold.stroke(path, with: .color(CYNight.lanternHot), lineWidth: core)
            guard projected.count > 1 else { continue }
            let lamp = projected[1]
            let dot = CGRect(x: lamp.x - lampR, y: lamp.y - lampR, width: lampR * 2, height: lampR * 2)
            gold.drawLayer { layer in
                layer.addFilter(.blur(radius: lampR))
                layer.fill(Path(ellipseIn: dot), with: .color(CYNight.lantern.opacity(0.95)))
            }
            gold.fill(Path(ellipseIn: dot.insetBy(dx: lampR * 0.62, dy: lampR * 0.62)), with: .color(CYNight.lanternHot))
        }
    }

    private func curve(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        guard pts.count > 1 else { return path }
        for i in 1..<pts.count {
            let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
            path.addQuadCurve(to: mid, control: pts[i - 1])
        }
        path.addLine(to: pts[pts.count - 1])
        return path
    }
}
