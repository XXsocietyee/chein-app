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
                Picker(W8Text.t("类型", "Type"), selection: $kind) {
                    Text(W8Text.t("计分申诉", "Score appeal")).tag(OrientScoreReviewModel.Kind.appeal)
                    Text(W8Text.t("成绩争议", "Score dispute")).tag(OrientScoreReviewModel.Kind.dispute)
                }
                .pickerStyle(.segmented)
                TextField(W8Text.t("说明理由（最多 500 字）", "Explain why (up to 500 characters)"), text: $reason, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("orientScore.review.reason")
                Button(W8Text.t("提交前确认", "Review before sending")) { model.review(kind: kind, reason: reason) }
                    .buttonStyle(.cySecondary(fullWidth: true))
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("orientScore.review.begin")
                statusView
            }
        }
        .confirmationDialog(
            W8Text.t("确认提交？", "Send this?"),
            isPresented: Binding(
                get: { if case .awaitingConfirmation = model.state { return true } else { return false } },
                set: { if !$0 { model.cancel() } }),
            titleVisibility: .visible
        ) {
            Button(W8Text.t("确认提交", "Send")) { Task { await model.confirm() } }
            Button(W8Text.t("取消", "Cancel"), role: .cancel) { model.cancel() }
        }
    }

    @ViewBuilder private var statusView: some View {
        switch model.state {
        case .submitting:
            ProgressView().accessibilityIdentifier("orientScore.review.submitting")
        case .submitted:
            Label(W8Text.t("已提交，等待服务器处理", "Sent. The server will review it."), systemImage: "checkmark.circle.fill")
                .foregroundStyle(CYColor.successText)
                .accessibilityIdentifier("orientScore.review.submitted")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("orientScore.review.failed")
        case .unavailable:
            Label(W8Text.t("暂未开放：申诉和争议暂时只能在对局记录中提交。", "Not available yet: appeals and disputes can only be sent from the round record for now."),
                  systemImage: "exclamationmark.circle")
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("orientScore.review.unavailable")
        case .idle, .awaitingConfirmation:
            EmptyView()
        }
    }
}
