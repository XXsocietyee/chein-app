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
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader("poll.title")
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(verbatim: "原投票结果 · 只读")
                        .font(CYTypography.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: "结果读取不代表仍可参与；本页不创建、投票、关闭或重试任何原操作。")
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.isCurrent {
                    CYEmptyState(systemImage: "lock", "poll.disabled", kind: .generic)
                } else if let poll = model.poll {
                    pollBody(poll)
                } else if model.failed {
                    CYEmptyState(systemImage: "exclamationmark.triangle", "poll.failed", kind: .failure)
                    CYPillButton(verbatim: "重新读取原投票结果", systemImage: "arrow.clockwise", action: reload)
                        .disabled(model.loading)
                        .accessibilityLabel(Text(verbatim: "重新读取原投票结果"))
                }
                if model.loading { loadingBlock("poll.loading") }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cyDomainPageBackground()
        .cyHeroScreen()
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
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay { CYCoverArt(seed: poll.question.isEmpty ? "poll-\(poll.id)" : poll.question, symbol: "chart.bar.xaxis") }
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                .accessibilityHidden(true)
            Text(verbatim: poll.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : poll.question)
                .font(CYTypography.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            statusChip(poll)
            if let date = poll.deadlineAt?.value {
                CYListRow("poll.deadline", trailing: .value(date.formatted(.dateTime)), card: true) {
                    CYRowIcon(systemImage: "calendar")
                }
            }
            CYSectionHeader("poll.options")
            ForEach(poll.options) { option in optionRow(poll, option) }
            if let total = poll.totalVoters {
                CYListRow("poll.total", trailing: .value(String(total)), card: true) {
                    CYRowIcon(systemImage: "person.2")
                }
            }
        }
    }

    @ViewBuilder private func statusChip(_ poll: GroupPoll) -> some View {
        if poll.status == "CLOSED" {
            CYStatusChip("poll.closed", tone: .neutral, systemImage: "lock")
        } else if poll.isOpen() {
            CYStatusChip("poll.open", tone: .success, systemImage: "circle")
        } else {
            CYStatusChip("poll.deadlinePassed", tone: .warning, systemImage: "clock")
        }
    }

    private func optionRow(_ poll: GroupPoll, _ option: GroupPollOption) -> some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: option.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : option.content)
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let count = option.voteCount, let total = poll.totalVoters {
                    Text(verbatim: "\(count) / \(total)")
                        .font(CYTypography.numericBody)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PollShareBar(count: count, total: total)
                }
                if poll.myOptionId == option.id {
                    CYStatusChip("poll.yourVote", tone: .success, systemImage: "checkmark.circle.fill")
                }
            }
            .accessibilityElement(children: .combine)
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
}

/// Share of votes. A missing total stays off this row; a real 0 stays 0 and draws an empty track.
private struct PollShareBar: View {
    let count: Int
    let total: Int
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let fraction = total > 0 ? min(1, CGFloat(count) / CGFloat(total)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(CYColor.bgRaised)
                Capsule().fill(CYColor.textPrimary).frame(width: max(0, proxy.size.width * fraction))
            }
        }
        .frame(height: barHeight)
        .accessibilityHidden(true)
    }
}
