import SwiftUI

@MainActor struct PlayAdvancedTeamControls: View {
    @Bindable var model: PlayAdvancedCoordinator
    let surfaceID: UUID
    @State private var review: PlayAdvancedTeamReview?
    @State private var reviewIssue = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
        VStack(alignment: .leading, spacing: 16) {
            if let team = model.teamProjection {
                LabeledContent("advancedTeam.progress") { Text("\(team.completedUnits) / \(team.requiredTurns)").accessibilityLabel(Text("a11y.value.ofTotal \(Int(team.completedUnits)) \(Int(team.requiredTurns))")).monospacedDigit() }
                if let turn = team.turn { PlayAdvancedTurnBlock(turn: turn, isLeader: team.isLeader) }
                else { LabeledContent("advancedTeam.turnIndex") { Text(verbatim: String(team.turnIndex + 1)) } }
                LabeledContent("advancedTeam.myRole") {
                    if let role = team.myRoleDisplay { Text(verbatim: role) }
                    else { Text("advancedTeam.unassigned") }
                }
                LabeledContent { Text(verbatim: team.myTask ?? WP09Copy.unknown) } label: { Text(verbatim: W8Text.t("我的任务", "My task")) }
                LabeledContent { Text(verbatim: team.myEvidence.isEmpty ? WP09Copy.unknown : team.myEvidence.joined(separator: "\n")) } label: {
                    Text(verbatim: W8Text.t("我能贡献的证据", "Evidence I can contribute"))
                }
                LabeledContent { Text(verbatim: team.waitingOn(chinese: W8Text.isChinese)) } label: { Text(verbatim: W8Text.t("当前等谁", "Who is waited on")) }
                LabeledContent { Text(verbatim: team.myPrivateClues.isEmpty ? WP09Copy.unknown : team.myPrivateClues.joined(separator: "\n")) } label: {
                    Text(verbatim: W8Text.t("只属于我的线索", "Clues that are only mine"))
                }
                .privacySensitive()
                Text(team.assignment == "AUTO" ? "advancedTeam.auto" : team.isLeader ? "advancedTeam.leader" : "advancedTeam.leaderOnly").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                ForEach(team.members) { member in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: member.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        if team.isLeader {
                            if let role = member.roleID { Text(verbatim: team.roleLabel(role)) }
                            else { Text("advancedTeam.unassigned") }
                        }
                        if team.isLeader && team.assignment == "LEADER" {
                            ForEach(team.roles) { role in
                                CYPillButton(verbatim: role.label, style: .secondary, fullWidth: false) { prepare(.assign(memberID: member.id, roleID: role.id)) }
                                    .disabled(!model.canTeamInteract || !team.canAssign(memberID: member.id, roleID: role.id))
                                    .accessibilityIdentifier("advancedTeam.assign.\(member.id).\(role.id)")
                            }
                        }
                    }
                }
                if team.completedUnits >= team.requiredTurns { CYStatusChip("advancedTeam.turnsRecorded", tone: .success, systemImage: "checkmark") }
                else {
                    CYPillButton("advancedTeam.complete") { prepare(.completeUnit) }
                        .disabled(!model.canTeamInteract || !team.canRequestUnit)
                        .accessibilityIdentifier("advancedTeam.complete")
                }
                Text("advancedTeam.serverTurn").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                if let state = model.state, state.remainingSeconds(nowMilliseconds: 0) == 0 {
                    CYStatusChip("advancedTeam.expired", tone: .warning, systemImage: "clock.badge.xmark").accessibilityIdentifier("advancedTeam.expired")
                }
            } else { CYEmptyState(systemImage: "person.3", "advancedTeam.unavailable") }
            if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
            if reviewIssue { CYStatusChip("advancedTeam.reviewChanged", tone: .warning, systemImage: "exclamationmark.triangle").accessibilityIdentifier("advancedTeam.reviewChanged") }
        }
        }.accessibilityIdentifier("advancedTeam.controls")
        .cySheet(item: $review) { captured in Group {
            NavigationStack {
                Form {
                    Section("advancedTeam.review") {
                        if let member = captured.memberName { LabeledContent("advancedTeam.member", value: member) }
                        if let role = captured.roleLabel { LabeledContent("advancedTeam.role", value: role) }
                        Text(captured.action == .completeUnit ? "advancedTeam.complete" : "advancedTeam.assign")
                        Text("advancedTeam.serverTurn")
                        LabeledContent("playkit.version") { Text(verbatim: String(captured.version)) }
                        CYPillButton("playkit.confirm") {
                            review = nil
                            Task { await model.submitTeamReview(captured) }
                        }.disabled(!model.canTeamInteract || model.state?.version != captured.version)
                            .accessibilityIdentifier("advancedTeam.confirm")
                    }
                }.cyGroupedSurface().cyPageTitle("advancedTeam.review")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("playkit.cancel") { review = nil } } }
            }.privacySensitive()
        }.cySheet(detents: [.large]) }
        .onChange(of: model.state?.version) { _, _ in review = nil }
        .onChange(of: model.isCurrent) { _, current in if !current { review = nil } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { review = nil } }
        .onDisappear { review = nil }
    }
    private func prepare(_ action: PlayAdvancedTeamReview.Action) {
        do { review = try model.reviewTeamAction(action, surfaceID: surfaceID); reviewIssue = false }
        catch { review = nil; reviewIssue = true }
    }
}

