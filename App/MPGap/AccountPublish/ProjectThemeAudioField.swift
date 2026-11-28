import SwiftUI

/// MP `publish/fabu/topic-detail-sheet.wxml:70-77` (card 主题配乐 after the covers, before 画面风格) +
/// `theme-media.js` `uploadThemeAudio` / `clearThemeAudio`. One captured upload at a time, through the same
/// story-audio upload source and journal as chapter narration (separate journal key, see `themeMusicJournal()`).
@MainActor final class ProjectThemeAudioPresentation: ObservableObject {
    struct Opening {
        let controllerID: UUID
        let generation: Int
        let lease: ProjectEditStarterController.Lease
        let revision: Int
        let bytes: Data
        let target: ProjectStoryAudioTarget
        let source: any ProjectStoryAudioUploading
        let journal: ProjectStoryAudioJournal
        let savedReference: String
    }
    struct Presentation: Identifiable {
        let opening: Opening
        let flow: ProjectStoryAudioFlow
        var id: UUID { flow.id }
    }
    let editor: ProjectEditModel
    @Published private(set) var presentation: Presentation?
    private let controllerID = UUID()
    private var generation = 0
    private var applied: (targetID: UUID, revision: Int, bytes: Data)?
    init(editor: ProjectEditModel) { self.editor = editor }
    func capture() -> Opening? {
        guard presentation == nil, let lease = editor.captureStarterLease(),
              let source = editor.coordinator.storyAudioSource, source.isCurrent(session: lease.session),
              let parentJournal = editor.coordinator.storyAudioJournal,
              let bytes = ProjectEditPendingMaterials.exactData(editor.draft),
              let target = try? ProjectStoryAudioTarget(themeMusicIn: editor.draft, identity: lease.identity,
                                                        session: lease.session) else { return nil }
        return .init(controllerID: controllerID, generation: generation, lease: lease, revision: editor.draftMutationRevision,
                     bytes: bytes, target: target, source: source, journal: parentJournal.themeMusicJournal(),
                     savedReference: ProjectThemeAudio.reference(in: editor.draft) ?? "")
    }
    func isCurrent(_ opening: Opening) -> Bool {
        guard opening.controllerID == controllerID, opening.generation == generation, editor.isCurrentStarterLease(opening.lease),
              opening.target.kind == .themeMusic,
              let source = editor.coordinator.storyAudioSource, ObjectIdentifier(source) == ObjectIdentifier(opening.source),
              editor.coordinator.storyAudioJournal?.themeMusicJournal() === opening.journal,
              source.isCurrent(session: opening.lease.session) else { return false }
        let expected = applied?.targetID == opening.target.id ? applied : nil
        return editor.draftMutationRevision == (expected?.revision ?? opening.revision) &&
            ProjectEditPendingMaterials.exactData(editor.draft) == (expected?.bytes ?? opening.bytes)
    }
    func open(_ opening: Opening) {
        guard presentation == nil, isCurrent(opening),
              opening.target.matches(editor.draft, identity: opening.lease.identity, session: opening.lease.session) else { return }
        applied = nil
        let flow = ProjectStoryAudioFlow(target: opening.target, session: opening.lease.session, identity: opening.lease.identity,
            source: opening.source, journal: opening.journal, currentDraft: { [weak self] in self?.editor.draft },
            parentCurrent: { [weak self] in self?.isCurrent(opening) == true })
        presentation = .init(opening: opening, flow: flow)
    }
    func apply(_ original: Presentation) {
        guard presentation?.id == original.id, isCurrent(original.opening), let next = original.flow.draftForApply() else { return }
        guard editor.persistLocalChange(next, lease: original.opening.lease) else { original.flow.localSaveFailed(); return }
        guard presentation?.id == original.id, editor.isCurrentStarterLease(original.opening.lease),
              let bytes = ProjectEditPendingMaterials.exactData(next), ProjectEditPendingMaterials.exactData(editor.draft) == bytes else {
            close(original); return
        }
        applied = (original.opening.target.id, editor.draftMutationRevision, bytes)
        original.flow.didSaveAppliedDraft()
        if original.flow.state == .applied { close(original) }
    }
    func close(_ original: Presentation) {
        original.flow.close()
        guard presentation?.id == original.id else { return }
        presentation = nil; applied = nil; generation += 1
    }
    func retire() { if let presentation { close(presentation) } else { generation += 1; applied = nil } }
    func binding(_ original: Presentation?) -> Binding<Presentation?> {
        .init(get: { guard let original, self.presentation?.id == original.id, self.isCurrent(original.opening) else { return nil }; return original },
              set: { if $0 == nil, let original { self.close(original) } })
    }
}

