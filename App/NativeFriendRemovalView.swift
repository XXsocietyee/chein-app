import SwiftUI

@MainActor final class NativeFriendRemovalViewModel: ObservableObject {
    let flow: NativeFriendRemovalFlow
    init(_ flow: NativeFriendRemovalFlow, onResolved: @escaping () -> Void) {
        self.flow = flow; flow.onChange = { [weak self] in self?.objectWillChange.send() }; flow.onResolved = onResolved
    }
}

/// The original real-row identity remains visible. No numeric peer input, block action or conversation creation.
@MainActor struct NativeFriendRemovalView: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: NativeFriendRemovalViewModel
    @State private var confirmingRetry = false
    @State private var confirmingRemoval = false
    @State private var retryCommand: NativeFriendRemovalCommand?
    @State private var operationTask: Task<Void, Never>?
    init(flow: NativeFriendRemovalFlow, onResolved: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: NativeFriendRemovalViewModel(flow, onResolved: onResolved))
    }
    private var flow: NativeFriendRemovalFlow { model.flow }
    private var recoverIsPrimary: Bool { flow.pending != nil && flow.review == nil }
    var body: some View {
        Form {
            Section {
                CYHeroHeader("friendRemoval.title", tableName: "NativeFriendRemoval")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
            if let item = flow.presentationItem {
                Section {
                    CYListRow(verbatim: item.displayName, trailing: .none) { personArt(item.displayName) }
                        .accessibilityIdentifier("friendRemoval.target")
                }
            }
            if flow.busy {
                CYSkeleton()
                    .accessibilityLabel(Text("cy.state.loading"))
                    .accessibilityIdentifier("friendRemoval.loading")
            }
            if flow.phase == .closed { notice("friendRemoval.closed") }
            if let issue = flow.issue { notice(issue, symbol: "exclamationmark.triangle", identifier: "friendRemoval.issue") }
            if flow.pending != nil {
                Section {
                    notice("friendRemoval.unknown")
                    removalAction("friendRemoval.recover", style: recoverIsPrimary ? .primary : .secondary, enabled: flow.canRecover, identifier: "friendRemoval.recover") {
                        perform { await flow.recover() }
                    }
                    removalAction("friendRemoval.retryOriginal", style: .secondary, enabled: flow.canRetryOriginal, identifier: "friendRemoval.retryOriginal") {
                        retryCommand = flow.pendingCommand; confirmingRetry = true
                    }
                }
            } else if flow.item == nil && flow.result == nil && flow.phase == .ready {
                CYEmptyState(systemImage: "checkmark.circle", "friendRemoval.noPending", tableName: "NativeFriendRemoval")
            }
            if let result = flow.result {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                        Image(systemName: result.outcome == "APPLIED" ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(result.outcome == "APPLIED" ? palette.success : palette.danger)
                            .accessibilityHidden(true)
                        text(result.outcome == "APPLIED" ? "friendRemoval.applied" : "friendRemoval.rejected")
                            .cyText(.body)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("friendRemoval.outcome")
                    }
                }
            }
            if let current = flow.currentRelationship {
                Section {
                    LabeledContent {
                        text(current.state == .friend ? "friendRemoval.currentFriend" : "friendRemoval.currentNotFriend")
                            .accessibilityIdentifier("friendRemoval.current")
                    } label: { text("friendRemoval.currentTitle") }
                }
            }
            if flow.review != nil || (flow.item != nil && flow.result == nil && flow.pending == nil) {
                Section {
                    Button(role: .destructive) {
                        if flow.review == nil { flow.reviewRemoval() }
                        confirmingRemoval = flow.review != nil
                    } label: { text("friendRemoval.review").frame(maxWidth: .infinity) }
                        .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                        .disabled(!(flow.canReview || flow.canConfirm))
                        .accessibilityIdentifier("friendRemoval.review")
                        .listRowBackground(Color.clear)
                }
            }
        }
        .formStyle(.grouped)
        .cyText(.body)
        .cyGroupedSurface()
        .cyHeroScreen()
        .accessibilityIdentifier("friendRemoval.home")
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .task { await flow.load() }
        .onDisappear { suspend() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { perform { await flow.load() } }
            else { suspend() }
        }
        .onChange(of: flow.isCurrent) { _, current in
            if !current { cancelOperation() }
        }
        // The sheet only presents the flow's own review; swipe-dismissing keeps the review open while Cancel clears it.
        .sheet(isPresented: $confirmingRemoval) {
            CYConfirmSheet(
                title: localized("d7.friendRemoval.confirmTitle"),
                message: localized("friendRemoval.impact"),
                confirmTitle: localized("friendRemoval.confirm"),
                cancelTitle: localized("friendRemoval.cancel"),
                isDestructive: true,
                confirmDisabled: !flow.canConfirm,
                confirmIdentifier: "friendRemoval.confirm",
                cancelIdentifier: "friendRemoval.cancel",
                consequences: [
                    CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: localized("friendRemoval.impact"))
                ],
                onCancel: { flow.cancelReview() }
            ) {
                guard let confirmed = flow.review else { return }
                perform { await flow.confirm(confirmed: confirmed) }
            }
            .cyDomainSheet(detents: [.half, .full])
        }
        .sheet(isPresented: $confirmingRetry, onDismiss: { retryCommand = nil }) {
            CYConfirmSheet(
                title: localized("friendRemoval.retryTitle"),
                message: localized("friendRemoval.retryImpact"),
                confirmTitle: localized("friendRemoval.retryConfirm"),
                cancelTitle: localized("friendRemoval.keepPending"),
                isDestructive: true,
                consequences: [
                    CYConfirmConsequence(systemImage: "arrow.clockwise", text: localized("friendRemoval.retryImpact"))
                ]
            ) {
                guard let confirmed = retryCommand else { return }
                retryCommand = nil
                perform { await flow.retryOriginal(confirmed: confirmed) }
            }
            .cyDomainSheet(detents: [.half, .full])
        }
        .tint(palette.brand)
    }
    private func removalAction(_ key: String, style: CYPillStyle, enabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        CYPillButton(LocalizedStringKey(key), style: style, tableName: "NativeFriendRemoval", action: action)
            .disabled(!enabled)
            .accessibilityIdentifier(identifier)
            .listRowBackground(Color.clear)
    }
    private func notice(_ key: String, symbol: String? = nil, identifier: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(palette.warning).accessibilityHidden(true)
            }
            text(key)
                .cyText(.body)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(CYOptionalAccessibilityIdentifier(identifier: identifier))
        }
    }
    private func personArt(_ seed: String) -> some View {
        Color.clear
            .frame(width: 40, height: 40)
            .overlay { CYCoverArt(seed: seed.isEmpty ? "friend" : seed, symbol: "person.fill", showsDebugLabel: false) }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
    private func perform(_ operation: @escaping @MainActor () async -> Void) {
        // A repeated tap must not cancel an already-dispatched original command.
        guard !flow.busy else { return }
        operationTask?.cancel()
        operationTask = Task {
            guard !Task.isCancelled else { return }
            await operation()
        }
    }
    private func cancelOperation() {
        operationTask?.cancel(); operationTask = nil
        confirmingRetry = false; retryCommand = nil; confirmingRemoval = false
    }
    private func suspend() {
        cancelOperation(); flow.invalidate()
    }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeFriendRemoval") }
    private func localized(_ key: String) -> String { String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeFriendRemoval", locale: locale)) }
}

#if DEBUG
/// UI-only synthetic transport. It hosts the same ordinary friend list, confirmation and recovery screens.
@MainActor final class NativeFriendRemovalFixtureState: ObservableObject, NativeFriendServing, NativeFriendRemovalServing {
    final class Journal: OperationPendingListing {
        var rows: [OperationPendingRecord] = []
        func pending(ownerKey: String, targetKey: String) throws -> OperationPendingRecord? { rows.first { $0.ownerKey == ownerKey && $0.targetKey == targetKey } }
        func pendingRecords(ownerKey: String) throws -> [OperationPendingRecord] { rows.filter { $0.ownerKey == ownerKey } }
        func write(_ record: OperationPendingRecord) throws { rows.append(record) }
        func clear(_ record: OperationPendingRecord) throws { rows.removeAll { $0 == record } }
    }
    let journal = Journal()
    var viewerID: Int64 = 2
    var isCurrent = true
    var canWrite = true
    var canSettle = true
    @Published var removeCount = 0
    @Published var receiptCount = 0
    @Published var settleCount = 0
    var currentFriend = true
    var terminal: [UUID: NativeFriendRemovalReceipt] = [:]
    let loseResponse: Bool
    let item = NativeFriendItem(peerID: 9, nickname: "Synthetic friend", state: .friend, version: 3, message: "", expiresAtMS: 0)
    lazy var home = NativeFriendFlow(service: self, journal: journal, ownerKey: "removal-fixture-friend")
    init(loseResponse: Bool = ProcessInfo.processInfo.arguments.contains("--friend-removal-unknown")) { self.loseResponse = loseResponse }
    func makeRemoval(item: NativeFriendItem?) -> NativeFriendRemovalFlow { .init(item: item, service: self, journal: journal, ownerKey: "removal-fixture-owner-2") }
    func relationship(peerID: Int64) async throws -> NativeFriendRelationship {
        .init(viewerID: viewerID, peerID: peerID, state: currentFriend ? .friend : .none, version: currentFriend ? 3 : 4, conversationID: 80)
    }
    func page(requests: Bool, cursor: Int64) async throws -> NativeFriendPage {
        .init(viewerID: viewerID, incoming: [], outgoing: [], friends: !requests && currentFriend ? [item] : [], hasMore: false, nextCursor: nil)
    }
    func write(_ command: NativeFriendCommand) async throws -> NativeFriendReceipt { throw NativeFriendFailure.notSent }
    func receipt(peerID: Int64, action: NativeFriendAction, requestID: String) async throws -> NativeFriendReceipt { throw NativeFriendFailure.notSent }
    func remove(_ command: NativeFriendRemovalCommand) async throws -> NativeFriendRemovalReceipt {
        removeCount += 1
        if let previous = terminal[command.requestID] { return previous }
        currentFriend = false
        let result = NativeFriendRemovalReceipt(viewerID: viewerID, command: command, outcome: "APPLIED", reason: "REMOVED", removedVersion: command.expectedVersion + 1, currentRelationship: try await relationship(peerID: command.peerID))
        terminal[command.requestID] = result
        if loseResponse { throw NativeFriendFailure.unknown }; return result
    }
    func receipt(_ command: NativeFriendRemovalCommand) async throws -> NativeFriendRemovalReceipt {
        receiptCount += 1
        if let previous = terminal[command.requestID] { return previous }
        return .init(viewerID: viewerID, command: command, outcome: "UNKNOWN", currentRelationship: try await relationship(peerID: command.peerID))
    }
    func settle(_ command: NativeFriendRemovalCommand) async throws -> NativeFriendRemovalReceipt {
        settleCount += 1
        if let previous = terminal[command.requestID] { return previous }
        let result = NativeFriendRemovalReceipt(viewerID: viewerID, command: command, outcome: "REJECTED", reason: "FINALIZED_WITHOUT_REMOVAL", currentRelationship: try await relationship(peerID: command.peerID))
        terminal[command.requestID] = result; return result
    }
}
@MainActor struct NativeFriendRemovalFixtureHost: View {
    @StateObject private var state = NativeFriendRemovalFixtureState()
    var body: some View {
        VStack {
            NavigationStack {
                NativeFriendHomeView(flow: state.home, removalFactory: { state.makeRemoval(item: $0) }, conversation: { _ in AnyView(Text(verbatim: "Existing synthetic chat")) })
            }
            Text(verbatim: "\(state.removeCount)/\(state.receiptCount)/\(state.settleCount)").accessibilityIdentifier("friendRemoval.fixture.counts")
        }
    }
}
#endif
