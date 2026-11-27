#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// D4 design fixtures (clubs / channels / me). Synthetic, in-memory data only — never shipped in Release.
/// Reachable with `--design-fixture d4-directory | d4-detail | d4-owner-detail | d4-channels | d4-settings | d4-growth | d4-leaderboard | d4-badges`.
/// The "synthetic" label lives in the nav bar title area of the host, never over content.
@MainActor struct D4ClubFixture: View {
    enum Screen { case directory, detail(owner: Bool), channels(list: Bool), confirm, joinConfirm, tab(ClubDetailTab), members }
    let screen: Screen
    @StateObject private var reader: ClubFixtureReader
    init(_ screen: Screen) {
        self.screen = screen
        let scenario: ClubFixtureScenario
        switch screen {
        case .detail(owner: true), .channels, .confirm, .joinConfirm, .tab, .members: scenario = .owner
        case .detail(owner: false): scenario = .visitor
        case .directory: scenario = .visitor
        }
        let fixtureReader = ClubFixtureReader(scenario: scenario)
        fixtureReader.designCopy = true
        _reader = StateObject(wrappedValue: fixtureReader)
    }
    private static let community = try? ClubCommunityFixture.context(identity: ClubReadIdentity(accountID: 701, epoch: 0), clubID: 81, designCopy: true)
    var body: some View {
        NavigationStack {
            switch screen {
            case .directory: ClubDirectoryView(reader: reader)
            case .detail: ClubDetailView(id: 81, reader: reader, community: Self.community)
            // mp-club r3 (18:15 sweep): the 帖文 tab reads the club's posts like the MP, not the "not in this version" state.
            case .tab(let tab): ClubDetailView(id: 81, reader: reader, community: Self.community, requestedTab: tab)
            case .members: ClubMembersView(id: 81, reader: reader)
            case .channels(let list): D4ChannelsHost(reader: reader, startInList: list)
            case .confirm: D4ConfirmHost(reader: reader, join: false)
            case .joinConfirm: D4ConfirmHost(reader: reader, join: true)
            }
        }
        .environment(\.clubEnrollmentProfile, ClubEnrollmentProfileContext(reader: reader.profileReader, squareReader: reader.squareReader))
    }
}

/// Club detail with the quit-club CYConfirmSheet presented (same content as ClubActionPanel's leave flow).
@MainActor private struct D4ConfirmHost: View {
    @ObservedObject var reader: ClubFixtureReader
    let join: Bool
    @State private var show = true
    @State private var stage = false
    @Environment(\.locale) private var locale
    var body: some View {
        ClubDetailView(id: 81, reader: reader)
            .overlay { if stage { D4JoinStage() } }
            .cySheet(isPresented: $show) {
                if join {
                    CYConfirmSheet(
                        title: String(localized: LocalizedStringResource("club.action.join", locale: locale)),
                        message: ChannelCopy.text("城瘾跑团", "City Run Club", locale: locale) + "\n" + String(localized: LocalizedStringResource("club.action.confirm.join", locale: locale)),
                        confirmTitle: String(localized: LocalizedStringResource("club.action.join", locale: locale)),
                        isDestructive: false,
                        showsJoinReward: true
                    ) { show = false; stage = true }
                } else {
                CYConfirmSheet(
                    title: ChannelCopy.text("退出「城瘾跑团」？", "Leave “City Run Club”?", locale: locale),
                    message: String(localized: LocalizedStringResource("club.action.confirm.leave", locale: locale)),
                    confirmTitle: String(localized: LocalizedStringResource("club.action.leave", locale: locale)),
                    isDestructive: true,
                    consequences: ClubLeaveConsequences.rows(locale: locale)
                ) { show = false }
                }
            }
    }
}

