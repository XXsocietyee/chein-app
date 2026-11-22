import SwiftUI

/// IWP-8a. Unmounted. Shows server-approved reviews only (the model filters again defensively).
@MainActor struct BundleReviewListView: View {
    @ObservedObject var model: BundleReviewListModel

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading where model.items.isEmpty:
                CYLoadingStateView(rows: 2).listRowBackground(Color.clear)
            case .unavailable:
                CYEmptyState(systemImage: "star.bubble", LocalizedStringKey(W8Text.t("评价功能暂未开放", "Reviews are not available yet")),
                             messageIdentifier: "bundleReviewList.unavailable").listRowBackground(Color.clear)
            case .failed:
                CYEmptyState(systemImage: "exclamationmark.triangle", LocalizedStringKey(W8Text.t("评价加载失败", "Couldn't load reviews")),
                             actionTitle: "action.retry") { Task { await model.load() } }.listRowBackground(Color.clear)
            case .empty:
                CYEmptyState(
                    systemImage: "star.bubble",
                    LocalizedStringKey(W8Text.t("还没有评价", "No reviews yet")),
                    detailVerbatim: W8Text.t("完成体验后，可以留下第一条评价。", "Finish an experience to share the first review.")
                ).listRowBackground(Color.clear)
            default:
                ForEach(model.items, id: \.id) { review in
                    VStack(alignment: .leading, spacing: 4) {
                        Label { Text(verbatim: String(review.rating)).cyText(.cardTitle).monospacedDigit() } icon: { Image(systemName: "star.fill").foregroundStyle(CYColor.warningText) }
                        Text(verbatim: review.content)
                        if let time = review.createTime { Text(verbatim: time).cyText(.meta) }
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
        .cyDomainScreen(.player)
    }
}
