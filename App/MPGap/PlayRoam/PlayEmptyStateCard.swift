import SwiftUI

/// MP `pages/play/index` `.play-empty` card (空态遮罩): one sentence and the exits the MP gives for it.
/// signup → 你还没有报名这个场次 + 去报名 (MP `goSignup` = back to the detail page);
/// empty → 路线配置中 + 返回; needPass (402) → server sentence or 请先购买自玩通行证后再开始 + 获取通行证 (topic page).
/// Login expiry is handled app-wide (`onUnauthorized`), so the MP `auth` card has no native twin.
enum PlayEmptyKind: Equatable {
    case signup, empty, needPass(String?)

    /// The blocking card for a loaded run, or nil when the run can be shown. Free exploration keeps its own pack page.
    static func blocking(_ availability: PlaySessionAvailability?) -> PlayEmptyKind? {
        if availability == .registrationRequired { return .signup }
        if availability == .empty { return .empty }
        return nil
    }

    /// 402 from `/api/play/nodes` (no or expired self-play pass), MP C-26.
    static func failure(_ issue: PlayExperienceError?) -> PlayEmptyKind? {
        if case .rejected(402, let message) = issue { return .needPass(message) }
        return nil
    }
}

struct PlayEmptyStateCard: View {
    let kind: PlayEmptyKind
    var topicID: Int? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var route: MPParityRoute?

    var body: some View {
        ContentUnavailableView {
            Label { title } icon: { Image(systemName: symbol) }
        } actions: {
            actions
        }
        .accessibilityIdentifier("playx.empty")
        .mpParityRouteDestination($route)
    }

    private var symbol: String {
        switch kind {
        case .signup: return "ticket"
        case .empty: return "map"
        case .needPass: return "wallet.pass"
        }
    }

    @ViewBuilder private var title: some View {
        switch kind {
        case .signup: Text("playx.empty.signup")
        case .empty: Text("playx.empty.route")
        case .needPass(let message):
            if let message, !message.isEmpty { Text(verbatim: message) } else { Text("playx.empty.needPass") }
        }
    }

    @ViewBuilder private var actions: some View {
        switch kind {
        case .signup:
            Button("playx.empty.signup.action") { dismiss() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("playx.empty.signup")
        case .empty:
            Button("action.back") { dismiss() }
                .buttonStyle(.bordered).controlSize(.large)
                .accessibilityIdentifier("playx.empty.back")
        case .needPass:
            Button("playx.empty.getPass") { openPass() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("playx.empty.getPass")
        }
    }

    private func openPass() {
        guard let topicID else { dismiss(); return }
        route = MPParityRoute(miniProgramPath: "pages/topic/index/index", query: ["id": String(topicID)])
        if route == nil { dismiss() }
    }
}

/// MP error card secondary exit (DS Error §): 返回活动详情 under 重新加载.
struct PlayBackToDetailButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("playx.empty.backDetail") { dismiss() }
            .buttonStyle(.bordered).controlSize(.large)
            .accessibilityIdentifier("playx.empty.backDetail")
    }
}
