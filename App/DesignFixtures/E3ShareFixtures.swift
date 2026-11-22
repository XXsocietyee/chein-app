#if DEBUG
import SwiftUI

/// e3 share fixtures. Every case mounts the REAL share surface on a synthetic, offline reader:
/// `--design-fixture e3-share-walk | e3-share-medal | e3-share-route | e3-share-activity | e3-share-templates`.
/// Nothing here reaches a Release build; the generated cover art carries CYCoverArt's DEBUG label.
enum E3ShareFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e3-share-walk":
            let reader = E3ShareFixtureReader()
            guard let record = try? reader.history().first else { return nil }
            return wrap(NavigationStack { RoamHistoryShareView(record: record, reader: reader) })
        case "e3-share-medal":
            let reader = E3ShareFixtureReader()
            guard let record = try? reader.history().first, let medal = RoamMedalShareSelection(record: record, kind: .journey) else { return nil }
            return wrap(NavigationStack { RoamMedalShareView(selection: medal, reader: reader) })
        case "e3-share-route":
            // REAL route detail with the share entry in its toolbar (E1 synthetic route reader).
            return wrap(NavigationStack { OfficialRouteDetailView(reader: E1Fixture.routeReader, routeID: "1") })
        case "e3-share-route-card":
            return wrap(CatalogShareCardView(content: E3ShareFixtureContent.route, tint: .ember))
        case "e3-share-activity":
            // REAL activity detail with the share entry in its toolbar (E1 synthetic activity reader).
            return wrap(NavigationStack { ActivityDetailView(id: 101, reader: ActivityFixtureReader(scenario: .reviews), registrationEnabled: true) })
        case "e3-share-activity-card":
            return wrap(CatalogShareCardView(content: E3ShareFixtureContent.activity, tint: .sunset))
        case "e3-share-templates":
            return wrap(E3ShareTemplateGallery())
        default: return nil
        }
    }
    @MainActor private static func wrap<V: View>(_ v: V) -> AnyView { AnyView(v.roleTheme(.player)) }
}

