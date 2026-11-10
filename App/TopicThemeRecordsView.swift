import SwiftUI

/// Source "我的游玩记录" sheet: paged history (20 per page) and a per-run result card. Read-only; no replay.
@MainActor struct TopicThemeRecordsView: View {
    let topicID: Int
    let topicName: String
    let reader: any TopicThemeRecordsReading
    @State private var rows: [TopicThemeRecord] = []
    @State private var nextBefore: Int?
    @State private var hasMore = false
    @State private var loading = false
    @State private var failed = false
    @State private var loadedScope: UUID?
    var body: some View {
        List {
            Section { CYHeroHeader("topicXcx.records.title", subtitle: nil) }.e1HeroRow()
            Section { Text(verbatim: topicName).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
            if loading && rows.isEmpty { CYLoadingStateView(rows: 3).accessibilityLabel(Text("topicXcx.records.loading")).listRowBackground(Color.clear) }
            else if failed && rows.isEmpty {
                CYEmptyState(systemImage: "wifi.exclamationmark", "topicXcx.records.failed", messageIdentifier: "topic.records.failed",
                             actionTitle: "topicXcx.records.reload", kind: .failure) { Task { await load(reset: true) } }
                    .listRowBackground(Color.clear)
            } else if rows.isEmpty && loadedScope == reader.scope {
                CYEmptyState(systemImage: "clock", "topicXcx.records.empty", messageIdentifier: "topic.records.empty")
                    .listRowBackground(Color.clear)
            }
            ForEach(rows) { row in
                NavigationLink { TopicThemeCardView(sessionID: row.sessionID, reader: reader) } label: {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        switch row.title {
                        case .server(let text): Text(verbatim: text).font(CYTypography.cardTitle)
                        case .completed: Text("topicXcx.records.completed").font(CYTypography.cardTitle)
                        case .ended: Text("topicXcx.records.ended").font(CYTypography.cardTitle)
                        case .playing: Text("topicXcx.records.playing").font(CYTypography.cardTitle)
                        }
                        if let scene = row.sceneName { Text(verbatim: scene).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                        if let ended = row.endedAt { Text(verbatim: ended).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                        else { Text("topicXcx.records.playing").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                        if let summary = row.summary { Text(verbatim: summary).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).lineLimit(2) }
                    }
                }.accessibilityIdentifier("topic.records.row.\(row.sessionID)")
            }
            if hasMore && !rows.isEmpty {
                CYPillButton(failed ? "topicXcx.records.reload" : "topicXcx.records.more", style: .secondary) { Task { await load(reset: false) } }
                    .disabled(loading).accessibilityIdentifier("topic.records.more").e1ActionRow()
            }
        }
        .listStyle(.insetGrouped).cyGroupedSurface().cyHeroScreen()
        .task(id: reader.scope) { await load(reset: true) }
        .accessibilityIdentifier("topic.records")
    }
    private func load(reset: Bool) async {
        guard !loading, reader.isConfigured else { return }
        let scope = reader.scope
        loading = true; failed = false
        defer { loading = false }
        do {
            let page = try await reader.themeHistory(topicID: topicID, beforeSessionID: reset ? nil : nextBefore)
            guard scope == reader.scope else { return }
            var seen = Set(reset ? [] : rows.map(\.sessionID))
            rows = (reset ? [] : rows) + page.rows.filter { seen.insert($0.sessionID).inserted }
            hasMore = page.hasMore; nextBefore = page.nextBefore; loadedScope = scope
        } catch is CancellationError { }
        catch { if scope == reader.scope { failed = true; if reset { rows = [] }; loadedScope = scope } }
    }
}

@MainActor struct TopicThemeCardView: View {
    let sessionID: Int
    let reader: any TopicThemeRecordsReading
    @State private var card: TopicThemeCard?
    @State private var failed = false
    var body: some View {
        List {
            if let card {
                Section {
                    if let title = card.title { CYHeroHeader(verbatim: title).e1HeroRow() } else { CYHeroHeader("topicXcx.records.cardTitle").e1HeroRow() }
                    if let scene = card.scene { LabeledContent { Text(verbatim: scene) } label: { Text("topicXcx.records.scene") } }
                    if let summary = card.summary { Text(verbatim: summary) }
                }
                if !card.values.isEmpty {
                    Section {
                        ForEach(Array(card.values.enumerated()), id: \.offset) { _, row in
                            LabeledContent {
                                Text(verbatim: String(row.value)).font(CYTypography.numericBody)
                            } label: {
                                if let label = row.label { Text(verbatim: label) } else { Text(LocalizedStringKey("topicXcx.records.value." + row.kind)) }
                            }
                        }
                    }
                }
                quantitySection(card.items, title: "topicXcx.records.items")
                quantitySection(card.medals, title: "topicXcx.records.medals")
                if !card.epilogues.isEmpty {
                    Section("topicXcx.records.epilogues") {
                        ForEach(Array(card.epilogues.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) { Text(verbatim: row.name).font(CYTypography.cardTitle); if let line = row.line { Text(verbatim: line).font(CYTypography.body).foregroundStyle(CYColor.textSecondary) } }
                        }
                    }
                }
                if let next = card.nextScene { Text("topicXcx.records.nextScene \(next)") }
            } else if failed {
                CYEmptyState(systemImage: "wifi.exclamationmark", "topicXcx.records.cardFailed", messageIdentifier: "topic.records.cardFailed",
                             actionTitle: "topicXcx.records.cardReload", kind: .failure) { Task { await load() } }
                    .listRowBackground(Color.clear)
            } else { CYLoadingStateView(rows: 2).accessibilityLabel(Text("topicXcx.records.cardLoading")).listRowBackground(Color.clear) }
        }
        .listStyle(.insetGrouped).cyGroupedSurface().cyHeroScreen()
        .task(id: reader.scope) { await load() }
        .accessibilityIdentifier("topic.records.card")
    }
    @ViewBuilder private func quantitySection(_ rows: [TopicThemeCard.Quantity], title: LocalizedStringKey) -> some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent { if let q = row.quantity { Text(verbatim: "×\(q)") } } label: { Text(verbatim: row.name) }
                }
            }
        }
    }
    private func load() async {
        let scope = reader.scope; failed = false
        do { let value = try await reader.themeCard(sessionID: sessionID); if scope == reader.scope { card = value } }
        catch is CancellationError { }
        catch { if scope == reader.scope { failed = true } }
    }
}
