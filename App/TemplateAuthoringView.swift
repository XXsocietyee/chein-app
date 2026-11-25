import SwiftUI
import Combine

@MainActor final class TemplateAuthoringModel: ObservableObject {
    let coordinator: TemplateAuthoringCoordinator
    @Published var draft = TemplateAuthoringDraft()
    @Published var review: TemplateAuthoringReview?
    @Published var revision = 0
    @Published var busy = false
    @Published private(set) var optionMediaIssue: String?
    @Published private(set) var ruleSteps = TemplateAuthoringRuleSteps(raw: nil)
    @Published private(set) var ruleStepIssue: String?
    @Published private(set) var ruleInputRevisions: [UUID: UUID] = [:]
    private var optionMediaGeneration = 0
    private(set) var storyEditorGeneration = 0
    var legacyHintGeneration = UUID()
    private(set) var metadataGeneration = UUID()
    private(set) var mediaReviewGeneration = UUID()
    var mediaReviewControllers: [WeakTemplateMediaReviewController] = []
    var mediaImageSelectionApproved: () -> Bool = { false }
    var mediaFixtureMode: String?
    private var epoch: TemplateAuthoringSession?
    private var draftIdentity: TemplateAuthoringIdentity?
#if DEBUG
    // Bounded, non-observable input facts. Only the explicitly synthetic fixture probe displays them.
    private let gameInputProbeID = UUID()
    private var gameInputAttempts = 0
    private var gameInputEvents: [String] = []
    func gameInputProbe(_ game: TemplateAdvancedGame) -> String {
        "model=\(gameInputProbeID.uuidString);attempts=\(gameInputAttempts);canEdit=\(canEdit);modelEnabled=\(draft.advanced.enabled(game.section));coordinatorEnabled=\(coordinator.draft.advanced.enabled(game.section));locked=\(coordinator.locked);events=\(gameInputEvents.joined(separator: "|"))"
    }
#endif
    init(coordinator: TemplateAuthoringCoordinator) { self.coordinator = coordinator }
    // A pending/terminal write locks edits but must not blank the same owner's retained hints.
    var canReadLegacyHints: Bool { coordinator.session != nil && epoch == coordinator.session && draftIdentity == coordinator.identity }
    var canReadMetadataDraft: Bool { coordinator.session != nil && epoch == coordinator.session && draftIdentity == coordinator.identity }
    var canReadStoryDraft: Bool { coordinator.session != nil && epoch == coordinator.session && draftIdentity == coordinator.identity }
    var canEdit: Bool { coordinator.session != nil && epoch == coordinator.session && draftIdentity == coordinator.identity && !coordinator.locked && coordinator.restore == .missing }
    func load() {
        retireMediaReviews()
        metadataGeneration = UUID()
        storyEditorGeneration += 1
        legacyHintGeneration = UUID()
        // Child editors mutate the shared local draft while the parent Form is offscreen.
        // Preserve those edits before a same-owner reappearance reload, never across identity changes.
        if canEdit, draft != coordinator.draft { coordinator.change(draft) }
        coordinator.synchronizeSession(); coordinator.open()
        draft = coordinator.draft; epoch = coordinator.session; draftIdentity = coordinator.identity
        resetRuleSteps()
        review = nil; optionMediaIssue = nil; revision += 1
    }
    func changed() {
        metadataGeneration = UUID()
        guard canEdit else { draft = coordinator.draft; return }
        if ruleSteps.storedText != draft.ruleInstructions { resetRuleSteps() }
        coordinator.change(draft); review = nil; revision += 1
        refreshMediaReviews()
    }
    /// Optional-module manager commits only its captured draft and retires media/timeline callbacks first.
    @discardableResult func commitOptionalModuleChange(_ change: TemplateOptionalModules.Change, matching scope: TemplateOptionalModules) -> Bool {
        guard canEdit, !busy, review == nil, let next = scope.applying(change, to: draft) else { return false }
        retireMediaReviews(); storyEditorGeneration += 1
        draft = next; changed(); reloadMediaReviews(); return true
    }
    func setGameEnabled(_ game: TemplateAdvancedGame, _ enabled: Bool) {
#if DEBUG
        gameInputAttempts += 1
        let inputAllowed = canEdit, previous = draft.advanced.enabled(game.section)
        defer {
            gameInputEvents.append("game=\(game.rawValue),requested=\(enabled),allowed=\(inputAllowed),before=\(previous),after=\(draft.advanced.enabled(game.section)),saved=\(coordinator.draft.advanced.enabled(game.section))")
            gameInputEvents = Array(gameInputEvents.suffix(3))
        }
#endif
        guard canEdit else { return }
        draft.advanced.setGameEnabled(game, enabled)
        if enabled { draft.validationMethod = .manual }
        // A pushed editor can outlive the parent Form's onChange observation.
        // Commit before returning to the parent, whose task reloads the coordinator.
        changed()
    }
    func restore() {
        retireMediaReviews()
        metadataGeneration = UUID()
        storyEditorGeneration += 1; legacyHintGeneration = UUID(); optionMediaGeneration += 1
        optionMediaIssue = nil; coordinator.restoreDraft(); draft = coordinator.draft
        resetRuleSteps(); revision += 1; reloadMediaReviews()
    }
    func discard() {
        retireMediaReviews()
        metadataGeneration = UUID()
        storyEditorGeneration += 1; legacyHintGeneration = UUID(); optionMediaGeneration += 1
        optionMediaIssue = nil; coordinator.discardLocal(); draft = coordinator.draft
        resetRuleSteps(); revision += 1; reloadMediaReviews()
    }
    func save() { guard canEdit else { return }; coordinator.change(draft); coordinator.saveLocal(); revision += 1 }
    func prepare(_ intent: TemplateAuthoringIntent) { guard canEdit else { return }; metadataGeneration = UUID(); coordinator.change(draft); coordinator.prepare(intent); review = coordinator.review; revision += 1 }
    func cancel() { coordinator.cancelReview(); review = nil; revision += 1 }
    func confirm(_ value: TemplateAuthoringReview) async { busy = true; review = nil; await coordinator.confirm(value); busy = false; revision += 1 }
    func readOriginalRequest(session: TemplateAuthoringSession, identity: TemplateAuthoringIdentity, requestID: String) async {
        guard !busy, let current = coordinator.session, TemplateAuthoringSavedResult.exactSession(current, session),
              coordinator.identity == identity, coordinator.pending?.serverRequest?.requestId == requestID,
              coordinator.canReadOriginalRequest else { return }
        busy = true; defer { busy = false; revision += 1 }
        await coordinator.readOriginalRequest()
    }
    func leave() {
        // Retained child callbacks must expire even when the same draft returns later.
        retireMediaReviews()
        metadataGeneration = UUID()
        storyEditorGeneration += 1; legacyHintGeneration = UUID(); optionMediaGeneration += 1
        coordinator.leaveScreen(); review = nil
    }
    private func retireMediaReviews() {
        mediaReviewGeneration = UUID()
        mediaReviewControllers = mediaReviewControllers.filter { $0.value != nil }
        mediaReviewControllers.forEach { $0.value?.retire() }
    }
    func mediaReferencesWillChange() { mediaReviewControllers.forEach { $0.value?.referencesWillChange() } }
    func refreshMediaReviews() { mediaReviewControllers.forEach { $0.value?.refresh() } }
    private func reloadMediaReviews() { mediaReviewControllers.forEach { $0.value?.reload() } }
    private func resetRuleSteps() {
        ruleSteps = .init(raw: draft.ruleInstructions); ruleStepIssue = nil; ruleInputRevisions = [:]
    }
    func ruleStep(_ id: UUID) -> Binding<String> {
        let bindingEpoch = epoch, bindingIdentity = draftIdentity
        return .init(get: {
            // Keep the same owner's locked review text visible; mutation still requires canEdit.
            guard self.epoch != nil, self.epoch == self.coordinator.session, self.epoch == bindingEpoch,
                  self.draftIdentity == self.coordinator.identity, self.draftIdentity == bindingIdentity,
                  self.ruleSteps.storedText == self.draft.ruleInstructions else { return "" }
            return self.ruleSteps.text(for: id) ?? ""
        }, set: { text in
            guard self.canEdit, self.epoch == bindingEpoch, self.draftIdentity == bindingIdentity,
                  self.ruleSteps.text(for: id) != nil else { return }
            self.changeRuleSteps(rejectedRowID: id) { try $0.update(id: id, text: text) }
        })
    }
    func addRuleStep() { changeRuleSteps { try $0.add() } }
    func removeRuleStep(_ id: UUID) { changeRuleSteps { try $0.remove(id: id) } }
    /// Design hand-off r1 CF-33 / CF-60: drag, the row "⋯" menu and VoiceOver share one reorder rule.
    func moveRuleSteps(fromOffsets source: IndexSet, toOffset destination: Int) {
        changeRuleSteps { try $0.move(fromOffsets: source, toOffset: destination) }
    }
    func ruleStepAction(_ action: EditorRowAction, at index: Int) {
        guard ruleSteps.rows.indices.contains(index) else { return }
        switch action {
        case .delete:
            if ruleSteps.canRemove { removeRuleStep(ruleSteps.rows[index].id) }
        case .moveUp, .moveDown:
            if let destination = EditorReorder.destination(for: action, index: index, count: ruleSteps.rows.count) {
                moveRuleSteps(fromOffsets: IndexSet(integer: index), toOffset: destination)
            }
        case .duplicate:
            break
        }
    }
    private func changeRuleSteps(rejectedRowID: UUID? = nil, _ edit: (inout TemplateAuthoringRuleSteps) throws -> Void) {
        guard canEdit, ruleSteps.storedText == draft.ruleInstructions else { return }
        do {
            var next = ruleSteps
            try edit(&next)
            ruleSteps = next; draft.ruleInstructions = next.storedText; ruleStepIssue = nil
            ruleInputRevisions = ruleInputRevisions.filter { next.text(for: $0.key) != nil }
            changed()
        } catch TemplateAuthoringRuleSteps.EditError.asciiLength {
            ruleStepIssue = "templateRules.asciiLimit"
            // Rejecting the model write alone leaves TextField's native editing buffer ahead.
            // Recreate only this control from the unchanged accepted row, never truncate source.
            if let rejectedRowID { ruleInputRevisions[rejectedRowID] = UUID() }
        } catch TemplateAuthoringRuleSteps.EditError.rowLimit {
            ruleStepIssue = "templateRules.rowLimit"
        } catch { /* Unsupported or stale rows remain unchanged. */ }
    }
    func optional(_ path: WritableKeyPath<TemplateAuthoringDraft, String?>) -> Binding<String> {
        let isMedia = path == \.questionImg || path == \.questionAudio || path == \.audioUrl
        let mediaGeneration = mediaReviewGeneration
        return .init(get: {
            if isMedia && (!self.canReadStoryDraft || self.mediaReviewGeneration != mediaGeneration) { return "" }
            return self.draft[keyPath: path] ?? ""
        }, set: {
            if isMedia {
                guard self.canEdit, self.mediaReviewGeneration == mediaGeneration else { return }
                self.mediaReferencesWillChange()
            }
            self.draft[keyPath: path] = $0.isEmpty ? nil : $0
        })
    }
    func number(_ path: WritableKeyPath<TemplateAuthoringDraft, Int?>) -> Binding<String> {
        .init(get: { self.draft[keyPath: path].map(String.init) ?? "" }, set: { self.draft[keyPath: path] = Int($0) })
    }
    func optionMedia(_ letter: TemplateChoiceOptionMedia.Letter, _ kind: TemplateChoiceOptionMedia.Kind) -> Binding<String> {
        let bindingEpoch = epoch, bindingIdentity = draftIdentity
        let bindingGeneration = optionMediaGeneration
        let mediaGeneration = mediaReviewGeneration
        return .init(get: {
            // A write-only lock must not hide this owner's unchanged media references.
            guard self.epoch != nil, self.epoch == self.coordinator.session, self.epoch == bindingEpoch,
                  self.draftIdentity == self.coordinator.identity, self.draftIdentity == bindingIdentity,
                  self.optionMediaGeneration == bindingGeneration, self.mediaReviewGeneration == mediaGeneration else { return "" }
            return self.draft.choiceOptionMedia.text(letter, kind) ?? ""
        }, set: { text in
            guard self.canEdit, self.epoch == bindingEpoch, self.draftIdentity == bindingIdentity,
                  self.optionMediaGeneration == bindingGeneration, self.mediaReviewGeneration == mediaGeneration, self.draft.validationMethod == .choice,
                  self.draft.choiceOptionMedia.isSupported else { return }
            do {
                self.mediaReferencesWillChange()
                try self.draft.setChoiceOptionMedia(letter, kind, to: text)
                self.optionMediaIssue = nil
                self.changed()
            } catch { self.optionMediaIssue = "templateAuthor.optionMedia.limit" }
        })
    }
}