/// d4-join-confirm after Confirm: Join pill -> dots -> green check (same width) -> avatar flies into the strip -> chip.
/// Self-driving so a video needs no taps; success haptics are logged once (`[CYHaptic]` lines).
private struct D4JoinStage: View {
    @State private var state: CYMorphState = .idle
    var body: some View {
        ZStack {
            CYNight.ink0.opacity(0.92).ignoresSafeArea()
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text(verbatim: "City Run Club").cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                CYClubJoinStage(title: "club.action.join", state: state, seed: "club-81", memberCount: 12, identifier: "club.action.join") { state = .working }
            }
            .padding(CYSpacing.pageHorizontal)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500)); state = .working
            try? await Task.sleep(for: .milliseconds(1100)); state = .done
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
    // mp-club r3 (19:50 sweep): channel data follows the UI language (fixture data, `tt(en, zh)`); the en UI test pins stay English.
    private static func tt(_ en: String, _ zh: String) -> String {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
    }
    static let listing = ChannelDirectoryListing(
        clubID: 81,
        categories: [ChannelDirectoryCategory(id: 10, clubID: 81, name: tt("Announcements", "公告"), position: 1),
                     ChannelDirectoryCategory(id: 20, clubID: 81, name: tt("Community", "社区"), position: 2)],
        channels: [
            ChannelDirectoryEntry(id: 1001, clubID: 81, categoryID: 10, name: tt("club-news", "俱乐部动态"), kind: 2, visibility: 0, position: 1,
                                  myState: ChannelDirectoryMyState(lastReadMessageID: 1, lastReadAt: nil, notifyPref: 0, unreadCount: 2, readStateAvailable: true)),
            ChannelDirectoryEntry(id: 1002, clubID: 81, categoryID: 20, name: tt("weekend-walks", "周末徒步"), kind: 1, visibility: 0, position: 1,
                                  myState: ChannelDirectoryMyState(lastReadMessageID: 1, lastReadAt: nil, notifyPref: 0, unreadCount: 5, readStateAvailable: true)),
            ChannelDirectoryEntry(id: 1003, clubID: 81, categoryID: 20, name: tt("photo-spots", "拍照点位"), kind: 1, visibility: 0, position: 2)
        ])
    static let messages: [Int64: [ChannelTranscriptMessage]] = [
        1001: [
            .make(id: 1, conversationID: 1001, senderID: 701, senderName: tt("Fixture creator", "示例主理人"), content: tt("Saturday route is confirmed. Meet at the east gate at 9:30.", "周六路线已确定，9:30 东门集合。"), createdAt: "2026-11-07 09:00:00")
        ],
        1002: [
            .make(id: 11, conversationID: 1002, senderID: 703, senderName: tt("Mina", "米娜"), content: tt("Anyone up for the river loop this weekend?", "这周末有人一起走河边环线吗？"), createdAt: "2026-11-07 18:02:00"),
            .make(id: 12, conversationID: 1002, senderID: 703, senderName: tt("Mina", "米娜"), content: tt("It is about 6 km, flat, with a tea stop halfway.", "全程约 6 公里，路很平，中途可以喝茶歇脚。"), createdAt: "2026-11-07 18:03:00"),
            .make(id: 13, conversationID: 1002, senderID: 701, senderName: tt("Fixture creator", "示例主理人"), content: tt("Count me in. I will bring the stamp book.", "算我一个，我带上集邮册。"), createdAt: "2026-11-07 18:10:00"),
            .make(id: 14, conversationID: 1002, senderID: 704, senderName: tt("Jun", "阿俊"), content: tt("Joining too!", "我也来！"), createdAt: "2026-11-07 18:12:00")
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
    enum Screen { case settings, growth, growthFailure, growthOffline, leaderboard, badges, badgesEmpty, badgesError, stamps, stampsEmpty }
    let screen: Screen
    @State private var growth = GrowthCenterFixtureReader(scenario: .content)
    @State private var growthFailure = GrowthCenterFixtureReader(scenario: .failure)
    @State private var growthOffline = GrowthCenterFixtureReader(scenario: .network)
    var body: some View {
        switch screen {
        case .settings: SettingsView().environmentObject(AppSession()).environmentObject(NativeOriginalUnreadBadgeState())
        case .growth: NavigationStack { GrowthCenterView(reader: growth) }
        case .growthFailure: NavigationStack { GrowthCenterView(reader: growthFailure) }
        case .growthOffline: NavigationStack { GrowthCenterView(reader: growthOffline) }
        case .leaderboard: NavigationStack { GrowthLeaderboardView(reader: growth) }
        case .badges: NavigationStack { ObjectBadgeWallView(reader: ProfileFixtureReader(.success)) }
        case .badgesEmpty: NavigationStack { ObjectBadgeWallView(reader: ProfileFixtureReader(.empty)) }
        case .badgesError: NavigationStack { ObjectBadgeWallView(reader: ProfileFixtureReader(.error)) }
        case .stamps: NavigationStack { RoamStampAlbumView(reader: RoamExperienceFixtureReader(scenario: .content)) }
        case .stampsEmpty: NavigationStack { RoamStampAlbumView(reader: RoamExperienceFixtureReader(scenario: .empty)) }
        }
    }
}

/// Club enrollment / governance workspace / operations through the existing synthetic access fixtures (labelled, DEBUG only).
@MainActor struct D4ClubOpsFixture: View {
    enum Screen { case enroll, governance, operations(create: Bool), operationsFacts(unknown: Bool) }
    let screen: Screen
    @State private var access = ClubGovernanceFixtureAccess()
    @State private var opsAccess = ClubOperationsFixtureAccess(scenario: .owner)
    @State private var governance: ClubGovernanceCoordinator?
    @State private var ops: ClubOperationsCoordinator?
    var body: some View {
        NavigationStack {
            if let governance, let ops {
                switch screen {
                case .enroll:
                    ClubEnrollmentView(clubID: 81, focusTopicID: nil, identity: access.identity, access: access, coordinator: governance)
                case .governance:
                    ClubGovernanceWorkspaceView(clubID: 81, identity: access.identity, access: access, coordinator: governance)
                case .operations(let create):
                    ClubOperationsWorkspaceView(target: create ? .create : .club(81), identity: opsAccess.identity, access: opsAccess, coordinator: ops)
                case .operationsFacts(let unknown):
                    // Edit facts over `ClubEditPage`: known counts, or an owner body that omits them (em dash).
                    ClubOperationsWorkspaceView(target: .club(81), identity: opsAccess.identity, access: opsAccess, coordinator: ops)
                        .environment(\.clubEditDetailBody, { _ in Data((unknown ? ClubEditFixtureData.missingQuota : ClubEditFixtureData.owner).utf8) })
                }
            } else { ProgressView() }
        }
        .task {
            // mp-club r3 (20:25 sweep): the enroll roster's topic name follows the UI language, like the other club fixtures.
            if case .enroll = screen, Locale.preferredLanguages.first?.hasPrefix("zh") == true {
                access.overrideValue[.topics] = ClubGovernanceFixtures.json(#"[{"id":91,"name":"示例主题","signupCount":8}]"#)
            }
            governance = ClubGovernanceCoordinator(access: access)
            ops = ClubOperationsCoordinator(access: opsAccess)
        }
    }
}
#endif
