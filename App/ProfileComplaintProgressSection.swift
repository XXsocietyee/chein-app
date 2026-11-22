import SwiftUI

/// Source 我的处理进展: the owner's complaint progress, read-only. Uses the same reader
/// and presentation lifetime as the preparation form; it never submits or edits a case.
/// The enclosing screen owns the controller, its first read and its retirement.
@MainActor struct ProfileComplaintProgressSection: View {
    let model: ProfileComplaintProgressController
    var body: some View {
        Section {
            if let issue = model.issue {
                VStack(alignment: .leading, spacing: 4) {
                    Text("profile.complaintProgress.unavailable").cyText(.bodyMedium)
                        .accessibilityIdentifier("profile.complaintProgress.issue")
                    if case .denied(let message?) = issue { Text(verbatim: message).cyText(.bodyCompact).foregroundStyle(.secondary) }
                    else { Text(LocalizedStringKey(issue.detailKey)).cyText(.bodyCompact).foregroundStyle(.secondary) }
                }
            }
            ForEach(model.rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        if let name = row.topicName { Text(verbatim: name).cyText(.bodyMedium) }
                        else { Text("profile.complaint.unnamed").cyText(.bodyMedium) }
                        Spacer(minLength: 8)
                        if let status = row.statusText { Text(verbatim: status).cyText(.meta) }
                        else { Text("profile.complaintProgress.statusUnknown").cyText(.meta) }
                    }
                    if let reason = row.reason { Text(verbatim: reason).cyText(.bodyCompact) }
                    if let note = row.handleNote {
                        Text("profile.complaintProgress.handleNote \(note)").cyText(.bodyCompact).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("profile.complaintProgress.row.\(row.id)")
            }
        } header: {
            HStack {
                Text("profile.complaintProgress.title")
                Spacer()
                Button("profile.complaintProgress.refresh") { Task { await model.load() } }
                    .disabled(model.isLoading || !model.contextMatches)
                    .accessibilityIdentifier("profile.complaintProgress.refresh")
            }
        }
    }
}
