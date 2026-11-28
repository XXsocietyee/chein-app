import SwiftUI

/// Factory invocation happens at the normal entry, never during a request or by a
/// context-search card. The retained owner binds the original actor/channel issuance.
@MainActor struct NativeChannelChainLaunchView: View {
    let makeFlow: () -> NativeChannelChainFlow?
    let current: () -> Bool
    @State private var flow: NativeChannelChainFlow?
    @State private var attempted = false
    var body: some View {
        Group {
            if let flow { NativeChannelChainView(flow: flow, current: current) }
            else if attempted { ContentUnavailableView("d7.chain.unavailable", systemImage: "list.number") }
            else {
                ProgressView { Text("d7.channelActivity.loading") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.task {
            guard !attempted else { return }
            attempted = true
            if current() { flow = makeFlow() }
        }
    }
}

@MainActor private struct NativeChannelChainView: View {
    @Bindable var flow: NativeChannelChainFlow
    let current: () -> Bool
    @Environment(\.scenePhase) private var scene
    @Environment(\.locale) private var locale
    @State private var title = ""
    @State private var maxSlots = "0"
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(86400)
    @State private var content = ""
    @State private var retryPresented = false
    @State private var operation = NativeChannelActivityScreenTask()
    private var available: Bool { current() && scene == .active }
    var body: some View {
        Form {
            if !flow.isCurrent { ContentUnavailableView("d7.chain.unavailable", systemImage: "list.number") }
            else {
                status
                // A confirmed original receipt survives a separate current-roster read failure.
                // Scope/account/receipt authority still gates this memory-only projection.
                if let confirmed = flow.lastConfirmedRequest {
                    Section {
                        Label(label(confirmed.operation), systemImage: "checkmark.circle")
                    } header: { Text("d7.chain.done") }
                        .accessibilityIdentifier("channel.chain.originalReceipt")
                }
                if let review = flow.review { reviewSection(review) }
                else if let pending = flow.pending { recoverySection(pending) }
                if let page = flow.page { chainPage(page) }
                else if flow.reference != nil, !flow.busy, flow.phase != .appliedRedacted {
                    ContentUnavailableView {
                        Label("d7.chain.loadFailed", systemImage: "list.number")
                    } actions: {
                        Button("d7.channelActivity.retry") { run { _ in await flow.refresh() } }
                            .buttonStyle(.bordered)
                    }
                    .disabled(!flow.service.canRead || flow.review != nil)
                } else if flow.reference == nil, flow.pending == nil, flow.review == nil {
                    createSection
                }
            }
        }
        .nativeChannelScreen()
        .navigationTitle(Text("d7.chain.title"))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task(id: available) {
            if available { await flow.activate(current: current) }
            else { retireScreen() }
        }
        .onChange(of: current()) { _, valid in if !valid { retireScreen() } }
        .onChange(of: scene) { _, phase in if phase != .active { retireScreen() } }
        .onDisappear { retireScreen() }
        .confirmationDialog(Text("d7.chain.retry.title"), isPresented: $retryPresented, titleVisibility: .visible) {
            Button("d7.channelActivity.retry") {
                run { current in await flow.retryOriginal(); guard current() else { return }; await refreshAfterSettlement() }
            }
            Button("d7.channelActivity.cancel", role: .cancel) {}
        }
    }
    @ViewBuilder private func chainPage(_ page: NativeChannelChainPage) -> some View {
        Section {
            Text(verbatim: chainTitle(page.chain.title))
                .font(.headline)
            LabeledContent("d7.chain.status") { chainStatusChip(page) }
            LabeledContent("d7.chain.joined") {
                if page.chain.maxSlots == 0 { Text("d7.chain.joined.unlimited \(page.chain.activeCount)").monospacedDigit() }
                else { Text("d7.chain.joined.limited \(page.chain.activeCount) \(page.chain.maxSlots)").monospacedDigit() }
            }
            if let end = page.chain.deadlineAt {
                LabeledContent("d7.chain.deadline") { Text(Date(timeIntervalSince1970: Double(end) / 1000), format: .dateTime.month().day().hour().minute()) }
            }
            Button("d7.channelActivity.refresh") { run { _ in await flow.refresh() } }
                .disabled(flow.busy || flow.review != nil)
        }
        Section {
            if flow.entries.isEmpty {
                ContentUnavailableView("d7.chain.entries.empty", systemImage: "tray")
            }
            ForEach(flow.entries) { entry in chainEntry(entry) }
            if page.hasMore {
                CYLoadMoreRow("d7.chain.showMore", isLoading: flow.busy) { run { _ in await flow.more() } }
                    .disabled(flow.review != nil)
            }
        } header: { Text("d7.chain.entries") }
        if flow.pending == nil, flow.review == nil { mineSection(page) }
    }
    @ViewBuilder private var createSection: some View {
        if flow.service.allows(.create), flow.service.canRead, flow.service.canRecover {
            Section {
                TextField("d7.chain.create.title", text: $title)
                TextField("d7.chain.create.maxSlots", text: $maxSlots).keyboardType(.numberPad)
                Toggle("d7.chain.create.hasDeadline", isOn: $hasDeadline)
                if hasDeadline { DatePicker("d7.chain.deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute]) }
                Button("d7.chain.create.submit") {
                    guard let maximum = Int(maxSlots) else { return }
                    flow.prepareCreate(title: title, maxSlots: maximum, deadline: hasDeadline ? deadline : nil)
                }
                .disabled(!flow.canCreate || Int(maxSlots) == nil)
            } header: { Text("d7.chain.create") }
            .disabled(!flow.canCreate)
        } else {
            ContentUnavailableView("d7.chain.unavailable", systemImage: "list.number")
        }
    }
    @ViewBuilder private func mineSection(_ page: NativeChannelChainPage) -> some View {
        Section {
            if let mine = page.mine {
                if mine.status == "ACTIVE" { LabeledContent("d7.chain.status") { Text("d7.chain.mine.joined \(mine.position)").monospacedDigit() } }
                else { LabeledContent("d7.chain.status") { Text("d7.chain.withdrawn") } }
                if mine.status == "ACTIVE", let original = mine.content, page.chain.canParticipate {
                    Button("d7.chain.mine.useEntry") { content = original }
                        .disabled(!flow.canJoin)
                }
            }
            if page.chain.canParticipate {
                TextField("d7.chain.mine.field", text: $content, axis: .vertical).disabled(!flow.canJoin)
                if page.mine?.status == "ACTIVE" {
                    Button("d7.chain.mine.update") { flow.prepareJoin(content: content) }
                        .disabled(!flow.canJoin)
                } else {
                    Button("d7.chain.mine.join") { flow.prepareJoin(content: content) }
                        .disabled(!flow.canJoin)
                }
                if page.mine?.status == "ACTIVE" {
                    Button("d7.chain.mine.withdraw", role: .destructive) { flow.prepareWithdraw() }
                        .disabled(!flow.canWithdraw)
                }
            } else {
                Text("d7.chain.mine.cannotJoin")
                    .foregroundStyle(.secondary)
            }
            if flow.canClose {
                Button("d7.chain.close", role: .destructive) { flow.prepareClose() }
            }
        } header: { Text("d7.chain.mine") }
    }
    private func chainTitle(_ raw: String) -> String {
        let shown = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return shown.isEmpty ? "—" : shown
    }
    private func chainEntry(_ entry: NativeChannelChainEntry) -> some View {
        let active = entry.status == "ACTIVE"
        let shown = entry.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return LabeledContent {
            Text(verbatim: entry.position).monospacedDigit()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    if active { Text(verbatim: shown.isEmpty ? "—" : shown) } else { Text("d7.chain.withdrawn").foregroundStyle(.secondary) }
                    if entry.memberId == flow.service.actorID {
                        Label("d7.chain.me", systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                ChainEntryMark(seed: active ? "chain-\(entry.position)" : "chain-\(entry.position)-out")
            }
        }
    }
    @ViewBuilder private func chainStatusChip(_ page: NativeChannelChainPage) -> some View {
        if page.chain.status == "CLOSED" {
            Label("d7.chain.status.closed", systemImage: "lock").foregroundStyle(.secondary)
        } else if page.chain.accepting {
            Label("d7.chain.status.open", systemImage: "checkmark.circle").foregroundStyle(CYColor.successText)
        } else {
            Label("d7.chain.status.ended", systemImage: "clock").foregroundStyle(CYColor.warningText)
        }
    }
    @ViewBuilder private var status: some View {
        switch flow.phase {
        case .reading:
            ProgressView { Text("d7.channelActivity.loading") }
                .frame(maxWidth: .infinity)
        case .submitting:
            ProgressView("d7.channelActivity.sending")
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
        case .unknown: Text("d7.chain.notice.unknown").nativeChannelNotice(systemImage: "clock")
        case .applied: Text("d7.chain.notice.applied")
        case .appliedRedacted: Text("d7.chain.notice.redacted").nativeChannelNotice(systemImage: "checkmark.circle")
        case .rejected(let code):
            if code == "SCREENING_PENDING" { Text("d7.channelActivity.rulesPending").nativeChannelNotice(systemImage: "exclamationmark.circle") }
            else { Text("d7.chain.notice.rejected").nativeChannelNotice(systemImage: "exclamationmark.circle") }
        case .persistenceFailed: Text("d7.channelActivity.saveFailed").nativeChannelNotice(systemImage: "exclamationmark.circle")
        default: EmptyView()
        }
    }
    @ViewBuilder private func reviewSection(_ command: NativeChannelChainCommand) -> some View {
        Section {
            Text(label(command.operation)).font(.headline)
            if let title = command.title { Text(verbatim: title) }
            if let slots = command.maxSlots {
                LabeledContent("d7.chain.review.maxSlots") {
                    if slots == 0 { Text("d7.chain.review.unlimited") } else { Text("d7.chain.review.people \(slots)").monospacedDigit() }
                }
            }
            if let end = command.deadlineAt {
                LabeledContent("d7.chain.deadline") { Text(Date(timeIntervalSince1970: Double(end) / 1000), format: .dateTime.month().day().hour().minute()) }
            }
            if let text = command.content { Text(verbatim: text) }
            Button("d7.chain.review.confirm") {
                run { current in await flow.confirm(); guard current() else { return }; await refreshAfterSettlement() }
            }
            .disabled(flow.busy)
            Button("d7.channelActivity.cancel", role: .cancel) { flow.cancelReview() }
                .disabled(flow.busy)
        } header: { Text("d7.chain.review.title") }
    }
    @ViewBuilder private func recoverySection(_ command: NativeChannelChainCommand) -> some View {
        Section {
            if flow.ownsPending {
                Text(label(command.operation)).font(.headline)
                if let title = command.title { Text(verbatim: title) }
                if let text = command.content { Text(verbatim: text) }
                Button("d7.chain.pending.check") {
                    run { current in await flow.recover(); guard current() else { return }; await refreshAfterSettlement() }
                }
                .disabled(flow.busy || !flow.service.canRecover)
                Button("d7.chain.pending.retry") { retryPresented = true }
                    .disabled(flow.busy || !flow.service.canRecover || !flow.service.allows(command.operation))
            } else {
                Text("d7.chain.pending.other")
            }
        } header: { Text("d7.chain.pending.title") }
    }
    private func label(_ operation: NativeChannelChainCommand.Operation) -> LocalizedStringKey {
        switch operation { case .create: return "d7.chain.op.create"; case .join: return "d7.chain.op.join"; case .withdraw: return "d7.chain.op.withdraw"; case .close: return "d7.chain.op.close" }
    }
    private func run(_ work: @escaping NativeChannelActivityScreenWork) {
        operation.start(current: { available && flow.isCurrent }, work: work)
    }
    private func retireScreen() {
        operation.retire(); flow.deactivate(); clearDraft()
    }
    private func refreshAfterSettlement() async {
        guard flow.isCurrent, flow.pending == nil, flow.reference != nil,
              flow.phase != .appliedRedacted, flow.phase != .persistenceFailed else { return }
        content = ""; title = ""
        await flow.refresh()
    }
    private func clearDraft() { title = ""; content = ""; maxSlots = "0"; hasDeadline = false; retryPresented = false }
}

private struct ChainEntryMark: View {
    let seed: String
    var body: some View {
        CYCoverArt(seed: seed, symbol: "text.quote", showsDebugLabel: false, cornerRadius: CYRadius.sm)
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }
}

/// Local presentation work only. The activity flow remains the sole writer/journal owner.
/// Retiring a screen releases its task slot even when a transport ignores cancellation.
typealias NativeChannelActivityScreenWork = @MainActor (_ current: @escaping @MainActor () -> Bool) async -> Void
@MainActor final class NativeChannelActivityScreenTask {
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0
    var isRunning: Bool { task != nil }
    func start(current sourceCurrent: @escaping @MainActor () -> Bool,
               work: @escaping NativeChannelActivityScreenWork) {
        guard task == nil, sourceCurrent() else { return }
        generation &+= 1
        let ticket = generation
        task = Task { @MainActor in
            defer { if generation == ticket { task = nil } }
            let current: @MainActor () -> Bool = {
                !Task.isCancelled && self.generation == ticket && sourceCurrent()
            }
            guard current() else { return }
            await work(current)
        }
    }
    func retire() {
        generation &+= 1
        task?.cancel(); task = nil
    }
}
