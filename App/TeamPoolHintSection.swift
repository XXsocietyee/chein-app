import SwiftUI

/// Team run section of the hint dialog and run header (contract §4 / §25.1).
/// Hints, skips, live shared timer countdown, and single `teamScore` belong to the whole team.
/// No client points or money are spent or written here.
@MainActor struct TeamPoolHintSection: View {
    @Bindable var model: TeamPoolHintModel
    @Environment(\.locale) private var locale
    @State private var confirmingSkip = false

    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        GroupBox {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("teamPool.title").font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let pool = model.pool {
                    Text(verbatim: c.t("团队总分 \(Self.scoreText(pool))", "Team score \(Self.scoreText(pool))"))
                        .font(.subheadline).monospacedDigit()
                        .accessibilityIdentifier("teamPool.score")
                        .accessibilityLabel(Text(verbatim: c.t("团队总分", "Team total score")))
                        .accessibilityValue(Text(verbatim: Self.scoreText(pool)))
                }
            }
            if let pool = model.pool {
                HStack(spacing: 12) {
                    if let left = pool.hintsLeft, let total = pool.hintsTotal {
                        Text("teamPool.hintsLeft \(left) \(total)").accessibilityIdentifier("teamPool.hintsLeft")
                    }
                    if let left = pool.skipsLeft, let total = pool.skipsTotal {
                        Text("teamPool.skipsLeft \(left) \(total)").accessibilityIdentifier("teamPool.skipsLeft")
                    }
                    if let solved = pool.solvedNodeIds {
                        Text(verbatim: c.t("已解 \(solved.count)", "Solved \(solved.count)"))
                            .accessibilityIdentifier("teamPool.solvedCount")
                    }
                }
                .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)

