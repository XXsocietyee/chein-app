import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - Orient score (subpackageMember/orient-score) — read-only native screen
// Shows the player's own round score, per-dimension breakdown, settlement, ledger timeline and
// appeal/dispute status. Appeals, disputes, sync and settle are NOT offered here: they stay in the
// existing OrientSessionCoordinator flow and this screen never reports a write as done.

@available(macOS 14.0, *)
@MainActor final class OrientScoreModel: ObservableObject {
    @Published private(set) var state: OrientScoreLoadState = .loading
    /// Returns the player's own score, or nil when there is no round to show.
    private let loader: () async throws -> OrientSessionScore?
    private var generation = 0

    init(loader: @escaping () async throws -> OrientSessionScore?) {
        self.loader = loader
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
        do {
            let score = try await loader()
            guard stamp == generation else { return }
            readyFacts = score.map(OrientScorePage.facts(from:))
            state = score.map { .ready(OrientScorePresentation.summary(from: $0)) } ?? .empty
        } catch is CancellationError {
            return
        } catch {
            guard stamp == generation else { return }
            state = OrientScorePresentation.failure(for: error)
        }
    }
}

@available(macOS 14.0, *)
@MainActor struct OrientScoreView: View {
    @StateObject private var model: OrientScoreModel
    /// Mini-program "选择其他对局": shown only when the host can list the player's other rounds (needs logic).
    private let onChooseAnother: (() -> Void)?

    init(model: OrientScoreModel, onChooseAnother: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: model)
        self.onChooseAnother = onChooseAnother
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
        }
        .background(CYColor.bgPage)
        .navigationTitle(Text("orientScore.title"))
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder private var content: some View {
        switch model.page.phase {
        case .loading?, nil:
            CYLoadingState("orientScore.loading", messageIdentifier: "orientScore.loading")
                .frame(maxWidth: .infinity, minHeight: 240)
                .accessibilityIdentifier("orientScore.loading")
        case .empty:
            CYEmptyStateView(
                systemImage: "list.number",
                title: LocalizedStringKey(W8Text.t("没有可查看的本人对局", "No round of yours to show")),
                description: LocalizedStringKey(W8Text.t("参加一场定向后，成绩会显示在这里。", "Scores appear here after you play an orienteering round.")))
                .accessibilityIdentifier("orientScore.empty")
        case .failed(let message, let retryable):
            CYErrorStateView(
                title: LocalizedStringKey(W8Text.t("计分加载失败", "Couldn't load the score")),
                message: LocalizedStringKey(message),
                retryTitle: LocalizedStringKey(W8Text.t("重新读取", "Try again")),
                onRetry: retryable ? { Task { await model.load() } } : nil)
                .accessibilityIdentifier("orientScore.error")
        case .ready(let summary):
            OrientScoreReadyContent(summary: summary)
            // Mini-program footer: "刷新计分" and, when other rounds exist, "选择其他对局".
            VStack(spacing: CYSpacing.xs) {
                Button(W8Text.t("刷新计分", "Refresh score")) { Task { await model.load() } }
                    .font(CYTypography.label)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("orientScore.refresh")
                if let onChooseAnother {
                    Button(W8Text.t("选择其他对局", "Choose another round"), action: onChooseAnother)
                        .font(CYTypography.label)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("orientScore.chooseAnother")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, CYSpacing.md)
        }
    }
}

