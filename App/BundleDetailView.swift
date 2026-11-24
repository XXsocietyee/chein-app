import SwiftUI

/// Bundle detail (T-02). Compliance copy comes only from the server fields in `content`; the app
/// bundles no legal text. The purchase button needs both `saleEnabled` and a caller-supplied action
/// (checkout is a separate, blocked work package). Not mounted anywhere.
///
/// Motion (docs/release/motion-spec-purchase.md): parallax hero, rolling price, staggered included rows,
/// pinned buy bar whose price pill opens the order summary sheet (detents: compact height, large).
/// `paying` mirrors an in-flight purchase so the CTA shows its processing state; the view itself never writes.
@MainActor struct BundleDetailView: View {
    let content: BundleDetailContent
    var onPurchase: (() -> Void)? = nil
    var paying = false
    /// DEBUG hosts: present the order summary as soon as the screen appears (shots of the compact detent).
    var presentsSummaryOnAppear = false
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @QuestifyReduceMotion private var reduceMotion
    @State private var noticesOpen = false
    @State private var summaryOpen = false
    @State private var summaryDetent: PresentationDetent = .large
    @State private var stagger = CYStaggerGate()
    @ScaledMetric(relativeTo: .body) private var summaryHeight: CGFloat = 430
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var name: String {
        let n = (content.catalog.topicName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "—" : n
    }
    private var priceText: String? { E1Money.yuan(text: content.extras?.price?.text) }
    private var heroHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 320 : 260 }
    private var compactDetent: PresentationDetent { .height(summaryHeight) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                hero
                priceBlock
                included
                merchants
                notices
            }
            .padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm).padding(.bottom, CYSpacing.xxl)
        }
        .background(palette.bgPage)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .cyHeroScreen()
        .sheet(isPresented: $summaryOpen) { summarySheet }
        .onAppear {
            summaryDetent = dynamicTypeSize.isAccessibilitySize ? .large : compactDetent
            if presentsSummaryOnAppear { summaryOpen = true }
        }
        .cyDomainScreen(.player)
    }

    /// Hero art with the bundle name on it: the one visible title. Stretches when pulled, parallaxes when scrolled.
    private var hero: some View {
        Color.clear
            .overlay { E1CoverArt(seed: name, symbol: "shippingbox") }
            .overlay(alignment: .bottomLeading) {
                Text(verbatim: name).cyText(.pageTitle).foregroundStyle(.white)
                    .lineLimit(4).minimumScaleFactor(0.6).accessibilityAddTraits(.isHeader)
                    .padding(CYSpacing.lg).padding(.top, 64).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
            .cyHeroParallax(height: heroHeight)
    }

    /// Price with currency symbol and a validity chip; absent values are omitted, never shown as 0.
    @ViewBuilder private var priceBlock: some View {
        if priceText != nil || content.extras?.validityDays != nil {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if let priceText {
                    Text(verbatim: copy.t("套餐价", "Bundle price")).cyText(.meta).foregroundStyle(palette.textTertiary)
                    CYAnimatedPrice(text: priceText)
                }
                if let days = content.extras?.validityDays {
                    Label { Text(verbatim: copy.t("购买后 \(days) 天内有效", "Valid for \(days) days after purchase")) } icon: { Image(systemName: "calendar.badge.clock") }
                        .cyText(.caption).foregroundStyle(palette.info)
                        .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs + 1)
                        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.infoSoft))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.lg)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var included: some View {
        if !content.catalog.items.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                header("checklist", copy.t("包含内容", "What is included"))
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

    @ViewBuilder private var merchants: some View {
        if let list = content.extras?.merchants, !list.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                header("storefront", copy.t("参与商家", "Participating merchants"))
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.offset) { index, merchant in
                        if index > 0 { Divider().overlay(palette.borderSubtle).padding(.leading, 52) }
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "storefront")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: merchant.merchantName ?? "—").cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                                if let summary = merchant.qualificationSummary {
                                    Text(verbatim: summary).cyText(.meta).foregroundStyle(palette.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, CYSpacing.sm)
                        .accessibilityElement(children: .combine)
                    }
                }
                .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.md)
            }
        }
    }

    /// Compliance copy stays server-supplied; collapsed by default so the purchase decision stays in view.
    @ViewBuilder private var notices: some View {
        if content.hasCompliance {
            DisclosureGroup(isExpanded: $noticesOpen) {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(Array(content.complianceDeclarations.enumerated()), id: \.offset) { _, line in
                        Text(verbatim: line).cyText(.meta).foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let url = content.agreementURL {
                        Link(destination: url) { text("detail.agreement").cyText(.meta, weight: .semibold) }
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, CYSpacing.sm)
            } label: {
                Label { text("detail.compliance").cyText(.cardTitle) } icon: { Image(systemName: "doc.text.magnifyingglass") }
                    .foregroundStyle(palette.textPrimary)
            }
            .tint(palette.textSecondary)
            .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.lg)
        }
    }

    private func header(_ icon: String, _ title: String) -> some View { E1IconHeader(systemImage: icon, title: title) }

    // MARK: Buy bar + summary sheet

    @ViewBuilder private var bottomBar: some View {
        if content.showsNotOnSale {
            text("detail.notOnSale").cyText(.meta).foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity).padding(CYSpacing.lg).background(.bar)
                .accessibilityIdentifier("bundle.detail.notOnSale")
        } else if onPurchase != nil {
            CYBuyBar(
                priceText: priceText,
                priceCaption: copy.t("合计", "Total"),
                summaryLabel: copy.t("订单摘要", "order summary"),
                ctaTitle: copy.t("立即购买", "Buy now"),
                processing: paying,
                processingLabel: copy.t("处理中", "processing"),
                summaryOpen: $summaryOpen,
                onCTA: { summaryOpen = true }
            )
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
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: "ticket")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name ?? "—").cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                let stores = item.stores.compactMap(\.merchantName).filter { !$0.isEmpty }
                if !stores.isEmpty {
                    Text(verbatim: stores.joined(separator: " · ")).cyText(.meta).foregroundStyle(palette.textSecondary)
                }
                if let terms = item.termsMode, !terms.isEmpty {
                    Text(verbatim: terms).cyText(.meta).foregroundStyle(palette.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}
