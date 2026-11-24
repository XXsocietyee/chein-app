import SwiftUI

@MainActor final class ApprovedTopicReviewReadModel: ObservableObject {
    let flow: ApprovedTopicReviewFlow
    @Published private(set) var revision = 0
    @Published private(set) var isWorking = false
    @Published private(set) var confirmation: ApprovedTopicReviewFlow.Confirmation?
    init(flow: ApprovedTopicReviewFlow) { self.flow = flow }
    func load() async {
        guard !isWorking else { return }; isWorking = true
        await flow.load(); isWorking = false; revision += 1
    }
    func selectSource(_ choice: ApprovedMerchantReviewChoices.Choice, from original: ApprovedTopicReviewFlow.SourceSelectionPresentation) {
        guard !isWorking, flow.selectSource(choice, from: original) else { return }; revision += 1
    }
    func captureSources(_ original: ApprovedTopicReviewFlow.SourceSelectionPresentation) {
        guard !isWorking, let claim = flow.claimSourceCapture(original) else { return }
        isWorking = true; revision += 1
        Task { [weak self, flow] in await flow.captureSources(claim); self?.isWorking = false; self?.revision += 1 }
    }
    func review(_ capture: ApprovedTopicReviewCapture) {
        guard confirmation == nil, !isWorking, let original = flow.review(capture) else { return }
        confirmation = original; revision += 1
    }
    func owns(_ original: ApprovedTopicReviewFlow.Confirmation) -> Bool {
        confirmation?.id == original.id && flow.confirmation?.id == original.id && flow.isCurrent
    }
    func cancel(_ original: ApprovedTopicReviewFlow.Confirmation) {
        guard confirmation?.id == original.id else { return }; flow.cancel(original); confirmation = nil; revision += 1
    }
    func confirm(_ original: ApprovedTopicReviewFlow.Confirmation) {
        guard confirmation?.id == original.id else { return }
        guard owns(original), let claim = flow.claim(original) else { flow.cancel(original); confirmation = nil; revision += 1; return }
        confirmation = nil; isWorking = true; revision += 1
        Task { [weak self, flow] in await flow.submit(claim); self?.isWorking = false; self?.revision += 1 }
    }
    func check(_ original: ApprovedTopicReviewJournal.Snapshot) {
        guard !isWorking, flow.canReadStatus, flow.snapshot == original else { return }; isWorking = true
        Task { [weak self, flow] in await flow.check(original); self?.isWorking = false; self?.revision += 1 }
    }
    func retry(_ original: ApprovedTopicReviewJournal.Snapshot) {
        guard !isWorking, flow.canRetryExact, flow.snapshot == original else { return }; isWorking = true
        Task { [weak self, flow] in await flow.retryExact(original); self?.isWorking = false; self?.revision += 1 }
    }
    func observe(_ original: ApprovedTopicReviewJournal.Snapshot) {
        guard !isWorking, flow.canObserve, flow.snapshot == original else { return }; isWorking = true
        Task { [weak self, flow] in await flow.observeCurrent(original); self?.isWorking = false; self?.revision += 1 }
    }
    func binding(_ original: ApprovedTopicReviewFlow.Confirmation?) -> Binding<ApprovedTopicReviewFlow.Confirmation?> {
        .init(get: { guard let original, self.owns(original) else { return nil }; return original }, set: { value in
            guard value == nil, let original else { return }; self.cancel(original)
        })
    }
}

