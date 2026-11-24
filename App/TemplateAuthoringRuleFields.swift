import SwiftUI

/// Rule steps as list rows (design hand-off r1 CF-33, CF-60, CF-71): numbered rows that reorder by drag
/// (long press), by the trailing "⋯" menu (上移 / 下移 / 删除) or by VoiceOver actions; the handle is
/// trailing; one dashed add row with the `n/12` count at the limit. The numbered handles say the order,
/// so no explainer line is needed.
@MainActor struct TemplateAuthoringRuleFields: View {
    private struct InputIdentity: Hashable {
        let rowID: UUID
        let rejectionRevision: UUID?
    }
    @ObservedObject var model: TemplateAuthoringModel
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Group {
            Text("templateAuthor.field.ruleInstructions")
                .cyText(.label)
                .foregroundStyle(palette.textSecondary)
            if !model.ruleSteps.isEditable {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Text("templateRules.historical").cyText(.meta).foregroundStyle(palette.textSecondary)
                        .accessibilityIdentifier("templateRules.historical")
                    Text(verbatim: model.ruleSteps.storedText ?? "").textSelection(.enabled)
                        .cyText(.bodyCompact)
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("templateRules.original")
                }
            } else {
                let count = model.ruleSteps.rows.count
                ForEach(Array(model.ruleSteps.rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .top, spacing: CYSpacing.sm) {
                        Text(verbatim: String(format: "%02d", index + 1))
                            .cyText(.meta, monospacedDigit: true)
                            .foregroundStyle(palette.actionPrimaryFg)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(palette.actionPrimaryBg))
                            .padding(.top, CYSpacing.s2_5)
                            .accessibilityHidden(true)
                        TextField("templateRules.prompt", text: model.ruleStep(row.id), axis: .vertical)
                            .id(InputIdentity(rowID: row.id, rejectionRevision: model.ruleInputRevisions[row.id]))
                            .lineLimit(1...6)
                            .cyText(.bodyCompact)
                            .padding(CYSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(palette.bgPage))
                            .accessibilityIdentifier("templateRules.input.\(index)")
                            .accessibilityLabel(Text("templateRules.stepNumber \(index + 1)"))
                        EditorRowActionsMenu(
                            index: index, count: count,
                            actions: model.ruleSteps.canRemove ? [.moveUp, .moveDown, .delete] : [.moveUp, .moveDown],
                            deleteTitle: Text("templateRules.removeNumber \(index + 1)"),
                            menuID: "templateRules.menu.\(index)",
                            deleteID: "templateRules.remove.\(index)"
                        ) { action in
                            if action == .delete { model.removeRuleStep(row.id) } else { model.ruleStepAction(action, at: index) }
                        }
                        EditorDragHandle()
                    }
                    .padding(.vertical, CYSpacing.xs)
                    .editorReorderAccessibility(index: index, count: count) { model.ruleStepAction($0, at: index) }
                }
                .onMove { model.moveRuleSteps(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    for index in offsets.sorted(by: >) { model.ruleStepAction(.delete, at: index) }
                }
                .deleteDisabled(!model.ruleSteps.canRemove)
                EditorAddRow(
                    title: Text("templateRules.add"),
                    count: count,
                    limit: TemplateAuthoringRuleSteps.maximumRows,
                    accessibilityID: "templateRules.add"
                ) { model.addRuleStep() }
                .disabled(!model.ruleSteps.canAdd)
            }
            if let key = model.ruleStepIssue {
                Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(palette.danger)
                    .accessibilityIdentifier("templateRules.issue")
            }
        }
    }
}
