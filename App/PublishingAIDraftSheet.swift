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
                        .submitLabel(.return)
                        .disabled(model.flow.busy)
                        .accessibilityIdentifier("contextPublish.ai.prompt")
                        .focused($ideaFocused)
                    PublishingAIPromptControls(controller:inspiration,flow:model.flow,applied:{ ideaFocused = true })
                    // Screens r4 · Figma 239:24018 (CF-59, CF-68): while generating, the send button turns into 停止生成
                    // in place (same slot); stopping keeps the idea for another try.
                    if model.flow.busy {
                        Button { model.flow.stop() } label: {
                            Label { ConfigR4Text.text("config.ai.stop") } icon: { Image(systemName: "stop.fill") }
                        }
                        .accessibilityIdentifier("contextPublish.ai.stop")
                    } else {
                        Button {
                            Task { await model.flow.generate() }
                        } label: {
                            Label("contextPublish.ai.generate", systemImage: "sparkles")
                                .fontWeight(.semibold)
                        }
                        .disabled(!model.flow.canGenerate)
                        .accessibilityIdentifier("contextPublish.ai.generate")
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let key = model.flow.messageKey {
                            Text(LocalizedStringKey(key)).foregroundStyle(.red)
                        }
                        if let message = model.flow.serverMessage {
                            Text(verbatim: message).foregroundStyle(.red)
                        }
                        if !model.flow.canGenerate && !model.flow.busy && model.flow.quotaReadState != .loading && model.flow.quota?.exhausted != true {
                            Text("contextPublish.ai.unavailable")
                        }
                        Text("contextPublish.ai.notice")
                    }
                }
                if model.flow.busy && model.flow.candidate == nil {
                    // CF-59: the draft card appears at once as a placeholder that fills in when the draft lands.
                    Section {
                        ProgressView("contextPublish.ai.generating")
                            .frame(maxWidth: .infinity)
                        Text(verbatim: "Placeholder draft title")
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                        Text(verbatim: "Placeholder draft description that fills in when the draft lands.")
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("contextPublish.ai.generatingCard")
                }
                PublishingAIQuotaSection(flow: model.flow)
                G6AIThemeDraftRecoverySection()
                // Mini-program pages/publish/simple `.simple-ai__filing`: filing number under the AI tool, if any.
                Section { EmptyView() } footer: { AIGCFilingNumberText() }
                if let result = model.flow.candidate, let candidateGeneration = model.flow.candidateGeneration {
                    Section {
                        if model.flow.candidateIsPrevious {
                            Label("publishingAICandidate.previousNotice", systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(CYColor.warningText)
                        }
                        if let sourceIdea = model.flow.candidateSourceIdea {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("publishingAICandidate.sourceIdea")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(verbatim: sourceIdea)
                                    .textSelection(.enabled)
                            }.accessibilityIdentifier("publishingAICandidate.sourceIdea")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: result.draft.title)
                                .font(.headline)
                            if let subtitle = result.draft.subtitle {
                                Text(verbatim: subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text(verbatim: result.draft.description)
                                .foregroundStyle(.secondary)
                        }
                        .id(candidateGeneration)
                        Label("contextPublish.ai.placesUnconfirmed", systemImage: "mappin.and.ellipse")
                            .foregroundStyle(CYColor.warningText)
                        ForEach(Array(result.draft.nodes.enumerated()), id: \.element.id) { index, node in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: node.name)
                                    Text(verbatim: node.description)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "\(index + 1).circle.fill")
                                    .foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                            }
                        }
                        Button {
                            if let draft = model.flow.accept(candidateGeneration: candidateGeneration) { accept(draft); dismiss() }
                        } label: {
                            Text(model.flow.candidateIsPrevious ? LocalizedStringKey("publishingAICandidate.usePrevious") : LocalizedStringKey("contextPublish.ai.use"))
                                .fontWeight(.semibold)
                        }
                        .disabled(!model.flow.canAcceptCandidate)
                        .accessibilityIdentifier("contextPublish.ai.use")
                    } header: {
                        Text(model.flow.candidateIsPrevious ? LocalizedStringKey("publishingAICandidate.previous") : LocalizedStringKey("contextPublish.ai.generated"))
                    }
                }
            }.navigationTitle("contextPublish.ai.title").navigationBarTitleDisplayMode(.inline)
            .modifier(PublishingAIPromptLifetime(controller:inspiration))
            .cyDomainScreen(.topicEditor)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { model.flow.close(); dismiss() } } }
            .task { await model.flow.loadQuota() }.onDisappear { model.flow.close() }
            // `.success` once when a draft lands (not on re-render, not when it is cleared).
            .sensoryFeedback(.success, trigger: model.flow.candidateGeneration, condition: CYHapticTransition.isSet)
        }
    }
}
