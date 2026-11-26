import SwiftUI

/// A result-only presentation over the existing poll client. It does not call the
/// mutation coordinator's refresh/recovery methods or touch any pending journal.
@MainActor private final class GroupPollOriginalResultModel: ObservableObject {
    @Published private(set) var poll: GroupPoll?
    @Published private(set) var loading = false
    @Published private(set) var failed = false
    private let owner: GroupPollCoordinator
    private let reference: GroupPollReference
    private let sourceCurrent: () -> Bool
    private var generation: UInt64 = 0
    private var active = false
    init(owner: GroupPollCoordinator, reference: GroupPollReference, current: @escaping () -> Bool) {
        self.owner = owner; self.reference = reference; sourceCurrent = current
    }
    var isCurrent: Bool {
        active && sourceCurrent() && owner.isCurrent && owner.reference == reference
            && owner.scope.conversationID == reference.conversationID && owner.canRead
    }
    func activate() async {
        guard !Task.isCancelled else { return }
        active = true
        await reload()
    }
    func reload() async {
        guard isCurrent, !Task.isCancelled else { retire(); return }
        generation &+= 1; let run = generation
        poll = nil; failed = false; loading = true
        defer { if generation == run { loading = false } }
        do {
            // This is the exact existing original result route and captured session.
            // Historical-audience authorization stays server-owned; no membership grant.
            let value = try await owner.client.result(reference, expectedIdentity: owner.scope.identity)
            guard generation == run, isCurrent, !Task.isCancelled else { return }
            try value.validate(reference: reference, conversationID: owner.scope.conversationID, results: true)
            poll = value
        } catch {
            guard generation == run else { return }
            poll = nil
            if !isCurrent || Task.isCancelled { retire() } else { failed = true }
        }
    }
    func retire() {
        active = false; generation &+= 1; poll = nil; loading = false; failed = false
    }
}

/// Original type4 cards and server-owned type9 results share this passive destination.
/// No create, vote, close, resend, receipt settlement or ACK action is exposed here.
@MainActor struct GroupPollOriginalResultView: View {
    @StateObject private var model: GroupPollOriginalResultModel
    @State private var readTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var phase
    init(owner: GroupPollCoordinator, reference: GroupPollReference, current: @escaping () -> Bool) {
        _model = StateObject(wrappedValue: GroupPollOriginalResultModel(owner: owner, reference: reference, current: current))
    }
    var body: some View {
        List {
            Section {
                Text(verbatim: "原投票结果 · 只读")
                    .fixedSize(horizontal: false, vertical: true)
            } footer: {
                Text(verbatim: "结果读取不代表仍可参与；本页不创建、投票、关闭或重试任何原操作。")
            }
            if !model.isCurrent {
                ContentUnavailableView("poll.disabled", systemImage: "lock")
            } else if let poll = model.poll {
                pollBody(poll)
            } else if model.failed {
                ContentUnavailableView {
                    Label("poll.failed", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button(action: reload) {
                        Label { Text(verbatim: "重新读取原投票结果") } icon: { Image(systemName: "arrow.clockwise") }
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.loading)
                    .accessibilityLabel(Text(verbatim: "重新读取原投票结果"))
                }
            }
            if model.loading { loadingBlock("poll.loading") }
        }
        .navigationTitle(Text("poll.title"))
        .navigationBarTitleDisplayMode(.inline)
        .cyAnimation(value: model.loading)
        .toolbar { Button("messaging.refresh", systemImage: "arrow.clockwise") { reload() }.disabled(!model.isCurrent || model.loading).accessibilityLabel(Text("messaging.refresh")) }
        .privacySensitive().accessibilityIdentifier("poll.originalResult.readOnly")
        .task(id: phase) {
            guard phase == .active else { retire(); return }
            await model.activate()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 8_000_000_000) } catch { return }
                guard model.isCurrent else { retire(); return }
                if !model.loading { await model.reload() }
            }
        }
        .onDisappear { retire() }
        .onChange(of: model.isCurrent) { _, current in if !current { retire() } }
    }
    private func reload() {
        guard phase == .active, model.isCurrent else { retire(); return }
        readTask?.cancel(); readTask = Task { await model.reload() }
    }
    private func retire() { readTask?.cancel(); readTask = nil; model.retire() }

    @ViewBuilder private func pollBody(_ poll: GroupPoll) -> some View {
        Section {
            Text(verbatim: poll.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : poll.question)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            statusChip(poll)
            if let date = poll.deadlineAt?.value {
                LabeledContent {
                    Text(verbatim: date.formatted(.dateTime))
                } label: {
                    Label("poll.deadline", systemImage: "calendar")
                }
            }
        }
        Section {
            ForEach(poll.options) { option in optionRow(poll, option) }
        } header: {
            Text("poll.options")
        }
        if let total = poll.totalVoters {
            Section {
                LabeledContent {
                    Text(verbatim: String(total)).monospacedDigit()
                } label: {
                    Label("poll.total", systemImage: "person.2")
                }
            }
        }
    }

    @ViewBuilder private func statusChip(_ poll: GroupPoll) -> some View {
        if poll.status == "CLOSED" {
            Label("poll.closed", systemImage: "lock")
                .foregroundStyle(.secondary)
        } else if poll.isOpen() {
            Label("poll.open", systemImage: "circle")
                .foregroundStyle(.green)
        } else {
            Label("poll.deadlinePassed", systemImage: "clock")
                .foregroundStyle(.orange)
        }
    }

    private func optionRow(_ poll: GroupPoll, _ option: GroupPollOption) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: option.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : option.content)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: CYSpacing.sm)
                if poll.myOptionId == option.id {
                    Label("poll.yourVote", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.tint)
                }
                if let count = option.voteCount, let total = poll.totalVoters {
                    Text(verbatim: "\(count) / \(total)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            // Share of votes. A missing total stays off this row; a real 0 stays 0 and draws an empty track.
            if let count = option.voteCount, let total = poll.totalVoters {
                ProgressView(value: Double(total > 0 ? min(count, total) : 0), total: Double(max(total, 1)))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func loadingBlock(_ key: LocalizedStringKey) -> some View {
        ProgressView { Text(key) }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }
}
