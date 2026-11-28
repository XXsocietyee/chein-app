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
            Section {
                amountHero
            }
            routeSection
            Section {
                LabeledContent {
                    Text(verbatim: Cloud03Copy.shown(presentation.remainingRatioText))
                } label: {
                    Label(catalog("remainingRatioLabel"), systemImage: "percent")
                }
                LabeledContent {
                    Text(verbatim: Cloud03Copy.shown(presentation.remainingValueText))
                } label: {
                    Label(catalog("remainingValueLabel"), systemImage: "circle.lefthalf.filled")
                }
                LabeledContent {
                    Text(verbatim: Cloud03Copy.shown(presentation.totalValueText))
                } label: {
                    Label(catalog("totalValueLabel"), systemImage: "tag")
                }
                if let key = presentation.afterSalesPointerKey {
                    Cloud03Note(text: Text(verbatim: catalog(key)), symbol: "person.crop.circle.badge.questionmark", tone: .info)
                        .accessibilityIdentifier("bundleRefund.afterSales")
                }
            } footer: {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: catalog(presentation.quoteOnlyNoticeKey))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bundleRefund.quoteOnly")
                    Text(verbatim: Cloud03Copy.shown(presentation.policyVersion))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var amountHero: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: catalog("amountLabel"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: Cloud03Copy.shown(presentation.amountText))
                .cyText(.dataXL)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var routeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: catalog(presentation.routeBodyKey))
                    .fixedSize(horizontal: false, vertical: true)
                if let reason = presentation.serverReason {
                    Text(verbatim: Cloud03Copy.shown(reason))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier("bundleRefund.route")
        } header: {
            Label(catalog(presentation.routeTitleKey), systemImage: "arrow.uturn.backward")
        }
    }

    private func catalog(_ key: String) -> String {
        Cloud03Copy.catalog(key, table: table, locale: locale)
    }
}
