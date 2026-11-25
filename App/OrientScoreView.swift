import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - Orient score (subpackageMember/orient-score) — read-only native screen
// Shows the player's own round score, per-dimension breakdown, settlement, ledger timeline and
// appeal/dispute status. Appeal and dispute are offered only when the reports grant supplies a
// submitter. Sync, settle, purchase, and payout are not offered here. An unknown write stays an em dash.

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

    init(model: OrientScoreModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainScreen(.game)
        .cyPushedChrome(domain: .game)
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
        .sheet(isPresented: $showsSignIn, onDismiss: { Task { await model.load() } }) {
            if let orientScoreSession { LoginView(intent: .player).environmentObject(orientScoreSession) }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @State private var showsSignIn = false

    @ViewBuilder private var content: some View {
        switch model.page.phase {
        case .loading?, nil:
            CYLoadingState("orientScore.loading", messageIdentifier: "orientScore.loading")
                .frame(maxWidth: .infinity, minHeight: 240)
        case .empty?:
            if let rounds = model.choices, !rounds.isEmpty {
                OrientScoreRoundChooser(rounds: rounds) { id in Task { await model.choose(id) } }
            } else {
                CYEmptyState(systemImage: "list.number", "orientScore.empty.title", detail: "orientScore.empty.detail",
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
                OrientScoreReadyContent(summary: summary, facts: facts, score: model.loadedScore, session: orientScoreSession)
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
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            totalCard
            dimensionsCard
            settlementCard
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
        CYCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(summary.phase).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                Text(verbatim: facts?.totalText ?? summary.total)
                    .cyText(.data2XL)
                    .contentTransition(.numericText())
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityLabel(summary.totalAccessibility)
                // Source: 对局 {{score.sessionId}}.
                Text("orientScore.session \(String(facts?.sessionID ?? summary.sessionID))")
                    .cyText(.meta).foregroundStyle(CYColor.textTertiary)
                Text("orientScore.precision")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityIdentifier("orientScore.total")
    }

    private var dimensionsCard: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("orientScore.breakdown").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                ForEach(summary.dimensions) { row in
                    HStack {
                        Text(row.label).cyText(.bodyMedium)
                        Spacer(minLength: CYSpacing.md)
                        Text(row.value).cyText(.bodyMedium, monospacedDigit: true)
                    }
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var settlementCard: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("orientScore.settlement").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                switch facts?.settlement {
                case .settled(let total, let points, let xp)?:
                    Text("orientScore.settled \(total)").cyText(.bodyMedium)
                    Text("orientScore.rewards \(points) \(xp)").cyText(.bodyCompact)
                case .unknown?:
                    Text(verbatim: OrientScorePage.unknownDisplay).cyText(.bodyMedium)
                case .absent?:
                    EmptyView()
                case nil:
                    if let settlement = summary.settlement {
                        Text("orientScore.settled \(settlement.total)").cyText(.bodyMedium)
                        Text("orientScore.rewards \(String(settlement.points)) \(String(settlement.xp))").cyText(.bodyCompact)
                    }
                }
                Text(summary.settlementNotice).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(CYColor.textPrimary)
        }
    }

    /// MP orient-score wxml:52-64 本场榜单: 看本场榜单 (榜单加载中 while reading), the retry line on failure.
    private var boardCard: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("orientScore.board.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                Button { Task { await loadBoard() } } label: {
                    Text(LocalizedStringKey(boardLoading ? "orientScore.board.loading" : "orientScore.board.open"))
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.cySecondary(fullWidth: true))
                .disabled(boardLoading)
                .accessibilityIdentifier("orientScore.board.open")
                if boardFailed {
                    Text("orientScore.board.failed").cyText(.meta).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("orientScore.board.failed")
                }
            }
        }
        .sheet(item: $board) { content in
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
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("orientScore.timeline").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if summary.timeline.isEmpty {
                    Text("orientScore.timeline.empty").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                ForEach(summary.timeline) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        HStack {
                            Text(row.dimension).cyText(.bodyMedium)
                            Spacer(minLength: CYSpacing.md)
                            Text(row.delta).cyText(.bodyMedium, monospacedDigit: true)
                        }
                        Text("orientScore.running \(runningText(row))").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        if !row.reason.isEmpty { Text(row.reason).cyText(.meta).foregroundStyle(CYColor.textTertiary) }
                        if let reversed = row.reversesEntryID {
                            Text("orientScore.reverses \(String(reversed))").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        }
                        if row.appealPending {
                            Text("orientScore.appealPending").cyText(.meta).foregroundStyle(CYColor.warningText)
                        }
                    }
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: row.accessibilitySummary) + (row.appealPending ? Text("orientScore.appealPending.spoken") : Text(verbatim: "")))
                }
            }
        }
    }

    /// Running total from the page facts when present; a missing running total is an em dash, never summed from the delta.
    private func runningText(_ row: OrientScoreTimelineRow) -> String {
        guard let facts else { return row.running }
        return facts.timeline.first(where: { $0.entryID == row.entryID })?.runningText ?? OrientScorePage.unknownDisplay
    }

    private func reviewsCard(title: LocalizedStringKey, emptyText: LocalizedStringKey, rows: [OrientScoreReviewRow]) -> some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if rows.isEmpty {
                    Text(emptyText).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(row.statusText).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                        Text(row.reason).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        if let note = row.note {
                            Text("orientScore.resolution \(note)").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}


/// Mini-program `state === 'choosing'`: the player's own current rounds, each with 「查看此局计分」 (PLY-25-1).
@available(macOS 14.0, *)
@MainActor struct OrientScoreRoundChooser: View {
    let rounds: [OrientSessionView]
    let onChoose: (Int) -> Void

    var body: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("orientScore.choose.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                ForEach(rounds, id: \.sessionID) { round in
                    HStack(alignment: .center, spacing: CYSpacing.md) {
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(phaseKey(round.phase)).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                            Text("orientScore.choose.round \(String(round.sessionID))").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                            if let started = round.startedAt {
                                Text(Date(timeIntervalSince1970: TimeInterval(started) / 1000), format: .dateTime.month().day().hour().minute())
                                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        Spacer(minLength: CYSpacing.sm)
                        CYPillButton("orientScore.choose.view", style: .secondary, fullWidth: false, compact: true) { onChoose(round.sessionID) }
                            .accessibilityIdentifier("orientScore.choose.\(round.sessionID)")
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
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
            CYEmptyState(systemImage: "list.number", "orientScore.empty.title", detail: "orientScore.empty.detail",
                         messageIdentifier: "orientScore.empty")
                .cyDomainScreen(.game)
                .cyPushedChrome(domain: .game)
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
                CYListRow("orientScore.entry", trailing: .none) { CYRowIcon(systemImage: "list.number") }
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
