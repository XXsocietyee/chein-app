import SwiftUI

// MARK: - MP pages/publish/fabu/topic-detail-sheet.wxml:144-185 (玩法规则 card, rows 进行方式 · 交换物资 · 表决方式 · 允许再玩一次 · 同场路线)
// theme-runtime-structure.js MODES / modeReason / setMode + runtime-structure-editor.wxml kind 'mode' (进行方式 page)
// theme-ownership.js:96-107 onThemeAllowTrade / onThemeVotePolicy (shared team world only)
// theme-runtime-survival.js:101 display, :124-137 toggleThemeReplay / toggleThemeTeamTrail
// survival-editor.wxml + theme-runtime-survival.js openSurvivalEditor / saveSurvivalEditor (结果卡 sheet)
// theme-d20-page.js onD20Toggle / openD20Sheet (rows d20 检定 · d20 与角色设定; sheet in ProjectEditD20Sheet.swift)

/// 玩法规则 in the 主题详情 sheet, after the runtime-values entries and before 可玩时段 (MP order).
/// Two system `Toggle` rows bound to Core `ProjectEditThemeRules`; a refusal shows as a red section footer
/// (MP `themeReplayError`). No request: the topic save carries `themeRuntimeConfig`.
@MainActor struct ProjectEditThemeRulesSection: View {
    @ObservedObject var model: ProjectEditModel
    @State private var refusalKey: String?
    @State private var editingCard = false
    @State private var editingD20 = false

