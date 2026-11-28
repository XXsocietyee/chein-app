#if DEBUG
import SwiftUI

/// Collection album fixtures (HERO). Every screen mounts the REAL view on a synthetic, clearly labelled reader; nothing ships in Release.
/// Reach with `--design-fixture album-<name>`; add `--uitesting-reduce-motion` to see every fallback.
///
/// | name | shows |
/// |---|---|
/// | `album-kit` | every kit piece and state: ring, pager, flip, sheen, locked, new, unlock moment |
/// | `album-stamps` | real stamp album: 8 synthetic stamps, two collected this week (new), pages + grid |
/// | `album-stamps-empty` | real stamp album, empty |
/// | `album-badges` | real badge wall (wall layout): 4 lit (one lit today, new), 4 locked silhouettes |
/// | `album-badges-new` | same wall opened straight on the badge lit today: first-open unlock moment |
/// | `album-badges-locked` | real badge wall, nothing lit yet |
/// | `album-cards` | real object cards: foil and plain cards, one still generating |
/// | `album-unlock` | the full-screen unlock moment (existing `CYCelebrationMoment`) |
enum AlbumFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "album-kit": return wrap(AlbumKitFixture())
        case "album-stamps": return wrap(NavigationStack { RoamStampAlbumView(reader: AlbumStampFixtureReader(empty: false)) })
        case "album-stamps-empty": return wrap(NavigationStack { RoamStampAlbumView(reader: AlbumStampFixtureReader(empty: true)) })
        case "album-badges": return wrap(AlbumBadgeWallFixture(variant: .mixed, openNew: false))
        case "album-badges-new": return wrap(AlbumBadgeWallFixture(variant: .mixed, openNew: true))
        case "album-badges-locked": return wrap(AlbumBadgeWallFixture(variant: .allLocked, openNew: false))
        case "album-cards": return wrap(NavigationStack { ObjectCardsView(reader: AlbumObjectCardFixtureReader(), media: AlbumFixtureArt()) })
        case "album-unlock":
            return wrap(CYCelebrationMoment(kind: .badge, seed: "album-unlock", symbol: "moon.stars.fill",
                                            title: Text(verbatim: "Night Owl"), message: Text(verbatim: "Badge unlocked · DEBUG fixture"),
                                            primaryTitle: "action.close", onPrimary: {}))
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                Text(verbatim: "DEBUG fixture · synthetic data")
                    .cyText(.caption).foregroundStyle(CYColor.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 4).background(CYColor.bgRaised)
                view
            }
            .themeDomain(.player)
            .preferredColorScheme(.dark)
            .background(CYColor.bgPage.ignoresSafeArea())
        )
    }

    /// "yyyy-MM-dd HH:mm:ss" for `daysAgo` days before now, so "new" is judged against the real clock.
    static func stamp(daysAgo: Int, hour: Int = 10) -> String {
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d %02d:00:00", parts.year ?? 2026, parts.month ?? 1, parts.day ?? 1, hour)
    }
}

// MARK: - Stamp album

