import SwiftUI

/// U06-01 seat facts (mini `.tm-seats` chips): 持有效票 / 票已失效 / 待审申请 / 还可加入 plus the
/// invitation deadline. Every value is the server's; an unknown row is omitted, never drawn as 0.
struct TeamSeatFactsCard: View {
    let detail: TeamDetail
    @Environment(\.locale) private var locale
    private var rows: [TeamSeatPresentation.Row] { TeamSeatPresentation.rows(detail.seats) }
    private var invite: TeamSeatPresentation.InviteLine? { TeamSeatPresentation.inviteLine(detail.invite) }
    var body: some View {
        if !rows.isEmpty || invite != nil {
            CYCard(padding: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                            Text(LocalizedStringKey(row.labelKey))
                                .cyText(.body)
                                .foregroundStyle(row.warning ? CYColor.dangerText : CYColor.textSecondary)
                            Spacer(minLength: CYSpacing.sm)
                            Text(verbatim: String(row.value))
                                .cyText(.numericBody).monospacedDigit()
                                .foregroundStyle(row.warning ? CYColor.dangerText : CYColor.textPrimary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("teamSeats.row.\(row.id)")
                    }
                    if let invite { inviteLine(invite) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("teamSeats.card")
        }
    }
    @ViewBuilder private func inviteLine(_ line: TeamSeatPresentation.InviteLine) -> some View {
        switch line {
        case .unavailable:
            Label("team.invite.unavailable", systemImage: "clock.badge.xmark")
                .cyText(.meta).foregroundStyle(CYColor.warningText)
                .accessibilityIdentifier("teamSeats.invite")
        case .expires(let raw):
            let chinese = locale.language.languageCode?.identifier == "zh"
            if let text = TeamPagePresentation.startText(raw, chinese: chinese) {
                Label { Text("team.invite.expires \(text)") } icon: { Image(systemName: "clock") }
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("teamSeats.invite")
            }
        }
    }
}

/// U06-01/U06-03: the viewer's own relationship, kept apart from story roles and host permissions.
/// On an invitation page this is the server's join hint; the join button stays and the write decides.
struct TeamViewerRelationshipLine: View {
    let detail: TeamDetail
    let invitation: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if !invitation, let duty = TeamSeatPresentation.dutyKey(detail.viewer, detail: detail) {
                CYStatusChip(LocalizedStringKey(duty), tone: duty == "team.viewer.captain" ? .info : .neutral,
                             systemImage: duty == "team.viewer.captain" ? "crown" : "person")
                    .accessibilityIdentifier("teamViewer.duty")
                Text("team.viewer.dutyScope")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if invitation, let status = TeamSeatPresentation.applicationKey(detail.viewer) {
                Text(LocalizedStringKey(status))
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamViewer.application")
            }
            if invitation, detail.joined != true, let hint = TeamSeatPresentation.blockerKey(detail.viewer, entry: .join) {
                Label(LocalizedStringKey(hint), systemImage: "exclamationmark.circle")
                    .cyText(.meta).foregroundStyle(CYColor.warningText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamViewer.joinHint")
            }
        }
    }
}
