#if DEBUG
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/square/detail` has the post with its comments, the
/// comment-section states (评论加载失败 + 重试, 暂无评论) and the page shells (这条帖文暂不可用, 动态加载失败 + 重试).
/// The design fixtures mount the same `SquareDetailView` the feed pushes, on the offline fixture reader with posts and
/// comments in the UI language (no synthetic server text, no offline note):
/// `d2-square-detail`, `d2-square-detail-no-comments`, `d2-square-detail-comments-failed`,
/// `d2-square-detail-unavailable`, `d2-square-detail-failed`.
@MainActor struct SquareDetailDesignFixtureHost: View {
    @State private var reader: SquareFixtureReader

    init(scenario: SquareFixtureReader.Scenario) {
        _reader = State(initialValue: SquareFixtureReader(scenario: scenario, designLocalized: true))
    }

    var body: some View {
        NavigationStack {
            SquareDetailView(id: 701, reader: reader)
        }
    }
}
#endif
