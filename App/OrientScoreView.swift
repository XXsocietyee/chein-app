import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - Orient score (subpackageMember/orient-score) — read-only native screen
// Shows the player's own round score, per-dimension breakdown, settlement, ledger timeline and
// appeal/dispute status. Appeal and dispute are offered only when the reports grant supplies a
// submitter. PLY-25-2: sync and settle follow the MP (`OrientScoreSettlementControls.swift`).
// Purchase and payout are not offered here. An unknown write stays an em dash.

@available(macOS 14.0, *)
@MainActor final class OrientScoreModel: ObservableObject {
    @Published private(set) var state: OrientScoreLoadState = .loading
    @Published private(set) var loadedScore: OrientSessionScore?
    /// The player's own current rounds when there is more than one and none is chosen (mini-program chooser).
    @Published private(set) var choices: [OrientSessionView]?
    /// True after the read was refused for lack of a signed-in owner (mini-program no-permission state).
    @Published private(set) var needsSignIn = false
    /// More than one round was listed, so 「选择其他对局」 is offered on a loaded score.
    @Published private(set) var canChooseOther = false
    /// Returns the chosen round's score, the rounds to choose from, or nothing.
    private let loader: (Int?) async throws -> OrientScoreLoad
    private var chosenSessionID: Int?
    private var generation = 0

    init(loader: @escaping () async throws -> OrientSessionScore?) {
        self.loader = { _ in try await loader().map(OrientScoreLoad.score) ?? .none }
    }

    /// PLY-25-1: several current rounds become a choice instead of a false empty.
    /// `initialSessionID` is the mini-program `sessionId` query: it skips the chooser when the server lists that round.
    init(rounds: @escaping (Int?) async throws -> OrientScoreLoad, initialSessionID: Int? = nil) {
        self.loader = rounds
        self.chosenSessionID = initialSessionID
    }

    func choose(_ sessionID: Int) async {
        chosenSessionID = sessionID
        canChooseOther = true
        await load()
    }

    func chooseAnother() async {
        chosenSessionID = nil
        await load()
    }

    /// `OrientScorePage` over the same state: capability present, so nothing here is hidden. Unknown numbers are an em dash.
    var page: OrientScorePage {
        switch state {
        case .loading: return .bind(clientCapabilityPresent: true, loading: true)
        case .empty: return .bind(clientCapabilityPresent: true, roundPresent: false)
        case .failed: return .bind(clientCapabilityPresent: true, failed: true)
        case .ready: return OrientScorePage(clientCapabilityPresent: true, serverFactPresent: true, phase: readyFacts.map { OrientScorePage.Phase.ready($0) } ?? .unknown)
        }
    }
    private var readyFacts: OrientScorePage.Facts?

    func load() async {
        generation += 1
        let stamp = generation
        state = .loading
        loadedScore = nil
        choices = nil
        needsSignIn = false
        do {
            let result = try await loader(chosenSessionID)
            guard stamp == generation else { return }
            switch result {
            case .score(let score):
                loadedScore = score
                readyFacts = OrientScorePage.facts(from: score)
                state = .ready(OrientScorePresentation.summary(from: score))
            case .choose(let rounds):
                chosenSessionID = nil
                canChooseOther = true
                choices = rounds
                readyFacts = nil
                state = .empty
            case .none:
                readyFacts = nil
                state = .empty
            }
        } catch is CancellationError {
            return
        } catch {
            guard stamp == generation else { return }
            needsSignIn = (error as? APIError) == .unauthorized || (error as? OrientSessionFailure)?.isUnauthorized == true
            state = OrientScorePresentation.failure(for: error)
        }
    }
}

@available(macOS 14.0, *)
@MainActor struct OrientScoreView: View {
    @StateObject private var model: OrientScoreModel
    @Environment(\.orientScoreSession) private var orientScoreSession
    /// PLY-25-2: lives above the ready content so a pending write survives a reload.
    @StateObject private var settlement = OrientScoreSettlementModel()

