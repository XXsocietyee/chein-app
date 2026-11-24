import SwiftUI

/// S02 presentation only. The original owners retain every state and request boundary.
private struct IMFlowFormPresentation: ViewModifier {
    @Environment(\.themeDomain) private var domain
    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .cyText(.body)
            .environment(\.defaultMinListRowHeight, 44)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IMFlowPrimaryActionPresentation: ViewModifier {
    @Environment(\.themeDomain) private var domain
    func body(content: Content) -> some View {
        content.cyText(.button)
            .buttonStyle(.questifyPrimary)
            .controlSize(.large)
            .tint(Theme.Color.actionPrimaryBackground(in: domain))
            .foregroundStyle(Theme.Color.actionPrimaryForeground(in: domain))
            .frame(minHeight: 44)
    }
}

extension View {
    func imFlowForm() -> some View { modifier(IMFlowFormPresentation()) }
    func imFlowPrimaryAction() -> some View { modifier(IMFlowPrimaryActionPresentation()) }
}

/// One existing state, readable independently of color; never infers an operation result.
struct IMFlowStateMessage: View {
    enum Tone { case neutral, attention, success }
    let text: Text
    var symbol = "info.circle"
    var tone: Tone = .neutral
    @Environment(\.cyPalette) private var palette
    private var color: Color {
        switch tone {
        case .neutral: return palette.textSecondary
        case .attention: return palette.danger
        case .success: return palette.success
        }
    }
    private var fill: Color {
        switch tone {
        case .neutral: return palette.actionSecondaryBg
        case .attention: return palette.dangerSoft
        case .success: return palette.successSoft
        }
    }
    var body: some View {
        Label { text.fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: symbol).accessibilityHidden(true)
        }
        .cyText(.bodyCompact)
        .foregroundStyle(color)
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
