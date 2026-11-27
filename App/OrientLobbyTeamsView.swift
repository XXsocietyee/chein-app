import SwiftUI

/// RTEAMS-1: subpackageRoam/my-teams `?tab=open&ownerType=&ownerId=&scope=` — 本场招募 from a topic's team card.
/// Reads `GET /api/orient/team/lobby` by owner; full teams are not listed (MP B3). A row opens the same team on the
/// nearby map, where 申请加入 uses the existing apply request (no new write here).
@MainActor struct OrientLobbyTeamsView: View {
    let ownerType: Int
    let ownerID: Int
    /// MP `scope`: "主题名 · 时间 场", shown under the title when present.
    var scopeTitle: String? = nil
    @EnvironmentObject private var session: AppSession
    @State private var phase: Phase = .loading
    private enum Phase { case loading, signedOut, failed, loaded([OrientSessionTeam]) }

    var body: some View {
        if NativeR2Flags.cityOrientation {
            CityOrientationTeamLobbyView(ownerType: ownerType, ownerID: ownerID, scopeTitle: scopeTitle)
        } else {
            legacyBody
        }
    }

    private var legacyBody: some View {
        List {
            if let scopeTitle, !scopeTitle.isEmpty {
                Text(verbatim: scopeTitle).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("orientLobby.scope")
            }
            switch phase {
            case .loading:
                CYSkeleton(label: "orientLobby.loading")
            case .signedOut:
                CYEmptyState(systemImage: "person.crop.circle", "orientLobby.signIn")
                    .accessibilityIdentifier("orientLobby.signIn")
            case .failed:
                CYEmptyState(systemImage: "exclamationmark.triangle", "orientLobby.failed", messageIdentifier: "orientLobby.failed",
                             actionTitle: "action.retry", actionIdentifier: "orientLobby.retry", kind: .failure) { Task { await load() } }
            case .loaded(let teams):
                let open = teams.filter { team in
                    guard let max = team.maxMembers, max > 0, let joined = team.joinedCount else { return true }
                    return joined < max
                }
                if open.isEmpty {
                    CYEmptyState(systemImage: "person.3", "orientLobby.empty")
                        .accessibilityIdentifier("orientLobby.empty")
                } else {
                    ForEach(open, id: \.teamID) { team in
                        NavigationLink {
                            SessionRoamNearbyTeamsView(focusTeamID: NearbyTeamID(team.teamID))
                        } label: { row(team) }
                        .accessibilityIdentifier("orientLobby.team.\(team.teamID)")
                    }
                }
            }
        }
        .cyGroupedSurface()
        .cyPageTitle("orientLobby.title")
        .task { await load() }
        .refreshable { await load() }
        .accessibilityIdentifier("orientLobby.screen")
    }

    private func row(_ team: OrientSessionTeam) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Group {
                if let name = team.name ?? team.title, !name.isEmpty { Text(verbatim: name) } else { Text("orientLobby.unnamed \(team.teamID)") }
            }
            .cyText(.cardTitle).lineLimit(2)
            HStack(spacing: CYSpacing.sm) {
                Group {
                    if let leader = team.leaderName, !leader.isEmpty { Text("orientLobby.leader \(leader)") } else { Text("orientLobby.leaderUnknown") }
                }
                Text(verbatim: membersText(team)).monospacedDigit()
            }
            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            Text("orientLobby.apply").cyText(.meta, weight: .semibold).foregroundStyle(.tint)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func membersText(_ team: OrientSessionTeam) -> String {
        let joined = team.joinedCount.map(String.init) ?? "—"
        guard let max = team.maxMembers, max > 0 else { return joined }
        return "\(joined)/\(max)"
    }

    private func load() async {
        guard let configuration = session.regionalConfiguration?.apiConfiguration else { phase = .failed; return }
        guard let token = session.token else { phase = .signedOut; return }
        if case .loaded = phase {} else { phase = .loading }
        let service = OrientSessionService(configuration: configuration, transport: session.runtimeHTTPTransport, contract: .currentC6)
        do { phase = .loaded(try await service.lobby(ownerType: ownerType, ownerID: ownerID, token: token)) }
        catch is CancellationError { return }
        catch APIError.unauthorized { phase = .signedOut }
        catch { phase = .failed }
    }
}
