import SwiftUI

// MARK: - MP pages/publish/fabu/topic-detail-sheet.wxml:126-140 (runtime-values card rows 行动次数 · 没有实际效果时也消耗)
// theme-runtime.js onRuntimeActionToggle / onRuntimeActionLimit / onRuntimeName (actionName) / _validateRuntimeConfig
// theme-ownership.js onThemeConsumeOnNoEffect / runtimeConsumeOnNoEffectDisabledReason

/// The 生命值 / 幸运值 rows (`ProjectEditRuntimeStatRow`), the 行动次数 row, the custom integer values (`ProjectEditRuntimeCustomValueRows`) (switch, value line, 显示名称 and 上限 while editing) and the closing
/// 没有实际效果时也消耗 switch of the MP runtime-values card. Bound to Core `ProjectEditThemeRules`;
/// no request, the topic save carries `themeRuntimeConfig`.
@MainActor struct ProjectEditRuntimeValuesRows: View {
    @ObservedObject var model: ProjectEditModel
    /// MP `runtimeEditingStat`: "hp", "luck" or "action"; one row's fields are open at a time.
    @State private var editing: String?
    @State private var refusalKey: String?

    private var editingAction: Bool { editing == "action" }

    var body: some View {
        Section {
            // MP topic-detail-sheet.wxml:115-123: 生命值 then 幸运值 open the card (schema-1 journeyRules only).
            if ProjectEditRuntimeStats.available(in: model.draft) {
                ProjectEditRuntimeStatRow(model: model, stat: .hp, editing: $editing, refusalKey: $refusalKey)
                ProjectEditRuntimeStatRow(model: model, stat: .luck, editing: $editing, refusalKey: $refusalKey)
            }
            actionToggle
            editButton
            if editingAction {
                actionFields
            }
            // MP topic-detail-sheet.wxml:130-135: custom integer values, then 自定义整数值 · 添加.
            if ProjectEditRuntimeStats.available(in: model.draft) {
                ProjectEditRuntimeCustomValueRows(model: model, refusalKey: $refusalKey)
            }
            consumeToggle
        } footer: {
            footer
        }
        .disabled(!model.fullEdit)
    }

    private static let actionKey = "mpPublish.values.action"

    private var limit: Int? { ProjectEditThemeRules.actionLimit(in: model.draft) }

    private var actionLabel: String {
        let name = ProjectEditThemeRules.actionName(in: model.draft).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: String.LocalizationValue(Self.actionKey)) : name
    }

    private var actionToggle: some View {
        Toggle(isOn: Binding(get: { limit != nil }, set: { setActionEnabled($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: actionLabel)
                actionValue
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("projectEdit.values.action")
    }

    @ViewBuilder private var actionValue: some View {
        if let limit {
            Text("mpPublish.values.enabled \(limit)")
        } else {
            Text("mpPublish.values.disabled")
        }
    }

    /// MP 编辑 pill: opens 显示名称 / 上限 under the row; a second tap closes them.
    private var editButton: some View {
        Button {
            editing = editingAction ? nil : "action"
        } label: {
            LabeledContent {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(editingAction ? 90 : 0))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } label: {
                Text("mpPublish.values.edit \(actionLabel)")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(editingAction ? .isSelected : [])
        .accessibilityIdentifier("projectEdit.values.action.edit")
    }

    @ViewBuilder private var actionFields: some View {
        LabeledContent("mpPublish.values.name") {
            TextField("mpPublish.values.action", text: Binding(get: { ProjectEditThemeRules.actionName(in: model.draft) }, set: { setActionName($0) }))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityIdentifier("projectEdit.values.action.name")
        if limit != nil {
            LabeledContent("mpPublish.values.limit") {
                TextField("mpPublish.values.limit", value: Binding(get: { limit ?? ProjectEditThemeRules.defaultActionLimit }, set: { setActionLimit($0) }), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityIdentifier("projectEdit.values.action.limit")
        }
    }

    private var consumeToggle: some View {
        let available = ProjectEditThemeRules.consumeOnNoEffectAvailable(in: model.draft)
        let on = ProjectEditThemeRules.consumeOnNoEffect(in: model.draft)
        return Toggle(isOn: Binding(get: { on }, set: { setConsume($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("mpPublish.values.consume")
                Text(LocalizedStringKey(consumeDetailKey(available: available, on: on)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!available)
        .accessibilityIdentifier("projectEdit.values.consume")
    }

    private func consumeDetailKey(available: Bool, on: Bool) -> String {
        if !available { return "mpPublish.values.consume.needsMode" }
        return on ? "mpPublish.values.consume.on" : "mpPublish.values.consume.off"
    }

    @ViewBuilder private var footer: some View {
        if let refusalKey {
            Label(LocalizedStringKey(refusalKey), systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
                .accessibilityIdentifier("projectEdit.values.error")
        }
    }

    private func setActionEnabled(_ enabled: Bool) {
        apply { try ProjectEditThemeRules.setActionEnabled(enabled, in: $0) }
        if !enabled && editingAction { editing = nil }
    }

    private func setActionLimit(_ value: Int) {
        apply { try ProjectEditThemeRules.setActionLimit(value, in: $0) }
    }

    private func setActionName(_ name: String) {
        apply { try ProjectEditThemeRules.setActionName(name, in: $0) }
    }

    private func setConsume(_ enabled: Bool) {
        apply { try ProjectEditThemeRules.setConsumeOnNoEffect(enabled, in: $0) }
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
}
