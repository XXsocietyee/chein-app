#if DEBUG
import SwiftUI

/// Club photo-card fixtures. Each mounts the REAL kit (`CYClubPhotoCard`, `CYClubRowCard`) on synthetic, clearly labelled values;
/// nothing ships in Release. Reach with `--design-fixture clubcards-<name>`.
///
/// | name | shows |
/// |---|---|
/// | `clubcards-home` | 你的俱乐部 row cards (owner, joined) then 发现 photo cards: Join, Apply, pending. Continuity lab: tap a card and it zooms into the (synthetic) club detail; back returns along the same path |
/// | `clubcards-directory` | directory photo cards: prominent Join, joined chip, unknown member count (em dash) |
/// | `clubcards-states` | every trailing state in one column: join, apply, pending, joined, owner, none (merchant) |
/// | `clubcards-strip` | member strip: 0, unknown, 3, 5, 120 members |
/// | `clubcards-ax` | home at accessibility Dynamic Type: footer stacks, no clipping |
/// Card join continuity: Join -> dots -> check, the avatar flies into the strip, the count rolls, then the chip.
private struct JoinMorphCard: View {
    @State private var morph: CYMorphState = .idle
    @State private var joined = false
    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            Text(verbatim: "Synthetic: Night Market Crew").font(.footnote).foregroundStyle(.secondary)
            CYClubPhotoCard(name: "Night Market Crew", place: "Food · Chengdu", coverURL: nil, memberCount: 12, seed: "night",
                            action: joined ? .joined : .join, morph: morph, onOpen: {}, onJoin: { morph = .working },
                            identifier: "fixture.club")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(for: .milliseconds(600)); morph = .working
            try? await Task.sleep(for: .milliseconds(1000)); morph = .done
            try? await Task.sleep(for: .milliseconds(900)); joined = true
        }
    }
}

enum ClubCardFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "clubcards-home": return wrap(ClubCardsContinuityHost())
        case "clubcards-directory": return wrap(directory)
        case "clubcards-states": return wrap(states)
        case "clubcards-strip": return wrap(strip)
        case "clubcards-join": return wrap(JoinMorphCard())
        case "clubcards-ax": return wrap(home.environment(\.dynamicTypeSize, .accessibility3))
        default: return nil
        }
    }

    @MainActor private static func photo(_ name: String, place: String?, count: Int?, action: CYClubCardAction, prominent: Bool = false, onOpen: @escaping () -> Void = {}) -> some View {
        CYClubPhotoCard(name: name, place: place, coverURL: nil, memberCount: count, seed: name, prominent: prominent,
                        action: action, onOpen: onOpen, onJoin: onOpen, identifier: "fixture.club.\(name)")
    }

    /// The Club home list with the real kit cards. `open` receives a club id; each card is a zoom source for that id.
    @MainActor fileprivate static func homeList(open: @escaping (Int) -> Void) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYClubRowCard(name: "Riverside Runners", logoURL: nil, memberCount: 128, seed: "r1", action: .owner, onOpen: { open(1) }, identifier: "fixture.club.Riverside Runners")
                    .cyHeroSourceInherited(1)
                CYClubRowCard(name: "Old Town Tea Society", logoURL: nil, memberCount: 42, seed: "r2", action: .joined, onOpen: { open(2) }, identifier: "fixture.club.Old Town Tea Society")
                    .cyHeroSourceInherited(2)
                photo("Night Market Crew", place: "Food · Chengdu", count: 125, action: .join, prominent: true, onOpen: { open(3) })
                    .cyHeroSourceInherited(3)
                photo("Dawn Temple Run", place: "Sports · Hangzhou", count: 31, action: .apply, onOpen: { open(4) })
                    .cyHeroSourceInherited(4)
                photo("Hidden Bookshop Crawl", place: "Culture · Shanghai", count: 9, action: .pending, onOpen: { open(5) })
                    .cyHeroSourceInherited(5)
            }
            .padding(CYSpacing.pageHorizontal)
        }
    }

    @MainActor private static var home: some View { homeList { _ in } }

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
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 4).background(.bar)
                view
            }
            .themeDomain(.player)
        )
    }
}

/// `clubcards-home` host: same list, inside a stack, pushing a synthetic club detail (id 81 on the fixture reader for every card).
@MainActor private struct ClubCardsContinuityHost: View {
    @Namespace private var hero
    @StateObject private var reader = ClubFixtureReader(scenario: .visitor)
    @State private var opened: Int?
    var body: some View {
        NavigationStack {
            ClubCardFixtures.homeList { opened = $0 }
                .cyHeroNamespace(hero)
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $opened) { id in
                    ClubDetailView(id: 81, reader: reader)
                        .cyHeroDestinationWithFallback(id, in: hero)
                }
        }
        .environment(\.clubEnrollmentProfile, ClubEnrollmentProfileContext(reader: reader.profileReader, squareReader: reader.squareReader))
    }
}
#endif
