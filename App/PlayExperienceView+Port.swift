import SwiftUI

/// PORT-6 `pages/play`: re-read the authoritative run state after a read-side problem.
/// Calls the existing coordinator `load()` only; no route, lease or endpoint is added.
@MainActor struct PlayResyncAction: View {
    let model: PlayExperienceCoordinator
    var body: some View {
        if model.snapshot != nil, PlayResyncPort.offersResync(for: model.issue) {
            Button("playx.resync", systemImage: "arrow.clockwise") { Task { await model.load() } }
                .disabled(model.phase == .submitting || model.phase == .loading)
                .frame(minHeight: 44)
                .accessibilityIdentifier("playx.resync")
        }
    }
}
