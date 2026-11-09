import SwiftUI

/// Step dots from the mini-program activity page (基本信息 · 活动内容 · 票务与合作).
/// The step table in `ActivityPublishingWizard` stays the source; titles are localized keys here.
/// Field errors are shown under their field by the form; this only shows a reason no field owns.
@MainActor struct ActivityPublishingWizardChrome: View {
    let step: Int
    let block: String?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private static let fieldOwned: Set<String> = ["name", "addressName", "startDate", "endDate", "categoryIds",
        "description", "imgUrl", "templateId", "collaborators", "ticket"]
    private static let ticketPrefixes = ["ticketName", "ticketPrice", "ticketStock", "ticketStart", "ticketEnd"]
    private var unownedBlock: String? {
        guard let block, !Self.fieldOwned.contains(block),
              !Self.ticketPrefixes.contains(where: { block.hasPrefix($0) }) else { return nil }
        return block
    }
    var body: some View {
        let current = ActivityPublishingWizard.clamp(step)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(ActivityPublishingWizard.progress(current)) { item in
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(item.state == "todo" ? palette.bgStrong : palette.textPrimary)
                            .frame(height: 4)
                        Text(Self.titleKey(item.key))
                            .font(item.state == "current" ? CYTypography.label : CYTypography.meta)
                            .foregroundStyle(item.state == "todo" ? palette.textTertiary : palette.textPrimary)
                            .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("publishModes.activity.wizard.progress." + item.key)
                    .accessibilityAddTraits(item.state == "current" ? .isSelected : [])
                }
            }
            // Three step columns cannot hold accessibility-size words: cap the labels (the heading below still scales).
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            if let unownedBlock {
                Text(verbatim: ActivityPublishingWizardValidationPresentation(locale: locale).message(for: unownedBlock))
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("publishModes.activity.wizard.validation")
            }
            Text(verbatim: CoreLoopCopy(locale: locale).wizardHeading(for: current))
                .font(CYTypography.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("publishModes.activity.wizard.heading")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("publishModes.activity.wizard.step." + String(current))
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
    var body: some View {
        let current = ActivityPublishingWizard.clamp(step)
        // Pinned bar chrome: one compact row at every size (type capped), the form above keeps scrolling.
        HStack(spacing: CYSpacing.md) { secondary(current); primary(current) }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    @ViewBuilder private func secondary(_ current: Int) -> some View {
        if current == 0 {
            CYPillButton("publishModes.cancel", style: .secondary, fullWidth: false, action: onCancel)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.cancel")
        } else {
            CYPillButton("publishModes.wizard.back", style: .secondary, fullWidth: false, action: onBack)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.back")
        }
    }
    @ViewBuilder private func primary(_ current: Int) -> some View {
        if current < ActivityPublishingWizard.steps.count - 1 {
            CYPillButton("publishModes.wizard.next", action: onNext)
                .disabled(!enabled)
                .accessibilityIdentifier("publishModes.activity.wizard.next")
        } else {
            CYPillButton("publishModes.review", action: onReview)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: summary.heading)
                .font(.headline)
                .accessibilityIdentifier("publishModes.activity.reviewSummary.heading")

            if merchantHost {
                Text(verbatim: copy.merchantFreeTicketOnlyNotice)
                    .font(.caption)
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
        .padding(.vertical, 6)
        .accessibilityIdentifier("publishModes.activity.reviewSummary")
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String, id: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: label).font(.caption).foregroundStyle(.secondary)
                Text(verbatim: value).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("publishModes.activity.reviewSummary.\(id)")
        } else {
            LabeledContent {
                Text(verbatim: value)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Text(verbatim: label)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("publishModes.activity.reviewSummary.\(id)")
        }
    }
}
