import SwiftUI

/// Builds missing-item diagnostics for `CYPublishStatusBar` directly from `ActivityPublishingWizard.blockingField`.
enum ActivityPublishingStatusHelper {
    static func issues(for draft: ActivityPublishDraft, locale: Locale) -> [CYPublishValidationIssue] {
        let copy = ActivityPublishingWizardValidationPresentation(locale: locale)
        return (0..<ActivityPublishingWizard.steps.count).compactMap { stepIndex in
            guard let field = ActivityPublishingWizard.blockingField(stepIndex, draft) else { return nil }
            return CYPublishValidationIssue(
                id: "step-\(stepIndex)-\(field)",
                stepIndex: stepIndex,
                message: copy.message(for: field)
            )
        }
    }
}

/// Template 10/11/12 Merchant Light header combining `CYPublishStatusBar` (what is configured, what is missing,
/// whether it is saved, jump-to-step) with step dots from `pages/publish/activity`.
@MainActor struct ActivityPublishingWizardChrome: View {
    let step: Int
    let block: String?
    var issues: [CYPublishValidationIssue] = []
    var saveState: CYPublishSaveState = .unsavedChanges
    var isSubmittingReview: Bool = false
    var onSelectStep: ((Int) -> Void)? = nil
    var onSubmitReview: (() -> Void)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private static let fieldOwned: Set<String> = ["name", "addressName", "startDate", "endDate", "categoryIds",
        "description", "imgUrl", "templateId", "collaborators", "ticket"]
    private static let ticketPrefixes = ["ticketName", "ticketPrice", "ticketStock", "ticketStart", "ticketEnd"]
    private var unownedBlock: String? {
        guard let block, !Self.fieldOwned.contains(block),
              !Self.ticketPrefixes.contains(where: { block.hasPrefix($0) }) else { return nil }
        return block
    }
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    /// Design hand-off r1 CF-58 / CF-19 / CF-22: a three-segment step bar under the nav (a visited segment is
    /// tappable), one save chip, and no second primary or large in-content title. Errors stay inline under
    /// their fields; the one primary is the bottom bar's 下一步 / 发布.
    var body: some View {
        let current = ActivityPublishingWizard.clamp(step)
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(spacing: CYSpacing.sm) {
                ForEach(Array(ActivityPublishingWizard.progress(current).enumerated()), id: \.element.id) { index, item in
                    Button { if index < current { onSelectStep?(index) } } label: {
                        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center, spacing: 6) {
                            Capsule()
                                .fill(item.state == "todo" ? palette.bgStrong : palette.textPrimary)
                                .frame(height: 4)
                            Text(Self.titleKey(item.key))
                                .cyText(item.state == "current" ? .label : .meta)
                                .foregroundStyle(item.state == "todo" ? palette.textSecondary : palette.textPrimary)
                                .cyWrapText(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                        }
                        .frame(maxWidth: .infinity, minHeight: EditorKitMetric.hit, alignment: .top)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= current)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("publishModes.activity.wizard.progress." + item.key)
                    .accessibilityAddTraits(item.state == "current" ? .isSelected : [])
                }
            }
            HStack(spacing: CYSpacing.sm) {
                EditorSaveChip(state: chipState, detail: chipDetail)
                if let onRetry = retryAction {
                    Button(action: onRetry) { EditorKitText.text("editorKit.retry") }
                        .buttonStyle(.editorSecondary)
                        .accessibilityIdentifier("publishModes.activity.wizard.saveRetry")
                }
                Spacer(minLength: 0)
            }
            if let unownedBlock {
                Text(verbatim: ActivityPublishingWizardValidationPresentation(locale: locale).message(for: unownedBlock))
                    .cyText(.meta)
                    .foregroundStyle(palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("publishModes.activity.wizard.validation")
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityIdentifier("publishModes.activity.wizard.step." + String(current))
    }
    private var chipState: EditorSaveState {
        switch saveState {
        case .savedDraft: return .saved
        case .unsavedChanges: return .unsaved
        case .saveFailed: return .failed
        }
    }
    private var retryAction: (() -> Void)? {
        if case .saveFailed(_, let onRetry) = saveState { return onRetry }
        return nil
    }
    private var chipDetail: Text? {
        switch saveState {
        case .savedDraft(let updatedAt): return Text(verbatim: updatedAt)
        case .unsavedChanges: return nil
        case .saveFailed(let reason, _): return Text(verbatim: reason)
        }
    }
    @ViewBuilder private func wizardSteps(_ current: Int) -> some View {
        ForEach(ActivityPublishingWizard.progress(current)) { item in
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center, spacing: 6) {
                Capsule()
                    .fill(item.state == "todo" ? palette.bgStrong : palette.textPrimary)
                    .frame(height: 4)
                Text(Self.titleKey(item.key))
                    .cyText(item.state == "current" ? .label : .meta)
                    .foregroundStyle(item.state == "todo" ? palette.textTertiary : palette.textPrimary)
                    .cyWrapText(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            }
            .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("publishModes.activity.wizard.progress." + item.key)
            .accessibilityAddTraits(item.state == "current" ? .isSelected : [])
        }
    }
    private static func titleKey(_ key: String) -> LocalizedStringKey {
        switch key {
        case "basic": return "publishModes.wizard.step.basic"
        case "content": return "publishModes.wizard.step.content"
        case "ticket": return "publishModes.wizard.step.ticket"
        default: return LocalizedStringKey(key)
        }
    }
}

/// Mini-program bottom bar: Cancel (step 0) or Back on the left, Next or Review as the one primary action.
/// The last step opens the existing review, not a second publish.
@MainActor struct ActivityPublishingWizardNavigation: View {
    let step: Int
    let enabled: Bool
    let onCancel: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onReview: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let current = ActivityPublishingWizard.clamp(step)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(spacing: CYSpacing.md))
        layout {
            secondary(current, fullWidth: dynamicTypeSize.isAccessibilitySize)
            primary(current)
        }
    }
    @ViewBuilder private func secondary(_ current: Int, fullWidth: Bool) -> some View {
        if current == 0 {
            CYPillButton("publishModes.cancel", style: .secondary, fullWidth: fullWidth, compact: true, action: onCancel)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.cancel")
        } else {
            CYPillButton("publishModes.wizard.back", style: .secondary, fullWidth: fullWidth, compact: true, action: onBack)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.back")
        }
    }
    @ViewBuilder private func primary(_ current: Int) -> some View {
        if current < ActivityPublishingWizard.steps.count - 1 {
            CYPillButton("publishModes.wizard.next", compact: true, action: onNext)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.next")
        } else {
            CYPillButton("publishModes.review", compact: true, action: onReview)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.review")
        }
    }
}

