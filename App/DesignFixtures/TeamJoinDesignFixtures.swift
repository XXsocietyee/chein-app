#if DEBUG
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/team/join/index?entry=code` is the 加入码 field
/// (≤ 40) with its error under it and 下一步 as the one primary button (wxml:24-30); a malformed code shows
/// 加入码不对，检查一下再输, and a code the server cannot resolve comes back to the field with the lookup reason
/// (js:154, :168). The page had no design fixture. These mount the same `TeamInvitationEntryView` the team home
/// pushes, on the offline synthetic team service, with no debug controls:
/// `t5-team-join` (empty field), `t5-team-join-invalid` (malformed code), `t5-team-join-network` (lookup failed).
@MainActor struct TeamJoinDesignFixtureHost: View {
    enum Mode { case blank, invalid, network }
    @State private var service: TeamSyntheticService?
    private let mode: Mode
    private let journal = TeamMemoryJournal()

    init(mode: Mode) {
        self.mode = mode
        _service = State(initialValue: try? TeamSyntheticService(scenario: .invitation))
    }

    private func makeCoordinator(_ service: TeamSyntheticService) -> TeamCoordinator {
        let session = try? TeamSyntheticFixtures.session()
        return TeamCoordinator(service: service, journal: journal, currentSession: { session })
    }

    private var presetCode: String {
        switch mode {
        case .blank: return ""
        case .invalid: return "LANTERN://42"
        case .network: return "LANTERN-42"
        }
    }

    private var presetReason: LocalizedStringKey? {
        mode == .network ? "mpr3.team.joinCodeNetwork" : nil
    }

    var body: some View {
        if let service {
            NavigationStack {
                TeamInvitationEntryView(makeCoordinator: { makeCoordinator(service) },
                                        presetCode: presetCode,
                                        presetInvalid: mode == .invalid,
                                        presetReason: presetReason)
            }
        } else {
            ContentUnavailableView("team.loadFailed", systemImage: "exclamationmark.triangle")
        }
    }
}
#endif
