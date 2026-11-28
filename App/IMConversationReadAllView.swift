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
            List {
                if model.batch.isCurrent {
                    Section {
                        LabeledContent {
                            Text(verbatim: String(model.items.count))
                        } label: {
                            Label("d7.readAll.count", systemImage: "bubble.left.and.bubble.right")
                        }
                    }
                    Section {
                        phaseContent(appearance)
                    }
                    Section {
                        ForEach(model.items) { item in conversationRow(item) }
                    } header: {
                        Text("d7.readAll.conversations")
                    }
                } else {
                    ContentUnavailableView("messaging.signInHint", systemImage: "person.crop.circle")
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("im.readAll.title"))
            .navigationBarTitleDisplayMode(.inline)
            .cyHaptic(.success, trigger: model.phase == .finished, where: CYHapticTransition.turnedOn)
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
                Button {
                    guard let token = model.prepare(appearance: appearance) else { return }
                    Task { await model.perform(token) }
                } label: {
                    Label("d7.readAll.confirm", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isActionPending)
                .accessibilityIdentifier("im.readAll.confirmButton")
            } else {
                Text("d7.readAll.unavailable")
                    .foregroundStyle(.secondary)
            }
        case .running:
            loadingBlock("d7.readAll.running")
            if model.stopRequested {
                Text("d7.readAll.stopping")
                    .foregroundStyle(.secondary)
            } else {
                Button("d7.readAll.stop", role: .destructive) { model.stop() }
                    .accessibilityIdentifier("im.readAll.stopButton")
            }
        case .finished:
            summary
            if model.batch.unknownCount > 0 {
                Text("d7.readAll.unknownHint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .cancelled:
            Label("d7.readAll.cancelled", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
        }
    }
    private func conversationRow(_ item: IMConversationReadAllItem) -> some View {
        Label {
            VStack(alignment: .leading) {
                MessagingConversationName(conversation: item.conversation)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Label(LocalizedStringKey(outcomeKey(item.outcome)), systemImage: outcomeSymbol(item.outcome))
                    .font(.subheadline)
                    .foregroundStyle(outcomeTint(item.outcome))
            }
        } icon: {
            Image(systemName: "bubble.left")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("im.readAll.item.\(item.id)")
    }
    private func loadingBlock(_ key: LocalizedStringKey) -> some View {
        HStack {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            ProgressView()
        }
        .accessibilityElement(children: .combine)
    }
    private func outcomeTint(_ outcome: IMConversationReadAllOutcome) -> Color {
        switch outcome {
        case .acknowledged: return .green
        case .rejected: return .red
        case .outcomeUnknown, .unavailable: return .orange
        case .submitting: return .blue
        case .notAttempted, .protectedIntent: return .secondary
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
    @ViewBuilder private var summary: some View {
        summaryRow("d7.readAll.acknowledged", value: model.batch.acknowledgedCount, systemImage: "checkmark.circle")
        summaryRow("d7.readAll.unknown", value: model.batch.unknownCount, systemImage: "questionmark.circle")
        summaryRow("d7.readAll.rejected", value: model.batch.rejectedCount, systemImage: "xmark.octagon")
        summaryRow("d7.readAll.remaining", value: model.batch.remainingCount, systemImage: "circle")
    }
    private func summaryRow(_ key: LocalizedStringKey, value: Int, systemImage: String) -> some View {
        LabeledContent {
            Text(verbatim: String(value))
        } label: {
            Label(key, systemImage: systemImage)
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
