import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Refund apply (IWP-R). Unmounted. The money gate is closed, so this screen does not send a refund.
/// The server route and amount are shown verbatim. There is no per-unit picker.
struct BundleRefundApplyView: View {
    let model: BundleRefundProgressModel

    private func phrase(_ zh: String, _ en: String) -> String { W8Text.t(zh, en) }

    var body: some View {
        Cloud03Screen(
            title: phrase("退款申请", "Refund request"),
            seed: model.expectedRoute.isEmpty ? "bundle-refund-apply" : model.expectedRoute,
            symbol: "arrow.uturn.backward"
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYListRow(verbatim: phrase("退回路由", "Refund route"), trailing: .value(Cloud03Copy.shown(model.expectedRoute)), card: true) {
                    CYRowIcon(systemImage: "arrow.uturn.backward")
                }
                .accessibilityIdentifier("bundleRefund.apply.route")
                CYListRow(verbatim: phrase("报价金额", "Quoted amount"), trailing: .value(Cloud03Copy.shown(model.expectedAmount)), card: true) {
                    CYRowIcon(systemImage: "tag")
                }
                .accessibilityIdentifier("bundleRefund.apply.amount")
                CYNoteBanner(
                    text: Text(verbatim: phrase("暂不可用，不会提交退款。", "Not available yet. No refund is sent.")),
                    symbol: "lock",
                    tone: .warning
                )
                .accessibilityIdentifier("bundleRefund.apply.unavailable")
                CYNoteBanner(
                    text: Text(verbatim: phrase("报价仅供查看，资金不会变动。", "Quote only. No money moves.")),
                    symbol: "info.circle",
                    tone: .info
                )
                if model.canApply {
                    CYPillButton(verbatim: phrase("提交退款申请", "Submit refund request"), systemImage: "paperplane") {
                        let key = UUID().uuidString
                        Task { await model.apply(idempotencyKey: key) }
                    }
                    .accessibilityIdentifier("bundleRefund.apply.submit")
                }
            }
        }
    }
}