@available(macOS 14.0, *)
@MainActor struct OrientScoreReadyContent: View {
    let summary: OrientScoreSummary
    /// `OrientScorePage.Facts` for the same score: total, settlement, and timeline numbers (em dash when unknown).
    var facts: OrientScorePage.Facts? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            totalCard
            dimensionsCard
            settlementCard
            timelineCard
            reviewsCard(title: "orientScore.appeals", emptyText: "orientScore.appeals.empty", rows: summary.appeals)
            reviewsCard(title: "orientScore.disputes", emptyText: "orientScore.disputes.empty", rows: summary.disputes)
            CYCard(variant: .subtle, radius: CYRadius.sm, padding: CYSpacing.md) {
                Text("orientScore.readOnly")
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var totalCard: some View {
        CYCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(summary.phase).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                Text(verbatim: facts?.totalText ?? summary.total)
                    .font(CYTypography.data2XL)
                    .contentTransition(.numericText())
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityLabel(summary.totalAccessibility)
                Text(W8Text.t("对局 \(summary.sessionID)", "Round \(summary.sessionID)")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                Text(W8Text.t("计分精确到 0.01 分；积分与探索值以结算结果为准。", "Scores are exact to 0.01. Points and explore XP follow the settlement result."))
                    .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityIdentifier("orientScore.total")
    }

    private var dimensionsCard: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("orientScore.breakdown").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                ForEach(summary.dimensions) { row in
                    HStack {
                        Text(row.label).font(CYTypography.bodyMedium)
                        Spacer(minLength: CYSpacing.md)
                        Text(row.value).font(CYTypography.bodyMedium.monospacedDigit())
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
                Text(W8Text.t("结算结果", "Settlement")).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                if let settlement = summary.settlement {
                    Text(W8Text.t("本局已结算 · \(settlement.total)", "Settled · \(settlement.total)")).font(CYTypography.bodyMedium)
                    Text(W8Text.t("积分 \(settlement.points) · 探索值 \(settlement.xp)", "Points \(settlement.points) · Explore XP \(settlement.xp)"))
                        .font(CYTypography.bodyCompact)
                    Text(W8Text.t("结算编号 \(settlement.settlementID)", "Settlement \(settlement.settlementID)"))
                        .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    Text(W8Text.t("结算后冲正只影响展示分，不追发或追扣本局奖励。", "Corrections after settlement change only the shown score; this round's rewards are not re-issued or clawed back."))
                        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(summary.settlementNotice).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(CYColor.textPrimary)
        }
    }

    private var timelineCard: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("orientScore.timeline").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                if summary.timeline.isEmpty {
                    Text("orientScore.timeline.empty").font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                ForEach(summary.timeline) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        HStack {
                            Text(row.dimension).font(CYTypography.bodyMedium)
                            Spacer(minLength: CYSpacing.md)
                            Text(row.delta).font(CYTypography.bodyMedium.monospacedDigit())
                        }
                        Text("orientScore.running \(runningText(row))").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        if !row.reason.isEmpty { Text(row.reason).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                        Text(row.nodeID.map { W8Text.t("流水 \(row.entryID) · 节点 \($0)", "Entry \(row.entryID) · node \($0)") } ?? W8Text.t("流水 \(row.entryID)", "Entry \(row.entryID)"))
                            .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        if let reversed = row.reversesEntryID {
                            Text("orientScore.reverses \(String(reversed))").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        }
                        if row.appealPending {
                            Text("orientScore.appealPending").font(CYTypography.meta).foregroundStyle(CYColor.warningText)
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
                Text(title).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                if rows.isEmpty {
                    Text(emptyText).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(row.statusText).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                        Text(row.reason).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        if let note = row.note {
                            Text("orientScore.resolution \(note)").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Binding stub for Cursor: composition that can read this player's own round score for a topic/activity
/// (`OrientSessionService.current` to pick the session, then `.score`). Nothing conforms yet, so the entry
/// below stays hidden (capability absent => hidden). It never syncs, settles, appeals, or disputes.
@MainActor protocol OrientScoreEntryProviding {
    /// Nil hides the entry. The loader returns nil when the player has no round of their own here.
    func orientScoreLoader(topicID: Int, activityID: Int) -> (() async throws -> OrientSessionScore?)?
}

/// subpackageMember/orient-score entry from the participation/activity detail (source `participation-result-entry`).
@available(macOS 14.0, *)
@MainActor struct OrientScoreEntryLink: View {
    let loader: () async throws -> OrientSessionScore?
    var body: some View {
        Section {
            NavigationLink { OrientScoreView(model: OrientScoreModel(loader: loader)) } label: {
                CYListRow("orientScore.title", trailing: .none) { CYRowIcon(systemImage: "list.number") }
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
