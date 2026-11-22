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
        loadedScore = nil
        do {
            let score = try await loader()
            guard stamp == generation else { return }
            loadedScore = score
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
        .cyHideTabBar(true)
        .cyPageTitle("orientScore.title")
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder private var content: some View {
        switch model.page.phase {
        case .loading?, nil:
            CYLoadingState("orientScore.loading", messageIdentifier: "orientScore.loading")
                .frame(maxWidth: .infinity, minHeight: 240)
        case .empty?:
            CYEmptyState(systemImage: "list.number", "orientScore.empty.title", detail: "orientScore.empty.detail",
                         messageIdentifier: "orientScore.empty")
        case .error?:
            if case .failed(let message, let retryable) = model.state {
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

    private var reviewSubmitter: (submitter: OrientScoreReviewModel.Submitter, makeKey: () -> String)? {
        guard let score, let session else { return nil }
        return OrientScoreReviewFactory.makeSubmitter(OrientScoreReviewContext(session: session, score: score, entryID: { nil }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            totalCard
            dimensionsCard
            settlementCard
            timelineCard
            reviewsCard(title: "orientScore.appeals", emptyText: "orientScore.appeals.empty", rows: summary.appeals)
            reviewsCard(title: "orientScore.disputes", emptyText: "orientScore.disputes.empty", rows: summary.disputes)
            if let score, let session, reviewSubmitter != nil {
                OrientScoreReviewSection(session: session, score: score, entries: summary.timeline)
            } else {
                CYCard(variant: .subtle, radius: CYRadius.sm, padding: CYSpacing.md) {
                    Text("orientScore.readOnly")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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


/// subpackageMember/orient-score entry from the participation/activity detail (source `participation-result-entry`).
@available(macOS 14.0, *)
@MainActor struct OrientScoreEntryLink: View {
    let loader: () async throws -> OrientSessionScore?
    var session: AppSession? = nil
    var body: some View {
        Section {
            NavigationLink {
                OrientScoreView(model: OrientScoreModel(loader: loader))
                    .environment(\.orientScoreSession, session)
            } label: {
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
