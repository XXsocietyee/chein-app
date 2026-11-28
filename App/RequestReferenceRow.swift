import SwiftUI
import UIKit

/// OWN-OPT-072: a copyable, non-sensitive request reference under an unknown-result or server-error state.
/// Shows nothing when no fresh server reference exists; it never invents one.
struct RequestReferenceRow: View {
    let reference: String
    @State private var copied = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// a11y-dt r3: at accessibility sizes the copy button sits under the reference (same order); the reference wraps
    /// instead of shrinking.
    private var rowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
            : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
    }
    init?(pathFragment: String, ledger: RequestReferenceLedger = .shared) {
        guard let value = ledger.latest(pathFragment: pathFragment) else { return nil }
        reference = value
    }
    var body: some View {
        rowLayout {
            VStack(alignment: .leading, spacing: 2) {
                Text("requestReference.label").cyText(.caption).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: reference).cyText(.meta).monospaced().foregroundStyle(CYColor.textPrimary)
                    .textSelection(.enabled).lineLimit(3)
            }
            Spacer(minLength: 0)
            Button {
                LocalPasteboard.copy(reference)
                copied = true
            } label: {
                Label(LocalizedStringKey(copied ? "requestReference.copied" : "requestReference.copy"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    .cyText(.caption)
            }
            .buttonStyle(.borderless)
            .frame(minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("requestReference.row")
        .accessibilityLabel(Text("requestReference.label"))
        .accessibilityValue(Text(verbatim: reference))
        .accessibilityHint(Text(copied ? "requestReference.copied" : "requestReference.copy"))
    }
}
