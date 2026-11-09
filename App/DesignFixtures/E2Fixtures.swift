#if DEBUG
import SwiftUI

/// E2 player fixtures (play / city / stamps / badges / chapters / journey / dice). Synthetic and DEBUG-only; never in Release.
/// Reach with `--design-fixture e2-<name>`. Every screen shows a labelled "DEBUG fixture" strip above the real view.
enum E2FixtureKind: String {
    case timedStopwatch = "timed-stopwatch", timedReaction = "timed-reaction", dice, journey
    case chapters, chaptersEmpty = "chapters-empty", stampCamera = "stamp-camera", badgeDetail = "badge-detail"
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
        case .journey: JourneyContentFixtureHostView()
        case .chapters: E2ChaptersHost(empty: false)
        case .chaptersEmpty: E2ChaptersHost(empty: true)
        case .stampCamera: NavigationStack { RoamStampCameraView() }
        case .badgeDetail: E2BadgeDetailHost()
        }
    }
}

/// Readers live in @State: a reader rebuilt on every body pass changes the view owner and the list never loads.
private struct E2ChaptersHost: View {
    @State private var roam = RoamExperienceFixtureReader(scenario: .content)
    @State private var tickets: TicketWalletFixtureReader
    init(empty: Bool) { _tickets = State(initialValue: TicketWalletFixtureReader(scenario: empty ? .empty : .content)) }
    var body: some View { NavigationStack { RoamEnrolledChaptersView(roam: roam, tickets: tickets) } }
}

private struct E2BadgeDetailHost: View {
    @State private var reader = ProfileFixtureReader(.success)
    @State private var badge: ProfileBadgeSelection?
    var body: some View {
        NavigationStack {
            if let badge {
                ObjectBadgeDetailView(badge: badge, reader: reader, expectedIdentity: reader.identity)
                    .modifier(ObjectBadgeThreeDEntry(badge: badge, reader: reader, expectedIdentity: reader.identity))
            } else { CYSkeleton().padding(CYSpacing.pageHorizontal) }
        }
        .task {
            guard let wall = try? await reader.profileBadges() else { return }
            if let medal = wall.medals?.first(where: { !$0.isAchievement }) ?? wall.medals?.first { badge = .medal(medal) }
            else if let identity = wall.identities.first { badge = .identity(identity) }
        }
    }
}
#endif
