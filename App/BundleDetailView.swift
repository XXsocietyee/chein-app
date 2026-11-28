import SwiftUI

/// Bundle detail (T-02). Compliance copy comes only from the server fields in `content`; the app
/// bundles no legal text. The purchase button needs both `saleEnabled` and a caller-supplied action
/// (checkout is a separate, blocked work package). Not mounted anywhere.
///
/// Native r2: a system inset-grouped list with the bundle name as the inline navigation title, a pinned bottom
/// bar (total + one prominent Buy button) whose total opens the order summary sheet (detents: compact height, large).
/// `paying` mirrors an in-flight purchase so the CTA shows its processing state; the view itself never writes.
@MainActor struct BundleDetailView: View {
    let content: BundleDetailContent
    var onPurchase: (() -> Void)? = nil
    var paying = false
    /// DEBUG hosts: present the order summary as soon as the screen appears (shots of the compact detent).
    var presentsSummaryOnAppear = false
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var noticesOpen = false
    @State private var summaryOpen = false
    @State private var summaryDetent: PresentationDetent = .large
    @ScaledMetric(relativeTo: .body) private var summaryHeight: CGFloat = 430
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var name: String {
        let n = (content.catalog.topicName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "—" : n
    }
    private var priceText: String? { E1Money.yuan(text: content.extras?.price?.text) }
    private var compactDetent: PresentationDetent { .height(summaryHeight) }

    var body: some View {
        List {
            priceBlock
            included
            merchants
            notices
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(verbatim: name))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .cySheet(isPresented: $summaryOpen) { summarySheet }
        .onAppear {
            summaryDetent = dynamicTypeSize.isAccessibilitySize ? .large : compactDetent
            if presentsSummaryOnAppear { summaryOpen = true }
        }
        .themeDomain(.player)
    }

    /// Price and validity; absent values are omitted, never shown as 0.
    @ViewBuilder private var priceBlock: some View {
        if priceText != nil || content.extras?.validityDays != nil {
            Section {
                if let priceText {
                    LabeledContent {
                        Text(verbatim: LocaleDisplay.yuanAmounts(in: priceText, locale: locale))
                            .cyText(.numericTitle)
                            .foregroundStyle(.primary)
                    } label: {
                        Text(verbatim: copy.t("套餐价", "Bundle price"))
                    }
                }
                if let days = content.extras?.validityDays {
                    Label {
                        Text(verbatim: copy.t("购买后 \(days) 天内有效", "Valid for \(days) days after purchase"))
                    } icon: {
                        Image(systemName: "calendar.badge.clock").foregroundStyle(.tint)
                    }
                }
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

    @ViewBuilder private var merchants: some View {
        if let list = content.extras?.merchants, !list.isEmpty {
            Section {
                ForEach(Array(list.enumerated()), id: \.offset) { _, merchant in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: merchant.merchantName ?? "—")
                            if let summary = merchant.qualificationSummary {
                                Text(verbatim: summary).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "storefront")
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(verbatim: copy.t("参与商家", "Participating merchants"))
            }
        }
    }

    /// Compliance copy stays server-supplied; collapsed by default so the purchase decision stays in view.
    @ViewBuilder private var notices: some View {
        if content.hasCompliance {
            Section {
                DisclosureGroup(isExpanded: $noticesOpen) {
                    ForEach(Array(content.complianceDeclarations.enumerated()), id: \.offset) { _, line in
                        Text(verbatim: line).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let url = content.agreementURL {
                        Link(destination: url) { text("detail.agreement") }
                    }
                } label: {
                    Label { text("detail.compliance") } icon: { Image(systemName: "doc.text.magnifyingglass") }
                }
            }
        }
    }

    // MARK: Buy bar + summary sheet

    @ViewBuilder private var bottomBar: some View {
        if content.showsNotOnSale {
            text("detail.notOnSale").font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding().background(.bar)
                .accessibilityIdentifier("bundle.detail.notOnSale")
        } else if onPurchase != nil {
            HStack(spacing: CYSpacing.md) {
                Button {
                    summaryOpen.toggle()
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: copy.t("合计", "Total")).font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: CYSpacing.xs) {
                            Text(verbatim: priceText ?? "—").font(.headline.monospacedDigit()).foregroundStyle(.primary)
                            Image(systemName: "chevron.up").font(.caption.weight(.semibold))
                        }
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(verbatim: copy.t("合计", "Total") + " " + (priceText ?? "—") + ", " + copy.t("订单摘要", "order summary")))
                Spacer(minLength: 0)
                Button {
                    summaryOpen = true
                } label: {
                    if paying {
                        HStack(spacing: CYSpacing.sm) {
                            ProgressView()
                            Text(verbatim: copy.t("处理中…", "Processing…"))
                        }
                    } else {
                        Text(verbatim: copy.t("立即购买", "Buy now"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(paying)
            }
            .padding(.horizontal)
            .padding(.vertical, CYSpacing.sm)
            .background(.bar)
            .accessibilityIdentifier("bundle.detail.purchase")
        }
    }

    private var summarySheet: some View {
        BundleOrderSummarySheet(
            content: content,
            priceText: priceText,
            paying: paying,
            onPay: { onPurchase?() }
        )
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [compactDetent, .large], selection: $summaryDetent)
        .presentationDragIndicator(.visible)
        .cyHaptic(.impactLight, trigger: summaryDetent)
        .themeDomain(.player)
    }
}

/// One included item: ticket icon, name, stores, terms. Combined for VoiceOver.
struct BundleIncludedRow: View {
    let item: FreeExploreLaunchCatalog.Item

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name ?? "—")
                let stores = item.stores.compactMap(\.merchantName).filter { !$0.isEmpty }
                if !stores.isEmpty {
                    Text(verbatim: stores.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                }
                if let terms = item.termsMode, !terms.isEmpty {
                    Text(verbatim: terms).font(.footnote).foregroundStyle(.tertiary)
                }
            }
        } icon: {
            Image(systemName: "ticket")
        }
        .accessibilityElement(children: .combine)
    }
}