    var body: some View {
        Section {
            NavigationLink {
                ProjectEditRunModePage(model: model)
            } label: {
                LabeledContent {
                    Text(LocalizedStringKey(ProjectEditThemeRules.modeLabelKey(ProjectEditThemeRules.runMode(in: model.draft))))
                } label: {
                    Label("mpPublish.rules.mode", systemImage: "person.3")
                }
            }
            .accessibilityIdentifier("projectEdit.rules.mode")
            if ProjectEditThemeRules.worldShared(in: model.draft) {
                Toggle(isOn: Binding(get: { ProjectEditThemeRules.allowTrade(in: model.draft) }, set: { setAllowTrade($0) })) {
                    Label("mpPublish.rules.allowTrade", systemImage: "arrow.left.arrow.right")
                }
                .accessibilityIdentifier("projectEdit.rules.allowTrade")
                Picker(selection: Binding(get: { ProjectEditThemeRules.votePolicy(in: model.draft) }, set: { setVotePolicy($0) })) {
                    ForEach(ProjectEditThemeRules.VotePolicy.allCases) { policy in
                        Text(LocalizedStringKey(policy.labelKey)).tag(policy)
                    }
                } label: {
                    Label("mpPublish.rules.votePolicy", systemImage: "line.3.horizontal.decrease")
                }
                .accessibilityIdentifier("projectEdit.rules.votePolicy")
            }
            Button {
                editingCard = true
            } label: {
                LabeledContent {
                    Text(ProjectEditThemeRules.cardCustomized(in: model.draft) ? "mpPublish.rules.card.custom" : "mpPublish.rules.card.default")
                } label: {
                    Label("mpPublish.rules.card", systemImage: "star")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("projectEdit.rules.card")
            Toggle(isOn: Binding(get: { ProjectEditThemeRules.replayEnabled(in: model.draft) }, set: { setReplay($0) })) {
                Label("mpPublish.rules.replay", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("projectEdit.rules.replay")
            Toggle(isOn: Binding(get: { ProjectEditThemeRules.teamTrail(in: model.draft) }, set: { setTeamTrail($0) })) {
                Label("mpPublish.rules.teamTrail", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .accessibilityIdentifier("projectEdit.rules.teamTrail")
            Toggle(isOn: Binding(get: { d20.checkEnabled }, set: { setD20($0) })) {
                Label("mpPublish.d20.check", systemImage: "die.face.5")
            }
            .accessibilityIdentifier("projectEdit.rules.d20")
            if d20.checkEnabled {
                Button {
                    editingD20 = true
                } label: {
                    LabeledContent {
                        ProjectEditD20Summary(rules: d20)
                    } label: {
                        Label("mpPublish.d20.settings", systemImage: "person.text.rectangle")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("projectEdit.rules.d20Settings")
            }
        } header: {
            Text("mpPublish.rules.title")
        } footer: {
            if let refusalKey {
                Label(LocalizedStringKey(refusalKey), systemImage: "exclamationmark.circle")
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("projectEdit.rules.error")
            }
        }
        .disabled(!model.fullEdit)
        .sheet(isPresented: $editingCard) {
            ProjectEditResultCardSheet(model: model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $editingD20) {
            ProjectEditD20Sheet(model: model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var d20: ProjectEditD20Rules.Model { ProjectEditD20Rules.model(in: model.draft) }

    /// MP `onD20Toggle`: a refused write leaves the switch where it was and shows the reason.
    private func setD20(_ enabled: Bool) {
        apply { try ProjectEditD20Rules.setCheckEnabled(enabled, in: $0) }
    }

    private func setReplay(_ enabled: Bool) {
        do {
            model.draft = try ProjectEditThemeRules.setReplay(enabled, in: model.draft)
            refusalKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            refusalKey = key
        } catch {
            refusalKey = ProjectEditThemeRules.Copy.unreadable
        }
    }

    private func setAllowTrade(_ enabled: Bool) {
        apply { try ProjectEditThemeRules.setAllowTrade(enabled, in: $0) }
    }

    private func setVotePolicy(_ policy: ProjectEditThemeRules.VotePolicy) {
        apply { try ProjectEditThemeRules.setVotePolicy(policy, in: $0) }
    }

    private func apply(_ change: (ProjectEditDraft) throws -> ProjectEditDraft) {
        do {
            model.draft = try change(model.draft)
            refusalKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            refusalKey = key
        } catch {
            refusalKey = ProjectEditThemeRules.Copy.unreadable
        }
    }

    private func setTeamTrail(_ enabled: Bool) {
        do {
            model.draft = try ProjectEditThemeRules.setTeamTrail(enabled, in: model.draft)
            refusalKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            refusalKey = key
        } catch {
            refusalKey = ProjectEditThemeRules.Copy.unreadable
        }
    }
}

/// MP `runtime-structure-editor.wxml` kind `mode`: header 队伍怎样一起玩？, three single-choice rows
/// (icon · name · red reason when unavailable · mark), the support-matrix loading line and the
/// non-blocking read failure with 重试. Native: a pushed list; a choice applies at once.
@MainActor struct ProjectEditRunModePage: View {
    @ObservedObject var model: ProjectEditModel
    @State private var inputs: NativeRuntimeStructureAuthorInputs?
    @State private var loading = false
    @State private var loadFailed = false
    @State private var refusalKey: String?

    private var currentInputs: NativeRuntimeStructureAuthorInputs? {
        guard let inputs, model.coordinator.runtimeStructureInputsAreCurrent(inputs) else { return nil }
        return inputs
    }

    var body: some View {
        List {
            Section {
                ForEach(ProjectEditThemeRules.RunMode.allCases) { mode in
                    modeRow(mode, reason: ProjectEditThemeRules.modeReason(mode, in: model.draft, inputs: currentInputs))
                }
            } header: {
                Text("mpPublish.rules.mode.question")
            } footer: {
                footer
            }
        }
        .navigationTitle(Text("mpPublish.rules.mode"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func modeRow(_ mode: ProjectEditThemeRules.RunMode, reason: ProjectEditThemeRules.ModeReason?) -> some View {
        let selected = ProjectEditThemeRules.runMode(in: model.draft) == mode
        return Button {
            choose(mode)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label(LocalizedStringKey(ProjectEditThemeRules.modeLabelKey(mode)), systemImage: icon(mode))
                    if let reason {
                        reasonText(reason)
                            .font(.footnote)
                            .foregroundStyle(CYColor.dangerText)
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(reason != nil || !model.fullEdit)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("projectEdit.rules.mode." + mode.rawValue)
    }

    @ViewBuilder private var footer: some View {
        if let refusalKey {
            Label(LocalizedStringKey(refusalKey), systemImage: "exclamationmark.circle")
                .foregroundStyle(CYColor.dangerText)
        } else if loading {
            Label {
                Text("mpPublish.rules.mode.loading")
            } icon: {
                ProgressView()
            }
        } else if loadFailed {
            VStack(alignment: .leading, spacing: 8) {
                Text("mpPublish.rules.mode.matrixFailed")
                Button("mpPublish.rules.mode.retry") {
                    Task { await load() }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func reasonText(_ reason: ProjectEditThemeRules.ModeReason) -> Text {
        switch reason {
        case .key(let key): return Text(LocalizedStringKey(key))
        case .text(let text): return Text(verbatim: text)
        }
    }

    private func icon(_ mode: ProjectEditThemeRules.RunMode) -> String {
        switch mode {
        case .player: return "person"
        case .team: return "person.3"
        case .sharedWorld: return "map"
        }
    }

    private func choose(_ mode: ProjectEditThemeRules.RunMode) {
        do {
            model.draft = try ProjectEditThemeRules.setMode(mode, in: model.draft, inputs: currentInputs)
            refusalKey = nil
        } catch ProjectEditRuntimeActsError.refused(let key) {
            refusalKey = key
        } catch {
            refusalKey = ProjectEditThemeRules.Copy.unreadable
        }
    }

    private func load() async {
        guard model.fullEdit, !loading else { return }
        loading = true
        loadFailed = false
        do {
            inputs = try await model.coordinator.runtimeStructureInputs(draft: model.draft)
        } catch {
            inputs = nil
            loadFailed = true
        }
        loading = false
    }
}

/// MP `survival-editor.wxml` (结果卡): 退出 / 完成 → title 结果卡 → error line → 结果卡封面 (1:1 upload; empty = topic cover)
/// → 卡片上显示 (nine check rows in `CARD_FIELDS` order) + 显示已解锁内容 → 恢复默认结果卡 (only for a customized card).
/// Native: a stacked sheet with 取消 / 完成; 完成 runs the MP card checks and keeps the sheet open on a problem.
@MainActor struct ProjectEditResultCardSheet: View {
    @ObservedObject var model: ProjectEditModel
    @Environment(\.dismiss) private var dismiss
    @State private var row: [String: ProjectEditJSON] = [:]
    @State private var customized = false
    @State private var reset = false
    @State private var errorKey: String?
    @State private var loaded = false

    private var cover: Binding<String> {
        Binding(get: { ProjectEditThemeRules.cardCover(row) }, set: { value in
            reset = false
            errorKey = nil
            row = ProjectEditThemeRules.settingCardCover(value, in: row)
        })
    }

    private var showUnlocks: Binding<Bool> {
        Binding(get: { row["showUnlocks"] == .bool(true) }, set: { row["showUnlocks"] = .bool($0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorKey {
                    Section {
                        Label(LocalizedStringKey(errorKey), systemImage: "exclamationmark.circle")
                            .foregroundStyle(CYColor.dangerText)
                            .accessibilityIdentifier("projectEdit.card.error")
                    }
                }
                Section {
                    ProjectEditTopicImageField(kind: .resultCard, title: "mpPublish.rules.card.cover", value: cover, identifier: "projectEdit.card.cover")
                } footer: {
                    if ProjectEditThemeRules.cardCover(row).isEmpty {
                        Text("mpPublish.rules.card.coverFallback")
                    }
                }
                Section {
                    ForEach(ProjectEditThemeRules.CardField.allCases) { field in
                        fieldRow(field)
                    }
                    Toggle("mpPublish.rules.card.showUnlocks", isOn: showUnlocks)
                        .accessibilityIdentifier("projectEdit.card.showUnlocks")
                } header: {
                    Text("mpPublish.rules.card.shows")
                }
                if customized {
                    Section {
                        Button("mpPublish.rules.card.reset", role: .destructive) {
                            customized = false
                            row = [:]
                            reset = true
                            errorKey = nil
                        }
                        .accessibilityIdentifier("projectEdit.card.reset")
                    }
                }
            }
            .navigationTitle(Text("mpPublish.rules.card"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { save() }
                        .accessibilityIdentifier("projectEdit.card.done")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                row = ProjectEditThemeRules.card(in: model.draft)
                customized = ProjectEditThemeRules.cardCustomized(in: model.draft)
            }
        }
    }

    private func fieldRow(_ field: ProjectEditThemeRules.CardField) -> some View {
        let checked = ProjectEditThemeRules.cardFields(row).contains(field.rawValue)
        return Button {
            reset = false
            errorKey = nil
            row = ProjectEditThemeRules.toggleCardField(field, in: row)
        } label: {
            HStack {
                fieldLabel(field)
                    .foregroundStyle(.primary)
                Spacer()
                if checked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(checked ? .isSelected : [])
        .accessibilityIdentifier("projectEdit.card.field." + field.rawValue)
    }

    private func fieldLabel(_ field: ProjectEditThemeRules.CardField) -> Text {
        if let name = ProjectEditThemeRules.cardCustomName(field, in: model.draft) {
            return Text(verbatim: name)
        }
        return Text(LocalizedStringKey(ProjectEditThemeRules.cardFieldLabelKey(field)))
    }

    private func save() {
        do {
            model.draft = try ProjectEditThemeRules.saveCard(row, reset: reset, in: model.draft)
            dismiss()
        } catch ProjectEditRuntimeActsError.refused(let key) {
            errorKey = key
        } catch {
            errorKey = ProjectEditThemeRules.Copy.unreadable
        }
    }
}
