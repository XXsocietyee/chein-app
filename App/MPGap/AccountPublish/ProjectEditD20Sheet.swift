import SwiftUI

// MARK: - MP pages/publish/components/d20-settings (d20 与角色设定), opened from the 玩法规则 row in
// fabu/topic-detail-sheet.wxml:186-202; model fabu/theme-d20.js, handlers fabu/theme-d20-page.js.

/// The d20 与角色设定 row value: MP `summary` = `N 项属性` / `没有属性`, then ` · ` + the preset name.
@MainActor struct ProjectEditD20Summary: View {
    let rules: ProjectEditD20Rules.Model

    var body: some View {
        if let preset = rules.preset {
            countText + Text(verbatim: " · ") + Text(LocalizedStringKey(preset.labelKey))
        } else {
            countText
        }
    }

    private var countText: Text {
        rules.attributes.isEmpty ? Text("mpPublish.d20.noAttrs") : Text("mpPublish.d20.attrCount \(rules.attributes.count)")
    }
}

/// MP `d20-settings` first level, in MP order: 规则难度 (轻松 / 标准 / 硬核) → 规则 (天然 20 和天然 1 · 魔鬼交易 · 动量)
/// → 属性 (rows `开局值 / 最大值`, expand for 最小值 / 最大值 / 开局值 and 删除; presets + 自定义; 编辑 reorders)
/// → 更多规则 (进度钟 N · 特质 N). Edits stay local; 完成 writes them back (`onD20Save`), 取消 drops them.
@MainActor struct ProjectEditD20Sheet: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.dismiss) private var dismiss
    @State private var rules = ProjectEditD20Rules.Model()
    @State private var loaded = false
    @State private var errorKey: String?
    @State private var expandedKey: String?
    @State private var addingCustom = false
    @State private var customName = ""
    @State private var pendingDelete: ProjectEditD20Rules.Attribute?

    private var readOnly: Bool { !model.fullEdit }
    private var attributesLocked: Bool { readOnly || rules.bound }

    var body: some View {
        NavigationStack {
            Form {
                if let errorKey {
                    Section {
                        Label(LocalizedStringKey(errorKey), systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("projectEdit.d20.error")
                    }
                }
                Section {
                    Picker("mpPublish.d20.difficulty", selection: $rules.preset) {
                        ForEach(ProjectEditD20Rules.Preset.allCases) { preset in
                            Text(LocalizedStringKey(preset.labelKey)).tag(Optional(preset))
                        }
                    }
                    .cyAdaptiveSegmented()
                    .labelsHidden()
                    .accessibilityIdentifier("projectEdit.d20.preset")
                } header: {
                    Text("mpPublish.d20.difficulty")
                }
                .disabled(readOnly)
                Section {
                    Toggle("mpPublish.d20.natAuto", isOn: $rules.natAuto)
                        .accessibilityIdentifier("projectEdit.d20.natAuto")
                    Toggle("mpPublish.d20.bargain", isOn: $rules.bargain)
                        .accessibilityIdentifier("projectEdit.d20.bargain")
                    Toggle("mpPublish.d20.momentum", isOn: $rules.momentum)
                        .accessibilityIdentifier("projectEdit.d20.momentum")
                } header: {
                    Text("mpPublish.d20.rules")
                }
                .disabled(readOnly)
                attributesSection
                Section {
                    NavigationLink {
                        ProjectEditD20MoreRulesPage(rules: rules)
                    } label: {
                        LabeledContent("mpPublish.d20.more") {
                            Text("mpPublish.d20.more.value \(rules.clocks.count) \(rules.aspects.count)")
                        }
                    }
                    .accessibilityIdentifier("projectEdit.d20.more")
                }
            }
            .navigationTitle(Text("mpPublish.d20.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { save() }
                        .accessibilityIdentifier("projectEdit.d20.done")
                }
            }
            .alert("mpPublish.d20.attr.namePrompt", isPresented: $addingCustom) {
                TextField("mpPublish.d20.attr.namePrompt", text: $customName)
                Button("action.cancel", role: .cancel) { customName = "" }
                Button("mpPublish.d20.attr.addAction") { addCustom() }
            }
            .confirmationDialog(deleteTitle, isPresented: deleteDialogShown, titleVisibility: .visible) {
                Button("mpPublish.d20.attr.delete", role: .destructive) { confirmDelete() }
                Button("action.cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("mpPublish.d20.attr.deleteMessage")
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                rules = ProjectEditD20Rules.model(in: model.draft)
            }
        }
    }

    private var attributesSection: some View {
        Section {
            ForEach(rules.attributes) { attribute in
                attributeRow(attribute)
            }
            .onDelete { offsets in
                guard !attributesLocked, let index = offsets.first else { return }
                pendingDelete = rules.attributes[index]
            }
            .onMove { from, to in
                guard !attributesLocked else { return }
                rules.attributes.move(fromOffsets: from, toOffset: to)
            }
            .deleteDisabled(attributesLocked)
            .moveDisabled(attributesLocked)
            if !attributesLocked && rules.attributes.count < ProjectEditD20Rules.maxAttributes {
                Menu {
                    ForEach(availablePresets) { preset in
                        Button(LocalizedStringKey(preset.labelKey)) { add(preset) }
                    }
                    Button("mpPublish.d20.attr.custom") {
                        customName = ""
                        addingCustom = true
                    }
                } label: {
                    Label("mpPublish.d20.attr.add", systemImage: "plus")
                }
                .accessibilityIdentifier("projectEdit.d20.attr.add")
            }
        } header: {
            HStack {
                Text("mpPublish.d20.attrs")
                Spacer()
                if !attributesLocked && !rules.attributes.isEmpty {
                    EditButton()
                }
            }
        }
    }

    @ViewBuilder private func attributeRow(_ attribute: ProjectEditD20Rules.Attribute) -> some View {
        let summary = LabeledContent(attribute.label) {
            Text("mpPublish.d20.attr.value \(attribute.initial) \(attribute.max)")
        }
        if attributesLocked {
            summary
        } else {
            DisclosureGroup(isExpanded: expandedBinding(attribute.key)) {
                Stepper(value: valueBinding(attribute.key, .min), in: minRange(attribute)) {
                    LabeledContent("mpPublish.d20.attr.min") { Text(attribute.min, format: .number) }
                }
                Stepper(value: valueBinding(attribute.key, .max), in: maxRange(attribute)) {
                    LabeledContent("mpPublish.d20.attr.max") { Text(attribute.max, format: .number) }
                }
                Stepper(value: valueBinding(attribute.key, .initial), in: initialRange(attribute)) {
                    LabeledContent("mpPublish.d20.attr.initial") { Text(attribute.initial, format: .number) }
                }
                Button("mpPublish.d20.attr.delete", role: .destructive) { pendingDelete = attribute }
            } label: {
                summary
            }
            .accessibilityIdentifier("projectEdit.d20.attr")
        }
    }

    // MP steppers: 最小值 0…max-1, 最大值 min+1…20, 开局值 min…max (values outside stay as read).
    private func minRange(_ attribute: ProjectEditD20Rules.Attribute) -> ClosedRange<Int> {
        let lower = Swift.min(0, attribute.min)
        return lower...Swift.max(lower, attribute.max - 1)
    }

    private func maxRange(_ attribute: ProjectEditD20Rules.Attribute) -> ClosedRange<Int> {
        let lower = attribute.min + 1
        return lower...Swift.max(lower, ProjectEditD20Rules.stepperCeiling, attribute.max)
    }

    private func initialRange(_ attribute: ProjectEditD20Rules.Attribute) -> ClosedRange<Int> {
        attribute.min...Swift.max(attribute.min, attribute.max)
    }

    private func expandedBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { expandedKey == key }, set: { expandedKey = $0 ? key : nil })
    }

    private func valueBinding(_ key: String, _ field: ProjectEditD20Rules.AttributeField) -> Binding<Int> {
        Binding(get: {
            guard let attribute = rules.attributes.first(where: { $0.key == key }) else { return 0 }
            switch field {
            case .min: return attribute.min
            case .max: return attribute.max
            case .initial: return attribute.initial
            }
        }, set: { value in
            guard let index = rules.attributes.firstIndex(where: { $0.key == key }) else { return }
            rules.attributes[index] = ProjectEditD20Rules.clamp(rules.attributes[index], field, value)
        })
    }

    private var takenLabels: Set<String> { Set(rules.attributes.map(\.label)) }

    private var availablePresets: [ProjectEditD20Rules.AttributePreset] {
        ProjectEditD20Rules.attributePresets.filter { !takenLabels.contains(localized($0.labelKey)) }
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    private func add(_ preset: ProjectEditD20Rules.AttributePreset) {
        append(label: localized(preset.labelKey), preset: preset)
    }

    private func addCustom() {
        let name = String(customName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ProjectEditD20Rules.attributeNameLimit))
        customName = ""
        guard !name.isEmpty else { return }
        if takenLabels.contains(name) {
            errorKey = "mpPublish.d20.attr.taken"
            return
        }
        append(label: name, preset: nil)
    }

    private func append(label: String, preset: ProjectEditD20Rules.AttributePreset?) {
        guard rules.attributes.count < ProjectEditD20Rules.maxAttributes, !takenLabels.contains(label) else { return }
        let attribute = ProjectEditD20Rules.newAttribute(label: label, preset: preset, in: rules)
        rules.attributes.append(attribute)
        expandedKey = attribute.key
        errorKey = nil
    }

    private var deleteDialogShown: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private var deleteTitle: Text {
        Text("mpPublish.d20.attr.deleteTitle \(pendingDelete?.label ?? "")")
    }

    private func confirmDelete() {
        guard let attribute = pendingDelete else { return }
        rules.attributes.removeAll { $0.key == attribute.key }
        if expandedKey == attribute.key { expandedKey = nil }
        pendingDelete = nil
    }

    private func save() {
        guard !readOnly else {
            dismiss()
            return
        }
        do {
            model.draft = try ProjectEditD20Rules.save(rules, in: model.draft)
            dismiss()
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditThemeRules.Copy.unreadable
        }
    }
}

