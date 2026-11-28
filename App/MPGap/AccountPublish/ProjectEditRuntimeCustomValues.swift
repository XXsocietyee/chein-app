import SwiftUI

// MARK: - MP pages/publish/fabu/topic-detail-sheet.wxml:130-135 (runtime-values card rows 自定义整数值)
// + fabu/index.wxml:1856-1877 (value editor sheet) · theme-runtime.js openValueEditor / saveValueEditor /
// removeValue / onValueEnabled / onValueLinkSwitch · theme-values.js attribute / links / references

/// What the value editor sheet opens with.
struct ProjectEditRuntimeValueEditorItem: Identifiable, Hashable {
    var value: ProjectEditRuntimeValues.Value
    var isNew: Bool
    var linked: Bool
    var id: String { value.key }
}

/// The custom integer value rows of the MP runtime-values card (one switch + 编辑 row per value),
/// then the 自定义整数值 · 添加 row that opens the value editor. Bound to Core `ProjectEditRuntimeValues`.
@MainActor struct ProjectEditRuntimeCustomValueRows: View {
    @ObservedObject var model: ProjectEditModel
    @Binding var refusalKey: String?
    @State private var editorItem: ProjectEditRuntimeValueEditorItem?
    @State private var saves = 0

    private var rows: [ProjectEditRuntimeValues.Value] { ProjectEditRuntimeValues.values(in: model.draft) }

    var body: some View {
        ForEach(rows) { row in
            valueToggle(row)
            editButton(row)
        }
        addButton
            .sheet(item: $editorItem) { item in
                editor(item)
            }
            .sensoryFeedback(.success, trigger: saves)
    }

    private func valueToggle(_ row: ProjectEditRuntimeValues.Value) -> some View {
        Toggle(isOn: Binding(get: { true }, set: { on in if !on { remove(row.key) } })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: row.label)
                Self.valueLine(row)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("projectEdit.values.custom.\(row.key)")
    }

    /// MP: 已启用 · 玩家可见/玩家隐藏 · min 至 max (· 开局值越界).
    static func valueLine(_ row: ProjectEditRuntimeValues.Value) -> Text {
        let base = row.visible
            ? Text("mpPublish.values.custom.visibleLine \(row.min) \(row.max)")
            : Text("mpPublish.values.custom.hiddenLine \(row.min) \(row.max)")
        if row.invalidInitial {
            return base + Text("mpPublish.values.custom.initialOut")
        }
        return base
    }

