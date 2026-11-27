import SwiftUI

/// IWP-8a. Unmounted. Shows server-approved reviews only (the model filters again defensively).
@MainActor struct BundleReviewListView: View {
    @ObservedObject var model: BundleReviewListModel
    @Environment(\.locale) private var locale

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading where model.items.isEmpty:
                CYLoadingState()
                    .listRowBackground(Color.clear)
            case .unavailable:
                ContentUnavailableView {
                    Label {
                        Text(verbatim: W8Text.t("评价功能暂未开放", "Reviews are not available yet"))
                            .accessibilityIdentifier("bundleReviewList.unavailable")
                    } icon: {
                        Image(systemName: "star.bubble")
                    }
                }
                .listRowBackground(Color.clear)
            case .failed:
                ContentUnavailableView {
                    Label(W8Text.t("评价加载失败", "Couldn't load reviews"), systemImage: "exclamationmark.triangle")
                } actions: {
                    Button { Task { await model.load() } } label: { Text("action.retry") }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            case .empty:
                ContentUnavailableView {
                    Label(W8Text.t("还没有评价", "No reviews yet"), systemImage: "star.bubble")
                } description: {
                    Text(verbatim: W8Text.t("完成体验后，可以留下第一条评价。", "Finish an experience to share the first review."))
                }
                .listRowBackground(Color.clear)
            default:
                ForEach(model.items, id: \.id) { review in
                    VStack(alignment: .leading, spacing: 4) {
                        Label { Text(verbatim: String(review.rating)).font(.headline).monospacedDigit() } icon: { Image(systemName: "star.fill").foregroundStyle(.orange) }
                        Text(verbatim: review.content)
                        if let time = review.createTime { Text(verbatim: LocaleDisplay.civil(time, locale: locale)).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                if model.hasMore {
                    Button { Task { await model.loadMore() } } label: {
                        Text(verbatim: W8Text.t("加载更多", "Load more"))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .task { await model.load() }
        .refreshable { await model.load() }
        .themeDomain(.player)
    }
}
