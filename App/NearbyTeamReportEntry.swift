import SwiftUI

/// TEAM-REPORT-01 (mini-program subpackageRoam/nearby + my-teams): 「举报队伍」 on the nearby team card,
/// the same report as team detail (`team-report-sheet` → POST /api/team/report via `TeamReportSubmission`).
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
                    .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).underline()
                    .frame(minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: c.t("举报这支队伍", "Report this team")))
            .accessibilityIdentifier("nearby.team.report.\(teamID)")
            .sheet(isPresented: $presented) { NearbyTeamReportSheet(teamID: teamID) }
        }
    }
}

/// Same copy, limits and honest states as the team-detail report sheet (`TeamOrientBoardSection`).
@MainActor struct NearbyTeamReportSheet: View {
    let teamID: Int
    @Environment(\.teamOrientBoardAccess) private var access
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var state: TeamReportState = .idle
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    private var trimmed: String { TeamReportRules.trimmedReason(reason) }

    var body: some View {
        NavigationStack {
            Form {
                CYHeroHeader(verbatim: c.t("举报队伍", "Report team"))
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                switch state {
                case .submitted:
                    Section {
                        CYStatusChip(verbatim: c.t("举报已记录，平台将核查处理", "Report recorded. Platform support will review it."),
                                     tone: .success, systemImage: "checkmark.circle.fill")
                            .accessibilityIdentifier("nearby.team.reportSuccess")
                    }
                case .unavailable:
                    Section {
                        CYStatusChip(verbatim: c.t("举报功能暂不可用，请稍后再试", "Reporting is currently unavailable. Please try again later."),
                                     tone: .warning, systemImage: "exclamationmark.triangle")
                            .accessibilityIdentifier("nearby.team.reportUnavailable")
                    }
                default:
                    Section {
                        TextField(c.t("请描述该队伍的违规情况", "Describe the issue with this team"), text: $reason, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("nearby.team.reportReason")
                    } header: { Text(verbatim: c.t("举报原因", "Reason for report")) } footer: {
                        Text(verbatim: "\(trimmed.count)/\(TeamReportRules.reasonLimit)").monospacedDigit()
                    }
                    if case .failed = state {
                        Section {
                            Text(verbatim: c.t("举报未能提交，请检查网络后重试", "Your report could not be submitted. Check your connection and try again."))
                                .font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
                                .accessibilityIdentifier("nearby.team.reportError")
                        }
                    }
                    Section {
                        CYPillButton(verbatim: state == .submitting ? c.t("提交中…", "Submitting…") : c.t("提交举报", "Submit report")) {
                            Task { state = .submitting; state = await TeamReportSubmission.run(access: access, teamID: teamID, reason: reason) }
                        }
                        .disabled(state == .submitting || trimmed.isEmpty || trimmed.count > TeamReportRules.reasonLimit)
                        .accessibilityIdentifier("nearby.team.reportSubmit")
                    }
                }
            }
            .cyHeroScreen()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(c.t("关闭", "Close")) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(state == .submitting)
    }
}
