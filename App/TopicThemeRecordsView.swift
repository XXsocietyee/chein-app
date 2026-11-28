import SwiftUI

/// Source "我的游玩记录" sheet: paged history (20 per page) and a per-run result card. Read-only; no replay.
@MainActor struct TopicThemeRecordsView: View {
    let topicID: Int
    let topicName: String
    let reader: any TopicThemeRecordsReading
    @Environment(\.locale) private var locale
    @State private var rows: [TopicThemeRecord] = []
    @State private var nextBefore: Int?
    @State private var hasMore = false
    @State private var loading = false
    @State private var failed = false
    @State private var loadedScope: UUID?
    var body: some View {
        List {
            Section { Text(verbatim: topicName).font(.subheadline).foregroundStyle(.secondary) }
            if loading && rows.isEmpty { ProgressView { Text("topicXcx.records.loading") }.frame(maxWidth: .infinity) }
            else if failed && rows.isEmpty {
                ContentUnavailableView {
                    Label { Text("topicXcx.records.failed").accessibilityIdentifier("topic.records.failed") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    Button { Task { await load(reset: true) } } label: { Text("topicXcx.records.reload") }
                        .buttonStyle(.bordered)
                }
            } else if rows.isEmpty && loadedScope == reader.scope {
                ContentUnavailableView {
                    Label { Text("topicXcx.records.empty").accessibilityIdentifier("topic.records.empty") } icon: { Image(systemName: "clock") }
                }
            }
            ForEach(rows) { row in
                NavigationLink { TopicThemeCardView(sessionID: row.sessionID, reader: reader, topicID: topicID, topicName: topicName) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        switch row.title {
                        case .server(let text): Text(verbatim: text).font(.headline)
                        case .completed: Text("topicXcx.records.completed").font(.headline)
                        case .ended: Text("topicXcx.records.ended").font(.headline)
                        case .playing: Text("topicXcx.records.playing").font(.headline)
                        }
                        if let scene = row.sceneName { Text(verbatim: scene).font(.subheadline) }
                        if let ended = row.endedAt { Text(verbatim: LocaleDisplay.civil(ended, locale: locale)).font(.subheadline).foregroundStyle(.secondary) }
                        else { Text("topicXcx.records.playing").font(.subheadline).foregroundStyle(.secondary) }
                        if let summary = row.summary { Text(verbatim: summary).font(.subheadline).lineLimit(2) }
                    }
                }.accessibilityIdentifier("topic.records.row.\(row.sessionID)")
            }
            if hasMore && !rows.isEmpty {
                Button(failed ? "topicXcx.records.reload" : "topicXcx.records.more") { Task { await load(reset: false) } }
                    .disabled(loading).accessibilityIdentifier("topic.records.more")
            }
        }
        .appNavigationTitle("topicXcx.records.title")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reader.scope) { await load(reset: true) }
        .refreshable { await load(reset: true) }
        .accessibilityIdentifier("topic.records")
        .cyDomainScreen(.player)
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
    /// R11-PC-B-1: the topic, for 查看战报 (MP utils/theme-records.js:35-42 `openThemeRunReport`) and 再玩一局 (:127-161).
    var topicID: Int = 0
    var topicName: String = ""
    @State private var card: TopicThemeCard?
    @State private var failed = false
    @State private var replayAllowed = false
    @State private var replayBusy = false
    @State private var replayFailed = false
    @State private var showsReplayRun = false
    @Environment(\.topicThemeRecordsSession) private var session
    private var replayBinding: PlayThemeReplayProduction? {
        guard let session else { return nil }
        return PlayThemeReplayBridge.binding(session: session, scope: .topic(topicID), topicID: topicID)
    }
    var body: some View {
        List {
            // MP theme-records card sheet: title → summary → 场景 + values → items → medals → epilogues → next scene,
            // then 本局战报 / 再玩一次 at the end.
            if let card {
                Section {
                    if let title = card.title { Text(verbatim: title).font(.title3.weight(.semibold)) } else { Text("topicXcx.records.cardTitle").font(.title3.weight(.semibold)) }
                    if let summary = card.summary { Text(verbatim: summary) }
                }
                if card.scene != nil || !card.values.isEmpty {
                    Section {
                        if let scene = card.scene { LabeledContent { Text(verbatim: scene) } label: { Text("topicXcx.records.scene") } }
                        ForEach(Array(card.values.enumerated()), id: \.offset) { _, row in
                            LabeledContent {
                                Text(verbatim: String(row.value))
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
                            VStack(alignment: .leading) { Text(verbatim: row.name).font(.headline); if let line = row.line { Text(verbatim: line) } }
                        }
                    }
                }
                if let next = card.nextScene { Text("topicXcx.records.nextScene \(next)").foregroundStyle(.secondary) }
                if topicID > 0 { runActions }
            } else if failed {
                ContentUnavailableView {
                    Label { Text("topicXcx.records.cardFailed").accessibilityIdentifier("topic.records.cardFailed") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    Button { Task { await load() } } label: { Text("topicXcx.records.cardReload") }
                        .buttonStyle(.bordered)
                }
            } else {
                ProgressView { Text("topicXcx.records.cardLoading") }.frame(maxWidth: .infinity)
            }
        }
        .task(id: reader.scope) { await load() }
        .task(id: sessionID) { await loadReplay() }
        .refreshable { await load() }
        .navigationDestination(isPresented: $showsReplayRun) {
            if let session { SessionPlayRuntimeView(session: session, destination: .journey(.topic(topicID))) }
        }
        .accessibilityIdentifier("topic.records.card")
        .cyDomainScreen(.player)
    }
    /// R11-PC-B-1: 查看战报 opens the run report for this session; 再玩一局 only when theme state says `replayAllowed` and the
    /// run is not a TEAM run (`PlayThemeReplayExchange.focus`), then the existing replay write and the topic play page.
    @ViewBuilder private var runActions: some View {
        Section {
            if let session {
                NavigationLink {
                    MPReviewedPageScreen(page: "subpackageJourney/pages/report/index",
                                         query: ["topicId": String(topicID), "runId": String(sessionID), "topicName": topicName])
                        .environmentObject(session)
                } label: { Label("topicXcx.records.viewReport", systemImage: "doc.text.magnifyingglass") }
                    .accessibilityIdentifier("topic.records.viewReport")
            }
            if replayAllowed {
                Button {
                    Task { await replay() }
                } label: { Label("topicXcx.records.replay", systemImage: "arrow.counterclockwise") }
                    .disabled(replayBusy)
                    .accessibilityIdentifier("topic.records.replay")
                if replayFailed {
                    Text("topicXcx.records.replayFailed").font(.footnote).foregroundStyle(CYColor.dangerText)
                }
            }
        }
    }
    private func loadReplay() async {
        guard topicID > 0, let binding = replayBinding else { replayAllowed = false; return }
        replayAllowed = await binding.focus(sessionID: sessionID)
    }
    private func replay() async {
        guard !replayBusy, let binding = replayBinding else { return }
        replayBusy = true; replayFailed = false
        defer { replayBusy = false }
        if await binding.replay() { showsReplayRun = true } else { replayFailed = true; replayAllowed = binding.allowed }
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

private struct TopicThemeRecordsSessionKey: EnvironmentKey { static let defaultValue: AppSession? = nil }
extension EnvironmentValues {
    /// R11-PC-B-1: the signed-in session for the record card's 查看战报 / 再玩一局. Nil hides both.
    var topicThemeRecordsSession: AppSession? {
        get { self[TopicThemeRecordsSessionKey.self] }
        set { self[TopicThemeRecordsSessionKey.self] = newValue }
    }
}
