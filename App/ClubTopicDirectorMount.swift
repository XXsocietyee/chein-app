import SwiftUI

/// CLB-G13 (MP topic-detail wxml:160-500): the director block that the MP folds into the topic detail when it is opened
/// with an `activityId` (2026-09-03: the director page was merged into the activity detail).
///
/// The host is injected through the environment and defaults to nil, so the block stays hidden (gate default off) until
/// the composition that owns `AppSession` sets `.environment(\.clubTopicDirectorHost, session.clubTopicDirectorHost)`.
/// It reuses the existing `PlayDirectorCoordinator` (`AppSession.playDirector(activityID:)`) as its summary feed and
/// opens the full `SessionPlayRuntimeView(.director)` for every tool; nothing here adds a new request.
struct ClubTopicDirectorHost {
    var coordinator: @MainActor (_ activityID: Int) -> PlayDirectorCoordinator?
    var destination: @MainActor (_ activityID: Int) -> AnyView
}

private struct ClubTopicDirectorHostKey: EnvironmentKey {
    static let defaultValue: ClubTopicDirectorHost? = nil
}

extension EnvironmentValues {
    var clubTopicDirectorHost: ClubTopicDirectorHost? {
        get { self[ClubTopicDirectorHostKey.self] }
        set { self[ClubTopicDirectorHostKey.self] = newValue }
    }
}

@MainActor extension AppSession {
    /// The director host for club topic detail. Nil when the play runtime is not configured.
    var clubTopicDirectorHost: ClubTopicDirectorHost {
        .init(coordinator: { [weak self] in self?.playDirector(activityID: $0) },
              destination: { [weak self] activityID in
                  guard let self else { return AnyView(ContentUnavailableView("playx.disabled", systemImage: "gamecontroller")) }
                  return AnyView(SessionPlayRuntimeView(session: self, destination: .director(activityID)))
              })
    }
}

/// Mounts `ClubGapTopicDirectorEmbeddedSection` for one activity once the director projection has loaded.
@MainActor struct ClubTopicDirectorEmbeddedMount: View {
    let activityID: Int
    /// CLB-G13c: 联系商家 opens this topic's sent cooperation list (MP `goStationMerchants`).
    var topicID: Int? = nil
    @Environment(\.clubTopicDirectorHost) private var host
    @Environment(\.locale) private var locale
    @State private var openingTool = false

    var body: some View {
        if let host, let model = host.coordinator(activityID) {
            content(model, host: host)
                .task(id: activityID) { if model.projection == nil { await model.load() } }
                .navigationDestination(isPresented: $openingTool) { host.destination(activityID) }
        }
    }