/// Host within the existing navigation stack. Intro/name/edit are replacement steps.
/// CF-44 (polish-d-r1): the signed-in session's 16:9 cover upload service for the template editor, supplied by the
/// screens that hold the session (发布 tab, 我的 → 创作) so the intermediate save/launch flows need no new parameters.
struct TemplateCoverSource {
    let makeService: () -> ActivityCoverService?
    let session: () -> PublishingSession?
}
private struct TemplateCoverSourceKey: EnvironmentKey { static let defaultValue: TemplateCoverSource? = nil }
extension EnvironmentValues {
    var templateCoverSource: TemplateCoverSource? {
        get { self[TemplateCoverSourceKey.self] }
        set { self[TemplateCoverSourceKey.self] = newValue }
    }
}

@MainActor struct TemplateAuthoringView: View {
    @Environment(\.templateCoverSource) private var environmentCover
    @Environment(\.locale) private var locale
    /// verify-r2 N-01: this page applies the topicEditor domain to itself, so its own palette is that domain's.
    /// Reading `cyPalette` here gave the pushing NavigationStack's palette (the dark player shell).
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private enum Step { case intro, name, edit }
    @StateObject private var model: TemplateAuthoringModel
    @StateObject private var media: TemplateMediaReviewController
    @State private var step: Step = .intro
    @State private var preview = false
    @State private var discard = false
    @State private var toastMessage: String?
    // Design hand-off r1 CF-44 / CF-45 / CF-17: outline, preview gate and jump-to-first-error.
    @State private var outlineCurrent: EditorOutlineSection = .info
    @State private var previewMissing = false
    @State private var pendingJump = false
    @State private var errorJumps = 0
    // CF-44 (polish-d-r1): the cover is chosen with the shared 16:9 picker/crop/upload, not typed as a URL.
    @StateObject private var cover = ActivityCoverAuthoringOwner()
    // Screens r4 (verify-r1 2.10): 题目图片 uses the same picker / crop / upload owner as the cover, with its own target.
    @StateObject private var questionImage = ActivityCoverAuthoringOwner()
    // Screens r4: C2's one delete rule (undo toast + UndoManager) for the gameplay editor's lists.
    @StateObject private var undoCenter = ProjectEditUndoCenter()
    @Environment(\.undoManager) private var undoManager
    @State private var gameplayPicker = false
    @State private var showsSignIn = false
    @Environment(\.scenePhase) private var scenePhase
    private let makeCoverService: (() -> ActivityCoverService?)?
    private let coverSession: () -> PublishingSession?
    let sessionRevision: UInt64
    let metadataReader: (any DiscoveryReading)?
    private let onSavedDraft: ((TemplateAuthoringSavedDraft) -> Void)?
    private let canReturnSavedDraft: (TemplateAuthoringSavedDraft) -> Bool
    init(coordinator: TemplateAuthoringCoordinator, sessionRevision: UInt64, metadataReader: (any DiscoveryReading)? = nil,
         imageSelectionApproved: @escaping () -> Bool = { false }, mediaFixtureMode: String? = nil,
         onSavedDraft: ((TemplateAuthoringSavedDraft) -> Void)? = nil,
         canReturnSavedDraft: @escaping (TemplateAuthoringSavedDraft) -> Bool = { _ in false },
         makeCoverService: (() -> ActivityCoverService?)? = nil,
         coverSession: @escaping () -> PublishingSession? = { nil },
         startsInEditor: Bool = false) {
        self.makeCoverService = makeCoverService; self.coverSession = coverSession
        // MP `pages/publish/temp/index` opens on the editor (the intro is its own page, template-intro).
        _step = State(initialValue: startsInEditor ? .edit : .intro)
        let value = TemplateAuthoringModel(coordinator: coordinator)
        value.mediaImageSelectionApproved = imageSelectionApproved; value.mediaFixtureMode = mediaFixtureMode
        _model = StateObject(wrappedValue: value)
        _media = StateObject(wrappedValue: .init(model: value, imageSelectionApproved: imageSelectionApproved, fixtureMode: mediaFixtureMode))
        self.sessionRevision = sessionRevision; self.metadataReader = metadataReader
        self.onSavedDraft = onSavedDraft; self.canReturnSavedDraft = canReturnSavedDraft
    }
    private var outline: EditorOutline {
        EditorOutline(current: outlineCurrent, errors: EditorOutline.errors(forIssues: model.draft.publishIssues))
    }
    private func jump(to section: EditorOutlineSection, _ proxy: ScrollViewProxy) {
        outlineCurrent = section
        withAnimation(.easeOut(duration: EditorMotionSpec.pushSeconds)) { proxy.scrollTo(section.anchor, anchor: .top) }
    }
    private func jumpToFirstError(_ proxy: ScrollViewProxy) {
        jump(to: outline.firstError ?? .info, proxy); errorJumps += 1
    }
    /// verify-r2 N-01: the topic-editor domain wraps the whole page (ground, section bar, bottom bar), not only the Form.
    var body: some View {
        pageBody.cyDomainScreen(.topicEditor)
            .sheet(isPresented: $showsSignIn) { LoginView(intent: .player) }
    }
    @ViewBuilder private var pageBody: some View {
        let _ = cover.bind(read: {
            guard model.coordinator.session != nil, step == .edit else { return nil }
            return .init(session: coverSession() ?? environmentCover?.session(), target: .template(model.coordinator.identity.draftID),
                         draft: try? JSONEncoder().encode(model.draft), reference: model.draft.imgUrl ?? "", editable: model.canEdit)
        }, apply: { reference in
            guard model.canEdit else { return false }
            model.draft.imgUrl = reference; return true
        }, service: { (makeCoverService ?? environmentCover?.makeService)?() })
        let _ = questionImage.bind(read: {
            guard model.coordinator.session != nil, step == .edit else { return nil }
            return .init(session: coverSession() ?? environmentCover?.session(), target: .templateQuestionImage(model.coordinator.identity.draftID),
                         draft: try? JSONEncoder().encode(model.draft), reference: model.draft.questionImg ?? "", editable: model.canEdit)
        }, apply: { reference in
            guard model.canEdit else { return false }
            model.mediaReferencesWillChange()
            model.draft.questionImg = reference.isEmpty ? nil : reference; return true
        }, service: { (makeCoverService ?? environmentCover?.makeService)?() })
        ScrollViewReader { proxy in
        Form {
            // verify-r1 2.9 / N-09: while editing, the page title is the inline nav title, so the section bar sits
            // directly under the bar; the 34 pt heading stays on the intro and name steps only.
            // C-I2: the intro has no title (MP P-22: the copy is the hero); the heading stays on the name step.
            if !(model.coordinator.session != nil && step != .name) {
                Section { CYHeroHeader("templateAuthor.title") }.e1HeroRow()
            }
            if model.coordinator.session == nil {
                // C-T7: MP 登录后编辑玩法模板 + 去登录.
                Section { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "templateAuthor.signIn", messageIdentifier: "templateAuthor.signIn",
                                       actionTitle: "action.goSignIn", actionStyle: .primary) { showsSignIn = true }
                    .listRowBackground(Color.clear) }
            }
            restoreSection
            if model.coordinator.session != nil {
                switch step {
                case .intro: intro
                case .name: name
                case .edit: editor
                }
            }
            if let key = model.coordinator.messageKey { Section { Text(LocalizedStringKey(key)).accessibilityIdentifier("templateAuthor.status") } }
            if let request = model.coordinator.pending?.serverRequest, let session = model.coordinator.session {
                let identity = model.coordinator.identity
                Section {
                    #if DEBUG
                    // C-T11: the raw request id is support detail, shown in debug builds only.
                    Text(verbatim: "Request: " + request.requestId).textSelection(.enabled)
                    #endif
                    if let receipt = model.coordinator.pending?.serverReceipt {
                        Text(verbatim: receipt.state)
                        Text(verbatim: locale.language.languageCode?.identifier == "zh" ? "保存/提审回执不等于审核通过、上架或媒体检查完成。" : "A save or review-submission receipt does not mean approval, listing, or completed media checks.")
                    }
                    CYPillButton(verbatim: locale.language.languageCode?.identifier == "zh" ? "查询原请求结果" : "Read original request result", style: .secondary, systemImage: "arrow.clockwise") {
                        Task { await model.readOriginalRequest(session: session, identity: identity, requestID: request.requestId) }
                    }.disabled(!model.coordinator.canReadOriginalRequest || model.busy)
                        .accessibilityIdentifier("templateAuthor.readOriginalRequest").e1ActionRow()
                }
            }
            if let onSavedDraft {
                Section {
                    Text("projectNodeCreate.draftOnly", tableName: "ProjectNodeTemplateCreation")
                    if let saved = model.coordinator.savedDraft {
                        Text(verbatim: "#" + String(saved.memberTemplateID.rawValue))
                        CYPillButton("projectNodeCreate.return", tableName: "ProjectNodeTemplateCreation") { onSavedDraft(saved) }
                            .disabled(!canReturnSavedDraft(saved)).accessibilityIdentifier("projectNodeCreate.return").e1ActionRow()
                    } else if model.coordinator.locked {
                        Text("projectNodeCreate.noReceipt", tableName: "ProjectNodeTemplateCreation")
                    }
                }
            }
        }
        .formStyle(.grouped).cyGroupedSurface()
        .environment(\.configUndoCenter, undoCenter)
        .environment(\.templateMediaReviewController, media)
        .environment(\.templateQuestionImageOwner, (makeCoverService != nil || environmentCover != nil) ? questionImage : nil)
        .editorToast($undoCenter.toast)
        .navigationTitle(model.coordinator.session != nil && step == .edit ? appLocalized("templateAuthor.editNavTitle", locale: locale) : "")
        .navigationBarTitleDisplayMode(.inline)
        .cyPushedChrome(domain: .topicEditor)
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.coordinator.session != nil, step == .edit {
                EditorSectionBar(outline: outline) { jump(to: $0, proxy) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.coordinator.session != nil, step == .edit {
                CYFooterBar {
                    let isAX = dynamicTypeSize.isAccessibilitySize
                    let layout = isAX ? AnyLayout(VStackLayout(spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
                    layout {
                        // C-T5 (MP temp wxml:1492): 保存草稿 sits in the bottom bar as the secondary action.
                        Button { model.prepare(.saveDraft) } label: { Text("templateAuthor.reviewDraft") }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: isAX, compact: true))
                            .disabled(!model.canEdit || !model.draft.canSave || model.draft.validationMethod.isLocalConfigurationOnly)
                            .accessibilityIdentifier("templateAuthor.reviewDraft")
                        // CF-45: one preview entry. With missing data it opens on a state that says what is missing.
                        Button { if model.draft.publishIssues.isEmpty { preview = true } else { previewMissing = true } } label: {
                            Label { EditorKitText.text("editorKit.preview") } icon: { Image(systemName: "play.circle") }
                        }
                        .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: isAX, compact: true))
                        .disabled(!model.canEdit || model.draft.validationMethod == .preference)
                        .accessibilityIdentifier("templateAuthor.preview")

                        if onSavedDraft == nil {
                            // CF-17: the primary stays enabled for missing data and jumps to the first problem.
                            Button {
                                if model.draft.publishIssues.isEmpty { model.prepare(.publish) } else { jumpToFirstError(proxy) }
                            } label: {
                                Text("templateAuthor.reviewPublish")
                            }
                            .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true, compact: true))
                            .disabled(!model.canEdit || model.draft.validationMethod.isLocalConfigurationOnly)
                            .accessibilityIdentifier("templateAuthor.reviewPublish")
                        }
                    }
                }
            }
        }
        .onChange(of: pendingJump) { _, jumpNow in
            if jumpNow { pendingJump = false; jumpToFirstError(proxy) }
        }
        }
        .sensoryFeedback(.error, trigger: errorJumps)
        .editorSheet(isPresented: $previewMissing, family: .nodePreview) {
            EditorSheetPage(title: EditorKitText.text("editorKit.preview.missing.title"), leading: .close) {
                EditorStateView(
                    kind: .empty,
                    title: EditorKitText.text("editorKit.preview.missing.title"),
                    message: model.draft.publishIssues.sorted().first.map { Text(LocalizedStringKey($0)) },
                    actionTitle: EditorKitText.text("editorKit.preview.missing.action"),
                    accessibilityID: "editorKit.templatePreviewMissing"
                ) { previewMissing = false; pendingJump = true }
            }
            .themeDomain(.topicEditor)
        }
        .modifier(TemplateAuthoringExitGuard(model: model, overlaysOpen: { preview || discard || previewMissing || media.review != nil }))
        .disabled(model.busy)
        .task { model.load(); media.reload() }
        .onChange(of: model.draft) { _, _ in model.changed() }
        .onChange(of: sessionRevision) { _, _ in preview = false; step = .intro; model.load(); media.reload() }
        .onDisappear { if !cover.hasNativeSelection { cover.disappear() } }
        .onDisappear { if !questionImage.hasNativeSelection { questionImage.disappear() } }
        .onDisappear { media.retire(); model.leave() }
        .onAppear { cover.appear(active: scenePhase == .active); questionImage.appear(active: scenePhase == .active) }
        .onAppear { undoCenter.attach(undoManager) }
        .onChange(of: scenePhase) { _, phase in cover.setActive(phase == .active); questionImage.setActive(phase == .active) }
        .background { ActivityCoverLifetime(owner: cover, departure: {}).frame(width: 0, height: 0) }
        .background { RetainedImagePresenterHost(host: cover.pickerHost).frame(width: 0, height: 0) }
        .background { ActivityCoverLifetime(owner: questionImage, departure: {}).frame(width: 0, height: 0) }
        .background { RetainedImagePresenterHost(host: questionImage.pickerHost).frame(width: 0, height: 0) }
        // Screens r4 · Figma 237:71933 (CF-51, SR2-19): 选择玩法 as a sheet with the one confirm in the header.
        .editorSheet(isPresented: $gameplayPicker, family: .gameplayPicker) {
            TemplateGameplayPickerSheet(current: model.draft.validationMethod, locked: !model.draft.advanced.enabledGames.isEmpty,
                                        commit: { picked in model.legacyHintMethodBinding().wrappedValue = picked },
                                        commitGame: { game in model.setGameEnabled(game, true) })
            .themeDomain(.topicEditor)
        }
        .preference(key: TemplateAuthoringSavedResultPreferenceKey.self, value: TemplateAuthoringSavedResultObservation.capture(model: model, eligible: onSavedDraft == nil))
        .preference(key: TemplateAuthoringPublishResultPreferenceKey.self, value: TemplateAuthoringPublishResultObservation.capture(model: model, eligible: onSavedDraft == nil))
        .modifier(TemplateMediaReviewPresentation(controller: media))
        .sheet(isPresented: $preview) {
            TemplateConfiguredRehearsalPreview(model: model) { TemplateAuthoringPreviewView(draft: model.draft) }
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.topicEditor)
        }
        .sheet(item: $model.review, onDismiss: { model.cancel() }) { value in
            NavigationStack { TemplateAuthoringReviewView(review: value, canSimulate: model.coordinator.canSimulate, canSubmit: model.coordinator.canSubmit, confirm: { Task { await model.confirm(value) } }, cancel: { model.cancel() }) }
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.topicEditor)
        }
        .cyModalConfirm(
            isPresented: $discard,
            title: appLocalized("templateAuthor.discardQuestion", locale: locale),
            cancelTitle: appLocalized("templateAuthor.cancel", locale: locale),
            confirmTitle: appLocalized("templateAuthor.discard", locale: locale),
            isDestructive: true,
            onCancel: { discard = false },
            onConfirm: { discard = false; model.discard() }
        )
        .onChange(of: model.coordinator.messageKey) { _, key in
            if let key { toastMessage = appLocalized(String.LocalizationValue(stringLiteral: key), locale: locale) }
        }
        .cyToast(verbatimMessage: $toastMessage)
    }
    @ViewBuilder private var restoreSection: some View {
        if model.coordinator.restore != .missing {
            Section("templateAuthor.restoreTitle") {
                if case .ready = model.coordinator.restore {
                    Text("templateAuthor.restoreMessage")
                    CYPillButton("templateAuthor.restore", style: .secondary, systemImage: "arrow.uturn.backward") { model.restore(); step = .edit }
                        .disabled(model.coordinator.locked).accessibilityIdentifier("templateAuthor.restore").e1ActionRow()
                } else { Text("templateAuthor.restoreFailed") }
                Button("templateAuthor.discard", role: .destructive) { discard = true }.disabled(model.coordinator.locked)
            }
        }
    }
    private var intro: some View {
        // Mini-program publish/template-intro: covers, value proposition, 开始创建. No explanatory rows.
        Section {
            TemplateAuthoringIntroExperience(model: model, reader: metadataReader, onContinue: { step = .name })
        }
    }
    private var name: some View {
        // Mini-program: naming comes right after the intro, then the editor.
        Section("templateAuthor.nameStep") {
            HStack {
                TextField("templateAuthor.field.title", text: $model.draft.title).accessibilityIdentifier("templateAuthor.field.title")
                TemplateBasicFieldClearButton(model: model, field: .title)
            }
            Button { step = .edit } label: { Text("templateAuthor.continue") }
                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                .disabled(!model.draft.canSave || !model.canEdit).accessibilityIdentifier("templateAuthor.continue")
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
    }
    /// Mini-program publish/temp order: cover and name, template info, rules, completion
    /// (game), reward and story, tools; then save draft, preview and publish.
    @ViewBuilder private var editor: some View {
        Group {
            // CF-22: one save status, an icon plus two characters; details on tap.
            Section {
                HStack {
                    EditorSaveChip(
                        state: model.coordinator.locked ? .failed : .saved,
                        detail: EditorKitText.text(model.coordinator.locked ? "editorKit.save.detail.pending" : "editorKit.save.detail.local")
                    )
                    Spacer(minLength: 0)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            Section {
                // verify-r1 2.9: the name is edited on the cover (header below); no separate 名称 row.
                // CF-44: no raw URL field. The 16:9 tile above shows the cover; the shared picker crops and uploads it.
                if makeCoverService != nil || environmentCover != nil {
                    ActivityCoverAuthoringSection(owner: cover, kind: .template)
                        .accessibilityIdentifier("templateCover.section")
                } else if model.draft.imgUrl?.isEmpty == false {
                    HStack {
                        Text("template.set", tableName: "ActivityCoverAuthoring").foregroundStyle(palette.textSecondary)
                        Spacer(minLength: CYSpacing.sm)
                        TemplateBasicFieldClearButton(model: model, field: .cover)
                    }
                }
            } header: {
                // CF-44: a 16:9 cover with the title over its bottom edge.
                TemplateAuthoringCoverHeader(imageURL: model.draft.imgUrl, title: $model.draft.title, editable: model.canEdit,
                                             defaultCover: TemplateInteractionDefaultCover.image(title: model.draft.title, advanced: model.draft.advanced))
            }
            .id(EditorOutlineSection.info.anchor)
            Section("templateAuthor.basics") {
                HStack(alignment: .bottom) {
                    TemplateAuthoringField("description", text: $model.draft.description, multiline: true)
                    TemplateBasicFieldClearButton(model: model, field: .description)
                }
                if model.draft.publishIssues.contains("templateAuthor.validation.descriptionLength") {
                    Text("templateAuthor.validation.descriptionLength").cyText(.meta).foregroundStyle(palette.danger)
                }
                TemplateAuthoringField("requiredMaterials", text: model.optional(\.requiredMaterials))
                TemplateAuthoringVenueField(model: model)
                TemplateAuthoringMetadataFields(model: model, reader: metadataReader)
                TemplateAuthoringField("difficulty", text: model.optional(\.difficulty))
                Toggle("templateAuthor.sync", isOn: .init(get: { model.draft.isSync == 1 }, set: { model.draft.isSync = $0 ? 1 : 0 }))
            }
            Section {
                TemplateAuthoringRuleFields(model: model)
            }
            .id(EditorOutlineSection.rules.anchor)
            Section("templateAuthor.finish") {
                Toggle("templateAuthor.moduleEnabled", isOn: $model.draft.finishEnabled)
                if model.draft.finishEnabled {
                    // Screens r4 · Figma 237:71933: the gameplay is picked in the 选择玩法 sheet (grid of previews).
                    Button { gameplayPicker = true } label: {
                        EditorRow(label: ConfigR4Text.text("config.gameplay.row"),
                                  value: Text(LocalizedStringKey(model.draft.validationMethod.labelKey)),
                                  systemImage: TemplateGameplayPickerSheet.symbol(model.draft.validationMethod),
                                  isLocked: !model.draft.advanced.enabledGames.isEmpty)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.draft.advanced.enabledGames.isEmpty).accessibilityIdentifier("templateAuthor.method")
                    TemplateAuthoringCompletionFields(model: model)
                    NavigationLink("templateAuthor.advanced") { TemplateAuthoringAdvancedView(model: model) }.accessibilityIdentifier("creatorComposition.open")
                }
            }
            .id(EditorOutlineSection.gameplay.anchor)
            // r9 C-T3: MP temp/index.wxml:108-118, :1056-1074 (扫完回复 · 状态不好时松一点 · 可触发的结果).
            if model.draft.finishEnabled { TemplateAuthoringGapRound4Section(model: model) }
            TemplateAuthoringRewardStoryFields(model: model)
            Section {
                NavigationLink("templateModules.title") { TemplateOptionalModuleManager(model: model) }
                    .accessibilityIdentifier("templateModules.open")
            }
            .id(EditorOutlineSection.tools.anchor)
            Section(String(localized: LocalizedStringResource("templateMedia.title", defaultValue: "Media", locale: locale))) {
                TemplateMediaReviewFields(controller: media)
            }
            if !model.draft.publishIssues.isEmpty {
                Section("templateAuthor.validationTitle") {
                    ForEach(Array(Set(model.draft.publishIssues)).sorted(), id: \.self) {
                        Label(LocalizedStringKey($0), systemImage: "exclamationmark.circle")
                            .cyText(.meta)
                            .foregroundStyle(palette.danger)
                    }
                }
            }
            if model.draft.validationMethod.isLocalConfigurationOnly {
                Section {
                    Text("templateAuthor.localConfigurationOnly").cyText(.meta).foregroundStyle(palette.textSecondary)
                }
            }
            Section {
                CYPillButton("templateAuthor.saveLocal", style: .tertiary) { model.save() }.accessibilityIdentifier("templateAuthor.saveLocal").e1ActionRow()
            }
        }.disabled(!model.canEdit)
    }

}

struct TemplateAuthoringField: View {
    let key: String
    @Binding var text: String
    let multiline: Bool
    let accessibilityID: String?
    @Environment(\.cyPalette) private var palette
    init(_ key: String, text: Binding<String>, multiline: Bool = false, accessibilityID: String? = nil) {
        self.key = key; _text = text; self.multiline = multiline; self.accessibilityID = accessibilityID
    }
    /// Design hand-off r1 CF-47 / CF-48: the unit is a suffix, not part of the label; 积分 is the only currency.
    static let limits: [String: Int] = ["description": 30, "kicker": 32]
    static let units: [String: EditorUnit] = [
        "xp": .points, "seconds": .seconds, "holdSeconds": .seconds, "durationSeconds": .seconds,
        "targetSeconds": .seconds, "audioDuration": .seconds, "bearing": .degrees, "tolerance": .degrees
    ]
    var body: some View {
        if let unit = Self.units[key] {
            numberBody(unit)
        } else {
            // verify-r1 3.5 / CF-10 (`237:43689`): text fields are the Editor kit field (label above, filled field,
            // live counter at the limit). Number fields keep the suffix layout below.
            EditorField(label: Text(LocalizedStringKey("templateAuthor.field." + key)), text: $text,
                        kind: multiline ? .area : .line, limit: Self.limits[key],
                        accessibilityID: accessibilityID ?? "templateAuthor.field." + key)
                .textInputAutocapitalization(.sentences)
                .padding(.vertical, 3)
        }
    }
    private func numberBody(_ unit: EditorUnit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey("templateAuthor.field." + key))
                .cyText(.label)
                .foregroundStyle(palette.textSecondary)
            HStack(spacing: CYSpacing.s1_5) {
                TextField(LocalizedStringKey("templateAuthor.field." + key), text: $text)
                    .lineLimit(1...1).accessibilityIdentifier(accessibilityID ?? "templateAuthor.field." + key)
                    .cyText(.bodyCompact)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                EditorKitText.text(unit.key).cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
            }
        }.padding(.vertical, 3)
    }
}