/// The 主题配乐 row: title with the play icon, then 移除 (only with audio) and 上传 / 更换, as in the MP card.
/// Hidden when there is no audio and this account or topic cannot upload (no "not connected" captions).
@MainActor struct ProjectThemeAudioField: View {
    @ObservedObject var model: ProjectEditModel
    @StateObject private var uploads: ProjectThemeAudioPresentation
    @State private var cleared = 0
    init(model: ProjectEditModel) {
        self.model = model
        _uploads = StateObject(wrappedValue: .init(editor: model))
    }
    var body: some View {
        let opening = uploads.capture(), upload = uploads.presentation
        let hasAudio = ProjectThemeAudio.hasAudio(in: model.draft)
        let unsupported = ProjectThemeAudio.isUnsupported(in: model.draft)
        if hasAudio || unsupported || opening != nil || upload != nil {
            Section {
                rows(opening: opening, hasAudio: hasAudio, unsupported: unsupported)
            }
            .id("project-issue-anchor-themeAudio")
            .sensoryFeedback(.selection, trigger: cleared)
            .cySheet(item: uploads.binding(upload)) { original in
                ProjectThemeAudioUploadView(original: original, picker: model.storyAudioPicker?(),
                                            apply: { uploads.apply($0) }, close: { uploads.close(original) })
                    .cyDomainSheet(detents: [.half, .full])
                    .themeDomain(.topicEditor)
            }
            .onChange(of: model.editorIncarnation) { _, _ in uploads.retire() }
            .onDisappear { uploads.retire() }
        }
    }
    @ViewBuilder private func rows(opening: ProjectThemeAudioPresentation.Opening?, hasAudio: Bool, unsupported: Bool) -> some View {
        HStack(spacing: CYSpacing.xs) {
            Label {
                Text("mpPublish.themeAudio.title")
            } icon: {
                Image(systemName: "play.circle").foregroundStyle(.tint)
            }
            Spacer(minLength: CYSpacing.xs)
            if hasAudio && !unsupported {
                Button(role: .destructive) { clear() } label: { Text("mpPublish.themeAudio.remove") }
                    .buttonStyle(.bordered)
                    .disabled(!model.fullEdit || uploads.presentation != nil)
                    .accessibilityLabel(Text("mpPublish.themeAudio.removeLabel"))
                    .accessibilityIdentifier("projectThemeAudio.remove")
            }
            if opening != nil {
                Button { if let opening { uploads.open(opening) } } label: {
                    Label(hasAudio ? LocalizedStringKey("mpPublish.themeAudio.replace") : LocalizedStringKey("mpPublish.themeAudio.upload"), systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text("mpPublish.themeAudio.uploadLabel"))
                .accessibilityIdentifier("projectThemeAudio.upload")
            }
        }
        if hasAudio, let reference = ProjectThemeAudio.reference(in: model.draft) {
            // Verbatim text only: no Link, fetch or implicit playback of the saved reference.
            Text(verbatim: reference)
                .font(.footnote).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled)
                .accessibilityIdentifier("projectThemeAudio.reference")
        }
        if unsupported {
            Text("mpPublish.themeAudio.unsupported").font(.footnote).foregroundStyle(.secondary)
        }
    }
    /// MP `clearThemeAudio`: no confirmation; `audioUrl` '' and `audioDuration` 0.
    private func clear() {
        guard model.fullEdit, uploads.presentation == nil,
              let next = try? ProjectThemeAudio.clearing(in: model.draft) else { return }
        uploads.retire()
        model.draft = next
        cleared += 1
    }
}

