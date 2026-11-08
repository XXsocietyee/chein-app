import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for the topic-template "use" writer. Production is gated (nothing is sent, the button explains
/// "Not available yet"). Composition replaces `makeUser` once a write route and grant are approved.
@MainActor enum TopicTemplateUseFactory {
    static var makeUser: () -> TopicTemplateUsing = { GatedTopicTemplateUser() }
}

/// Drop-in "Use this template" row for the topic-template detail screen. On a server-confirmed copy it
/// calls `onCopied(topicID)` so the host can open the draft in the editor (mini: pages/publish/fabu?id=).
@MainActor struct TopicTemplateUseSection: View {
    let templateID: Int
    let scope: String?
    let readOnly: Bool
    let onCopied: (Int) -> Void
    @StateObject private var model: TopicTemplateUseModel

    init(templateID: Int, scope: String?, readOnly: Bool, onCopied: @escaping (Int) -> Void) {
        self.templateID = templateID
        self.scope = scope
        self.readOnly = readOnly
        self.onCopied = onCopied
        _model = StateObject(wrappedValue: TopicTemplateUseModel(writer: TopicTemplateUseFactory.makeUser(), readOnly: readOnly))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Button {
                Task { await model.use(id: templateID, scope: scope) }
            } label: {
                Text(W8Text.t("使用此模板", "Use this template")).frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.cyPrimary(fullWidth: true))
            .disabled(model.state == .using)
            .accessibilityIdentifier("topicTemplate.use")
            if let message = TopicTemplateUseModel.message(for: model.state) {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("topicTemplate.useMessage")
            }
        }
        .onChange(of: model.state) { _, state in
            if case .copied(let topicID) = state { onCopied(topicID) }
        }
    }
}