                teamTimerRow(pool)
            }

            if let hint = model.hint {
                VStack(alignment: .leading, spacing: 4) {
                    Text("teamPool.hintLevel \(hint.level)").font(.subheadline).foregroundStyle(.secondary)
                    Text(verbatim: hint.content)
                        .font(hint.type == "LETTER" || hint.type == "DIGIT" ? Font.title.bold() : Font.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("teamPool.hint")
                    if model.coveredByTeam {
                        Text("teamPool.coveredByTeam").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else if model.canRecover && model.notice == .unknown {
                Button { Task { await model.recover() } } label: { Text("teamPool.keepChecking") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("teamPool.recover")
            } else {
                HStack(spacing: 12) {
                    Button { Task { await model.requestHint() } } label: { Text("teamPool.useHint") }
                        .buttonStyle(.bordered)
                        .disabled(!model.canRequestHint)
                        .accessibilityIdentifier("teamPool.useHint")
                        .accessibilityLabel(Text("teamPool.useHint"))
                        .accessibilityHint(hintCountHint)
                    Button { confirmingSkip = true } label: { Text(verbatim: c.t("全队跳过", "Team skip")) }
                        .buttonStyle(.bordered)
                        .disabled(!model.canRequestSkip)
                        .accessibilityIdentifier("teamPool.useSkip")
                        .accessibilityLabel(Text(verbatim: c.t("全队跳过", "Team skip")))
                        .accessibilityHint(Text(verbatim: c.t("将消耗全队共享跳过额度，并同步给全队成员。",
                                                            "This spends one shared team skip and syncs progress across the team.")))
                }
            }

            if model.skipResult != nil || model.isNodeSolvedByTeam {
                Text(verbatim: model.skippedByTeam
                     ? c.t("队友已跳过并同步全队进度", "Skipped by teammate; team progress synced")
                     : c.t("本题已同步全队跳过完成（计入共享团队进度）", "Team shared skip applied and synced"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("teamPool.skipped")
            }

            if let notice = model.notice { noticeText(notice) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("teamPool.section")
        .accessibilityLabel(Text("teamPool.title"))
        .accessibilityHint(Text(verbatim: c.t("第一个答对全队推进 · 全队共用提示/跳过/计时与统一团队总分",
                                              "First solve advances the team · Shared hints, skips, timer & single team score")))
        .confirmationDialog(
            c.t("使用全队共享跳过", "Use team shared skip"),
            isPresented: $confirmingSkip,
            titleVisibility: .visible
        ) {
            Button(c.t("确认跳过并全队同步", "Confirm team skip"), role: .destructive) {
                Task { await model.requestSkip() }
            }
            .accessibilityIdentifier("teamPool.skip.confirm")
            Button(c.t("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(c.t("将消耗全队共享跳过额度，并同步给全队成员。",
                    "This spends one shared team skip and syncs progress across the team."))
        }
    }

    @ViewBuilder private func teamTimerRow(_ pool: TeamPoolSnapshot) -> some View {
        if let limit = pool.timerLimitSec, limit > 0 {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if pool.isTimerExpired(at: context.date) {
                    Text("teamPool.timerExpired")
                        .font(.subheadline).foregroundStyle(.red)
                        .accessibilityIdentifier("teamPool.timerExpired")
                        .accessibilityLabel(Text("teamPool.timerExpired"))
                } else if let remaining = pool.remainingTimerSeconds(at: context.date) {
                    let line = c.t("全队计时剩余 \(Self.formatDuration(remaining))", "Team timer \(Self.formatDuration(remaining))")
                    Text(verbatim: line)
                        .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityIdentifier("teamPool.timerRemaining")
                        .accessibilityLabel(Text(verbatim: line))
                        .accessibilityValue(Text(verbatim: Self.formatDuration(remaining)))
                } else if model.canStartTimer {
                    let line = c.t("开始全队计时 (\(Self.formatDuration(limit)))", "Start team timer (\(Self.formatDuration(limit)))")
                    Button { Task { await model.startTimer() } } label: {
                        Text(verbatim: line)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("teamPool.timerStart")
                    .accessibilityLabel(Text(verbatim: line))
                    .accessibilityHint(Text(verbatim: c.t("第一个答对全队推进 · 全队共用提示/跳过/计时与统一团队总分",
                                                        "First solve advances the team · Shared hints, skips, timer & single team score")))
                }
            }
        }
    }

    static func scoreText(_ pool: TeamPoolSnapshot) -> String {
        pool.teamScore.map(String.init) ?? "—"
    }

    private var hintCountHint: Text {
        if let left = model.pool?.hintsLeft, let total = model.pool?.hintsTotal {
            return Text("teamPool.hintsLeft \(left) \(total)")
        }
        return Text("teamPool.unknown")
    }

    static func formatDuration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let mins = clamped / 60
        let secs = clamped % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func noticeText(_ notice: TeamPoolHintModel.Notice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                switch notice {
                case .exhausted: Text("teamPool.exhausted")
                case .timerExpired: Text("teamPool.timerExpired")
                case .timerDisabled: Text(verbatim: c.t("该玩法未启用全队计时", "Team timer not enabled"))
                case .disabled, .unavailable: Text("teamPool.unavailable")
                case .hintUnavailable: Text("teamPool.hintUnavailable")
                case .notMember: Text("teamPool.notMember")
                case .nodeNotFound: Text(verbatim: c.t("未找到该打卡节点", "Node not found in team run"))
                case .requestConflict: Text(verbatim: c.t("请求标识冲突，请刷新后重试", "Request ID conflict; reload"))
                case .unknown: Text("teamPool.unknown")
                case .failed: Text("teamPool.failed")
                }
            }
            .font(.subheadline).foregroundStyle(.red)
            .accessibilityIdentifier("teamPool.notice")
            if notice == .unknown || notice == .failed,
               let row = RequestReferenceRow(pathFragment: "/api/team/pool") { row }
        }
    }
}

/// Run-level team shared resource bar mounted on `PlayExperienceView` (`orientationList`) for §25.1.
@MainActor struct TeamPoolRunStatusSection: View {
    @Bindable var model: TeamPoolHintModel
    @Environment(\.locale) private var locale

    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        if let pool = model.pool, pool.enabled {
            Section {
                HStack {
                    Label {
                        Text(verbatim: c.t("团队总分", "Team total score"))
                    } icon: {
                        Image(systemName: "person.3.fill")
                    }
                    Spacer()
                    Text(verbatim: TeamPoolHintSection.scoreText(pool))
                        .font(.headline).monospacedDigit()
                        .accessibilityIdentifier("teamPool.run.score")
                        .accessibilityLabel(Text(verbatim: c.t("团队总分", "Team total score")))
                        .accessibilityValue(PageTemplateVoiceOver.spoken(TeamPoolHintSection.scoreText(pool), locale: locale))
                }
                HStack(spacing: 12) {
                    if let left = pool.hintsLeft, let total = pool.hintsTotal {
                        Text("teamPool.hintsLeft \(left) \(total)")
                    }
                    if let left = pool.skipsLeft, let total = pool.skipsTotal {
                        Text("teamPool.skipsLeft \(left) \(total)")
                    }
                    if let solved = pool.solvedNodeIds {
                        Text(verbatim: c.t("已解 \(solved.count) 关", "\(solved.count) solved"))
                    }
                }
                .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)

                if let limit = pool.timerLimitSec, limit > 0 {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if pool.isTimerExpired(at: context.date) {
                            Text("teamPool.timerExpired")
                                .foregroundStyle(CYColor.dangerText)
                        } else if let remaining = pool.remainingTimerSeconds(at: context.date) {
                            Text(verbatim: c.t("全队计时剩余 \(TeamPoolHintSection.formatDuration(remaining))",
                                               "Team timer \(TeamPoolHintSection.formatDuration(remaining))"))
                                .monospacedDigit()
                                .accessibilityIdentifier("teamPool.run.timer")
                        } else if model.canStartTimer {
                            Button { Task { await model.startTimer() } } label: {
                                Text(verbatim: c.t("开始全队计时 (\(TeamPoolHintSection.formatDuration(limit)))",
                                                   "Start team timer (\(TeamPoolHintSection.formatDuration(limit)))"))
                            }
                            .accessibilityIdentifier("teamPool.run.timerStart")
                        }
                    }
                }
                Text(verbatim: c.t("第一个答对全队推进 · 全队共用提示/跳过/计时与统一团队总分",
                                   "First solve advances the team · Shared hints, skips, timer & single team score"))
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("teamPool.title")
            }
            .accessibilityIdentifier("teamPool.run.section")
            .accessibilityLabel(Text("teamPool.title"))
            .accessibilityValue(PageTemplateVoiceOver.spoken(TeamPoolHintSection.scoreText(pool), locale: locale))
            .accessibilityHint(Text(verbatim: c.t("第一个答对全队推进 · 全队共用提示/跳过/计时与统一团队总分",
                                                  "First solve advances the team · Shared hints, skips, timer & single team score")))
        }
    }
}

extension AppSession {
    /// The team pool for one stop (or `nodeID == 0` for run-level shared score/timer/pool bar) of a run.
    func teamPoolHint(topicID: Int?, nodeID: Int, runTeamID: Int? = nil) -> TeamPoolHintModel? {
        guard let topicID, topicID > 0, nodeID >= 0, let configuration = regionalConfiguration?.apiConfiguration,
              let context = currentRuntimeDependencyContext, composition.playerWriteGrant(context) != nil else { return nil }
        let service = TeamPoolService(configuration: configuration, transport: runtimeHTTPTransport, token: { [weak self] in
            guard let self, self.currentRuntimeDependencyContext == context else { return nil }
            return self.token
        })
        let teams = makeTeamCoordinator()
        return TeamPoolHintModel(service: service, nodeID: Int64(nodeID)) { [weak self] in
            guard self?.currentRuntimeDependencyContext == context else { return nil }
            if let runTeamID, runTeamID > 0 { return Int64(runTeamID) }
            await teams.loadTeams()
            let live: [TeamStatus] = [.recruiting, .full, .inProgress]
            return teams.teams.first { $0.ownerType == 1 && $0.ownerID == topicID && live.contains($0.status) }.map { Int64($0.id) }
        }
    }
}
