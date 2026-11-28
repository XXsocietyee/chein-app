import SwiftUI

// MARK: - MP pages/publish/fabu/topic-detail-sheet.wxml:115-123 (runtime-values card rows 生命值 · 幸运值)
// theme-runtime.js _syncRuntimeStats / onRuntimeStatToggle (refused while referenced) / onRuntimeStatMax / onRuntimeName / editRuntimeStat

/// One 生命值 or 幸运值 row of the MP runtime-values card: switch with the value line
/// (已启用 · 玩家可见 · 0 至 N / 未启用), the 编辑 row, and while editing 显示名称 and 上限.
/// Bound to Core `ProjectEditRuntimeStats`; no request, the topic save carries both fields.
@MainActor struct ProjectEditRuntimeStatRow: View {
    @ObservedObject var model: ProjectEditModel
    let stat: ProjectEditRuntimeStats.Stat
    @Binding var editing: String?
    @Binding var refusalKey: String?

    private var isEditing: Bool { editing == stat.rawValue }
    private var enabled: Bool { ProjectEditRuntimeStats.enabled(stat, in: model.draft) }
    private var maximum: Int { ProjectEditRuntimeStats.maximum(stat, in: model.draft) }

    private var label: String {
        let name = ProjectEditRuntimeStats.name(stat, in: model.draft).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? String(localized: String.LocalizationValue(stat.labelKey)) : name
    }

    var body: some View {
        toggle
        editButton
        if isEditing {
            fields
        }
    }

    private var toggle: some View {
        Toggle(isOn: Binding(get: { enabled }, set: { setEnabled($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: label)
                valueLine
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("projectEdit.values.\(stat.rawValue)")
    }

    @ViewBuilder private var valueLine: some View {
        if enabled {
            Text("mpPublish.values.enabled \(maximum)")
        } else {
            Text("mpPublish.values.disabled")
        }
    }

    /// MP 编辑 pill: opens 显示名称 / 上限 under the row; one row is open at a time.
    private var editButton: some View {
        Button {
            editing = isEditing ? nil : stat.rawValue
        } label: {
            LabeledContent {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isEditing ? 90 : 0))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } label: {
                Text("mpPublish.values.edit \(label)")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isEditing ? .isSelected : [])
        .accessibilityIdentifier("projectEdit.values.\(stat.rawValue).edit")
    }

    @ViewBuilder private var fields: some View {
        LabeledContent("mpPublish.values.name") {
            TextField(LocalizedStringKey(stat.labelKey), text: Binding(get: { ProjectEditRuntimeStats.name(stat, in: model.draft) }, set: { setName($0) }))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityIdentifier("projectEdit.values.\(stat.rawValue).name")
        if enabled {
            LabeledContent("mpPublish.values.limit") {
                TextField("mpPublish.values.limit", value: Binding(get: { maximum }, set: { setMaximum($0) }), format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityIdentifier("projectEdit.values.\(stat.rawValue).limit")
        }
    }

    private func setEnabled(_ on: Bool) {
        do {
            model.draft = try ProjectEditRuntimeStats.setEnabled(on, stat, in: model.draft)
            refusalKey = nil
        } catch {
            refusalKey = Self.key(error)
        }
    }

    private func setMaximum(_ value: Int) {
        do {
            let result = try ProjectEditRuntimeStats.setMaximum(value, stat, in: model.draft)
            model.draft = result.draft
            refusalKey = result.warning
        } catch {
            refusalKey = Self.key(error)
        }
    }

    private func setName(_ name: String) {
        do {
            model.draft = try ProjectEditRuntimeStats.setName(name, stat, in: model.draft)
            refusalKey = nil
        } catch {
            refusalKey = Self.key(error)
        }
    }

    private static func key(_ error: Error) -> String {
        if case ProjectEditRuntimeActsError.refused(let key) = error { return key }
        if error is ProjectEditRuntimeValues.Refusal { return ProjectEditRuntimeCustomValueRows.message(error) }
        return ProjectEditThemeRules.Copy.unreadable
    }
}
