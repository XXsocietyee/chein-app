import SwiftUI

@MainActor struct TemplateAuthoringRuleFields: View {
    private struct InputIdentity: Hashable {
        let rowID: UUID
        let rejectionRevision: UUID?
    }
    @ObservedObject var model: TemplateAuthoringModel
    @Environment(\.cyPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("templateAuthor.field.ruleInstructions")
                .font(CYTypography.label)
                .foregroundStyle(palette.textSecondary)
            if !model.ruleSteps.isEditable {
                Text("templateRules.historical").font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("templateRules.historical")
                Text(verbatim: model.ruleSteps.storedText ?? "").textSelection(.enabled)
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityIdentifier("templateRules.original")
            } else {
                ForEach(Array(model.ruleSteps.rows.enumerated()), id: \.element.id) { index, row in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack {
                            Text(verbatim: String(format: "%02d", index + 1))
                                .font(CYTypography.micro.weight(.semibold).monospacedDigit())
                                .foregroundStyle(palette.actionPrimaryFg)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(palette.actionPrimaryBg))
                                .accessibilityHidden(true)
                            Text("templateRules.step")
                                .font(CYTypography.label)
                                .foregroundStyle(palette.textPrimary)
                            Text(verbatim: String(index + 1))
                                .font(CYTypography.label.monospacedDigit())
                                .foregroundStyle(palette.textPrimary)
                            Spacer()
                            if model.ruleSteps.canRemove {
                                Button("templateRules.remove", role: .destructive) { model.removeRuleStep(row.id) }
                                    .buttonStyle(.borderless)
                                    .font(CYTypography.meta)
                                    .accessibilityIdentifier("templateRules.remove.\(index)")
                                    .accessibilityLabel(Text("templateRules.removeNumber \(index + 1)"))
                            }
                        }
                        TextField("templateRules.prompt", text: model.ruleStep(row.id), axis: .vertical)
                            .id(InputIdentity(rowID: row.id, rejectionRevision: model.ruleInputRevisions[row.id]))
                            .lineLimit(1...6)
                            .font(CYTypography.bodyCompact)
                            .padding(CYSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(palette.bgPage))
                            .accessibilityIdentifier("templateRules.input.\(index)")
                            .accessibilityLabel(Text("templateRules.stepNumber \(index + 1)"))
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
                Button {
                    model.addRuleStep()
                } label: {
                    Label("templateRules.add", systemImage: "plus.circle.fill")
                }
                    .disabled(!model.ruleSteps.canAdd).accessibilityIdentifier("templateRules.add")
            }
            if let key = model.ruleStepIssue {
                Text(LocalizedStringKey(key)).font(CYTypography.meta).foregroundStyle(palette.danger)
                    .accessibilityIdentifier("templateRules.issue")
            }
        }.padding(.vertical, 3)
    }
}
