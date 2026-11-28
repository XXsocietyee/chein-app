import SwiftUI

/// Mini-program pages/club/notify audience rows: label + `N 人`; a null count is an em dash (ClubNotifyPage.unknownDisplay), never 0.
struct ClubOpsNotifyAudienceRows: View {
    let rows: [ClubOpsNotifyAudienceRow]
    var body: some View {
        ForEach(rows) { row in
            HStack {
                Text(LocalizedStringKey("club.gov.choice." + row.id))
                Spacer()
                if let count = row.count { ClubOpsJoinNotifyCopy.people(count).monospacedDigit().foregroundStyle(.secondary) }
                else { Text(verbatim: ClubNotifyPage.unknownDisplay).foregroundStyle(.secondary) }
            }.accessibilityIdentifier("clubOpsJN.notify.audience." + row.id)
        }
    }
}

/// Title (1–80) and content (1–1000) with the mini-program labels and placeholders, one Form row per field.
/// The command validation is unchanged; the first issue the page would toast shows as red footnote text.
struct ClubOpsNotifyContentFields: View {
    @Binding var title: String
    @Binding var content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            label("clubOpsJN.notify.field.title")
            TextField(text: $title) { Text("clubOpsJN.notify.placeholder.title", tableName: "ClubOpsJoinNotify") }
                .submitLabel(.next)
                .accessibilityIdentifier("club.gov.input.title")
        }
        VStack(alignment: .leading, spacing: 4) {
            label("clubOpsJN.notify.field.content")
            TextField(text: $content, axis: .vertical) { Text("clubOpsJN.notify.placeholder.content", tableName: "ClubOpsJoinNotify") }
                .lineLimit(3...8)
                .accessibilityIdentifier("club.gov.input.content")
        }
        if !(title.isEmpty && content.isEmpty), let issue = ClubOpsNotifyPresentation.draftIssue(title: title, content: content) {
            ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.issue." + issue.rawValue).font(.footnote).foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("clubOpsJN.notify.issue")
        }
    }
    private func label(_ key: String) -> some View {
        HStack(spacing: 2) {
            ClubOpsJoinNotifyCopy.text(key)
            Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

/// Reviewed preview: `N 人`, or the empty-group note (send stays blocked by existing validation).
struct ClubOpsNotifyPreviewSummary: View {
    let value: ClubGovernanceValue
    var body: some View {
        let recipient = ClubNotifyPage.previewRecipient(value)
        if let count = recipient.literal {
            LabeledContent { ClubOpsJoinNotifyCopy.people(count).monospacedDigit() } label: { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.preview.title") }
                .accessibilityIdentifier("clubOpsJN.notify.preview")
            if count == 0 { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.preview.empty").font(.subheadline).foregroundStyle(.secondary) }
        } else {
            LabeledContent { Text(verbatim: recipient.displayText).monospacedDigit() } label: { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.preview.title") }
                .accessibilityIdentifier("clubOpsJN.notify.preview")
        }
    }
}

/// CU-C-135 delivery card: status, total, delivered, pending (derived) and failed.
struct ClubOpsNotifyCampaignRows: View {
    let campaign: ClubOpsNotifyCampaign
    /// Send/retry outcome line in place of the mini-program toast; nil for a plain status read.
    var outcome: ClubGovernanceMutation? = nil
    /// Page projection. A nil count is an em dash. The older campaign still treats null as 0.
    var delivery: ClubNotifyDeliveryPage? = nil
    var body: some View {
        if let key = outcomeKey { ClubOpsJoinNotifyCopy.text(key).font(.headline).accessibilityIdentifier("clubOpsJN.notify.outcome") }
        LabeledContent { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.phase." + campaign.phase.rawValue) } label: { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.status.label") }
            .accessibilityIdentifier("clubOpsJN.notify.phase")
        row("clubOpsJN.notify.total", campaign.totalCount, projected: delivery?.total)
        row("clubOpsJN.notify.success", campaign.successCount, projected: delivery?.success, tint: .green)
        LabeledContent {
            if let pending = delivery?.pending, pending.literal == nil {
                Text(verbatim: pending.displayText).monospacedDigit()
            } else {
                Text(delivery?.pending?.literal ?? campaign.pendingCount, format: .number).monospacedDigit()
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.pending")
                if campaign.processing { ClubOpsJoinNotifyCopy.text("clubOpsJN.notify.processing").font(.footnote).foregroundStyle(.secondary) }
            }
        }.accessibilityIdentifier("clubOpsJN.notify.pending")
        row("clubOpsJN.notify.failed", campaign.failedCount, projected: delivery?.failed, tint: .red)
    }
    private var outcomeKey: String? {
        switch outcome {
        case .sendNotification?:
            switch campaign.phase {
            case .completed: return "clubOpsJN.notify.sent.completed"
            case .partialFailed: return "clubOpsJN.notify.sent.partialFailed"
            case .delivering: return "clubOpsJN.notify.sent.delivering"
            }
        case .retryNotification?: return campaign.failedCount > 0 ? "clubOpsJN.notify.retried.stillFailed" : "clubOpsJN.notify.retried.done"
        default: return nil
        }
    }
    @ViewBuilder private func row(_ key: String, _ value: Int, projected: ClubNotifyCount? = nil, tint: Color = .primary) -> some View {
        LabeledContent {
            if let projected, projected.literal == nil {
                Text(verbatim: projected.displayText).monospacedDigit().foregroundStyle(tint)
            } else {
                Text(projected?.literal ?? value, format: .number).monospacedDigit().foregroundStyle(tint)
            }
        } label: { ClubOpsJoinNotifyCopy.text(key) }
            .accessibilityIdentifier(key)
    }
}
