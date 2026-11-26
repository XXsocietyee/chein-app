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
    /// Mini-program `rankingState`: loading skeleton, inline error with retry, or the card (empty reads "暂无队伍排名").
    @State private var rankingPhase: RankingPhase = .hidden
    private enum RankingPhase: Equatable { case hidden, loading, failed, ready }
    @State private var loading = false
    @State private var loadError = false
    @State private var showingReportSheet = false
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        if detail.joined == true {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let access, access.enabled {
                    progressCard
                    switch rankingPhase {
                    case .hidden: EmptyView()
                    case .loading:
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            rankingTitle
                            CYSkeleton().accessibilityLabel(Text(verbatim: c.t("正在加载队伍排名", "Loading team ranking")))
                        }
                        .accessibilityIdentifier("team.orient.rankingLoading")
                    case .failed:
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            rankingTitle
                            HStack {
                                CYStatusChip(verbatim: c.t("队伍排名加载失败", "Team ranking failed to load"), tone: .danger, systemImage: "exclamationmark.triangle")
                                Spacer()
                                CYPillButton(verbatim: c.t("重试", "Retry"), style: .secondary, fullWidth: false) {
                                    Task { await load() }
                                }
                            }
                        }
                        .accessibilityIdentifier("team.orient.rankingError")
                    case .ready:
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
            .cySheet(isPresented: $showingReportSheet) { Group {
                // Source `team-report-sheet`: five fixed reasons, sent verbatim.
                TeamReportReasonSheet(teamID: detail.team.id)
            }.cySheet() }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack {
                Text(c.t("任务进度", "Task progress"))
                    .cyText(.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if loading {
                    ProgressView().controlSize(.small).accessibilityLabel(Text("team.loading"))
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
                .cyText(.bodyCompact)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("team.orient.summary")

                if !board.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text(c.t("队员", "Member"))
                                    .cyText(.caption)
                                    .foregroundStyle(CYColor.textSecondary)
                                ForEach(board.tasks) { task in
                                    Text(verbatim: task.title)
                                        .cyText(.caption)
                                        .foregroundStyle(CYColor.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            Divider()
                            ForEach(board.members) { member in
                                GridRow {
                                    Text(verbatim: member.name.isEmpty ? c.t("队员", "Member") : member.name)
                                        .cyText(.meta)
                                    ForEach(board.tasks) { task in
                                        let done = member.hasCompleted(taskID: task.id)
                                        Text(verbatim: done ? "✓" : "·")
                                            .cyText(.meta, weight: .bold)
                                            .foregroundStyle(done ? CYColor.successText : CYColor.textSecondary)
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

    private var rankingTitle: some View {
        Text(c.t("本场队伍排名", "Session team ranking"))
            .cyText(.sectionTitle)
            .accessibilityAddTraits(.isHeader)
    }

    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            rankingTitle
            if ranking.isEmpty {
                Text(c.t("暂无队伍排名", "No team ranking yet"))
                    .cyText(.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("team.orient.rankingEmpty")
            }

            ForEach(ranking) { row in
                HStack(spacing: 10) {
                    Text(verbatim: "#\(row.rank)")
                        .cyText(.bodyMedium)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(verbatim: row.teamName.isEmpty ? "#\(row.teamID)" : row.teamName)
                                .cyText(.bodyMedium)
                            if row.isMyTeam(currentTeamID: detail.team.id) {
                                CYStatusChip(verbatim: c.t("我的队伍", "My team"), tone: .info, systemImage: "person.fill")
                            }
                        }
                        if let duration = row.durationText {
                            Text(verbatim: duration)
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    Spacer()
                    Text(verbatim: "\(row.completedCount) / \(row.totalTasks)")
                        .cyText(.numericBody)
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

    private func load() async {
        guard let access, access.enabled, detail.joined == true else { return }
        loading = true
        loadError = false
        defer { loading = false }
        do {
            board = try await access.loadBoard(teamID: detail.team.id)
            if let key = detail.team.ownerKey {
                rankingPhase = .loading
                do {
                    ranking = try await access.loadRanking(ownerType: key.type, ownerID: key.id)
                    rankingPhase = .ready
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    ranking = []
                    rankingPhase = .failed
                }
            } else {
                ranking = []
                rankingPhase = .hidden
            }
        } catch is CancellationError {
        } catch {
            loadError = true
        }
    }
}
