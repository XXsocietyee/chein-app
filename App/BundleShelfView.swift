import SwiftUI

/// Shelf list (T-01). Renders only what the injected model holds; with the default unavailable client
/// it shows the unavailable text and no cards. Not mounted anywhere.
@MainActor struct BundleShelfView: View {
    @Bindable var model: BundleShelfModel
    var onSelect: ((BundleShelfItem) -> Void)? = nil
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    var body: some View {
        List {
            switch model.state {
            case .idle, .loading where model.items.isEmpty:
                ProgressView { text("shelf.loading") }
            case .unavailable:
                text("shelf.unavailable").accessibilityIdentifier("bundle.shelf.unavailable")
            case .failed:
                text("shelf.error").accessibilityIdentifier("bundle.shelf.error")
            default:
                if model.items.isEmpty { text("shelf.empty") }
                ForEach(model.items, id: \.topicId) { item in
                    Button { onSelect?(item) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = item.topicName { Text(verbatim: name).font(.headline) }
                            if let price = item.fromPrice {
                                Text(verbatim: price.text).font(.subheadline)
                            }
                            if let days = item.validityDays {
                                Text(verbatim: String(days)).font(.footnote)
                            }
                        }
                    }
                    .disabled(onSelect == nil)
                    .onAppear {
                        if item.topicId == model.items.last?.topicId, model.hasMore {
                            Task { await model.loadMore() }
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("shelf.title", tableName: table))
        .task { if model.state == .idle { await model.refresh() } }
        .refreshable { await model.refresh() }
    }
}