@MainActor struct PlayAdvancedLeaderboardView: View {
    @Bindable var model: PlayAdvancedCoordinator
    let surfaceID: UUID
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let metric = model.leaderboardMetric {
                Text(metric == .elapsed ? "advancedBoard.elapsed" : metric == .units ? "advancedBoard.units" : "advancedBoard.score").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                Text("advancedBoard.scope").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                // mp-states r3 (MP pages/play/components/advanced-game/index.wxml:52-55): the loader says 正在读取排行榜… on screen.
                if model.leaderboardPhase == "loading" { ProgressView { Text("advancedBoard.loading") }.frame(maxWidth: .infinity) }
                else {
                    switch LeaderboardFetchPresentation.resolve(phase: model.leaderboardPhase, rowCount: model.leaderboard.count) {
                    case .error:
                        CYStatusChip("advancedBoard.failed", tone: .danger, systemImage: "exclamationmark.triangle").accessibilityIdentifier("advancedBoard.failed")
                    case .empty:
                        CYEmptyState(systemImage: "list.number", "advancedBoard.empty", messageIdentifier: "advancedBoard.empty")
                    case .ready, .other:
                        EmptyView()
                    }
                }
                ForEach(Array(model.leaderboard.enumerated()), id: \.offset) { _, row in
                    let rankText = row["rank"].integer.map(String.init) ?? "—"
                    let rawValue = metric == .elapsed
                        ? row["elapsedSeconds"].integer.map { "\($0) s" }
                        : row[metric == .units ? "completedUnits" : "score"].integer.map(String.init)
                    HStack {
                        Group {
                            if row["rank"].integer == nil {
                                Text(verbatim: "—").accessibilityLabel(Text("growth.unknownValue"))
                            } else {
                                Text(verbatim: rankText)
                            }
                        }
                        .monospacedDigit()
                        Text(verbatim: row["displayName"].text ?? "")
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Group {
                            if let rawValue {
                                Text(verbatim: rawValue)
                            } else {
                                Text(verbatim: "—").accessibilityLabel(Text("growth.unknownValue"))
                            }
                        }
                        .monospacedDigit()
                    }
                }
                CYPillButton("playx.refresh", style: .secondary, systemImage: "arrow.clockwise") { Task { await model.loadAdvancedLeaderboard(surfaceID: surfaceID) } }
                    .disabled(model.leaderboardPhase == "loading")
                    .accessibilityIdentifier("advancedBoard.refresh")
            } else { CYEmptyState(systemImage: "list.number", "advancedBoard.unavailable") }
        }.privacySensitive().accessibilityIdentifier("advancedBoard.view")
    }
}


/// Inline stories must expose the same shared mechanics, including combinations
/// with no standalone PlayKit kind. Distinct identity fences fallback navigation.
@MainActor struct PlayAdvancedInlineTeamHost: View {
    @Bindable var model: PlayAdvancedCoordinator
    @State private var surfaceID = UUID()
    @State private var surfaceVisible = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.state?.isMultiplayer == true {
                GroupBox("playx.advanced.roles") { PlayAdvancedTeamControls(model: model, surfaceID: surfaceID) }
            }
            if model.state?.config["leaderboard"]["enabled"].bool == true {
                GroupBox("advancedBoard.title") { PlayAdvancedLeaderboardView(model: model, surfaceID: surfaceID) }
            }
        }.accessibilityIdentifier("advancedTeam.inlineHost")
        .onAppear { surfaceVisible = true; model.beginTeamSurface(id: surfaceID) }
        .task(id: model.state?.version) { await model.loadAdvancedLeaderboard(surfaceID: surfaceID) }
        .onDisappear { surfaceVisible = false; model.endTeamSurface(id: surfaceID) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.endTeamSurface(id: surfaceID) }
            else if phase == .active && surfaceVisible { model.beginTeamSurface(id: surfaceID); Task { await model.loadAdvancedLeaderboard(surfaceID: surfaceID) } }
        }
    }
}
