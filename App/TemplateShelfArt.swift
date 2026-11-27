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

    /// `art.js` FEATURED_TOPICS order.
    static let featuredTopicNames = ["异常事务局：不存在的坐标", "风味巡游", "末日广播：最后一座中继站", "上海像一部旧电影",
                                     "时间污染：被删除的今天", "城市藏宝猎人", "高温末日逃生"]
    /// MP `buildTopics`: the named featured topics first, then the rest in list order, capped at the featured count.
    static func featuredTopics(_ rows: [DiscoveryTopicTemplate]) -> [DiscoveryTopicTemplate] {
        var picked = featuredTopicNames.compactMap { name in rows.first { topicKey($0.name) == name } }
        for row in rows where !picked.contains(where: { $0.id == row.id }) { picked.append(row) }
        return Array(picked.prefix(featuredTopicNames.count))
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

    /// `art.js` `gameArt(title).prop`: the public topic stop pill uses the bundled prop, not the server `gameIcon`.
    /// An unknown title stays nil so the row draws the play symbol, the same branch as the mini-program.
    static func gameProp(_ title: String?) -> Image? {
        switch (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
        case "今晚的暗号": return MPAsset.FeatureIcon.secretCode
        case "老板的秘密题": return MPAsset.FeatureIcon.secretQuestion
        case "拍下这一刻": return MPAsset.FeatureIcon.photoMoment
        case "收集这枚风味印章": return MPAsset.FeatureIcon.flavorStamp
        case "新品盲测局": return MPAsset.FeatureIcon.blindTest
        case "今日搭配任务": return MPAsset.FeatureIcon.styleMission
        case "集合点亮": return MPAsset.FeatureIcon.gather
        case "小队竞速点亮": return MPAsset.FeatureIcon.teamRace
        case "街角谜题": return MPAsset.FeatureIcon.streetPuzzle
        case "城市取景任务": return MPAsset.FeatureIcon.cityCamera
        case "城市接力棒": return MPAsset.FeatureIcon.relay
        case "今日角色任务": return MPAsset.FeatureIcon.roleMission
        case "招牌菜限时盲猜": return MPAsset.FeatureIcon.signatureDish
        case "咖啡风味人格": return MPAsset.FeatureIcon.coffeePersonality
        case "分支故事接力": return MPAsset.FeatureIcon.branchStory
        case "细节观察挑战": return MPAsset.FeatureIcon.detailObservation
        case "一桌任务宾果": return MPAsset.FeatureIcon.tableBingo
        case "小队能量接力": return MPAsset.FeatureIcon.teamEnergy
        case "闭眼味觉师": return MPAsset.FeatureIcon.blindTaste
        case "沉默点单": return MPAsset.FeatureIcon.silentOrder
        case "便利店调酒师": return MPAsset.FeatureIcon.diyDrink
        case "治愈音乐角": return MPAsset.FeatureIcon.musicCorner
        case "午夜电台": return MPAsset.FeatureIcon.midnightRadio
        case "低碳行动": return MPAsset.FeatureIcon.lowCarbon
        case "今日城市签": return MPAsset.FeatureIcon.dailyCitySign
        default: return nil
        }
    }

    /// MP `utils/template-art.js` INTERACTION_ICON_BY_TITLE (same table as `pages/template/index.js:24-43`): the registered
    /// interaction plays and life-backup G0-G6 map by title to `/images/interaction-templates/*.svg`. MP `templateArt` uses it
    /// where a play has no cover of its own (template-intro covers, search results).
    static func interactionIcon(_ title: String?) -> Image? {
        switch (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
        case "今晚的暗号": return MPAsset.BannerCover.merchantSecretCode // MP: utils/template-art.js:7 (merchant-secret-code.svg)
        case "老板的秘密题": return MPAsset.BannerCover.merchantSecretQuestion // MP: utils/template-art.js:8 (merchant-secret-question.svg)
        case "拍下这一刻": return MPAsset.BannerCover.merchantPhotoMoment // MP: utils/template-art.js:9 (merchant-photo-moment.svg)
        case "收集这枚风味印章": return MPAsset.BannerCover.merchantFlavorStamp // MP: utils/template-art.js:10 (merchant-flavor-stamp.svg)
        case "新品盲测局": return MPAsset.BannerCover.merchantBlindTest // MP: utils/template-art.js:11 (merchant-blind-test.svg)
        case "今日搭配任务": return MPAsset.BannerCover.merchantStyleMission // MP: utils/template-art.js:12 (merchant-style-mission.svg)
        case "集合点亮": return MPAsset.BannerCover.clubGather // MP: utils/template-art.js:13 (club-gather.svg)
        case "小队竞速点亮": return MPAsset.BannerCover.clubTeamRace // MP: utils/template-art.js:14 (club-team-race.svg)
        case "街角谜题": return MPAsset.BannerCover.clubStreetPuzzle // MP: utils/template-art.js:15 (club-street-puzzle.svg)
        case "城市取景任务": return MPAsset.BannerCover.clubCityCamera // MP: utils/template-art.js:16 (club-city-camera.svg)
        case "城市接力棒": return MPAsset.BannerCover.clubRelay // MP: utils/template-art.js:17 (club-relay.svg)
        case "今日角色任务": return MPAsset.BannerCover.clubRoleMission // MP: utils/template-art.js:18 (club-role-mission.svg)
        case "G0｜30秒生活掉线测试": return MPAsset.BannerCover.lifeOutageTest // MP: utils/template-art.js:20 (life-outage-test.svg)
        case "G1｜现在出状况，你先选什么": return MPAsset.BannerCover.lifeWhatFirst // MP: utils/template-art.js:21 (life-what-first.svg)
        case "G2｜我的底线三选一": return MPAsset.BannerCover.lifeBottomLine // MP: utils/template-art.js:22 (life-bottom-line.svg)
        case "G3｜营业时间拼图": return MPAsset.BannerCover.lifeHoursPuzzle // MP: utils/template-art.js:23 (life-hours-puzzle.svg)
        case "G4｜去之前准备什么": return MPAsset.BannerCover.lifePrepChecklist // MP: utils/template-art.js:24 (life-prep-checklist.svg)
        case "G5｜值不值得现在处理": return MPAsset.BannerCover.lifeWorthNow // MP: utils/template-art.js:25 (life-worth-now.svg)
        case "G6｜首选失效怎么办": return MPAsset.BannerCover.lifeFirstChoiceOffline // MP: utils/template-art.js:26 (life-first-choice-offline.svg)
        default: return nil
        }
    }
}

/// Hero shelf card over a bundled MP cover: the photo, then the title and meta below it in system text styles.
struct TemplateShelfArtHeroCard: View {
    let art: Image
    let title: Text
    var meta: String? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay { art.resizable().scaledToFill().accessibilityHidden(true) }
                .clipShape(.rect(cornerRadius: CYRadius.inner, style: .continuous)) // image crop only
            VStack(alignment: .leading, spacing: 2) {
                title.font(.headline).foregroundStyle(.primary).lineLimit(stacked ? nil : 2)
                if let meta, !meta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary).lineLimit(stacked ? nil : 2)
                }
            }
            .fixedSize(horizontal: false, vertical: stacked)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Square thumb for a shelf row whose title has a bundled MP cover.
struct TemplateShelfArtThumb: View {
    let art: Image
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 72
    var body: some View {
        art.resizable().scaledToFill()
            // a11y-dt r3: capped like list artwork in Music, so the title keeps the row width at AX sizes.
            .frame(width: min(side, 96), height: min(side, 96))
            .clipShape(.rect(cornerRadius: CYRadius.inner, style: .continuous)) // image crop only
            .accessibilityHidden(true)
    }
}
