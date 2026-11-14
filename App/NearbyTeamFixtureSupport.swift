#if DEBUG
import SwiftUI
@MainActor struct NearbyTeamFixtureRoot: View {
    @State private var destination: NearbyTeamDestination?
    /// `--nearby-team-fixture-empty-mine`, or `emptyMine: true`, opens 我的 with no teams.
    private let emptyMine: Bool
    @State private var coordinator: NearbyTeamCoordinator
    init(emptyMine: Bool = false) {
        let empty = emptyMine || ProcessInfo.processInfo.arguments.contains("--nearby-team-fixture-empty-mine")
        self.emptyMine = empty
        _coordinator = State(initialValue: NearbyTeamSyntheticFixtures.coordinator(emptyMine: empty))
    }
    var body: some View {
        NavigationStack {
            NearbyTeamsView(coordinator: coordinator, context: NearbyTeamSyntheticFixtures.context,
                            joinedTeams: emptyMine ? [] : NearbyTeamSyntheticFixtures.joinedTeams, initialTab: emptyMine ? 1 : 0) { destination = $0 }
                .overlay(alignment: .bottom) {
                    if let destination { Text(verbatim: String(describing: destination)).accessibilityIdentifier("nearby.fixture.destination") }
                }
        }
    }
}
#endif
