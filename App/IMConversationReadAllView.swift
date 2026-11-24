import SwiftUI

struct IMConversationReadAllButtonToken: Equatable {
    let id: UUID
    let appearance: UUID
}

@MainActor final class IMConversationReadAllReviewModel: ObservableObject {
    let batch: IMConversationReadAll
    @Published private(set) var appearance: UUID?
    @Published private(set) var phase: IMConversationReadAllPhase
    @Published private(set) var items: [IMConversationReadAllItem]
    @Published private(set) var isActionPending = false
    @Published private(set) var stopRequested = false
    private var queued: IMConversationReadAllButtonToken?
    private var executing: IMConversationReadAllButtonToken?
    private let invalidateList: () -> Void

    init(batch: IMConversationReadAll, invalidateList: @escaping () -> Void) {
        self.batch = batch; self.invalidateList = invalidateList
        phase = batch.phase; items = batch.items
    }
    func observe() {
        let lifetime = UUID()
        appearance = lifetime; queued = nil; executing = nil; isActionPending = false
        batch.onChange = { [weak self] in
            guard let self, self.appearance == lifetime else { return }
            self.copySnapshot()
        }
        copySnapshot()
    }
    func prepare(appearance expected: UUID?) -> IMConversationReadAllButtonToken? {
        guard let expected, appearance == expected, queued == nil, executing == nil,
              batch.canConfirm else { return nil }
        let token = IMConversationReadAllButtonToken(id: UUID(), appearance: expected)
        queued = token; isActionPending = true
        return token
    }
    func perform(_ token: IMConversationReadAllButtonToken) async {
        guard queued == token, appearance == token.appearance else { return }
        queued = nil
        guard batch.canConfirm, !Task.isCancelled else {
            batch.stop(); isActionPending = false; copySnapshot(); return
        }
        executing = token
        await batch.confirm()
        // List/cache ownership outlives a closed review. This also runs for unknown
        // or partial results: those writes may have reached the server. Invalidation
        // creates no network task; the current list appearance owns the actual read.
        if batch.attemptedCount > 0, batch.isCurrent { invalidateList() }
        guard appearance == token.appearance, executing == token else { return }
        executing = nil; isActionPending = false; copySnapshot()
    }
    func stop() { batch.stop(); copySnapshot() }
    func dismiss() {
        appearance = nil; queued = nil; executing = nil; isActionPending = false
        batch.stop()
        phase = .cancelled
        // Never cancel/reset the session coordinator or resend an uncertain item.
    }
    private func copySnapshot() {
        phase = batch.phase; items = batch.items; stopRequested = batch.stopRequested
    }
}