struct TemplateAuthoringReviewView: View {
    let review: TemplateAuthoringReview
    let canSimulate: Bool
    let canSubmit: Bool
    let confirm: () -> Void
    let cancel: () -> Void
    /// verify-r2 N-01: this page applies the topicEditor domain to itself, so its own palette is that domain's.
    /// Reading `cyPalette` here gave the pushing NavigationStack's palette (the dark player shell).
    private var palette: CYDomainPalette { CYDomainPalette(.topicEditor) }
    var body: some View {
        Form {
            Section { CYHeroHeader("templateAuthor.reviewTitle") }.e1HeroRow()
            Section {
                Text(verbatim: review.title).cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                Text(review.request.path.hasSuffix("publish") ? "templateAuthor.publishReview" : "templateAuthor.draftReview")
                    .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                if !canSubmit && !canSimulate { Text("templateAuthor.unavailable").foregroundStyle(palette.textSecondary) }
            }
            if let draft = review.draft, !draft.advanced.enabledConfigurationLabelKeys.isEmpty {
                Section("creatorComposition.review") {
                    ForEach(draft.advanced.enabledConfigurationLabelKeys, id: \.self) { key in
                        Text(LocalizedStringKey(key)).accessibilityIdentifier("creatorComposition.review." + key)
                    }
                    if draft.advanced.hasRootAuthoringConfiguration { Text("creatorRoot.rules") }
                }
            }
            if canSimulate {
                Section { Text("templateAuthor.fixtureNotice").foregroundStyle(palette.textSecondary) }
            }
        }.formStyle(.grouped).cyGroupedSurface().cyHeroScreen().cyDomainScreen(.topicEditor)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if canSimulate || canSubmit {
                    CYFooterBar {
                        if canSimulate {
                            Button(action: confirm) { Text("templateAuthor.confirmSimulation") }
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true, compact: true))
                                .accessibilityIdentifier("templateAuthor.confirmSimulation")
                        } else if canSubmit {
                            Button(action: confirm) { Text("templateAuthor.confirmRequest") }
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true, compact: true))
                                .accessibilityIdentifier("templateAuthor.confirmRequest")
                        }
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("templateAuthor.cancel", action: cancel).accessibilityIdentifier("templateAuthor.cancelReview") } }
    }
}

