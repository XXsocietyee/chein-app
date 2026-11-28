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
                                    primaryTitle: LocalizedStringKey(tt("Done", "完成")), onPrimary: {})
            case .stamp:
                CYCelebrationMoment(kind: .stamp, seed: "lantern-gate", symbol: "mappin.and.ellipse",
                                    title: Text(verbatim: tt("Stamp collected", "盖章成功")),
                                    message: Text(verbatim: tt("Lantern Gate is now in your passport.", "灯笼门已收入你的漫游护照。")),
                                    primaryTitle: LocalizedStringKey(tt("Done", "完成")), onPrimary: {})
            case .checkIn:
                CYCelebrationMoment(kind: .checkIn, seed: "check-in", symbol: "checkmark.circle.fill",
                                    title: Text(verbatim: tt("Checked in", "签到成功")),
                                    message: Text(verbatim: tt("Day 4 in a row. See you tomorrow.", "已连续签到 4 天，明天见。")),
                                    primaryTitle: LocalizedStringKey(tt("Done", "完成")), onPrimary: {})
            }
        }
        .themeDomain(.player)
        // a11y-dt r3: follows the system appearance (18:15 rule); the map placeholder and title adapt, so contrast holds in both.
    }
}

/// Badge collection grid: real `ObjectBadgeWallBadgeLabel` wall tiles in the real `CYCollectionGrid` (one column at accessibility sizes), earned and locked.
struct E5bBadgeWallFixture: View {
    @State private var reader: AlbumBadgeFixtureReader
    init() {
        let names = [tt("Night Owl", "夜猫子"), tt("First Stamp", "第一枚印章"), tt("Market Regular", "菜场常客"),
                     tt("Ten Spots", "十处打卡"), tt("Club Founder", "俱乐部创始人"), tt("Rainy Day Walker", "雨天漫步者")]
        let hints = [tt("Check in at 10 spots", "在 10 个地点打卡"), tt("Create a club", "创建一个俱乐部"),
                     tt("Finish a roam on a rainy day", "在雨天完成一次漫游")]
        let json = #"[{"badgeCode":"A","badgeName":"\#(names[0])","category":"EXPLORE","unlocked":true,"unlockTime":"2026-10-01 10:00:00"},{"badgeCode":"B","badgeName":"\#(names[1])","category":"EXPLORE","unlocked":true,"unlockTime":"2026-09-12 16:30:00"},{"badgeCode":"C","badgeName":"\#(names[2])","category":"FOOD","unlocked":true,"unlockTime":"2026-08-03 09:15:00"},{"badgeCode":"D","badgeName":"\#(names[3])","category":"EXPLORE","unlockHint":"\#(hints[0])","unlocked":false},{"badgeCode":"E","badgeName":"\#(names[4])","category":"SOCIAL","unlockHint":"\#(hints[1])","unlocked":false},{"badgeCode":"F","badgeName":"\#(names[5])","category":"EXPLORE","unlockHint":"\#(hints[2])","unlocked":false}]"#
        let list = (try? JSONDecoder().decode([ProfileIdentityBadge].self, from: Data(json.utf8))) ?? []
        _reader = State(initialValue: AlbumBadgeFixtureReader(variant: .allLocked, identityRows: list))
    }
    // mp-mine r3 (sweep b954de71c): the sweep drew a hand-built copy of the wall (bare ScrollView, caption headers at the
    // edge) that the app never ships. The fixture now mounts the real `ObjectBadgeWallView` (grouped List: ring header,
    // 已点亮, 未解锁) on the same bilingual rows, so the sweep and the AX5 variant show the shipped page.
    var body: some View {
        NavigationStack {
            ObjectBadgeWallView(reader: reader)
        }
        .themeDomain(.player)
        // mp-mine r3 (18:15 rule): fixtures follow the system appearance, no forced scheme.
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

/// W3-8 accessibility sweep fixtures (synthetic, debug only): `a11y-roam-ax5` (map chrome at AX5), `a11y-passport-ax5`
/// (passport page at AX5), `a11y-badges-ax5` (badge grid at AX5 with a locked tile).
struct A11yRoamAX5Fixture: View {
    var body: some View {
        CYMapScaffold(detent: .compact, peek: AnyView(
            HStack(spacing: CYSpacing.sm) {
                Text(verbatim: tt("Nearby activities", "附近活动")).cyText(.bodyMedium).foregroundStyle(.primary)
                Spacer(minLength: 0)
                // a11y-dt r3 (22:11 sweep): a bare "—" read as a placeholder shown as data; the peek states the count (P29).
                Text(verbatim: "2").cyText(.bodyMedium, monospacedDigit: true).foregroundStyle(.primary)
                    .accessibilityLabel(Text(verbatim: tt("2 nearby", "附近 2 个")))
                Image(systemName: "chevron.up").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
            }
            // a11y-dt r3 (23:07 sweep): title was black text on the black panel in light mode and "2" grey on black;
            // same material + semantic foregrounds as the real roam peek (RoamBrowserView.peekLine).
            .padding(.horizontal, CYSpacing.lg).frame(maxWidth: .infinity, minHeight: 44)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            .padding(.horizontal, CYSpacing.md)
        ), map: { CYMapPlaceholder() }, controls: {
            HStack(alignment: .center) {
                Text(verbatim: tt("Roam", "漫游")).cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.6).layoutPriority(1).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                CYGlassLabel(systemImage: "ellipsis")
            }
        }, floating: {
            HStack(spacing: CYSpacing.xxl) {
                CYGlassLabel(systemImage: "info")
                CYGoLabel()
                CYGlassLabel(systemImage: "map")
            }
        }, panel: { Color.clear })
        .environment(\.dynamicTypeSize, .accessibility5)
        .themeDomain(.player)
        // a11y-dt r3: follows the system appearance (18:15 rule); the map placeholder and title adapt, so contrast holds in both.
    }
}

/// a11y-dt r3 (20:55 sweep): `a11y-passport-ax5` mounts the passport page (stamp ring, badge rail, action capsules)
/// at AX5; the badge wall at AX5 lives under `a11y-badges-ax5`.
struct A11yPassportAX5Fixture: View {
    var body: some View {
        IAPassportFixture(count: 3, badges: [
            PassportBadge(id: 0, name: iaFixtureText("Night Owl", "夜猫子")),
            PassportBadge(id: 1, name: iaFixtureText("First Stamp", "第一枚印章"))
        ], badgeTotal: 6)
            .environment(\.dynamicTypeSize, .accessibility5)
    }
}

struct A11yBadgesAX5Fixture: View {
    var body: some View {
        E5bBadgeWallFixture()
            .environment(\.dynamicTypeSize, .accessibility5)
    }
}
#endif
