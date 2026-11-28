import SwiftUI

// `Player/Hold Button` (skill-r2 SR2-10): Rest / Holding (松手取消) / Done. Hold 0.8 s; the ring
// trims 0 → 1 linearly; an early release springs it back. VoiceOver and Reduce Motion users get a
// plain activation (HIG gestures: more than one way to interact).

struct CityHoldButton: View {
    let title: String
    var holdingTitle: String
    var enabled = true
    let onCommit: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    static let duration = 0.8

    var body: some View {
        ZStack {
            Capsule().fill(palette.actionPrimaryBg)
            Capsule().strokeBorder(palette.actionPrimaryFg.opacity(0.18), lineWidth: 2)
            Capsule().inset(by: 1).trim(from: 0, to: progress)
                .stroke(palette.actionPrimaryFg, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            HStack(spacing: CYSpacing.sm) {
                if done { Image(systemName: "checkmark").accessibilityHidden(true) }
                Text(verbatim: holding ? holdingTitle : title).lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            }
            .cyText(.button)
            .foregroundStyle(palette.actionPrimaryFg)
            .padding(.horizontal, CYSpacing.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .scaleEffect(holding ? 0.97 : 1)
        .opacity(enabled ? 1 : 0.4)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: reduceMotion ? 0 : Self.duration, maximumDistance: 24) {
            commit()
        } onPressingChanged: { pressing in
            guard enabled, !reduceMotion else { return }
            holding = pressing
            if pressing {
                withAnimation(.linear(duration: Self.duration)) { progress = 1 }
            } else if !done {
                withAnimation(CityTokens.pressSpring) { progress = 0 }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: done, condition: CYHapticTransition.isOn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
        .accessibilityIdentifier("city.roam.hold")
    }

    private func commit() {
        guard enabled else { return }
        done = true
        holding = false
        progress = 1
        onCommit()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            done = false
            withAnimation(CityTokens.pressSpring) { progress = 0 }
        }
    }
}