@MainActor struct TemplateAuthoringPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let draft: TemplateAuthoringDraft
    @Environment(\.templateConfiguredRehearsals) private var configuredRehearsals
    var body: some View {
        List {
            // Screens r4 · Figma 238:25435 (CF-63): the five-step 玩家视角预览 leads; the per-gameplay rehearsals stay below.
            Section { TemplatePlayerPreviewPager(draft: draft) }.e1HeroRow()
            Section("templateAuthor.finish") {
                Text(LocalizedStringKey(draft.validationMethod.labelKey))
                if draft.validationMethod.rawValue == 7 {
                    TemplateSensorDraftPreviewContent(draft: draft.sensorDraft ?? .init())
                }
                if let question = draft.questionName { Text(verbatim: question) }
                if draft.validationMethod == .choice { ForEach([draft.questionA, draft.questionB, draft.questionC, draft.questionD].compactMap { $0 }, id: \.self) { Text(verbatim: $0) } }
                if draft.validationMethod == .choice {
                    TemplateChoiceOptionMediaFields(configuration: draft.choiceOptionMedia,
                        field: { letter, kind in .constant(draft.choiceOptionMedia.text(letter, kind) ?? "") }, readOnly: true)
                }
                if let configuredRehearsals, configuredRehearsals.offersLegacyQuestion {
                    TemplateConfiguredLegacyRehearsalPreviewButton(controller: configuredRehearsals)
                }
                ForEach(draft.advanced.enabledGames) { game in
                    Text(LocalizedStringKey(game.labelKey))
                    if let configuredRehearsals, configuredRehearsals.route(for: game) != nil {
                        TemplateConfiguredRehearsalPreviewButton(controller: configuredRehearsals, game: game)
                    }
                    else if game.isMiniProgramAddition { NavigationLink("playkitAuthor.preview") { TemplateMiniGamePreviewView(draft: draft.advanced, game: game) } }
                    else if game == .dice && draft.advanced.diceMode == "d20" { NavigationLink("creatorRoot.d20Preview") { TemplateD20RehearsalView(draft: draft.advanced) } }
                    else { Text("templateAuthor.noGameplay").foregroundStyle(.secondary) }
                }
            }
            if draft.advanced.hasRootAuthoringConfiguration {
                Section("creatorRoot.rules") { NavigationLink("creatorRoot.rehearse") { TemplateRootRehearsalView(draft: draft.advanced) } }
            }
            if !draft.advanced.enabledCreatorFamilies.isEmpty {
                Section("creator.modules") {
                    ForEach(draft.advanced.enabledCreatorFamilies) { family in
                        NavigationLink(LocalizedStringKey(family.labelKey)) { TemplateCreatorRehearsalView(draft: draft.advanced, family: family) }
                    }
                }
            }
            if draft.storyEnabled {
                Section("templateAuthor.story") {
                    if let story = try? draft.preparedStoryText() { Text(verbatim: story) }
                    ForEach((try? draft.storyBeats()) ?? []) { beat in
                        VStack(alignment: .leading) { if !beat.tag.isEmpty { Text(verbatim: beat.tag).cyText(.caption) }; Text(verbatim: beat.text); if !beat.imgs.isEmpty { Label("templateAuthor.linkedMedia", systemImage: "photo") } }
                    }
                }
            }
            if let raw = draft.preferenceJson { Section("templateAuthor.preference.title") { TemplatePreferencePreviewView(raw: raw) } }
            if draft.rewardEnabled { Section("templateAuthor.reward") {
                if let medal = draft.medalName, !medal.isEmpty { LabeledContent("templateAuthor.field.medalName", value: medal) }
                if let feedback = draft.feedbackText, !feedback.isEmpty { Text(verbatim: feedback) }
                if let style = draft.medalStyle, !(draft.medalName ?? "").isEmpty || !(draft.medalImg ?? "").isEmpty {
                    LabeledContent("templateAuthor.field.medalStyle", value: style)
                }
            } }
        }.listStyle(.insetGrouped).cyGroupedSurface()
            .navigationTitle(ConfigR4Text.text("config.preview.title")).navigationBarTitleDisplayMode(.inline)
            .cyDomainScreen(.topicEditor)
            .toolbar { ToolbarItem(placement: .cancellationAction) { if let configuredRehearsals {
                TemplateConfiguredRehearsalCloseButton(controller: configuredRehearsals)
            } else { Button("templateAuthor.close") { dismiss() } } } }
    }
}

