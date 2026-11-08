import SwiftUI

/// Bundle detail (T-02). Compliance copy comes only from the server fields in `content`; the app
/// bundles no legal text. The purchase button needs both `saleEnabled` and a caller-supplied action
/// (checkout is a separate, blocked work package). Not mounted anywhere.
@MainActor struct BundleDetailView: View {
    let content: BundleDetailContent
    var onPurchase: (() -> Void)? = nil
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    var body: some View {
        Form {
            Section {
                if let name = content.catalog.topicName { Text(verbatim: name).font(.headline) }
                if let price = content.extras?.price { LabeledContent { Text(verbatim: price.text) } label: { text("detail.price") } }
                if let days = content.extras?.validityDays {
                    LabeledContent { Text(verbatim: String(days)) } label: { text("detail.validityDays") }
                }
            }
            Section {
                ForEach(content.catalog.items, id: \.chapterId) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        if let name = item.name { Text(verbatim: name) }
                        if let terms = item.termsMode { Text(verbatim: terms).font(.footnote) }
                        ForEach(item.stores, id: \.offerId) { store in
                            if let merchant = store.merchantName { Text(verbatim: merchant).font(.footnote) }
                        }
                    }
                }
            } header: { text("detail.items") }
            if let merchants = content.extras?.merchants, !merchants.isEmpty {
                Section {
                    ForEach(merchants, id: \.offerId) { merchant in
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = merchant.merchantName { Text(verbatim: name) }
                            if let summary = merchant.qualificationSummary { Text(verbatim: summary).font(.footnote) }
                        }
                    }
                } header: { text("detail.merchants") }
            }
            if content.hasCompliance {
                Section {
                    ForEach(Array(content.complianceDeclarations.enumerated()), id: \.offset) { _, line in
                        Text(verbatim: line).font(.footnote)
                    }
                    if let url = content.agreementURL {
                        Link(destination: url) { text("detail.agreement") }
                    }
                } header: { text("detail.compliance") }
            }
            Section {
                if content.showsNotOnSale {
                    text("detail.notOnSale").accessibilityIdentifier("bundle.detail.notOnSale")
                } else if let onPurchase {
                    Button(action: onPurchase) { text("detail.purchase") }
                        .accessibilityIdentifier("bundle.detail.purchase")
                }
            }
        }
        .navigationTitle(Text("detail.title", tableName: table))
    }
}
