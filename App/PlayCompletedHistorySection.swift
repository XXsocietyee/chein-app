import SwiftUI

/// `_loadCompletedHistory`: after the route loads, `GET api/play/history` returns the run's already-earned
/// chapters. Chapters the live route no longer lists are appended to the chapter cards as read-only
/// 「已完成章节」 cards (`play-history.js project()`); this renders those cards. A failed or mismatched read
/// shows nothing — never a partial history.
@MainActor struct PlayCompletedHistorySection: View {
    let routeSessionID: Int?
    let liveChapterIDs: Set<Int>
    @Environment(\.playRuntimeGap) private var binding
    @State private var history: PlayHistoryProjection?

    private var missing: [PlayHistoryProjection.Chapter] {
        (history?.chapters ?? []).filter { !liveChapterIDs.contains($0.id) && !$0.lines.isEmpty }
    }

    var body: some View {
        Group {
            if !missing.isEmpty {
                Section("playHistory.title") {
                    ForEach(missing, id: \.id) { chapter in
                        DisclosureGroup {
                            ForEach(Array(chapter.lines.enumerated()), id: \.offset) { _, line in
                                Text(verbatim: line).font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                            }
                        } label: {
                            Label { Text("playHistory.chapter") } icon: { Image(systemName: "book.closed").accessibilityHidden(true) }
                        }
                        .accessibilityIdentifier("playHistory.chapter.\(chapter.id)")
                    }
                }
            }
        }
        .task(id: routeSessionID) { await load() }
    }

    private func load() async {
        guard let binding, let owner = binding.ownerID, let client = binding.client(),
              let scope = PlayHistoryScope(owner: owner, activityID: binding.activityID, topicID: binding.topicID,
                                           routeSessionID: routeSessionID) else { history = nil; return }
        let read = await PlayHistoryProjection.read(client: client, scope: scope, configVersion: nil)
        guard !Task.isCancelled, binding.ownerID == owner else { return }
        history = read
    }
}
