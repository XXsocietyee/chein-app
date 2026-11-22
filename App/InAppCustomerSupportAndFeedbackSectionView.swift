import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif

/// Self-contained row describing an in-app customer support or feedback channel's parity readiness.
public struct CustomerSupportChannelRow: Sendable, Equatable, Identifiable {
    public enum ChannelKind: String, CaseIterable, Sendable, Equatable {
        case generalFeedbackSubmission
        case orderAfterSalesDispute
        case ugcReportFollowUp
        case merchantClubSettlementSupport
    }

    public let id: String
    public let channelKind: ChannelKind
    public let title: String
    public let attachesRedactedDiagnosticContext: Bool
    public let supportsOfflineDraftPreservation: Bool
    public let providesTicketReadbackStatus: Bool

    public init(
        id: String? = nil,
        channelKind: ChannelKind,
        title: String,
        attachesRedactedDiagnosticContext: Bool = true,
        supportsOfflineDraftPreservation: Bool = true,
        providesTicketReadbackStatus: Bool = true
    ) {
        self.id = id ?? channelKind.rawValue
        self.channelKind = channelKind
        self.title = title
        self.attachesRedactedDiagnosticContext = attachesRedactedDiagnosticContext
        self.supportsOfflineDraftPreservation = supportsOfflineDraftPreservation
        self.providesTicketReadbackStatus = providesTicketReadbackStatus
    }

    public var isCompliant: Bool {
        attachesRedactedDiagnosticContext
            && supportsOfflineDraftPreservation
            && providesTicketReadbackStatus
    }

    public var statusBadgeText: String {
        isCompliant ? "READY · REDACTED · TRACKED" : "WARNING · CHANNEL NON-COMPLIANT"
    }

    public var detailSummaryText: String {
        "Redacted Diagnostics: \(attachesRedactedDiagnosticContext ? "YES" : "NO") · Offline Draft: \(supportsOfflineDraftPreservation ? "YES" : "NO") · Ticket Readback: \(providesTicketReadbackStatus ? "ACTIVE" : "MISSING")"
    }

    public static let defaultRows: [CustomerSupportChannelRow] = [
        .init(
            id: ChannelKind.generalFeedbackSubmission.rawValue,
            channelKind: .generalFeedbackSubmission,
            title: "In-App Product Feedback & Issue Report",
            attachesRedactedDiagnosticContext: true,
            supportsOfflineDraftPreservation: true,
            providesTicketReadbackStatus: true
        ),
        .init(
            id: ChannelKind.orderAfterSalesDispute.rawValue,
            channelKind: .orderAfterSalesDispute,
            title: "Order & Registration After-Sales Support",
            attachesRedactedDiagnosticContext: true,
            supportsOfflineDraftPreservation: true,
            providesTicketReadbackStatus: true
        ),
        .init(
            id: ChannelKind.ugcReportFollowUp.rawValue,
            channelKind: .ugcReportFollowUp,
            title: "UGC Moderation & Abuse Report Follow-Up",
            attachesRedactedDiagnosticContext: true,
            supportsOfflineDraftPreservation: true,
            providesTicketReadbackStatus: true
        ),
        .init(
            id: ChannelKind.merchantClubSettlementSupport.rawValue,
            channelKind: .merchantClubSettlementSupport,
            title: "Merchant & Club Settlement Concierge Support",
            attachesRedactedDiagnosticContext: true,
            supportsOfflineDraftPreservation: true,
            providesTicketReadbackStatus: true
        ),
    ]
}

/// Self-contained snapshot for in-app customer support, order after-sales, UGC report follow-up,
/// and merchant/club settlement support readiness.
public struct CustomerSupportParitySnapshot: Sendable, Equatable {
    public let rows: [CustomerSupportChannelRow]
    public let slaResponseTargetHours: Int
    public let redactsPIIBeforeAttachmentUpload: Bool

    public init(
        rows: [CustomerSupportChannelRow] = CustomerSupportChannelRow.defaultRows,
        slaResponseTargetHours: Int = 24,
        redactsPIIBeforeAttachmentUpload: Bool = true
    ) {
        self.rows = rows
        self.slaResponseTargetHours = slaResponseTargetHours
        self.redactsPIIBeforeAttachmentUpload = redactsPIIBeforeAttachmentUpload
    }

    public static let defaultReady = CustomerSupportParitySnapshot()

    public var totalCount: Int {
        rows.count
    }

    public var compliantCount: Int {
        rows.filter(\.isCompliant).count
    }

    public var coversAllChannels: Bool {
        Set(rows.map(\.channelKind)) == Set(CustomerSupportChannelRow.ChannelKind.allCases)
    }

    public var isAllCompliant: Bool {
        coversAllChannels
            && redactsPIIBeforeAttachmentUpload
            && slaResponseTargetHours > 0
            && slaResponseTargetHours <= 24
            && compliantCount == totalCount
            && totalCount > 0
    }

    public var overallStatusBadgeText: String {
        isAllCompliant ? "READY · 4/4 SUPPORT CHANNELS" : "WARNING · SUPPORT CHANNEL DRIFT"
    }

    public var headerSummaryText: String {
        "Channels: \(compliantCount)/\(totalCount) · SLA Target: <= \(slaResponseTargetHours)h · PII Redaction: \(redactsPIIBeforeAttachmentUpload ? "ENFORCED" : "DISABLED")"
    }
}

/// SwiftUI diagnostics section displaying feedback, order after-sales, UGC report follow-up,
/// and merchant/club settlement support readiness.
@MainActor
public struct InAppCustomerSupportAndFeedbackSectionView: View {
    public let snapshot: CustomerSupportParitySnapshot

    public init(snapshot: CustomerSupportParitySnapshot = .defaultReady) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: "In-App Customer Support & Feedback")
                    .cyText(.cardTitle)
                    .accessibilityIdentifier("customerSupportFeedback.headerTitle")
                Spacer()
                Text(verbatim: snapshot.overallStatusBadgeText)
                    .cyText(.meta, weight: .semibold)
                    .foregroundStyle(snapshot.isAllCompliant ? CYColor.successText : CYColor.warningText)
                    .accessibilityIdentifier("customerSupportFeedback.statusBadge")
            }

            Text(verbatim: snapshot.headerSummaryText)
                .cyText(.meta)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("customerSupportFeedback.summaryLine")

            if !snapshot.isAllCompliant {
                Text(verbatim: "Warning: One or more support channels lack redacted diagnostic context, offline draft preservation, or ticket readback.")
                    .cyText(.caption, weight: .medium)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityIdentifier("customerSupportFeedback.warningBanner")
            }

            ForEach(snapshot.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verbatim: row.title)
                            .cyText(.bodyMedium)
                        Spacer()
                        Text(verbatim: row.statusBadgeText)
                            .cyText(.caption, weight: .semibold)
                            .foregroundStyle(row.isCompliant ? CYColor.successText : CYColor.warningText)
                    }
                    Text(verbatim: row.detailSummaryText)
                        .cyText(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityIdentifier("customerSupportFeedback.row.\(row.id)")
            }
        }
        .padding(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("customerSupportFeedback.section")
    }
}
