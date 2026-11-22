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
            else if attempted { CYEmptyState(systemImage: "list.number", "d7.chain.unavailable") }
            else {
                CYSkeleton()
                    .padding(CYSpacing.lg)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("d7.channelActivity.loading"))
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
    @Environment(\.cyPalette) private var palette
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
            Section {
                CYHeroHeader("d7.chain.title")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: CYSpacing.lg))
                    .listRowSeparator(.hidden)
            }
            if !flow.isCurrent { CYEmptyState(systemImage: "list.number", "d7.chain.unavailable").listRowBackground(Color.clear) }
            else {
                status
                // A confirmed original receipt survives a separate current-roster read failure.
                // Scope/account/receipt authority still gates this memory-only projection.
                if let confirmed = flow.lastConfirmedRequest {
                    Section {
                        CYListRow(label(confirmed.operation), trailing: .none) { CYRowIcon(systemImage: "checkmark.circle") }
                    } header: { CYSectionHeader("d7.chain.done").textCase(nil) }
                        .accessibilityIdentifier("channel.chain.originalReceipt")
                }
                if let review = flow.review { reviewSection(review) }
                else if let pending = flow.pending { recoverySection(pending) }
                if let page = flow.page { chainPage(page) }
                else if flow.reference != nil, !flow.busy, flow.phase != .appliedRedacted {
                    CYEmptyState(systemImage: "list.number", "d7.chain.loadFailed", actionTitle: "d7.channelActivity.retry", actionStyle: flow.review == nil ? .primary : .secondary) {
                        run { _ in await flow.refresh() }
                    }
                    .disabled(!flow.service.canRead || flow.review != nil)
                    .listRowBackground(Color.clear)
                } else if flow.reference == nil, flow.pending == nil, flow.review == nil {
                    createSection
                }
            }
        }
        .nativeChannelScreen()
        .cyHeroScreen()
        .privacySensitive()
        .task(id: available) {
            if available { await flow.activate(current: current) }
            else { retireScreen() }
        }
        .onChange(of: current()) { _, valid in if !valid { retireScreen() } }
        .onChange(of: scene) { _, phase in if phase != .active { retireScreen() } }
        .onDisappear { retireScreen() }
        .sheet(isPresented: $retryPresented) {
            CYConfirmSheet(
                title: appLocalized("d7.chain.retry.title", locale: locale),
                message: "",
                confirmTitle: appLocalized("d7.channelActivity.retry", locale: locale),
                cancelTitle: appLocalized("d7.channelActivity.cancel", locale: locale)
            ) {
                run { current in await flow.retryOriginal(); guard current() else { return }; await refreshAfterSettlement() }
            }
            .cyDomainSheet(detents: [.peek, .half])
        }
    }
    @ViewBuilder private func chainPage(_ page: NativeChannelChainPage) -> some View {
        Section {
            CYImageCard(verbatim: chainTitle(page.chain.title), fallback: "d7.chain.title", style: .hero)
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.lg, bottom: CYSpacing.sm, trailing: CYSpacing.lg))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            LabeledContent("d7.chain.status") { chainStatusChip(page) }
                .cyText(.body)
            LabeledContent("d7.chain.joined") {
                if page.chain.maxSlots == 0 { Text("d7.chain.joined.unlimited \(page.chain.activeCount)").monospacedDigit() }
                else { Text("d7.chain.joined.limited \(page.chain.activeCount) \(page.chain.maxSlots)").monospacedDigit() }
            }
            .cyText(.body)
            if let end = page.chain.deadlineAt {
                LabeledContent("d7.chain.deadline") { Text(Date(timeIntervalSince1970: Double(end) / 1000), format: .dateTime.month().day().hour().minute()) }
                    .cyText(.body)
            }
            CYPillButton("d7.channelActivity.refresh", style: .secondary) { run { _ in await flow.refresh() } }
                .disabled(flow.busy || flow.review != nil)
                .listRowBackground(Color.clear)
        }
        Section {
            if flow.entries.isEmpty {
                Label("d7.chain.entries.empty", systemImage: "tray")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    .accessibilityElement(children: .combine)
            }
            ForEach(flow.entries) { entry in chainEntry(entry) }
            if page.hasMore {
                CYPillButton("d7.chain.showMore", style: .secondary) { run { _ in await flow.more() } }
                    .disabled(flow.busy || flow.review != nil)
                    .listRowBackground(Color.clear)
            }
        } header: { CYSectionHeader("d7.chain.entries").textCase(nil) }
        if flow.pending == nil, flow.review == nil { mineSection(page) }
    }
    @ViewBuilder private var createSection: some View {
        if flow.service.allows(.create), flow.service.canRead, flow.service.canRecover {
            Section {
                TextField("d7.chain.create.title", text: $title)
                TextField("d7.chain.create.maxSlots", text: $maxSlots).keyboardType(.numberPad)
                Toggle("d7.chain.create.hasDeadline", isOn: $hasDeadline)
                if hasDeadline { DatePicker("d7.chain.deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute]) }
                CYPillButton("d7.chain.create.submit") {
                    guard let maximum = Int(maxSlots) else { return }
                    flow.prepareCreate(title: title, maxSlots: maximum, deadline: hasDeadline ? deadline : nil)
                }
                .disabled(!flow.canCreate || Int(maxSlots) == nil)
                .listRowBackground(Color.clear)
            } header: { CYSectionHeader("d7.chain.create").textCase(nil) }
            .disabled(!flow.canCreate)
        } else {
            CYEmptyState(systemImage: "list.number", "d7.chain.unavailable").listRowBackground(Color.clear)
        }
    }
    @ViewBuilder private func mineSection(_ page: NativeChannelChainPage) -> some View {
        Section {
            if let mine = page.mine {
                if mine.status == "ACTIVE" { LabeledContent("d7.chain.status") { Text("d7.chain.mine.joined \(mine.position)").monospacedDigit() } }
                else { LabeledContent("d7.chain.status") { Text("d7.chain.withdrawn") } }
                if mine.status == "ACTIVE", let original = mine.content, page.chain.canParticipate {
                    CYPillButton("d7.chain.mine.useEntry", style: .secondary) { content = original }
                        .disabled(!flow.canJoin)
                        .listRowBackground(Color.clear)
                }
            }
            if page.chain.canParticipate {
                TextField("d7.chain.mine.field", text: $content, axis: .vertical).disabled(!flow.canJoin)
                if page.mine?.status == "ACTIVE" {
                    CYPillButton("d7.chain.mine.update") { flow.prepareJoin(content: content) }
                        .disabled(!flow.canJoin)
                        .listRowBackground(Color.clear)
                } else {
                    CYPillButton("d7.chain.mine.join") { flow.prepareJoin(content: content) }
                        .disabled(!flow.canJoin)
                        .listRowBackground(Color.clear)
                }
                if page.mine?.status == "ACTIVE" {
                    Button("d7.chain.mine.withdraw", role: .destructive) { flow.prepareWithdraw() }
                        .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                        .disabled(!flow.canWithdraw)
                        .listRowBackground(Color.clear)
                }
            } else {
                Text("d7.chain.mine.cannotJoin")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if flow.canClose {
                Button("d7.chain.close", role: .destructive) { flow.prepareClose() }
                    .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                    .listRowBackground(Color.clear)
            }
        } header: { CYSectionHeader("d7.chain.mine").textCase(nil) }
    }
    private func chainTitle(_ raw: String) -> String {
        let shown = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return shown.isEmpty ? "—" : shown
    }
    private func chainEntry(_ entry: NativeChannelChainEntry) -> some View {
        let active = entry.status == "ACTIVE"
        let shown = entry.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if active {
                CYListRow(verbatim: shown.isEmpty ? "—" : shown, trailing: .value(entry.position)) {
                    ChainEntryMark(seed: "chain-\(entry.position)")
                }
            } else {
                CYListRow("d7.chain.withdrawn", trailing: .value(entry.position)) {
                    ChainEntryMark(seed: "chain-\(entry.position)-out")
                }
            }
            if entry.memberId == flow.service.actorID {
                CYStatusChip("d7.chain.me", systemImage: "person")
            }
        }
    }
    @ViewBuilder private func chainStatusChip(_ page: NativeChannelChainPage) -> some View {
        if page.chain.status == "CLOSED" {
            CYStatusChip("d7.chain.status.closed", tone: .neutral, systemImage: "lock")
        } else if page.chain.accepting {
            CYStatusChip("d7.chain.status.open", tone: .success, systemImage: "checkmark.circle")
        } else {
            CYStatusChip("d7.chain.status.ended", tone: .warning, systemImage: "clock")
        }
    }
    @ViewBuilder private var status: some View {
        switch flow.phase {
        case .reading:
            CYSkeleton()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("d7.channelActivity.loading"))
                .listRowBackground(Color.clear)
        case .submitting:
            ProgressView("d7.channelActivity.sending")
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
        case .unknown: Text("d7.chain.notice.unknown").nativeChannelNotice(systemImage: "clock")
        case .applied: Text("d7.chain.notice.applied").cyText(.body).fixedSize(horizontal: false, vertical: true)
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
            Text(label(command.operation)).cyText(.sectionTitle).fixedSize(horizontal: false, vertical: true)
            if let title = command.title { Text(verbatim: title).cyText(.body).fixedSize(horizontal: false, vertical: true) }
            if let slots = command.maxSlots {
                LabeledContent("d7.chain.review.maxSlots") {
                    if slots == 0 { Text("d7.chain.review.unlimited") } else { Text("d7.chain.review.people \(slots)").monospacedDigit() }
                }
            }
            if let end = command.deadlineAt {
                LabeledContent("d7.chain.deadline") { Text(Date(timeIntervalSince1970: Double(end) / 1000), format: .dateTime.month().day().hour().minute()) }
            }
            if let text = command.content { Text(verbatim: text).cyText(.body).fixedSize(horizontal: false, vertical: true) }
            CYPillButton("d7.chain.review.confirm") {
                run { current in await flow.confirm(); guard current() else { return }; await refreshAfterSettlement() }
            }
            .disabled(flow.busy)
            .listRowBackground(Color.clear)
            Button("d7.channelActivity.cancel", role: .cancel) { flow.cancelReview() }
                .cyText(.label)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                .disabled(flow.busy)
        } header: { CYSectionHeader("d7.chain.review.title").textCase(nil) }
    }
    @ViewBuilder private func recoverySection(_ command: NativeChannelChainCommand) -> some View {
        Section {
            if flow.ownsPending {
                Text(label(command.operation)).cyText(.sectionTitle).fixedSize(horizontal: false, vertical: true)
                if let title = command.title { Text(verbatim: title).cyText(.body).fixedSize(horizontal: false, vertical: true) }
                if let text = command.content { Text(verbatim: text).cyText(.body).fixedSize(horizontal: false, vertical: true) }
                CYPillButton("d7.chain.pending.check", style: .secondary) {
                    run { current in await flow.recover(); guard current() else { return }; await refreshAfterSettlement() }
                }
                .disabled(flow.busy || !flow.service.canRecover)
                .listRowBackground(Color.clear)
                CYPillButton("d7.chain.pending.retry", style: .tertiary) { retryPresented = true }
                    .disabled(flow.busy || !flow.service.canRecover || !flow.service.allows(command.operation))
                    .listRowBackground(Color.clear)
            } else {
                Text("d7.chain.pending.other").cyText(.body).fixedSize(horizontal: false, vertical: true)
            }
        } header: { CYSectionHeader("d7.chain.pending.title").textCase(nil) }
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
