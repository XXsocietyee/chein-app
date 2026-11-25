import SwiftUI

/// Unavailable landing for retired `pages/play/circle/index`: incomplete link, one home action.
/// The same keys and identifiers stay. This view does not open the live play page.
@MainActor struct PlayCircleRetiredLinkView: View {
    let goHome: () -> Void
    var body: some View {
        CYEmptyState(
            // MP circle onLoad without topicId: cy-empty missing-param (info glyph), 探索链接不完整, no sub line, 返回首页.
            systemImage: "info.circle",
            "playx.circleLink.title",
            messageIdentifier: "playx.circleLink.missing",
            actionTitle: "playx.circleLink.home",
            actionIdentifier: "playx.circleLink.home",
            actionStyle: .primary,
            action: goHome
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(CYColor.bgPage)
        // PLAYC-2: MP cy-nav-bar 自由探索 on every host (deep link and in-app).
        .cyPageTitle("playFree.title")
    }
}

#if DEBUG
/// `--play-circle-link-query "topicId=12&inviteCode=AB12"`; an empty query shows the missing state.
@MainActor struct PlayCircleLegacyLinkFixtureHost: View {
    @State private var link: PlayCircleLegacyLink
    @State private var wentHome = false
    init() {
        let args = ProcessInfo.processInfo.arguments
        let index = args.firstIndex(of: "--play-circle-link-query")
        let raw = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? ""
        var query: [String: String] = [:]
        for item in URLComponents(string: "?" + raw)?.queryItems ?? [] { query[item.name] = item.value ?? "" }
        _link = State(initialValue: PlayCircleLegacyLink.resolve(query))
    }
    var body: some View {
        NavigationStack {
            switch link {
            case .missingParameter:
                if wentHome { Text("playx.circleLink.fixtureHome").accessibilityIdentifier("playx.circleLink.fixtureHome") }
                else { PlayCircleRetiredLinkView { wentHome = true } }
            case .play(let topicID, let invite, let registration):
                VStack {
                    Text(verbatim: "topic \(topicID)").accessibilityIdentifier("playx.circleLink.redirect.topic")
                    Text(verbatim: "invite \(invite ?? "-")").accessibilityIdentifier("playx.circleLink.redirect.invite")
                    Text(verbatim: "registration \(registration.map(String.init) ?? "-")").accessibilityIdentifier("playx.circleLink.redirect.registration")
                }
            }
        }
    }
}
#endif
