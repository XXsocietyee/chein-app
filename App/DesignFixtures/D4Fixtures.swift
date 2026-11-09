#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// D4 design fixtures (clubs / channels / me). Synthetic, in-memory data only — never shipped in Release.
/// Reachable with `--design-fixture d4-directory | d4-detail | d4-owner-detail | d4-channels | d4-settings | d4-growth | d4-leaderboard | d4-badges`.
/// The "synthetic" label lives in the nav bar title area of the host, never over content.
@MainActor struct D4ClubFixture: View {
    enum Screen { case directory, detail(owner: Bool), channels(list: Bool), confirm }
    let screen: Screen
    @StateObject private var reader: ClubFixtureReader
    init(_ screen: Screen) {
        self.screen = screen
        let scenario: ClubFixtureScenario
        switch screen {
        case .detail(owner: true), .channels, .confirm: scenario = .owner
        case .detail(owner: false): scenario = .visitor
        case .directory: scenario = .visitor
        }
        _reader = StateObject(wrappedValue: ClubFixtureReader(scenario: scenario))
    }
    var body: some View {
        NavigationStack {
            switch screen {
            case .directory: ClubDirectoryView(reader: reader)
            case .detail: ClubDetailView(id: 81, reader: reader)
            case .channels(let list): D4ChannelsHost(reader: reader, startInList: list)
            case .confirm: D4ConfirmHost(reader: reader)
            }
        }
        .environment(\.clubEnrollmentProfile, ClubEnrollmentProfileContext(reader: reader.profileReader, squareReader: reader.squareReader))
    }
}

/// Club detail with the quit-club CYConfirmSheet presented (same content as ClubActionPanel's leave flow).
@MainActor private struct D4ConfirmHost: View {
    @ObservedObject var reader: ClubFixtureReader
    @State private var show = true
    @Environment(\.locale) private var locale
    var body: some View {
        ClubDetailView(id: 81, reader: reader)
            .sheet(isPresented: $show) {
                CYConfirmSheet(
                    title: ChannelCopy.text("退出「城瘾跑团」？", "Leave “City Run Club”?", locale: locale),
                    message: appLocalized("club.action.confirm.leave", locale: locale),
                    confirmTitle: appLocalized("club.action.leave", locale: locale),
                    isDestructive: true,
                    consequences: ClubLeaveConsequences.rows(locale: locale)
                ) { show = false }
            }
    }
}

@MainActor private struct D4ChannelsHost: View {
    @ObservedObject var reader: ClubFixtureReader
    let startInList: Bool
    @State private var club: ClubRecord?
    var body: some View {
        Group {
            if let club {
                ClubChannelMessagingView(club: club, viewerMemberID: 701, viewerRoleTier: .member,
                                         listing: Self.listing, startsInChannelList: startInList, initialMessagesByChannelID: Self.messages,
                                         blockedUsersStore: D4MemoryBlockedStore())
            } else { ProgressView() }
        }
        .task { club = try? await reader.clubDetail(id: 81) }
    }
    static let listing = ChannelDirectoryListing(
        clubID: 81,
        categories: [ChannelDirectoryCategory(id: 10, clubID: 81, name: "Announcements", position: 1),
                     ChannelDirectoryCategory(id: 20, clubID: 81, name: "Community", position: 2)],
        channels: [
            ChannelDirectoryEntry(id: 1001, clubID: 81, categoryID: 10, name: "club-news", kind: 2, visibility: 0, position: 1,
                                  myState: ChannelDirectoryMyState(lastReadMessageID: 1, lastReadAt: nil, notifyPref: 0, unreadCount: 2, readStateAvailable: true)),
            ChannelDirectoryEntry(id: 1002, clubID: 81, categoryID: 20, name: "weekend-walks", kind: 1, visibility: 0, position: 1,
                                  myState: ChannelDirectoryMyState(lastReadMessageID: 1, lastReadAt: nil, notifyPref: 0, unreadCount: 5, readStateAvailable: true)),
            ChannelDirectoryEntry(id: 1003, clubID: 81, categoryID: 20, name: "photo-spots", kind: 1, visibility: 0, position: 2)
        ])
    static let messages: [Int64: [ChannelTranscriptMessage]] = [
        1001: [
            .make(id: 1, conversationID: 1001, senderID: 701, senderName: "Fixture creator", content: "Saturday route is confirmed. Meet at the east gate at 9:30.", createdAt: "2026-11-07 09:00:00")
        ],
        1002: [
            .make(id: 11, conversationID: 1002, senderID: 703, senderName: "Mina", content: "Anyone up for the river loop this weekend?", createdAt: "2026-11-07 18:02:00"),
            .make(id: 12, conversationID: 1002, senderID: 703, senderName: "Mina", content: "It is about 6 km, flat, with a tea stop halfway.", createdAt: "2026-11-07 18:03:00"),
            .make(id: 13, conversationID: 1002, senderID: 701, senderName: "Fixture creator", content: "Count me in. I will bring the stamp book.", createdAt: "2026-11-07 18:10:00"),
            .make(id: 14, conversationID: 1002, senderID: 704, senderName: "Jun", content: "Joining too!", createdAt: "2026-11-07 18:12:00")
        ]
    ]
}

private final class D4MemoryBlockedStore: ChannelBlockedUsersStoring, @unchecked Sendable {
    private var blocked: [String: Set<Int>] = [:]
    private func key(_ club: Int, _ viewer: Int) -> String { "\(club)-\(viewer)" }
    func blockedUserIDs(clubID: Int, viewerMemberID: Int) -> Set<Int> { blocked[key(clubID, viewerMemberID)] ?? [] }
    func addBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int) { blocked[key(clubID, viewerMemberID), default: []].insert(targetMemberID) }
    func removeBlockedUser(targetMemberID: Int, clubID: Int, viewerMemberID: Int) { blocked[key(clubID, viewerMemberID), default: []].remove(targetMemberID) }
}

@MainActor struct D4MeFixture: View {
    enum Screen { case settings, growth, leaderboard, badges }
    let screen: Screen
    @State private var growth = GrowthCenterFixtureReader(scenario: .content)
    var body: some View {
        switch screen {
        case .settings: SettingsView().environmentObject(AppSession()).environmentObject(NativeOriginalUnreadBadgeState())
        case .growth: NavigationStack { GrowthCenterView(reader: growth) }
        case .leaderboard: NavigationStack { GrowthLeaderboardView(reader: growth) }
        case .badges: NavigationStack { ObjectBadgeWallView(reader: ProfileFixtureReader(.success)) }
        }
    }
}
#endif
