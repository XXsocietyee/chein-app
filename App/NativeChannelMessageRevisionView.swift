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
            Section {
                CYHeroHeader("revisions.title", tableName: "NativeChannelMessage")
                    .channelKitInset(clear: true)
            }
            if canRead {
                if rows.isEmpty && !loading && !failed && !hasMore {
                    CYEmptyState(systemImage: "clock.arrow.circlepath", "d7.channelRevisions.empty")
                        .channelKitInset(clear: true)
                } else {
                    ForEach(rows) { row in
                        revisionRow(row).channelKitInset()
                    }
                    if hasMore {
                        CYPillButton("search.more", style: failed ? .secondary : .primary, tableName: "NativeChannelMessage") {
                            Task { await load() }
                        }
                        .disabled(loading)
                        .accessibilityLabel(Text("search.more", tableName: "NativeChannelMessage"))
                        .channelKitInset(clear: true)
                    }
                }
            }
            if loading {
                CYSkeleton().channelKitInset(clear: true)
            }
            if failed {
                CYEmptyState(
                    systemImage: "exclamationmark.triangle",
                    "load.failed",
                    tableName: "NativeChannelMessage",
                    actionTitle: "messaging.retry",
                    actionIdentifier: "ncm47.revisions.retry",
                    actionStyle: .primary,
                    kind: .failure
                ) { Task { await load() } }
                .disabled(retryBlocked)
                .channelKitInset(clear: true)
            }
        }
        .nativeChannelScreen()
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cyHeroScreen()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.done") { dismiss() } } }
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
            CYStatusChip("d7.channelRevisions.version \(row.revision_no)", systemImage: "clock.arrow.circlepath")
            if let content = readable(row.content) {
                CYListRow(verbatim: content, trailing: CYListRowTrailing.none) {
                    ChannelCoverTile(seed: "revision-\(row.revision_no)", symbol: "clock.arrow.circlepath")
                }
                .textSelection(.enabled)
            } else {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    CYRowIcon(systemImage: "text.bubble")
                    Text("message.unavailable", tableName: "NativeChannelMessage")
                        .font(CYTypography.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// 40pt generated cover. The frame is on a solid color so the art cannot expand the row.
private struct ChannelCoverTile: View {
    let seed: String
    let symbol: String
    var body: some View {
        Color.clear
            .frame(width: 40, height: 40)
            .overlay {
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false, cornerRadius: CYRadius.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct ChannelKitInset: ViewModifier {
    var clear = false
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(clear ? Color.clear : CYColor.bgElevated)
            .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.lg, bottom: CYSpacing.md, trailing: CYSpacing.lg))
    }
}

private extension View {
    func channelKitInset(clear: Bool = false) -> some View {
        modifier(ChannelKitInset(clear: clear))
    }
}
