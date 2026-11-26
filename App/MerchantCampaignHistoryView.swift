import SwiftUI

// MC7-12-2..MC7-12-9 (pages/merchant/crm-campaigns, BL-100): 触达记录 as its own pushed, read-only page.
// - Rows: title, "time · channel · status", 送达 N / M 人 (view-model.js shapeCampaign); footer 仅显示最近 20 条.
// - Pull to refresh keeps the list; a failed refresh only toasts 刷新失败，稍后再试.
// - Row tap opens a sheet titled with the campaign: its own loading / 触达明细加载失败 + 重新加载 states, exactly five
//   counts (名单人数 · 已送达 · 未同意 · 频次受限 · 未送达 = failed + retryable), and 这次触达没有逐人结果 when empty.
// Uses the engagement model's existing `.campaigns` / `.campaign(id)` reads; nothing here creates, dispatches or retries.

enum MerchantCampaignHistoryCopy {
    static func statusKey(_ raw: String?) -> String {
        switch raw?.uppercased() {
        case "READY": return "merchant.campaigns.status.ready"
        case "PROCESSING", "SENDING": return "merchant.campaigns.status.processing"
        case "SUCCESS": return "merchant.campaigns.status.success"
        case "PARTIAL_FAILED": return "merchant.campaigns.status.partialFailed"
        case "NO_ELIGIBLE": return "merchant.campaigns.status.noEligible"
        default: return "merchant.campaigns.status.other"
        }
    }
    static func statusTone(_ raw: String?) -> CYStatusTone {
        switch raw?.uppercased() {
        case "SUCCESS": return .success
        case "PARTIAL_FAILED": return .warning
        default: return .neutral
        }
    }
    static func recipientStatusKey(_ raw: String?) -> String {
        switch raw?.uppercased() {
        case "PENDING": return "merchant.campaigns.recipient.pending"
        case "DELIVERED": return "merchant.campaigns.recipient.delivered"
        case "SKIPPED_NO_CONSENT": return "merchant.campaigns.recipient.noConsent"
        case "SKIPPED_FREQUENCY": return "merchant.campaigns.recipient.frequency"
        case "RETRYABLE_BUSY": return "merchant.campaigns.recipient.retryable"
        case "FAILED": return "merchant.campaigns.recipient.failed"
        default: return "merchant.campaigns.status.other"
        }
    }
    static func recipientTone(_ raw: String?) -> CYStatusTone {
        switch raw?.uppercased() {
        case "DELIVERED": return .success
        case "RETRYABLE_BUSY", "FAILED": return .warning
        default: return .neutral
        }
    }
    static func channelKey(_ channel: MerchantCampaignChannel?) -> String? {
        switch channel {
        case .inApp: return "merchant.campaigns.channel.inApp"
        case .coupon: return "merchant.campaigns.channel.coupon"
        case nil: return nil
        }
    }
    /// "yyyy-MM-dd HH:mm" from the server text (MP formatTime keeps the first 16 characters).
    static func time(_ fields: MerchantBusinessObject, _ key: String) -> String? {
        guard let raw = fields.mbText(key), raw.count >= 16 else { return nil }
        return String(raw.prefix(16))
    }
}

struct MerchantCampaignHistoryView: View {
    @ObservedObject var model: MerchantEngagementViewModel
    @State private var selected: MerchantCampaignTask?
    @State private var toastMessage: String?
    @Environment(\.locale) private var locale

