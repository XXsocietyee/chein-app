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
                  guard let self else { return AnyView(CYEmptyState(systemImage: "gamecontroller", "playx.disabled")) }
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
            ClubTopicGenericOpsSection(activityID: activityID, revision: projection.revision) { _ in openingTool = true }
            ClubTopicPlanFallbackSection(activityID: activityID, revision: projection.revision) { Task { await model.load() } }
            ClubTopicDirectorReadySection(projection: projection, topicID: topicID)
            ClubGapTopicDirectorEmbeddedSection(
                summary: Self.summary(projection, model: model, locale: locale),
                onConfirmUnknownWrite: { Task { await model.recover() } },
                onRetryUnknownWrite: { Task { await model.retryExact() } },
                onOpenTool: { _ in openingTool = true },
                onToggleLeaderboardVisibility: { toggleLeaderboard(model) })
        } else if model.phase == "loading" {
            Section {
                CYSkeleton()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("club.topic.director.loading"))
                    .accessibilityIdentifier("club.topic.director.loading")
            }
        } else if model.phase == "failed" {
            Section {
                CYEmptyState(systemImage: "exclamationmark.triangle", "club.topic.director.failed",
                             actionTitle: "action.retry", actionIdentifier: "club.topic.director.retry",
                             kind: .failure) { Task { await model.load() } }
            }
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
            if merchantHoldBlocked, let topicID {
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
