import SwiftUI

struct IMConversationRowButtonToken: Equatable {
    enum Operation: Equatable { case confirm, retryUnchanged }
    let id: UUID
    let appearance: UUID
    let operation: Operation
    let mutation: IMMutation
}

@MainActor final class IMConversationRowReviewModel: ObservableObject {
    @Published private(set) var state: IMReviewState
    @Published private(set) var appearance: UUID?
    @Published private(set) var isActionPending = false
    let actions: IMConversationRowActions
    private var queued: IMConversationRowButtonToken?
    private var executing: IMConversationRowButtonToken?
    private let invalidateList: () -> Void
    init(actions: IMConversationRowActions, invalidateList: @escaping () -> Void = {}) {
        self.actions = actions; self.invalidateList = invalidateList; state = actions.state
    }
    func observe() {
        let lifetime = UUID()
        appearance = lifetime; queued = nil; executing = nil; isActionPending = false
        actions.coordinator.onChange = { [weak self] in
            guard let self, self.appearance == lifetime else { return }
            self.state = self.actions.state
        }
        state = actions.state
    }
    /// Called synchronously by a button in this exact rendered appearance. Tasks
    /// may consume this token once; they cannot create or restore an appearance.
    func prepare(_ operation: IMConversationRowButtonToken.Operation,
                 appearance expected: UUID?) -> IMConversationRowButtonToken? {
        guard let expected, appearance == expected, actions.isCurrent,
              queued == nil, executing == nil else { return nil }
        let mutation: IMMutation
        switch (operation, actions.state) {
        case (.confirm, .reviewing(let value)), (.retryUnchanged, .outcomeUnknown(let value)): mutation = value
        default: return nil
        }
        guard let action = actions.action,
              mutation == action.mutation(conversationID: actions.conversation.id) else { return nil }
        let token = IMConversationRowButtonToken(id: UUID(), appearance: expected,
            operation: operation, mutation: mutation)
        queued = token; isActionPending = true
        return token
    }
    func perform(_ token: IMConversationRowButtonToken) async -> Bool {
        guard queued == token, appearance == token.appearance else { return false }
        queued = nil
        guard actions.isCurrent, !Task.isCancelled, matchesPendingMutation(token) else {
            isActionPending = false; state = actions.state; return false
        }
        executing = token
        let accepted: Bool
        switch token.operation {
        case .confirm: accepted = await actions.confirm()
        case .retryUnchanged: accepted = await actions.retryUnchanged()
        }
        // Receipt ownership and UI ownership are separate. A confirmed operation
        // still invalidates its exact list cache after Close, without reviving UI.
        let matchingReceipt = accepted && actions.isCurrent && actions.hasMatchingAcknowledgment
            && actions.action?.mutation(conversationID: actions.conversation.id) == token.mutation
        if matchingReceipt { invalidateList() }
        // An old completion cannot overwrite or notify a newly opened sheet.
        guard appearance == token.appearance, executing == token else { return false }
        executing = nil; isActionPending = false
        guard actions.isCurrent else { state = .idle; return false }
        state = actions.state
        return matchingReceipt && !Task.isCancelled
    }
    private func matchesPendingMutation(_ token: IMConversationRowButtonToken) -> Bool {
        switch (token.operation, actions.state) {
        case (.confirm, .reviewing(let mutation)), (.retryUnchanged, .outcomeUnknown(let mutation)):
            return mutation == token.mutation
                && actions.action?.mutation(conversationID: actions.conversation.id) == token.mutation
        default: return false
        }
    }
    func dismiss() {
        // Invalidate before cancelReview emits a synchronous owner callback.
        appearance = nil; queued = nil; executing = nil; isActionPending = false
        actions.cancelReview(); state = .idle
        // The session owner's outcomeUnknown/submitting journal remains intact.
    }
}

/// Sheet presentation is owned by the list, outside its loading/error subtree.
/// Receipt acknowledgment requests a list read; it never updates badges locally.
@MainActor struct IMConversationRowActionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: IMConversationRowReviewModel
    init(actions: IMConversationRowActions, invalidateList: @escaping () -> Void) {
        _model = StateObject(wrappedValue: IMConversationRowReviewModel(actions: actions,
            invalidateList: invalidateList))
    }
    var body: some View {
        let appearance = model.appearance
        let titleKey = model.actions.action?.titleKey ?? "im.row.title"
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    CYHeroHeader(LocalizedStringKey(titleKey))
                    if model.actions.isCurrent {
                        CYCard {
                            HStack(alignment: .top, spacing: CYSpacing.md) {
                                CYRowIcon(systemImage: model.actions.action?.symbolName ?? "bubble.left")
                                MessagingConversationName(conversation: model.actions.conversation)
                                    .font(CYTypography.cardTitle)
                                    .foregroundStyle(CYColor.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                        phaseContent(appearance)
                    } else {
                        CYEmptyState(systemImage: "person.crop.circle", "messaging.signInHint")
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cyDomainPageBackground()
            .cyHeroScreen()
            .cyAnimation(value: model.state)
            .cyHaptic(.success, trigger: model.state) { _, new in
                if case .acknowledged = new { return true }
                return false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isReviewing ? LocalizedStringKey("action.cancel") : LocalizedStringKey("action.close")) { model.dismiss(); dismiss() }
                        .accessibilityIdentifier("im.row.close")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .privacySensitive()
        .accessibilityIdentifier("im.row.review")
        .onAppear { model.observe() }
        .onDisappear { model.dismiss() }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private func phaseContent(_ appearance: UUID?) -> some View {
        switch model.state {
        case .reviewing:
            CYPillButton(LocalizedStringKey(model.actions.action?.titleKey ?? "im.full.confirm"), systemImage: model.actions.action?.symbolName) {
                guard let token = model.prepare(.confirm, appearance: appearance) else { return }
                Task { _ = await model.perform(token) }
            }
            .disabled(model.isActionPending)
            .accessibilityIdentifier("im.row.confirm")
        case .submitting:
            loadingBlock("im.full.submitting").accessibilityIdentifier("im.row.submitting")
        case .outcomeUnknown:
            Text("d7.rowActions.unknown")
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            CYPillButton("d7.rowActions.retry", systemImage: "arrow.clockwise") {
                guard let token = model.prepare(.retryUnchanged, appearance: appearance) else { return }
                Task { _ = await model.perform(token) }
            }
            .disabled(model.isActionPending)
            .accessibilityIdentifier("im.row.retrySame")
        case .acknowledged:
            if model.actions.hasMatchingAcknowledgment {
                CYStatusChip("d7.rowActions.done", tone: .success, systemImage: "checkmark.circle")
                    .accessibilityIdentifier("im.row.acknowledged")
            } else {
                Text("d7.rowActions.mismatch")
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .rejected:
            CYStatusChip("d7.rowActions.rejected", tone: .danger, systemImage: "xmark.octagon")
        case .closed:
            Text("im.full.closed")
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .idle:
            Text("im.full.disabled")
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private func loadingBlock(_ key: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(key)
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            CYSkeleton().accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
    private var isReviewing: Bool {
        if case .reviewing = model.state { return true }
        return false
    }
}

@MainActor struct IMConversationRowActionPresentation: Identifiable {
    let id = UUID()
    let actions: IMConversationRowActions
}
