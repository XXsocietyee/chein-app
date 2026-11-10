import SwiftUI

private struct TeamOrientBoardAccessKey: EnvironmentKey {
    static let defaultValue: (any TeamOrientBoardAccess)? = nil
}

extension EnvironmentValues {
    var teamOrientBoardAccess: (any TeamOrientBoardAccess)? {
        get { self[TeamOrientBoardAccessKey.self] }
        set { self[TeamOrientBoardAccessKey.self] = newValue }
    }
}

/// Orienteering team progress board (`/api/orient/team/detail`) and session ranking (`/api/orient/team/ranking`)
/// plus non-leader report entry from `pages/team/detail/index.{js,wxml}`.
@MainActor struct TeamOrientBoardSection: View {
    let detail: TeamDetail
    @Environment(\.teamOrientBoardAccess) private var access
    @Environment(\.locale) private var locale
    @State private var board: TeamOrientBoardDetail?
    @State private var ranking: [TeamOrientRankingRow] = []
    @State private var loading = false
    @State private var loadError = false
    @State private var showingReportSheet = false
    @State private var reportReason = ""
    @State private var reportState: TeamReportState = .idle
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        if detail.joined == true {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let access, access.enabled {
                    progressCard
                    if !ranking.isEmpty {
                        rankingCard
                    }
                }
                if detail.leader != true {
                    CYPillButton(verbatim: c.t("举报队伍", "Report team"), style: .tertiary, systemImage: "flag", fullWidth: false) {
                        showingReportSheet = true
                    }
                    .accessibilityIdentifier("team.orient.report")
                }
            }
            .task(id: detail.team.id) {
                await load()
            }
            .sheet(isPresented: $showingReportSheet) {
                reportSheet
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack {
                Text(c.t("任务进度", "Task progress"))
                    .font(Theme.Font.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if loading {
                    ProgressView().controlSize(.small)
                }
            }

            if loadError && board == nil {
                HStack {
                    CYStatusChip(verbatim: c.t("进度加载失败", "Failed to load task progress"), tone: .danger, systemImage: "exclamationmark.triangle")
                    Spacer()
                    CYPillButton(verbatim: c.t("重试", "Retry"), style: .secondary, fullWidth: false) {
                        Task { await load() }
                    }
                }
                .accessibilityIdentifier("team.orient.error")
            } else if let board {
                Text(
                    board.isEmpty
                        ? c.t("当前场次暂无定向任务", "No orienteering tasks for this session")
                        : c.t("全队已完成 \(board.completedCount) / \(board.tasks.count) 个节点",
                              "Team completed \(board.completedCount) / \(board.tasks.count) nodes")
                )
                .font(CYTypography.bodyCompact)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("team.orient.summary")

                if !board.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text(c.t("队员", "Member"))
                                    .font(CYTypography.caption)
                                    .foregroundStyle(CYColor.textSecondary)
                                ForEach(board.tasks) { task in
                                    Text(verbatim: task.title)
                                        .font(CYTypography.caption)
                                        .foregroundStyle(CYColor.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Divider()
                            ForEach(board.members) { member in
                                GridRow {
                                    Text(verbatim: member.name.isEmpty ? c.t("队员", "Member") : member.name)
                                        .font(.caption)
                                    ForEach(board.tasks) { task in
                                        let done = member.hasCompleted(taskID: task.id)
                                        Text(verbatim: done ? "✓" : "·")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(done ? CYColor.successText : CYColor.textTertiary)
                                            .accessibilityLabel(
                                                done ? c.t("已完成", "Completed") : c.t("未完成", "Pending")
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("team.orient.matrix")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("team.orient.board")
    }

    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(c.t("本场队伍排名", "Session team ranking"))
                .font(Theme.Font.sectionTitle)
                .accessibilityAddTraits(.isHeader)

            ForEach(ranking) { row in
                HStack(spacing: 10) {
                    Text(verbatim: "#\(row.rank)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .frame(width: 32, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(verbatim: row.teamName.isEmpty ? "#\(row.teamID)" : row.teamName)
                                .font(.subheadline.weight(.medium))
                            if row.isMyTeam(currentTeamID: detail.team.id) {
                                CYStatusChip(verbatim: c.t("我的队伍", "My team"), tone: .info, systemImage: "person.fill")
                            }
                        }
                        if let duration = row.durationText {
                            Text(verbatim: duration)
                                .font(CYTypography.meta)
                                .foregroundStyle(CYColor.textTertiary)
                        }
                    }
                    Spacer()
                    Text(verbatim: "\(row.completedCount) / \(row.totalTasks)")
                        .font(CYTypography.numericBody)
                        .monospacedDigit()
                        .foregroundStyle(CYColor.textSecondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("team.orient.ranking")
    }

    private var reportSheet: some View {
        NavigationStack {
            Form {
                CYHeroHeader(verbatim: c.t("举报队伍", "Report team"))
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                if reportState == .submitted {
                    Section {
                        CYStatusChip(verbatim: c.t("举报已记录，平台将核查处理", "Report recorded. Platform support will review it."),
                                     tone: .success, systemImage: "checkmark.circle.fill")
                            .accessibilityIdentifier("team.orient.reportSuccess")
                    }
                } else if reportState == .unavailable {
                    Section {
                        CYStatusChip(verbatim: c.t("举报功能暂不可用，请稍后再试", "Reporting is currently unavailable. Please try again later."),
                                     tone: .warning, systemImage: "exclamationmark.triangle")
                            .accessibilityIdentifier("team.orient.reportUnavailable")
                    }
                } else {
                    Section(c.t("举报原因", "Reason for report")) {
                        TextField(c.t("请描述该队伍的违规情况", "Describe the issue with this team"),
                                  text: $reportReason, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("team.orient.reportReason")
                    }
                    if case .failed = reportState {
                        Section {
                            Text(c.t("举报未能提交，请检查网络后重试", "Your report could not be submitted. Check your connection and try again."))
                                .font(.footnote)
                                .foregroundStyle(CYColor.dangerText)
                                .accessibilityIdentifier("team.orient.reportError")
                        }
                    }
                    Section {
                        CYPillButton(verbatim: reportState == .submitting ? c.t("提交中…", "Submitting…") : c.t("提交举报", "Submit report")) {
                            Task { await submitReport() }
                        }
                        .disabled(reportState == .submitting
                                  || TeamReportRules.trimmedReason(reportReason).isEmpty
                                  || TeamReportRules.trimmedReason(reportReason).count > TeamReportRules.reasonLimit)
                        .accessibilityIdentifier("team.orient.reportSubmit")
                    }
                }
            }
            .cyHeroScreen()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(c.t("关闭", "Close")) {
                        showingReportSheet = false
                        reportState = .idle
                        reportReason = ""
                    }
                }
            }
        }
    }

    private func submitReport() async {
        reportState = .submitting
        reportState = await TeamReportSubmission.run(access: access, teamID: detail.team.id, reason: reportReason)
    }

    private func load() async {
        guard let access, access.enabled, detail.joined == true else { return }
        loading = true
        loadError = false
        defer { loading = false }
        do {
            board = try await access.loadBoard(teamID: detail.team.id)
            if let key = detail.team.ownerKey {
                ranking = (try? await access.loadRanking(ownerType: key.type, ownerID: key.id)) ?? []
            } else {
                ranking = []
            }
        } catch is CancellationError {
        } catch {
            loadError = true
        }
    }
}
