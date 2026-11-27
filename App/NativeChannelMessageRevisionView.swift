import SwiftUI

@MainActor struct NativeChannelMessageRevisionView: View {
    let client: any NativeChannelMessageAccess
    let messageID: NativeChannelMessageID
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [NativeChannelMessageRevision] = []
    @State private var cursor: Int64?
    @State private var hasMore = false
    @State private var loading = false
    @State private var failed = false
    @State private var identity: MessagingReadIdentity?
    @State private var generation = 0
    private var canRead: Bool {
        phase == .active && identity != nil && client.identity == identity && client.allows(.revisions)
    }
    private var retryBlocked: Bool {
        phase != .active || loading || identity == nil || client.identity != identity || !client.allows(.revisions)
    }
    var body: some View {
        List {
            if canRead {
                if rows.isEmpty && !loading && !failed && !hasMore {
                    ContentUnavailableView("d7.channelRevisions.empty", systemImage: "clock.arrow.circlepath")
                } else {
                    ForEach(rows) { row in
                        Section { revisionRow(row) }
                    }
                    if hasMore {
                        Button { Task { await load() } } label: { Text("search.more", tableName: "NativeChannelMessage") }
                            .disabled(loading)
                            .accessibilityLabel(Text("search.more", tableName: "NativeChannelMessage"))
                    }
                }
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity)
            }
            if failed {
                ContentUnavailableView {
                    Label { Text("load.failed", tableName: "NativeChannelMessage") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    Button("messaging.retry") { Task { await load() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("ncm47.revisions.retry")
                }
                .disabled(retryBlocked)
            }
        }
        .nativeChannelScreen()
        .listStyle(.insetGrouped)
        .navigationTitle(Text("revisions.title", tableName: "NativeChannelMessage"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { dismiss() } } }
        .task(id: phase) {
            clear()
            guard phase == .active else { return }
            identity = client.identity
            await load()
        }
        .onChange(of: client.identity) { _, _ in clear() }
        .onDisappear(perform: clear).privacySensitive()
    }
    private func revisionRow(_ row: NativeChannelMessageRevision) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label("d7.channelRevisions.version \(row.revision_no)", systemImage: "clock.arrow.circlepath")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let content = readable(row.content) {
                Text(verbatim: content)
                    .textSelection(.enabled)
            } else {
                Label {
                    Text("message.unavailable", tableName: "NativeChannelMessage")
                } icon: {
                    Image(systemName: "text.bubble")
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
    }
    /// Blank withheld copy is unknown. A real revision number stays a number, including 0.
    private func readable(_ content: String?) -> String? {
        guard let content else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : content
    }
    private func clear() { generation += 1; rows = []; identity = nil; cursor = nil; hasMore = false; loading = false; failed = false }
    private func load() async {
        guard phase == .active, !Task.isCancelled, !loading, let identity, client.identity == identity, client.allows(.revisions) else { return }
        let run = generation, requested = cursor; loading = true; failed = false
        defer { if generation == run { loading = false } }
        do {
            let page = try await client.revisions(messageID: messageID, cursor: requested)
            guard generation == run, client.identity == identity, client.allows(.revisions), !Task.isCancelled else { return }
            let ids = Set(rows.map(\.id)); rows += page.list.filter { !ids.contains($0.id) }
            cursor = page.next_cursor.flatMap(Int64.init); hasMore = page.has_more
        } catch { if generation == run { failed = true; if !client.allows(.revisions) { clear() } } }
    }
}