// These actions affect only the current unsaved basic fields.
enum TemplateBasicClearField {
    case title, description, cover, questionImage, questionAudio
    case optionMedia(TemplateChoiceOptionMedia.Letter)
    var rawValue: String {
        switch self {
        case .title: return "title"
        case .description: return "description"
        case .cover: return "cover"
        case .questionImage: return "questionImage"
        case .questionAudio: return "questionAudio"
        case .optionMedia(let letter): return "optionMedia." + letter.rawValue
        }
    }
    func value(in draft: TemplateAuthoringDraft) -> String {
        switch self {
        case .title: return draft.title
        case .description: return draft.description
        case .cover: return draft.imgUrl ?? ""
        case .questionImage, .questionAudio:
            guard draft.finishEnabled, [.text, .choice].contains(draft.validationMethod) else { return "" }
            switch self { case .questionImage: return draft.questionImg ?? ""; default: return draft.questionAudio ?? "" }
        case .optionMedia(let letter):
            let media = draft.choiceOptionMedia
            guard draft.finishEnabled, draft.validationMethod == .choice, media.isSupported,
                  TemplateChoiceOptionRows(draft: draft).letters.contains(letter),
                  Self.hasUniqueMediaKeys(draft.questionOptionMediaJson) else { return "" }
            return [media.text(letter, .image), media.text(letter, .audio)].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        }
    }
    func label(_ locale: Locale) -> String {
        switch self {
        case .title: return appLocalized("templateBasicClear.title", locale: locale)
        case .description: return appLocalized("templateBasicClear.description", locale: locale)
        case .cover: return appLocalized("templateBasicClear.cover", locale: locale)
        case .questionImage: return appLocalized("templateBasicClear.questionImage", locale: locale)
        case .questionAudio: return appLocalized("templateBasicClear.questionAudio", locale: locale)
        case .optionMedia(let letter): return appLocalized("templateBasicClear.optionMedia \(letter.rawValue)", locale: locale)
        }
    }
    // The existing projection validates the schema. This narrow lexical guard also
    // rejects duplicate or escaped-alias keys before an explicit edit rewrites JSON.
    private static func hasUniqueMediaKeys(_ raw: String?) -> Bool {
        guard let raw, !raw.isEmpty else { return true }
        let bytes = Array(raw.utf8)
        var index = 0, objects: [Set<Data>] = []
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 123 { objects.append([]); index += 1 }
            else if byte == 125 {
                guard !objects.isEmpty else { return false }; objects.removeLast(); index += 1
            } else if byte == 34 {
                let start = index; index += 1
                var closed = false
                while index < bytes.count {
                    let value = bytes[index]; index += 1
                    if value == 92 { guard index < bytes.count else { return false }; index += 1 }
                    else if value == 34 { closed = true; break }
                }
                guard closed else { return false }
                var next = index
                while next < bytes.count && [9, 10, 13, 32].contains(bytes[next]) { next += 1 }
                if next < bytes.count && bytes[next] == 58 {
                    guard !objects.isEmpty,
                          let key = try? JSONDecoder().decode(String.self, from: Data(bytes[start..<index])),
                          objects[objects.count - 1].insert(Data(key.utf8)).inserted else { return false }
                }
            } else { index += 1 }
        }
        return objects.isEmpty
    }
}

