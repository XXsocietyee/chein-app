import SwiftUI

/// Mini `club/components/club-game-code-sheet` (Figma 335:1275): QR card, topic name, save action.
/// States: loading ("generating" placeholder in the code's footprint), ready (code), error (a line of
/// copy sized to its content plus retry, never the empty code-sized box).
/// Save is the reason the mini sheet exists (some plays print the code for stations); native shows it
/// only when the host passes `onSave`. Nil keeps it hidden (capability absent => hidden).
struct CYClubGameCodeCard<Code: View>: View {
    enum Phase: Equatable { case loading, ready, error(String?) }
    let state: Phase
    let name: String?
    var onRetry: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil
    @ViewBuilder let code: () -> Code
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var codeSide: CGFloat = 240

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            switch state {
            case .loading:
                RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYNight.ink2)
                    .frame(width: codeSide, height: codeSide)
                    .overlay(Text("gameCode.generating", tableName: "SocialParity").cyText(.meta).foregroundStyle(CYColor.textTertiary))
                    .accessibilityIdentifier("club.gameCode.loading")
            case .ready:
                code()
                    .frame(maxWidth: codeSide, maxHeight: codeSide)
                    .padding(CYSpacing.md)
                    .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(Color.white))
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
            case .error(let message):
                VStack(spacing: CYSpacing.md) {
                    Group {
                        if let message, !message.isEmpty { Text(verbatim: message) } else { Text("gameCode.failed", tableName: "SocialParity") }
                    }
                    .cyText(.body).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    if let onRetry {
                        CYPillButton("gameCode.retry", style: .secondary, fullWidth: false, compact: true, tableName: "SocialParity", action: onRetry)
                            .accessibilityIdentifier("club.gameCode.retry")
                    }
                }
                .accessibilityIdentifier("club.gameCode.error")
            }
            if let name, !name.isEmpty {
                Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
            }
            if state == .ready, let onSave {
                Button(action: onSave) {
                    Label { Text("gameCode.save", tableName: "SocialParity") } icon: { Image(systemName: "arrow.down.to.line") }
                        .font(CYTypography.label.weight(.semibold)).foregroundStyle(CYColor.textPrimary)
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.cyPressable)
                .accessibilityHint(Text("gameCode.saveHint", tableName: "SocialParity"))
                .accessibilityIdentifier("club.gameCode.save")
            }
        }
        .padding(CYSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(CYNight.ink1))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
        .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: state)
    }
}
