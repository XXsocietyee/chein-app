import SwiftUI

@MainActor final class TemplateChoiceOptionRowsEditor: ObservableObject {
    typealias Letter = TemplateChoiceOptionMedia.Letter
    let model: TemplateAuthoringModel
    private var session: TemplateAuthoringSession?
    private var identity: TemplateAuthoringIdentity?
    private var mediaGeneration: UUID?
    private var methodGeneration: UUID?
    private var generation = 0
    private var active = false
    @Published private(set) var revision = 0
    init(model: TemplateAuthoringModel) { self.model = model; reload() }
    var canRead: Bool {
        active && model.canReadStoryDraft && session == model.coordinator.session && identity == model.coordinator.identity &&
            mediaGeneration == model.mediaReviewGeneration && methodGeneration == model.legacyHintGeneration &&
            model.draft.finishEnabled && model.draft.validationMethod == .choice
    }
    var canEdit: Bool { canRead && model.canEdit }
    var rows: TemplateChoiceOptionRows { .init(draft: model.draft) }
    var letters: [Letter] { canRead ? rows.letters : [] }
    func reload() {
        generation += 1; active = true
        session = model.coordinator.session; identity = model.coordinator.identity
        mediaGeneration = model.mediaReviewGeneration; methodGeneration = model.legacyHintGeneration
        revision += 1
    }
    func retire() { generation += 1; active = false; revision += 1 }
    func text(_ letter: Letter) -> Binding<String> {
        let stamp = generation
        return .init(get: {
            guard self.generation == stamp, self.canRead, self.letters.contains(letter) else { return "" }
            return self.model.draft[keyPath: TemplateChoiceOptionRows.path(letter)] ?? ""
        }, set: { value in
            guard self.generation == stamp, self.canEdit, self.letters.contains(letter) else { return }
            self.model.draft[keyPath: TemplateChoiceOptionRows.path(letter)] = value
            self.model.changed()
        })
    }
    func attachment(_ letter: Letter, _ kind: TemplateChoiceOptionMedia.Kind) -> Binding<String> {
        let stamp = generation, original = model.optionMedia(letter, kind)
        return .init(get: {
            guard self.generation == stamp, self.canRead, self.letters.contains(letter) else { return "" }
            return original.wrappedValue
        }, set: { value in
            guard self.generation == stamp, self.canEdit, self.letters.contains(letter) else { return }
            original.wrappedValue = value
        })
    }
    func answer() -> Binding<String> {
        let stamp = generation
        return .init(get: { self.generation == stamp && self.canRead ? self.model.draft.correctAnswer ?? "" : "" }, set: { value in
            guard self.generation == stamp, self.canEdit,
                  value.isEmpty || self.letters.contains(where: { $0.rawValue == value }) else { return }
            self.model.draft.correctAnswer = value.isEmpty ? nil : value
            self.model.changed()
        })
    }
    func action(_ edit: TemplateChoiceOptionRows.Edit) -> () -> Void {
        let stamp = generation, mutation = model.metadataGeneration, original = rows
        return { [weak self] in
            guard let self, self.generation == stamp, self.canEdit, self.model.metadataGeneration == mutation,
                  let next = original.applying(edit, to: self.model.draft) else { return }
            // Retire old row callbacks and pending media review before letters can move.
            self.generation += 1
            self.model.mediaReferencesWillChange()
            self.model.draft = next
            self.model.changed(); self.revision += 1
        }
    }
}

