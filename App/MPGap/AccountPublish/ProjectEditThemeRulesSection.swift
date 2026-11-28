import SwiftUI

// MARK: - MP pages/publish/fabu/topic-detail-sheet.wxml:144-185 (玩法规则 card, rows 进行方式 · 交换物资 · 表决方式 · 允许再玩一次 · 同场路线)
// theme-runtime-structure.js MODES / modeReason / setMode + runtime-structure-editor.wxml kind 'mode' (进行方式 page)
// theme-ownership.js:96-107 onThemeAllowTrade / onThemeVotePolicy (shared team world only)
// theme-runtime-survival.js:101 display, :124-137 toggleThemeReplay / toggleThemeTeamTrail

/// 玩法规则 in the 主题详情 sheet, after the runtime-values entries and before 可玩时段 (MP order).
/// Two system `Toggle` rows bound to Core `ProjectEditThemeRules`; a refusal shows as a red section footer
/// (MP `themeReplayError`). No request: the topic save carries `themeRuntimeConfig`.
@MainActor struct ProjectEditThemeRulesSection: View {
    @ObservedObject var model: ProjectEditModel
    @State private var refusalKey: String?

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
            Toggle(isOn: Binding(get: { ProjectEditThemeRules.replayEnabled(in: model.draft) }, set: { setReplay($0) })) {
                Label("mpPublish.rules.replay", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("projectEdit.rules.replay")
            Toggle(isOn: Binding(get: { ProjectEditThemeRules.teamTrail(in: model.draft) }, set: { setTeamTrail($0) })) {
                Label("mpPublish.rules.teamTrail", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            .accessibilityIdentifier("projectEdit.rules.teamTrail")
        } header: {
            Text("mpPublish.rules.title")
        } footer: {
            if let refusalKey {
                Label(LocalizedStringKey(refusalKey), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("projectEdit.rules.error")
            }
        }
        .disabled(!model.fullEdit)
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
                            .foregroundStyle(.red)
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
                .foregroundStyle(.red)
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
