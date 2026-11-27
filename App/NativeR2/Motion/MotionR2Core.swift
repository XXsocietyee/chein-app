import SwiftUI
import UIKit

// Native r2 motion r2 (owner's 20 X references, brief `docs/briefs/native-r2-motion-r2.md`).
// The "delight" layer on top of the Apple-native base: only at a moment of meaning (reward, arrival, success,
// first-run), never on plain lists. System springs; every moment has a Reduce Motion version (fade or static) and
// a VoiceOver announcement or label. One switch: `-nativeR2.motion2 NO` turns every R-moment off.

extension NativeR2Flags {
    /// Motion r2 delight moments (R1–R18). Default on.
    static var motion2: Bool { isEnabled("nativeR2.motion2") }
    /// R5 tab-symbol bounce. The system tab bar renders label images itself and may ignore symbol effects, so this
    /// stays off until a simulator check confirms it (`-nativeR2.motion2.tabBounce YES`).
    static var motion2TabBounce: Bool { motion2 && isEnabled("nativeR2.motion2.tabBounce", default: false) }
}

/// Shared switches and helpers for the motion r2 moments.
enum MotionR2 {
    /// Animated version allowed: the flag is on and Reduce Motion is off.
    static func live(reduceMotion: Bool) -> Bool { NativeR2Flags.motion2 && !reduceMotion }

    /// The system spring used by every moment (close to UIKit's default sheet spring).
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    /// The press spring (stamp ink press, reward pop).
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.55)

    /// Approximate display corner radius for the edge glow (iPhones with Face ID are 39–55 pt; 0 on Home-button phones).
    @MainActor static var displayCornerRadius: CGFloat {
        let insets = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
        return insets > 0 ? 47 : 0
    }

    /// Posts a VoiceOver announcement for a catalog key.
    @MainActor static func announce(_ key: String.LocalizationValue) {
        AccessibilityNotification.Announcement(appLocalized(key, locale: Locale.current)).post()
    }

    /// Posts a VoiceOver announcement for an already-resolved sentence.
    @MainActor static func announce(verbatim sentence: String) {
        guard !sentence.isEmpty else { return }
        AccessibilityNotification.Announcement(sentence).post()
    }
}

// MARK: - R2 / R13 tilt (CoreMotion attitude → rotation3DEffect, clamped)

/// Turns the content with the phone (R13) using the one shared `CYTilt` source. The source runs only while this view
/// is on screen (`cyTiltHold` releases it on disappear), never under Reduce Motion, Low Power or the flag off.
struct MotionR2Tilt: ViewModifier {
    var maxDegrees: Double = 12
    var enabled: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pitchBaseline: Double?

    private var live: Bool { enabled && MotionR2.live(reduceMotion: reduceMotion) && CYLightBudget.gyroAllowed }

    private func clamped(_ radians: Double) -> Double {
        let degrees = radians * 180 / Double.pi
        return min(self.maxDegrees, max(-self.maxDegrees, degrees))
    }

    func body(content: Content) -> some View {
        let tilt = CYTilt.shared
        let roll = live ? clamped(tilt.roll) : 0
        let pitch = live ? clamped(tilt.pitch - (pitchBaseline ?? tilt.pitch)) : 0
        return content
            .rotation3DEffect(.degrees(roll), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(-pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .cyTiltHold(live)
            .onChange(of: live) { _, isLive in if !isLive { pitchBaseline = nil } }
            .onChange(of: tilt.pitch) { _, value in if live, pitchBaseline == nil { pitchBaseline = value } }
    }
}

/// R2 holographic sheen: a soft white band that slides across the content with the phone's roll.
/// Reduce Motion or the flag off: no sheen (the content stays as it is).
struct MotionR2HoloSheen: ViewModifier {
    var active: Bool = true
    var cornerRadius: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var live: Bool { active && MotionR2.live(reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        let roll = live && CYLightBudget.gyroAllowed ? CYTilt.shared.roll : 0
        let shift = CGFloat(max(-0.6, min(0.6, roll)))
        return content.overlay {
            if live {
                LinearGradient(colors: [.clear, .white.opacity(0.5), .cyan.opacity(0.25), .pink.opacity(0.2), .clear],
                               startPoint: UnitPoint(x: -0.2 + shift, y: 0),
                               endPoint: UnitPoint(x: 1.2 + shift, y: 1))
                    .blendMode(.overlay)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - R8 edge glow

/// R8: the screen edge glows once (0.8 s) in a colour when a success happens. Decoration only (hidden from
/// VoiceOver; the success itself announces). Reduce Motion or the flag off: nothing.
struct MotionR2EdgeGlow: ViewModifier {
    let active: Bool
    let fireOnAppear: Bool
    let color: Color
    @State private var glowing = false
    @State private var fired = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay { glowLayer }
            .onAppear { if fireOnAppear { fire() } }
            .onChange(of: active) { old, new in if !old && new { fire() } }
    }

    @ViewBuilder private var glowLayer: some View {
        if glowing {
            RoundedRectangle(cornerRadius: MotionR2.displayCornerRadius, style: .continuous)
                .strokeBorder(AngularGradient(colors: [color, color.opacity(0.35), color, color.opacity(0.6), color],
                                              center: .center), lineWidth: 8)
                .blur(radius: 10)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
        }
    }

    private func fire() {
        guard MotionR2.live(reduceMotion: reduceMotion), !fired || !fireOnAppear else { return }
        fired = true
        withAnimation(.easeOut(duration: 0.2)) { glowing = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeIn(duration: 0.35)) { glowing = false }
        }
    }
}

extension View {
    /// R13: the content turns with the phone (±`maxDegrees`).
    func motionR2Tilt(maxDegrees: Double = 12, enabled: Bool = true) -> some View {
        modifier(MotionR2Tilt(maxDegrees: maxDegrees, enabled: enabled))
    }

    /// R2: holographic sheen that follows the phone's roll.
    func motionR2HoloSheen(active: Bool = true, cornerRadius: CGFloat = 16) -> some View {
        modifier(MotionR2HoloSheen(active: active, cornerRadius: cornerRadius))
    }

    /// R8: one edge glow when `active` turns true.
    func motionR2EdgeGlow(when active: Bool, color: Color = .green) -> some View {
        modifier(MotionR2EdgeGlow(active: active, fireOnAppear: false, color: color))
    }

    /// R8: one edge glow when the view appears (finish line).
    func motionR2EdgeGlowOnAppear(color: Color = .green) -> some View {
        modifier(MotionR2EdgeGlow(active: false, fireOnAppear: true, color: color))
    }
}
