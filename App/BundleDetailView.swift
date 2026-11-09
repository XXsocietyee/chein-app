import SwiftUI

/// Bundle detail (T-02). Compliance copy comes only from the server fields in `content`; the app
/// bundles no legal text. The purchase button needs both `saleEnabled` and a caller-supplied action
/// (checkout is a separate, blocked work package). Not mounted anywhere.
@MainActor struct BundleDetailView: View {
    let content: BundleDetailContent
    var onPurchase: (() -> Void)? = nil
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var noticesOpen = false
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var name: String {
        let n = (content.catalog.topicName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "—" : n
    }
    private var priceText: String? { E1Money.yuan(text: content.extras?.price?.text) }

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
        .navigationTitle(Text("detail.title", tableName: table))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        Color.clear.aspectRatio(dynamicTypeSize.isAccessibilitySize ? 1.0 : 1.45, contentMode: .fit)
            .overlay { E1CoverArt(seed: name, symbol: "shippingbox") }
            .overlay(alignment: .bottomLeading) {
                Text(verbatim: name).font(.system(.largeTitle).weight(.bold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                    .padding(CYSpacing.lg).padding(.top, 64).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
    }

    /// Price with currency symbol and a validity chip; absent values are omitted, never shown as 0.
    @ViewBuilder private var priceBlock: some View {
        if priceText != nil || content.extras?.validityDays != nil {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if let priceText {
                    Text(verbatim: copy.t("套餐价", "Bundle price")).font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                    Text(verbatim: priceText).font(CYTypography.data2XL).foregroundStyle(palette.textPrimary).minimumScaleFactor(0.7).lineLimit(1)
                }
                if let days = content.extras?.validityDays {
                    Label { Text(verbatim: copy.t("购买后 \(days) 天内有效", "Valid for \(days) days after purchase")) } icon: { Image(systemName: "calendar.badge.clock") }
                        .font(CYTypography.caption).foregroundStyle(palette.info)
                        .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.xs + 1)
                        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.infoSoft))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var included: some View {
        if !content.catalog.items.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                header("checklist", copy.t("包含内容", "What is included"))
                VStack(spacing: 0) {
                    ForEach(Array(content.catalog.items.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Divider().overlay(palette.borderSubtle).padding(.leading, 52) }
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "ticket")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: item.name ?? "—").font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                                let stores = item.stores.compactMap(\.merchantName).filter { !$0.isEmpty }
                                if !stores.isEmpty {
                                    Text(verbatim: stores.joined(separator: " · ")).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                                }
                                if let terms = item.termsMode, !terms.isEmpty {
                                    Text(verbatim: terms).font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, CYSpacing.sm)
                        .accessibilityElement(children: .combine)
                    }
                }
                .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.md)
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
                                Text(verbatim: merchant.merchantName ?? "—").font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                                if let summary = merchant.qualificationSummary {
                                    Text(verbatim: summary).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, CYSpacing.sm)
                        .accessibilityElement(children: .combine)
                    }
                }
                .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.md)
            }
        }
    }

    /// Compliance copy stays server-supplied; collapsed by default so the purchase decision stays in view.
    @ViewBuilder private var notices: some View {
        if content.hasCompliance {
            DisclosureGroup(isExpanded: $noticesOpen) {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(Array(content.complianceDeclarations.enumerated()), id: \.offset) { _, line in
                        Text(verbatim: line).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let url = content.agreementURL {
                        Link(destination: url) { text("detail.agreement").font(CYTypography.meta.weight(.semibold)) }
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, CYSpacing.sm)
            } label: {
                Label { text("detail.compliance").font(CYTypography.cardTitle) } icon: { Image(systemName: "doc.text.magnifyingglass") }
                    .foregroundStyle(palette.textPrimary)
            }
            .tint(palette.textSecondary)
            .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
        }
    }

    private func header(_ icon: String, _ title: String) -> some View { E1IconHeader(systemImage: icon, title: title) }

    @ViewBuilder private var bottomBar: some View {
        if content.showsNotOnSale {
            text("detail.notOnSale").font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity).padding(CYSpacing.lg).background(.bar)
                .accessibilityIdentifier("bundle.detail.notOnSale")
        } else if let onPurchase {
            HStack(spacing: CYSpacing.md) {
                if let priceText, !dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: copy.t("合计", "Total")).font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                        Text(verbatim: priceText).font(CYTypography.dataXL).foregroundStyle(palette.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                CYPillButton("detail.purchase", tableName: table, action: onPurchase)
                    .accessibilityIdentifier("bundle.detail.purchase")
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md).background(.bar)
        }
    }
}
