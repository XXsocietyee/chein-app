import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// fix/1128c-ai-showcase step 2: "Create with AI", the AI first step of the build process. Level C · Utility (a plain
/// grouped list). Reached from the home AI showcase, the 发布 tab "+" (first item) and the publish menu (first section).
/// Players: Draft with AI. Club hosts: also Fill template with AI and Design a club event with AI (backend `gateRole`).
@MainActor struct SessionAICreationHubView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.rootSignIn) private var rootSignIn

    var body: some View {
        Group {
            if session.publishingSession == nil {
                ContentUnavailableView {
                    Label("aiCreation.signedOut.title", systemImage: "wand.and.stars")
                } description: {
                    Text("aiCreation.signedOut.body")
                } actions: {
                    if rootSignIn.isAvailable {
                        Button("action.goSignIn") { rootSignIn() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("aiCreation.signIn")
                    }
                }
            } else {
                list
            }
        }
        .navigationTitle(Text("aiCreation.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("aiCreation.hub")
    }

    private var list: some View {
        List {
            Section {
                NavigationLink {
                    SessionAIThemeDraftStartView().environmentObject(session)
                } label: {
                    AICreationRow(title: "aiCreation.theme.title", detail: "aiCreation.theme.detail", symbol: "wand.and.stars")
                }
                .disabled(session.g6PublishingAIDraftFactory == nil)
                .accessibilityIdentifier("aiCreation.theme")
                if session.aiCreationIsClubHost {
                    NavigationLink {
                        SessionAITemplateFillView().environmentObject(session)
                    } label: {
                        AICreationRow(title: "aiCreation.template.title", detail: "aiCreation.template.detail", symbol: "square.and.pencil")
                    }
                    .accessibilityIdentifier("aiCreation.template")
                    if rootTabSwitch.isAvailable {
                        Button {
                            rootTabSwitch(.club)
                        } label: {
                            AICreationRow(title: "aiCreation.club.title", detail: "aiCreation.club.detail", symbol: "person.3.sequence")
                        }
                        .accessibilityIdentifier("aiCreation.club")
                    }
                }
            } header: {
                Text("aiCreation.section")
            } footer: {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if session.g6PublishingAIDraftFactory == nil {
                        Text("aiCreation.theme.unavailable")
                    }
                    Text("aiCreation.footer")
                    AIGCFilingNumberText()
                }
            }
            Section {
                Label("aiCreation.safety.title", systemImage: "checkmark.shield")
                Text("aiCreation.safety.detail")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("aiCreation.safety.section")
            }
            .accessibilityElement(children: .combine)
        }
        .listStyle(.insetGrouped)
    }
}

/// Settings-style row: tinted symbol, title, one line of detail.
@MainActor struct AICreationRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(CYColor.brand)
        }
    }
}

/// Draft with AI: the existing quick-publish page (MP `pages/publish/simple`) with its AI draft sheet opened first:
/// quota, progress / stop, review-before-apply, recovery of an earlier draft, then the places to confirm on the map
/// and the professional editor (whose publish step runs the AI safety precheck).
@MainActor struct SessionAIThemeDraftStartView: View {
    @EnvironmentObject private var session: AppSession
    @State private var seed: ProjectEditDraft?
    @State private var showEditor = false

    var body: some View {
        QuickPublishingView(placeSearch: PublishingMapKitAdapter.playerPublishing, account: session.publishingSession,
                            draftStore: session.publishingDraftStore, makeAIDraft: session.g6PublishingAIDraftFactory,
                            opensAIOnAppear: true, openProfessional: openProfessional)
            .id(session.publishingSession?.epoch)
            .navigationDestination(isPresented: $showEditor) { editor }
            .onChange(of: session.publishingSession) { _, _ in clear() }
    }

    private func openProfessional(_ value: ProjectEditDraft) {
        seed = value
        showEditor = true
    }

    private func clear() {
        seed = nil
        showEditor = false
    }

    @ViewBuilder private var editor: some View {
        if let seed {
            ProjectEditView(coordinator: session.projectEditor(product: seed.product, owner: seed.owner), sessionRevision: session.sessionRevision,
                            seed: seed, publisherClient: session.publisherLifecycleContext?.client,
                            publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) },
                            cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) })
                .id(session.projectEditorContextID)
        }
    }
}

/// Fill template with AI (club hosts, `api/ai/template/fill`): ask → progress / cancel → review → apply into the 互动
/// template editor → undo. Nothing is published from here; the editor keeps its own review and publish gates.
@MainActor struct SessionAITemplateFillView: View {
    @EnvironmentObject private var session: AppSession
    @State private var request = AITemplateFillRequest()
    @State private var phase: AITemplateFillPhase = .editing
    @State private var task: Task<Void, Never>?
    @State private var runner: AITemplateFillRunner?
    @State private var previousDraft: TemplateAuthoringDraft?
    @State private var applyFailed = false
    @State private var showsEditor = false
    @FocusState private var focused: Bool