/// Choose → upload → apply, the same three explicit steps as chapter narration (`ProjectChapterAudioAuthorView`).
@MainActor struct ProjectThemeAudioUploadView: View {
    let original: ProjectThemeAudioPresentation.Presentation
    let close: () -> Void
    @StateObject private var model: ProjectStoryAudioAuthorModel
    init(original: ProjectThemeAudioPresentation.Presentation, picker: (any ProjectStoryAudioSelecting)? = nil,
         apply: @escaping (ProjectThemeAudioPresentation.Presentation) -> Void, close: @escaping () -> Void) {
        self.original = original; self.close = close
        _model = StateObject(wrappedValue: .init(flow: original.flow, picker: picker,
            permitsPicker: { original.opening.source.permitsPicker(session: original.opening.lease.session) }, apply: { apply(original) }))
    }
    var body: some View {
        let flow = model.flow
        NavigationStack {
            Form {
                chooseSection(flow)
                if let review = flow.review { reviewSection(flow, review) }
                if flow.hasUnstoredReceipt {
                    Section {
                        Text("projectStoryAudio.unstored")
                        Button { model.persistReceipt() } label: { Text("projectStoryAudio.saveReceipt") }
                            .buttonStyle(.bordered).disabled(!flow.canPersistReceipt)
                    }
                }
                if let receipt = flow.receipt { receiptSection(flow, receipt) }
                statusSection(flow)
            }
            .navigationTitle(Text("mpPublish.themeAudio.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("projectStoryAudio.close") { model.close(); close() }
                    .accessibilityIdentifier("projectThemeAudio.close")
            } }
        }
        .background(RetainedImagePresenterHost(host: model.pickerHost).frame(width: 0, height: 0))
        .onAppear { model.load() }
        .onDisappear { model.close(); close() }
    }
    private func chooseSection(_ flow: ProjectStoryAudioFlow) -> some View {
        Section {
            if !original.opening.savedReference.isEmpty {
                Text(verbatim: original.opening.savedReference)
                    .font(.footnote).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
            }
            Button { Task { await model.choose() } } label: { Text("projectStoryAudio.choose") }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(!flow.canPick).accessibilityIdentifier("projectThemeAudio.choose")
            if model.selectionFailed { Text("projectStoryAudio.selectionFailed").font(.footnote).foregroundStyle(.secondary) }
        } footer: {
            Text("mpPublish.themeAudio.scope")
        }
    }
    private func reviewSection(_ flow: ProjectStoryAudioFlow, _ review: ProjectStoryAudioFlow.Review) -> some View {
        Section {
            Text(verbatim: review.audio.filename)
            LabeledContent("projectStoryAudio.bytes",
                           value: Int64(review.audio.bytes.count).formatted(.byteCount(style: .file)))
            Button { model.upload(review) } label: { Text("projectStoryAudio.upload") }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!flow.canUpload(review)).accessibilityIdentifier("projectThemeAudio.uploadFile")
            Button(role: .cancel) { model.cancel(review) } label: { Text("projectStoryAudio.cancelLocal") }
                .buttonStyle(.borderless).disabled(flow.busy)
        }
    }
    private func receiptSection(_ flow: ProjectStoryAudioFlow, _ receipt: ProjectStoryUploadedAudio) -> some View {
        Section {
            Text(verbatim: receipt.filename)
            if !flow.referenceFitsTarget { Text("mpPublish.themeAudio.tooLong").font(.footnote).foregroundStyle(.secondary) }
            Button { model.apply() } label: { Text("mpPublish.themeAudio.apply") }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!flow.canApply).accessibilityIdentifier("projectThemeAudio.apply")
        }
    }
    @ViewBuilder private func statusSection(_ flow: ProjectStoryAudioFlow) -> some View {
        if flow.unresolvedUploadCount > 0 && !flow.hasUnstoredReceipt { Text("projectStoryAudio.unknown") }
        if flow.state == .localSaveFailed { Text("projectStoryAudio.localFailed") }
        if flow.state == .failed { Text("projectStoryAudio.failed") }
        if flow.state == .unauthorized { Text("projectStoryAudio.unauthorized") }
        if flow.state == .uploading { CYLoadingState(messageIdentifier: "projectStoryAudio.uploading") }
    }
}