/// Real `RoamStampAlbumView` reader: album pages come from this synthetic list, everything else delegates to the existing
/// offline fixture reader (so the view keeps its offline notice and generated art).
@MainActor final class AlbumStampFixtureReader: RoamExperienceReading {
    private let base = RoamExperienceFixtureReader(scenario: .content)
    private let empty: Bool
    init(empty: Bool) { self.empty = empty }
    var identity: RoamExperienceIdentity? { base.identity }
    var isConfigured: Bool { true }
    var isOfflineExample: Bool { true }
    func history() throws -> [RoamHistoryRecord] { try base.history() }
    func sessionFact(_ query: RoamRecoveryQuery) async throws -> RoamSessionFact { try await base.sessionFact(query) }
    func tilePage(afterID: Int, limit: Int) async throws -> RoamTileMemoryPage { try await base.tilePage(afterID: afterID, limit: limit) }
    func shopBadge() async throws -> RoamShopBadge? { try await base.shopBadge() }
    func album(page: Int, pageSize: Int) async throws -> RoamAlbumPage {
        try Task.checkCancellation()
        if empty { return try JSONDecoder().decode(RoamAlbumPage.self, from: Data("{\"list\":[],\"total\":0,\"pageNum\":\(page),\"pageSize\":\(pageSize)}".utf8)) }
        let rows: [(Int, String, Int)] = [
            (1041, "Old Town tea house", 1), (1040, "Riverside bookshop", 3), (1032, "Night market lanterns", 9),
            (1027, "Harbour lighthouse", 15), (1019, "Botanic glasshouse", 24), (1011, "Clock tower square", 38),
            (1004, "Hillside temple steps", 57), (1001, "First stamp · city gate", 90),
        ]
        let list = rows.map { id, caption, days in
            #"{"id":\#(id),"picUrl":"","caption":"\#(caption)","checkState":1,"createTime":"\#(AlbumFixtures.stamp(daysAgo: days))"}"#
        }.joined(separator: ",")
        return try JSONDecoder().decode(RoamAlbumPage.self, from: Data(#"{"list":[\#(list)],"total":\#(rows.count),"pageNum":\#(page),"pageSize":\#(pageSize)}"#.utf8))
    }
}

// MARK: - Badge wall

enum AlbumBadgeVariant { case mixed, allLocked }

/// Real `ObjectBadgeWallView` on a synthetic `ProfileReading`. `.mixed`: four lit identity badges (one lit today), four locked,
/// two city medals and one achievement. `.allLocked`: only locked identity badges and no medals.
@MainActor final class AlbumBadgeFixtureReader: ProfileReading {
    let variant: AlbumBadgeVariant
    /// Sweep fixtures (`e5b-badge-wall`) pass their own bilingual identity rows; no medals then.
    private let identityRows: [ProfileIdentityBadge]?
    init(variant: AlbumBadgeVariant, identityRows: [ProfileIdentityBadge]? = nil) {
        self.variant = variant
        self.identityRows = identityRows
    }
    var isConfigured: Bool { true }
    var identity: ProfileReadIdentity? { ProfileReadIdentity(accountID: 9001, epoch: 1) }
    func profileOrders() async throws -> [ProfileOrder] { throw APIError.notConfigured }
    func profileOrder(id: Int) async throws -> ProfileOrder { throw APIError.notConfigured }
    func profileParticipants() async throws -> [ProfileParticipant] { throw APIError.notConfigured }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.notConfigured }
    func profileBadges() async throws -> ProfileBadgeWall {
        try Task.checkCancellation()
        if let identityRows { return ProfileBadgeWall(identities: identityRows, medals: []) }
        let today = AlbumFixtures.stamp(daysAgo: 0)
        let identities: String
        switch variant {
        case .mixed:
            identities = #"""
            [{"badgeCode":"NIGHT_OWL","badgeName":"Night Owl","category":"EXPLORE","statement":"Ten check-ins after 10 pm.","unlockHint":"Check in ten times after 10 pm","unlocked":true,"unlockTime":"\#(today)"},
             {"badgeCode":"FIRST_STAMP","badgeName":"First Stamp","category":"EXPLORE","statement":"Your first city stamp.","unlockHint":"Collect one stamp","unlocked":true,"unlockTime":"\#(AlbumFixtures.stamp(daysAgo: 40))"},
             {"badgeCode":"MARKET_REGULAR","badgeName":"Market Regular","category":"FOOD","statement":"Five market visits.","unlockHint":"Visit five markets","unlocked":true,"unlockTime":"\#(AlbumFixtures.stamp(daysAgo: 21))"},
             {"badgeCode":"RAINY_WALKER","badgeName":"Rainy Day Walker","category":"EXPLORE","statement":"A roam in the rain.","unlockHint":"Finish a roam while it rains","unlocked":true,"unlockTime":"\#(AlbumFixtures.stamp(daysAgo: 12))"},
             {"badgeCode":"TEN_SPOTS","badgeName":"Ten Spots","category":"EXPLORE","statement":"Ten different places.","unlockHint":"Check in at ten different places","unlocked":false},
             {"badgeCode":"CLUB_FOUNDER","badgeName":"Club Founder","category":"SOCIAL","statement":"Start a club.","unlockHint":"Found a club with three members","unlocked":false},
             {"badgeCode":"EARLY_BIRD","badgeName":"Early Bird","category":"EXPLORE","statement":"Dawn check-in.","unlockHint":"Check in before 7 am","unlocked":false},
             {"badgeCode":"CITY_LOOP","badgeName":"City Loop","category":"EXPLORE","statement":"Every district in one month.","unlockHint":"Visit every district within a month","unlocked":false}]
            """#
        case .allLocked:
            identities = #"""
            [{"badgeCode":"TEN_SPOTS","badgeName":"Ten Spots","category":"EXPLORE","statement":"Ten different places.","unlockHint":"Check in at ten different places","unlocked":false},
             {"badgeCode":"CLUB_FOUNDER","badgeName":"Club Founder","category":"SOCIAL","statement":"Start a club.","unlockHint":"Found a club with three members","unlocked":false},
             {"badgeCode":"EARLY_BIRD","badgeName":"Early Bird","category":"EXPLORE","statement":"Dawn check-in.","unlockHint":"Check in before 7 am","unlocked":false},
             {"badgeCode":"NIGHT_OWL","badgeName":"Night Owl","category":"EXPLORE","statement":"Ten check-ins after 10 pm.","unlockHint":"Check in ten times after 10 pm","unlocked":false}]
            """#
        }
        let medals = variant == .mixed
            ? #"[{"templateId":921,"medalName":"Old Town enamel medal","style":"enamel","condition":"Complete the Old Town route","getTime":"\#(AlbumFixtures.stamp(daysAgo: 5))"},{"templateId":922,"medalName":"Harbour medal","condition":"Complete the Harbour route","getTime":"\#(AlbumFixtures.stamp(daysAgo: 60))"},{"templateId":930,"kind":"achievement","medalName":"100 km walked","getTime":"\#(AlbumFixtures.stamp(daysAgo: 30))"}]"#
            : "[]"
        let decoder = JSONDecoder()
        let identityRows = try decoder.decode([ProfileIdentityBadge].self, from: Data(identities.utf8))
        let medalRows = try decoder.decode([ProfileMedal].self, from: Data(medals.utf8))
        return ProfileBadgeWall(identities: identityRows, medals: medalRows)
    }
}

/// Wall in the wall layout; `openNew` pushes the badge lit today so the first-open unlock moment plays (confetti, ring, haptic).
/// The "seen" memory is cleared for that badge on each launch of this fixture so the moment is repeatable.
@MainActor struct AlbumBadgeWallFixture: View {
    let variant: AlbumBadgeVariant
    let openNew: Bool
    @State private var reader: AlbumBadgeFixtureReader
    @State private var newBadge: ProfileBadgeSelection?
    @State private var pushed = false
    init(variant: AlbumBadgeVariant, openNew: Bool) {
        self.variant = variant; self.openNew = openNew
        _reader = State(initialValue: AlbumBadgeFixtureReader(variant: variant))
    }
    var body: some View {
        NavigationStack {
            ObjectBadgeWallView(reader: reader)
                .navigationDestination(isPresented: $pushed) {
                    if let newBadge {
                        ObjectBadgeDetailView(badge: newBadge, reader: reader, expectedIdentity: reader.identity)
                    }
                }
        }
        .task {
            guard openNew, newBadge == nil else { return }
            let seen = UserDefaults.standard.string(forKey: "cy.album.seen") ?? ""
            UserDefaults.standard.set(seen.split(separator: "\n").filter { $0 != "identity.NIGHT_OWL" }.joined(separator: "\n"), forKey: "cy.album.seen")
            guard let wall = try? await reader.profileBadges(),
                  let fresh = wall.identities.first(where: { $0.badgeCode == "NIGHT_OWL" && $0.unlocked }) else { return }
            newBadge = .identity(fresh)
            try? await Task.sleep(for: .milliseconds(600))
            pushed = true
        }
    }
}

// MARK: - Object cards

/// Real `ObjectCardsView` reader: six synthetic cards (foil and plain, one still generating) and generated art through `AlbumFixtureArt`.
@MainActor final class AlbumObjectCardFixtureReader: ObjectCardReading {
    let scope = UUID()
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    func list(category: ObjectCardCategory) async throws -> ObjectCardCollection {
        try Task.checkCancellation()
        let json = #"""
        [{"id":"c1","title":"Brass compass","sourceUrl":"fixture://compass","caption":"Found at the harbour flea market.","category":"其他","place":"Harbour market","cardStyle":"foil","genStatus":"DONE","frames":["fixture://compass","fixture://compass-2","fixture://compass-3"]},
         {"id":"c2","title":"Tea tin","sourceUrl":"fixture://tea","caption":"Old Town tea house.","category":"食物饮料","place":"Old Town","cardStyle":"plain","genStatus":"DONE"},
         {"id":"c3","title":"Paper lantern","sourceUrl":"fixture://lantern","caption":"Night market.","category":"玩具摆件","place":"Night market","cardStyle":"foil","genStatus":"DONE"},
         {"id":"c4","title":"Second-hand novel","sourceUrl":"fixture://book","caption":"","category":"书籍文具","place":"Riverside bookshop","cardStyle":"plain","genStatus":"DONE"},
         {"id":"c5","title":"Enamel pin","sourceUrl":"fixture://pin","caption":"Still rendering the 3D card.","category":"其他","place":"Clock tower square","cardStyle":"foil","genStatus":"GENERATING"},
         {"id":"c6","title":"Canvas tote","sourceUrl":"fixture://tote","caption":"","category":"鞋包","place":"Botanic glasshouse","cardStyle":"plain","genStatus":"DONE"}]
        """#
        let cards = try JSONDecoder().decode([ObjectCard].self, from: Data(json.utf8))
        let filtered = category == .all ? cards : cards.filter { $0.category == category.rawValue }
        return try ObjectCardCollection(cards: filtered, total: filtered.count)
    }
}

/// Fixture media: renders the kit's generated cover art to PNG for any `fixture://` URL, so the layout is judged with imagery.
@MainActor final class AlbumFixtureArt: ObjectCardImageLoading {
    private static let symbols = ["safari.fill", "cup.and.saucer.fill", "lamp.table.fill", "book.closed.fill", "pin.fill", "bag.fill"]
    func image(url: String) async throws -> Data {
        guard url.hasPrefix("fixture://") else { throw ObjectCardMediaFailure.unsupportedImage }
        let seed = String(url.dropFirst("fixture://".count))
        let index = Int(CYCoverArt.stableHash(seed) % UInt64(Self.symbols.count))
        let renderer = ImageRenderer(content:
            CYCoverArt(seed: seed, symbol: Self.symbols[index], showsDebugLabel: false, cornerRadius: 0)
                .frame(width: 320, height: 320)
        )
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else { throw ObjectCardMediaFailure.unsupportedImage }
        return data
    }
}

// MARK: - Kit gallery

/// Every album piece in every state on one dark page: judge motion, locked/unlocked/new, Reduce Motion fallbacks and Dynamic Type here.
struct AlbumKitFixture: View {
    private struct Piece: Identifiable { let id: Int; let name: String; let locked: Bool; let isNew: Bool }
    private let pieces = [Piece(id: 1, name: "Night Owl", locked: false, isNew: true), Piece(id: 2, name: "First Stamp", locked: false, isNew: false),
                          Piece(id: 3, name: "Ten Spots", locked: true, isNew: false), Piece(id: 4, name: "Club Founder", locked: true, isNew: false)]
    @State private var flipped = false
    @State private var unlockMoment = 0
    @State private var unlocked = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xl) {
                    HStack(spacing: CYSpacing.lg) {
                        CYAlbumProgressRing(value: 7, total: 12, accessibilityLabel: Text(verbatim: "7 of 12 collected"))
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(verbatim: "Album kit").cyText(.display).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                            Text(verbatim: "7 of 12 collected · ring counts up").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    HStack(spacing: CYSpacing.lg) {
                        CYAlbumProgressRing(value: 0, total: nil, size: 64, accessibilityLabel: Text(verbatim: "Total unknown"))
                        Text(verbatim: "Unknown total = dim track and a dash").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    section("Pages turn on the spine")
                    CYAlbumPager(items: pieces, height: 260, pageLabel: { Text(verbatim: "Page \($0) of \($1)") }) { piece in
                        VStack(spacing: CYSpacing.md) {
                            CYFoilMedal(unlocked: !piece.locked, size: 120) {
                                CYCoverArt(seed: piece.name, showsDebugLabel: false, showsGlyph: true)
                            }
                            Text(verbatim: piece.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            CYStatusChip(verbatim: piece.locked ? "Locked" : "Collected", tone: piece.locked ? .neutral : .success)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cyAlbumCard(padding: CYSpacing.lg)
                        .cyFoilSheen(active: !piece.locked)
                        .cyLockedSilhouette(piece.locked, showsLock: false)
                        .cyNewPulse(piece.isNew, text: Text(verbatim: "New"))
                    }
                    section("Tap to flip")
                    CYFlipCard(flipped: $flipped, flipActionTitle: Text(verbatim: "Flip")) {
                        CYCoverArt(seed: "flip-front", symbol: "seal.fill", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                            .frame(height: 200).cyFoilSheen(trigger: flipped ? 0 : 1)
                    } back: {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text(verbatim: "NO. 0041").cyText(.caption).monospaced().foregroundStyle(CYColor.textTertiary)
                            Text(verbatim: "Old Town tea house").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            CYFactRow(label: Text(verbatim: "Collected on"), value: AlbumFixtures.stamp(daysAgo: 1).prefix(10).description)
                            Spacer(minLength: 0)
                            Text(verbatim: "Tap to turn back").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading).cyAlbumCard(padding: CYSpacing.lg)
                    }
                    section("Grid: unlocked foil, locked silhouette, new pulse")
                    LazyVGrid(columns: CYCollectionGrid.columns(accessibility: dynamicTypeSize.isAccessibilitySize), spacing: CYCollectionGrid.spacing) {
                        ForEach(pieces) { piece in
                            CYBadgeTile(seed: piece.name, locked: piece.locked, name: Text(verbatim: piece.name),
                                        status: Text(verbatim: piece.locked ? "Locked" : "Collected"))
                                .cyFoilSheen(active: !piece.locked)
                                .cyLockedSilhouette(piece.locked, showsLock: false)
                                .cyNewPulse(piece.isNew, text: Text(verbatim: "New"))
                        }
                    }
                    section("Unlock moment (tap the medal)")
                    HStack {
                        Spacer()
                        CYFoilMedal(unlocked: unlocked, size: 140) { CYCoverArt(seed: "unlock", symbol: "moon.stars.fill", showsDebugLabel: false) }
                            .cyUnlockCelebration(trigger: unlockMoment)
                            .onTapGesture {
                                withAnimation(CYAlbumMotion.flip) { unlocked = true }
                                unlockMoment += 1
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(Text(verbatim: unlocked ? "Night Owl, unlocked" : "Night Owl, locked. Double-tap to unlock"))
                        Spacer()
                    }
                    .padding(.vertical, CYSpacing.lg)
                }
                .padding(CYSpacing.pageHorizontal)
                .padding(.bottom, CYSpacing.xxl)
            }
            .cyDomainPageBackground()
            .cyHeroScreen()
        }
    }
    private func section(_ title: String) -> some View {
        Text(verbatim: title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
    }
}
#endif
