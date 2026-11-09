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
}

struct E2Fixture: View {
    let kind: E2FixtureKind
    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "DEBUG fixture · synthetic data")
                .font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                .frame(maxWidth: .infinity).padding(.vertical, 4).background(CYColor.bgRaised)
            content
        }
        .themeDomain(.player)
        .preferredColorScheme(.dark)
        .background(CYColor.bgPage.ignoresSafeArea())
    }

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
                Text(verbatim: "17").font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit()
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
        case .timedResult:
            ScrollView {
                VStack(spacing: CYSpacing.lg) {
                    PlayTimedResultCard(outcome: true, value: "10.04 s", target: "10.00 s", delta: "+0.04 s")
                    PlayTimedResultCard(outcome: false, value: "412 ms", target: "300 ms", delta: nil)
                    PlayTimedResultCard(outcome: nil, value: "9.71 s", target: nil, delta: nil)
                }.padding(CYSpacing.pageHorizontal)
            }
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
            }.cyGroupedSurface().navigationTitle("roam.chapters.title")
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
#endif
