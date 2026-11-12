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
        Button(action: action) {
            ZStack {
                Text(titleKey)
                    .font(.system(.body).weight(.bold))
                    .multilineTextAlignment(.center)
                    .opacity(done ? 0 : 1)
                    .scaleEffect(done && !reduceMotion ? 0.8 : 1)
                Image(systemName: "checkmark")
                    .font(.system(.title3).weight(.heavy))
                    .symbolEffect(.bounce, value: done)
                    .opacity(done ? 1 : 0)
                    .scaleEffect(done || reduceMotion ? 1 : 0.5)
            }
            .foregroundStyle(done ? CYNight.ink0 : palette.actionPrimaryFg)
            .padding(.horizontal, CYSpacing.xxl)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Capsule(style: .continuous).fill(done ? CYNight.verify : palette.actionPrimaryBg))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.cyPressable)
        .animation(reduceMotion ? CYMotion.reduced : .spring(response: 0.4, dampingFraction: 0.7), value: done)
        .accessibilityLabel(Text(titleKey))
        .accessibilityValue(done ? Text("onboarding.createAccount.done") : Text(verbatim: ""))
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
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .offset(x: p * 11)
                }
                .frame(width: 44, height: 24)
            }
            Text(titleKey)
                .font(.subheadline.weight(.medium))
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

/// The fogged city seen at night: indigo ground, a faint street grid, lantern-gold avenues. Lit = avenues at 60 %
/// with a soft glow; unlit (under fog) = 30 %. No hue outside indigo / lantern.
struct OBNightMap: View {
    var lit: Bool
    @QuestifyReduceMotion private var reduceMotion

    // Avenues as unit-space polylines (x, y), smoothed with quad curves through midpoints.
    private static let avenues: [[CGPoint]] = [
        [.init(x: 0.02, y: 0.62), .init(x: 0.25, y: 0.55), .init(x: 0.52, y: 0.60), .init(x: 0.98, y: 0.42)],
        [.init(x: 0.10, y: 0.08), .init(x: 0.30, y: 0.34), .init(x: 0.46, y: 0.58), .init(x: 0.58, y: 0.98)],
        [.init(x: 0.90, y: 0.05), .init(x: 0.74, y: 0.30), .init(x: 0.66, y: 0.62), .init(x: 0.80, y: 0.96)],
        [.init(x: 0.00, y: 0.28), .init(x: 0.34, y: 0.30), .init(x: 0.70, y: 0.26), .init(x: 1.00, y: 0.18)],
        [.init(x: 0.18, y: 0.92), .init(x: 0.40, y: 0.80), .init(x: 0.62, y: 0.82), .init(x: 0.96, y: 0.74)],
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [CYNight.indigo, CYNight.ink1], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // Faint grid, rotated a little so it reads as streets, not graph paper.
                var grid = Path()
                let step = size.width / 9
                for i in -2...12 {
                    let v = CGFloat(i) * step
                    grid.move(to: CGPoint(x: v, y: -20)); grid.addLine(to: CGPoint(x: v, y: size.height + 20))
                    grid.move(to: CGPoint(x: -20, y: v)); grid.addLine(to: CGPoint(x: size.width + 20, y: v))
                }
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                g.rotate(by: .degrees(-12))
                g.translateBy(x: -size.width / 2, y: -size.height / 2)
                g.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 0.6)
                // Lantern avenues: a wide soft pass, then a thin bright core.
                for pts in Self.avenues {
                    var path = Path()
                    let p = pts.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                    path.move(to: p[0])
                    for i in 1..<p.count {
                        let mid = CGPoint(x: (p[i - 1].x + p[i].x) / 2, y: (p[i - 1].y + p[i].y) / 2)
                        path.addQuadCurve(to: mid, control: p[i - 1])
                    }
                    path.addLine(to: p[p.count - 1])
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 4))
                        l.stroke(path, with: .color(CYNight.lantern.opacity(0.5)), lineWidth: 5)
                    }
                    ctx.stroke(path, with: .color(CYNight.lanternHot.opacity(0.9)), lineWidth: 1.2)
                }
            }
            .opacity(lit ? 0.6 : 0.3)
            .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: 0.9), value: lit)
            RadialGradient(colors: [CYNight.lantern.opacity(lit ? 0.12 : 0.04), .clear], center: .center, startRadius: 0, endRadius: 140)
        }
    }
}
