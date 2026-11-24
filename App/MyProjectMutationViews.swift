import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for my-project list writes. Defaults to `GatedMyProjectMutator` until root composition
/// installs the live mutator backed by the signed-in China session.
@MainActor enum MyProjectMutationFactory {
    static var makeMutator: () -> MyProjectMutating = { GatedMyProjectMutator() }

    /// True once composition replaced the gated mutator. While false the list offers no write at all.
    static var isLive: Bool { !(makeMutator() is GatedMyProjectMutator) }

    /// The list's mutation model, or nil while writes are gated (capability absent: hidden).
    static func liveModel(scope: String?) -> MyProjectMutationModel? {
        let mutator = makeMutator()
        guard !(mutator is GatedMyProjectMutator) else { return nil }
        return MyProjectMutationModel(writer: mutator, scope: scope ?? "")
    }
}

/// Confirm dialog + honest result banner for `MyProjectMutationModel`. Attach to the list screen and call
/// `model.begin(...)` from the row menu; re-read the list when `model.reloadToken` changes.
/// This is a status strip on the host list, not its own screen, so it does not set a navigation title.
@MainActor struct MyProjectMutationStatusView: View {
    @ObservedObject var model: MyProjectMutationModel
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            switch model.state {
            case .working:
                CYSkeleton()
                    .accessibilityIdentifier("myProject.mutation.working")
            case .done:
                CYStatusChip(verbatim: W8Text.t("已完成", "Done"), tone: .success, systemImage: "checkmark.circle.fill")
                    .accessibilityIdentifier("myProject.mutation.done")
                    .accessibilityLabel(Text(verbatim: W8Text.t("已完成", "Done")))
                    .accessibilityValue(Text(verbatim: W8Text.t("已完成", "Done")))
                    .accessibilityHint(Text(verbatim: W8Text.t("已完成", "Done")))
            case .failed(_, let message):
                Label {
                    Text(LocalizedStringKey(message))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .cyText(.body)
                .foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("myProject.mutation.failed")
                .accessibilityLabel(Text(verbatim: message.isEmpty ? "—" : message))
                .accessibilityValue(Text(verbatim: message.isEmpty ? "—" : message))
                .accessibilityHint(Text(verbatim: message.isEmpty ? "—" : message))
            case .unavailable:
                Label(W8Text.t("暂未开放：此操作暂时无法在 App 内完成。", "Not available yet: this action can't be done in the app yet."),
                      systemImage: "exclamationmark.circle")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("myProject.mutation.unavailable")
                    .accessibilityLabel(Text(verbatim: W8Text.t("暂未开放：此操作暂时无法在 App 内完成。", "Not available yet: this action can't be done in the app yet.")))
                    .accessibilityValue(Text(verbatim: W8Text.t("暂未开放：此操作暂时无法在 App 内完成。", "Not available yet: this action can't be done in the app yet.")))
                    .accessibilityHint(Text(verbatim: W8Text.t("暂未开放：此操作暂时无法在 App 内完成。", "Not available yet: this action can't be done in the app yet.")))
            case .idle, .awaitingConfirmation:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(
            isPresented: Binding(
                get: { if case .awaitingConfirmation = model.state { return true } else { return false } },
                set: { if !$0 { model.dismiss() } }
            )
        ) {
            CYConfirmSheet(
                title: confirmationText,
                message: "",
                confirmTitle: MerchantAreaCopy.text("确认", "Confirm", locale),
                isDestructive: true,
                onCancel: { model.dismiss() },
                onConfirm: { Task { await model.confirm() } }
            )
            .cyDomainSheet(detents: [.half])
            .themeDomain(.topicEditor)
        }
    }

    private var confirmationText: String {
        if let text = model.confirmationText, !text.isEmpty { return text }
        if case .awaitingConfirmation(let mutation) = model.state { return mutation.confirmationMessage ?? "" }
        return ""
    }
}
