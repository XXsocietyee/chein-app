import SwiftUI

/// Shelf list (T-01). Renders only what the injected model holds; with the default unavailable client
/// it shows the unavailable text and no cards. Not mounted anywhere.
@MainActor struct BundleShelfView: View {
    @Bindable var model: BundleShelfModel
    var onSelect: ((BundleShelfItem) -> Void)? = nil
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    var body: some View {
        ScrollView {
            LazyVStack(spacing: CYSpacing.md) {
                switch model.state {
                case .idle, .loading where model.items.isEmpty:
                    CYLoadingStateView(rows: 3).accessibilityLabel(text("shelf.loading"))
                case .unavailable:
                    CYEmptyState(systemImage: "shippingbox", "shelf.unavailable", tableName: table, messageIdentifier: "bundle.shelf.unavailable")
                case .failed:
                    CYEmptyState(systemImage: "exclamationmark.triangle", "shelf.error", tableName: table,
                                 messageIdentifier: "bundle.shelf.error", actionTitle: "action.retry") { Task { await model.refresh() } }
                default:
                    if model.items.isEmpty { CYEmptyState(systemImage: "shippingbox", "shelf.empty", tableName: table) }
                    ForEach(model.items, id: \.topicId) { item in
                        Button { onSelect?(item) } label: {
                            CYImageCard(title: Text(verbatim: item.topicName ?? "—"), meta: meta(item),
                                        imageURL: item.coverUrl.flatMap(URL.init(string:)), style: .hero)
                        }
                        .buttonStyle(.plain)
                        .disabled(onSelect == nil)
                        .onAppear {
                            if item.topicId == model.items.last?.topicId, model.hasMore {
                                Task { await model.loadMore() }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.vertical, CYSpacing.md)
        }
        .navigationTitle(Text("shelf.title", tableName: table))
        .task { if model.state == .idle { await model.refresh() } }
        .refreshable { await model.refresh() }
    }

    /// Price and validity only when the server sent them; an absent value is omitted, never shown as 0.
    private func meta(_ item: BundleShelfItem) -> Text? {
        var parts: [Text] = []
        if let price = item.fromPrice { parts.append(Text(verbatim: price.text)) }
        if let days = item.validityDays { parts.append(text("detail.validityDays") + Text(verbatim: " " + String(days))) }
        guard var first = parts.first else { return nil }
        for part in parts.dropFirst() { first = first + Text(verbatim: " · ") + part }
        return first
    }
}
