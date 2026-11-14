#if DEBUG
import SwiftUI

/// One open creation and one closed-lease creation. The closed lease keeps the review button and does not send.
@MainActor struct SessionTeamCreateFixtureHost: View {
    var body: some View {
        if let coordinator = Self.coordinator() {
            TeamCreateView(activityID: TeamSyntheticFixtures.creation.ownerID, coordinator: coordinator)
        } else {
            CurA11yNotice(
                text: Text("team.create.leaseClosed"),
                hint: Text("curA11y.teamCreate.closed.hint", tableName: "CurA11y"),
                identifier: "team.create.leaseClosed",
                heading: true
            )
        }
    }

    static func coordinator() -> TeamCoordinator? {
        guard let session = try? TeamSyntheticFixtures.session() else { return nil }
        let journal = TeamMemoryJournal()
        let closed = ProcessInfo.processInfo.arguments.contains("--session-team-create=closed")
        if closed {
            let service = TeamReadOnlyService(creationLoader: { owner, _ in
                guard owner == TeamSyntheticFixtures.creation.ownerID else { throw TeamFailure.invalidRequest }
                return TeamSyntheticFixtures.creation
            })
            return TeamCoordinator(service: service, journal: journal, currentSession: { session })
        }
        guard let service = try? TeamSyntheticService(scenario: .content) else { return nil }
        return TeamCoordinator(service: service, journal: journal, currentSession: { session })
    }
}
#endif