@MainActor struct ApprovedTopicReviewRequestView: View {
    let original: ApprovedTopicReviewPresentation.Presentation
    let close: () -> Void
    @StateObject private var model: ApprovedTopicReviewReadModel
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var primaryPulse = 0
    init(original: ApprovedTopicReviewPresentation.Presentation, close: @escaping () -> Void) {
        self.original = original; self.close = close; _model = StateObject(wrappedValue: .init(flow: original.flow))
    }
    var body: some View {
        let confirmation = model.confirmation
        NavigationStack {
            Form {
                Cloud02ScreenHeader(title: "topicReview.title", seed: "topic-review", symbol: "doc.text.magnifyingglass")
                    .cloud02GutterRow()
                if original.flow.isCurrent {
                    if model.isWorking {
                        CYSkeleton()
                            .accessibilityIdentifier("topicReview.loading")
                            .accessibilityLabel(Text("wallet.loading"))
                            .cloud02GutterRow()
                    } else { content }
                } else {
                    stateCopy(art: .failure, key: "topicReview.changed", identifier: "topicReview.changed")
                }
            }
            .p04LifecycleSurface()
            .cyHeroScreen()
            .cyDomainPageBackground()
            .cyHaptic(.impactMedium, trigger: primaryPulse)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: LocalizedStringResource("topicReview.close", defaultValue: "Close", locale: locale)), action: close)
                    .accessibilityIdentifier("topicReview.close")
            } }
        }
        .themeDomain(.player)
        .task(id: original.id) { await model.load() }
        .sheet(item: model.binding(confirmation)) { captured in Group {
            if model.owns(captured) {
                ApprovedTopicReviewConfirmationView(original: captured, confirm: { model.confirm(captured) }, cancel: { model.cancel(captured) })
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        }
        .onDisappear { original.flow.close() }
    }
    @ViewBuilder private var content: some View {
        let flow = original.flow
        switch flow.state {
        case .selectingSources(let presentation):
            ApprovedMerchantReviewSourceSection(model: model, presentation: presentation)
        case .ready(let capture):
            ApprovedTopicReviewSummarySection(coverSource: original.coverSource, coverSession: flow.session, coverContextCurrent: { flow.isCurrent && flow.state == .ready(capture) }, capture: capture)
            Section {
                Cloud02ActionButton(title: "topicReview.review", identifier: "topicReview.review", systemImage: "doc.text.magnifyingglass", primary: true, isDisabled: !flow.canConfirm(capture)) {
                    primaryPulse += 1
                    model.review(capture)
                }
                .cloud02GutterRow()
            }
        case .known(let receipt):
            Section {
                Text(String(localized: LocalizedStringResource("topicReview.submitted", defaultValue: "The server recorded this review request. It is not an approval or a release receipt. The original V2 submission remains unchanged.", locale: locale)))
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("topicReview.submitted")
                receiptField(String(localized: LocalizedStringResource("topicReview.submittedTask", defaultValue: "Submitted review task ID", locale: locale)), String(receipt.auditTaskID), "submittedTask")
                receiptField(String(localized: LocalizedStringResource("topicReview.submittedVersion", defaultValue: "Task version when submitted", locale: locale)), String(receipt.submittedTaskVersion), "submittedVersion")
                receiptField(String(localized: LocalizedStringResource("topicReview.submittedState", defaultValue: "Status when submitted", locale: locale)), receipt.submittedTaskStatus == 0
                    ? String(localized: LocalizedStringResource("topicReview.pending", defaultValue: "Pending review", locale: locale))
                    : String(localized: LocalizedStringResource("topicReview.escalated", defaultValue: "Escalated review", locale: locale)), "submittedState")
                receiptField(String(localized: LocalizedStringResource("topicReview.requestID", defaultValue: "Saved request ID", locale: locale)), receipt.requestID, "requestID")
                Text(String(localized: LocalizedStringResource("topicReview.afterSubmission", defaultValue: "Close this sheet to check the approved snapshot separately. A saved submission status is historical and does not establish the current review outcome.", locale: locale)))
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let captured = flow.snapshot { ApprovedTopicReviewObservationSection(model: model, original: captured) }
            recoveryControls(checkIsPrimary: flow.isReceiptForThisSubmission)
            if !flow.isReceiptForThisSubmission {
                Section {
                    Text(String(localized: LocalizedStringResource("topicReview.previousDraft", defaultValue: "This recovered receipt belongs to an earlier submitted draft. You can now capture the current acknowledged draft.", locale: locale)))
                        .cyText(.body)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Cloud02ActionButton(title: "topicReview.captureCurrent", identifier: "topicReview.captureCurrent", systemImage: "square.and.arrow.down", primary: true) {
                        primaryPulse += 1
                        Task { await model.load() }
                    }
                    .cloud02GutterRow()
                }
            }
        case .unconfirmed:
            Section {
                Text(String(localized: LocalizedStringResource("topicReview.unconfirmed", defaultValue: "The outcome is unconfirmed. The original request is saved. Check its status or retry exactly that request; a new request will not be invented.", locale: locale)))
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("topicReview.unconfirmed")
                if let id = flow.snapshot?.current?.command.requestID { receiptField(String(localized: LocalizedStringResource("topicReview.requestID", defaultValue: "Saved request ID", locale: locale)), id, "requestID") }
            }
            recoveryControls(checkIsPrimary: true)
        case .failed(_):
            Section {
                stateCopy(art: .failure, key: "topicReview.failed", identifier: "topicReview.failed")
                Cloud02ActionButton(title: "topicReview.reload", identifier: "topicReview.reload", systemImage: "arrow.clockwise", primary: true) {
                    primaryPulse += 1
                    Task { await model.load() }
                }
                .cloud02GutterRow()
            }
        case .unauthorized:
            stateCopy(art: .generic, key: "topicReview.unauthorized", identifier: "topicReview.unauthorized")
        case .idle, .loading, .sending:
            CYSkeleton()
                .accessibilityIdentifier("topicReview.loading")
                .accessibilityLabel(Text("wallet.loading"))
                .cloud02GutterRow()
        case .closed: EmptyView()
        }
    }
    @ViewBuilder private func recoveryControls(checkIsPrimary: Bool) -> some View {
        let flow = original.flow
        if let captured = flow.snapshot {
            Section {
                if !flow.canReadStatus && !flow.canRetryExact {
                    Text(String(localized: LocalizedStringResource("topicReview.recoveryUnavailable", defaultValue: "Recovery is not configured for this account or request. The saved request remains unchanged.", locale: locale)))
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("topicReview.recoveryUnavailable")
                }
                Cloud02ActionButton(title: "topicReview.check", identifier: "topicReview.check", systemImage: "doc.text.magnifyingglass", primary: checkIsPrimary, isDisabled: !flow.canReadStatus) {
                    if checkIsPrimary { primaryPulse += 1 }
                    model.check(captured)
                }
                .cloud02GutterRow()
                if captured.current?.receipt == nil {
                    Cloud02ActionButton(title: "topicReview.retryExact", identifier: "topicReview.retryExact", systemImage: "arrow.clockwise", primary: false, isDisabled: !flow.canRetryExact) {
                        model.retry(captured)
                    }
                    .cloud02GutterRow()
                }
            }
        }
    }
    private func receiptField(_ label: String, _ value: String, _ suffix: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: label)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: cloud02Known(value))
                .cyText(.body)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("topicReview." + suffix)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, CYSpacing.sm)
    }
    private func stateCopy(art: CYStateKind, key: LocalizedStringKey, identifier: String?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYStateArt(kind: art, size: typeSize.isAccessibilitySize ? 84 : 120)
            Text(key)
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(Cloud02Identifier(identifier))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cloud02GutterRow()
    }
}

