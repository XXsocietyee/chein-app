import SwiftUI

/// Sheet item for one retained safety owner. The owner, not the sheet, keeps a
/// pending/unknown action alive if the sheet is dismissed.
struct IMSafetyPresentation: Identifiable {
    let id = UUID()
    let owner: IMSafetyCoordinator
}

@MainActor final class IMSafetyModel: ObservableObject {
    let owner: IMSafetyCoordinator
    @Published private(set) var state: IMSafetyState
    init(owner: IMSafetyCoordinator) {
        self.owner = owner; state = owner.visibleState
        owner.onChange = { [weak self] in self?.state = self?.owner.visibleState ?? .idle }
    }
}

/// Mini-program cy-danger-confirm keys `im.conversation.delete` and `im.block`
/// (utils/danger-actions.js); report/unblock get the same explicit review on iOS.
struct IMSafetyCopy {
    let titleKey: String
    let contentKey: String?
    let consequenceKeys: [String]
    let confirmKey: String
    let doneKey: String
    let doneDetailKey: String?
    let failureKey: String
    init(_ action: IMSafetyAction) {
        switch action {
        case .hide:
            titleKey = "im.safety.hide.title"; contentKey = "im.safety.hide.content"
            consequenceKeys = ["im.safety.hide.consequence1", "im.safety.hide.consequence2"]
            confirmKey = "im.safety.hide.confirm"; doneKey = "im.safety.hide.done"; doneDetailKey = nil
            failureKey = "im.safety.hide.failed"
        case .block:
            titleKey = "im.safety.block.title"; contentKey = nil
            consequenceKeys = ["im.safety.block.consequence1", "im.safety.block.consequence2"]
            confirmKey = "im.safety.block.confirm"; doneKey = "im.safety.block.done"; doneDetailKey = "im.safety.block.doneDetail"
            failureKey = "im.safety.block.failed"
        case .unblock:
            titleKey = "im.safety.unblock.title"; contentKey = nil; consequenceKeys = ["im.safety.unblock.c1", "im.safety.unblock.c2"]
            confirmKey = "im.safety.unblock.confirm"; doneKey = "im.safety.unblock.done"; doneDetailKey = nil
            failureKey = "im.safety.unblock.failed"
        case .report, .reportWithReason:
            titleKey = "im.safety.report.title"; contentKey = "im.safety.report.content"; consequenceKeys = ["im.safety.report.c1"]
            confirmKey = "im.safety.report.confirm"; doneKey = "im.safety.report.done"; doneDetailKey = nil
            failureKey = "im.safety.report.failed"
        }
    }
}

