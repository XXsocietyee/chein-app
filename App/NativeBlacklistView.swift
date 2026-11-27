import SwiftUI

@MainActor final class NativeBlacklistViewModel: ObservableObject {
    let flow: NativeBlacklistFlow
    init(_ flow: NativeBlacklistFlow) { self.flow = flow; flow.onChange = { [weak self] in self?.objectWillChange.send() } }
}
/// Ordinary owner management, intentionally independent of conversations and numeric peer entry.
@MainActor struct NativeBlacklistView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @StateObject private var model: NativeBlacklistViewModel
    @State private var settlement: NativeBlacklistCommand?
    @State private var confirmingSettlement = false
    @State private var visit: UUID?
    @State private var visible = false
    init(flow: NativeBlacklistFlow) { _model = StateObject(wrappedValue: NativeBlacklistViewModel(flow)) }
    private var flow: NativeBlacklistFlow { model.flow }
    var body: some View {
        List {
            if flow.busy {
                ProgressView { Text("cy.state.loading") }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("blacklist.loading")
            }
            if flow.phase == .closed {
                ContentUnavailableView {
                    Label { text("blacklist.closed") } icon: { Image(systemName: "lock") }
                }
                .accessibilityIdentifier("blacklist.closed")
            }
            if flow.phase == .failed {
                ContentUnavailableView {
                    Label { Text(LocalizedStringKey(flow.issue ?? "blacklist.readFailure"), tableName: "NativeBlacklist") } icon: { Image(systemName: "exclamationmark.triangle") }
                        .accessibilityIdentifier("blacklist.issue")
                } actions: {
                    Button { performPresented { await flow.load() } } label: { text("blacklist.retry") }
                        .buttonStyle(.bordered)
                        .disabled(flow.busy)
                        .accessibilityIdentifier("blacklist.retry")
                }
            } else if let issue = flow.issue, !(flow.pendingCommand != nil && issue == "blacklist.unknown") {
                Section {
                    Label(localized(issue), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("blacklist.issue")
                }
            }
            if flow.phase == .ready || flow.phase == .reviewing {
                if flow.items.isEmpty && !flow.busy {
                    ContentUnavailableView {
                        Label { text("blacklist.empty") } icon: { Image(systemName: "person.crop.circle.badge.checkmark") }
                    }
                    .accessibilityIdentifier("blacklist.empty")
                } else if !flow.items.isEmpty {
                    Section {
                        ForEach(flow.items) { item in
                            Label {
                                Text(verbatim: item.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : item.nickname)
                            } icon: {
                                Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("blacklist.row.\(item.peerID)")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if flow.canReview {
                                    Button { performPresented { await flow.reviewUnblock(item) } } label: { text("blacklist.review") }
                                        .tint(.red)
                                        .accessibilityIdentifier("blacklist.review.\(item.peerID)")
                                }
                            }
                        }
                        if flow.nextCursor != nil {
                            Button { performPresented { await flow.loadMore() } } label: { text("blacklist.more") }
                            .disabled(flow.busy)
                            .accessibilityIdentifier("blacklist.more")
                        }
                    }
                }
            }
            if let original = flow.pendingCommand {
                Section {
                    text("blacklist.unknown")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("blacklist.original")
                    Text(verbatim: "\(original.peerID)\n\(original.expectedBlockID)\n\(original.requestID.uuidString)")
                        .font(.footnote.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        .accessibilityIdentifier("blacklist.originalIdentity")
                    Button { performPresented { await flow.recover() } } label: { text("blacklist.recover") }
                    .disabled(!flow.canRecover)
                    .accessibilityIdentifier("blacklist.recover")
                    Button(role: .destructive) {
                        settlement = original
                        confirmingSettlement = true
                    } label: { text("blacklist.settle") }
                    .disabled(!flow.canSettle)
                    .accessibilityIdentifier("blacklist.settle")
                }
            }
            if let result = flow.result {
                Section {
                    Label(localized(result.outcome == "APPLIED" ? "blacklist.applied" : "blacklist.rejected"),
                          systemImage: result.outcome == "APPLIED" ? "checkmark.circle" : "xmark.circle")
                        .foregroundStyle(result.outcome == "APPLIED" ? Color.green : Color.red)
                        .accessibilityIdentifier("blacklist.outcome")
                    text("blacklist.historical")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: "\(result.peerID)\n\(result.requestID)")
                        .font(.footnote.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        .accessibilityIdentifier("blacklist.resultIdentity")
                    if let current = flow.current {
                        Label(localized(current.blocked ? "blacklist.currentBlocked" : "blacklist.currentUnblocked"),
                              systemImage: current.blocked ? "hand.raised" : "person")
                            .foregroundStyle(current.blocked ? Color.orange : Color.green)
                            .accessibilityIdentifier("blacklist.current")
                    } else {
                        text("blacklist.currentFailure")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button { performPresented { await flow.retryReadback() } } label: { text("blacklist.refreshCurrent") }
                    .disabled(flow.busy)
                    .accessibilityIdentifier("blacklist.refreshCurrent")
                    Button { performPresented { await flow.load() } } label: { text("blacklist.returnList") }
                    .disabled(flow.busy)
                    .accessibilityIdentifier("blacklist.returnList")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(text("blacklist.title"))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .accessibilityIdentifier("blacklist.home")
        .onAppear { visible = true; if scenePhase == .active { visit = UUID(); performPresented { await flow.load() } } }
        .onDisappear { visible = false; close() }
        .onChange(of: scenePhase) { _, phase in
            close()
            if phase == .active, visible { visit = UUID(); performPresented { await flow.load() } }
        }
        .onChange(of: flow.isCurrent) { _, current in if !current { close() } }
        // Pull to refresh replaces the toolbar refresh button; same guards as before.
        .refreshable {
            guard visible, scenePhase == .active, visit != nil, !flow.busy, flow.review == nil, flow.pending == nil else { return }
            await flow.load()
        }
        .cySheet(isPresented: Binding(get: { flow.review != nil && flow.selected != nil }, set: { if !$0 { flow.cancelReview() } })) {
            reviewSheet
        }
        .confirmationDialog(localized("blacklist.settleTitle"), isPresented: $confirmingSettlement, titleVisibility: .visible) {
            Button(localized("blacklist.settleConfirm"), role: .destructive) {
                guard let original = settlement else { return }; settlement = nil
                performPresented { await flow.settleOriginal(confirmed: original) }
            }
            Button(localized("blacklist.cancel"), role: .cancel) { settlement = nil }
        } message: {
            text("blacklist.settleImpact")
        }
    }
    /// Compact unblock review: the person, one destructive action and Cancel.
    @ViewBuilder private var reviewSheet: some View {
        if let review = flow.review, let item = flow.selected {
            NavigationStack {
                List {
                    Section {
                        Label {
                            Text(verbatim: item.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : item.nickname)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("blacklist.exactPeer")
                        } icon: {
                            Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                        }
                        Text(verbatim: "\(review.expectedBlockID)\n\(review.requestID.uuidString)")
                            .font(.footnote.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                            .accessibilityIdentifier("blacklist.reviewIdentity")
                        text("blacklist.confirmImpact")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Section {
                        Button(role: .destructive) { performPresented { await flow.confirm(expected: review) } } label: { text("blacklist.confirm") }
                            .disabled(!flow.canConfirm)
                            .accessibilityIdentifier("blacklist.confirm")
                    }
                }
                .navigationTitle(text("d7.blacklist.reviewTitle"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { flow.cancelReview() } label: { text("blacklist.cancel") }
                            .disabled(flow.busy)
                            .accessibilityIdentifier("blacklist.cancel")
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    private func performPresented(_ action: @escaping @MainActor () async -> Void) {
        guard visible, scenePhase == .active, let capturedVisit = visit else { return }
        let capturedFlow = flow
        Task { @MainActor in
            guard visible, scenePhase == .active, visit == capturedVisit, flow === capturedFlow else { return }
            await action()
        }
    }
    private func close() { visit = nil; settlement = nil; confirmingSettlement = false; flow.invalidate() }
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "NativeBlacklist") }
    private func localized(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeBlacklist", locale: locale))
    }
}
