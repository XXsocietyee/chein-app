import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// R11-MEM-17-3: MP order detail 下次再来 (scene-member-order-detail/index.wxml:314-327; view model index.js:164-180).
/// 关注主办俱乐部 posts `api/user/follow/action` like `followClub` (index.js:879-903) and marks followed only on a 200.
/// 加入俱乐部 opens the club page, which sends join / apply through `ClubActionCoordinator` (as the order club row does).
/// The next edition opens the topic page (`goNextEdition`, index.js:935-940); without one the row only says when it appears.
struct ExploreCompletionRevisitSection: View {
    let revisit: ExploreCompletionSnapshot.Revisit
    let clubID: Int
    @EnvironmentObject private var session: AppSession
    @State private var followedNow = false
    @State private var following = false
    @State private var followFailed = false

    var body: some View {
        Section("exploreRevisit.title") {
            clubNameText.font(.headline)
            followRow
            joinRow
            nextRow
        }
    }

    private var clubNameText: Text {
        if let name = revisit.clubName, !name.isEmpty { return Text(verbatim: name) }
        return Text("exploreRevisit.hostClub")
    }

    @ViewBuilder private var followRow: some View {
        if revisit.followed || followedNow {
            Label("exploreRevisit.followed", systemImage: "checkmark")
        } else if let leader = revisit.clubLeaderMemberID, leader > 0 {
            Button("orderDetail.club.follow") { Task { await follow(leader) } }
                .disabled(following)
                .accessibilityIdentifier("exploreRevisit.follow")
            if followFailed { Text("exploreRevisit.followFailed").font(.footnote).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var joinRow: some View {
        if revisit.joined {
            Label("exploreRevisit.joined", systemImage: "person.2.fill")
        } else if session.clubActionCoordinator.isConfigured {
            NavigationLink {
                ClubDetailView(
                    id: clubID,
                    reader: session,
                    actionCoordinator: session.clubActionCoordinator,
                    management: session.clubManagementContext,
                    community: session.clubCommunityContext,
                    publicRoster: session.clubPublicRosterReader
                )
            } label: {
                Label("exploreRevisit.join", systemImage: "person.badge.plus")
            }
            .accessibilityIdentifier("exploreRevisit.join")
        }
    }

    @ViewBuilder private var nextRow: some View {
        if let next = revisit.nextEdition {
            NavigationLink {
                SessionTopicDetailView(id: next.topicID, session: session)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    if let name = next.name, !name.isEmpty { Text(verbatim: name) } else { Text("exploreRevisit.nextFallback") }
                    if let date = next.startDate { startText(date).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .accessibilityIdentifier("exploreRevisit.next")
        } else {
            Text("exploreRevisit.nextPending").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func startText(_ time: ExploreCompletionTime) -> some View {
        switch time {
        case .text(let raw): if !raw.isEmpty { Text(verbatim: raw) }
        case .milliseconds(let value):
            Text(Date(timeIntervalSince1970: TimeInterval(value) / 1_000), style: .date)
        }
    }

    private func follow(_ memberID: Int) async {
        guard !following, let base = session.currentRuntimeDependencyContext?.baseURL else { return }
        following = true
        defer { following = false }
        let service = MemberRound2Service(baseURL: base, token: { [weak session] in session?.token }, transport: session.runtimeHTTPTransport)
        let reply = await service.followClubOwner(memberID: memberID)
        if case .ok = reply { followedNow = true; followFailed = false } else { followFailed = true }
    }
}
