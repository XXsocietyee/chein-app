import SwiftUI

/// Unmounted candidate. Three server-driven states (success / review / rejected) plus `NONE`; any outcome the
/// app does not recognise is shown as neutral "processing". Reason text comes from the server only.
@MainActor struct BundleRedeemResultView: View {
    @ObservedObject var model: BundleVoucherModel
    let unitID: String
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        List {
            switch model.redeemState {
            case .idle, .loading:
                Section { ProgressView { text("bundle.redeem.loading") } }
            case .unavailable:
                Section { text("bundle.redeem.unavailable").accessibilityIdentifier("bundleRedeem.unavailable") }
            case .failed:
                Section {
                    text("bundle.redeem.error")
                    Button { Task { await model.loadRedeemResult(unitID: unitID) } } label: { text("bundle.redeem.retry") }
                }
            case .loaded(let presentation, let result):
                Section {
                    headline(presentation).accessibilityIdentifier("bundleRedeem.state")
                    if let name = result.merchantName, presentation == .success { Text(verbatim: name) }
                    if let reason = result.reason, !reason.isEmpty, presentation == .rejected || presentation == .review {
                        Text(verbatim: reason).font(.footnote)
                    }
                }
            }
        }
        .navigationTitle(Text("bundle.redeem.title", tableName: table))
        .task { await model.loadRedeemResult(unitID: unitID) }
    }

    private func headline(_ presentation: BundleRedeemPresentation) -> Text {
        switch presentation {
        case .success: return text("bundle.redeem.success")
        case .review: return text("bundle.redeem.review")
        case .rejected: return text("bundle.redeem.rejected")
        case .notRedeemed: return text("bundle.redeem.none")
        case .processing: return text("bundle.redeem.processing")
        }
    }
}
