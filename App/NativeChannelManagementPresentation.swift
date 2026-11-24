import SwiftUI

struct NativeChannelFlowReference: View {
    let label: Text
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            label.cyText(.label).foregroundStyle(.secondary)
            Text(verbatim: value).font(.callout.monospaced())
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }.accessibilityElement(children: .combine)
    }
}

/// Full-width read-only facts keep long values legible beside their original labels.
struct NativeChannelFlowFact: View {
    let label: Text
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1) {
            label.cyText(.meta).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: value).cyText(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
