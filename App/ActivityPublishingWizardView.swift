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

    /// Design hand-off r1 CF-58 / CF-19 / CF-22: step progress under the nav (a visited step is tappable), one save
    /// status line, and no second primary or large in-content title. Errors stay inline under their fields; the one
    /// primary is the bottom bar's 下一步 / 发布.
    /// The MP step bar has no Apple control: closest is a `ProgressView` plus plain borderless step buttons.
    var body: some View {
        let current = ActivityPublishingWizard.clamp(step)
        let items = ActivityPublishingWizard.progress(current)
        VStack(alignment: .leading, spacing: 10) {
            // Design pass me (P4, R-steps): where the publisher is, as "1 of 3 complete" + ring, titled by the
            // current step; the step buttons below keep the jump-back to a visited step.
            CYStepProgressHeader(Text(Self.titleKey(items[min(current, items.count - 1)].key)),
                                 systemImage: "square.and.pencil", done: current, total: items.count,
                                 identifier: "publishModes.activity.wizard.header")
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button { if index < current { onSelectStep?(index) } } label: {
                        Label {
                            Text(Self.titleKey(item.key))
                                .fontWeight(item.state == "current" ? .semibold : .regular)
                        } icon: {
                            Image(systemName: item.state == "todo" ? "circle" : (item.state == "current" ? "circle.inset.filled" : "checkmark.circle.fill"))
                        }
                        .font(.footnote)
                        .foregroundStyle(item.state == "todo" ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                    }
                    .buttonStyle(.borderless)
                    .disabled(index >= current)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("publishModes.activity.wizard.progress." + item.key)
                    .accessibilityAddTraits(item.state == "current" ? .isSelected : [])
                }
            }
            HStack(spacing: 8) {
                Label { EditorKitText.text(chipState.key) } icon: { Image(systemName: chipState.symbol) }
                    .font(.footnote)
                    .foregroundStyle(chipState.usesErrorColour ? Color.red : Color.secondary)
                    .accessibilityIdentifier("editorKit.saveChip")
                if let chipDetail {
                    chipDetail.font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let onRetry = retryAction {
                    Button(action: onRetry) { EditorKitText.text("editorKit.retry") }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("publishModes.activity.wizard.saveRetry")
                }
            }
            if let unownedBlock {
                Text(verbatim: ActivityPublishingWizardValidationPresentation(locale: locale).message(for: unownedBlock))
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("publishModes.activity.wizard.validation")
            }
        }
        .padding(.vertical, 4)
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
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            secondary(current, fullWidth: dynamicTypeSize.isAccessibilitySize)
            primary(current)
        }
    }
    @ViewBuilder private func secondary(_ current: Int, fullWidth: Bool) -> some View {
        if current == 0 {
            Button(action: onCancel) { Text("publishModes.cancel").frame(maxWidth: fullWidth ? CGFloat.infinity : nil) }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.cancel")
        } else {
            Button(action: onBack) { Text("publishModes.wizard.back").frame(maxWidth: fullWidth ? CGFloat.infinity : nil) }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.back")
        }
    }
    @ViewBuilder private func primary(_ current: Int) -> some View {
        if current < ActivityPublishingWizard.steps.count - 1 {
            Button(action: onNext) { Text("publishModes.wizard.next").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.next")
        } else {
            Button(action: onReview) { Text("publishModes.review").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var summary: ActivityPublishingWizard.ReviewSummary { copy.reviewSummary(rawSummary) }
    init(summary: ActivityPublishingWizard.ReviewSummary, merchantHost: Bool = false) {
        self.rawSummary = summary
        self.merchantHost = merchantHost
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: summary.heading)
                .font(.headline)
                .accessibilityIdentifier("publishModes.activity.reviewSummary.heading")

            if merchantHost {
                Text(verbatim: copy.merchantFreeTicketOnlyNotice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("publishModes.activity.reviewSummary.visibility")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("publishModes.activity.reviewSummary")
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String, id: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: label).font(.footnote).foregroundStyle(.secondary)
                Text(verbatim: value).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("publishModes.activity.reviewSummary.\(id)")
        } else {
            LabeledContent {
                Text(verbatim: value)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Text(verbatim: label)
            }
            .accessibilityIdentifier("publishModes.activity.reviewSummary.\(id)")
        }
    }
}
