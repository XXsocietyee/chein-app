import SwiftUI

/// Order summary presented from the buy bar's price pill (docs/release/motion-spec-purchase.md).
/// Compact detent: name, item count, price rows, total and the pay button. Dragging to `.large` reveals the
/// included items, which stagger in once. Unknown amounts are a dash, never 0. Writes nothing: `onPay` is the caller's.
@MainActor struct BundleOrderSummarySheet: View {
    let content: BundleDetailContent
    var priceText: String?
    var paying = false
    let onPay: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var stagger = CYStaggerGate()
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var name: String {
        let n = (content.catalog.topicName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "—" : n
    }
    private var stacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                Text(verbatim: copy.t("订单摘要", "Order summary"))
                    .cyText(.sheetTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, CYSpacing.sm)
                bundleRow
                priceRows
                if let line = content.complianceDeclarations.first {
                    Text(verbatim: line)
                        .cyText(.caption)
                        .foregroundStyle(palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                CYPayButton(
                    title: copy.t("确认支付", "Pay"),
                    amount: priceText,
                    processing: paying,
                    processingLabel: copy.t("处理中", "processing"),
                    action: onPay
                )
                .accessibilityIdentifier("bundle.summary.pay")
                included
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.jumbo)
        }
        .background(palette.bgElevated)
    }

    private var bundleRow: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: "shippingbox")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).cyText(.cardTitle).foregroundStyle(palette.textPrimary).lineLimit(2)
                let count = content.catalog.items.count
                if count > 0 {
                    Text(verbatim: copy.t("包含 \(count) 项", CoreLoopCopy.count(Substring(String(count)), "item included", "items included")))
                        .cyText(.meta).foregroundStyle(palette.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Bundle price, validity, total. Rows stack at accessibility sizes so the amount never squeezes.
    private var priceRows: some View {
        VStack(spacing: 0) {
            if let priceText {
                row(copy.t("套餐价", "Bundle price")) {
                    Text(verbatim: priceText).cyText(.numericBody).foregroundStyle(palette.textPrimary).monospacedDigit()
                }
                Divider().overlay(palette.borderSubtle)
            }
            if let days = content.extras?.validityDays {
                row(copy.t("有效期", "Validity")) {
                    Text(verbatim: copy.t("购买后 \(days) 天", CoreLoopCopy.count(Substring(String(days)), "day after purchase", "days after purchase")))
                        .cyText(.numericBody).foregroundStyle(palette.textPrimary)
                }
                Divider().overlay(palette.borderSubtle)
            }
            row(copy.t("合计", "Total"), emphasized: true) {
                CYAnimatedPrice(text: priceText ?? "—", font: CYTypography.dataXL)
            }
        }
        .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.md)
    }

    private func row<Value: View>(_ title: String, emphasized: Bool = false, @ViewBuilder value: () -> Value) -> some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: CYSpacing.md))
        return layout {
            Text(verbatim: title)
                .cyText(emphasized ? .bodyMedium : .body)
                .foregroundStyle(emphasized ? palette.textPrimary : palette.textSecondary)
            if !stacked { Spacer(minLength: CYSpacing.sm) }
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var included: some View {
        if !content.catalog.items.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                E1IconHeader(systemImage: "checklist", title: copy.t("包含内容", "What is included"))
                    .padding(.top, CYSpacing.sm)
                VStack(spacing: 0) {
                    ForEach(Array(content.catalog.items.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 0) {
                            if index > 0 { Divider().overlay(palette.borderSubtle).padding(.leading, 52) }
                            BundleIncludedRow(item: item)
                        }
                        .cyStaggeredAppear(index: index, gate: stagger)
                    }
                }
                .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.md)
            }
        }
    }
}
