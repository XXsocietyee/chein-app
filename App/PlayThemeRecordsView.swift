import SwiftUI

/// 我的游玩记录 and 本局结果 (mini-program `cy-theme-records`). 再玩一次 is on the result sheet when replay is allowed.
@MainActor struct PlayThemeRecordsView: View {
    @Bindable var model: PlayThemeRecordsCoordinator
    var title: String?

    var body: some View {
        List {
            if let title { Text(verbatim: title).font(.subheadline).foregroundStyle(.secondary) }
            ForEach(model.rows) { row in
                Button { Task { await model.openCard(sessionID: row.sessionID) } } label: { rowLabel(row) }
                    .disabled(!row.hasCard && !row.isTeam)
                    .accessibilityIdentifier("playx.themeRecords.row.\(row.sessionID)")
            }
            if model.rows.isEmpty, !model.busy, model.issue == nil {
                CYEmptyStateView(systemImage: "clock.arrow.circlepath", title: "playx.themeRecords.empty")
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("playx.themeRecords.empty")
            }
            if model.busy, model.cardSessionID == nil { ProgressView("playx.themeRecords.loading") }
            if model.cardSessionID == nil, let issue = model.issue { issueText(issue) }
            if PlayThemeRecordsPagination.isOffered(model) {
                Button(model.issue == .historyFailed ? "playx.themeRecords.reload" : "playx.themeRecords.more") {
                    Task {
                        guard PlayThemeRecordsPagination.isOffered(model), !model.busy else { return }
                        await model.loadMore()
                    }
                }
                    .disabled(model.busy).accessibilityIdentifier("playx.themeRecords.more")
            }
        }.cyGroupedSurface()
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .cyPageTitle("playx.themeRecords.title")
        .accessibilityIdentifier("playx.themeRecords")
        .task { if model.rows.isEmpty { await model.open() } }
        .onDisappear { model.close() }
        .sheet(isPresented: Binding(get: { model.cardSessionID != nil }, set: { if !$0 { model.closeCard() } })) { Group {
            NavigationStack { cardContent.toolbar { ToolbarItem(placement: .cancellationAction) {
                Button { model.closeCard() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel(Text("playx.themeRecords.backToList")).accessibilityIdentifier("playx.themeRecords.closeCard")
            } } }
        }.cySheet(detents: [.large]) }
    }

    private func rowLabel(_ row: PlayThemeHistoryRow) -> some View {
        HStack {
            Image(systemName: row.hasCard ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(row.hasCard ? CYColor.successText : CYColor.textTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                outcomeText(row.outcome).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if let scene = row.sceneName { Text(verbatim: scene).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                if let summary = row.summary { Text(verbatim: summary).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
            }
            Spacer()
            if let ended = row.endedAt { Text(ended, format: .dateTime.year().month().day()).cyText(.caption).monospacedDigit().foregroundStyle(CYColor.textTertiary) }
            else { Text("playx.themeRecords.inProgress").cyText(.caption).foregroundStyle(CYColor.textTertiary) }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
    }

    private func outcomeText(_ outcome: PlayThemeHistoryRow.Outcome) -> Text {
        switch outcome {
        case .titled(let title): return Text(verbatim: title)
        case .completed: return Text("playx.themeRecords.completed")
        case .ended: return Text("playx.themeRecords.ended")
        case .inProgress: return Text("playx.themeRecords.inProgress")
        }
    }

    @ViewBuilder private func issueText(_ issue: PlayThemeRecordsCoordinator.Issue) -> some View {
        Group {
            switch issue {
            case .historyFailed, .refused: Text("playx.themeRecords.historyFailed")
            case .cardFailed: Text("playx.themeRecords.cardFailed")
            case .teamCardMissing: Text("playx.themeRecords.teamCardMissing")
            }
        }
        .foregroundStyle(CYColor.dangerText).accessibilityIdentifier("playx.themeRecords.issue")
    }

    private var cardContent: some View {
        List {
            if let title { Text(verbatim: title).cyText(.meta) }
            if let card = model.card {
                if let cardTitle = card.title { Text(verbatim: cardTitle).cyText(.sheetTitle) } else { Text("playx.themeRecords.cardTitle").cyText(.sheetTitle) }
                if let summary = card.summary { Text(verbatim: summary) }
                if card.scene != nil || !card.values.isEmpty {
                    Section {
                        if let scene = card.scene { LabeledContent { Text(verbatim: scene) } label: { Text("playx.themeRecords.scene") } }
                        ForEach(Array(card.values.enumerated()), id: \.offset) { _, row in
                            LabeledContent { Text(verbatim: row.value).cyText(.numericBody) } label: { valueName(row.name) }
                        }
                    }
                }
                ForEach(Array((card.items + card.medals).enumerated()), id: \.offset) { _, row in
                    LabeledContent { Text(verbatim: "×\(row.quantity)").monospacedDigit() } label: { Text(verbatim: row.name) }
                }
                ForEach(Array(card.epilogues.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading) { Text(verbatim: row.name).cyText(.cardTitle); Text(verbatim: row.line) }
                }
                ForEach(Array(card.exhibits.enumerated()), id: \.offset) { _, line in Text(verbatim: line) }
                if !card.knownEndings.isEmpty {
                    Section("playx.themeRecords.knownEndings") { ForEach(Array(card.knownEndings.enumerated()), id: \.offset) { _, ending in Text(verbatim: ending) } }
                }
                if let next = card.nextScene { Text("playx.themeRecords.nextScene \(next)").cyText(.meta) }
            }
            if model.busy { ProgressView("playx.themeRecords.cardLoading") }
            if let issue = model.issue { issueText(issue) }
            if model.issue == .cardFailed, let session = model.cardSessionID {
                Button("playx.themeRecords.retryCard") { Task { await model.openCard(sessionID: session) } }
                    .accessibilityIdentifier("playx.themeRecords.retryCard")
            }
            if let session = model.cardSessionID {
                PlayThemeReplayButton(sessionID: session)
            }
        }.cyGroupedSurface()
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .accessibilityIdentifier("playx.themeRecords.card")
    }

    private func valueName(_ name: PlayThemeResultCard.ValueName) -> Text {
        switch name {
        case .server(let text): return Text(verbatim: text)
        case .hp: return Text("playx.themeRecords.hp")
        case .luck: return Text("playx.themeRecords.luck")
        case .actions: return Text("playx.themeRecords.actions")
        case .rescues: return Text("playx.themeRecords.rescues")
        }
    }
}

/// Refusal is not a transient read failure. Preserve the loaded rows, but do not
/// turn a retained pagination cursor into a retry after 401 / 403 / code 2.
@MainActor enum PlayThemeRecordsPagination {
    static func isOffered(_ model: PlayThemeRecordsCoordinator) -> Bool {
        model.issue != .refused && model.hasMore
            && (!model.rows.isEmpty || model.issue == .historyFailed)
    }
}

#if DEBUG
#Preview("Records · dark (player)") { PlayThemeRecordsFixtureHost().preferredColorScheme(.dark) }
#Preview("Records · light sanity") { PlayThemeRecordsFixtureHost().preferredColorScheme(.light) }
#endif
