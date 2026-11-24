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
}

/// Appeal / dispute form with an explicit confirm step. Attach under `OrientScoreReadyContent`
/// only when `makeSubmitter` returns a submitter. Sync and settle are not on this form.
@MainActor struct OrientScoreReviewSection: View {
    @StateObject private var model: OrientScoreReviewModel
    @StateObject private var selection: OrientScoreReviewEntrySelection
    private let entries: [OrientScoreTimelineRow]
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @State private var reason = ""
    @State private var kind: OrientScoreReviewModel.Kind = .appeal

    init(session: AppSession, score: OrientSessionScore, entries: [OrientScoreTimelineRow]) {
        let selection = OrientScoreReviewEntrySelection()
        if entries.count == 1 { selection.entryID = entries[0].entryID }
        self.entries = entries
        _selection = StateObject(wrappedValue: selection)
        let built = OrientScoreReviewFactory.makeSubmitter(OrientScoreReviewContext(
            session: session, score: score, entryID: { selection.entryID }))
        _model = StateObject(wrappedValue: OrientScoreReviewModel(
            submitter: built?.submitter, makeKey: built?.makeKey ?? { UUID().uuidString }))
    }

    var body: some View {
        CYCard(variant: .subtle, radius: CYRadius.sm, padding: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Picker("orientScore.review.kind", selection: $kind) {
                    Text("orientScore.review.appeal").tag(OrientScoreReviewModel.Kind.appeal)
                    Text("orientScore.review.dispute").tag(OrientScoreReviewModel.Kind.dispute)
                }
                .pickerStyle(.segmented)
                if kind == .appeal {
                    Picker("orientScore.review.entry", selection: entryBinding) {
                        Text("orientScore.review.needEntry").tag(0)
                        ForEach(entries) { row in
                            Text(verbatim: row.dimension + " " + row.delta).tag(row.entryID)
                        }
                    }
                    .accessibilityIdentifier("orientScore.review.entry")
                }
                TextField("orientScore.review.reason", text: $reason, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("orientScore.review.reason")
                Button("orientScore.review.begin") { model.review(kind: kind, reason: reason) }
                    .buttonStyle(.cySecondary(fullWidth: true))
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("orientScore.review.begin")
                CYScreenOfflineWriteBanner(
                    routes: ["/api/orient/scoring/appeal", "/api/orient/scoring/dispute"],
                    session: offlineWriteSession.session
                )
                statusView
            }
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

    private var entryBinding: Binding<Int> {
        Binding(get: { selection.entryID ?? 0 }, set: { selection.entryID = $0 > 0 ? $0 : nil })
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
