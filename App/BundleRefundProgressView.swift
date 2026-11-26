import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Refund progress (IWP-R). Unmounted. "Refunded" is shown only when the presentation says the server state is REFUNDED.
/// Processing, an unknown outcome, and a manual payout stay in progress.
struct BundleRefundProgressView: View {
    let presentation: BundleRefundProgressPresentation

    private func phrase(_ zh: String, _ en: String) -> String { W8Text.t(zh, en) }

    var body: some View {
        Cloud03Screen(
            title: phrase(presentation.titleZh, presentation.titleEn),
            seed: presentation.serverState.isEmpty ? "bundle-refund-progress" : presentation.serverState,
            symbol: presentation.showsRefunded ? "checkmark.circle" : "clock"
        ) {
            Section {
                LabeledContent {
                    Text(verbatim: Cloud03Copy.shown(presentation.serverState))
                } label: {
                    Label(phrase("服务器状态", "Server state"), systemImage: "server.rack")
                }
                .accessibilityIdentifier("bundleRefund.progress.state")
                if let refundNo = presentation.refundNo {
                    LabeledContent {
                        Text(verbatim: Cloud03Copy.shown(refundNo))
                    } label: {
                        Label(phrase("退款单号", "Refund number"), systemImage: "number")
                    }
                    .accessibilityIdentifier("bundleRefund.progress.number")
                }
            } footer: {
                if !presentation.showsRefunded {
                    Cloud03Note(
                        text: Text(verbatim: phrase("尚未退款。处理中、结果未知或人工打款都不是已退款。", "Not refunded yet. Processing, an unknown outcome, or a manual payout is not a refund.")),
                        symbol: "clock",
                        tone: .info
                    )
                    .accessibilityIdentifier("bundleRefund.progress.notRefunded")
                }
            }
        }
    }
}
