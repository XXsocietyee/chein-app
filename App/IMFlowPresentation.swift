import SwiftUI

/// S02 presentation only. The original owners retain every state and request boundary.
/// Native r2: the system grouped form and the system prominent button, no custom type, tint or row heights.
private struct IMFlowFormPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IMFlowPrimaryActionPresentation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
    private var color: Color {
        switch tone {
        case .neutral: return .secondary
        case .attention: return .red
        case .success: return .green
        }
    }
    var body: some View {
        Label { text } icon: {
            Image(systemName: symbol).foregroundStyle(color).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