@MainActor struct TemplateChoiceOptionRowsFields: View {
    typealias Letter = TemplateChoiceOptionMedia.Letter
    @ObservedObject var model: TemplateAuthoringModel
    @StateObject private var editor: TemplateChoiceOptionRowsEditor
    @State private var expandedLetter: Letter?
    @FocusState private var focused: Letter?
    @Environment(\.configUndoCenter) private var undoCenter
    @Environment(\.locale) private var locale
    init(model: TemplateAuthoringModel) {
        self.model = model; _editor = StateObject(wrappedValue: .init(model: model))
    }
    /// Native r2: rows of the parent Form section (system reorder via `onMove`, no drawn field boxes or drag handle).
    var body: some View {
        Group {
            if !model.draft.choiceOptionMedia.isSupported {
                Text("templateAuthor.optionMedia.unsupported").font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("templateAuthor.optionMedia.unsupported")
            }
            if !editor.rows.supportsReordering {
                Text("templateChoiceRows.reorderUnavailable").font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("templateChoiceRows.reorderUnavailable")
            }
            if let issue = model.optionMediaIssue {
                Text(LocalizedStringKey(issue)).font(.footnote).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("templateAuthor.optionMedia.limit")
            }
            // Screens r4 · Figma 238:16749 (CF-46 / CF-60): one row per option, the correct-answer circle in
            // front, the text, attachments and "⋯". Only the option being edited expands (its attachments).
            // Delete happens at once and can be undone.
            ForEach(Array(editor.letters.enumerated()), id: \.element) { index, letter in
                optionRow(letter, index: index)
            }
            .onMove { source, destination in
                guard let from = source.first else { return }
                editor.action(.move(from: from, to: destination))()
            }
            .moveDisabled(!(editor.canEdit && editor.rows.supportsReordering))
            Button { add() } label: {
                HStack {
                    Label("templateChoiceRows.add", systemImage: "plus.circle.fill")
                    Spacer()
                    Text(verbatim: "\(editor.letters.count)/4").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .disabled(!editor.rows.canAdd)
            .accessibilityIdentifier("templateChoiceRows.add")
            if let raw = model.draft.correctAnswer, !raw.isEmpty, !editor.letters.contains(where: { $0.rawValue == raw }) {
            Picker("templateAuthor.field.correctAnswer", selection: editor.answer()) {
                Text("templateAuthor.choose").tag("")
                ForEach(editor.letters) { letter in Text(verbatim: letter.rawValue).tag(letter.rawValue) }
                if let raw = model.draft.correctAnswer, !raw.isEmpty, !editor.letters.contains(where: { $0.rawValue == raw }) {
                    Text(verbatim: raw).tag(raw)
                }
            }.accessibilityIdentifier("templateChoiceRows.correctAnswer")
            }
        }.disabled(!editor.canEdit)
            .onAppear { editor.reload() }
            .onDisappear { editor.retire() }
            .onChange(of: model.mediaReviewGeneration) { _, _ in editor.reload() }
            .onChange(of: model.legacyHintGeneration) { _, _ in editor.reload() }
    }

    @ViewBuilder private func optionRow(_ letter: Letter, index: Int) -> some View {
        let answer = editor.answer()
        let isCorrect = answer.wrappedValue == letter.rawValue
        let count = editor.letters.count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { answer.wrappedValue = isCorrect ? "" : letter.rawValue } label: {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(isCorrect ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(Text("editorKit.answer.correctLetter \(letter.rawValue)", tableName: "EditorKit"))
                .accessibilityValue(EditorKitText.text(isCorrect ? "editorKit.answer.selected" : "editorKit.answer.notSelected"))
                .accessibilityAddTraits(isCorrect ? [.isSelected] : [])
                .accessibilityIdentifier("templateChoiceRows.correctAnswer." + letter.rawValue)
                .sensoryFeedback(.selection, trigger: isCorrect)
                TextField(text: editor.text(letter), prompt: Text("config.option.placeholder \(letter.rawValue)", tableName: ConfigR4Text.table)) {
                    Text("config.option.name \(letter.rawValue)", tableName: ConfigR4Text.table)
                }
                .focused($focused, equals: letter)
                .submitLabel(index == count - 1 && editor.rows.canAdd ? .return : .next)
                .onSubmit { submitted(letter, index: index) }
                .accessibilityIdentifier("templateChoiceRows.text." + letter.rawValue)
                Button { expandedLetter = expandedLetter == letter ? nil : letter } label: {
                    Image(systemName: expandedLetter == letter ? "chevron.up" : "paperclip")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("templateAuthor.optionMedia.title"))
                .accessibilityIdentifier("templateChoiceRows.attachments." + letter.rawValue)
                EditorRowActionsMenu(
                    index: index, count: count, actions: editor.rows.canRemove ? [.moveUp, .moveDown, .delete] : [.moveUp, .moveDown],
                    deleteTitle: Text("templateChoiceRows.removeLetter \(letter.rawValue)"),
                    menuID: "templateChoiceRows.menu." + letter.rawValue,
                    deleteID: "templateChoiceRows.remove." + letter.rawValue
                ) { act($0, letter: letter, index: index) }
                .disabled(!editor.rows.supportsReordering)
            }
            .buttonStyle(.borderless)
            if expandedLetter == letter {
                ForEach(TemplateChoiceOptionMedia.Kind.allCases) { kind in
                    TextField(LocalizedStringKey(kind.labelKey), text: editor.attachment(letter, kind))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .disabled(!model.draft.choiceOptionMedia.isSupported)
                        .accessibilityIdentifier("templateAuthor.optionMedia." + letter.rawValue + "." + kind.rawValue)
                }
                TemplateBasicFieldClearButton(model: model, field: .optionMedia(letter), iconOnly: false)
                    .buttonStyle(.borderless)
            }
        }
        .editorReorderAccessibility(index: index, count: count) { act($0, letter: letter, index: index) }
    }

    private func act(_ action: EditorRowAction, letter: Letter, index: Int) {
        switch action {
        case .moveUp, .moveDown:
            guard let destination = EditorReorder.destination(for: action, index: index, count: editor.letters.count) else { return }
            withAnimation {
                editor.action(.move(from: index, to: destination))()
            }
        case .delete:
            guard editor.rows.canRemove else { return }
            remove(letter)
        case .duplicate:
            break
        }
    }

    /// C2's one delete rule: the option goes at once, 已删除「选项 B」 撤销 stays 5 s (and shake / ⌘Z).
    /// Undo writes back only the choice fields, so edits made elsewhere in the meantime are kept.
    private func remove(_ letter: Letter) {
        let previous = model.draft
        if expandedLetter == letter { expandedLetter = nil }
        withAnimation { editor.action(.remove(letter))() }
        guard model.draft != previous, let undoCenter else { return }
        let name = ConfigR4Text.string("config.option.short", locale: locale) + " " + letter.rawValue
        let owner = model, rows = editor
        undoCenter.recordDelete(
            message: String(format: OpsR3Text.string("editor.deleted.item", locale: locale), name),
            actionName: ConfigR4Text.string("config.option.undoDelete", locale: locale)
        ) {
            guard owner.canEdit else { return false }
            owner.mediaReferencesWillChange()
            var restored = owner.draft
            restored.questionA = previous.questionA; restored.questionB = previous.questionB
            restored.questionC = previous.questionC; restored.questionD = previous.questionD
            restored.correctAnswer = previous.correctAnswer; restored.questionOptionMediaJson = previous.questionOptionMediaJson
            owner.draft = restored; owner.changed(); rows.reload()
            return true
        }
    }

    private func add() {
        guard editor.rows.canAdd else { return }
        let next = editor.letters.count
        withAnimation { editor.action(.add)() }
        if Letter.allCases.indices.contains(next) { focused = Letter.allCases[next] }
    }

    /// CF-74: Return moves to the next option; on the last one it adds a new option (as in Reminders).
    private func submitted(_ letter: Letter, index: Int) {
        let letters = editor.letters
        if index + 1 < letters.count { focused = letters[index + 1] }
        else if editor.rows.canAdd { add() }
        else { focused = nil }
    }
}