    @ViewBuilder private func content(_ model: PlayDirectorCoordinator, host: ClubTopicDirectorHost) -> some View {
        if let projection = model.projection {
            ClubTopicGenericOpsSection(activityID: activityID, revision: projection.revision,
                                       writeLocked: model.phase != "ready",
                                       onOpenAction: { _ in openingTool = true },
                                       onSubmitted: { Task { await model.load() } })
            ClubTopicPlanFallbackSection(activityID: activityID, revision: projection.revision) { Task { await model.load() } }
            ClubTopicDirectorReadySection(projection: projection, topicID: topicID)
            // CLB-G13d (MP topic-detail wxml:172-198, 262-295): MP copy for the write states, capability-gated tools,
            // the stations note, and 排行榜 rows with 暂无榜单记录.
            ClubTopicDirectorToolsSection(projection: projection, phase: model.phase,
                                          unknownWriteLabel: Self.summary(projection, model: model, locale: locale).unknownWriteLabel,
                                          onConfirmUnknownWrite: { Task { await model.recover() } },
                                          onRetryUnknownWrite: { Task { await model.retryExact() } },
                                          onOpenTool: { openingTool = true },
                                          onToggleLeaderboard: { toggleLeaderboard(model) },
                                          onExportRecap: { Task { if let text = await model.exportRecap() { LocalPasteboard.copy(text) } } })
        } else if model.phase == "loading" {
            Section {
                ProgressView { Text("club.topic.director.loading") }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("club.topic.director.loading")
            }
        } else if let state = Self.loadState(phase: model.phase, issue: model.issue) {
            // CLB-r3-director-states (MP topic-detail wxml:163-171, director.js:378-385 classifyLoadError):
            // NOT_FOUND → 还没有可管理的活动局; transport → 网络连接失败 + 重新连接; any other refusal → 导演台读取失败
            // with the server sentence + 重新加载. A refused read used to render nothing.
            Section {
                switch state {
                case .empty(let message):
                    ContentUnavailableView {
                        Label("club.topic.director.empty", systemImage: "flag.checkered")
                    } description: {
                        if let message { Text(verbatim: message) } else { Text("club.topic.director.emptySub") }
                    }
                    .accessibilityIdentifier("club.topic.director.empty")
                case .network:
                    ContentUnavailableView {
                        Label("club.topic.director.network", systemImage: "wifi.exclamationmark")
                    } actions: {
                        Button("club.topic.director.reconnect") { Task { await model.load() } }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("club.topic.director.retry")
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("club.topic.director.failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        if let message { Text(verbatim: message) } else { Text("club.topic.director.failedSub") }
                    } actions: {
                        Button("action.reload") { Task { await model.load() } }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("club.topic.director.retry")
                    }
                }
            }
        }
    }

    enum LoadState: Equatable {
        case empty(String?)
        case network
        case failed(String?)
    }

    /// MP `classifyLoadError` on the native coordinator: only reached while there is no projection.
    static func loadState(phase: String, issue: PlayExperienceError?) -> LoadState? {
        switch phase {
        case "rejected":
            if case .rejected(let code, let message)? = issue {
                let text = message.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                return code == 404 ? .empty(text) : .failed(text)
            }
            return .failed(nil)
        case "failed":
            return issue == .unknownResult ? .network : .failed(nil)
        default:
            return nil
        }
    }

    private func toggleLeaderboard(_ model: PlayDirectorCoordinator) {
        guard let projection = model.projection, let visible = projection.leaderboardVisible,
              let command = try? PlayDirectorCommand(activityID: activityID, nodeID: nil, expectedRevision: projection.revision,
                                                     action: .visibility, payload: ["visible": .bool(!visible)]) else {
            openingTool = true; return
        }
        Task { await model.submit(command) }
    }

    /// 准备总览 numbers straight from the CLUB projection: readiness.readyStations / requiredStations (or the station
    /// count), the team count, and the first readiness blocker as the caption. A missing number reads 0, never an invented value.
    static func summary(_ projection: PlayDirectorProjection, model: PlayDirectorCoordinator, locale: Locale) -> ClubTopicDirectorSummary {
        let readiness = projection.club["readiness"]
        let total = readiness["requiredStations"].integer ?? projection.stations.count
        // The director page's own action names (`playx.director.action.*`, all eleven are in the catalog).
        let pendingTitle = model.pending.map { appLocalized(String.LocalizationValue(stringLiteral: "playx.director.action." + $0.action.rawValue), locale: locale) }
        // The first server blocker sentence, as the director page lists them under readiness; none → no caption.
        let blocker = (readiness["blockers"].array ?? []).compactMap { $0.text }.first
        return ClubTopicDirectorSummary(
            readyStations: readiness["readyStations"].integer ?? 0,
            totalStations: total,
            activeTeams: projection.teams.count,
            caption: blocker,
            leaderboardHidden: projection.leaderboardVisible == false,
            hasUnknownWrite: model.phase == "unknown",
            unknownWriteLabel: pendingTitle)
    }
}

/// CLB-G12: one reviewed MP route opened from the topic 更多 menu.
struct ClubTopicMoreRoute: Hashable {
    let page: String
    let query: [String: String]
}

/// CLB-G13c (MP topic-detail wxml:244-261, director.js:35-110, 855-877): 准备总览 only while the session is preparing
/// (projection PREPARING / READY), with 节点状态 (「N/M 站就绪」 + each station) and 队伍进度 (the session status + each
/// team's 「done/total 节点」). The caption is 「还不能开始：」 + the server blockers. 联系商家 shows while a blocker
/// names the merchant (待商家接受 / 合作单) and opens the topic's sent cooperation list.
@MainActor struct ClubTopicDirectorReadySection: View {
    let projection: PlayDirectorProjection
    let topicID: Int?

    private static let stationCodes: Set<String> = ["INVITED", "ACCEPTED", "READY", "ACTIVE", "PAUSED", "CLOSED"]
    private static let teamCodes: Set<String> = ["PREPARING", "RUNNING", "COMPLETED", "BLOCKED", "PAUSED", "ERROR"]
    private static let sessionCodes: Set<String> = ["NOT_PREPARED", "DRAFT", "PREPARING", "READY", "RUNNING", "FINISHED", "CANCELLED"]

