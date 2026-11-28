import SwiftUI

struct ProjectEditCompletionRulesForm: View {
    @Binding var rules: ProjectEditCompletionRules
    let city: Bool
    let fullEdit: Bool
    let totalNodes: Int
    /// MP `topic-detail-sheet.wxml:217-234` 通关条件 card: city topics switch to 完成 N / 总节点 个节点即通关;
    /// free explore shows the title only (always ALL). The 宾果九宫格 cells moved to `ProjectEditBingoRow`.
    var body: some View {
        Section {
            if rules.readOnly {
                Label("projectEdit.completion.readOnly", systemImage: "lock")
                    .accessibilityIdentifier("projectEdit.completion.readOnly")
            } else if city {
                Picker("projectEdit.completion.mode", selection: $rules.mode) {
                    Text("projectEdit.completion.all").tag("ALL")
                    Text("projectEdit.completion.atLeast").tag("AT_LEAST")
                }.accessibilityIdentifier("projectEdit.completion.mode")
                if rules.mode == "AT_LEAST" {
                    HStack {
                        TextField("projectEdit.completion.count", text: $rules.requiredCount)
                            .keyboardType(.numberPad).accessibilityIdentifier("projectEdit.completion.count")
                        Text(verbatim: "/ \(totalNodes)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            } else {
                LabeledContent("projectEdit.completion.mode") { Text("projectEdit.completion.all") }
            }
            if let key = rules.validationIssue(totalNodes: totalNodes), !ProjectEditCompletionRules.bingoIssueKeys.contains(key) {
                Label(LocalizedStringKey(key), systemImage: "exclamationmark.circle").foregroundStyle(CYColor.dangerText)
            }
        }.disabled(!fullEdit || rules.readOnly)
    }
}

struct ProjectEditCompletionRulesSummary: View {
    let draft: ProjectEditDraft
    private var rules: ProjectEditCompletionRules { (draft.completionRules ?? .init(raw: draft.preserved["completeRuleJson"])).forProduct(draft.product) }
    var body: some View {
        Section("projectEdit.completion.title") {
            if rules.readOnly { Text("projectEdit.completion.readOnly") }
            else {
                Text(LocalizedStringKey(rules.mode == "AT_LEAST" ? "projectEdit.completion.atLeast" : "projectEdit.completion.all"))
                if rules.mode == "AT_LEAST" { Text(verbatim: rules.requiredCount) }
                Text(LocalizedStringKey(rules.bingoEnabled ? "projectEdit.completion.enabled" : "projectEdit.completion.disabled"))
                if rules.bingoEnabled, rules.cells.count == 9 {
                    ForEach(ProjectEditCompletionRules.displayOrder, id: \.self) { position in
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("projectEdit.completion.condition." + String(position)))
                            Text(verbatim: rules.cells[position].label)
                            if !rules.cells[position].couponID.isEmpty {
                                LabeledContent("projectEdit.completion.coupon", value: rules.cells[position].couponID)
                            }
                            Text(verbatim: rules.cells[position].feedbackText)
                        }
                    }
                }
            }
        }
    }
}
