import SwiftUI

/// Loads `pages/publish/simple` home and AI quota through `QuickPublishSimplePageCoordinator`.
/// A missing reader stays on screen: the quota is an em dash and the form is not hidden.
@MainActor final class QuickPublishSimplePageOwner: ObservableObject {
    @Published private(set) var phase: QuickPublishSimplePageSnapshot.Phase = .loading
    @Published private(set) var quotaText = QuickPublishSimpleCount.unknownText
    private var generation = 0

    func load(read: ((PublishingRead) async throws -> ProjectEditJSON)?, draft: QuickPublishDraft) async {
        generation += 1
        let stamp = generation
        guard let read else {
            phase = Self.blank(draft) ? .empty : .ready
            quotaText = QuickPublishSimpleCount.unknownText
            return
        }
        phase = .loading
        let grant = QuickPublishSimplePageGrant(features: [.publishingRead, .publishingAIQuota])
        let coordinator = QuickPublishSimplePageCoordinator(grant: grant, read: read)
        await coordinator.load(draft: draft)
        guard stamp == generation else { return }
        let snapshot = coordinator.snapshot
        phase = snapshot.phase == .hidden ? .empty : snapshot.phase
        quotaText = snapshot.showsAIQuota ? snapshot.quotaRemainingText : QuickPublishSimpleCount.unknownText
    }

    private static func blank(_ draft: QuickPublishDraft) -> Bool {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.nodes.isEmpty
    }
}

struct QuickPublishSimplePageStatus: View {
    @ObservedObject var owner: QuickPublishSimplePageOwner
    private let table = "WP06PartialPages"

    var body: some View {
        switch owner.phase {
        case .loading:
            ProgressView()
                .accessibilityIdentifier("publishModes.quick.loading")
            Text("wp06.publish.loading", tableName: table)
        case .error:
            Text("wp06.publish.error", tableName: table)
                .accessibilityIdentifier("publishModes.quick.error")
        case .empty, .hidden:
            Text("wp06.publish.empty", tableName: table)
                .accessibilityIdentifier("publishModes.quick.empty")
            Text(verbatim: owner.quotaText)
                .accessibilityIdentifier("publishModes.quick.quota")
        case .unknown:
            Text("wp06.publish.unknown", tableName: table)
                .accessibilityIdentifier("publishModes.quick.unknown")
            Text(verbatim: owner.quotaText)
                .accessibilityIdentifier("publishModes.quick.quota")
        case .ready:
            Text("wp06.publish.quotaRemaining", tableName: table)
            Text(verbatim: owner.quotaText)
                .accessibilityIdentifier("publishModes.quick.quota")
        }
    }
}