    var body: some View {
        Form {
            AITemplateFillRequestSection(request: $request, focused: $focused, locked: phase.isBusy)
            AITemplateFillStatusSection(phase: phase, canGenerate: request.isComplete && runner != nil,
                                        generate: generate, cancel: cancel)
            if case .review(let suggestion) = phase {
                AITemplateFillReviewSection(suggestion: suggestion, apply: { apply(suggestion) }, discard: discard)
            }
            if previousDraft != nil {
                Section {
                    Button("aiTemplate.openEditor") { showsEditor = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("aiTemplate.openEditor")
                    Button("aiTemplate.undo", role: .destructive, action: undo)
                        .accessibilityIdentifier("aiTemplate.undo")
                } footer: {
                    Text("aiTemplate.applied.footer")
                }
            }
            if applyFailed {
                Text("aiTemplate.applyFailed")
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("aiTemplate.applyFailed")
            }
            Section { EmptyView() } footer: { AIGCFilingNumberText() }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text("aiTemplate.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsEditor) { sessionTemplateAuthoringEntry(session) }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("action.done") { focused = false } } }
        .task(id: session.publishingSession) { resetForAccount() }
        .onDisappear { cancel() }
        .sensoryFeedback(.success, trigger: phase.reviewID, condition: CYHapticTransition.becameSet)
    }

    private func resetForAccount() {
        cancel()
        runner = session.makeAITemplateFillRunner()
        previousDraft = nil
        applyFailed = false
        phase = .editing
    }

    private func generate() {
        guard let runner, request.isComplete, !phase.isBusy else { return }
        focused = false
        phase = .working
        let sent = request
        task = Task {
            let outcome = await runner.run(sent)
            guard !Task.isCancelled else { return }
            phase = AITemplateFillPhase(outcome)
        }
    }

    private func cancel() {
        task?.cancel()
        task = nil
        runner?.cancel()
        if phase.isBusy { phase = .editing }
    }

    private func discard() { phase = .editing }

    /// Applies into the session's retained 互动 template coordinator (the one the editor entry opens).
    private func apply(_ suggestion: AITemplateFillSuggestion) {
        let coordinator = session.templateAuthoringEditor(from: nil, scope: nil)
        let before = coordinator.draft
        let next = suggestion.applied(to: before)
        coordinator.change(next)
        guard coordinator.draft == next else { applyFailed = true; return }
        applyFailed = false
        previousDraft = before
        phase = .editing
    }

    private func undo() {
        guard let previousDraft else { return }
        let coordinator = session.templateAuthoringEditor(from: nil, scope: nil)
        coordinator.change(previousDraft)
        self.previousDraft = nil
    }
}

enum AITemplateFillPhase: Equatable {
    case editing, working
    case review(AITemplateFillSuggestion)
    case refused(String)
    case failed

    init(_ outcome: AITemplateFillRunner.Outcome) {
        switch outcome {
        case .suggestion(let value): self = .review(value)
        case .refused(let message): self = .refused(message)
        case .failed: self = .failed
        }
    }

    var isBusy: Bool { self == .working }
    var reviewID: String? {
        if case .review(let value) = self { return value.traceID ?? String(value.values.count) }
        return nil
    }
}

@MainActor private struct AITemplateFillRequestSection: View {
    @Binding var request: AITemplateFillRequest
    var focused: FocusState<Bool>.Binding
    let locked: Bool

    var body: some View {
        Section {
            TextField("aiTemplate.venue", text: $request.venue)
                .focused(focused)
                .accessibilityIdentifier("aiTemplate.venue")
            TextField("aiTemplate.idea", text: $request.idea, axis: .vertical)
                .lineLimit(3...7)
                .focused(focused)
                .accessibilityIdentifier("aiTemplate.idea")
            DisclosureGroup("aiTemplate.more") {
                TextField("aiTemplate.category", text: $request.category).focused(focused)
                TextField("aiTemplate.reward", text: $request.reward).focused(focused)
                TextField("aiTemplate.playStyle", text: $request.playStyle).focused(focused)
            }
        } header: {
            Text("aiTemplate.request")
        } footer: {
            Text("aiTemplate.request.footer")
        }
        .disabled(locked)
    }
}

@MainActor private struct AITemplateFillStatusSection: View {
    let phase: AITemplateFillPhase
    let canGenerate: Bool
    let generate: () -> Void
    let cancel: () -> Void

    var body: some View {
        Section {
            switch phase {
            case .working:
                HStack(spacing: CYSpacing.sm) {
                    ProgressView()
                    Text("aiTemplate.working")
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("aiTemplate.working")
                Button("action.cancel", role: .cancel, action: cancel)
                    .accessibilityIdentifier("aiTemplate.cancel")
            case .review:
                EmptyView()
            default:
                Button(action: generate) {
                    Label(LocalizedStringKey(phase == .failed ? "aiTemplate.retry" : "aiTemplate.generate"), systemImage: "sparkles")
                        .fontWeight(.semibold)
                }
                .disabled(!canGenerate)
                .accessibilityIdentifier("aiTemplate.generate")
            }
        } footer: {
            switch phase {
            case .refused(let message):
                Text(verbatim: message).foregroundStyle(CYColor.dangerText)
            case .failed:
                Text("aiTemplate.failed").foregroundStyle(CYColor.dangerText)
            default:
                if !canGenerate { Text("aiTemplate.needsInput") }
            }
        }
    }
}

@MainActor private struct AITemplateFillReviewSection: View {
    let suggestion: AITemplateFillSuggestion
    let apply: () -> Void
    let discard: () -> Void

    var body: some View {
        Section {
            Label("aiTemplate.reviewNotice", systemImage: "eye")
                .foregroundStyle(CYColor.warningText)
            ForEach(suggestion.rows) { row in
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(LocalizedStringKey("aiTemplate.field." + row.key))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(verbatim: row.value)
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }
            Button(action: apply) {
                Text("aiTemplate.apply").fontWeight(.semibold)
            }
            .accessibilityIdentifier("aiTemplate.apply")
            Button("aiTemplate.discard", role: .destructive, action: discard)
                .accessibilityIdentifier("aiTemplate.discard")
        } header: {
            Text("aiTemplate.review")
        }
    }
}
