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
    @State private var reportSubmitted = false
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
                    Button {
                        showingReportSheet = true
                    } label: {
                        Label(c.t("举报队伍", "Report team"), systemImage: "flag")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
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
                    Text(c.t("进度加载失败", "Failed to load task progress"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(c.t("重试", "Retry")) {
                        Task { await load() }
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
                }
                .accessibilityIdentifier("team.orient.error")
            } else if let board {
                Text(
                    board.isEmpty
                        ? c.t("当前场次暂无定向任务", "No orienteering tasks for this session")
                        : c.t("全队已完成 \(board.completedCount) / \(board.tasks.count) 个节点",
                              "Team completed \(board.completedCount) / \(board.tasks.count) nodes")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("team.orient.summary")

                if !board.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                            GridRow {
                                Text(c.t("队员", "Member"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(board.tasks) { task in
                                    Text(verbatim: task.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
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
                                            .foregroundStyle(done ? CYColor.successText : .secondary)
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
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
                                Text(c.t("我的队伍", "My team"))
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            }
                        }
                        if let duration = row.durationText {
                            Text(verbatim: duration)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(verbatim: "\(row.completedCount) / \(row.totalTasks)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("team.orient.ranking")
    }

    private var reportSheet: some View {
        NavigationStack {
            Form {
                if reportSubmitted {
                    Section {
                        Label(c.t("举报已记录，平台将核查处理", "Report recorded. Platform support will review it."),
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(CYColor.successText)
                    }
                } else {
                    Section(c.t("举报原因", "Reason for report")) {
                        TextField(c.t("请描述该队伍的违规情况", "Describe the issue with this team"),
                                  text: $reportReason, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("team.orient.reportReason")
                    }
                    Section {
                        Button(c.t("提交举报", "Submit report")) {
                            reportSubmitted = true
                        }
                        .disabled(reportReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("team.orient.reportSubmit")
                    }
                }
            }
            .navigationTitle(c.t("举报队伍", "Report team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(c.t("关闭", "Close")) {
                        showingReportSheet = false
                        reportSubmitted = false
                        reportReason = ""
                    }
                }
            }
        }
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