    private func editButton(_ row: ProjectEditRuntimeValues.Value) -> some View {
        Button {
            open(row)
        } label: {
            LabeledContent {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } label: {
                Text("mpPublish.values.edit \(row.label)")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("projectEdit.values.custom.\(row.key).edit")
    }

    private var addButton: some View {
        Button {
            openNew()
        } label: {
            LabeledContent {
                Label("mpPublish.values.custom.add", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.tint)
            } label: {
                Text("mpPublish.values.custom")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("mpPublish.values.custom.addA11y"))
        .accessibilityIdentifier("projectEdit.values.custom.add")
    }

    @ViewBuilder private func editor(_ item: ProjectEditRuntimeValueEditorItem) -> some View {
        ProjectEditRuntimeValueEditor(model: model, start: item, onSaved: { saves += 1 })
    }

    private func open(_ row: ProjectEditRuntimeValues.Value) {
        editorItem = ProjectEditRuntimeValueEditorItem(value: row, isNew: false, linked: ProjectEditRuntimeValues.linked(row.key, in: model.draft))
    }

    /// MP `openValueEditor`: a bound topic edits its values in 初始状态 instead.
    private func openNew() {
        if ProjectEditRuntimeValues.bound(in: model.draft) {
            refusalKey = ProjectEditRuntimeValues.Copy.bound
            return
        }
        editorItem = ProjectEditRuntimeValueEditorItem(value: ProjectEditRuntimeValues.newValue(in: model.draft), isNew: true, linked: false)
    }

    private func remove(_ key: String) {
        do {
            model.draft = try ProjectEditRuntimeValues.remove(key, in: model.draft)
            refusalKey = nil
        } catch {
            refusalKey = Self.message(error)
        }
    }

    /// Refusal text for the card footer and the sheet: a copy key, or 请先移除引用：places.
    static func message(_ error: Error) -> String {
        guard let refusal = error as? ProjectEditRuntimeValues.Refusal else { return ProjectEditThemeRules.Copy.unreadable }
        switch refusal {
        case .copy(let key):
            return key
        case .referenced(let places):
            let names = places.map { Self.place($0) }
            let joined = ListFormatter.localizedString(byJoining: names)
            let text: String.LocalizationValue = "mpPublish.values.ref.blocked \(joined)"
            return String(localized: text)
        }
    }

    private static func place(_ reference: ProjectEditRuntimeValues.Reference) -> String {
        switch reference {
        case .chapterCost(let number):
            let text: String.LocalizationValue = "mpPublish.values.ref.chapter \(number)"
            return String(localized: text)
        case .item(let name):
            let text: String.LocalizationValue = "mpPublish.values.ref.item \(name)"
            return String(localized: text)
        case .link(let id):
            let text: String.LocalizationValue = "mpPublish.values.ref.link \(id)"
            return String(localized: text)
        }
    }
}

/// MP value editor sheet: 名称 · 玩家可见 → 范围 (最小值 · 最大值) → 关联 (下降时一起扣生命值) → 删除数值.
/// 退出 drops the edits; 完成 saves through `ProjectEditRuntimeValues.save`.
@MainActor struct ProjectEditRuntimeValueEditor: View {
    @ObservedObject var model: ProjectEditModel
    let start: ProjectEditRuntimeValueEditorItem
    let onSaved: () -> Void
    @State private var value: ProjectEditRuntimeValues.Value
    @State private var link: Bool
    @State private var errorKey: String?
    @Environment(\.dismiss) private var dismiss

    init(model: ProjectEditModel, start: ProjectEditRuntimeValueEditorItem, onSaved: @escaping () -> Void) {
        self.model = model
        self.start = start
        self.onSaved = onSaved
        _value = State(initialValue: start.value)
        _link = State(initialValue: start.linked)
    }

    private var readOnly: Bool { ProjectEditRuntimeValues.bound(in: model.draft) }

    private var hpLabel: String {
        let name = ProjectEditRuntimeStats.name(.hp, in: model.draft).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: String.LocalizationValue(ProjectEditRuntimeStats.Stat.hp.labelKey)) : name
    }

    private var title: Text {
        let label = value.label.trimmingCharacters(in: .whitespaces)
        if !label.isEmpty { return Text(verbatim: label) }
        return start.isNew ? Text("mpPublish.values.custom.addTitle") : Text("mpPublish.values.custom.editTitle")
    }

    var body: some View {
        NavigationStack {
            form
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .presentationDetents([.medium, .large])
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent("mpPublish.values.custom.label") {
                    TextField("mpPublish.values.custom.label", text: labelBinding)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityIdentifier("projectEdit.values.custom.editor.label")
                Toggle("mpPublish.values.custom.visible", isOn: $value.visible)
                    .accessibilityIdentifier("projectEdit.values.custom.editor.visible")
            }
            .disabled(readOnly)
            rangeSection
            Section("mpPublish.values.custom.links") {
                Toggle(isOn: $link) {
                    Text("mpPublish.values.custom.link \(hpLabel)")
                }
                .accessibilityIdentifier("projectEdit.values.custom.editor.link")
            }
            .disabled(readOnly)
            deleteSection
        }
    }

    private var rangeSection: some View {
        Section {
            Stepper(value: $value.min, in: ProjectEditRuntimeValues.floor...Swift.max(value.max, ProjectEditRuntimeValues.floor)) {
                LabeledContent("mpPublish.values.custom.min", value: value.min, format: .number)
            }
            .accessibilityIdentifier("projectEdit.values.custom.editor.min")
            Stepper(value: $value.max, in: Swift.min(value.min, ProjectEditRuntimeValues.ceiling)...ProjectEditRuntimeValues.ceiling) {
                LabeledContent("mpPublish.values.custom.max", value: value.max, format: .number)
            }
            .accessibilityIdentifier("projectEdit.values.custom.editor.max")
        } header: {
            Text("mpPublish.values.custom.range")
        }
        .disabled(readOnly)
    }

    @ViewBuilder private var deleteSection: some View {
        Section {
            if !start.isNew && !readOnly {
                Button(role: .destructive) {
                    remove()
                } label: {
                    Text("mpPublish.values.custom.delete")
                }
                .accessibilityIdentifier("projectEdit.values.custom.editor.delete")
            }
        } footer: {
            if let errorKey {
                Label(LocalizedStringKey(errorKey), systemImage: "exclamationmark.circle")
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("projectEdit.values.custom.editor.error")
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("mpPublish.values.custom.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("mpPublish.values.custom.done") { save() }
                .disabled(readOnly)
        }
    }

    /// MP `maxlength="24"`.
    private var labelBinding: Binding<String> {
        Binding(get: { value.label }, set: { text in
            value.label = String(text.prefix(ProjectEditRuntimeValues.labelLimit))
            errorKey = nil
        })
    }

    private func save() {
        do {
            model.draft = try ProjectEditRuntimeValues.save(value, link: link, in: model.draft)
            onSaved()
            dismiss()
        } catch {
            errorKey = ProjectEditRuntimeCustomValueRows.message(error)
        }
    }

    private func remove() {
        do {
            model.draft = try ProjectEditRuntimeValues.remove(value.key, in: model.draft)
            dismiss()
        } catch {
            errorKey = ProjectEditRuntimeCustomValueRows.message(error)
        }
    }
}
