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
    @QuestifyReduceMotion private var reduceMotion
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
                        .cyText(.bodyCompact)
                        .disabled(model.flow.busy)
                        .accessibilityIdentifier("contextPublish.ai.prompt")
                        .focused($ideaFocused)
                    PublishingAIPromptControls(controller:inspiration,flow:model.flow,applied:{ ideaFocused = true })
                    if let key = model.flow.messageKey {
                        Text(LocalizedStringKey(key))
                            .cyText(.meta)
                            .foregroundStyle(palette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let message = model.flow.serverMessage {
                        Text(verbatim: message)
                            .cyText(.meta)
                            .foregroundStyle(palette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Screens r4 · Figma 239:24018 (CF-59, CF-68): while generating, the send button turns into 停止生成
                    // in place (same slot, the label cross-fades); stopping keeps the idea for another try.
                    Group {
                        if model.flow.busy {
                            Button { model.flow.stop() } label: {
                                Label { ConfigR4Text.text("config.ai.stop") } icon: { Image(systemName: "stop.fill") }
                            }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: true, compact: true))
                            .accessibilityIdentifier("contextPublish.ai.stop")
                        } else {
                            Button {
                                Task { await model.flow.generate() }
                            } label: {
                                Label("contextPublish.ai.generate", systemImage: "sparkles")
                            }
                            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true, compact: true))
                            .disabled(!model.flow.canGenerate)
                            .accessibilityIdentifier("contextPublish.ai.generate")
                        }
                    }
                    .animation(CYMotion.resolve(.easeOut(duration: CYMotion.Duration.quick), reduceMotion: reduceMotion), value: model.flow.busy)
                    .listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.md, bottom: CYSpacing.sm, trailing: CYSpacing.md))
                    if !model.flow.canGenerate && !model.flow.busy && model.flow.quotaReadState != .loading && model.flow.quota?.exhausted != true {
                        Text("contextPublish.ai.unavailable")
                            .cyText(.meta)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Text("contextPublish.ai.notice")
                        .cyText(.meta)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if model.flow.busy && model.flow.candidate == nil {
                    // CF-59: the draft card appears at once as a skeleton that fills in when the draft lands.
                    Section {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            ProgressView("contextPublish.ai.generating")
                                .cyText(.meta)
                                .foregroundStyle(palette.textSecondary)
                            CYSkeleton(variant: .card)
                        }
                        .padding(.vertical, CYSpacing.xs)
                        .transition(.opacity)
                        .accessibilityIdentifier("contextPublish.ai.generatingCard")
                    }
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
                                    .cyText(.meta)
                                    .foregroundStyle(palette.textTertiary)
                                Text(verbatim: sourceIdea)
                                    .cyText(.bodyCompact)
                                    .foregroundStyle(palette.textPrimary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.accessibilityIdentifier("publishingAICandidate.sourceIdea")
                        }
                        // xrefs-1 Adopt 12 / PAT 14: generated fields rewrite in place (blurReplace 250 ms, from the top
                        // at 0 / 40 / 70 / 90 ms); a new generation retargets. Reduce Motion: cross-fade.
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: result.draft.title)
                                .cyText(.cardTitle)
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .modifier(PublishingAIRewrite(generation: candidateGeneration, order: 0))
                            if let subtitle = result.draft.subtitle {
                                Text(verbatim: subtitle)
                                    .cyText(.label)
                                    .foregroundStyle(palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .modifier(PublishingAIRewrite(generation: candidateGeneration, order: 1))
                            }
                            Text(verbatim: result.draft.description)
                                .cyText(.bodyCompact)
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .modifier(PublishingAIRewrite(generation: candidateGeneration, order: 2))
                        }
                        CYStatusChip("contextPublish.ai.placesUnconfirmed", tone: .warning, systemImage: "mappin.and.ellipse")
                        ForEach(Array(result.draft.nodes.enumerated()), id: \.element.id) { index, node in
                            HStack(alignment: .top, spacing: CYSpacing.sm) {
                                Text(verbatim: "\(index + 1)")
                                    .cyText(.meta, monospacedDigit: true)
                                    .foregroundStyle(palette.actionPrimaryFg)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(palette.actionPrimaryBg))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: node.name)
                                        .cyText(.label)
                                        .foregroundStyle(palette.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(verbatim: node.description)
                                        .cyText(.meta)
                                        .foregroundStyle(palette.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, CYSpacing.xs)
                            .modifier(PublishingAIRewrite(generation: candidateGeneration, order: 3, station: index))
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
            }.navigationTitle("contextPublish.ai.title").navigationBarTitleDisplayMode(.inline)
            .modifier(PublishingAIPromptLifetime(controller:inspiration))
            .scrollContentBackground(.hidden)
            .cyDomainScreen(.topicEditor)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { model.flow.close(); dismiss() } } }
            .task { await model.flow.loadQuota() }.onDisappear { model.flow.close() }
            // `.success` once when a draft lands (not on re-render, not when it is cleared).
            .cyHaptic(.success, trigger: model.flow.candidateGeneration) { old, new in new != nil && old != new }
            .animation(CYMotion.resolve(.easeOut(duration: CYMotion.Duration.quick), reduceMotion: reduceMotion), value: model.flow.busy)
        }
    }
}

/// One AI-written field: when the draft's generation changes, the old text blurs out and the new text blurs in
/// (`blurReplace`, 250 ms) at its slot's delay from the top (`CYMotion.Stagger.rewrite`). Stations follow on
/// `stations` (shrinking gaps), rising 8 pt. Reduce Motion: a cross-fade, no delay.
private struct PublishingAIRewrite: ViewModifier {
    let generation: Int
    let order: Int
    var station: Int?
    @QuestifyReduceMotion private var reduceMotion
    /// CF-59 stations: 120 ms to the second, then shrinking gaps; the rest land with the fifth (no uniform stagger).
    static let stations: [Double] = [0, 0.12, 0.2, 0.25, 0.28]

    private var delay: Double {
        if let station { return CYMotion.Stagger.delay(order, in: CYMotion.Stagger.rewrite) + CYMotion.Stagger.delay(station, in: Self.stations) }
        return CYMotion.Stagger.delay(order, in: CYMotion.Stagger.rewrite)
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        if station != nil { return AnyTransition.opacity.combined(with: .offset(y: 8)) }
        return AnyTransition(.blurReplace)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            content.id(generation).transition(transition)
        }
        .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: 0.25).delay(delay), value: generation)
    }
}
