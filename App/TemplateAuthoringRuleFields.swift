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
    var body: some View {
        Group {
            Text("templateAuthor.field.ruleInstructions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !model.ruleSteps.isEditable {
                VStack(alignment: .leading, spacing: 8) {
                    Text("templateRules.historical").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("templateRules.historical")
                    Text(verbatim: model.ruleSteps.storedText ?? "").textSelection(.enabled)
                        .accessibilityIdentifier("templateRules.original")
                }
            } else {
                let count = model.ruleSteps.rows.count
                ForEach(Array(model.ruleSteps.rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "\(index + 1).circle.fill")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        TextField("templateRules.prompt", text: model.ruleStep(row.id), axis: .vertical)
                            .id(InputIdentity(rowID: row.id, rejectionRevision: model.ruleInputRevisions[row.id]))
                            .lineLimit(1...6)
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
                    }
                    .editorReorderAccessibility(index: index, count: count) { model.ruleStepAction($0, at: index) }
                }
                .onMove { model.moveRuleSteps(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    for index in offsets.sorted(by: >) { model.ruleStepAction(.delete, at: index) }
                }
                .deleteDisabled(!model.ruleSteps.canRemove)
                Button { model.addRuleStep() } label: {
                    HStack {
                        Label("templateRules.add", systemImage: "plus.circle.fill")
                        Spacer()
                        Text(verbatim: "\(count)/\(TemplateAuthoringRuleSteps.maximumRows)").accessibilityLabel(Text("a11y.value.ofTotal \(Int(count)) \(Int(TemplateAuthoringRuleSteps.maximumRows))"))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!model.ruleSteps.canAdd || count >= TemplateAuthoringRuleSteps.maximumRows)
                .accessibilityIdentifier("templateRules.add")
            }
            if let key = model.ruleStepIssue {
                Text(LocalizedStringKey(key)).font(.footnote).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("templateRules.issue")
            }
        }
    }
}
