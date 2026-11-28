#if DEBUG
import SwiftUI

/// E2 player fixtures (play / city / stamps / badges / chapters / journey / dice). Synthetic and DEBUG-only; never in Release.
/// Reach with `--design-fixture e2-<name>`. Every screen shows a labelled "DEBUG fixture" strip above the real view.
enum E2FixtureKind: String {
    case timedStopwatch = "timed-stopwatch", timedReaction = "timed-reaction", dice, journey
    case npcChat = "npc-chat", badgeLocked = "badge-locked", timedResult = "timed-result"
    case chapters, chaptersEmpty = "chapters-empty", stampCamera = "stamp-camera", badgeDetail = "badge-detail"
    case cityRules = "city-rules", cityParticipation = "city-participation", cityParticipationConfirm = "city-participation-confirm", cityParticipationJoin = "city-participation-join"
    case cityNeutral = "city-neutral", cityOnsite = "city-onsite", cityArrival = "city-arrival", cityMap = "city-map", bundle, journalDiagnostic = "journal-diagnostic", passportAnniversary = "passport-anniversary", passportRecap = "passport-recap"
    case playkitQA = "playkit-qa", playkitProfile = "playkit-profile", playkitNote = "playkit-note", playkitPhoto = "playkit-photo"
    case rep3TaskPlay = "rep3-task-play", rep3TaskPlayOffline = "rep3-task-play-offline"
}

struct E2Fixture: View {
    let kind: E2FixtureKind
    var body: some View {
        VStack(spacing: 0) {
            if !isSweepPage {
                Text(verbatim: "DEBUG fixture · synthetic data")
                    .cyText(.caption).foregroundStyle(CYColor.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 4).background(CYColor.bgRaised)
            }
            content
        }
        .themeDomain(.player)
        .background(CYColor.bgPage.ignoresSafeArea())
    }

    /// mp-journey r3 (sweep 22:11 `rep3-task-play`): the swept play page renders without the debug strip.
    private var isSweepPage: Bool { kind == .rep3TaskPlay || kind == .rep3TaskPlayOffline }

    @ViewBuilder private var content: some View {
        switch kind {
        case .timedStopwatch:
            ScrollView {
                PlayKitTimedChallengeView(kind: .stopwatch, segment: .object(["targetSeconds": .integer(10)]), enabled: true, active: true,
                                          onDirty: {}, requestReview: { _, _, _ in })
            }
        case .timedReaction:
            ScrollView {
                PlayKitTimedChallengeView(kind: .reaction, segment: .object(["seconds": .integer(5)]), enabled: true, active: true,
                                          onDirty: {}, requestReview: { _, _, _ in })
            }
        case .dice:
            VStack(spacing: CYSpacing.lg) {
                DiceD20CanvasView(values: [17], kept: 17, rollMode: "normal", rolling: false)
                    .frame(height: 260)
                Text(verbatim: "17").cyText(.dataXL).monospacedDigit()
                    .foregroundStyle(CYColor.textPrimary)
            }.padding(CYSpacing.pageHorizontal)
        case .npcChat: ShopNPCFixtureView(enabled: true, seed: ["Where is the stamp hidden?"])
        case .journey: JourneyContentFixtureHostView()
        case .chapters: E2ChaptersHost(empty: false)
        case .chaptersEmpty: E2ChaptersHost(empty: true)
        case .stampCamera: NavigationStack { RoamStampCameraView() }
        case .badgeDetail: E2BadgeDetailHost(locked: false)
        case .badgeLocked: E2BadgeDetailHost(locked: true)
        case .cityRules: E2RulesHost()
        case .cityParticipation: E2ParticipationHost(stage: 0)
        case .cityParticipationConfirm: E2ParticipationHost(stage: 1)
        case .cityParticipationJoin: E2ParticipationHost(stage: 2)
        case .cityNeutral: E2NeutralHost()
        case .cityOnsite: E2OnsiteHost()
        case .cityArrival: E2ArrivalHost()
        case .cityMap: E2OrderedMapHost()
        case .bundle: E2BundleHost()
        case .journalDiagnostic: NavigationStack { List { GameJournalCompositionAndPlaySummarySectionView() }.cyGroupedSurface().navigationTitle("游戏手账").navigationBarTitleDisplayMode(.inline) }
        case .passportAnniversary: NavigationStack { RoamAnniversaryView(reader: RoamPassportToolsFixtureReader()) }
        case .passportRecap: NavigationStack { RoamMonthlyRecapView(reader: RoamPassportToolsFixtureReader()) }
        case .playkitQA: E2PlayKitHost(kind: .qa)
        case .playkitProfile: E2PlayKitHost(kind: .profile)
        case .playkitNote: E2PlayKitHost(kind: .note)
        case .playkitPhoto: E2PlayKitHost(kind: .photoCheck)
        case .timedResult:
            ScrollView {
                VStack(spacing: CYSpacing.lg) {
                    PlayTimedResultCard(outcome: true, value: "10.04 s", target: "10.00 s", delta: "+0.04 s")
                    PlayTimedResultCard(outcome: false, value: "412 ms", target: "300 ms", delta: nil)
                    PlayTimedResultCard(outcome: nil, value: "9.71 s", target: nil, delta: nil)
                }.padding(CYSpacing.pageHorizontal)
            }
        case .rep3TaskPlay:
            Rep3PlayFixtureHost(offlineFailure: false)
        case .rep3TaskPlayOffline:
            Rep3PlayFixtureHost(offlineFailure: true)
        }
    }
}

