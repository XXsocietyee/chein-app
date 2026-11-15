import SwiftUI
import UIKit

// MARK: - Shake to roll

/// Mini-program 摇一摇掷骰/硬币 (2026-11-10 业主「掷骰子也可以摇晃的」): the system shake gesture fires
/// the same action as the on-screen button, which stays as the fallback when there is no motion.
/// Uses UIKit `motionEnded(.motionShake)`, so it needs no motion permission and never reads sensors
/// continuously. Disabled ⇒ ignored.
extension View {
    func cyOnShake(enabled: Bool = true, perform action: @escaping () -> Void) -> some View {
        background(CYShakeReader(enabled: enabled, action: action).frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

private struct CYShakeReader: UIViewRepresentable {
    let enabled: Bool
    let action: () -> Void
    func makeUIView(context: Context) -> CYShakeView { CYShakeView() }
    func updateUIView(_ view: CYShakeView, context: Context) {
        view.onShake = enabled ? action : nil
        if enabled, view.window != nil, !view.isFirstResponder { DispatchQueue.main.async { view.claimIfIdle() } }
    }
    static func dismantleUIView(_ view: CYShakeView, coordinator: ()) { view.onShake = nil; view.resignFirstResponder() }
}

final class CYShakeView: UIView {
    var onShake: (() -> Void)?
    override var canBecomeFirstResponder: Bool { onShake != nil }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { DispatchQueue.main.async { [weak self] in self?.claimIfIdle() } }
    }
    /// Never steals focus from a text field the player is typing in.
    func claimIfIdle() {
        guard onShake != nil, let window, !(window.firstResponderIsTextInput) else { return }
        becomeFirstResponder()
    }
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake, let onShake { onShake() } else { super.motionEnded(motion, with: event) }
    }
}

private extension UIView {
    var firstResponderIsTextInput: Bool {
        if isFirstResponder { return self is UITextInput }
        return subviews.contains { $0.firstResponderIsTextInput }
    }
}

// MARK: - D20 difficulty tiers

/// Mini-program playkit-journey-check `.jc__tiers`: 简单 / 标准 / 困难, the author's tier lit.
/// Unknown or empty tier lights 标准 (same as `tier === 'medium' || !tier`). Display only.
struct CYDiceTierStrip: View {
    let tier: String
    @Environment(\.cyThemeLook) private var look
    private var current: String {
        let value = tier.lowercased()
        return value == "easy" || value == "hard" ? value : "medium"
    }
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            ForEach(["easy", "medium", "hard"], id: \.self) { item in
                let on = item == current
                Text(LocalizedStringKey("mpd.dice.tier." + item))
                    .font(CYTypography.meta.weight(on ? .semibold : .regular))
                    .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs)
                    .foregroundStyle(on ? (look?.colors.bg.swiftUIColor ?? CYColor.bgPage) : (look?.colors.mute.swiftUIColor ?? CYColor.textSecondary))
                    .background(on ? (look?.colors.ink.swiftUIColor ?? CYColor.textPrimary) : Color.clear, in: Capsule())
                    .overlay(Capsule().strokeBorder((look?.colors.ink.swiftUIColor ?? CYColor.textTertiary).opacity(on ? 0 : 0.3), lineWidth: 0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("mpd.dice.tier.a11y \(Text(LocalizedStringKey("mpd.dice.tier." + current)))"))
        .accessibilityIdentifier("journey.check.tiers")
    }
}

// MARK: - Hold to shake

/// 「按住摇骰，松手掷出」: press and hold charges a bar (with a rising haptic and a shaking die), release rolls.
/// A plain tap also rolls (mini-program `bindtap="onRoll"`), and VoiceOver activation rolls once.
/// Reduce Motion: no shake, the bar fills without spring.
struct CYHoldToRollButton: View {
    let busy: Bool
    let action: () -> Void
    @State private var holding = false
    @State private var charge: CGFloat = 0
    @State private var startedAt: Date?
    @State private var tick = 0
    @Environment(\.isEnabled) private var enabled
    @Environment(\.cyThemeLook) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let fullCharge: TimeInterval = 0.9

    var body: some View {
        let colors = look?.colors
        let shape = RoundedRectangle(cornerRadius: look?.buttonRadius ?? CYRadius.pill, style: .continuous)
        ZStack(alignment: .leading) {
            shape.fill(colors?.ink.swiftUIColor ?? CYColor.textPrimary)
            shape.fill((colors?.a.swiftUIColor ?? CYColor.brand).opacity(0.85))
                .scaleEffect(x: max(charge, 0.0001), y: 1, anchor: .leading)
                .clipShape(shape)
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: "dice.fill")
                    .rotationEffect(.degrees(holding && !reduceMotion ? (tick.isMultiple(of: 2) ? -14 : 14) : 0))
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(busy ? "mpd.dice.hold.rolling" : (holding ? "mpd.dice.hold.release" : "mpd.dice.hold.idle")))
                    .contentTransition(.opacity)
            }
            .font(CYTypography.label)
            .fontDesign(look?.buttonDesign ?? .default)
            .foregroundStyle(colors?.bg.swiftUIColor ?? CYColor.bgPage)
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 56)
        .contentShape(shape)
        .opacity(enabled && !busy ? 1 : 0.55)
        .scaleEffect(holding && !reduceMotion ? 0.97 : 1)
        .animation(CYMotion.resolve(CYMotion.press, reduceMotion: reduceMotion), value: holding)
        .gesture(holdGesture)
        .cyHapticEvent(.diceRoll, trigger: tick) { _, _ in holding }
        .task(id: holding) { await shakeLoop() }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("mpd.dice.hold.a11y"))
        .accessibilityAction { if enabled && !busy { action() } }
        .accessibilityIdentifier("journey.check.roll")
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard enabled, !busy, !holding else { return }
                holding = true; startedAt = Date(); charge = 0
            }
            .onEnded { _ in
                guard holding else { return }
                holding = false; startedAt = nil
                withAnimation(CYMotion.resolve(CYMotion.release, reduceMotion: reduceMotion)) { charge = 0 }
                if enabled && !busy { action() }
            }
    }

    private func shakeLoop() async {
        guard holding else { return }
        while holding, !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(startedAt ?? Date())
            withAnimation(reduceMotion ? nil : .linear(duration: 0.08)) { charge = min(1, CGFloat(elapsed / fullCharge)) }
            tick &+= 1
            try? await Task.sleep(for: .milliseconds(80))
        }
    }
}