@MainActor final class TemplateBasicFieldClearController: ObservableObject {
    private let model: TemplateAuthoringModel
    let field: TemplateBasicClearField
    private var observation: AnyCancellable?
    private var visible = false, active = false
    @Published private(set) var generation = UUID()
    init(model: TemplateAuthoringModel, field: TemplateBasicClearField) {
        self.model = model; self.field = field
        observation = model.objectWillChange.sink { [weak self] _ in self?.generation = UUID() }
    }
    var canClear: Bool {
        visible && active && model.canEdit && !model.busy && model.review == nil &&
        model.coordinator.review == nil && !field.value(in: model.draft).isEmpty
    }
    func appear(sceneIsActive: Bool) {
        if !visible || active != sceneIsActive { generation = UUID() }
        visible = true; active = sceneIsActive
    }
    func disappear() { visible = false; active = false; generation = UUID() }
    func sceneChanged(isActive: Bool) {
        let next = visible && isActive
        if next != active { generation = UUID() }
        active = next
    }
    func clearAction() -> () -> Void {
        let stamp = generation, session = model.coordinator.session, identity = model.coordinator.identity
        let metadata = model.metadataGeneration, media = model.mediaReviewGeneration
        let source = TemplateSamplePreview.snapshot(model.draft)
        return { [weak self] in
            guard let self, self.canClear, self.generation == stamp, session != nil,
                  self.model.coordinator.session == session, self.model.coordinator.identity == identity,
                  self.model.metadataGeneration == metadata, self.model.mediaReviewGeneration == media,
                  source != nil, source == TemplateSamplePreview.snapshot(self.model.draft) else { return }
            switch self.field {
            case .title: self.model.draft.title = ""
            case .description: self.model.draft.description = ""
            case .cover: self.model.draft.imgUrl = nil
            case .questionImage:
                self.model.mediaReferencesWillChange()
                self.model.draft.questionImg = nil
            case .questionAudio:
                self.model.mediaReferencesWillChange()
                self.model.draft.questionAudio = nil
            case .optionMedia(let letter):
                do {
                    var next = self.model.draft
                    try next.setChoiceOptionMedia(letter, .image, to: "")
                    try next.setChoiceOptionMedia(letter, .audio, to: "")
                    self.model.mediaReferencesWillChange()
                    self.model.draft = next
                } catch { return }
            }
            self.model.changed()
        }
    }
}

