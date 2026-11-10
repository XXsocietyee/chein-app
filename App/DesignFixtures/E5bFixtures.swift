#if DEBUG
import SwiftUI

/// e5b signature-moment fixtures (synthetic, debug only):
/// `e5b-unlock`, `e5b-stamp`, `e5b-checkin`, `e5b-badge-wall`, `e5b-join`.
private func tt(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}

struct E5bMomentFixture: View {
    enum Kind { case unlock, stamp, checkIn }
    let kind: Kind
    var body: some View {
        Group {
            switch kind {
            case .unlock:
                CYCelebrationMoment(kind: .badge, seed: "night-owl", symbol: "moon.stars.fill",
                                    title: Text(verbatim: tt("Badge unlocked", "徽章已解锁")),
                                    message: Text(verbatim: tt("Night Owl: you explored after dark three times.", "夜行者：你在夜间探索了三次。")),
                                    primaryTitle: "Done", onPrimary: {})
            case .stamp:
                CYCelebrationMoment(kind: .stamp, seed: "lantern-gate", symbol: "mappin.and.ellipse",
                                    title: Text(verbatim: tt("Stamp collected", "盖章成功")),
                                    message: Text(verbatim: tt("Lantern Gate is now in your passport.", "灯笼门已收入你的漫游护照。")),
                                    primaryTitle: "Done", onPrimary: {})
            case .checkIn:
                CYCelebrationMoment(kind: .checkIn, seed: "check-in", symbol: "checkmark.circle.fill",
                                    title: Text(verbatim: tt("Checked in", "签到成功")),
                                    message: Text(verbatim: tt("Day 4 in a row. See you tomorrow.", "已连续签到 4 天，明天见。")),
                                    primaryTitle: "Done", onPrimary: {})
            }
        }
        .themeDomain(.player)
        .preferredColorScheme(.dark)
    }
}

/// Badge collection grid: real `ObjectBadgeWallBadgeLabel` wall tiles in a two-column grid, earned and locked.
struct E5bBadgeWallFixture: View {
    private let badges: [ProfileBadgeSelection]
    init() {
        let json = #"[{"badgeCode":"A","badgeName":"Night Owl","category":"EXPLORE","unlocked":true,"unlockTime":"2026-10-01 10:00:00"},{"badgeCode":"B","badgeName":"First Stamp","category":"EXPLORE","unlocked":true},{"badgeCode":"C","badgeName":"Market Regular","category":"FOOD","unlocked":true},{"badgeCode":"D","badgeName":"Ten Spots","category":"EXPLORE","unlocked":false},{"badgeCode":"E","badgeName":"Club Founder","category":"SOCIAL","unlocked":false},{"badgeCode":"F","badgeName":"Rainy Day Walker","category":"EXPLORE","unlocked":false}]"#
        let list = (try? JSONDecoder().decode([ProfileIdentityBadge].self, from: Data(json.utf8))) ?? []
        badges = list.map { .identity($0) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    HStack(spacing: CYSpacing.lg) {
                        CYCountRing(value: 3, total: 6)
                        Text(verbatim: tt("3 of 6 collected", "已收集 3 / 6")).font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                            ObjectBadgeWallBadgeLabel(badge: badge, layout: .wall)
                        }
                    }
                }
                .padding(CYSpacing.pageHorizontal)
            }
            .cyDomainPageBackground()
            .navigationTitle(Text(verbatim: tt("Badges", "徽章")))
        }
        .themeDomain(.player)
        .preferredColorScheme(.dark)
    }
}

/// The real join welcome sheet, driven through the real presentation object with an in-memory "seen" store.
@MainActor struct E5bJoinFixture: View {
    @StateObject private var reader = ClubFixtureReader(scenario: .member)
    @StateObject private var flow = ClubWelcomePresentation(seen: E5bSeenStore())
    var body: some View {
        Group {
            if let value = flow.presentation {
                ClubMemberWelcomeSheet(value: value, close: {}, goEvents: {})
            } else {
                Color.clear
            }
        }
        .themeDomain(.player)
        .preferredColorScheme(.dark)
        .task {
            guard let club = try? await reader.clubDetail(id: 81) else { return }
            flow.consider(club: club, identity: ClubReadIdentity(accountID: 1, epoch: 0), namespace: "fixture", role: nil, active: true)
        }
    }
}

@MainActor private final class E5bSeenStore: ClubWelcomeSeenStoring {
    func hasSeen(accountID: Int, clubID: Int, namespace: String) throws -> Bool { false }
    func markSeen(accountID: Int, clubID: Int, namespace: String) throws {}
}
#endif
