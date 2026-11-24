import SwiftUI

/// Round-4 SwiftUI views for `member` Gemini items:
/// `MKT-7-1` (Catalog-only bundle view for `free-explore?topicId=`),
/// `PLY-26-4` (Template mine card cover with `★ rating / N 次引用` overlay),
/// `MKT-10-5` (Player 403 `申请入驻` CTA).

// MARK: - MKT-7-1: Catalog-Only Free-Explore Bundle View (`?topicId=`)

public struct FreeExploreCatalogMerchantItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let merchantName: String
    public let chapterName: String
    public let perkSummary: String?

    public init(id: Int, merchantName: String, chapterName: String, perkSummary: String? = nil) {
        self.id = id
        self.merchantName = merchantName
        self.chapterName = chapterName
        self.perkSummary = perkSummary
    }
}

public struct FreeExploreCatalogBundleView: View {
    public let topicTitle: String
    public let items: [FreeExploreCatalogMerchantItem]
    public var onOpenTopic: () -> Void = {}

    public init(
        topicTitle: String,
        items: [FreeExploreCatalogMerchantItem],
        onOpenTopic: @escaping () -> Void = {}
    ) {
        self.topicTitle = topicTitle
        self.items = items
        self.onOpenTopic = onOpenTopic
    }

    public var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView("bundle.catalog.empty", systemImage: "bag")
            } else {
                Section("bundle.catalog.merchants") {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(item.merchantName)
                                .cyText(.cardTitle)
                            Text(item.chapterName)
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                            if let perk = item.perkSummary, !perk.isEmpty {
                                Text(perk)
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.brand)
                            }
                        }
                        .padding(.vertical, CYSpacing.xs)
                    }
                }
            }
            Section {
                Button("bundle.catalog.openTopic", action: onOpenTopic)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .cyPageTitle("bundle.receipt.title")
    }
}

// MARK: - PLY-26-4 (rest): Template Mine Card Cover (`imgUrl` or initial gradient + `★ rating / N 次引用`)

public struct TemplateMineCardCoverView: View {
    public let title: String
    public let imageURL: String?
    public let ratingText: String?
    public let quoteCount: Int

    public init(title: String, imageURL: String?, ratingText: String? = nil, quoteCount: Int = 0) {
        self.title = title
        self.imageURL = imageURL
        self.ratingText = ratingText
        self.quoteCount = quoteCount
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL, !imageURL.isEmpty {
                CYCachedAsyncImage(imageURL, role: .shelf)
                    .frame(height: 120)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                    .fill(CYColor.coverFallback)
                    .frame(height: 120)
                    .overlay {
                        Text(String(title.prefix(1)))
                            .cyText(.display)
                            .foregroundStyle(CYColor.textSecondary)
                    }
            }

            HStack(spacing: CYSpacing.xs) {
                if let ratingText, !ratingText.isEmpty {
                    Text("★ \(ratingText)")
                        .cyText(.meta, monospacedDigit: true)
                }
                if quoteCount > 0 {
                    Text("\(quoteCount) 次引用")
                        .cyText(.meta, monospacedDigit: true)
                }
            }
            .foregroundStyle(CYColor.actionPrimaryFg)
            .padding(.horizontal, CYSpacing.xs)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .padding(CYSpacing.xs)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
}

// MARK: - MKT-10-5: Coupon Forbidden Player CTA (`申请入驻`)

public struct CouponForbiddenPlayerActionView: View {
    public let isMerchant: Bool
    public var onBack: () -> Void
    public var onApplyMerchant: () -> Void

    public init(isMerchant: Bool, onBack: @escaping () -> Void, onApplyMerchant: @escaping () -> Void) {
        self.isMerchant = isMerchant
        self.onBack = onBack
        self.onApplyMerchant = onApplyMerchant
    }

    public var body: some View {
        ContentUnavailableView {
            Label("couponManagement.forbidden.title", systemImage: "lock")
        } actions: {
            if isMerchant {
                Button("common.back", action: onBack)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("couponManagement.forbidden.applyMerchant", action: onApplyMerchant)
                    .buttonStyle(.borderedProminent)
                Button("common.back", action: onBack)
                    .buttonStyle(.bordered)
            }
        }
    }
}
