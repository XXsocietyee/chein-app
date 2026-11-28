import SwiftUI
import Combine

@MainActor final class TemplatePictureChoiceController: ObservableObject {
    private let model: TemplateAuthoringModel
    private let session: TemplateAuthoringSession?
    private let identity: TemplateAuthoringIdentity
    private var mediaGeneration = UUID(), actionGeneration = UUID(), textGeneration = UUID()
    private var writing = false
    private var publicationObservation: AnyCancellable?, draftObservation: AnyCancellable?
    @Published private var active = false
    @Published private var choices: TemplatePictureChoices
    @Published private(set) var needsReload = false
    init(model: TemplateAuthoringModel) {
        self.model = model; session = model.coordinator.session; identity = model.coordinator.identity
        choices = .init(model.draft.advanced); reload()
        publicationObservation = model.objectWillChange.sink { [weak self] _ in
            guard let self else { return }; self.actionGeneration = UUID()
            if !self.writing && (!self.canReload || self.mediaGeneration != self.model.mediaReviewGeneration) { self.invalidate() }
        }
        // Parent onChange(draft) refreshes review metadata after our own write. Keep typing
        // through that refresh; only an actual external draft emission requires reload.
        draftObservation = model.$draft.dropFirst().sink { [weak self] _ in
            guard let self, !self.writing else { return }; self.invalidate()
        }
    }
    var canReload: Bool { model.canReadStoryDraft && session != nil && model.coordinator.session == session && model.coordinator.identity == identity }
    private var hasLease: Bool { active && canReload && mediaGeneration == model.mediaReviewGeneration && choices.isCurrent(model.draft.advanced) }
    var canEdit: Bool { hasLease && model.canEdit && choices.canEdit }
    var isSupported: Bool { hasLease && choices.isSupported }
    var canAdd: Bool { canEdit && choices.canAdd }
    var rows: [TemplatePictureChoices.Row] { hasLease ? choices.rows : [] }
    var correctCount: Int { hasLease ? choices.correctCount : 0 }
    var issues: [TemplateCreatorIssue] { hasLease ? model.draft.advanced.creatorIssues(.pricePair).filter { $0.path == "items" || $0.path.hasPrefix("items[") } : [] }
    func reload() {
        actionGeneration = UUID(); textGeneration = UUID()
        guard canReload else { active = false; needsReload = true; return }
        choices = .init(model.draft.advanced); mediaGeneration = model.mediaReviewGeneration; active = true; needsReload = false
    }
    func retire() { active = false; actionGeneration = UUID(); textGeneration = UUID() }
    private func invalidate() { retire(); needsReload = true }
    func addAction() -> () -> Void { action(.add) }
    func chooseAction(_ id: UUID) -> () -> Void { action(.choose(id)) }
    func removeAction(_ id: UUID) -> () -> Void { action(.remove(id)) }
    func moveAction(_ id: UUID, by offset: Int) -> () -> Void { action(.move(id, offset)) }
    private func action(_ edit: TemplatePictureChoices.Edit) -> () -> Void {
        let stamp = actionGeneration, metadata = model.metadataGeneration, captured = choices
        return { [weak self] in
            guard let self, self.canEdit, self.actionGeneration == stamp, self.model.metadataGeneration == metadata,
                  let update = captured.applying(edit, to: self.model.draft.advanced) else { return }
            self.textGeneration = UUID(); self.apply(update)
        }
    }
    func text(_ id: UUID, field: TemplatePictureChoices.TextField) -> Binding<String> {
        let stamp = textGeneration
        return .init(get: { [weak self] in
            guard let self, self.hasLease, self.textGeneration == stamp, let row = self.choices.rows.first(where: { $0.id == id }) else { return "" }
            return field == .name ? row.name : row.imageURL
        }, set: { [weak self] text in
            guard let self, self.canEdit, self.textGeneration == stamp, let update = self.choices.applying(.text(id, field, text), to: self.model.draft.advanced) else { return }
            self.apply(update)
        })
    }
    private func apply(_ update: TemplatePictureChoices.Update) {
        actionGeneration = UUID(); writing = true; defer { writing = false }
        choices = update.choices
        if !update.choices.isCurrent(model.draft.advanced) { model.draft.advanced = update.draft; model.changed() }
    }
}

@MainActor struct TemplatePictureChoiceEditor: View {
    @ObservedObject var model: TemplateAuthoringModel
    @StateObject private var editor: TemplatePictureChoiceController
    init(model: TemplateAuthoringModel) { self.model = model; _editor = StateObject(wrappedValue: .init(model: model)) }
    var body: some View {
        Form {
            Section {
                if editor.needsReload {
                    Text("templatePictures.changed").cyText(.meta)
                    Button("templatePictures.reload") { editor.reload() }.disabled(!editor.canReload).accessibilityIdentifier("creator.pictures.reload")
                } else if !editor.isSupported { Text("templatePictures.unsupported").cyText(.meta) }
                else { Text("templatePictures.correctCount \(editor.correctCount)").cyText(.meta) }
            }
            ForEach(Array(editor.rows.enumerated()), id: \.element.id) { index, row in
                Section {
                    Text("templatePictures.number \(index + 1)").cyText(.cardTitle)
                    TextField("creator.field.name", text: editor.text(row.id, field: .name), prompt: Text("creator.mp.pricePair.name.prompt"), axis: .vertical)
                        .accessibilityIdentifier("creator.pictures.name.\(index)")
                    Text(verbatim: "\(row.name.utf16.count)/32").cyText(.meta).foregroundStyle(.secondary).accessibilityLabel(Text("a11y.value.characters \(Int(row.name.utf16.count)) \(Int(32))"))
                    TextField("creator.field.imageUrl", text: editor.text(row.id, field: .imageURL), prompt: Text("creator.mp.pricePair.imageUrl.prompt"), axis: .vertical)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .accessibilityIdentifier("creator.pictures.imageURL.\(index)")
                    Button(action: editor.chooseAction(row.id)) {
                        Label(LocalizedStringKey(row.isCorrect ? "templatePictures.selected" : "templatePictures.select"), systemImage: row.isCorrect ? "largecircle.fill.circle" : "circle")
                    }.accessibilityAddTraits(row.isCorrect ? [.isSelected] : [])
                        .accessibilityIdentifier("creator.pictures.choose.\(index)")
                    HStack {
                        Button("templatePictures.up", systemImage: "arrow.up", action: editor.moveAction(row.id, by: -1)).disabled(index == 0)
                        Button("templatePictures.down", systemImage: "arrow.down", action: editor.moveAction(row.id, by: 1)).disabled(index == editor.rows.count - 1)
                        Spacer()
                        Button("creator.remove", role: .destructive, action: editor.removeAction(row.id)).accessibilityIdentifier("creator.pictures.remove.\(index)")
                    }
                }.disabled(!editor.canEdit)
            }
            Section {
                Button("templatePictures.add", systemImage: "plus", action: editor.addAction()).disabled(!editor.canAdd).accessibilityIdentifier("creator.pictures.add")
                Text("templatePictures.count \(editor.rows.count)").cyText(.meta)
            }
            if !editor.issues.isEmpty {
                Section("templateAuthor.validationTitle") {
                    ForEach(Array(editor.issues.enumerated()), id: \.offset) { _, issue in VStack(alignment: .leading) { Text(LocalizedStringKey(issue.labelKey)).foregroundStyle(CYColor.dangerText) } }
                }
            }
        }.navigationTitle("templatePictures.title").navigationBarTitleDisplayMode(.inline).onAppear { editor.reload() }.onDisappear { editor.retire() }
    }
}