/// Trailing clear control. Next to a field it is the native ✕; on its own row it reads as a labelled action.
/// It stays mounted (lifecycle drives the controller) and is invisible while there is nothing to clear.
@MainActor struct TemplateBasicFieldClearButton: View {
    @StateObject private var controller: TemplateBasicFieldClearController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    private let iconOnly: Bool
    init(model: TemplateAuthoringModel, field: TemplateBasicClearField, iconOnly: Bool = true) {
        _controller = StateObject(wrappedValue: .init(model: model, field: field)); self.iconOnly = iconOnly
    }
    var body: some View {
        Button(action: controller.clearAction()) {
            if iconOnly {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).imageScale(.large)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            } else {
                Label { Text(verbatim: controller.field.label(locale)) } icon: { Image(systemName: "xmark.circle") }
            }
        }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(verbatim: controller.field.label(locale)))
            .opacity(iconOnly && !controller.canClear ? 0 : 1)
            .accessibilityHidden(iconOnly && !controller.canClear)
            .disabled(!controller.canClear)
            .accessibilityIdentifier("templateBasicClear." + controller.field.rawValue)
            .onAppear { controller.appear(sceneIsActive: scenePhase == .active) }
            .onDisappear { controller.disappear() }
            .onChange(of: scenePhase) { _, phase in controller.sceneChanged(isActive: phase == .active) }
    }
}

