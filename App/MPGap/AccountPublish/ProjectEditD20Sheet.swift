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
                        ProjectEditD20MoreRulesPage(rules: $rules, readOnly: readOnly)
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

/// MP `d20-settings` second level 更多规则, in MP order: 进度钟 (rows `name · 坏事逼近 / 事情进展 · N 格`; expand for
/// 名称 · 类型 · 格数 · 删除; 添加进度钟 up to 6) → 特质 (rows expand for the description and 移除; preset chips add, up to 12).
/// Edits go into the sheet's local model; the sheet's 完成 saves them.
@MainActor struct ProjectEditD20MoreRulesPage: View {
    @Binding var rules: ProjectEditD20Rules.Model
    let readOnly: Bool
    @State private var openClock: String?
    @State private var openAspect: String?
    @State private var addingClock = false
    @State private var clockName = ""
    @State private var pendingClock: ProjectEditD20Rules.Clock?
    @State private var pendingAspect: ProjectEditD20Rules.Aspect?

    var body: some View {
        List {
            clocksSection
            aspectsSection
        }
        .navigationTitle(Text("mpPublish.d20.more"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("mpPublish.d20.clock.namePrompt", isPresented: $addingClock) {
            TextField("mpPublish.d20.clock.namePrompt", text: $clockName)
            Button("action.cancel", role: .cancel) { clockName = "" }
            Button("mpPublish.d20.clock.addAction") { addClock() }
        }
        .confirmationDialog(clockDeleteTitle, isPresented: clockDialogShown, titleVisibility: .visible) {
            Button("mpPublish.d20.clock.delete", role: .destructive) { confirmClockDelete() }
            Button("action.cancel", role: .cancel) { pendingClock = nil }
        } message: {
            Text("mpPublish.d20.clock.deleteMessage")
        }
        .confirmationDialog(aspectRemoveTitle, isPresented: aspectDialogShown, titleVisibility: .visible) {
            Button("mpPublish.d20.aspect.remove", role: .destructive) { confirmAspectRemove() }
            Button("action.cancel", role: .cancel) { pendingAspect = nil }
        } message: {
            Text("mpPublish.d20.aspect.removeMessage")
        }
    }

    // MARK: 进度钟

    private var clocksSection: some View {
        Section {
            if readOnly && rules.clocks.isEmpty {
                Text("mpPublish.d20.clocks.empty")
                    .foregroundStyle(.secondary)
            }
            ForEach(rules.clocks) { clock in
                clockRow(clock)
            }
            .onDelete { offsets in
                guard !readOnly, let index = offsets.first else { return }
                pendingClock = rules.clocks[index]
            }
            .deleteDisabled(readOnly)
            if !readOnly && rules.clocks.count < ProjectEditD20Rules.maxClocks {
                Button {
                    clockName = ""
                    openClock = nil
                    addingClock = true
                } label: {
                    Label("mpPublish.d20.clock.add", systemImage: "plus")
                }
                .accessibilityIdentifier("projectEdit.d20.clock.add")
            }
        } header: {
            Text("mpPublish.d20.clocks")
        }
    }

    @ViewBuilder private func clockRow(_ clock: ProjectEditD20Rules.Clock) -> some View {
        let summary = LabeledContent(clock.label) {
            Text("mpPublish.d20.clock.detail \(Text(LocalizedStringKey(clock.danger ? "mpPublish.d20.clock.danger" : "mpPublish.d20.clock.progress"))) \(clock.segments)")
        }
        if readOnly {
            summary
        } else {
            DisclosureGroup(isExpanded: openBinding(clock.key, $openClock)) {
                ProjectEditD20ClockNameField(label: clock.label) { name in rename(clock.key, name) }
                Picker("mpPublish.d20.clock.kind", selection: clockKind(clock.key)) {
                    Text("mpPublish.d20.clock.danger").tag(true)
                    Text("mpPublish.d20.clock.progress").tag(false)
                }
                .cyAdaptiveSegmented()
                Picker("mpPublish.d20.clock.segments", selection: clockSegments(clock.key)) {
                    ForEach(ProjectEditD20Rules.clockSegmentOptions, id: \.self) { count in
                        Text("mpPublish.d20.clock.segmentsOption \(count)").tag(count)
                    }
                }
                .cyAdaptiveSegmented()
                Button("mpPublish.d20.clock.delete", role: .destructive) { pendingClock = clock }
            } label: {
                summary
            }
            .accessibilityIdentifier("projectEdit.d20.clock")
        }
    }

    private func clockKind(_ key: String) -> Binding<Bool> {
        Binding(get: { rules.clocks.first(where: { $0.key == key })?.danger ?? true }, set: { value in
            guard let index = rules.clocks.firstIndex(where: { $0.key == key }) else { return }
            rules.clocks[index].danger = value
        })
    }

    private func clockSegments(_ key: String) -> Binding<Int> {
        Binding(get: { rules.clocks.first(where: { $0.key == key })?.segments ?? 6 }, set: { value in
            guard let index = rules.clocks.firstIndex(where: { $0.key == key }) else { return }
            rules.clocks[index].segments = value
        })
    }

    /// MP `clockRename`: a blank name keeps the old one.
    private func rename(_ key: String, _ name: String) {
        let label = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ProjectEditD20Rules.clockNameLimit))
        guard !label.isEmpty, let index = rules.clocks.firstIndex(where: { $0.key == key }) else { return }
        rules.clocks[index].label = label
    }

