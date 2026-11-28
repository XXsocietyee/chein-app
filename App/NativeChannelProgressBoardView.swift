import SwiftUI

public struct NativeChannelProgressTeamOption: Identifiable, Equatable {
    public let id: Int64
    public let name: String
    public init(id: Int64, name: String) throws { guard id > 0, !name.isEmpty else { throw NativeChannelProgressError.invalid }; self.id = id; self.name = name }
}
/// Coalesces selection changes while Core is busy. Resume is event-driven, not a
/// polling/retry loop, and only the last pending user intent is dispatched.
@MainActor final class NativeChannelProgressSelectionQueue: ObservableObject {
    @Published private(set) var pending: NativeChannelProgressQuery?
    @Published private(set) var running = false
    var hasPendingSelection: Bool { running || pending != nil }
    private var active = false
    private var visit = UUID()
    private var task: Task<Void, Never>?

    func activate() { if !active { active = true; visit = UUID() } }
    func retire() {
        active = false; visit = UUID(); task?.cancel(); task = nil
        pending = nil; running = false
    }
    @discardableResult func enqueue(_ query: NativeChannelProgressQuery, isCurrent: @escaping @MainActor () -> Bool,
                 isBusy: @escaping @MainActor () -> Bool,
                 select: @escaping @MainActor (NativeChannelProgressQuery) async -> Void) -> Task<Void, Never>? {
        guard active, isCurrent() else { return nil }
        pending = query
        return resume(isCurrent: isCurrent, isBusy: isBusy, select: select)
    }
    @discardableResult func resume(isCurrent: @escaping @MainActor () -> Bool, isBusy: @escaping @MainActor () -> Bool,
                select: @escaping @MainActor (NativeChannelProgressQuery) async -> Void) -> Task<Void, Never>? {
        guard active, !running, isCurrent(), !isBusy(), pending != nil else { return task }
        running = true
        let stamp = visit
        task = Task { @MainActor [weak self] in
            guard let self, self.active, self.visit == stamp else { return }
            guard !Task.isCancelled, isCurrent() else { self.retire(); return }
            guard !isBusy(), let query = self.pending else {
                self.running = false; self.task = nil; return
            }
            self.pending = nil
            // No suspension between this check and Core's select/begin gate.
            await select(query)
            guard self.active, self.visit == stamp else { return }
            self.running = false; self.task = nil
            guard !Task.isCancelled, isCurrent() else { self.pending = nil; return }
            self.resume(isCurrent: isCurrent, isBusy: isBusy, select: select)
        }
        return task
    }
}