    init(model: OrientScoreModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        // NAT-10 (native-r2): an inset-grouped List; each MP card is a Section.
        List {
            content
        }
        .listStyle(.insetGrouped)
        // N-ORIENT (r10): MP subpackageMember/orient-score is a normal member page, not a game stage;
        // the score list follows system Light/Dark under the player domain (same rule as N-PLAY-DARK).
        .cyDomainScreen(.player)
        .cyPushedChrome(domain: .player)
        .cyPageTitle("orientScore.title")
        .toolbar {
            // Mini-program 「选择其他对局」: only when this player has more than one round here.
            if model.canChooseOther, model.loadedScore != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("orientScore.choose.other") { Task { await model.chooseAnother() } }
                        .accessibilityIdentifier("orientScore.chooseOther")
                }
            }
        }
        .cySheet(isPresented: $showsSignIn, onDismiss: { Task { await model.load() } }) {
            if let orientScoreSession { LoginView(intent: .player).environmentObject(orientScoreSession) }
        }
        .task {
            let reader = model
            settlement.reload = { [weak reader] in await reader?.load() }
            await model.load()
        }
        .refreshable { await model.load() }
        .onChange(of: model.loadedScore) { _, score in
            settlement.attach(session: orientScoreSession, score: score)
        }
    }

    @State private var showsSignIn = false

    @ViewBuilder private var content: some View {
        switch model.page.phase {
        case .loading?, nil:
            ProgressView { Text("orientScore.loading") }
                .frame(maxWidth: .infinity, minHeight: 240)
                .accessibilityIdentifier("orientScore.loading")
        case .empty?:
            if let rounds = model.choices, !rounds.isEmpty {
                OrientScoreRoundChooser(rounds: rounds) { id in Task { await model.choose(id) } }
            } else {
                CYEmptyState(systemImage: "tray", "orientScore.empty.title", detail: "orientScore.empty.detail",
                             messageIdentifier: "orientScore.empty")
            }
        case .error?:
            if model.needsSignIn {
                // PLY-25-6: mini-program no-permission state 「请登录本人账号查看对局」 with a way to sign in.
                CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "orientScore.signIn.title",
                             messageIdentifier: "orientScore.signIn",
                             actionTitle: orientScoreSession == nil ? nil : "orientScore.signIn.action",
                             actionIdentifier: "orientScore.signIn.action") { showsSignIn = true }
            } else if case .failed(let message, let retryable) = model.state {
                CYEmptyState(systemImage: "exclamationmark.triangle", "orientScore.error.title",
                             detailVerbatim: message, messageIdentifier: "orientScore.error",
                             actionTitle: retryable ? "orientScore.error.retry" : nil, actionIdentifier: "orientScore.retry",
                             kind: .failure) { Task { await model.load() } }
            }
        case .unknown?:
            CYEmptyState(systemImage: "questionmark.circle", "orientScore.error.title", detailVerbatim: OrientScorePage.unknownDisplay,
                         messageIdentifier: "orientScore.unknown", actionTitle: "orientScore.error.retry",
                         actionIdentifier: "orientScore.retry") { Task { await model.load() } }
        case .ready(let facts)?:
            if case .ready(let summary) = model.state {
                OrientScoreReadyContent(summary: summary, facts: facts, score: model.loadedScore, session: orientScoreSession,
                                        settlement: settlement)
            }
        }
    }
}

@available(macOS 14.0, *)
@MainActor struct OrientScoreReadyContent: View {
    let summary: OrientScoreSummary
    /// `OrientScorePage.Facts` for the same score: total, settlement, and timeline numbers (em dash when unknown).
    var facts: OrientScorePage.Facts? = nil
    var score: OrientSessionScore? = nil
    var session: AppSession? = nil
    /// PLY-25-2: sync / settle / receipt (MP orient-score). Nil in fixtures.
    var settlement: OrientScoreSettlementModel? = nil
    @Environment(\.locale) private var locale
    /// PLY-25-3: MP `boardState` ('' / loading / error); a loaded board is shown in the sheet.
    @State private var boardLoading = false
    @State private var boardFailed = false
    @State private var board: OrientScoreBoardSheetContent?

    private var reviewSubmitter: (submitter: OrientScoreReviewModel.Submitter, makeKey: () -> String)? {
        guard let score, let session else { return nil }
        return OrientScoreReviewFactory.makeSubmitter(OrientScoreReviewContext(session: session, score: score, entryID: { nil }))
    }

