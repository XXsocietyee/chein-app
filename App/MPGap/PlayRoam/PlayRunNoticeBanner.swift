import SwiftUI

/// mp-journey r3: MP `pages/play/index` `.play-timebar`. One non-blocking line under the nav bar: the route notice
/// (路线配置已调整 / 本次路线已结束 / 已切换到备用路线) first, else the server time line while the run is not playable
/// (活动未开始 / 已结束, the footprints stay readable). Nothing when neither applies.
struct PlayRunNoticeBanner: View {
    let snapshot: PlaySnapshot?

    var body: some View {
        if let snapshot, let notice = PlayRunRouteNotice.of(snapshot.route) {
            line(Text(LocalizedStringKey(notice.key)))
        } else if let snapshot, let time = PlayRunRouteNotice.timeLine(snapshot.result) {
            line(Text(verbatim: time))
        }
    }

    private func line(_ text: Text) -> some View {
        Label { text } icon: { Image(systemName: "info.circle") }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("playx.routeNotice")
    }
}
