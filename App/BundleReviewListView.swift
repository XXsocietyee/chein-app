import SwiftUI

/// IWP-8a. Unmounted. Shows server-approved reviews only (the model filters again defensively).
@MainActor struct BundleReviewListView: View {
    @ObservedObject var model: BundleReviewListModel

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading where model.items.isEmpty:
                ProgressView()
            case .unavailable:
                Text(verbatim: W8Text.t("评价功能暂未开放", "Reviews are not available yet"))
                    .accessibilityIdentifier("bundleReviewList.unavailable")
            case .failed:
                Text(verbatim: W8Text.t("评价加载失败", "Couldn't load reviews"))
            case .empty:
                Text(verbatim: W8Text.t("暂无评价", "No reviews yet"))
            default:
                ForEach(model.items, id: \.id) { review in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: String(review.rating)).font(.headline)
                        Text(verbatim: review.content)
                        if let time = review.createTime { Text(verbatim: time).font(.caption) }
                    }
                }
                if model.hasMore {
                    Button { Task { await model.loadMore() } } label: {
                        Text(verbatim: W8Text.t("加载更多", "Load more"))
                    }
                }
            }
        }
        .task { await model.load() }
    }
}
