import SwiftUI

/// MP shelf art (`pages/templatedetail/shelf/art.js` THEMES, `shelf/game-covers.js` GAMES): topics bind by name and plays by
/// title, never by id (seed reruns move ids). The MP shows the bundled cover even when the server sends an `imgUrl`
/// ("包内图打开就能显示，不依赖接口回来的 imgUrl"), so a matched title always uses the MP asset.
enum TemplateShelfArt {
    /// `art.js` THEMES keys, in table order (`themeKey` takes the first prefix match).
    static let topicNames = ["城市藏宝猎人", "异常事务局：不存在的坐标", "末日广播：最后一座中继站", "时间污染：被删除的今天", "风味巡游",
                             "不惑之年", "预制人生", "高温末日逃生", "上海像一部旧电影", "生活不掉线", "一起动起来", "咖啡散步", "茶里偷闲",
                             "周末做点东西", "今天认真约会", "朋友别只在群里", "穿出新心情", "夜猫子城市生活"]
    /// `art.js` `themeKey`: exact name first, then a name with a version suffix (「预制人生 · 四站试玩版」).
    static func topicKey(_ name: String?) -> String? {
        let text = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if topicNames.contains(text) { return text }
        return topicNames.first { text.hasPrefix($0) }
    }
    /// `art.js` `topicArt(name).cover`: topic template name → `covers/topic/<slug>.jpg`.
    static func topicCover(_ name: String?) -> Image? {
        switch topicKey(name) ?? "" {
        case "城市藏宝猎人": return MPAsset.BannerCover.pagesTemplatedetailArtCoversTopicTreasureHunter
        case "异常事务局：不存在的坐标": return MPAsset.BannerCover.anomalyCoordinate
        case "末日广播：最后一座中继站": return MPAsset.BannerCover.apocalypseBroadcast
        case "时间污染：被删除的今天": return MPAsset.BannerCover.timePollution
        case "风味巡游": return MPAsset.BannerCover.pagesTemplatedetailArtCoversTopicFlavorTour
        case "不惑之年": return MPAsset.BannerCover.pagesTemplatedetailArtCoversTopicMidlifeDay
        case "预制人生": return MPAsset.BannerCover.prebuiltLife
        case "高温末日逃生": return MPAsset.BannerCover.heatEscape
        case "上海像一部旧电影": return MPAsset.BannerCover.pagesTemplatedetailArtCoversTopicOldMovie
        case "生活不掉线": return MPAsset.BannerCover.lifeBackup
        case "一起动起来": return MPAsset.BannerCover.feMove
        case "咖啡散步": return MPAsset.BannerCover.feCoffee
        case "茶里偷闲": return MPAsset.BannerCover.feTea
        case "周末做点东西": return MPAsset.BannerCover.feCraft
        case "今天认真约会": return MPAsset.BannerCover.feDate
        case "朋友别只在群里": return MPAsset.BannerCover.feFriends
        case "穿出新心情": return MPAsset.BannerCover.feStyle
        case "夜猫子城市生活": return MPAsset.BannerCover.feNight
        default: return nil
        }
    }

    /// `art.js` FEATURED_GAMES order: the 玩法 tab's top paging rail.
    static let featuredGameTitles = ["一桌任务宾果", "分支故事接力", "招牌菜限时盲猜", "闭眼味觉师", "城市取景任务", "小队竞速点亮",
                                     "拍下这一刻", "咖啡风味人格"]
    /// `game-covers.js` GAMES: the 25 shelf plays, title → `covers/game/<slug>.jpg`.
    static func gameCover(_ title: String?) -> Image? {
        switch (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
        case "今晚的暗号": return MPAsset.BannerCover.secretCode
        case "老板的秘密题": return MPAsset.BannerCover.secretQuestion
        case "拍下这一刻": return MPAsset.BannerCover.photoMoment
        case "收集这枚风味印章": return MPAsset.BannerCover.flavorStamp
        case "新品盲测局": return MPAsset.BannerCover.blindTest
        case "今日搭配任务": return MPAsset.BannerCover.styleMission
        case "集合点亮": return MPAsset.BannerCover.gather
        case "小队竞速点亮": return MPAsset.BannerCover.teamRace
        case "街角谜题": return MPAsset.BannerCover.streetPuzzle
        case "城市取景任务": return MPAsset.BannerCover.cityCamera
        case "城市接力棒": return MPAsset.BannerCover.relay
        case "今日角色任务": return MPAsset.BannerCover.roleMission
        case "招牌菜限时盲猜": return MPAsset.BannerCover.signatureDish
        case "咖啡风味人格": return MPAsset.BannerCover.coffeePersonality
        case "分支故事接力": return MPAsset.BannerCover.branchStory
        case "细节观察挑战": return MPAsset.BannerCover.detailObservation
        case "一桌任务宾果": return MPAsset.BannerCover.tableBingo
        case "小队能量接力": return MPAsset.BannerCover.teamEnergy
        case "闭眼味觉师": return MPAsset.BannerCover.pagesTemplatedetailArtCoversGameBlindTaste
        case "沉默点单": return MPAsset.BannerCover.pagesTemplatedetailArtCoversGameSilentOrder
        case "便利店调酒师": return MPAsset.BannerCover.pagesTemplatedetailArtCoversGameDiyDrink
        case "治愈音乐角": return MPAsset.BannerCover.pagesTemplatedetailArtCoversGameMusicCorner
        case "午夜电台": return MPAsset.BannerCover.pagesTemplatedetailArtCoversGameMidnightRadio
        case "低碳行动": return MPAsset.BannerCover.pagesTemplatedetailArtCoversGameLowCarbon
        case "今日城市签": return MPAsset.BannerCover.pagesTemplatedetailArtCoversGameDailyCitySign
        default: return nil
        }
    }
}

/// Hero shelf card over a bundled MP cover: the photo fills the card, with the same bottom scrim and text as `CYImageCard`.
struct TemplateShelfArtHeroCard: View {
    let art: Image
    let title: Text
    var meta: String? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let text = VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            title.cyText(.sectionTitle).lineLimit(stacked ? nil : 2)
            if let meta, !meta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(verbatim: meta).cyText(.meta).lineLimit(stacked ? nil : 2)
            }
        }
        .fixedSize(horizontal: false, vertical: stacked)
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        let photo = Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay { art.resizable().scaledToFill().accessibilityHidden(true) }
            .clipped()
        Group {
            if stacked {
                VStack(spacing: 0) {
                    photo
                    text.foregroundStyle(palette.textPrimary).background(palette.bgElevated)
                }
            } else {
                photo.overlay(alignment: .bottomLeading) {
                    text.foregroundStyle(.white)
                        .padding(.top, CYSpacing.jumbo)
                        .background(LinearGradient(stops: [.init(color: .clear, location: 0),
                                                           .init(color: .black.opacity(contrast == .increased ? 0.92 : 0.78), location: 0.7)],
                                                    startPoint: .top, endPoint: .bottom))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .shadow(color: palette.cardShadowColor.opacity(0.4), radius: 8, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}

/// Square thumb for a shelf row whose title has a bundled MP cover.
struct TemplateShelfArtThumb: View {
    let art: Image
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 72
    var body: some View {
        art.resizable().scaledToFill()
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}
