import SwiftUI
import UIKit

/// OWN-OPT-072: a copyable, non-sensitive request reference under an unknown-result or server-error state.
/// Shows nothing when no fresh server reference exists; it never invents one.
struct RequestReferenceRow: View {
    let reference: String
    @State private var copied = false
    init?(pathFragment: String, ledger: RequestReferenceLedger = .shared) {
        guard let value = ledger.latest(pathFragment: pathFragment) else { return nil }
        reference = value
    }
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("requestReference.label").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: reference).font(CYTypography.meta).monospaced().foregroundStyle(CYColor.textPrimary)
                    .textSelection(.enabled).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Button {
                LocalPasteboard.copy(reference)
                copied = true
            } label: {
                Label(LocalizedStringKey(copied ? "requestReference.copied" : "requestReference.copy"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(CYTypography.caption)
            }
            .buttonStyle(.borderless)
            .frame(minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("requestReference.row")
    }
}
