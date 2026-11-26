import SwiftUI

@MainActor final class ApprovedReleaseReadModel: ObservableObject {
    let flow: ApprovedTopicReleaseReadFlow
    let publisher: ApprovedTopicReleasePublishFlow?
    @Published private(set) var confirmation: ApprovedTopicReleasePublishFlow.Confirmation?
    @Published private(set) var revision = 0
    init(original: ApprovedReleaseAuthorPresentation.Presentation) { flow = original.flow; publisher = original.publisher }
    func load() async { publisher?.reload(); revision += 1; await flow.load(); revision += 1 }
    func review(_ prepared: ApprovedTopicReleasePreparation) {
        guard flow.isCurrent, flow.state == .ready(prepared), confirmation == nil else { return }
        confirmation = publisher?.review(prepared); revision += 1
    }
    func cancel(_ original: ApprovedTopicReleasePublishFlow.Confirmation) {
        publisher?.cancel(original)
        if confirmation?.id == original.id { confirmation = nil }
        revision += 1
    }
    func confirm(_ original: ApprovedTopicReleasePublishFlow.Confirmation) {
        guard confirmation?.id == original.id, flow.isCurrent, flow.state == .ready(original.prepared),
              let publisher, let claim = publisher.claim(original) else { cancel(original); return }
        confirmation = nil; revision += 1
        Task { [weak self] in await publisher.submit(claim); self?.revision += 1 }
    }
    func confirmationBinding(_ original: ApprovedTopicReleasePublishFlow.Confirmation?) -> Binding<ApprovedTopicReleasePublishFlow.Confirmation?> {
        Binding(get: { guard let original, self.confirmation?.id == original.id, self.publisher?.isCurrent == true,
            self.flow.isCurrent, self.flow.state == .ready(original.prepared) else { return nil }; return original },
            set: { value in guard value == nil, let original else { return }; self.cancel(original) })
    }
    func check(_ original: ApprovedTopicReleasePublicationJournal.Snapshot) async { revision += 1; await publisher?.checkStatus(original); revision += 1 }
    func retry(_ original: ApprovedTopicReleasePublicationJournal.Snapshot) async { revision += 1; await publisher?.retryExact(original); revision += 1 }
    func close() { publisher?.close(); flow.close(); revision += 1 }
}

