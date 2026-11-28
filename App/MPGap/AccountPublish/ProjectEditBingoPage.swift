import SwiftUI

/// MP `publish/fabu/topic-detail-sheet.wxml:236`: the 宾果九宫格 card is its own row right after 通关条件,
/// with the pill 配置. It opens `runtime-editor.wxml:35-37`: the nine cells in S order (label, or the step
/// number) → tap a cell → 编辑格子 (标题 · 完成反馈 · 奖励). There is no on/off switch: the grid is on
/// while any cell has content (`ProjectEditCompletionRules.setCell`).
struct ProjectEditBingoRow: View {
    @Binding var rules: ProjectEditCompletionRules
    let editable: Bool

    var body: some View {
        if !rules.readOnly, rules.cells.count == 9 {
            Section {
                NavigationLink {
                    ProjectEditBingoPage(rules: $rules, editable: editable)
                } label: {
                    LabeledContent {
                        if rules.configuredCellCount > 0 {
                            Text("mpPublish.bingo.configured \(rules.configuredCellCount)")
                        } else {
                            Text("mpPublish.bingo.configure")
                        }
                    } label: {
                        Label { Text("mpPublish.bingo.title") } icon: { Image(systemName: "square.grid.3x3") }
                    }
                }
                .accessibilityIdentifier("projectEdit.topicDetail.bingo")
            }
        }
    }
}

struct ProjectEditBingoPage: View {
    @Binding var rules: ProjectEditCompletionRules
    let editable: Bool
    @State private var editing: Int?
    @ScaledMetric(relativeTo: .headline) private var cellHeight: CGFloat = 88
    private let columns = Array(repeating: GridItem(.flexible(), spacing: CYSpacing.sm), count: 3)

    private var issue: String? {
        guard let key = rules.issueKey, ProjectEditCompletionRules.bingoIssueKeys.contains(key) else { return nil }
        return key
    }

    var body: some View {
        Form {
            if let issue {
                Section {
                    Label(LocalizedStringKey(issue), systemImage: "exclamationmark.circle")
                        .foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("projectEdit.bingo.issue")
                }
            }
            Section {
                LazyVGrid(columns: columns, spacing: CYSpacing.sm) {
                    ForEach(Array(ProjectEditCompletionRules.displayOrder.enumerated()), id: \.offset) { step, position in
                        Button {
                            editing = position
                        } label: {
                            cell(step: step, position: position)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("projectEdit.bingo.cell.\(position)")
                    }
                }
                .padding(.vertical, CYSpacing.xs)
            } footer: {
                Text("projectEdit.completion.serverConditions")
            }
        }
        .navigationTitle(Text("mpPublish.bingo.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $editing) { position in
            ProjectEditBingoCellPage(cell: cellBinding(position), position: position, editable: editable)
        }
    }

    private func cell(step: Int, position: Int) -> some View {
        let value = rules.cells[position]
        let label = value.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let rewarded = !value.feedbackText.isEmpty || (Int(value.couponID) ?? 0) > 0
        return VStack(spacing: CYSpacing.xs) {
            if label.isEmpty {
                Text(step + 1, format: .number).cyText(.numericTitle)
                    .foregroundStyle(.secondary)
            } else {
                Text(verbatim: label).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
            }
            Text(LocalizedStringKey("projectEdit.completion.condition." + String(position)))
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if rewarded {
                Image(systemName: "gift.fill").font(.caption).foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(CYSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: cellHeight)
        .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("mpPublish.bingo.cellA11y \(step + 1)"))
        .accessibilityValue(Text(verbatim: label))
        .accessibilityHint(rewarded ? Text("mpPublish.bingo.rewarded") : Text(verbatim: ""))
    }

    private func cellBinding(_ position: Int) -> Binding<ProjectEditCompletionRules.Cell> {
        Binding(get: { rules.cells[position] }, set: { value in
            var next = rules
            next.setCell(value, at: position)
            rules = next
        })
    }
}

/// MP `runtime-editor.wxml:37` 编辑格子: 标题 (placeholder 填写标题) → 完成反馈 → 奖励, one card.
struct ProjectEditBingoCellPage: View {
    @Binding var cell: ProjectEditCompletionRules.Cell
    let position: Int
    let editable: Bool
    @Environment(\.rewardCouponSource) private var couponSource
    @State private var couponName = ""

    /// MP `cy-reward-selector` (occasion topic, placeholder 选择奖励) when the session can list the author's coupons.
    @ViewBuilder private var couponField: some View {
        if let couponSource {
            RewardCouponSelectorRow(source: couponSource, couponID: $cell.couponID, couponName: $couponName,
                                    label: "rewardCoupon.label.default", occasion: "rewardCoupon.occasion.topic",
                                    placeholder: "rewardCoupon.placeholder.reward")
                .accessibilityIdentifier("projectEdit.completion.coupon.\(position)")
        } else {
            TextField(text: $cell.couponID, prompt: Text("projectEdit.completion.coupon")) {
                Text("projectEdit.completion.coupon")
            }
            .keyboardType(.numberPad)
            .accessibilityIdentifier("projectEdit.completion.coupon.\(position)")
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("mpPublish.bingo.condition") {
                    Text(LocalizedStringKey("projectEdit.completion.condition." + String(position)))
                }
                TextField(text: $cell.label, prompt: Text("mpPublish.bingo.labelPrompt")) {
                    Text("mpPublish.bingo.label")
                }
                .accessibilityIdentifier("projectEdit.completion.label.\(position)")
                TextField(text: $cell.feedbackText, prompt: Text("mpPublish.bingo.feedback"), axis: .vertical) {
                    Text("mpPublish.bingo.feedback")
                }
                .lineLimit(2...5)
                .accessibilityIdentifier("projectEdit.completion.feedback.\(position)")
                couponField
            } footer: {
                if couponSource == nil {
                    Text("projectEdit.completion.couponHint")
                }
            }
        }
        .disabled(!editable)
        .navigationTitle(Text("mpPublish.bingo.editCell"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
