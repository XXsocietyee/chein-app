import SwiftUI
import UIKit

// Night-city light, wave 3 (B6): the screen-edge light sweep that answers a verified pass.
// One comet of `verify` green runs once around the display edge (0 to 450 ms), then a steady ring at 60 % fades out
// (450 to 900 ms). Mount with `.cyEdgeGlow(trigger:)` on a screen root; it hugs the display corners because the
// overlay ignores the safe area. Fallbacks (spec 3.6): Reduce Motion = the ring fades in and out, no sweep;
// Reduce Transparency = a solid 2 pt ring, no blur; Low Power / thermal = sweep on, blur copies off.
// Haptics: impactLight at 0, impactLight at 130 ms, success at 260 ms (single success under Reduce Motion).

enum CYDisplayCorner {
    /// Display corner radius without private API: 55 pt on Face ID iPhones (safe-area top > 24 pt), 0 on home-button
    /// devices and when no window is up yet.
    @MainActor static var radius: CGFloat {
        let top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets.top ?? 0
        return top > 24 ? 55 : 0
    }
}

/// The light itself, a pure function of `sweep` (comet position, 0 to 1) and `ring` (steady ring intensity, 0 to 1).
struct CYEdgeGlow: View, Animatable {
    var color: Color = CYNight.verify
    var sweep: Double
    var ring: Double
    var cornerRadius: CGFloat = 55
    /// Reduce Transparency: a solid 2 pt ring, no comet, no blur.
    var solid = false
    /// Low Power / thermal: keep the comet, drop the blur copies.
    var cheap = false

    /// Animatable so the comet position is interpolated every frame (the `sweep` range test below reads the live value).
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(sweep, ring) }
        set { sweep = newValue.first; ring = newValue.second }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if solid {
                shape.strokeBorder(color.opacity(ring), lineWidth: 2)
            } else {
                if sweep > 0 && sweep < 1 {
                    if !cheap { shape.strokeBorder(comet, lineWidth: 12).blur(radius: 8).opacity(0.9) }
                    shape.strokeBorder(comet, lineWidth: 6).blur(radius: cheap ? 0 : 3)
                }
                shape.strokeBorder(color.opacity(0.6 * ring), lineWidth: 1.5)
                if !cheap { shape.strokeBorder(color.opacity(0.45 * ring), lineWidth: 5).blur(radius: 7) }
            }
        }
        .ignoresSafeArea()
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A tail that fades in over the last half turn and a near-white head at the leading point.
    private var comet: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.55),
                .init(color: color.opacity(0.9), location: 0.94),
                .init(color: .white.opacity(0.95), location: 1),
            ]),
            center: .center, angle: .degrees(sweep * 360 - 90))
    }
}

/// Drives `CYEdgeGlow` once per `trigger` change and plays the haptic ladder.
private struct CYEdgeGlowDriver: View {
    let trigger: Int
    let color: Color
    @State private var sweep = 0.0
    @State private var ring = 0.0
    @State private var run: Task<Void, Never>?
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var radius: CGFloat = 55

    var body: some View {
        CYEdgeGlow(color: color, sweep: sweep, ring: ring, cornerRadius: radius,
                   solid: reduceTransparency, cheap: !CYLightBudget.shadersAllowed)
            .onChange(of: trigger) { _, _ in fire() }
            .onAppear { radius = CYDisplayCorner.radius }
            .onDisappear { run?.cancel() }
    }

    private func fire() {
        run?.cancel()
        radius = CYDisplayCorner.radius
        run = Task { @MainActor in
            if reduceMotion {
                sweep = 0
                CYHaptics.success.play()
                withAnimation(.easeOut(duration: CYMotion.Duration.quick)) { ring = 1 }
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.45)) { ring = 0 }
                return
            }
            sweep = 0; ring = 0
            CYHaptics.impactLight.play()
            withAnimation(.easeInOut(duration: 0.45)) { sweep = 1 }
            withAnimation(.easeOut(duration: 0.3)) { ring = 1 }
            try? await Task.sleep(for: .milliseconds(130))
            guard !Task.isCancelled else { return }
            CYHaptics.impactLight.play()
            try? await Task.sleep(for: .milliseconds(130))
            guard !Task.isCancelled else { return }
            CYHaptics.success.play()
            try? await Task.sleep(for: .milliseconds(190))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.45)) { ring = 0 }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            sweep = 0
        }
    }
}

extension View {
    /// Sweeps `color` once around the display edge whenever `trigger` changes. Mount at a screen root.
    func cyEdgeGlow(trigger: Int, color: Color = CYNight.verify) -> some View {
        overlay { CYEdgeGlowDriver(trigger: trigger, color: color) }
    }
}
