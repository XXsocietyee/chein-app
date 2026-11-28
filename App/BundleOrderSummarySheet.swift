import SwiftUI

/// Order summary presented from the buy bar's price pill (docs/release/motion-spec-purchase.md).
/// Compact detent: name, item count, price rows, total and the pay button. Dragging to `.large` reveals the
/// included items. Native r2: a system inset-grouped list under an inline navigation title. Unknown amounts are a dash, never 0. Writes nothing: `onPay` is the caller's.
@MainActor struct BundleOrderSummarySheet: View {
    let content: BundleDetailContent
    var priceText: String?
    var paying = false
    let onPay: () -> Void

    @Environment(\.locale) private var locale
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var name: String {
        let n = (content.catalog.topicName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "—" : n
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    bundleRow
                }
                priceRows
                Section {
                    Button(action: onPay) {
                        HStack(spacing: CYSpacing.sm) {
                            if paying {
                                ProgressView()
                                Text(verbatim: copy.t("处理中…", "Processing…"))
                            } else {
                                Text(verbatim: copy.t("确认支付", "Pay"))
                                if let priceText { Text(verbatim: LocaleDisplay.yuanAmounts(in: priceText, locale: locale)).monospacedDigit() }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(paying)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("bundle.summary.pay")
                }
                included
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: copy.t("订单摘要", "Order summary")))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var bundleRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name).font(.headline).lineLimit(2)
                let count = content.catalog.items.count
                if count > 0 {
                    Text(verbatim: copy.t("包含 \(count) 项", CoreLoopCopy.count(Substring(String(count)), "item included", "items included")))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "shippingbox")
        }
        .accessibilityElement(children: .combine)
    }

    /// Bundle price, validity, total. Unknown amounts are a dash, never 0.
    private var priceRows: some View {
        Section {
            if let priceText {
                LabeledContent {
                    Text(verbatim: LocaleDisplay.yuanAmounts(in: priceText, locale: locale)).monospacedDigit()
                } label: {
                    Text(verbatim: copy.t("套餐价", "Bundle price"))
                }
            }
            if let days = content.extras?.validityDays {
                LabeledContent {
                    Text(verbatim: copy.t("购买后 \(days) 天", CoreLoopCopy.count(Substring(String(days)), "day after purchase", "days after purchase")))
                } label: {
                    Text(verbatim: copy.t("有效期", "Validity"))
                }
            }
            LabeledContent {
                Text(verbatim: priceText ?? "—")
                    .cyText(.numericTitle)
                    .foregroundStyle(.primary)
            } label: {
                Text(verbatim: copy.t("合计", "Total")).font(.headline)
            }
        } footer: {
            if let line = content.complianceDeclarations.first {
                Text(verbatim: line).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var included: some View {
        if !content.catalog.items.isEmpty {
            Section {
                ForEach(Array(content.catalog.items.enumerated()), id: \.offset) { _, item in
                    BundleIncludedRow(item: item)
                }
            } header: {
                Text(verbatim: copy.t("包含内容", "What is included"))
            }
        }
    }
}
