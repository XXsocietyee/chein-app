import SwiftUI

/// IWP-8c receiver screen. Unmounted. The typed code stays in this view's @State only for the call;
/// it is cleared as soon as the claim is submitted and is never persisted or logged.
/// Every rejection (wrong / expired / used) shows the same single message.
@MainActor struct BundleTransferClaimView: View {
    @ObservedObject var model: BundleTransferClaimModel
    @State private var code = ""
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        Form {
            switch model.phase {
            case .claimed:
                text("transfer.claim.done").accessibilityIdentifier("bundleTransfer.claimed")
            case .unavailable:
                text("transfer.unavailable").accessibilityIdentifier("bundleTransfer.unavailable")
            default:
                Section {
                    TextField(text: $code) { text("transfer.claim.code") }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    CYPillButton("transfer.claim.action", style: .primary, tableName: table) {
                        let typed = code
                        code = ""
                        Task { await model.claim(code: typed) }
                    }
                        .disabled(code.isEmpty || model.phase == .claiming)
                }
                switch model.phase {
                case .claiming: CYLoadingStateView(rows: 1).accessibilityLabel(text("transfer.claiming"))
                case .codeNotAccepted: text("transfer.claim.rejected").accessibilityIdentifier("bundleTransfer.rejected")
                case .outcomeUnknown: text("transfer.claim.unknown")
                case .failed: text("transfer.error")
                default: EmptyView()
                }
            }
        }
        .cyGroupedSurface()
        .onDisappear { code = "" }
    }
}
