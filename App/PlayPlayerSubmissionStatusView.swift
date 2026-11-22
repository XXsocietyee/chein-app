import SwiftUI

/// Matches the mini-program's inline “本站任务” submission readback. Only a
/// pending record displays its verification number; evidence-only is distinct.
struct PlayPlayerSubmissionStatusView: View {
    let state: PlayPlayerSubmissionState
    var body: some View {
        Group {
            switch state {
            case .none: EmptyView()
            case .unconfirmed:
                Text("playerSubmission.unconfirmed").cyText(.bodyCompact).foregroundStyle(.secondary)
                    .accessibilityIdentifier("playerSubmission.unconfirmed")
            case .record(let record):
                VStack(alignment: .leading, spacing: 8) {
                    CYStatusChip(LocalizedStringKey(record.status.titleKey), tone: tone(record.status), systemImage: symbol(record.status))
                        .accessibilityIdentifier("playerSubmission.status." + record.status.rawValue.lowercased())
                    if record.status == .pending {
                        LabeledContent("playerSubmission.number", value: String(record.submissionID))
                            .cyText(.bodyCompact).accessibilityIdentifier("playerSubmission.number")
                    }
                    if record.status == .rejected, let reason = record.rejectionReason {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("playerSubmission.reason").cyText(.meta)
                            Text(verbatim: reason).cyText(.bodyCompact)
                        }.accessibilityIdentifier("playerSubmission.reason")
                    }
                    if record.status == .recorded {
                        Text("playerSubmission.recordedNotice").cyText(.bodyCompact).foregroundStyle(.secondary)
                    }
                }.fixedSize(horizontal: false, vertical: true)
            }
        }.privacySensitive().accessibilityElement(children: .contain)
            .accessibilityIdentifier("playerSubmission.readback")
    }
    private func tone(_ status: PlayPlayerSubmissionRecord.Status) -> CYStatusTone {
        switch status {
        case .pending: return .warning
        case .approved: return .success
        case .rejected: return .danger
        case .recorded: return .neutral
        }
    }
    private func symbol(_ status: PlayPlayerSubmissionRecord.Status) -> String {
        switch status {
        case .pending: return "clock"
        case .approved: return "checkmark.circle"
        case .rejected: return "exclamationmark.bubble"
        case .recorded: return "doc.text"
        }
    }
}
