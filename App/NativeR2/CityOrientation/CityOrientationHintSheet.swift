import SwiftUI

/// P-056: 提示 on the run sheet opens the stop's hint ladder in place (a `.medium` / `.large` sheet over the
/// map) instead of pushing the stop page. A revealed hint also pops as a `.hint` island.
///
/// Behaviour is the stop page's: the same `PlayHelpLadderModel` read (`model.helpClient(nodeID:)` +
/// `load()`), the same team pool read, and the same `PlayHelpLadderPanel` (use / skip go through its own
/// confirm dialogs). When the server has no ladder for this stop, the legacy hint rows still live on the
/// stop page, so the sheet offers that page instead of guessing.
@MainActor struct CityOrientationHintSheet: View {
    @Bindable var model: PlayExperienceCoordinator
    let nodeID: Int
    var makeTeamPool: ((Int) -> TeamPoolHintModel?)? = nil
    var approvedArtworkHosts: Set<String> = []
    /// Opens the stop page (legacy hint rows) when the ladder is not enabled for this stop.
    let onOpenStop: (Int) -> Void
    @State private var help: PlayHelpLadderModel?
    @State private var teamPool: TeamPoolHintModel?
    @State private var loading = true
    @Environment(\.dismiss) private var dismiss

    private var ladder: PlayHelpLadderModel? {
        guard let current = help, current.enabled, current.identity.nodeID == nodeID else { return nil }
        return current
    }

    var body: some View {
        Group {
            if let ladder {
                PlayHelpLadderPanel(model: ladder, teamPool: teamPool, approvedArtworkHosts: approvedArtworkHosts,
                                     analyticsNodeID: nodeID, close: { dismiss() })
            } else if loading {
                ProgressView("playx.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("playHUD.hint", systemImage: "lightbulb")
                } description: {
                    Text("nativeR2.city.hint.onStop")
                } actions: {
                    Button("nativeR2.city.hint.openStop") { onOpenStop(nodeID) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("nativeR2.city.hint.openStop")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Native r2 M4: a revealed hint shows as a hint island; the ladder is already open here.
        .islandHints(ladder) {}
        .task(id: nodeID) { await load() }
        .accessibilityIdentifier("nativeR2.city.hint")
    }

    /// The stop page's `loadHelp`: one ladder read and the team pool read. Nothing new is sent.
    private func load() async {
        loading = true
        defer { loading = false }
        guard let snapshot = model.snapshot, let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }),
              !snapshot.isDone(node), !snapshot.isLocked(node), let client = model.helpClient(nodeID: nodeID) else {
            help = nil
            return
        }
        if teamPool?.nodeID != Int64(nodeID) {
            teamPool = makeTeamPool?(nodeID)
            teamPool?.onPoolUpdated = { updated in
                if updated.solvedNodeIds?.contains(Int64(nodeID)) == true {
                    Task { await model.load() }
                }
            }
        }
        if let current = help, current.identity == client.identity, current.loaded { await teamPool?.load(); return }
        let next = PlayHelpLadderModel(client: client, store: PlayHelpDefaultsRequestStore.shared)
        help = next
        await next.load()
        await teamPool?.load()
    }
}

/// The control point whose hint sheet is open.
struct CityOrientationHintTarget: Identifiable, Hashable {
    let id: Int
}