@MainActor struct ApprovedReleasePreparationView: View {
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var model: ApprovedReleaseReadModel
    @State private var primaryPulse = 0
    let original: ApprovedReleaseAuthorPresentation.Presentation
    let close: () -> Void
    init(original: ApprovedReleaseAuthorPresentation.Presentation, close: @escaping () -> Void) {
        self.original = original; self.close = close; _model = StateObject(wrappedValue: .init(original: original))
    }
    var body: some View {
        let confirmation = model.confirmation
        NavigationStack {
            Form {
                Cloud02ScreenHeader(title: "approvedRelease.title", seed: "approved-release", symbol: "checkmark.seal")
                    .cloud02GutterRow()
                Cloud02Note(key: "approvedRelease.readOnly", identifier: "approvedRelease.readOnly")
                    .cloud02GutterRow()
                if !model.flow.isCurrent {
                    changedContext
                } else {
                    switch model.flow.state {
                    case .idle, .loading:
                        CYSkeleton()
                            .accessibilityIdentifier("approvedRelease.loading")
                            .accessibilityLabel(Text("wallet.loading"))
                            .cloud02GutterRow()
                    case .ready(let prepared):
                        ApprovedReleaseSummarySection(coverSource: original.coverSource, coverSession: original.flow.session, coverContextCurrent: { original.flow.isCurrent && original.flow.state == .ready(prepared) }, prepared: prepared)
                    case .unauthorized:
                        stateCopy(art: .generic, key: "approvedRelease.unauthorized", identifier: nil)
                    case .failed(_):
                        stateCopy(art: .failure, key: "approvedRelease.checkFailed", identifier: "approvedRelease.failed")
                        Cloud02ActionButton(title: "approvedRelease.retry", identifier: "approvedRelease.retry", systemImage: "arrow.clockwise", primary: cloudPrimary == .reload) {
                            if cloudPrimary == .reload { primaryPulse += 1 }
                            Task { await model.load() }
                        }
                        .cloud02GutterRow()
                    case .closed: EmptyView()
                    }
                    if let publisher = model.publisher { publication(publisher) }
                }
            }
            .p04LifecycleSurface()
            .cyHeroScreen()
            .cyDomainPageBackground()
            .cyHaptic(.impactMedium, trigger: primaryPulse)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: LocalizedStringResource("approvedRelease.close", defaultValue: "Close", locale: locale))) { model.close(); close() }
                        .accessibilityIdentifier("approvedRelease.close")
                }
            }
        }
        .themeDomain(.player)
        .task(id: original.id) { await model.load() }
        .cySheet(item: model.confirmationBinding(confirmation)) { captured in Group {
            ApprovedReleasePublicationConfirmationView(original: captured, cancel: model.cancel, confirm: model.confirm)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        }
        .onDisappear { original.publisher?.close(); original.flow.close() }
    }

    private var cloudPrimary: Cloud02ReleasePrimary {
        guard model.flow.isCurrent, let publisher = model.publisher else { return .reload }
        if case .ready(let prepared) = model.flow.state, publisher.canReview(prepared) { return .review }
        if publisher.snapshot?.current != nil { return .check }
        return .reload
    }

    private var changedContext: some View {
        stateCopy(art: .failure, key: "approvedRelease.changedContext", identifier: nil)
    }

    private func stateCopy(art: CYStateKind, key: LocalizedStringKey, identifier: String?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYStateArt(kind: art, size: typeSize.isAccessibilitySize ? 84 : 120)
            identifiedText(key, identifier: identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cloud02GutterRow()
    }

    private func identifiedText(_ key: LocalizedStringKey, identifier: String?) -> some View {
        Text(key)
            .cyText(.body)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Cloud02Identifier(identifier))
    }

    @ViewBuilder private func publication(_ publisher: ApprovedTopicReleasePublishFlow) -> some View {
        let captured = publisher.snapshot
        Section {
            Cloud02Note(key: "approvedRelease.publishScope").cloud02GutterRow()
            switch publisher.state {
            case .sending:
                CYSkeleton()
                    .accessibilityIdentifier("approvedRelease.publication.sending")
                    .accessibilityLabel(Text("wallet.loading"))
                    .cloud02GutterRow()
            case .known(let receipt):
                knownReceipt(receipt).cloud02GutterRow()
            case .unconfirmed:
                Cloud02Note(key: "approvedRelease.unconfirmed", identifier: "approvedRelease.publication.unconfirmed").cloud02GutterRow()
            case .unavailable:
                Cloud02Note(key: "approvedRelease.journalUnavailable", identifier: "approvedRelease.publication.unavailable").cloud02GutterRow()
            case .idle, .reviewing, .closed: EmptyView()
            }
            if let captured, let record = captured.current {
                Text(verbatim: cloud02Known(record.command.requestID))
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("approvedRelease.publication.requestID")
                    .cloud02GutterRow()
                Cloud02ActionButton(title: "approvedRelease.checkResult", identifier: "approvedRelease.publication.check", systemImage: "doc.text.magnifyingglass", primary: cloudPrimary == .check, isDisabled: !publisher.canCheckStatus) {
                    if cloudPrimary == .check { primaryPulse += 1 }
                    Task { await model.check(captured) }
                }
                .cloud02GutterRow()
                if record.receipt == nil {
                    Cloud02ActionButton(title: "approvedRelease.retryExact", identifier: "approvedRelease.publication.retry", systemImage: "arrow.clockwise", primary: false, isDisabled: !publisher.canRetryExact) {
                        Task { await model.retry(captured) }
                    }
                    .cloud02GutterRow()
                }
            }
            if case .ready(let prepared) = model.flow.state, publisher.canReview(prepared) {
                Cloud02ActionButton(title: "approvedRelease.reviewPublication", identifier: "approvedRelease.publish", systemImage: "paperplane", primary: true) {
                    primaryPulse += 1
                    model.review(prepared)
                }
                .cloud02GutterRow()
            }
        }
    }

    private func knownReceipt(_ receipt: ApprovedTopicReleasePublicationReceipt) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(verbatim: String(receipt.releaseID))
                .cyText(.dataXL)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("approvedRelease.publication.releaseID")
            Text(verbatim: cloud02Known(receipt.manifestHash))
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("approvedRelease.publication.manifestHash")
            Text("approvedRelease.allocated")
                .cyText(.bodyCompact)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                Image(systemName: receipt.currentlyApproved ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(receipt.currentlyApproved ? palette.success : palette.warning)
                    .accessibilityHidden(true)
                Text(verbatim: receipt.currentlyApproved
                    ? String(localized: LocalizedStringResource("approvedRelease.receiptApproved", defaultValue: "Approved at the last server check", locale: locale))
                    : String(localized: LocalizedStringResource("approvedRelease.receiptChanged", defaultValue: "The last server check did not confirm current approval", locale: locale)))
                    .cyText(.body)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("approvedRelease.publication.approval")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.lg)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private enum Cloud02ReleasePrimary { case review, check, reload }

struct Cloud02ScreenHeader: View {
    let title: LocalizedStringKey
    var tableName: String? = nil
    let seed: String
    let symbol: String
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title3) private var coverHeight: CGFloat = 128

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if !typeSize.isAccessibilitySize {
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityHidden(true)
            }
            CYHeroHeader(title, tableName: tableName)
        }
    }
}

@MainActor struct Cloud02ActionButton: View {
    let title: LocalizedStringKey
    let identifier: String
    let systemImage: String
    var primary = true
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.sm) {
                Image(systemName: systemImage).accessibilityHidden(true)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(CYPillButtonStyle(style: primary ? .primary : .secondary))
        .disabled(isDisabled)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(Text(title))
    }
}

struct Cloud02Note: View {
    let key: LocalizedStringKey
    var tableName: String? = nil
    var identifier: String? = nil
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Text(key, tableName: tableName)
            .cyText(.bodyCompact)
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.lg)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                    .strokeBorder(palette.borderSubtle, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .modifier(Cloud02Identifier(identifier))
    }
}

struct Cloud02Identifier: ViewModifier {
    let identifier: String?
    init(_ identifier: String?) { self.identifier = identifier }
    func body(content: Content) -> some View {
        if let identifier, !identifier.isEmpty { content.accessibilityIdentifier(identifier) }
        else { content }
    }
}

extension View {
    func cloud02GutterRow() -> some View {
        listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: 0, bottom: CYSpacing.sm, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

func cloud02Known(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : text
}