    var body: some View {
        Group {
            totalCard
            dimensionsCard
            if let settlement { OrientScoreSettlementPendingCard(model: settlement) }
            settlementCard
            if !summary.recoveries.isEmpty { recoveriesCard }
            if session != nil, score != nil { boardCard }
            timelineCard
            reviewsCard(title: "orientScore.appeals", emptyText: "orientScore.appeals.empty", rows: summary.appeals)
            reviewsCard(title: "orientScore.disputes", emptyText: "orientScore.disputes.empty", rows: summary.disputes)
            // X11: no read-only boundary note for players; the form appears only when a submitter exists.
            if let score, let session, reviewSubmitter != nil {
                OrientScoreReviewSection(session: session, score: score, entries: summary.timeline)
            }
        }
    }

    private var totalCard: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                // Round 4: MP head line 「本局计分 · {phase}」 (orient-score wxml:20); no session id (PG-090).
                Text("orientScore.titlePhase \(summary.phase)").font(.footnote).foregroundStyle(.secondary)
                Text(verbatim: facts?.totalText ?? summary.total)
                    .font(.largeTitle.weight(.bold)).monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel(summary.totalAccessibility)
                Text("orientScore.precision")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("orientScore.total")
        }
    }

    private var dimensionsCard: some View {
        Section("orientScore.breakdown") {
            ForEach(summary.dimensions) { row in
                LabeledContent {
                    Text(row.value).monospacedDigit()
                } label: {
                    Text(row.label)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var settlementCard: some View {
        Section("orientScore.settlement") {
            VStack(alignment: .leading, spacing: 4) {
                switch facts?.settlement {
                case .settled(let total, let points, let xp)?:
                    Text("orientScore.settled \(total)").font(.body.weight(.medium))
                    Text("orientScore.rewards \(points) \(xp)").font(.subheadline)
                case .unknown?:
                    Text(verbatim: OrientScorePage.unknownDisplay).font(.body.weight(.medium))
                case .absent?:
                    EmptyView()
                case nil:
                    if let settlement = summary.settlement {
                        Text("orientScore.settled \(settlement.total)").font(.body.weight(.medium))
                        Text("orientScore.rewards \(String(settlement.points)) \(String(settlement.xp))").font(.subheadline)
                    }
                }
                Text(summary.settlementNotice).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let settlement { OrientScoreSettlementActions(model: settlement) }
            }
        }
    }

    /// MP `score.recoveries`: 历史操作人工核对. Shown only when the server sent rows.
    private var recoveriesCard: some View {
        Section("orientScore.recoveries.title") {
            ForEach(summary.recoveries) { row in
                VStack(alignment: .leading, spacing: 2) {
                    (Text(LocalizedStringKey(recoveryKind(row.kind)))
                        + Text(verbatim: " · ")
                        + Text(LocalizedStringKey(row.status == 0 ? "orientScore.recoveries.pending" : "orientScore.recoveries.noted")))
                    if !row.note.isEmpty {
                        Text("orientScore.recoveries.note \(row.note)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("orientScore.recoveries")
            }
        }
    }

    private func recoveryKind(_ kind: String) -> String {
        switch kind {
        case "SYNC": return "orientScore.kind.sync"
        case "SETTLE": return "orientScore.kind.settle"
        case "APPEAL": return "orientScore.review.appeal"
        case "DISPUTE": return "orientScore.review.dispute"
        default: return "orientScore.recoveries.kindFallback"
        }
    }

    /// MP orient-score wxml:52-64 本场榜单: 看本场榜单 (榜单加载中 while reading), the retry line on failure.
    private var boardCard: some View {
        Section("orientScore.board.title") {
            Button { Task { await loadBoard() } } label: {
                Text(LocalizedStringKey(boardLoading ? "orientScore.board.loading" : "orientScore.board.open"))
            }
            .disabled(boardLoading)
            .accessibilityIdentifier("orientScore.board.open")
            if boardFailed {
                Text("orientScore.board.failed").font(.footnote).foregroundStyle(.red)
                    .accessibilityIdentifier("orientScore.board.failed")
            }
        }
        .cySheet(item: $board) { content in
            OrientScoreLeaderboardSheetView(rows: content.rows, myRow: content.me, onClose: { board = nil })
        }
    }

    private func loadBoard() async {
        guard !boardLoading, let session, let score, let read = OrientScoreBoardRead.make(session: session) else {
            boardFailed = true; return
        }
        boardLoading = true; boardFailed = false
        defer { boardLoading = false }
        do {
            let value = try await read(score.sessionID)
            guard !Task.isCancelled, value.sessionID == score.sessionID else { return }
            board = OrientScoreBoardRead.content(value, locale: locale)
        } catch is CancellationError {
            return
        } catch {
            boardFailed = true
        }
    }

    private var timelineCard: some View {
        Section("orientScore.timeline") {
            if summary.timeline.isEmpty {
                ContentUnavailableView("orientScore.timeline.empty", systemImage: "clock")
            }
            ForEach(summary.timeline) { row in
                VStack(alignment: .leading, spacing: 2) {
                    LabeledContent {
                        Text(row.delta).monospacedDigit()
                    } label: {
                        Text(row.dimension)
                    }
                    Text("orientScore.running \(runningText(row))").font(.footnote).foregroundStyle(.secondary)
                    if !row.reason.isEmpty { Text(row.reason).font(.footnote).foregroundStyle(.secondary) }
                    // Round 4: MP shows 已撤销 (orient-score wxml:72), never the reversed entry id (PG-090).
                    if row.reversesEntryID != nil {
                        Text("orientScore.reversed").font(.footnote).foregroundStyle(.secondary)
                    }
                    if row.appealPending {
                        // Contrast (a11y-dt r3): orange footnote text is about 2:1; the glyph carries the colour.
                        Label {
                            Text("orientScore.appealPending").foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "hourglass").foregroundStyle(.orange)
                        }
                        .font(.footnote)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: row.accessibilitySummary) + (row.appealPending ? Text("orientScore.appealPending.spoken") : Text(verbatim: "")))
            }
        }
    }

    /// Running total from the page facts when present; a missing running total is an em dash, never summed from the delta.
    private func runningText(_ row: OrientScoreTimelineRow) -> String {
        guard let facts else { return row.running }
        return facts.timeline.first(where: { $0.entryID == row.entryID })?.runningText ?? OrientScorePage.unknownDisplay
    }

    private func reviewsCard(title: LocalizedStringKey, emptyText: LocalizedStringKey, rows: [OrientScoreReviewRow]) -> some View {
        Section {
            if rows.isEmpty {
                Text(emptyText).foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.statusText).font(.body.weight(.medium))
                    Text(row.reason).font(.subheadline).foregroundStyle(.secondary)
                    if let note = row.note {
                        Text("orientScore.resolution \(note)").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(title)
        }
    }
}


/// Mini-program `state === 'choosing'`: the player's own current rounds, each with 「查看此局计分」 (PLY-25-1).
@available(macOS 14.0, *)
@MainActor struct OrientScoreRoundChooser: View {
    let rounds: [OrientSessionView]
    let onChoose: (Int) -> Void

    var body: some View {
        Section("orientScore.choose.title") {
            ForEach(rounds, id: \.sessionID) { round in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phaseKey(round.phase))
                        if let started = round.startedAt {
                            Text(Date(timeIntervalSince1970: TimeInterval(started) / 1000), format: .dateTime.month().day().hour().minute())
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 8)
                    Button("orientScore.choose.view") { onChoose(round.sessionID) }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("orientScore.choose.\(round.sessionID)")
                }
            }
        }
        .accessibilityIdentifier("orientScore.chooser")
    }

    private func phaseKey(_ phase: OrientSessionPhase) -> LocalizedStringKey {
        switch phase {
        case .prepared, .running: return "orientScore.phase.progress"
        case .disqualified: return "orientScore.phase.disqualified"
        case .finished, .abandoned: return "orientScore.phase.ended"
        }
    }
}

/// `subpackageMember/orient-score/index?topicId=&activityId=&sessionId=` for the page router. A missing provider
/// (no regional configuration) shows the same empty state as a round-less player.
@available(macOS 14.0, *)
@MainActor struct OrientScoreDeepLinkScreen: View {
    let session: AppSession
    let topicID: Int
    var activityID: Int = 0
    var sessionID: Int? = nil

    var body: some View {
        if let rounds = session.orientScoreRoundsLoader(topicID: topicID, activityID: activityID) {
            OrientScoreView(model: OrientScoreModel(rounds: rounds, initialSessionID: sessionID))
                .environment(\.orientScoreSession, session)
        } else {
            CYEmptyState(systemImage: "tray", "orientScore.empty.title", detail: "orientScore.empty.detail",
                         messageIdentifier: "orientScore.empty")
                .cyDomainScreen(.player)
                .cyPushedChrome(domain: .player)
                .cyPageTitle("orientScore.title")
        }
    }
}

/// subpackageMember/orient-score entry from the participation/activity detail (source `participation-result-entry`).
@available(macOS 14.0, *)
@MainActor struct OrientScoreEntryLink: View {
    let rounds: (Int?) async throws -> OrientScoreLoad
    var session: AppSession? = nil
    var body: some View {
        Section {
            NavigationLink {
                OrientScoreView(model: OrientScoreModel(rounds: rounds))
                    .environment(\.orientScoreSession, session)
            } label: {
                // PLY-25-7: one entry label, mini-program 「定向成绩」.
                Label("orientScore.entry", systemImage: "list.number")
            }
            .accessibilityIdentifier("activity.openOrientScore")
        }
    }
}

#if DEBUG
@available(macOS 14.0, *)
private enum OrientScoreFixtures {
    static let score: OrientSessionScore = {
        let json = "{\"sessionId\":9,\"topicId\":3,\"activityId\":0,\"status\":1,\"totalCenti\":1700,"
            + "\"byDimension\":{\"TASK\":2000,\"PUZZLE\":0,\"BONUS\":0,\"PENALTY\":-300,\"ADJUSTMENT\":0},"
            + "\"timeline\":[{\"entryId\":30,\"dimension\":\"TASK\",\"deltaCenti\":2000,\"runningCenti\":2000,\"reasonCode\":\"TASK_DONE\"},"
            + "{\"entryId\":31,\"dimension\":\"PENALTY\",\"deltaCenti\":-300,\"runningCenti\":1700,\"reasonCode\":\"LATE\"}],"
            + "\"settlement\":null,\"appeals\":[],\"disputes\":[]}"
        return try! JSONDecoder().decode(OrientSessionScore.self, from: Data(json.utf8))
    }()
}

@available(macOS 14.0, *)
private struct PreviewFailure: Error {}

#Preview("Orient score · ready") {
    NavigationStack { OrientScoreView(model: OrientScoreModel(loader: { OrientScoreFixtures.score })) }
}
#Preview("Orient score · empty") {
    NavigationStack { OrientScoreView(model: OrientScoreModel(loader: { nil })) }
}
#Preview("Orient score · error") {
    NavigationStack { OrientScoreView(model: OrientScoreModel(loader: { throw PreviewFailure() })) }
}
#endif

/// PLY-25-3: rows for `OrientScoreLeaderboardSheetView`.
struct OrientScoreBoardSheetContent: Identifiable {
    let id: Int
    let rows: [OrientScoreLeaderboardItem]
    let me: OrientScoreLeaderboardItem?
}

/// PLY-25-3: `GET /api/orient/scoring/session/{id}/leaderboard` on the same c6 service and live session token as the
/// score read (`CloudB3SessionBridge.orientLoader`). Read only.
@MainActor enum OrientScoreBoardRead {
    static func make(session: AppSession) -> ((Int) async throws -> OrientSessionLeaderboard)? {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { return nil }
        let service = OrientSessionService(configuration: configuration, transport: session.runtimeHTTPTransport, contract: .currentC6)
        let access = session.squareGovernanceAccess()
        return { sessionID in
            guard let token = access.token, AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
            return try await service.leaderboard(sessionID: sessionID, token: token)
        }
    }

    /// MP orient-score-view.js `leaderboard`: ROUTE mode shows 已到结局 / 未到结局, SCORE mode the two-decimal score;
    /// elapsed is `N 毫秒`, or 用时待确认 when the server has none.
    static func content(_ board: OrientSessionLeaderboard, locale: Locale) -> OrientScoreBoardSheetContent {
        func item(_ row: OrientSessionLeaderboard.Row) -> OrientScoreLeaderboardItem {
            let score: String
            if board.mode == .route {
                score = row.reachedEnding ? appLocalized("orientScore.board.reached", locale: locale)
                    : appLocalized("orientScore.board.notReached", locale: locale)
            } else {
                score = OrientScoreFormat.centi(row.scoreCenti)
            }
            let elapsed = row.elapsedMs.map { appLocalized("orientScore.board.elapsedMs \($0)", locale: locale) }
                ?? appLocalized("orientScore.board.elapsedUnknown", locale: locale)
            return OrientScoreLeaderboardItem(id: row.rowKey, rank: row.rank, isMine: row.mine, scoreText: score, elapsedText: elapsed)
        }
        return OrientScoreBoardSheetContent(id: board.sessionID, rows: board.list.map(item), me: board.me.map(item))
    }
}
