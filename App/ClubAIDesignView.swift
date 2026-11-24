import SwiftUI

@MainActor private final class ClubAIDesignModel: ObservableObject {
    let flow: ClubAIDesignFlow
    @Published var revision = 0
    init(flow: ClubAIDesignFlow) { self.flow = flow }
}
@MainActor struct ClubAIDesignView: View {
    let clubID: Int
    let session: PublishingSession?
    let onAdopt: (ProjectEditDraft) -> Void
    @StateObject private var model: ClubAIDesignModel
    @State private var idea = ""
    @State private var style = ""
    @State private var minutes = ""
    @State private var generating = false
    @State private var operationID = UUID()
    @FocusState private var focused: Bool
    init(clubID: Int, session: PublishingSession?, flow: ClubAIDesignFlow, onAdopt: @escaping (ProjectEditDraft) -> Void) {
        self.clubID = clubID; self.session = session; self.onAdopt = onAdopt
        _model = StateObject(wrappedValue: ClubAIDesignModel(flow: flow))
    }
    private var input: ClubAIDesignInput? {
        if !minutes.isEmpty, Int(minutes) == nil { return nil }
        return try? .init(idea: idea, style: style, minutes: minutes.isEmpty ? nil : Int(minutes))
    }
    private var showsPreviousResult: Bool { generating || model.flow.resultIsPrevious(comparedTo: input) }
    var body: some View {
        let _ = model.revision
        Form {
            Section("context.ai.idea") {
                TextField("context.ai.idea", text: $idea, axis: .vertical).lineLimit(3...7).focused($focused)
                TextField("context.ai.style", text: $style).focused($focused)
                TextField("context.ai.minutes", text: $minutes).keyboardType(.numberPad).focused($focused)
                ClubAIDesignIdeaChips(clubID: clubID, session: session, idea: $idea, operationID: $operationID, generating: $generating)
            }.disabled(generating)
            if !model.flow.isConfigured {
                Label { Text("context.ai.disabled") } icon: { Image(systemName: "sparkles") }
                    .cyText(.body).foregroundStyle(CYColor.textSecondary)
            }
            if generating {
                ProgressView("context.ai.generating")
                CYPillButton("action.cancel", style: .tertiary) { operationID = UUID(); generating = false; model.flow.cancel(); model.revision += 1 }
                    .listRowBackground(Color.clear)
            } else {
                CYPillButton("context.ai.generate", style: model.flow.result == nil ? .primary : .secondary, systemImage: "sparkles") {
                    guard let input else { return }; focused = false
                    let request = UUID(); operationID = request; generating = true
                    Task {
                        guard operationID == request, generating, !Task.isCancelled else { return }
                        await model.flow.generate(input)
                        guard operationID == request else { return }; generating = false; model.revision += 1
                    }
                }.disabled(input == nil || !model.flow.canGenerate).accessibilityIdentifier("club.context.ai.generate")
                    .listRowBackground(Color.clear)
            }
            if let failure = model.flow.failure {
                Label { Text(LocalizedStringKey("context.ai.error." + String(describing: failure))) } icon: { Image(systemName: "exclamationmark.triangle") }
                    .cyText(.body).foregroundStyle(CYColor.textPrimary)
            }
            if let result = model.flow.result, let resultGeneration = model.flow.resultGeneration, let source = model.flow.resultInput {
                Section(showsPreviousResult ? LocalizedStringKey("clubAICandidate.previous") : LocalizedStringKey("context.ai.plan")) {
                    if showsPreviousResult { Text("clubAICandidate.previousNotice").font(.footnote) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("clubAICandidate.source").font(.caption).foregroundStyle(.secondary)
                        LabeledContent("clubAICandidate.generation") { Text(verbatim: String(resultGeneration)) }
                        LabeledContent("context.ai.idea") { Text(verbatim: source.idea).textSelection(.enabled) }
                        LabeledContent("context.ai.style") {
                            if source.style.isEmpty { Text("clubAICandidate.unspecified") }
                            else { Text(verbatim: source.style) }
                        }
                        LabeledContent("context.ai.minutes") {
                            if let minutes = source.minutes { Text(verbatim: String(minutes)) }
                            else { Text("clubAICandidate.unspecified") }
                        }
                    }.accessibilityIdentifier("clubAICandidate.source")
                    Text(verbatim: result.title).cyText(.sectionTitle)
                    Text(verbatim: result.subtitle).cyText(.body).foregroundStyle(CYColor.textSecondary)
                    Text(verbatim: result.storyline).cyText(.body)
                    if !result.fitReason.isEmpty { Text(verbatim: result.fitReason).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    ForEach(Array(result.nodes.enumerated()), id: \.offset) { idx, node in
                        CYListRow(verbatim: node.name, meta: [node.address, node.task].filter { !$0.isEmpty }.joined(separator: " · "), trailing: .none) {
                            Text(verbatim: String(idx + 1)).cyText(.label).monospacedDigit().frame(width: 28, height: 28)
                                .background(CYColor.bgRaised, in: Circle())
                        }
                    }
                    ForEach(Array(result.risks.enumerated()), id: \.offset) { _, risk in
                        Label { Text(verbatim: risk) } icon: { Image(systemName: "exclamationmark.triangle") }.cyText(.meta)
                    }
                }
                Section("context.ai.suggestions") { ForEach(Array(result.merchantSuggestions.enumerated()), id: \.offset) { _, value in Text(verbatim: value) } }
                if !result.promoCopy.isEmpty { Section("context.ai.promo") { Text(verbatim: result.promoCopy).textSelection(.enabled) } }
                ClubAIDesignPromoFeedback(clubID: clubID, session: session, flow: model.flow, resultGeneration: resultGeneration, promoCopy: result.promoCopy, operationID: $operationID, generating: $generating)
                Section {
                    Text("context.ai.adoptHint").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    CYPillButton(showsPreviousResult ? LocalizedStringKey("clubAICandidate.adoptPrevious") : LocalizedStringKey("context.ai.adopt"), style: .primary) {
                        guard !generating else { return }
                        if let draft = try? model.flow.adopt(clubID: clubID, generation: resultGeneration) { onAdopt(draft) }
                    }.disabled(generating || !model.flow.canAdoptResult)
                        .accessibilityIdentifier("club.context.ai.adopt").listRowBackground(Color.clear)
                }
            }
        }.navigationTitle("context.ai.title").scrollDismissesKeyboard(.interactively).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("action.done") { focused = false } } }
            .onChange(of: session) { _, _ in operationID = UUID(); generating = false; model.flow.cancel(); idea = ""; style = ""; minutes = ""; model.revision += 1 }
            .onDisappear { operationID = UUID(); generating = false; model.flow.cancel(); model.revision += 1 }
    }
}
/// Club owner context is supplied by a freshly read club detail. Adoption is a local draft;
/// ordinary project-editor validation, authorization and publish gates remain intact.
@MainActor struct SessionClubAIDesignView: View {
    @ObservedObject var session: AppSession
    let clubID: Int
    @State private var seed: ProjectEditDraft?
    @State private var openEditor = false
    var body: some View {
        ClubAIDesignView(clubID: clubID, session: session.publishingSession,
            flow: ClubAIDesignFlow(generator: session.makePublishingAuxiliaryService(feature: .publishingAIClub).map { ClubAIDesignGenerator(service: $0) }, current: { session.publishingSession })) {
                seed = $0; openEditor = true
            }
            .id(session.publishingSession?.epoch)
            .navigationDestination(isPresented: $openEditor) {
                if let seed {
                    ProjectEditView(coordinator: session.projectEditor(product: seed.product), sessionRevision: session.sessionRevision, seed: seed,
                        publisherClient: session.publisherLifecycleContext?.client).id(session.projectEditorContextID)
                }
            }
            .onChange(of: session.publishingSession) { _, _ in seed = nil; openEditor = false }
    }
}
