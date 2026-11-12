import SwiftUI

/// Touch-origin wave (wave 3 B2, Jakubantalik). Press: the card dips to 0.985 over 120 ms. Release: a Metal
/// distortion ring ripples outward from the finger for 800 ms (hard stop at 850 ms) with a thin lantern ring,
/// the card springs 1.02 to 1.0, and the action starts a beat later so the ripple reads before the push.
/// Reduce Motion: dip only, action immediate. Low Power / thermal serious: no shader; the Canvas light pulse carries the effect.
enum CYWave {
    static let duration: TimeInterval = 0.8
    static let hardStop: TimeInterval = 0.85
    /// Wave front travel in pt; mirrors the constant in `CYWave.metal`.
    static let reach: CGFloat = 520
    static let dipScale: CGFloat = 0.985
    static let releaseScale: CGFloat = 1.02
    /// The action starts this long after release when the wave plays.
    static let actionLead: TimeInterval = 0.24
    static let tapSlop: CGFloat = 10
}

/// Marks a child (the pill) that owns its own tap, so the card-level release does not also activate the card.
private struct CYPressWaveExcludedKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

extension View {
    /// Tells the enclosing `cyPressWave` card that taps on this view belong to it (card-space frame).
    func cyPressWaveExcluded() -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: CYPressWaveExcludedKey.self, value: [proxy.frame(in: .named(CYPressWaveModel.space))])
        })
    }
    /// Anticipation dip, touch-origin wave and delayed activation for a tappable card.
    /// `onTap` runs for taps outside `cyPressWaveExcluded` children; route those children through `model.perform`.
    func cyPressWave(_ model: CYPressWaveModel, onTap: (() -> Void)?) -> some View {
        modifier(CYPressWaveModifier(model: model, onTap: onTap))
    }
}

@MainActor @Observable final class CYPressWaveModel {
    nonisolated static let space = "cyPressWave.card"
    fileprivate(set) var pressed = false
    fileprivate(set) var bump = false
    fileprivate(set) var origin = CGPoint.zero
    fileprivate(set) var start: Date?
    fileprivate var excluded: [CGRect] = []
    @ObservationIgnored private var tracking = false
    @ObservationIgnored private var stopTask: Task<Void, Never>?
    @ObservationIgnored private var actionTask: Task<Void, Never>?

    var waving: Bool { start != nil }

    func progress(at date: Date) -> Double {
        start.map { min(max(date.timeIntervalSince($0) / CYWave.duration, 0), 1) } ?? 1
    }

    fileprivate func down(at point: CGPoint, reduceMotion: Bool) {
        guard !tracking else { return }
        tracking = true
        origin = point
        withAnimation(CYMotion.resolve(CYMotion.press, reduceMotion: reduceMotion)) { pressed = true }
        CYHaptics.impactLight.play()
    }

    fileprivate func cancel(reduceMotion: Bool) {
        guard tracking else { return }
        tracking = false
        withAnimation(CYMotion.resolve(CYMotion.release, reduceMotion: reduceMotion)) { pressed = false }
    }

    /// Finger lifted inside the slop: spring 1.02 → 1.0 and, unless the wave is off, start the ripple.
    fileprivate func up(at point: CGPoint, waveOn: Bool, reduceMotion: Bool, activatesCard: Bool, action: (() -> Void)?) {
        guard tracking else { return }
        tracking = false
        origin = point
        CYHaptics.impactMedium.play()
        if reduceMotion {
            withAnimation(CYMotion.reduced) { pressed = false }
        } else {
            withAnimation(CYMotion.release) { pressed = false; bump = true }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(CYMotion.release) { self?.bump = false }
            }
        }
        if waveOn {
            start = .now
            stopTask?.cancel()
            stopTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(CYWave.hardStop))
                guard !Task.isCancelled else { return }
                self?.start = nil
            }
        }
        if activatesCard, let action { schedule(action, lead: waveOn) }
    }

    /// For the pill: same lead as the card so the ripple reads before the push.
    func perform(_ action: (() -> Void)?, waveOn: Bool) {
        guard let action else { return }
        schedule(action, lead: waveOn)
    }

    private func schedule(_ action: @escaping () -> Void, lead: Bool) {
        actionTask?.cancel()
        guard lead else { action(); return }
        actionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(CYWave.actionLead))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    #if DEBUG
    /// Fixture only: plays a full press/release at `point` with no finger so a recording needs no touch injection.
    func simulateTap(at point: CGPoint, waveOn: Bool, reduceMotion: Bool) async {
        down(at: point, reduceMotion: reduceMotion)
        try? await Task.sleep(for: .milliseconds(120))
        up(at: point, waveOn: waveOn, reduceMotion: reduceMotion, activatesCard: false, action: nil)
    }
    #endif

    fileprivate func isExcluded(_ point: CGPoint) -> Bool { excluded.contains { $0.contains(point) } }
}

