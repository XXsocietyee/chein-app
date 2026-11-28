import SwiftUI

// Signature-moment kit (e5b): generated cover art, press feel, ring pulse, light confetti.
// Presentation only. Every moving piece is gated on Reduce Motion; haptics go through `CYHaptics`.

// MARK: - Cover art

/// Deterministic generated cover (gradient mesh + soft glow + SF Symbol) for tiles that have no photo.
/// The same `seed` always yields the same art, so fixtures look stable. Debug builds stamp a tiny label.
struct CYCoverArt: View {
    let seed: String
    var symbol: String? = nil
    var showsDebugLabel = true
    var showsGlyph = true
    var cornerRadius: CGFloat? = nil

    private static let symbols = ["fork.knife", "map", "ticket", "camera", "leaf", "cup.and.saucer", "figure.walk", "building.columns", "moon.stars", "music.note"]

    /// FNV-1a so the value is stable across launches (`String.hashValue` is randomised per process).
    static func stableHash(_ text: String) -> UInt64 {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 { value = (value ^ UInt64(byte)) &* 0x100000001b3 }
        return value
    }

    @ViewBuilder var body: some View {
        if let cornerRadius { art.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) } else { art }
    }

    @ViewBuilder private var art: some View {
        let h = Self.stableHash(seed)
        let hue = Double(h % 360) / 360.0
        let hue2 = (hue + 0.14).truncatingRemainder(dividingBy: 1)
        let hue3 = (hue + 0.52).truncatingRemainder(dividingBy: 1)
        let ax = 0.15 + Double((h >> 8) % 70) / 100.0
        let ay = 0.10 + Double((h >> 16) % 50) / 100.0
        let glyph = symbol ?? Self.symbols[Int((h >> 24) % UInt64(Self.symbols.count))]
        GeometryReader { proxy in
            let reach = max(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(colors: [Color(hue: hue, saturation: 0.78, brightness: 0.66), Color(hue: hue2, saturation: 0.85, brightness: 0.26)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(hue: hue3, saturation: 0.55, brightness: 0.95).opacity(0.55), .clear],
                               center: UnitPoint(x: ax, y: ay), startRadius: 0, endRadius: reach * 0.7)
                RadialGradient(colors: [Color(hue: hue2, saturation: 0.4, brightness: 1).opacity(0.28), .clear],
                               center: UnitPoint(x: 1 - ax, y: 1 - ay), startRadius: 0, endRadius: reach * 0.55)
                if showsGlyph { Image(systemName: glyph)
                    .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.42, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.20))
                    .offset(x: proxy.size.width * (ax - 0.5) * 0.4, y: -proxy.size.height * 0.08) }
                #if DEBUG
                if showsDebugLabel {
                    Text(verbatim: "DEBUG ART")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(6)
                }
                #endif
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Press feel

/// Spring scale-down on press with a selection tick. Use on cards and tiles.
struct CYPressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
            .cyHaptic(.selection, trigger: configuration.isPressed, where: CYHapticTransition.turnedOn)
    }
}

/// GO button feel. Hold: the circle springs to 0.9 and a ring tightens inward; touch-down fires a heavy impact (the roam
/// starts); release: a ring bursts outward and fades. `walking` swaps the idle breathing for a slow 3.2 s ring.
/// Also works as the style of a `NavigationLink` (the label is the circle artwork).
struct CYGoPressStyle: ButtonStyle {
    var walking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        CYGoPressBody(configuration: configuration, reduceMotion: reduceMotion, walking: walking)
    }
}

private struct CYGoPressBody: View {
    let configuration: ButtonStyle.Configuration
    let reduceMotion: Bool
    let walking: Bool
    @State private var burst = 0

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.5), value: configuration.isPressed)
            .background {
                ZStack {
                    CYRingPulse(trigger: burst, idle: !walking)
                    if walking { CYGoWalkingRing() }
                    CYGoHoldRing(pressed: configuration.isPressed)
                }.allowsHitTesting(false)
            }
            .cyHaptic(.impactHeavy, trigger: configuration.isPressed, where: CYHapticTransition.turnedOn)
            .onChange(of: configuration.isPressed) { old, new in if old && !new { burst += 1 } }
    }
}

/// Two quiet concentric rings: an idle breathing ring (when `idle`) and a one-shot burst whenever `trigger` changes.
struct CYRingPulse: View {
    var trigger: Int = 0
    var idle = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var burstProgress: CGFloat = 1

    var body: some View {
        ZStack {
            if idle && !reduceMotion {
                Circle()
                    .strokeBorder(Color.white.opacity(breathe ? 0.0 : 0.38), lineWidth: 2)
                    .scaleEffect(breathe ? 1.45 : 1.02)
            }
            if !reduceMotion {
                Circle()
                    .strokeBorder(Color.white.opacity(Double(1 - burstProgress) * 0.9), lineWidth: 4)
                    .scaleEffect(1 + burstProgress * 0.9)
            }
        }
        .onAppear {
            guard idle, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { breathe = true }
        }
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            burstProgress = 0
            withAnimation(.easeOut(duration: 0.6)) { burstProgress = 1 }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Entrance

private struct CYStaggerAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 18)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.08 * Double(index))) { shown = true }
            }
    }
}

extension View {
    /// Staggered fade + rise on first appearance. No-op under Reduce Motion.
    func cyStaggerAppear(_ index: Int) -> some View { modifier(CYStaggerAppear(index: index)) }
}

// MARK: - Confetti (light)

/// A short, restrained confetti burst. Fires when `trigger` changes (or once on appear with `onAppear`).
/// Under Reduce Motion nothing is drawn; pair it with `.cyHaptic(.success, ...)` and a symbol effect.
struct CYConfettiBurst: View {
    var trigger: Int = 0
    var fireOnAppear = false
    var pieces = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date?
    private let duration = 1.9
    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.78, blue: 0.28), Color(red: 0.99, green: 0.45, blue: 0.40),
        Color(red: 0.45, green: 0.80, blue: 0.95), Color(red: 0.70, green: 0.60, blue: 1.00), Color(red: 0.55, green: 0.90, blue: 0.62),
    ]

    private static func unit(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i &* 131 &+ k &* 7919)) * 43758.5453
        return x - floor(x)
    }

    /// Native r2: no confetti. Draws nothing; callers pair it with a system success haptic.
    var body: some View {
        EmptyView()
    }

    private func fire() {
        guard !reduceMotion else { return }
        start = Date()
    }
}