    var body: some View {
        content
            .navigationTitle(Text("merchant.campaigns.title"))
            .navigationBarTitleDisplayMode(.inline)
            .cyDomainScreen(.merchant)
            .cyToast(verbatimMessage: $toastMessage)
            .cySheet(item: $selected) { task in
                MerchantCampaignDetailSheet(model: model, task: task)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder private var content: some View {
        if model.campaigns.isEmpty && model.loading {
            List { ForEach(0..<4, id: \.self) { _ in CYSkeleton(variant: .row) } }
                .accessibilityIdentifier("merchant.campaigns.loading")
        } else if model.campaigns.isEmpty, let issue = model.issue {
            if issue == MerchantBusinessFailure.denied.key {
                MerchantDeniedState(title: "merchant.campaigns.denied", identifier: "merchant.campaigns.denied")
            } else {
                MerchantLoadFailedState(title: "merchant.campaigns.loadFailed",
                                        message: appLocalized(String.LocalizationValue(issue), locale: locale),
                                        identifier: "merchant.campaigns.failed") { Task { await model.load() } }
            }
        } else if model.campaigns.isEmpty, let access = model.access,
                  !(access.identity.map { $0.allows("merchant:marketing:read") || $0.allows("merchant:marketing:write") } ?? false) {
            // MC8-12-1 (crm-campaigns/index.js:45-66): a grant without marketing read is 当前身份不能查看触达记录,
            // not an empty history.
            MerchantDeniedState(title: "merchant.campaigns.denied", identifier: "merchant.campaigns.denied")
        } else if model.campaigns.isEmpty {
            CYEmptyState(systemImage: "tray", "merchant.campaigns.empty")
                .accessibilityIdentifier("merchant.campaigns.empty")
        } else {
            List {
                Section {
                    ForEach(model.campaigns) { task in
                        Button { selected = task } label: { row(task) }
                            .tint(CYColor.textPrimary)
                            .accessibilityIdentifier("merchant.campaigns.row.\(task.id)")
                    }
                } footer: {
                    Text("merchant.campaigns.recentOnly").accessibilityIdentifier("merchant.campaigns.recentOnly")
                }
            }
            .refreshable {
                await model.load()
                if model.issue != nil {
                    toastMessage = appLocalized("merchant.campaigns.refreshFailed", locale: locale)
                }
            }
        }
    }

    private func row(_ task: MerchantCampaignTask) -> some View {
        let delivered = task.counts["deliveredCount"] ?? 0
        let total = task.counts["recipientCount"] ?? 0
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: task.title.flatMap { $0.isEmpty ? nil : $0 } ?? appLocalized("merchant.campaigns.untitled", locale: locale))
                .cyText(.bodyMedium)
                .foregroundStyle(CYColor.textPrimary)
            HStack(spacing: CYSpacing.xs) {
                if let time = MerchantCampaignHistoryCopy.time(task.source, "createTime") {
                    Text(verbatim: time).monospacedDigit()
                }
                if let channel = MerchantCampaignHistoryCopy.channelKey(task.channel) {
                    Text(LocalizedStringKey(channel))
                }
                CYStatusChip(LocalizedStringKey(MerchantCampaignHistoryCopy.statusKey(task.status)),
                             tone: MerchantCampaignHistoryCopy.statusTone(task.status))
            }
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            Text("merchant.campaigns.summary \(delivered) \(total)")
                .cyText(.meta)
                .foregroundStyle(CYColor.textTertiary)
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct MerchantCampaignDetailSheet: View {
    @ObservedObject var model: MerchantEngagementViewModel
    let task: MerchantCampaignTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var phase: Phase = .loading
    private enum Phase: Equatable { case loading, failed(String), ready }

    private var detail: MerchantCampaignTask? { model.detail?.id == task.id ? model.detail : nil }

    var body: some View {
        NavigationStack {
            List {
                switch phase {
                case .loading:
                    ForEach(0..<3, id: \.self) { _ in CYSkeleton(variant: .row) }
                case .failed(let key):
                    MerchantLoadFailedState(title: "merchant.campaigns.detailFailed",
                                            message: appLocalized(String.LocalizationValue(key), locale: locale),
                                            identifier: "merchant.campaigns.detailFailed") { Task { await load() } }
                        .listRowBackground(Color.clear)
                case .ready:
                    if let detail {
                        Section {
                            count("merchant.campaigns.count.recipients", detail.counts["recipientCount"] ?? 0)
                            count("merchant.campaigns.count.delivered", detail.counts["deliveredCount"] ?? 0)
                            count("merchant.campaigns.count.noConsent", detail.counts["noConsentCount"] ?? 0)
                            count("merchant.campaigns.count.frequency", detail.counts["frequencySkippedCount"] ?? 0)
                            count("merchant.campaigns.count.undelivered", (detail.counts["failedCount"] ?? 0) + (detail.counts["retryableCount"] ?? 0))
                        }
                        Section {
                            if detail.recipients.isEmpty {
                                Text("merchant.campaigns.noRecipients")
                                    .foregroundStyle(CYColor.textSecondary)
                                    .accessibilityIdentifier("merchant.campaigns.noRecipients")
                            }
                            ForEach(detail.recipients) { recipient in
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    Text(verbatim: recipient.source.mbText("customerName") ?? "—")
                                        .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                                    HStack(spacing: CYSpacing.xs) {
                                        if let time = MerchantCampaignHistoryCopy.time(recipient.source, "updateTime") {
                                            Text(verbatim: time).monospacedDigit()
                                        }
                                        CYStatusChip(LocalizedStringKey(MerchantCampaignHistoryCopy.recipientStatusKey(recipient.source.mbText("status"))),
                                                     tone: MerchantCampaignHistoryCopy.recipientTone(recipient.source.mbText("status")))
                                    }
                                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    if let reason = recipient.source.mbText("failureMessage") {
                                        Text(verbatim: reason).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: (detail ?? task).title.flatMap { $0.isEmpty ? nil : $0 }
                                  ?? appLocalized("merchant.campaigns.detailTitle", locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("merchant.done") { dismiss() } }
            }
        }
        .task { await load() }
    }

    private func count(_ key: LocalizedStringKey, _ value: Int) -> some View {
        LabeledContent(key) { Text(value, format: .number).monospacedDigit() }
    }

    private func load() async {
        phase = .loading
        let before = model.issue
        await model.loadTask(task.id)
        if detail != nil { phase = .ready }
        else if let issue = model.issue, issue != before || before != nil { phase = .failed(issue) }
        else if !Task.isCancelled { phase = .failed("merchant.business.loadFailed") }
    }
}

/// Standalone host (workbench 更多 › 触达记录): owns its engagement model and reads on appear.
struct MerchantCampaignHistoryHost: View {
    @StateObject private var model: MerchantEngagementViewModel
    init(reader: any MerchantEngagementReading, journal: any MerchantBusinessIntentStore, exports: any MerchantExportRecoveryStoring) {
        _model = StateObject(wrappedValue: MerchantEngagementViewModel(reader: reader, journal: journal, exports: exports))
    }
    var body: some View {
        MerchantCampaignHistoryView(model: model)
            .task { await model.load() }
    }
}