    /// MP `clockAdd`: the new clock opens expanded.
    private func addClock() {
        let label = String(clockName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ProjectEditD20Rules.clockNameLimit))
        clockName = ""
        guard !label.isEmpty, rules.clocks.count < ProjectEditD20Rules.maxClocks else { return }
        let clock = ProjectEditD20Rules.newClock(label: label, in: rules)
        rules.clocks.append(clock)
        openClock = clock.key
    }

    private var clockDialogShown: Binding<Bool> {
        Binding(get: { pendingClock != nil }, set: { if !$0 { pendingClock = nil } })
    }

    private var clockDeleteTitle: Text {
        Text("mpPublish.d20.clock.deleteTitle \(pendingClock?.label ?? "")")
    }

    private func confirmClockDelete() {
        guard let clock = pendingClock else { return }
        rules.clocks.removeAll { $0.key == clock.key }
        if openClock == clock.key { openClock = nil }
        pendingClock = nil
    }

    // MARK: 特质

    private var aspectsSection: some View {
        Section {
            if readOnly && rules.aspects.isEmpty {
                Text("mpPublish.d20.aspects.empty")
                    .foregroundStyle(.secondary)
            }
            ForEach(rules.aspects) { aspect in
                aspectRow(aspect)
            }
            .onDelete { offsets in
                guard !readOnly, let index = offsets.first else { return }
                pendingAspect = rules.aspects[index]
            }
            .deleteDisabled(readOnly)
            if !readOnly && rules.aspects.count < ProjectEditD20Rules.maxAspects && !availableAspects.isEmpty {
                Menu {
                    ForEach(availableAspects) { preset in
                        Button(LocalizedStringKey(preset.labelKey)) { addAspect(preset) }
                    }
                } label: {
                    Label("mpPublish.d20.aspect.add", systemImage: "plus")
                }
                .accessibilityIdentifier("projectEdit.d20.aspect.add")
            }
        } header: {
            Text("mpPublish.d20.aspects")
        }
    }

    @ViewBuilder private func aspectRow(_ aspect: ProjectEditD20Rules.Aspect) -> some View {
        if readOnly {
            VStack(alignment: .leading, spacing: 2) {
                Text(aspect.label)
                if !aspect.desc.isEmpty {
                    Text(aspect.desc)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            DisclosureGroup(isExpanded: openBinding(aspect.key, $openAspect)) {
                if !aspect.desc.isEmpty {
                    Text(aspect.desc)
                        .foregroundStyle(.secondary)
                }
                Button("mpPublish.d20.aspect.remove", role: .destructive) { pendingAspect = aspect }
            } label: {
                Text(aspect.label)
            }
            .accessibilityIdentifier("projectEdit.d20.aspect")
        }
    }

    private var availableAspects: [ProjectEditD20Rules.AspectPreset] {
        let taken = Set(rules.aspects.map(\.label))
        return ProjectEditD20Rules.aspectPresets.filter { !taken.contains(localized($0.labelKey)) }
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    /// MP `aspectAdd`: the new trait opens expanded.
    private func addAspect(_ preset: ProjectEditD20Rules.AspectPreset) {
        guard rules.aspects.count < ProjectEditD20Rules.maxAspects else { return }
        let aspect = ProjectEditD20Rules.newAspect(label: localized(preset.labelKey), desc: localized(preset.descKey), in: rules)
        rules.aspects.append(aspect)
        openAspect = aspect.key
    }

    private var aspectDialogShown: Binding<Bool> {
        Binding(get: { pendingAspect != nil }, set: { if !$0 { pendingAspect = nil } })
    }

    private var aspectRemoveTitle: Text {
        Text("mpPublish.d20.aspect.removeTitle \(pendingAspect?.label ?? "")")
    }

    private func confirmAspectRemove() {
        guard let aspect = pendingAspect else { return }
        rules.aspects.removeAll { $0.key == aspect.key }
        if openAspect == aspect.key { openAspect = nil }
        pendingAspect = nil
    }

    private func openBinding(_ key: String, _ open: Binding<String?>) -> Binding<Bool> {
        Binding(get: { open.wrappedValue == key }, set: { open.wrappedValue = $0 ? key : nil })
    }
}

/// MP 名称 input (`maxlength="10"`, saved on blur / confirm): commits when editing ends.
@MainActor struct ProjectEditD20ClockNameField: View {
    let label: String
    let onCommit: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent("mpPublish.d20.clock.name") {
            TextField("mpPublish.d20.clock.namePrompt", text: $text)
                .multilineTextAlignment(.trailing)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { onCommit(text) }
        }
        .onAppear { text = label }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { onCommit(text) }
        }
        .accessibilityIdentifier("projectEdit.d20.clock.name")
    }
}
