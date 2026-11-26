import SwiftUI

/// Shelf list (T-01). Renders only what the injected model holds; with the default unavailable client
/// it shows the unavailable text and no cards. Not mounted anywhere.
@MainActor struct BundleShelfView: View {
    @Bindable var model: BundleShelfModel
    var onSelect: ((BundleShelfItem) -> Void)? = nil
    /// When the host pushes the detail with a NavigationLink, pass its namespace and apply `cyHeroDestination(item.topicId, in:)` there.
    var heroNamespace: Namespace.ID? = nil
    private let table = "BundleCommerce"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    var body: some View {
        List {
            switch model.state {
            case .idle, .loading where model.items.isEmpty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .accessibilityLabel(text("shelf.loading"))
            case .unavailable:
                ContentUnavailableView {
                    Label {
                        text("shelf.unavailable").accessibilityIdentifier("bundle.shelf.unavailable")
                    } icon: {
                        Image(systemName: "shippingbox")
                    }
                }
                .listRowBackground(Color.clear)
            case .failed:
                ContentUnavailableView {
                    Label {
                        text("shelf.error").accessibilityIdentifier("bundle.shelf.error")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } actions: {
                    Button { Task { await model.refresh() } } label: { Text("action.retry") }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            default:
                if model.items.isEmpty {
                    ContentUnavailableView {
                        Label { text("shelf.empty") } icon: { Image(systemName: "shippingbox") }
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(model.items, id: \.topicId) { item in
                    Button { onSelect?(item) } label: {
                        BundleShelfRow(item: item)
                    }
                    .foregroundStyle(.primary)
                    .modifier(CYOptionalHeroSource(id: item.topicId, namespace: heroNamespace))
                    .disabled(onSelect == nil)
                    .onAppear {
                        if item.topicId == model.items.last?.topicId, model.hasMore {
                            Task { await model.loadMore() }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("shelf.title", tableName: table)).navigationBarTitleDisplayMode(.inline)
        .task { if model.state == .idle { await model.refresh() } }
        .cyAnimation(value: model.items.map(\.topicId))
        .refreshable { await model.refresh() }
    }
}

/// Shelf row: cover thumbnail, name, "from" price, validity, chevron. Absent price/validity are left out, never 0.
private struct BundleShelfRow: View {
    let item: BundleShelfItem
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var thumb: CGFloat = 60
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var name: String { (item.topicName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : item.topicName! }
    private var coverURL: URL? {
        guard let raw = item.coverUrl, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
    var body: some View {
        HStack(spacing: CYSpacing.md) {
            cover
            text
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
    /// The server cover photo when there is one; otherwise the SF Symbol (no generated art).
    private var cover: some View {
        AsyncImage(url: coverURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary)
            }
        }
        .frame(width: thumb, height: thumb)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }
    private var text: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: name).font(.headline).lineLimit(2)
            if let price = E1Money.yuan(text: item.fromPrice?.text) {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                    if !copy.isChinese { Text(verbatim: "from").font(.subheadline).foregroundStyle(.secondary) }
                    Text(verbatim: price).font(.body.weight(.semibold).monospacedDigit()).lineLimit(1)
                    if copy.isChinese { Text(verbatim: "起").font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            if let days = item.validityDays {
                Label(copy.t("\(days) 天有效", "Valid \(days) days"), systemImage: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
