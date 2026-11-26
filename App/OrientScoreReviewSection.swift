import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

private struct OrientScoreSessionKey: EnvironmentKey {
    static let defaultValue: AppSession? = nil
}

extension EnvironmentValues {
    /// Signed-in session for the orient score appeal / dispute form. Nil keeps the form hidden.
    var orientScoreSession: AppSession? {
        get { self[OrientScoreSessionKey.self] }
        set { self[OrientScoreSessionKey.self] = newValue }
    }
}

/// Seam for the orient score appeal/dispute submitter. Nil until the reports grant
/// includes `/api/orient/scoring/appeal` and `/api/orient/scoring/dispute`.
@MainActor enum OrientScoreReviewFactory {
    static var makeSubmitter: (OrientScoreReviewContext) -> (submitter: OrientScoreReviewModel.Submitter, makeKey: () -> String)? = { context in
        OrientScoreReviewProduction.make(context)
    }
}

@MainActor final class OrientScoreReviewEntrySelection: ObservableObject {
    @Published var entryID: Int?
    /// PLY-25-5: MP 申诉漏记任务 node id (only when no ledger row is chosen).
    @Published var nodeID: Int?
}

/// PLY-25-5: which MP review sheet is open (row appeal, 漏记任务 appeal, or dispute).
struct OrientScoreReviewSheetTarget: Identifiable, Equatable {
    let kind: OrientReviewSheetKind
    let entryID: Int?
    var id: String { "\(kind.rawValue)-\(entryID ?? 0)" }
}

/// Appeal / dispute form with an explicit confirm step. Attach under `OrientScoreReadyContent`
/// only when `makeSubmitter` returns a submitter. Sync and settle are not on this form.
@MainActor struct OrientScoreReviewSection: View {
    @StateObject private var model: OrientScoreReviewModel
    @StateObject private var selection: OrientScoreReviewEntrySelection
    private let entries: [OrientScoreTimelineRow]
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    private let canDispute: Bool
    private let disputeDeadline: String?
    @State private var sheet: OrientScoreReviewSheetTarget?
    /// Filled by the sheet's 提交; validated into the confirm step once the sheet is gone.
    @State private var pendingReview: (kind: OrientScoreReviewModel.Kind, reason: String)?

    init(session: AppSession, score: OrientSessionScore, entries: [OrientScoreTimelineRow]) {
        let selection = OrientScoreReviewEntrySelection()
        self.entries = entries
        // PLY-25-5: status 1 or 2, a deadline, and no dispute still in status 0. Sync and settle stay off.
        canDispute = score.canDispute
        disputeDeadline = score.disputeWindowDeadline
        _selection = StateObject(wrappedValue: selection)
        let built = OrientScoreReviewFactory.makeSubmitter(OrientScoreReviewContext(
            session: session, score: score, entryID: { selection.entryID }, nodeID: { selection.nodeID }))
        _model = StateObject(wrappedValue: OrientScoreReviewModel(
            submitter: built?.submitter, makeKey: built?.makeKey ?? { UUID().uuidString }))
    }

    private var busy: Bool {
        switch model.state {
        case .submitting, .awaitingConfirmation: return true
        default: return false
        }
    }

    /// MP orient-score wxml:73-113: 申诉这一条 per ledger row (not while that row's appeal is pending), 申诉漏记任务,
    /// and the 成绩争议 entry; each opens the review sheet (reason up to 500, 节点编号 for a missed task).
    var body: some View {
        // NAT-10 (native-r2): a list Section, not a card.
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                let appealable = entries.filter { !$0.appealPending }
                if !appealable.isEmpty {
                    Menu {
                        ForEach(appealable) { row in
                            Button { sheet = OrientScoreReviewSheetTarget(kind: .appeal, entryID: row.entryID) } label: {
                                Text(verbatim: row.dimension + " " + row.delta)
                            }
                        }
                    } label: {
                        Text("orientScore.review.appealEntry").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)
                    .accessibilityIdentifier("orientScore.review.entry")
                }
                Button { sheet = OrientScoreReviewSheetTarget(kind: .appeal, entryID: nil) } label: {
                    Text("orientScore.review.appealMissing").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .disabled(busy)
                .accessibilityIdentifier("orientScore.review.missing")
                if let disputeDeadline, !disputeDeadline.isEmpty {
                    Text("orientScore.disputeDeadline \(disputeDeadline)")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("orientScore.review.deadline")
                }
                if canDispute {
                    Button { sheet = OrientScoreReviewSheetTarget(kind: .dispute, entryID: nil) } label: {
                        Text("orientScore.review.disputeEntry").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)
                    .accessibilityIdentifier("orientScore.review.dispute")
                }
                CYScreenOfflineWriteBanner(
                    routes: ["/api/orient/scoring/appeal", "/api/orient/scoring/dispute"],
                    session: offlineWriteSession.session
                )
                statusView
            }
        }
        .sheet(item: $sheet, onDismiss: {
            guard let pending = pendingReview else { return }
            pendingReview = nil
            model.review(kind: pending.kind, reason: pending.reason)
        }) { target in
            OrientScoreAppealSheetView(kind: target.kind, entryID: target.entryID.map { String($0) }, isBusy: busy,
                onSubmit: { node, reason in
                    selection.entryID = target.kind == .appeal ? target.entryID : nil
                    selection.nodeID = target.kind == .appeal && target.entryID == nil ? node : nil
                    pendingReview = (target.kind == .dispute ? .dispute : .appeal, reason)
                    sheet = nil
                },
                onClose: { sheet = nil })
        }
        .sheet(isPresented: Binding(
            get: { if case .awaitingConfirmation = model.state { return true } else { return false } },
            set: { if !$0 { model.cancel() } })
        ) {
            MemberOrientScoreConfirmSheet {
                Task {
                    await SessionOfflineSyncModel.shared.performWriteOptIn(
                        environmentSession: offlineWriteSession.session,
                        routes: ["/api/orient/scoring/appeal", "/api/orient/scoring/dispute"]
                    ) {
                        await model.confirm()
                    }
                }
            }
        }
    }

    @ViewBuilder private var statusView: some View {
        switch model.state {
        case .submitting:
            // PLY-25-9: the spinner names what it waits for.
            ProgressView { Text("orientScore.review.submittingLabel") }
                .accessibilityIdentifier("orientScore.review.submitting")
        case .submitted:
            Label("orientScore.review.submitted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(CYColor.successText)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("orientScore.review.submitted")
        case .failed(let message):
            if message == OrientScoreReviewOutcome.unknownMark {
                Label("orientScore.review.unknown", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("orientScore.review.failed")
            } else {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("orientScore.review.failed")
            }
        case .unavailable:
            Label("orientScore.review.unavailable",
                  systemImage: "exclamationmark.circle")
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("orientScore.review.unavailable")
        case .idle, .awaitingConfirmation:
            EmptyView()
        }
    }
}