@MainActor struct IMSafetyReviewView: View {
    @StateObject private var model: IMSafetyModel
    let onSettled: (IMSafetyAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ugcSafetyContext) private var ugcSafety
    @Environment(\.locale) private var locale
    @State private var task: Task<Void, Never>?
    init(owner: IMSafetyCoordinator, onSettled: @escaping (IMSafetyAction) -> Void) {
        _model = StateObject(wrappedValue: IMSafetyModel(owner: owner)); self.onSettled = onSettled
    }
    var body: some View {
        NavigationStack {
            List {
                content
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("im.safety.title"))
            .navigationBarTitleDisplayMode(.inline)
            .cyHaptic(.success, trigger: model.state) { _, new in
                if case .acknowledged = new { return true }
                return false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { close() }.disabled(isInFlight).accessibilityIdentifier("im.safety.close")
                }
            }
        }
        .accessibilityIdentifier("im.safety.sheet")
        .cyDomainSheet(detents: [.half, .full])
        .interactiveDismissDisabled(isInFlight)
        // A dispatched request is never cancelled by dismissal; its owner keeps the
        // unknown/acknowledged state. Only an acknowledged action refreshes the host.
        .onDisappear {
            if case .acknowledged(let action) = model.state {
                switch action {
                case .block(_, let targetMemberID):
                    ugcSafety?.blockedStore.recordLocalBlock(memberID: targetMemberID)
                case .unblock(_, let targetMemberID):
                    ugcSafety?.blockedStore.recordLocalUnblock(memberID: targetMemberID)
                default:
                    break
                }
                onSettled(action)
            }
            model.owner.cancelReview()
        }
        .cyDomainScreen(.player)
    }
    private var isInFlight: Bool {
        switch model.state { case .submitting, .verifying, .resolving: return true; default: return false }
    }
    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView("im.safety.idle", systemImage: "checkmark.shield")
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("im.safety.idle")
        case .resolving:
            loadingBlock("im.safety.resolving").accessibilityIdentifier("im.safety.resolving")
        case .unavailable(let message):
            Section {
                statusLabel("im.safety.unavailable", systemImage: "exclamationmark.circle", tint: .orange)
                    .accessibilityIdentifier("im.safety.unavailable")
                if let message, !message.isEmpty { serverMessage(message) }
            }
        case .reviewing(let action):
            let copy = IMSafetyCopy(action)
            let isDestructive: Bool = {
                switch action { case .block, .hide, .report, .reportWithReason: return true; case .unblock: return false }
            }()
            Section {
                Text(LocalizedStringKey(copy.titleKey))
                    .font(.headline)
                    .accessibilityIdentifier("im.safety.reviewTitle")
                if let key = copy.contentKey { bodyText(LocalizedStringKey(key)) }
                ForEach(Array(copy.consequenceKeys.enumerated()), id: \.offset) { index, key in
                    Label {
                        Text(LocalizedStringKey(key))
                    } icon: {
                        Image(systemName: (isDestructive && index == copy.consequenceKeys.count - 1) ? "exclamationmark.triangle" : "info.circle")
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Section {
                Button(role: isDestructive ? .destructive : nil) { run { await model.owner.confirm() } } label: {
                    Text(LocalizedStringKey(copy.confirmKey))
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(Text(LocalizedStringKey(copy.confirmKey)))
                .accessibilityIdentifier("im.safety.confirm")
                Button("action.cancel", role: .cancel) { close() }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("action.cancel"))
                    .accessibilityIdentifier("im.safety.cancel")
            }
        case .submitting:
            loadingBlock("im.safety.submitting").accessibilityIdentifier("im.safety.submitting")
        case .verifying:
            loadingBlock("im.safety.verifying").accessibilityIdentifier("im.safety.verifying")
        case .acknowledged(let action):
            let copy = IMSafetyCopy(action)
            Section {
                statusLabel(LocalizedStringKey(copy.doneKey), systemImage: "checkmark.circle", tint: .green)
                    .accessibilityIdentifier("im.safety.done")
                if let key = copy.doneDetailKey { bodyText(LocalizedStringKey(key)) }
            }
            Section {
                Button(action: close) {
                    Text("action.close").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("im.safety.doneClose")
            }
        case .rejected(let action, let message):
            Section {
                statusLabel(LocalizedStringKey(IMSafetyCopy(action).failureKey), systemImage: "xmark.octagon", tint: .red)
                    .accessibilityIdentifier("im.safety.rejected")
                if let message, !message.isEmpty { serverMessage(message) }
            }
            Section { retryButton(primary: true) }
        case .outcomeUnknown(let action):
            let isReport: Bool = {
                if case .report = action { return true }
                if case .reportWithReason = action { return true }
                return false
            }()
            Section {
                statusLabel("im.safety.unknown", systemImage: "questionmark.circle", tint: .orange)
                    .accessibilityIdentifier("im.safety.unknown")
                if isReport {
                    bodyText("im.safety.unknownReport")
                } else {
                    bodyText("im.safety.unknownHint")
                }
            }
            Section {
                if !isReport {
                    Button { run { await model.owner.verify() } } label: {
                        Label("im.safety.verify", systemImage: "checkmark.shield").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("im.safety.verify")
                }
                retryButton(primary: isReport)
            }
        case .notApplied:
            Section {
                statusLabel("im.safety.notApplied", systemImage: "arrow.uturn.backward.circle", tint: .secondary)
                    .accessibilityIdentifier("im.safety.notApplied")
            }
            Section { retryButton(primary: true) }
        }
    }
    private func statusLabel(_ key: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        Label {
            Text(key)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(tint)
        }
    }
    private func bodyText(_ key: LocalizedStringKey) -> some View {
        Text(key)
    }
    private func serverMessage(_ message: String) -> some View {
        Text(verbatim: message)
            .foregroundStyle(.secondary)
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
    /// Verify is the primary when the action can be read back. A report has no verify, so retry is the one primary.
    @ViewBuilder private func retryButton(primary: Bool) -> some View {
        if primary {
            Button { run { await model.owner.retryUnchanged() } } label: {
                Label("im.safety.retrySame", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("im.safety.retry")
        } else {
            Button { run { await model.owner.retryUnchanged() } } label: {
                Label("im.safety.retrySame", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("im.safety.retry")
        }
    }
    private func run(_ body: @escaping @MainActor () async -> Void) {
        guard task == nil else { return }
        task = Task { @MainActor in await body(); task = nil }
    }
    private func close() { dismiss() }
}