    private var preparing: Bool { ["PREPARING", "READY"].contains(projection.status.uppercased()) }
    private var readiness: PlayWireValue { projection.club["readiness"] }
    private var blockers: [String] {
        (readiness["blockers"].array ?? []).compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    /// MP `merchantHoldBlocked`: not running and a blocker mentions 待商家接受 or 合作单.
    private var merchantHoldBlocked: Bool {
        projection.status.uppercased() != "RUNNING" && blockers.contains { $0.contains("待商家接受") || $0.contains("合作单") }
    }

    var body: some View {
        if preparing {
            Section {
                LabeledContent {
                    readinessText
                } label: {
                    Text("club.director.ready.stations")
                }
                ForEach(Array(projection.stations.enumerated()), id: \.offset) { _, station in
                    LabeledContent {
                        Text(Self.key("club.director.stationStatus.", station["status"].text, known: Self.stationCodes))
                    } label: {
                        Text(verbatim: Self.firstText(station, ["name", "stationName", "nodeName"]) ?? "—")
                        if let issue = Self.firstText(station, ["issue", "blockedReason", "pauseReason", "exception"]) {
                            Text(verbatim: issue)
                        }
                    }
                }
                LabeledContent {
                    Text(Self.key("club.director.sessionStatus.", projection.status, known: Self.sessionCodes))
                } label: {
                    Text("club.director.ready.teams")
                }
                ForEach(Array(projection.teams.enumerated()), id: \.offset) { _, team in
                    LabeledContent {
                        teamProgress(team)
                    } label: {
                        Text(verbatim: Self.firstText(team, ["name", "teamName"]) ?? "—")
                        Text(Self.key("club.director.teamStatus.", team["status"].text, known: Self.teamCodes))
                    }
                }
            } header: {
                Text("club.director.ready.title")
            } footer: {
                if !blockers.isEmpty {
                    Label {
                        Text("club.director.ready.blocked \(blockers.joined(separator: "；"))")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
            }
            .accessibilityIdentifier("club.topic.director.ready")
            if PlayerLaunch.merchantCenterEnabled, merchantHoldBlocked, let topicID { // Lane G: 联系商家 (coop list) hidden in Release
                Section {
                    NavigationLink {
                        MPReviewedPageScreen(page: "pages/coop/list/index", query: ["tab": "sent", "topicId": String(topicID)])
                    } label: {
                        Label("club.director.ready.contactMerchant", systemImage: "storefront")
                    }
                    .accessibilityIdentifier("club.topic.director.contactMerchant")
                }
            }
        }
    }

    /// MP `readinessText`: 「ready/required 站就绪」, or — when either number is missing.
    @ViewBuilder private var readinessText: some View {
        if let ready = readiness["readyStations"].integer, let required = readiness["requiredStations"].integer {
            Text("club.director.ready.readiness \(ready) \(required)")
        } else {
            Text(verbatim: "—")
        }
    }

    /// MP `teamView.progressText`: 「completed/total 节点」, or —.
    @ViewBuilder private func teamProgress(_ team: PlayWireValue) -> some View {
        if let done = team["completedNodes"].integer, let total = team["totalNodes"].integer {
            Text("club.director.ready.progress \(done) \(total)")
        } else {
            Text(verbatim: "—")
        }
    }

    private static func firstText(_ value: PlayWireValue, _ keys: [String]) -> String? {
        for key in keys {
            if let text = value[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        }
        return nil
    }

    /// Status codes stay out of the UI (MP C-26): a known code maps to its label, anything else reads 待确认.
    private static func key(_ prefix: String, _ code: String?, known: Set<String>) -> LocalizedStringKey {
        let upper = (code ?? "").uppercased()
        return LocalizedStringKey(prefix + (known.contains(upper) ? upper : "unknown"))
    }
}

/// CLB-G13d (MP topic-detail wxml:172-198, 262-295; director.js:855-905): the director block below 准备总览.
/// - write state: 操作处理中 while a command is in flight; 结果待确认 with 确认结果 / 重试原操作 when the outcome is unknown;
/// - 开始准备后显示节点状态 when the projection has no stations yet;
/// - tools only where the projection offers them: 章节放行 (UNLOCK_CHAPTER with a releasable chapter), 队伍进度 (teams),
///   角色分配 (ASSIGN_ROLES with roles), 现场事件 (a paused station or a pending submission); each opens the director page;
/// - 排行榜 while the session has not finished: the toggle only with SET_LEADERBOARD_VISIBILITY, the rows, or 暂无榜单记录.
@MainActor struct ClubTopicDirectorToolsSection: View {
    let projection: PlayDirectorProjection
    let phase: String
    let unknownWriteLabel: String?
    let onConfirmUnknownWrite: () -> Void
    let onRetryUnknownWrite: () -> Void
    let onOpenTool: () -> Void
    let onToggleLeaderboard: () -> Void
    /// CLB-r11-topic-detail-03 (MP director.js:1440-1466 copyRecap): copies the privacy-filtered recap export.
    var onExportRecap: () -> Void = {}
    @Environment(\.locale) private var locale

    private var actions: Set<String> { projection.availableActions }
    private var canUnlockChapter: Bool { actions.contains("UNLOCK_CHAPTER") && !projection.chapterOptions.isEmpty }
    private var hasTeams: Bool { !projection.teams.isEmpty }
    private var canAssignRoles: Bool { actions.contains("ASSIGN_ROLES") && !projection.roleOptions.isEmpty && !projection.roles.isEmpty }
    private var hasIncidents: Bool {
        projection.stations.contains { ($0["status"].text ?? "").uppercased() == "PAUSED" } || !projection.submissions.isEmpty
    }
    private var leaderboard: PlayWireValue { projection.club["leaderboard"] }
    private var leaderboardRows: [PlayWireValue] { leaderboard["rows"].array ?? [] }
    private var finished: Bool { ["FINISHED", "CANCELLED"].contains(projection.status.uppercased()) }
    private var ended: Bool { projection.status.uppercased() == "FINISHED" }
    /// MP director.js:829-831: `projection.recap`, normalized through the same allowlist the director page uses.
    private var recap: PlayWireValue? { try? PlayDirectorRecap.normalize(projection.club["recap"]) }

    var body: some View {
        if phase == "submitting" || phase == "unknown" {
            Section {
                if phase == "submitting" {
                    Label { Text("club.director.processing") } icon: { ProgressView() }
                } else {
                    Label {
                        VStack(alignment: .leading) {
                            Text("club.director.unknownTitle").font(.headline)
                            if let unknownWriteLabel { Text(verbatim: unknownWriteLabel).font(.subheadline).foregroundStyle(.secondary) }
                        }
                    } icon: {
                        Image(systemName: "questionmark.circle").foregroundStyle(.orange)
                    }
                    Button("club.director.confirmResult", action: onConfirmUnknownWrite)
                        .accessibilityIdentifier("club.topic.director.confirmResult")
                    Button("club.director.retryOriginal", action: onRetryUnknownWrite)
                        .accessibilityIdentifier("club.topic.director.retryOriginal")
                }
            }
        }
        if projection.stations.isEmpty {
            Section {
                Text("club.director.stationsAfterPrepare").foregroundStyle(.secondary)
            }
        }
        if canUnlockChapter || hasTeams || canAssignRoles || hasIncidents {
            Section {
                if canUnlockChapter { tool("club.director.tool.chapterRelease", "lock.open", id: "chapterRelease") }
                if hasTeams { tool("club.director.tool.teamProgress", "flag.2.crossed", id: "teamProgress") }
                if canAssignRoles { tool("club.director.tool.roleAssignment", "person.2.badge.gearshape", id: "roleAssignment") }
                if hasIncidents { tool("club.director.tool.liveEvents", "bolt.badge.clock", id: "liveEvents") }
            } header: {
                Text("club.director.tools")
            } footer: {
                if canUnlockChapter { Text("club.director.unlockNote") }
            }
        }
        if let visible = projection.leaderboardVisible, !finished {
            Section {
                if leaderboardRows.isEmpty {
                    Text("club.director.leaderboardEmpty").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(leaderboardRows.enumerated()), id: \.offset) { index, row in
                        LabeledContent {
                            if let value = Self.firstText(row, ["value", "scoreText", "score"]) { Text(verbatim: value).monospacedDigit() }
                        } label: {
                            Text(verbatim: "\(index + 1). " + (Self.firstText(row, ["title", "teamName", "nickname", "name"]) ?? "—"))
                            if let sub = Self.firstText(row, ["subtitle", "progressText"]) { Text(verbatim: sub) }
                        }
                    }
                }
                if actions.contains("SET_LEADERBOARD_VISIBILITY") {
                    Button(action: onToggleLeaderboard) {
                        Label(visible ? LocalizedStringKey("club.director.hideLeaderboard") : LocalizedStringKey("club.director.showLeaderboard"),
                              systemImage: visible ? "eye.slash" : "eye")
                    }
                    .accessibilityIdentifier("club.topic.director.toggleLeaderboard")
                }
            } header: {
                Text("club.director.leaderboard")
            }
        }
        if ended { recapSections }
    }

    /// CLB-r11-topic-detail-03 (MP topic-detail wxml:296-312; director.js:280-305, 829-905): once the session has
    /// FINISHED, 活动复盘 shows the recap metrics (first three, then 完成情况), 节点完成 per station and the 榜单 rows,
    /// with 显示/隐藏榜单 and 复制复盘数据 where the projection offers them; without a recap it reads 复盘尚未生成.
    @ViewBuilder private var recapSections: some View {
        if let recap {
            let metrics = recap["metrics"].array ?? []
            let stations = recap["stations"].array ?? []
            Section {
                ForEach(Array(metrics.prefix(3).enumerated()), id: \.offset) { _, metric in metricRow(metric) }
                if projection.leaderboardVisible != nil, actions.contains("SET_LEADERBOARD_VISIBILITY") {
                    let visible = projection.leaderboardVisible == true
                    Button(action: onToggleLeaderboard) {
                        Label(visible ? LocalizedStringKey("club.director.hideLeaderboard") : LocalizedStringKey("club.director.showLeaderboard"),
                              systemImage: visible ? "eye.slash" : "eye")
                    }
                    .disabled(phase != "ready")
                    .accessibilityIdentifier("club.topic.director.recap.toggleLeaderboard")
                }
                if recap["exportAvailable"].bool == true {
                    Button(action: onExportRecap) { Label("club.director.recap.copy", systemImage: "doc.on.doc") }
                        .disabled(phase != "ready")
                        .accessibilityIdentifier("club.topic.director.recap.copy")
                }
            } header: {
                Text("club.director.recap.title")
            }
            if metrics.count > 3 {
                Section {
                    ForEach(Array(metrics.dropFirst(3).enumerated()), id: \.offset) { _, metric in metricRow(metric) }
                } header: {
                    Text("club.director.recap.completion")
                }
            }
            if !leaderboardRows.isEmpty {
                Section {
                    ForEach(Array(leaderboardRows.enumerated()), id: \.offset) { index, row in
                        LabeledContent {
                            if let value = Self.firstText(row, ["value", "scoreText", "score"]) { Text(verbatim: value).monospacedDigit() }
                        } label: {
                            Text(verbatim: "\(index + 1). " + (Self.firstText(row, ["title", "teamName", "nickname", "name"]) ?? "—"))
                        }
                    }
                } header: {
                    Text("club.director.recap.leaderboard")
                }
            }
            if !stations.isEmpty {
                Section {
                    ForEach(Array(stations.enumerated()), id: \.offset) { _, station in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: station["nodeName"].text ?? "—")
                            let subtitle = stationSubtitle(station)
                            if !subtitle.isEmpty { Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary) }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("club.director.recap.stations")
                }
            }
        } else {
            Section {
                Text("club.director.recap.pending").foregroundStyle(.secondary)
            } header: {
                Text("club.director.recap.title")
            }
        }
    }

    private func metricRow(_ metric: PlayWireValue) -> some View {
        let unit = metric["unit"].text ?? ""
        let value = metric["value"].integer.map { String($0) } ?? "—"
        return LabeledContent {
            Text(verbatim: unit.isEmpty ? value : value + " " + unit).monospacedDigit()
        } label: {
            Text(verbatim: metric["label"].text ?? "")
        }
    }

    /// MP director.js:295-305 recapStationRow: 到达 N 人 · 完成 N · 兜底 N · 打回 N.
    private func stationSubtitle(_ station: PlayWireValue) -> String {
        var parts: [String] = []
        if let arrived = station["arrivedPlayers"].integer { parts.append(appLocalized("club.director.recap.arrived \(arrived)", locale: locale)) }
        if let done = station["normalCompletedCount"].integer { parts.append(appLocalized("club.director.recap.completed \(done)", locale: locale)) }
        if let fallback = station["fallbackCompletedCount"].integer, fallback > 0 { parts.append(appLocalized("club.director.recap.fallback \(fallback)", locale: locale)) }
        if let rejected = station["rejectedCount"].integer, rejected > 0 { parts.append(appLocalized("club.director.recap.rejected \(rejected)", locale: locale)) }
        return parts.joined(separator: " · ")
    }

    private func tool(_ key: LocalizedStringKey, _ symbol: String, id: String) -> some View {
        Button(action: onOpenTool) { Label(key, systemImage: symbol) }
            .accessibilityIdentifier("club.topic.director.tool." + id)
    }

    private static func firstText(_ value: PlayWireValue, _ keys: [String]) -> String? {
        for key in keys {
            if let text = value[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
            if let number = value[key].integer { return String(number) }
        }
        return nil
    }
}