/// Round 4 image parity: MP `utils/template-display.js` `gameTemplateCover`. The seven built-in interaction games
/// default to their `/images/interaction-templates/*.svg` art, matched by the original title first and then by the
/// first enabled mechanic section (so a renamed adoption keeps its art). Anything else has no default cover.
enum TemplateInteractionDefaultCover {
    private static let byTitle: [String: String] = [
        "闭眼味觉师": "blindTaste", "沉默点单": "silentOrder", "便利店调酒师": "diyName", "治愈音乐角": "musicCorner",
        "午夜电台": "timeWindow", "低碳行动": "steps", "今日城市签": "dailySign"
    ]
    private static let sectionOrder = ["blindTaste", "silentOrder", "diyName", "musicCorner", "timeWindow", "steps", "dailySign"]

    static func image(title: String, advanced: TemplateAdvancedDraft) -> Image? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let section = byTitle[trimmed] ?? sectionOrder.first { advanced.enabled($0) }
        switch section {
        case "blindTaste": return MPAsset.BannerCover.blindTaste
        case "silentOrder": return MPAsset.BannerCover.silentOrder
        case "diyName": return MPAsset.BannerCover.diyDrink
        case "musicCorner": return MPAsset.BannerCover.musicCorner
        case "timeWindow": return MPAsset.BannerCover.midnightRadio
        case "steps": return MPAsset.BannerCover.lowCarbon
        case "dailySign": return MPAsset.BannerCover.dailyCitySign
        default: return nil
        }
    }
}
