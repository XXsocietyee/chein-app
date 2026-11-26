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
                        VStack(alignment: .leading) {
                            Text(item.merchantName)
                            Text(item.chapterName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let perk = item.perkSummary, !perk.isEmpty {
                                Text(perk)
                                    .font(.subheadline)
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            Section {
                Button(action: onOpenTopic) {
                    Text("bundle.catalog.openTopic").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
        // Native r2: the cover, then the rating / quote line as secondary text (no material chip or card corners).
        VStack(alignment: .leading) {
            if let imageURL, !imageURL.isEmpty {
                CYCachedAsyncImage(imageURL, role: .shelf)
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle().fill(.quaternary)
                    .frame(height: 120)
                    .overlay {
                        Text(String(title.prefix(1)))
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }

            HStack {
                if let ratingText, !ratingText.isEmpty {
                    Text("★ \(ratingText)")
                        .monospacedDigit()
                }
                if quoteCount > 0 {
                    Text("\(quoteCount) 次引用")
                        .monospacedDigit()
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
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
                    .controlSize(.large)
            } else {
                Button("couponManagement.forbidden.applyMerchant", action: onApplyMerchant)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("common.back", action: onBack)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
    }
}
