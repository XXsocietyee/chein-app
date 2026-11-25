import SwiftUI

/// RTEAMS-1 (MP pages/topic/index wxml:264-279, js `_loadTeams` / `openTeamLobby`): under the brands, the 组队 card —
/// 已组 N 支队伍 · 还差 M 人, up to five of this topic's teams near the first stop with coordinates
/// (`GET /api/team/nearby`, 20 km, filtered by topicId). Signed-out, no stop coordinates, a failed read or no team
/// hides the whole block. A joined city-orienteering topic (`is_join == 1`, productType 1) taps into
/// 我的队伍 · 本场招募 (`OrientLobbyTeamsView`, by activity when a team has one, else by topic).
struct TopicTeamsSource {
    let read: @MainActor (_ latitude: Double, _ longitude: Double) async -> [NearbyTeam]?
    let lobby: @MainActor (_ ownerType: Int, _ ownerID: Int, _ scope: String) -> AnyView
}

private struct TopicTeamsSourceKey: EnvironmentKey { static let defaultValue: TopicTeamsSource? = nil }
extension EnvironmentValues {
    var topicTeamsSource: TopicTeamsSource? {
        get { self[TopicTeamsSourceKey.self] }
        set { self[TopicTeamsSourceKey.self] = newValue }
    }
}

@MainActor struct TopicTeamsCard: View {
    @Environment(\.locale) private var locale
    let topic: TopicDetail
    @Environment(\.topicTeamsSource) private var source
    @State private var teams: [NearbyTeam] = []
    @State private var loadedTopic: Int?

    private var rows: [NearbyTeam] { loadedTopic == topic.id ? Array(teams.prefix(5)) : [] }
    private var canOpen: Bool { topic.isSignUp && topic.productType == 1 && source != nil }

    var body: some View {
        Group {
            if !rows.isEmpty {
                Section("topic.teams.title") {
                    // A NavigationLink, not a destination modifier: this card sits inside the topic List (lazy container).
                    if canOpen {
                        NavigationLink { lobbyDestination } label: { card }
                            .accessibilityIdentifier("topic.teams.card")
                    } else {
                        card.accessibilityElement(children: .combine).accessibilityIdentifier("topic.teams.card")
                    }
                }
            }
        }
        .task(id: topic.id) { await load() }
    }

    private var card: some View {
        let need = rows.reduce(0) { $0 + missing($1) }
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("topic.teams.count \(rows.count)").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                Spacer(minLength: CYSpacing.sm)
                if need > 0 { Text("topic.teams.need \(need)").cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.brand) }
            }
            ForEach(rows) { team in
                HStack(spacing: CYSpacing.sm) {
                    NearbyTeamFaces(count: max(1, min(3, team.memberAvatars.count)))
                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                        Text(verbatim: title(team)).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).lineLimit(1)
                        if !team.addressName.isEmpty {
                            Text(verbatim: team.addressName).cyText(.meta).foregroundStyle(CYColor.textSecondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: CYSpacing.sm)
                    VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
                        Text(verbatim: team.maxMembers > 0 ? "\(team.joinedCount)/\(team.maxMembers)" : "\(team.joinedCount)")
                            .cyText(.bodyMedium, monospacedDigit: true).foregroundStyle(CYColor.textPrimary)
                        if missing(team) > 0 {
                            Text("topic.teams.need \(missing(team))").cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.brand)
                        }
                    }
                }
            }
            if canOpen {
                Text("topic.teams.viewAll").cyText(.bodyMedium).foregroundStyle(CYColor.brand)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder private var lobbyDestination: some View {
        if let source {
            let row = rows.first { ($0.activityID ?? 0) > 0 }
            if let activity = row?.activityID { source.lobby(2, activity, topic.name) } else { source.lobby(1, topic.id, topic.name) }
        }
    }

    private func title(_ team: NearbyTeam) -> String {
        if !team.title.isEmpty { return team.title }
        if !team.activityName.isEmpty { return team.activityName }
        return String(localized: LocalizedStringResource("topic.teams.untitled", locale: locale))
    }

    private func missing(_ team: NearbyTeam) -> Int { team.maxMembers > team.joinedCount ? team.maxMembers - team.joinedCount : 0 }

    private func load() async {
        teams = []; loadedTopic = nil
        guard let source else { return }
        let point = topic.chapters.lazy.flatMap(\.nodes).first { node in
            guard let lat = node.latitude, let lng = node.longitude else { return false }
            return lat.isFinite && lng.isFinite && (lat != 0 || lng != 0)
        }
        guard let latitude = point?.latitude, let longitude = point?.longitude else { return }
        let captured = topic.id
        guard let result = await source.read(latitude, longitude), !Task.isCancelled, captured == topic.id else { return }
        teams = result.filter { $0.topicID == captured }
        loadedTopic = captured
    }
}