/// Synthetic saved walk with a medal and a 16-point loop, so the clipped sketch has a shape to show.
@MainActor final class E3ShareFixtureReader: RoamExperienceReading {
    private let scope = try! RoamHistoryScope(market: "cn", deployment: URL(string: "https://example.com/synthetic-share")!, accountID: 901)
    var identity: RoamExperienceIdentity? { RoamExperienceIdentity(scope: scope, epoch: 1) }
    var isConfigured: Bool { true }
    var isOfflineExample: Bool { true }
    private static let json = #"""
    [{"ts":1760256000000,"serverSessionID":9901,"zone":"Dashilar hutongs (offline example)","distance":"4.2","shops":3,"explorePct":62,"durSec":4215,
      "medal":"Lantern Night Walker","shopMedalName":"Courtyard Regular","photos":[],"pois":[],
      "track":[{"lat":39.8940,"lng":116.3900},{"lat":39.8946,"lng":116.3912},{"lat":39.8955,"lng":116.3918},{"lat":39.8961,"lng":116.3931},
               {"lat":39.8958,"lng":116.3947},{"lat":39.8949,"lng":116.3956},{"lat":39.8940,"lng":116.3962},{"lat":39.8931,"lng":116.3955},
               {"lat":39.8926,"lng":116.3941},{"lat":39.8929,"lng":116.3926},{"lat":39.8921,"lng":116.3915},{"lat":39.8926,"lng":116.3903},
               {"lat":39.8934,"lng":116.3897},{"lat":39.8941,"lng":116.3889},{"lat":39.8949,"lng":116.3885},{"lat":39.8957,"lng":116.3880}]}]
    """#
    func history() throws -> [RoamHistoryRecord] { try JSONDecoder().decode([RoamHistoryRecord].self, from: Data(Self.json.utf8)) }
    func sessionFact(_ query: RoamRecoveryQuery) async throws -> RoamSessionFact { throw APIError.notConfigured }
    func album(page: Int, pageSize: Int) async throws -> RoamAlbumPage { throw APIError.notConfigured }
    func tilePage(afterID: Int, limit: Int) async throws -> RoamTileMemoryPage { throw APIError.notConfigured }
    func shopBadge() async throws -> RoamShopBadge? { nil }
}

enum E3ShareFixtureContent {
    static var route: CYShareCardContent {
        let lat = [39.940, 39.9412, 39.9425, 39.9431, 39.9440, 39.9433]
        let lng = [116.400, 116.4021, 116.4035, 116.4058, 116.4072, 116.4094]
        return CYShareCardContent(kind: .route, eyebrow: Locale.current.pick("官方路线", "Official route"), title: "Old Town Lantern Walk (offline example)",
                                  subtitle: nil, place: "Beijing",
                                  stats: [CYShareStat(Locale.current.pick("用时", "Duration"), "1 h 35 min"), CYShareStat(Locale.current.pick("距离", "Distance"), "3.2 km"), CYShareStat(Locale.current.pick("站点", "Stops"), "4")],
                                  silhouette: CYShareCardContent.silhouette(latitudes: lat, longitudes: lng),
                                  artSeed: "Old Town Lantern Walk", artSymbol: "point.topleft.down.to.point.bottomright.curvepath", brand: "城瘾")
    }
    static var activity: CYShareCardContent {
        CYShareCardContent(kind: .activity, eyebrow: Locale.current.pick("活动", "Event"), title: "Riverside Sketching Morning (offline example)",
                           subtitle: "Sat 18 Oct · 09:30", place: "Liangma River Park",
                           stats: [CYShareStat(Locale.current.pick("价格", "Price"), Locale.current.pick("免费", "Free")), CYShareStat(Locale.current.pick("剩余名额", "Spots left"), "6"), CYShareStat(Locale.current.pick("分类", "Category"), nil)],
                           silhouette: [CGPoint(x: 0.5, y: 0.5)],
                           artSeed: "Riverside Sketching Morning", artSymbol: "paintpalette", brand: "城瘾")
    }
    static var walk: CYShareCardContent {
        CYShareCardContent(kind: .walk, eyebrow: Locale.current.pick("漫游记忆", "Roam memory"), title: Locale.current.pick("城市漫游", "City walk"),
                           subtitle: "12 Oct 2025", place: nil,
                           stats: [CYShareStat(Locale.current.pick("总距离", "Total distance"), "4.2 km"), CYShareStat(Locale.current.pick("时长", "Duration"), "1:10"), CYShareStat(Locale.current.pick("探店", "Shops visited"), "3"), CYShareStat(Locale.current.pick("探索度", "Explored"), nil)],
                           silhouette: [CGPoint(x: 0.12, y: 0.78), CGPoint(x: 0.28, y: 0.42), CGPoint(x: 0.47, y: 0.5), CGPoint(x: 0.63, y: 0.22), CGPoint(x: 0.88, y: 0.3)],
                           artSeed: "walk-1760256000000", artSymbol: "figure.walk", caption: Locale.current.pick("最后一站的饺子最好吃。", "Best dumplings on the last stop."), brand: "城瘾")
    }
    static var medal: CYShareCardContent {
        CYShareCardContent(kind: .medal, eyebrow: Locale.current.pick("徽章到手", "Medal earned"), title: "Lantern Night Walker",
                           subtitle: Locale.current.pick("已保存的漫游勋章 · 2025年10月12日", "Saved journey medal · 12 Oct 2025"), place: nil, showsPlace: false,
                           artSeed: "medal-Lantern Night Walker", artSymbol: "medal.fill", brand: "城瘾")
    }
}

/// Every template at both ratios, for the four content kinds. Pure review surface.
private struct E3ShareTemplateGallery: View {
    @Environment(\.locale) private var locale
    private let tints: [CYShareCardTint] = [.ink, .ember, .ocean, .moss]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    ForEach(Array([E3ShareFixtureContent.walk, E3ShareFixtureContent.route, E3ShareFixtureContent.activity, E3ShareFixtureContent.medal].enumerated()), id: \.offset) { index, content in
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            Text(verbatim: content.title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                            ForEach(CYShareCardRatio.allCases) { ratio in
                                ScrollView(.horizontal) {
                                    HStack(alignment: .top, spacing: CYSpacing.md) {
                                        ForEach(CYShareCardTemplate.allCases) { template in
                                            CYShareCardPreview(content: content, style: CYShareCardStyle(template: template, ratio: ratio, tint: tints[index % tints.count]))
                                                .frame(width: ratio.isStory ? 200 : 240)
                                        }
                                    }
                                }
                                .scrollIndicators(.hidden)
                            }
                        }
                    }
                    Text(verbatim: locale.pick("调试示例 · 合成数据", "DEBUG fixture · synthetic data")).cyText(.caption).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity)
                }
                .padding(CYSpacing.lg)
            }
            .background(CYColor.bgPage.ignoresSafeArea())
            .navigationTitle(Text(verbatim: locale.pick("分享卡模板", "Share card templates")))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