@MainActor struct IMConversationReadAllView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: IMConversationReadAllReviewModel
    init(batch: IMConversationReadAll, invalidateList: @escaping () -> Void) {
        _model = StateObject(wrappedValue: IMConversationReadAllReviewModel(batch: batch,
            invalidateList: invalidateList))
    }
    var body: some View {
        let appearance = model.appearance
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    CYHeroHeader("im.readAll.title")
                    if model.batch.isCurrent {
                        CYListRow("d7.readAll.count", trailing: .value(String(model.items.count)), card: true) {
                            CYRowIcon(systemImage: "bubble.left.and.bubble.right")
                        }
                        phaseContent(appearance)
                        LazyVStack(alignment: .leading, spacing: CYSpacing.md) {
                            CYSectionHeader("d7.readAll.conversations")
                            ForEach(model.items) { item in conversationRow(item) }
                        }
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
            .cyAnimation(value: model.phase)
            .cyHaptic(.success, trigger: model.phase) { _, new in new == .finished }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.phase == .reviewing ? LocalizedStringKey("action.cancel") : LocalizedStringKey("action.close")) { model.dismiss(); dismiss() }
                        .accessibilityIdentifier("im.readAll.closeButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .privacySensitive()
        .accessibilityIdentifier("im.readAll.reviewSheet")
        .onAppear { model.observe() }
        .onDisappear { model.dismiss() }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private func phaseContent(_ appearance: UUID?) -> some View {
        switch model.phase {
        case .reviewing:
            if model.batch.canConfirm {
                CYPillButton("d7.readAll.confirm", systemImage: "checkmark") {
                    guard let token = model.prepare(appearance: appearance) else { return }
                    Task { await model.perform(token) }
                }
                .disabled(model.isActionPending)
                .accessibilityIdentifier("im.readAll.confirmButton")
            } else {
                Text("d7.readAll.unavailable")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .running:
            loadingBlock("d7.readAll.running")
            if model.stopRequested {
                Text("d7.readAll.stopping")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button("d7.readAll.stop", role: .destructive) { model.stop() }
                    .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                    .accessibilityIdentifier("im.readAll.stopButton")
            }
        case .finished:
            summary
            if model.batch.unknownCount > 0 {
                Text("d7.readAll.unknownHint")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .cancelled:
            CYEmptyState(systemImage: "xmark.circle", "d7.readAll.cancelled")
        }
    }
    private func conversationRow(_ item: IMConversationReadAllItem) -> some View {
        CYCard {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                CYRowIcon(systemImage: "bubble.left")
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    MessagingConversationName(conversation: item.conversation)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CYStatusChip(LocalizedStringKey(outcomeKey(item.outcome)), tone: outcomeTone(item.outcome), systemImage: outcomeSymbol(item.outcome))
                }
            }
            .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("im.readAll.item.\(item.id)")
        }
    }
    private func loadingBlock(_ key: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(key)
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            CYSkeleton().accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
    private func outcomeTone(_ outcome: IMConversationReadAllOutcome) -> CYStatusTone {
        switch outcome {
        case .acknowledged: return .success
        case .rejected: return .danger
        case .outcomeUnknown, .unavailable: return .warning
        case .submitting: return .info
        case .notAttempted, .protectedIntent: return .neutral
        }
    }
    private func outcomeSymbol(_ outcome: IMConversationReadAllOutcome) -> String {
        switch outcome {
        case .acknowledged: return "checkmark.circle"
        case .rejected: return "xmark.octagon"
        case .outcomeUnknown: return "questionmark.circle"
        case .submitting: return "arrow.triangle.2.circlepath"
        case .unavailable: return "exclamationmark.circle"
        case .protectedIntent: return "lock"
        case .notAttempted: return "circle"
        }
    }
    private var summary: some View {
        VStack(spacing: CYSpacing.sm) {
            CYListRow("d7.readAll.acknowledged", trailing: .value(String(model.batch.acknowledgedCount)), card: true) {
                CYRowIcon(systemImage: "checkmark.circle")
            }
            CYListRow("d7.readAll.unknown", trailing: .value(String(model.batch.unknownCount)), card: true) {
                CYRowIcon(systemImage: "questionmark.circle")
            }
            CYListRow("d7.readAll.rejected", trailing: .value(String(model.batch.rejectedCount)), card: true) {
                CYRowIcon(systemImage: "xmark.octagon")
            }
            CYListRow("d7.readAll.remaining", trailing: .value(String(model.batch.remainingCount)), card: true) {
                CYRowIcon(systemImage: "circle")
            }
        }
    }
    private func outcomeKey(_ outcome: IMConversationReadAllOutcome) -> String {
        switch outcome {
        case .notAttempted: return "d7.readAll.remaining"
        case .submitting: return "d7.readAll.itemRunning"
        case .acknowledged: return "d7.readAll.acknowledged"
        case .rejected: return "d7.readAll.rejected"
        case .outcomeUnknown: return "d7.readAll.unknown"
        case .protectedIntent: return "d7.readAll.skipped"
        case .unavailable: return "d7.readAll.itemUnavailable"
        }
    }
}

@MainActor struct IMConversationReadAllPresentation: Identifiable {
    let id = UUID()
    let batch: IMConversationReadAll
}
