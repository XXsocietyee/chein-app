import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for the orient score appeal/dispute submitter. Returns nil in production until composition
/// injects a closure wrapping `OrientSessionCoordinator.appeal/dispute(confirmed: true, ...)`; nil makes
/// the form say "Not available yet" and send nothing.
@MainActor enum OrientScoreReviewFactory {
    static var makeSubmitter: () -> OrientScoreReviewModel.Submitter? = { nil }

    static func makeModel() -> OrientScoreReviewModel {
        OrientScoreReviewModel(submitter: makeSubmitter(), makeKey: { UUID().uuidString })
    }
}

/// Appeal / dispute form with an explicit confirm step. Attach under `OrientScoreReadyContent`.
@MainActor struct OrientScoreReviewSection: View {
    @StateObject private var model = OrientScoreReviewFactory.makeModel()
    @State private var reason = ""
    @State private var kind: OrientScoreReviewModel.Kind = .appeal

    var body: some View {
        CYCard(variant: .subtle, radius: CYRadius.sm, padding: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Picker("orientScore.review.kind", selection: $kind) {
                    Text("orientScore.review.appeal").tag(OrientScoreReviewModel.Kind.appeal)
                    Text("orientScore.review.dispute").tag(OrientScoreReviewModel.Kind.dispute)
                }
                .pickerStyle(.segmented)
                TextField("orientScore.review.reason", text: $reason, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("orientScore.review.reason")
                Button("orientScore.review.begin") { model.review(kind: kind, reason: reason) }
                    .buttonStyle(.cySecondary(fullWidth: true))
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("orientScore.review.begin")
                statusView
            }
        }
        .confirmationDialog(
            Text("orientScore.review.confirmTitle"),
            isPresented: Binding(
                get: { if case .awaitingConfirmation = model.state { return true } else { return false } },
                set: { if !$0 { model.cancel() } }),
            titleVisibility: .visible
        ) {
            Button("orientScore.review.send") { Task { await model.confirm() } }
            Button("action.cancel", role: .cancel) { model.cancel() }
        }
    }

    @ViewBuilder private var statusView: some View {
        switch model.state {
        case .submitting:
            ProgressView().accessibilityIdentifier("orientScore.review.submitting")
        case .submitted:
            Label("orientScore.review.submitted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(CYColor.successText)
                .accessibilityIdentifier("orientScore.review.submitted")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("orientScore.review.failed")
        case .unavailable:
            Label("orientScore.review.unavailable",
                  systemImage: "exclamationmark.circle")
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("orientScore.review.unavailable")
        case .idle, .awaitingConfirmation:
            EmptyView()
        }
    }
}
