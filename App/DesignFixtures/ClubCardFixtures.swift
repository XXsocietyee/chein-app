#if DEBUG
import SwiftUI

/// Club photo-card fixtures. Each mounts the REAL kit (`CYClubPhotoCard`, `CYClubRowCard`) on synthetic, clearly labelled values;
/// nothing ships in Release. Reach with `--design-fixture clubcards-<name>`.
///
/// | name | shows |
/// |---|---|
/// | `clubcards-home` | 你的俱乐部 row cards (owner, joined) then 发现 photo cards: Join, Apply, pending |
/// | `clubcards-directory` | directory photo cards: prominent Join, joined chip, unknown member count (em dash) |
/// | `clubcards-states` | every trailing state in one column: join, apply, pending, joined, owner, none (merchant) |
/// | `clubcards-strip` | member strip: 0, unknown, 3, 5, 120 members |
/// | `clubcards-ax` | home at accessibility Dynamic Type: footer stacks, no clipping |
enum ClubCardFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "clubcards-home": return wrap(home)
        case "clubcards-directory": return wrap(directory)
        case "clubcards-states": return wrap(states)
        case "clubcards-strip": return wrap(strip)
        case "clubcards-ax": return wrap(home.environment(\.dynamicTypeSize, .accessibility3))
        default: return nil
        }
    }

    @MainActor private static func photo(_ name: String, place: String?, count: Int?, action: CYClubCardAction, prominent: Bool = false) -> some View {
        CYClubPhotoCard(name: name, place: place, coverURL: nil, memberCount: count, seed: name, prominent: prominent,
                        action: action, onOpen: {}, onJoin: {}, identifier: "fixture.club.\(name)")
    }

    @MainActor private static var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYSectionHeader("club.home.yours")
                CYClubRowCard(name: "Riverside Runners", logoURL: nil, memberCount: 128, seed: "r1", action: .owner, onOpen: {})
                CYClubRowCard(name: "Old Town Tea Society", logoURL: nil, memberCount: 42, seed: "r2", action: .joined, onOpen: {})
                CYSectionHeader("club.home.discover").padding(.top, CYSpacing.md)
                photo("Night Market Crew", place: "Food · Chengdu", count: 125, action: .join, prominent: true)
                photo("Dawn Temple Run", place: "Sports · Hangzhou", count: 31, action: .apply)
                photo("Hidden Bookshop Crawl", place: "Culture · Shanghai", count: 9, action: .pending)
            }
            .padding(CYSpacing.pageHorizontal)
        }
    }

    @MainActor private static var directory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                photo("Rooftop Film Night", place: "Film · Shenzhen", count: 220, action: .join, prominent: true)
                photo("Binjiang Jazz Walk", place: "Music · Hangzhou", count: 64, action: .joined)
                photo("Lane 9 Makers", place: nil, count: nil, action: .join)
            }
            .padding(CYSpacing.pageHorizontal)
        }
    }

    @MainActor private static var states: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                photo("Sunset Photo Walk", place: "Open to all", count: 128, action: .join)
                photo("Harbour Chess Circle", place: "Review required", count: 128, action: .apply)
                photo("Lantern Festival Volunteers", place: "Request sent", count: 12, action: .pending)
                photo("Morning Tai Chi Park", place: "Member", count: 12, action: .joined)
                photo("West Lake Cyclists", place: "Creator", count: 12, action: .owner)
                photo("Corner Cafe Regulars", place: "No action", count: 12, action: .none)
            }
            .padding(CYSpacing.pageHorizontal)
        }
    }

    @MainActor private static var strip: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYClubMemberStrip(seed: "s0", count: 0)
            CYClubMemberStrip(seed: "su", count: nil)
            CYClubMemberStrip(seed: "s3", count: 3)
            CYClubMemberStrip(seed: "s5", count: 5)
            CYClubMemberStrip(seed: "s120", count: 120)
            Spacer()
        }
        .padding(CYSpacing.pageHorizontal)
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                Text(verbatim: "DEBUG fixture · synthetic data")
                    .font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 4).background(CYColor.bgRaised)
                view
            }
            .themeDomain(.player)
            .preferredColorScheme(.dark)
            .background(CYColor.bgPage.ignoresSafeArea())
        )
    }
}
#endif