@MainActor private struct ApprovedTopicReviewConfirmationView: View {
    let original: ApprovedTopicReviewFlow.Confirmation
    let confirm: () -> Void
    let cancel: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @State private var primaryPulse = 0
    var body: some View {
        NavigationStack {
            Form {
                Cloud02ScreenHeader(title: "topicReview.confirmTitle", seed: "topic-review-confirm", symbol: "paperplane")
                    .cloud02GutterRow()
                ApprovedTopicReviewSummarySection(capture: original.capture, prefix: "topicReview.confirm")
                Section {
                    Text(String(localized: LocalizedStringResource("topicReview.confirmation", defaultValue: "Send exactly this captured version for review. This action does not approve the content or create an immutable release.", locale: locale)))
                        .cyText(.body)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Cloud02ActionButton(title: "topicReview.submit", identifier: "topicReview.confirm.submit", systemImage: "paperplane.fill", primary: true) {
                        primaryPulse += 1
                        confirm()
                    }
                    .cloud02GutterRow()
                }
            }
            .p04LifecycleSurface()
            .cyHeroScreen()
            .cyDomainPageBackground()
            .cyHaptic(.impactMedium, trigger: primaryPulse)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: LocalizedStringResource("topicReview.cancel", defaultValue: "Cancel", locale: locale)), action: cancel)
                    .accessibilityIdentifier("topicReview.confirm.cancel")
            } }
        }
        .themeDomain(.player)
        .onDisappear(perform: cancel)
    }
}