/// Immediate-result stub: the real list container only reads while the scene is foreground and never completed inside the fixture host,
/// so this renders the real rows and cover header from synthetic tickets without any reader lifecycle.
private struct E2ChaptersHost: View {
    let empty: Bool
    private var topics: [TicketWalletTicket] {
        struct Envelope: Decodable { let data: [TicketWalletTicket] }
        guard !empty,
              let routes = try? JSONDecoder().decode(Envelope.self, from: Data(TicketWalletSyntheticFixtures.routeListJSON.utf8)).data,
              let acts = try? JSONDecoder().decode(Envelope.self, from: Data(TicketWalletSyntheticFixtures.activityListJSON.utf8)).data,
              let rows = try? RoamEnrolledChaptersProjection.topics(TicketWalletSnapshot(tickets: routes + acts)) else { return [] }
        return rows
    }
    var body: some View {
        NavigationStack {
            List {
                CYCoverHeaderSection("roam.chapters.title", symbol: "book.pages.fill", seed: "chapters")
                if topics.isEmpty { CYEmptyState(systemImage: "map", "roam.chapters.empty") }
                ForEach(topics) { ticket in
                    RoamEnrolledChapterRow(ticket: ticket, showsActionNotice: ticket.action != .detail).questifyCardListRow()
                }
            }.cyGroupedSurface().navigationTitle("roam.chapters.title").navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct E2BadgeDetailHost: View {
    let locked: Bool
    @State private var reader = ProfileFixtureReader(.success)
    @State private var badge: ProfileBadgeSelection?
    @State private var summary: ObjectBadgeWallSummary?
    var body: some View {
        NavigationStack {
            if let badge {
                ObjectBadgeDetailView(badge: badge, reader: reader, expectedIdentity: reader.identity, collection: summary)
                    .modifier(ObjectBadgeThreeDEntry(badge: badge, reader: reader, expectedIdentity: reader.identity))
            } else { CYSkeleton().padding(CYSpacing.pageHorizontal) }
        }
        .task {
            guard let wall = try? await reader.profileBadges() else { return }
            summary = wall.isPartial ? nil : ObjectBadgeWallSummary(wall: wall)
            if locked, let identity = wall.identities.first(where: { !$0.unlocked }) { badge = .identity(identity) }
            else if let medal = wall.medals?.first(where: { !$0.isAchievement }) ?? wall.medals?.first { badge = .medal(medal) }
            else if let identity = wall.identities.first { badge = .identity(identity) }
        }
    }
}

/// Template 6 Play Runtime fixture (synthetic data, debug only): normal active run + offline/retryable failure.
@MainActor private struct Rep3PlayFixtureHost: View {
    let offlineFailure: Bool
    @State private var model: PlayExperienceCoordinator

    init(offlineFailure: Bool) {
        self.offlineFailure = offlineFailure
        let config = try! APIConfiguration(baseURL: URL(string: "https://fixture.example/native/")!)
        let session = try? PlayExperienceSession(accountID: 9001, epoch: 1, namespace: "synthetic-play-cn", token: "synthetic-token")
        let service = PlayExperienceService(configuration: config, transport: Rep3PlayFixtureTransport(offlineFailure: offlineFailure), enabled: [.reads, .playerCommands])
        _model = State(initialValue: PlayExperienceCoordinator(scope: .activity(41), service: service, recovery: PlayMemoryCompletionRecovery(), pausedStorage: PlayMemoryPausedStorage(), currentSession: { session }))
    }

    var body: some View {
        NavigationStack {
            PlayExperienceView(model: model)
        }
        // mp-journey r3 (sweep 23:50): hosted in `.player` like `SessionPlayRuntimeView` (play `screenDomain`), so the
        // run map follows the system appearance; `.game` forced dark while d2-play rendered light.
        .cyDomainScreen(.player)
        .task { await model.load() }
    }
}

private final class Rep3PlayFixtureTransport: HTTPTransport, @unchecked Sendable {
    let offlineFailure: Bool
    init(offlineFailure: Bool) { self.offlineFailure = offlineFailure }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let path = request.url?.path ?? ""
        if offlineFailure, path.hasSuffix("api/play/nodes") {
            throw URLError(.notConnectedToInternet)
        }
        if path.hasSuffix("api/play/nodes") {
            // mp-journey r3 (sweep 19:15): fixture data follows the UI language.
            let payload = Locale.preferredLanguages.first?.hasPrefix("zh") == true
                ? #"{"topicId":71,"topicName":"古城夜游线（离线示例）","mode":1,"registered":true,"playable":true,"total":3,"doneCount":1,"nodes":[{"nodeId":701,"name":"鼓楼驿站","address":"鼓楼东大街 12 号","done":true,"arrived":true,"validationMethod":1},{"nodeId":702,"name":"灯笼石门","address":"景山前街 18 号","done":false,"arrived":true,"needGps":true,"validationMethod":3,"question":"石拱门上方悬挂的灯笼是什么颜色？","options":{"A":"朱红灯笼","B":"青石宫灯","C":"素白纸灯"}},{"nodeId":703,"name":"白塔茶室","address":"阜成门内大街 5 号","done":false,"locked":true,"lockReason":"完成「灯笼石门」后解锁","unlockAfterNodeId":702,"validationMethod":2}]}"#
                : #"{"topicId":71,"topicName":"Old Town Night Walk (offline sample)","mode":1,"registered":true,"playable":true,"total":3,"doneCount":1,"nodes":[{"nodeId":701,"name":"Drum Tower Post","address":"12 Gulou East St","done":true,"arrived":true,"validationMethod":1},{"nodeId":702,"name":"Lantern Stone Gate","address":"18 Jingshan Front St","done":false,"arrived":true,"needGps":true,"validationMethod":3,"question":"What colour are the lanterns above the stone arch?","options":{"A":"Vermilion lanterns","B":"Blue-stone palace lamps","C":"Plain white paper lamps"}},{"nodeId":703,"name":"White Pagoda Tea Room","address":"5 Fuchengmennei St","done":false,"locked":true,"lockReason":"Unlocks after Lantern Stone Gate","unlockAfterNodeId":702,"validationMethod":2}]}"#
            return (PlayExperienceSyntheticFixtures.envelope(payload), 200)
        }
        if path.hasSuffix("api/play/route-state") {
            return (PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.route), 200)
        }
        // mp-journey r3: a solo run has no led team (MP team-progress exists=false), so no retry bar on the fixture.
        if path.hasSuffix("api/club/lead/team-progress") {
            return (PlayExperienceSyntheticFixtures.envelope(#"{"exists":false}"#), 200)
        }
        throw URLError(.notConnectedToInternet)
    }
}
#endif
