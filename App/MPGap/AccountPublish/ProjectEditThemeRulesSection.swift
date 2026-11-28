import SwiftUI

// MARK: - MP pages/publish/fabu/topic-detail-sheet.wxml:144-185 (玩法规则 card, rows 交换物资 · 表决方式 · 允许再玩一次 · 同场路线)
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
