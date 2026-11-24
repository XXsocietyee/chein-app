import SwiftUI

@MainActor struct ProjectChapterAudioAuthorView: View {
    let original: ProjectChapterAudioPresentation.Presentation
    let close: () -> Void
    @StateObject private var model: ProjectStoryAudioAuthorModel
    init(original: ProjectChapterAudioPresentation.Presentation, picker: (any ProjectStoryAudioSelecting)? = nil,
         apply: @escaping (ProjectChapterAudioPresentation.Presentation) -> Void, close: @escaping () -> Void) {
        self.original = original; self.close = close
        _model = StateObject(wrappedValue: .init(flow: original.flow, picker: picker,
            permitsPicker: { original.opening.source.permitsPicker(session: original.opening.lease.session) }, apply: { apply(original) }))
    }
    var body: some View {
        let flow = model.flow, review = flow.review
        NavigationStack {
            Form {
                Section {
                    Text(verbatim: original.opening.chapterName)
                    Text("projectChapterAudio.selectionScope", tableName: "ProjectChapterAudio")
                    Text(verbatim: original.opening.savedReference).textSelection(.enabled)
                    CYPillButton("projectStoryAudio.choose", style: .secondary) { Task { await model.choose() } }
                        .listRowBackground(Color.clear)
                        .disabled(!flow.canPick).accessibilityIdentifier("projectChapterAudio.choose")
                    if !flow.matchesCapturedDraft && !flow.alreadyApplied { Text("projectChapterAudio.changed", tableName: "ProjectChapterAudio") }
                    if model.selectionFailed { Text("projectStoryAudio.selectionFailed") }
                }
                if let review {
                    Section {
                        Text(verbatim: review.audio.filename)
                        LabeledContent("projectStoryAudio.bytes", value: String(review.audio.bytes.count))
                        Text("projectStoryAudio.inspection")
                        CYPillButton("projectStoryAudio.upload") { model.upload(review) }.listRowBackground(Color.clear).disabled(!flow.canUpload(review))
                            .accessibilityIdentifier("projectChapterAudio.upload")
                        CYPillButton("projectStoryAudio.cancelLocal", style: .tertiary) { model.cancel(review) }.listRowBackground(Color.clear).disabled(flow.busy)
                    }
                }
                if flow.hasUnstoredReceipt {
                    Section {
                        Text("projectStoryAudio.unstored")
                        CYPillButton("projectStoryAudio.saveReceipt", style: .secondary) { model.persistReceipt() }.listRowBackground(Color.clear).disabled(!flow.canPersistReceipt)
                    }
                }
                if let receipt = flow.receipt {
                    Section {
                        Text(verbatim: receipt.filename)
                        Text(verbatim: receipt.reference).textSelection(.enabled)
                        Text("projectStoryAudio.referenceScope")
                        if !flow.referenceFitsTarget { Text("projectChapterAudio.receiptTooLong", tableName: "ProjectChapterAudio") }
                        CYPillButton("projectChapterAudio.apply", tableName: "ProjectChapterAudio") { model.apply() }
                            .listRowBackground(Color.clear)
                            .disabled(!flow.canApply).accessibilityIdentifier("projectChapterAudio.apply")
                    }
                }
                if flow.unresolvedUploadCount > 0 && !flow.hasUnstoredReceipt { Text("projectStoryAudio.unknown") }
                if flow.state == .localSaveFailed { Text("projectStoryAudio.localFailed") }
                if flow.state == .failed { Text("projectStoryAudio.failed") }
                if flow.state == .unauthorized { Text("projectStoryAudio.unauthorized") }
                if flow.state == .uploading { CYSkeleton() }
            }
            .navigationTitle(Text("projectChapterAudio.title", tableName: "ProjectChapterAudio")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("projectStoryAudio.close") { model.close(); close() }
            } }
        }
        .background(RetainedImagePresenterHost(host: model.pickerHost).frame(width: 0, height: 0))
        .onAppear { model.load() }
        .onDisappear { model.close(); close() }
    }
}
