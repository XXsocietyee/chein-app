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
