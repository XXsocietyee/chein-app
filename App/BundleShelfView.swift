import SwiftUI

/// Shelf list (T-01). Renders only what the injected model holds; with the default unavailable client
/// it shows the unavailable text and no cards. Not mounted anywhere.
@MainActor struct BundleShelfView: View {
    @Bindable var model: BundleShelfModel
    var onSelect: ((BundleShelfItem) -> Void)? = nil
    /// When the host pushes the detail with a NavigationLink, pass its namespace and apply `cyHeroDestination(item.topicId, in:)` there.
    var heroNamespace: Namespace.ID? = nil
    @State private var stagger = CYStaggerGate()
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
                    ForEach(Array(model.items.enumerated()), id: \.element.topicId) { index, item in
                        Button { onSelect?(item) } label: {
                            BundleShelfRow(item: item)
                                .cyStaggeredAppear(index: index, gate: stagger)
                        }
                        .buttonStyle(CYPressableStyle())
                        .modifier(CYOptionalHeroSource(id: item.topicId, namespace: heroNamespace))
                        .cyRowTransition()
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
        .navigationTitle(Text("shelf.title", tableName: table)).navigationBarTitleDisplayMode(.inline)
        .task { if model.state == .idle { await model.refresh() } }
        .cyAnimation(value: model.items.map(\.topicId))
        .cyRefreshable { await model.refresh() }
    }
}

/// Shelf row: cover thumbnail, name, "from" price, validity chip, chevron. Absent price/validity are left out, never 0.
private struct BundleShelfRow: View {
    let item: BundleShelfItem
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.cyPalette) private var palette
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var name: String { (item.topicName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : item.topicName! }
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    cover.aspectRatio(16.0 / 9.0, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    text
                }
            } else {
                HStack(spacing: CYSpacing.md) {
                    cover.frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    text
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                }
            }
        }
        .cyDomainCard(radius: CYRadius.card, padding: CYSpacing.md)
        .accessibilityElement(children: .combine)
    }
    private var cover: some View {
        Color.clear.overlay { E1CoverArt(seed: name, symbol: "shippingbox", imageURL: item.coverUrl, debugLabel: false) }
    }
    private var text: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: name).cyText(.cardTitle).foregroundStyle(palette.textPrimary).lineLimit(2)
            if let price = E1Money.yuan(text: item.fromPrice?.text) {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                    if !copy.isChinese { Text(verbatim: "from").cyText(.meta).foregroundStyle(palette.textTertiary) }
                    Text(verbatim: price).cyText(.dataXL, weight: .semibold).foregroundStyle(palette.textPrimary).minimumScaleFactor(0.8).lineLimit(1)
                    if copy.isChinese { Text(verbatim: "起").cyText(.meta).foregroundStyle(palette.textTertiary) }
                }
            }
            if let days = item.validityDays {
                CYStatusChip(verbatim: copy.t("\(days) 天有效", "Valid \(days) days"), tone: .info, systemImage: "calendar.badge.clock")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
