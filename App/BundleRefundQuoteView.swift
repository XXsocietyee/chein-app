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
    @Environment(\.locale) private var locale

    var body: some View {
        Cloud03Screen(
            title: catalog("title"),
            seed: presentation.policyVersion.isEmpty ? "bundle-refund-quote" : presentation.policyVersion,
            symbol: "arrow.uturn.backward"
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                amountHero
                routeCard
                CYListRow(
                    verbatim: catalog("remainingRatioLabel"),
                    trailing: .value(Cloud03Copy.shown(presentation.remainingRatioText)),
                    card: true
                ) { CYRowIcon(systemImage: "percent") }
                CYListRow(
                    verbatim: catalog("remainingValueLabel"),
                    trailing: .value(Cloud03Copy.shown(presentation.remainingValueText)),
                    card: true
                ) { CYRowIcon(systemImage: "circle.lefthalf.filled") }
                CYListRow(
                    verbatim: catalog("totalValueLabel"),
                    trailing: .value(Cloud03Copy.shown(presentation.totalValueText)),
                    card: true
                ) { CYRowIcon(systemImage: "tag") }
                if let key = presentation.afterSalesPointerKey {
                    CYNoteBanner(text: Text(verbatim: catalog(key)), symbol: "person.crop.circle.badge.questionmark", tone: .info)
                        .accessibilityIdentifier("bundleRefund.afterSales")
                }
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: catalog(presentation.quoteOnlyNoticeKey))
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bundleRefund.quoteOnly")
                    Text(verbatim: Cloud03Copy.shown(presentation.policyVersion))
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var amountHero: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: catalog("amountLabel"))
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: Cloud03Copy.shown(presentation.amountText))
                .font(CYTypography.dataXL)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var routeCard: some View {
        CYInfoCard(
            title: Text(verbatim: catalog(presentation.routeTitleKey)),
            symbol: "arrow.uturn.backward",
            tint: CYColor.textSecondary
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: catalog(presentation.routeBodyKey))
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let reason = presentation.serverReason {
                    Text(verbatim: Cloud03Copy.shown(reason))
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("bundleRefund.route")
    }

    private func catalog(_ key: String) -> String {
        Cloud03Copy.catalog(key, table: table, locale: locale)
    }
}
