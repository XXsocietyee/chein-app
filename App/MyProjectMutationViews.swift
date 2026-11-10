import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for my-project list writes. Production is gated: nothing is sent and the banner says
/// "Not available yet". Composition replaces `makeMutator` once the endpoint allowlist is approved.
@MainActor enum MyProjectMutationFactory {
    static var makeMutator: () -> MyProjectMutating = { GatedMyProjectMutator() }
}

/// Confirm dialog + honest result banner for `MyProjectMutationModel`. Attach to the list screen and call
/// `model.begin(...)` from the row menu; re-read the list when `model.reloadToken` changes.
/// This is a status strip on the host list, not its own screen, so it does not set a navigation title.
@MainActor struct MyProjectMutationStatusView: View {
    @ObservedObject var model: MyProjectMutationModel

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            switch model.state {
            case .working:
                CYSkeleton()
                    .accessibilityIdentifier("myProject.mutation.working")
            case .done:
                CYStatusChip(verbatim: W8Text.t("已完成", "Done"), tone: .success, systemImage: "checkmark.circle.fill")
                    .accessibilityIdentifier("myProject.mutation.done")
            case .failed(_, let message):
                Label {
                    Text(LocalizedStringKey(message))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(CYTypography.body)
                .foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("myProject.mutation.failed")
            case .unavailable:
                Label(W8Text.t("暂未开放：此操作暂时无法在 App 内完成。", "Not available yet: this action can't be done in the app yet."),
                      systemImage: "exclamationmark.circle")
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("myProject.mutation.unavailable")
            case .idle, .awaitingConfirmation:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(
            confirmationText,
            isPresented: Binding(
                get: { if case .awaitingConfirmation = model.state { return true } else { return false } },
                set: { if !$0 { model.dismiss() } }),
            titleVisibility: .visible
        ) {
            Button(W8Text.t("确认", "Confirm"), role: .destructive) { Task { await model.confirm() } }
            Button(W8Text.t("取消", "Cancel"), role: .cancel) { model.dismiss() }
        }
    }

    private var confirmationText: String {
        if case .awaitingConfirmation(let mutation) = model.state { return mutation.confirmationMessage ?? "" }
        return ""
    }
}
