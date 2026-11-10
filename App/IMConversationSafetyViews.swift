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
            titleKey = "im.safety.unblock.title"; contentKey = nil; consequenceKeys = []
            confirmKey = "im.safety.unblock.confirm"; doneKey = "im.safety.unblock.done"; doneDetailKey = nil
            failureKey = "im.safety.unblock.failed"
        case .report, .reportWithReason:
            titleKey = "im.safety.report.title"; contentKey = "im.safety.report.content"; consequenceKeys = []
            confirmKey = "im.safety.report.confirm"; doneKey = "im.safety.report.done"; doneDetailKey = nil
            failureKey = "im.safety.report.failed"
        }
    }
}

@MainActor struct IMSafetyReviewView: View {
    @StateObject private var model: IMSafetyModel
    let onSettled: (IMSafetyAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var task: Task<Void, Never>?
    init(owner: IMSafetyCoordinator, onSettled: @escaping (IMSafetyAction) -> Void) {
        _model = StateObject(wrappedValue: IMSafetyModel(owner: owner)); self.onSettled = onSettled
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    CYHeroHeader("im.safety.title")
                    content
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
                    Button("action.close") { close() }.disabled(isInFlight).accessibilityIdentifier("im.safety.close")
                }
            }
        }
        .accessibilityIdentifier("im.safety.sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isInFlight)
        // A dispatched request is never cancelled by dismissal; its owner keeps the
        // unknown/acknowledged state. Only an acknowledged action refreshes the host.
        .onDisappear {
            if case .acknowledged(let action) = model.state { onSettled(action) }
            model.owner.cancelReview()
        }
    }
    private var isInFlight: Bool {
        switch model.state { case .submitting, .verifying, .resolving: return true; default: return false }
    }
    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle:
            CYEmptyState(systemImage: "checkmark.shield", "im.safety.idle")
                .accessibilityIdentifier("im.safety.idle")
        case .resolving:
            loadingBlock("im.safety.resolving").accessibilityIdentifier("im.safety.resolving")
        case .unavailable(let message):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYStatusChip("im.safety.unavailable", tone: .warning, systemImage: "exclamationmark.circle")
                    .accessibilityIdentifier("im.safety.unavailable")
                if let message, !message.isEmpty { serverMessage(message) }
            }
        case .reviewing(let action):
            let copy = IMSafetyCopy(action)
            CYCard {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Text(LocalizedStringKey(copy.titleKey))
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("im.safety.reviewTitle")
                    if let key = copy.contentKey { bodyText(LocalizedStringKey(key)) }
                    ForEach(copy.consequenceKeys, id: \.self) { key in
                        Label {
                            Text(LocalizedStringKey(key))
                                .font(CYTypography.bodyCompact)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "info.circle").accessibilityHidden(true)
                        }
                        .foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Button(role: .destructive) { run { await model.owner.confirm() } } label: {
                Text(LocalizedStringKey(copy.confirmKey))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
            .accessibilityIdentifier("im.safety.confirm")
            Button("action.cancel", role: .cancel) { close() }
                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true))
                .accessibilityIdentifier("im.safety.cancel")
        case .submitting:
            loadingBlock("im.safety.submitting").accessibilityIdentifier("im.safety.submitting")
        case .verifying:
            loadingBlock("im.safety.verifying").accessibilityIdentifier("im.safety.verifying")
        case .acknowledged(let action):
            let copy = IMSafetyCopy(action)
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYStatusChip(LocalizedStringKey(copy.doneKey), tone: .success, systemImage: "checkmark.circle")
                    .accessibilityIdentifier("im.safety.done")
                if let key = copy.doneDetailKey { bodyText(LocalizedStringKey(key)) }
            }
            CYPillButton("action.close", action: close)
                .accessibilityIdentifier("im.safety.doneClose")
        case .rejected(let action, let message):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYStatusChip(LocalizedStringKey(IMSafetyCopy(action).failureKey), tone: .danger, systemImage: "xmark.octagon")
                    .accessibilityIdentifier("im.safety.rejected")
                if let message, !message.isEmpty { serverMessage(message) }
            }
            retryButton(primary: true)
        case .outcomeUnknown(let action):
            let isReport: Bool = {
                if case .report = action { return true }
                if case .reportWithReason = action { return true }
                return false
            }()
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYStatusChip("im.safety.unknown", tone: .warning, systemImage: "questionmark.circle")
                    .accessibilityIdentifier("im.safety.unknown")
                if isReport {
                    bodyText("im.safety.unknownReport")
                } else {
                    bodyText("im.safety.unknownHint")
                    CYPillButton("im.safety.verify", systemImage: "checkmark.shield") { run { await model.owner.verify() } }
                        .accessibilityIdentifier("im.safety.verify")
                }
            }
            retryButton(primary: isReport)
        case .notApplied:
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYStatusChip("im.safety.notApplied", tone: .neutral, systemImage: "arrow.uturn.backward.circle")
                    .accessibilityIdentifier("im.safety.notApplied")
            }
            retryButton(primary: true)
        }
    }
    private func bodyText(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(CYTypography.body)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func serverMessage(_ message: String) -> some View {
        Text(verbatim: message)
            .font(CYTypography.body)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    /// Verify is the primary when the action can be read back. A report has no verify, so retry is the one primary.
    private func retryButton(primary: Bool) -> some View {
        CYPillButton("im.safety.retrySame", style: primary ? .primary : .secondary, systemImage: "arrow.clockwise") {
            run { await model.owner.retryUnchanged() }
        }
        .accessibilityIdentifier("im.safety.retry")
    }
    private func run(_ body: @escaping @MainActor () async -> Void) {
        guard task == nil else { return }
        task = Task { @MainActor in await body(); task = nil }
    }
    private func close() { dismiss() }
}
