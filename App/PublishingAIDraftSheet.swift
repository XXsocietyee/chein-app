import SwiftUI

@MainActor final class PublishingAIDraftModel: ObservableObject {
    let flow: PublishingAIDraftFlow
    @Published var revision = 0
    init(client: (any PublishingAIDraftServing)?, product: ProjectEditProduct, initialIdea: String = "") {
        flow = PublishingAIDraftFlow(client: client, product: product)
        // One local seed per StateObject. Rendering or quota refresh never replaces user edits.
        flow.idea = initialIdea
        flow.onChange = { [weak self] in self?.revision += 1 }
    }
}
@MainActor struct PublishingAIDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// verify-r2 N-01: this page applies the topicEditor domain to itself, so its own palette is that domain's.
    /// Reading `cyPalette` here gave the pushing NavigationStack's palette (the dark player shell).
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }
    @StateObject private var model: PublishingAIDraftModel
    @StateObject private var inspiration = PublishingAIPromptController()
    @FocusState private var ideaFocused: Bool
    let accept: (QuickPublishDraft) -> Void
    init(client: (any PublishingAIDraftServing)?, product: ProjectEditProduct, initialIdea: String = "", accept: @escaping (QuickPublishDraft) -> Void) {
        _model = StateObject(wrappedValue: PublishingAIDraftModel(client: client, product: product, initialIdea: initialIdea)); self.accept = accept
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Design hand-off r1 CF-59: the prompt leads; suggestions and preference tags follow it.
                    TextField("contextPublish.ai.prompt", text: Binding(get: { model.flow.idea }, set: { model.flow.idea = $0; model.revision += 1 }), axis: .vertical)
                        .lineLimit(3...8)
                        .font(CYTypography.bodyCompact)
                        .disabled(model.flow.busy)
                        .accessibilityIdentifier("contextPublish.ai.prompt")
                        .focused($ideaFocused)
                    PublishingAIPromptControls(controller:inspiration,flow:model.flow,applied:{ ideaFocused = true })
                    if let key = model.flow.messageKey {
                        Text(LocalizedStringKey(key))
                            .font(CYTypography.meta)
                            .foregroundStyle(palette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let message = model.flow.serverMessage {
                        Text(verbatim: message)
                            .font(CYTypography.meta)
                            .foregroundStyle(palette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if model.flow.busy {
                        HStack(spacing: CYSpacing.sm) {
                            ProgressView("contextPublish.ai.generating")
                        }
                    }
                    Button {
                        Task { await model.flow.generate() }
                    } label: {
                        Label("contextPublish.ai.generate", systemImage: "sparkles")
                    }
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true, compact: true))
                    .disabled(!model.flow.canGenerate)
                    .accessibilityIdentifier("contextPublish.ai.generate")
                    .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.md, bottom: CYSpacing.sm, trailing: CYSpacing.md))
                    if !model.flow.canGenerate && !model.flow.busy && model.flow.quotaReadState != .loading && model.flow.quota?.exhausted != true {
                        Text("contextPublish.ai.unavailable")
                            .font(CYTypography.meta)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Text("contextPublish.ai.notice")
                        .font(CYTypography.meta)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PublishingAIQuotaSection(flow: model.flow)
                G6AIThemeDraftRecoverySection()
                // Mini-program pages/publish/simple `.simple-ai__filing`: filing number under the AI tool, if any.
                Section { EmptyView() } footer: { AIGCFilingNumberText() }
                if let result = model.flow.candidate, let candidateGeneration = model.flow.candidateGeneration {
                    Section(model.flow.candidateIsPrevious ? LocalizedStringKey("publishingAICandidate.previous") : LocalizedStringKey("contextPublish.ai.generated")) {
                        if model.flow.candidateIsPrevious {
                            CYStatusChip("publishingAICandidate.previousNotice", tone: .warning, systemImage: "clock.arrow.circlepath")
                        }
                        if let sourceIdea = model.flow.candidateSourceIdea {
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text("publishingAICandidate.sourceIdea")
                                    .font(CYTypography.meta)
                                    .foregroundStyle(palette.textTertiary)
                                Text(verbatim: sourceIdea)
                                    .font(CYTypography.bodyCompact)
                                    .foregroundStyle(palette.textPrimary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.accessibilityIdentifier("publishingAICandidate.sourceIdea")
                        }
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: result.draft.title)
                                .font(CYTypography.cardTitle)
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let subtitle = result.draft.subtitle {
                                Text(verbatim: subtitle)
                                    .font(CYTypography.label)
                                    .foregroundStyle(palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(verbatim: result.draft.description)
                                .font(CYTypography.bodyCompact)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        CYStatusChip("contextPublish.ai.placesUnconfirmed", tone: .warning, systemImage: "mappin.and.ellipse")
                        ForEach(Array(result.draft.nodes.enumerated()), id: \.element.id) { index, node in
                            HStack(alignment: .top, spacing: CYSpacing.sm) {
                                Text(verbatim: "\(index + 1)")
                                    .font(CYTypography.micro.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(palette.actionPrimaryFg)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(palette.actionPrimaryBg))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: node.name)
                                        .font(CYTypography.label)
                                        .foregroundStyle(palette.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(verbatim: node.description)
                                        .font(CYTypography.meta)
                                        .foregroundStyle(palette.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, CYSpacing.xs)
                        }
                        Button {
                            if let draft = model.flow.accept(candidateGeneration: candidateGeneration) { accept(draft); dismiss() }
                        } label: {
                            Text(model.flow.candidateIsPrevious ? LocalizedStringKey("publishingAICandidate.usePrevious") : LocalizedStringKey("contextPublish.ai.use"))
                        }
                        .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true, compact: true))
                        .disabled(!model.flow.canAcceptCandidate)
                        .accessibilityIdentifier("contextPublish.ai.use")
                        .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.md, bottom: CYSpacing.sm, trailing: CYSpacing.md))
                    }
                }
            }.navigationTitle("contextPublish.ai.title")
            .modifier(PublishingAIPromptLifetime(controller:inspiration))
            .scrollContentBackground(.hidden)
            .cyDomainScreen(.topicEditor)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { model.flow.close(); dismiss() } } }
            .task { await model.flow.loadQuota() }.onDisappear { model.flow.close() }
        }
    }
}