/// Whether the light pulse (Canvas, cheap) plays: everything except Reduce Motion.
func cyLightAllowed(reduceMotion: Bool) -> Bool { !reduceMotion }

/// Whether the shader wave plays right now (not Reduce Motion, not Low Power / thermal serious).
@MainActor func cyWaveAllowed(reduceMotion: Bool) -> Bool { !reduceMotion && CYLightBudget.shadersAllowed }

struct CYPressWaveModifier: ViewModifier {
    let model: CYPressWaveModel
    var onTap: (() -> Void)?
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        let waveOn = cyLightAllowed(reduceMotion: reduceMotion)
        let shaderOn = cyWaveAllowed(reduceMotion: reduceMotion)
        TimelineView(.animation(paused: !model.waving)) { timeline in
            let t = model.progress(at: timeline.date)
            let origin = model.origin
            let lit = waveOn && model.waving && t < 1
            let active = shaderOn && lit
            content
                .overlay { CYTouchRipple(origin: origin, progress: t).opacity(lit ? 1 : 0) }
                .cyWaveDistortion(origin: origin, t: t, active: active)
        }
        .coordinateSpace(name: CYPressWaveModel.space)
        .scaleEffect(model.pressed ? CYWave.dipScale : (model.bump ? CYWave.releaseScale : 1))
        .onPreferenceChange(CYPressWaveExcludedKey.self) { model.excluded = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(CYPressWaveModel.space))
                .onChanged { value in
                    if hypot(value.translation.width, value.translation.height) > CYWave.tapSlop {
                        model.cancel(reduceMotion: reduceMotion)
                    } else {
                        model.down(at: value.startLocation, reduceMotion: reduceMotion)
                    }
                }
                .onEnded { value in
                    let moved = hypot(value.translation.width, value.translation.height)
                    guard moved <= CYWave.tapSlop else { model.cancel(reduceMotion: reduceMotion); return }
                    model.up(at: value.location, waveOn: waveOn, reduceMotion: reduceMotion,
                             activatesCard: !model.isExcluded(value.startLocation), action: onTap)
                }
        )
    }
}

extension View {
    /// Metal distortion path. Without `CY_METAL_SHADERS` the light pulse in `CYTouchRipple` carries the effect alone.
    @ViewBuilder fileprivate func cyWaveDistortion(origin: CGPoint, t: Double, active: Bool) -> some View {
        #if CY_METAL_SHADERS
        visualEffect { view, proxy in
            let c = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let len = max(hypot(c.x - origin.x, c.y - origin.y), 1)
            return view.distortionEffect(
                ShaderLibrary.cyWave(.float2(origin), .float(t), .float(10), .float(0.09),
                                     .float2(CGPoint(x: (c.x - origin.x) / len, y: (c.y - origin.y) / len))),
                maxSampleOffset: CGSize(width: 12, height: 12), isEnabled: active && CYLightBudget.metalShadersAllowed)
        }
        #else
        self
        #endif
    }
}

/// Non-shader light: a soft radial lantern pulse from the touch point (0 to 280 pt over 600 ms, blurred), two 3 pt
/// rings fading out, and a brief 0.04 white lift of the whole card. Carries the effect alone when the Metal wave is
/// off or compiled out; sits on top of it otherwise. Lantern is allowed on the press ripple.
struct CYTouchRipple: View {
    var origin: CGPoint
    var progress: Double
    private static let pulseDuration = 0.6

    var body: some View {
        Canvas { ctx, size in
            let t = progress
            let elapsed = t * CYWave.duration
            let p = min(elapsed / Self.pulseDuration, 1)
            let easeOut = 1 - pow(1 - p, 3)
            ctx.blendMode = .plusLighter
            // Brightness lift: peaks at 80 ms, gone by 400 ms.
            let lift = max(0, elapsed < 0.08 ? elapsed / 0.08 : 1 - (elapsed - 0.08) / 0.32)
            if lift > 0 { ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.04 * lift))) }
            // Radial pulse.
            if p < 1 {
                let r = 280 * easeOut
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 6))
                    layer.fill(Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2)),
                               with: .radialGradient(Gradient(colors: [CYNight.lanternHot.opacity(0.35 * (1 - p)), .clear]),
                                                     center: origin, startRadius: 0, endRadius: max(r, 1)))
                }
            }
            // Two rings, the second 90 ms behind, 3 pt, ~40 % fading.
            for delay in [0.0, 0.09] {
                let q = min(max((elapsed - delay) / CYWave.duration, 0), 1)
                guard q > 0, q < 1 else { continue }
                let r = CYWave.reach * CGFloat(1 - pow(1 - q, 2))
                ctx.stroke(Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2)),
                           with: .color(CYNight.lanternHot.opacity(0.4 * (1 - q))), lineWidth: 3)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Button flavour for standalone cards (no nested button): same dip/spring, wave starts on release.
struct CYPressWaveStyle: ButtonStyle {
    var model: CYPressWaveModel
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.cyPressHandled, true)
            .cyPressWave(model, onTap: nil)
    }
}
