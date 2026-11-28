#if DEBUG
import SwiftUI

/// Design fixtures for MP `pages/team/detail` (mp-activity): `t5-team-detail` (leader view),
/// `t5-team-invite` (invitation, not joined) and `t5-team-detail-error` (read failure).
/// Same `TeamDetailView` the app pushes, offline synthetic service, data in the UI language,
/// and none of the UI-test account switch buttons.
@MainActor struct TeamDetailDesignFixtureHost: View {
    enum Mode { case leader, invitation, failure }
    @State private var service: TeamSyntheticService?
    private let mode: Mode
    private let journal = TeamMemoryJournal()

    init(mode: Mode) {
        self.mode = mode
        let scenario: TeamSyntheticService.Scenario
        switch mode {
        case .leader: scenario = .content
        case .invitation: scenario = .invitation
        case .failure: scenario = .failure
        }
        let made = try? TeamSyntheticService(scenario: scenario)
        if let made, let detail = Self.localizedDetail(joined: mode == .leader) { made.currentDetail = detail }
        made?.context = TeamCreationContext(ownerID: 5101, title: Self.tt("Harbour lantern night walk", "港口灯笼夜游"), registrationStatus: 2, teamMode: 2, maxMembers: 4)
        _service = State(initialValue: made)
    }

    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }

    private static func localizedDetail(joined: Bool) -> TeamDetail? {
        let membership = joined ? "\"joined\":true,\"leader\":true" : "\"joined\":false,\"leader\":false"
        let title = tt("Harbour lantern walk crew", "港口灯笼夜游小队")
        let captain = tt("Leo Chen", "陈乐")
        let mate = tt("Mia", "小米")
        let json = "{\"team\":{\"id\":4101,\"title\":\"\(title)\",\"status\":0,\"joinedCount\":2,\"maxMembers\":4,\"ownerType\":2,\"ownerId\":5101,\"expireTime\":\"2030-05-02 10:00:00\",\"joinMode\":2,\"inviteCode\":\"SYNTHETIC-TEAM\"},\(membership),\"members\":[{\"memberId\":901,\"memberName\":\"\(captain)\",\"role\":1},{\"memberId\":902,\"memberName\":\"\(mate)\",\"role\":0}]}"
        return try? JSONDecoder().decode(TeamDetail.self, from: Data(json.utf8))
    }

    private func makeCoordinator(_ service: TeamSyntheticService) -> TeamCoordinator {
        let session = try? TeamSyntheticFixtures.session()
        return TeamCoordinator(service: service, journal: journal, currentSession: { session })
    }

    var body: some View {
        if let service {
            NavigationStack {
                TeamDetailView(lookup: mode == .invitation ? .invitation("SYNTHETIC-TEAM") : .id(4101),
                               coordinator: makeCoordinator(service),
                               makeCoordinator: { makeCoordinator(service) })
            }
        } else {
            ContentUnavailableView("team.loadFailed", systemImage: "exclamationmark.triangle")
        }
    }
}
#endif