@MainActor struct NativeChannelProgressBoardView: View {
    @Bindable var model: NativeChannelProgressCoordinator
    let board: NativeChannelProgressBoard
    /// Nil means the real team index has not been supplied; IDs are never typed into this screen.
    let teamOptions: [NativeChannelProgressTeamOption]?
    @State private var period = ""
    @State private var completed = "all"
    @State private var teamID: Int64?
    @State private var section = "top"
    @StateObject private var selections = NativeChannelProgressSelectionQueue()
    @StateObject private var actions = NativeChannelProgressActionLifetime()
    private var boardTitle: String {
        let trimmed = board.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    var body: some View {
        List {
            Section {
                Picker(selection: $section) {
                    Text("top", tableName: "NativeChannelProgress").tag("top")
                    Text("d7.channelProgress.detail", tableName: "NativeChannelProgress").tag("detail")
                } label: { Text("d7.channelProgress.boardView", tableName: "NativeChannelProgress") }
                    .cyAdaptiveSegmented().labelsHidden()
                Picker(selection: $period) {
                    ForEach(["ALL","TOPIC","WEEK","MONTH"], id: \.self) { Text(LocalizedStringKey($0), tableName: "NativeChannelProgress").tag($0) }
                } label: { Text("period", tableName: "NativeChannelProgress") }
                if section == "detail" && board.filterSchemaJson["completed"] == "boolean" {
                    Picker(selection: $completed) {
                        Text("all", tableName: "NativeChannelProgress").tag("all")
                        Text("completed", tableName: "NativeChannelProgress").tag("true")
                        Text("inProgress", tableName: "NativeChannelProgress").tag("false")
                    } label: { Text("completionFilter", tableName: "NativeChannelProgress") }
                }
                if section == "detail" && board.filterSchemaJson["team_id"] == "int", model.isCurrent, let teamOptions {
                    Picker(selection: $teamID) {
                        Text("allTeams", tableName: "NativeChannelProgress").tag(Int64?.none)
                        ForEach(teamOptions) { team in Text(verbatim: team.name).tag(Optional(team.id)) }
                    } label: { Text("team", tableName: "NativeChannelProgress") }
                }
                if section == "detail" && board.filterSchemaJson["team_id"] == "int" && teamOptions == nil {
                    Text("teamIndexUnavailable", tableName: "NativeChannelProgress")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text("teamIndexUnavailable", tableName: "NativeChannelProgress"))
                }
            }.disabled(!model.isCurrent)
            if model.busy { NativeChannelProgressLoadingRow() }
            NativeChannelProgressIssueView(model: model, part: section)
            let buffer = section == "detail" ? model.detail : model.top
            if !selections.hasPendingSelection, let page = buffer.page {
                Section {
                    if !page.visible {
                        ContentUnavailableView {
                            Label {
                                Text("d7.channelProgress.hidden", tableName: "NativeChannelProgress")
                                    .accessibilityIdentifier("channelProgress.hidden")
                            } icon: {
                                Image(systemName: "eye.slash")
                            }
                        }
                    } else {
                        if buffer.rows.isEmpty {
                            ContentUnavailableView {
                                Label {
                                    Text("d7.channelProgress.empty", tableName: "NativeChannelProgress")
                                        .accessibilityIdentifier("channelProgress.empty")
                                } icon: {
                                    Image(systemName: "list.number")
                                }
                            }
                        }
                        ForEach(Array(buffer.rows.enumerated()), id: \.offset) { _, row in NativeChannelProgressRowView(row: row) }
                        if page.nextCursor != nil {
                            Button {
                                let detail = section == "detail"
                                actions.run { await model.loadMore(detail: detail) }
                            } label: {
                                Text("more", tableName: "NativeChannelProgress")
                            }
                            .disabled(model.busy)
                            .accessibilityLabel(Text("more", tableName: "NativeChannelProgress"))
                        }
                    }
                } footer: {
                    if let asOf = page.asOf {
                        Text("d7.channelProgress.updated \(NativeChannelProgressDateText.text(asOf))", tableName: "NativeChannelProgress")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let me = page.me {
                    Section {
                        NativeChannelProgressMeCard(row: me)
                    } header: { NativeChannelSectionTitle(key: "d7.channelProgress.me") }
                }
            }
            if !selections.hasPendingSelection, let meter = model.meter {
                NativeChannelProgressMeterSection(meter: meter)
            }
            NativeChannelProgressIssueView(model: model, part: "meter")
            Section {
                NavigationLink { NativeChannelProgressOwnHistoryView(model: model) } label: {
                    Label(NativeChannelProgressCopy.text("d7.channelProgress.historyTitle"), systemImage: "clock")
                }
                .disabled(model.busy || selections.hasPendingSelection)
                .accessibilityIdentifier("channelProgress.historyEntry")
            }
        }
        .navigationTitle(Text(verbatim: boardTitle))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .onAppear {
            actions.activate(); selections.activate()
            if period.isEmpty { period = board.period }
            reload()
        }
        .onDisappear { selections.retire(); actions.retire() }
        .onChange(of: period) { old, new in if !old.isEmpty && old != new { reload() } }
        .onChange(of: completed) { _, _ in reload() }
        .onChange(of: teamID) { _, _ in reload() }
        .onChange(of: model.busy) { _, busy in if !busy { resumeSelection() } }
        .onChange(of: model.isCurrent) { _, current in if !current { selections.retire(); actions.retire() } }
        .refreshable { reload() }
        .toolbar {
            Button { actions.run { await model.checkVersion() } } label: { Image(systemName: "arrow.clockwise") }
                .disabled(model.busy || selections.hasPendingSelection)
                .accessibilityLabel(Text("refresh", tableName: "NativeChannelProgress"))
        }
    }
    private func reload() {
        guard let query = try? NativeChannelProgressQuery(board: board, period: period, completed: completed == "all" ? nil : completed == "true", teamID: teamID) else { return }
        let model = model, board = board
        selections.enqueue(query, isCurrent: { model.isCurrent }, isBusy: { model.busy }) { query in
            await model.select(board, query: query)
        }
    }
    private func resumeSelection() {
        let model = model, board = board
        selections.resume(isCurrent: { model.isCurrent }, isBusy: { model.busy }) { query in
            await model.select(board, query: query)
        }
    }
}

struct NativeChannelProgressRowPresentation {
    let title: String
    let rank: String
    let progress: String?
    let state: String?
    let symbol: String
    let tone: Color
    let stateSymbol: String

    init(_ row: NativeChannelProgressRow) {
        if let name = row.displayName {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            title = trimmed.isEmpty ? "—" : trimmed
        } else {
            title = NativeChannelProgressCopy.text("d7.channelProgress.anonymous")
        }
        switch NativeChannelProgressRank(row) {
        case .known(let rank): self.rank = "#\(rank)"
        case .unranked, .unknown: self.rank = "—"
        }
        progress = Self.progressText(row)
        switch row.state {
        case "UNCONFIRMED":
            state = NativeChannelProgressCopy.text("d7.channelProgress.unconfirmed")
            stateSymbol = "clock"
            tone = .orange
            symbol = "clock"
        case "NO_COMPLETED_EFFORT":
            state = NativeChannelProgressCopy.text("d7.channelProgress.noCompletedEffort")
            stateSymbol = "circle"
            tone = .secondary
            symbol = "circle"
        case "NOT_APPLICABLE":
            state = NativeChannelProgressCopy.text("d7.channelProgress.notApplicable")
            stateSymbol = "minus.circle"
            tone = .blue
            symbol = "minus.circle"
        default:
            state = nil
            stateSymbol = "person"
            tone = .secondary
            symbol = row.subjectType == "TEAM" ? "person.3" : "person"
        }
    }

    var cardMeta: String {
        var parts = [rank]
        if let state { parts.append(state) }
        else if let progress { parts.append(progress) }
        return parts.joined(separator: " · ")
    }

    var spoken: String {
        var parts = [title, rank]
        if let state { parts.append(state) }
        else if let progress { parts.append(progress) }
        return parts.joined(separator: ", ")
    }

    /// Real counts only: done/required and percent, joined when both exist.
    static func progressText(_ row: NativeChannelProgressRow) -> String? {
        var parts: [String] = []
        if let done = row.done, let required = row.required { parts.append("\(done)/\(required)") }
        if let percent = row.percent { parts.append("\(percent)%") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct NativeChannelProgressRowView: View {
    let row: NativeChannelProgressRow
    private var presented: NativeChannelProgressRowPresentation { .init(row) }

    var body: some View {
        LabeledContent {
            Text(verbatim: presented.rank)
                .monospacedDigit()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: presented.title)
                    if let state = presented.state {
                        Label(state, systemImage: presented.stateSymbol)
                            .font(.subheadline)
                            .foregroundStyle(presented.tone)
                    } else if let progress = presented.progress {
                        Text(verbatim: progress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } icon: {
                Image(systemName: presented.symbol)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: presented.spoken))
    }
}

struct NativeChannelProgressMeCard: View {
    let row: NativeChannelProgressRow
    private var presented: NativeChannelProgressRowPresentation { .init(row) }

    var body: some View {
        LabeledContent {
            Text(verbatim: presented.cardMeta)
                .monospacedDigit()
        } label: {
            Label(presented.title, systemImage: presented.symbol)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: presented.spoken))
    }
}

private struct NativeChannelProgressLoadingRow: View {
    var body: some View {
        ProgressView { Text("cy.state.loading") }
            .frame(maxWidth: .infinity)
    }
}

private struct NativeChannelProgressMeterSection: View {
    let meter: NativeChannelProgressMeter

    var body: some View {
        Section {
            if meter.visible, let done = meter.done, let required = meter.required {
                LabeledContent {
                    Text(verbatim: "\(done)/\(required)").accessibilityLabel(Text("a11y.value.ofTotal \(Int(done)) \(Int(required))"))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } label: {
                    Text("completed", tableName: "NativeChannelProgress")
                }
                if let percent = meter.percent {
                    LabeledContent {
                        Text(verbatim: "\(percent)%")
                            .monospacedDigit()
                    } label: {
                        Text("d7.channelProgress.percent", tableName: "NativeChannelProgress")
                    }
                }
            } else {
                Label(NativeChannelProgressCopy.text("d7.channelProgress.hidden"), systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("d7.channelProgress.hidden", tableName: "NativeChannelProgress"))
            }
        } header: { NativeChannelSectionTitle(key: "ownProgress") }
    }
}

/// Server timestamps are ISO 8601; unparseable values are shown as received.
enum NativeChannelProgressDateText {
    static func text(_ raw: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = ISO8601DateFormatter().date(from: raw) ?? fractional.date(from: raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
