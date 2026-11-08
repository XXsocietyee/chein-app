import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Read-only refund quote (IWP-3). Shows the server's route, amount and remaining ratio as returned.
/// Intentionally contains no action control: applying a refund is a later work package.
/// Not mounted anywhere; a later composition WP decides where it appears.
struct BundleRefundQuoteView: View {
    let presentation: BundleRefundQuotePresentation
    init(quote: FreeExploreLaunchRefundQuote) { presentation = BundleRefundQuotePresentation(quote: quote) }

    private var table: String { BundleRefundQuotePresentation.tableName }

    var body: some View {
        List {
            Section {
                Text(LocalizedStringKey(presentation.routeTitleKey), tableName: table)
                    .font(.headline)
                    .accessibilityIdentifier("bundleRefund.route")
                Text(LocalizedStringKey(presentation.routeBodyKey), tableName: table)
                if let reason = presentation.serverReason {
                    Text(verbatim: reason).foregroundStyle(.secondary)
                }
            }
            Section {
                row("amountLabel", presentation.amountText)
                row("remainingRatioLabel", presentation.remainingRatioText)
                row("remainingValueLabel", presentation.remainingValueText)
                row("totalValueLabel", presentation.totalValueText)
            }
            if let key = presentation.afterSalesPointerKey {
                Section {
                    Text(LocalizedStringKey(key), tableName: table)
                        .accessibilityIdentifier("bundleRefund.afterSales")
                }
            }
            Section {
                Text(LocalizedStringKey(presentation.quoteOnlyNoticeKey), tableName: table)
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("bundleRefund.quoteOnly")
                Text(verbatim: presentation.policyVersion).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("title", tableName: table))
    }

    private func row(_ labelKey: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(labelKey), tableName: table)
            Spacer()
            Text(verbatim: value).foregroundStyle(.secondary)
        }
    }
}