/// MP `d20-settings` second level 更多规则: 进度钟 (name · 坏事逼近 / 事情进展 · N 格) → 特质 (name, description).
/// Shown as read; adding and editing clocks and traits is the next pass.
@MainActor struct ProjectEditD20MoreRulesPage: View {
    let rules: ProjectEditD20Rules.Model

    var body: some View {
        List {
            Section {
                if rules.clocks.isEmpty {
                    Text("mpPublish.d20.clocks.empty")
                        .foregroundStyle(.secondary)
                }
                ForEach(rules.clocks) { clock in
                    LabeledContent(clock.label) {
                        Text("mpPublish.d20.clock.detail \(Text(LocalizedStringKey(clock.danger ? "mpPublish.d20.clock.danger" : "mpPublish.d20.clock.progress"))) \(clock.segments)")
                    }
                }
            } header: {
                Text("mpPublish.d20.clocks")
            }
            Section {
                if rules.aspects.isEmpty {
                    Text("mpPublish.d20.aspects.empty")
                        .foregroundStyle(.secondary)
                }
                ForEach(rules.aspects) { aspect in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(aspect.label)
                        if !aspect.desc.isEmpty {
                            Text(aspect.desc)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("mpPublish.d20.aspects")
            }
        }
        .navigationTitle(Text("mpPublish.d20.more"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