/// Step 2 pre-publish / edit review summary card matching `pages/publish/activity/index.wxml` (`发布前摘要` / `修改摘要`).
@MainActor struct ActivityPublishingReviewSummaryCard: View {
    let rawSummary: ActivityPublishingWizard.ReviewSummary
    var merchantHost: Bool = false
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var summary: ActivityPublishingWizard.ReviewSummary { copy.reviewSummary(rawSummary) }
    init(summary: ActivityPublishingWizard.ReviewSummary, merchantHost: Bool = false) {
        self.rawSummary = summary
        self.merchantHost = merchantHost
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: summary.heading)
                .cyText(.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityIdentifier("publishModes.activity.reviewSummary.heading")

            if merchantHost {
                Text(verbatim: copy.merchantFreeTicketOnlyNotice)
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier("publishModes.activity.reviewSummary.merchantFreeNotice")
            }

            summaryRow(label: copy.t("名称", "Name"), value: summary.nameText, id: "name")
            summaryRow(label: copy.t("时间", "Time"), value: summary.timeText, id: "time")
            summaryRow(label: copy.t("地点", "Place"), value: summary.addressText, id: "address")
            summaryRow(label: copy.t("关联模板", "Linked template"), value: summary.templateText, id: "template")
            if let ticketText = summary.ticketSummaryText {
                summaryRow(label: copy.t("票种", "Tickets"), value: ticketText, id: "tickets")
            }

            Text(verbatim: summary.visibilityNotice)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("publishModes.activity.reviewSummary.visibility")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
        .accessibilityIdentifier("publishModes.activity.reviewSummary")
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String, id: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: label).cyText(.meta).foregroundStyle(palette.textSecondary)
                Text(verbatim: value).cyText(.bodyCompact).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("publishModes.activity.reviewSummary.\(id)")
        } else {
            LabeledContent {
                Text(verbatim: value)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Text(verbatim: label)
                    .foregroundStyle(palette.textSecondary)
            }
            .accessibilityIdentifier("publishModes.activity.reviewSummary.\(id)")
        }
    }
}
