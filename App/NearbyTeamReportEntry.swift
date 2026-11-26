import SwiftUI

/// TEAM-REPORT-01 (mini-program subpackageRoam/nearby + my-teams): 「举报队伍」 on the nearby team card,
/// the same `team-report-sheet` as team detail (`TeamReportReasonSheet` → POST /api/team/report).
/// Hidden for the viewer's own team (leader) and when no report access is wired.
@MainActor struct NearbyTeamReportButton: View {
    let teamID: Int
    let leader: Bool
    @Environment(\.teamOrientBoardAccess) private var access
    @Environment(\.locale) private var locale
    @State private var presented = false
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    var body: some View {
        if !leader, teamID > 0, let access, access.enabled {
            Button { presented = true } label: {
                Text(verbatim: c.t("举报队伍", "Report team"))
                    .cyText(.meta).foregroundStyle(CYColor.textTertiary).underline()
                    .frame(minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: c.t("举报这支队伍", "Report this team")))
            .accessibilityIdentifier("nearby.team.report.\(teamID)")
            .cySheet(isPresented: $presented) { TeamReportReasonSheet(teamID: teamID) }
        }
    }
}
