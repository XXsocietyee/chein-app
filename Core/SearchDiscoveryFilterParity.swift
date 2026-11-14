import Foundation

/// Search and discovery filters copied from hengyin `73f4f7be45aa5b49381baa2c1aff57e1b2245fad`.
/// `pages/search2` keeps one sort, `最近`, and does not send it as activity `sort_type`.
/// `pages/searchmap` still shows `最近` and `最热` and does send `sort_type`.
/// The template shelf (`pages/templatedetail/shelf`) has tags and no sort.
public enum SearchListSort: String, CaseIterable, Sendable, Hashable {
    /// Default order is `create_time desc`. The list request omits `sort_type`.
    case recent

    public var zh: String { "最近" }
    public var en: String { "Recent" }
}

public enum SearchMapSortChoice: Int, CaseIterable, Sendable, Hashable {
    case nearest = 1
    case popular = 2

    public var zh: String {
        switch self {
        case .nearest: return "最近"
        case .popular: return "最热"
        }
    }

    public var en: String {
        switch self {
        case .nearest: return "Nearest"
        case .popular: return "Popular"
        }
    }
}

public struct DiscoveryShelfTag: Equatable, Identifiable, Sendable, Hashable {
    public let key: String
    public let zh: String
    public let en: String
    public var id: String { key }
    public func title(chinese: Bool) -> String { chinese ? zh : en }
}

public struct DiscoveryShelfTagGroup: Equatable, Identifiable, Sendable, Hashable {
    public let zh: String
    public let en: String
    public let tags: [DiscoveryShelfTag]
    public var id: String { zh }
    public func title(chinese: Bool) -> String { chinese ? zh : en }
}

public struct DiscoveryShelfTagSet: Equatable, Sendable {
    /// Nil when the selection is `全部`, or when the selected tag matches nothing.
    public let selection: String?
    public let row: [DiscoveryShelfTag]
    public let groups: [DiscoveryShelfTagGroup]
}

public enum SearchDiscoveryFilterParity {
    public static let listSorts: [SearchListSort] = [.recent]
    public static let mapSorts: [SearchMapSortChoice] = [.nearest, .popular]
    /// The template shelf has no sort control.
    public static let discoverySorts: [String] = []

    /// CU-M-66: `最近` is the default order. It is not activity `sort_type`.
    public static func listSendsActivitySortType(_ sort: SearchListSort) -> Bool {
        switch sort {
        case .recent: return false
        }
    }

    public static func themeKey(_ name: String) -> String {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.themeOrder.contains(text) { return text }
        return Self.themeOrder.first { text.hasPrefix($0) } ?? ""
    }

    public static func visibleTopics(_ rows: [DiscoveryTopicTemplate]) -> [DiscoveryTopicTemplate] {
        rows.filter { !Self.hiddenThemeKeys.contains(Self.themeKey($0.name)) }
    }

    public static func topicTags(in rows: [DiscoveryTopicTemplate], selected: String?) -> DiscoveryShelfTagSet {
        let visible = Self.visibleTopics(rows)
        return Self.publish(Self.topicGroups, rowKeys: Self.topicRowKeys, selected: selected) { key in
            visible.contains { Self.topicMatches($0, key: key) }
        }
    }

    public static func topics(_ rows: [DiscoveryTopicTemplate], matching key: String?) -> [DiscoveryTopicTemplate] {
        let visible = Self.visibleTopics(rows)
        guard let key else { return visible }
        return visible.filter { Self.topicMatches($0, key: key) }
    }

    /// Shelf games: pack type 0, a title in the 25-title list, not a `G<digits>｜` segment, highest id per title.
    public static func shelfGames(_ rows: [DiscoveryPlayTemplate]) -> [DiscoveryPlayTemplate] {
        var best: [String: DiscoveryPlayTemplate] = [:]
        for row in rows {
            let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard row.packType == 0, Self.gameGroup[title] != nil, !Self.isSegmentTitle(title) else { continue }
            if let kept = best[title] {
                if row.id > kept.id { best[title] = row }
            } else {
                best[title] = row
            }
        }
        return Self.gameTitleOrder.compactMap { best[$0] }
    }

    public static func gameTags(in rows: [DiscoveryPlayTemplate], selected: String?) -> DiscoveryShelfTagSet {
        let shelf = Self.shelfGames(rows)
        return Self.publish(Self.gameGroups, rowKeys: Self.gameRowKeys, selected: selected) { key in
            shelf.contains { Self.gameMatches($0, key: key) }
        }
    }

    public static func games(_ rows: [DiscoveryPlayTemplate], matching key: String?) -> [DiscoveryPlayTemplate] {
        let shelf = Self.shelfGames(rows)
        guard let key else { return shelf }
        return shelf.filter { Self.gameMatches($0, key: key) }
    }

    public static func gameMatches(_ row: DiscoveryPlayTemplate, key: String) -> Bool {
        guard let rule = Self.gameRules[key] else { return false }
        let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch rule {
        case .titles(let names):
            return names.contains(title)
        case .soloPlayer:
            return Self.matches("单人", row.players ?? "")
        case .pairPlayer:
            return Self.matches("双人|2-4", row.players ?? "")
        case .squadPlayer:
            return Self.matches("小队|2-4|同桌", row.players ?? "")
        case .withinFiveMinutes:
            guard let duration = row.duration else { return false }
            return duration > 0 && duration <= 5
        case .group(let group):
            return Self.gameGroup[title] == group
        }
    }

    // MARK: - Topic catalog

    private static let hiddenThemeKeys: Set<String> = ["野生邻居观察局"]
    private static let themeOrder = [
        "城市藏宝猎人", "野生邻居观察局", "异常事务局：不存在的坐标", "末日广播：最后一座中继站",
        "时间污染：被删除的今天", "风味巡游", "不惑之年", "预制人生", "高温末日逃生", "上海像一部旧电影", "生活不掉线"
    ]
    private static let freeExplore = ["风味巡游", "不惑之年", "预制人生", "高温末日逃生", "上海像一部旧电影"]
    private static let stories = ["城市藏宝猎人", "异常事务局：不存在的坐标", "末日广播：最后一座中继站", "时间污染：被删除的今天"]
    private static let topicRowKeys = ["explore", "story", "survival", "puzzle", "scifi", "nostalgia", "solo", "t2h"]

    private static func seconds(_ row: DiscoveryTopicTemplate) -> Int { row.totalTime ?? 0 }

    private static func topicMatches(_ row: DiscoveryTopicTemplate, key: String) -> Bool {
        guard let rule = Self.topicRules[key] else { return false }
        let theme = Self.themeKey(row.name)
        switch rule {
        case .names(let names):
            return names.contains(theme)
        case .solo:
            return !theme.isEmpty && theme != "生活不掉线"
        case .upToOneHour:
            let value = Self.seconds(row)
            return value > 0 && value <= 3600
        case .upToTwoHours:
            let value = Self.seconds(row)
            return value > 3600 && value <= 7200
        case .halfDay:
            return Self.seconds(row) > 7200
        }
    }

    private enum TopicRule {
        case names([String])
        case solo
        case upToOneHour
        case upToTwoHours
        case halfDay
    }

    private static let topicGroups: [ShelfGroupDef] = [
        ShelfGroupDef(zh: "类型", en: "Type", tags: [
            ShelfTagDef(key: "explore", zh: "城市探索", en: "City exploring"),
            ShelfTagDef(key: "story", zh: "剧情叙事", en: "Story"),
            ShelfTagDef(key: "survival", zh: "生存逃脱", en: "Survival escape"),
            ShelfTagDef(key: "puzzle", zh: "解谜推理", en: "Puzzle"),
            ShelfTagDef(key: "versus", zh: "竞技对抗", en: "Competition"),
            ShelfTagDef(key: "life", zh: "生活实用", en: "Everyday")
        ]),
        ShelfGroupDef(zh: "风格", en: "Style", tags: [
            ShelfTagDef(key: "scifi", zh: "科幻异常", en: "Science fiction"),
            ShelfTagDef(key: "nostalgia", zh: "怀旧人文", en: "Nostalgia"),
            ShelfTagDef(key: "calm", zh: "治愈放松", en: "Calm")
        ]),
        ShelfGroupDef(zh: "适合谁", en: "Who it's for", tags: [
            ShelfTagDef(key: "solo", zh: "一个人", en: "Solo"),
            ShelfTagDef(key: "date", zh: "约会", en: "A date"),
            ShelfTagDef(key: "newcomer", zh: "初来上海", en: "New to Shanghai"),
            ShelfTagDef(key: "local", zh: "本地居民", en: "Local")
        ]),
        ShelfGroupDef(zh: "时长", en: "Duration", tags: [
            ShelfTagDef(key: "t1h", zh: "一小时内", en: "Within an hour"),
            ShelfTagDef(key: "t2h", zh: "两小时内", en: "Within two hours"),
            ShelfTagDef(key: "halfday", zh: "半天", en: "Half a day"),
            ShelfTagDef(key: "multiday", zh: "可以跨天", en: "Multi-day")
        ])
    ]

    private static let topicRules: [String: TopicRule] = {
        let explore = Self.freeExplore.filter { $0 != "高温末日逃生" }
        return [
            "explore": .names(explore),
            "story": .names(Self.stories),
            "survival": .names(["末日广播：最后一座中继站", "高温末日逃生", "异常事务局：不存在的坐标"]),
            "puzzle": .names(["城市藏宝猎人", "异常事务局：不存在的坐标", "时间污染：被删除的今天"]),
            "versus": .names([]),
            "life": .names(["生活不掉线"]),
            "scifi": .names(["异常事务局：不存在的坐标", "末日广播：最后一座中继站", "时间污染：被删除的今天"]),
            "nostalgia": .names(["上海像一部旧电影", "城市藏宝猎人", "时间污染：被删除的今天"]),
            "calm": .names(["不惑之年", "预制人生"]),
            "solo": .solo,
            "date": .names(["上海像一部旧电影", "风味巡游"]),
            "newcomer": .names(["风味巡游", "城市藏宝猎人", "上海像一部旧电影"]),
            "local": .names(["生活不掉线", "预制人生"]),
            "t1h": .upToOneHour,
            "t2h": .upToTwoHours,
            "halfday": .halfDay,
            "multiday": .names(Self.freeExplore)
        ]
    }()

    // MARK: - Game catalog

    private static let gameTitleOrder = [
        "今晚的暗号", "老板的秘密题", "拍下这一刻", "收集这枚风味印章", "新品盲测局", "今日搭配任务",
        "集合点亮", "小队竞速点亮", "街角谜题", "城市取景任务", "城市接力棒", "今日角色任务",
        "招牌菜限时盲猜", "咖啡风味人格", "分支故事接力", "细节观察挑战", "一桌任务宾果", "小队能量接力",
        "闭眼味觉师", "沉默点单", "便利店调酒师", "治愈音乐角", "午夜电台", "低碳行动", "今日城市签"
    ]
    private static let gameGroup: [String: String] = [
        "今晚的暗号": "shop", "老板的秘密题": "shop", "拍下这一刻": "city", "收集这枚风味印章": "shop",
        "新品盲测局": "shop", "今日搭配任务": "shop", "集合点亮": "team", "小队竞速点亮": "team",
        "街角谜题": "city", "城市取景任务": "city", "城市接力棒": "team", "今日角色任务": "team",
        "招牌菜限时盲猜": "shop", "咖啡风味人格": "shop", "分支故事接力": "team", "细节观察挑战": "city",
        "一桌任务宾果": "team", "小队能量接力": "team", "闭眼味觉师": "shop", "沉默点单": "shop",
        "便利店调酒师": "shop", "治愈音乐角": "shop", "午夜电台": "shop", "低碳行动": "city", "今日城市签": "city"
    ]
    private static let gameRowKeys = ["promo", "plugin", "riddle", "sport", "versus", "icebreak", "taste", "quick"]

    private enum GameRule {
        case titles([String])
        case soloPlayer
        case pairPlayer
        case squadPlayer
        case withinFiveMinutes
        case group(String)
    }

    private static let gameGroups: [ShelfGroupDef] = [
        ShelfGroupDef(zh: "用途", en: "Purpose", tags: [
            ShelfTagDef(key: "promo", zh: "营销引流", en: "Promotion"),
            ShelfTagDef(key: "plugin", zh: "插件玩法", en: "Plugin play"),
            ShelfTagDef(key: "icebreak", zh: "社交破冰", en: "Icebreaker"),
            ShelfTagDef(key: "teambuild", zh: "团建", en: "Team building")
        ]),
        ShelfGroupDef(zh: "玩法", en: "How to play", tags: [
            ShelfTagDef(key: "riddle", zh: "解谜", en: "Riddle"),
            ShelfTagDef(key: "quiz", zh: "问答抢答", en: "Quiz"),
            ShelfTagDef(key: "blind", zh: "盲猜盲测", en: "Blind tasting"),
            ShelfTagDef(key: "photo", zh: "拍照打卡", en: "Photo check-in"),
            ShelfTagDef(key: "relay", zh: "接力", en: "Relay"),
            ShelfTagDef(key: "roleplay", zh: "角色扮演", en: "Role play"),
            ShelfTagDef(key: "collect", zh: "收集", en: "Collecting"),
            ShelfTagDef(key: "silent", zh: "无声挑战", en: "Silent challenge")
        ]),
        ShelfGroupDef(zh: "题材", en: "Subject", tags: [
            ShelfTagDef(key: "sport", zh: "运动", en: "Sport"),
            ShelfTagDef(key: "versus", zh: "竞技对抗", en: "Competition"),
            ShelfTagDef(key: "taste", zh: "味觉", en: "Taste"),
            ShelfTagDef(key: "music", zh: "音乐", en: "Music"),
            ShelfTagDef(key: "fashion", zh: "时尚", en: "Fashion")
        ]),
        ShelfGroupDef(zh: "适合的店", en: "Shop", tags: [
            ShelfTagDef(key: "cafe", zh: "咖啡馆", en: "Cafe"),
            ShelfTagDef(key: "dining", zh: "餐饮", en: "Dining"),
            ShelfTagDef(key: "bar", zh: "酒吧", en: "Bar"),
            ShelfTagDef(key: "store", zh: "便利店", en: "Convenience store"),
            ShelfTagDef(key: "retail", zh: "服饰零售", en: "Clothing retail"),
            ShelfTagDef(key: "books", zh: "书店唱片店", en: "Bookstore and records"),
            ShelfTagDef(key: "street", zh: "街头户外", en: "Street")
        ]),
        ShelfGroupDef(zh: "人数", en: "Group size", tags: [
            ShelfTagDef(key: "p1", zh: "单人可玩", en: "Solo"),
            ShelfTagDef(key: "p2", zh: "双人", en: "Two people"),
            ShelfTagDef(key: "p3", zh: "小队", en: "Squad")
        ]),
        ShelfGroupDef(zh: "时间", en: "Time", tags: [
            ShelfTagDef(key: "quick", zh: "5 分钟内", en: "Within 5 minutes"),
            ShelfTagDef(key: "night", zh: "深夜限定", en: "Late night"),
            ShelfTagDef(key: "daily", zh: "每日一次", en: "Once a day")
        ]),
        ShelfGroupDef(zh: "分区", en: "Section", tags: [
            ShelfTagDef(key: "shop", zh: "到店互动", en: "In-store"),
            ShelfTagDef(key: "team", zh: "小队协作", en: "Team"),
            ShelfTagDef(key: "city", zh: "城市探索", en: "City exploring")
        ])
    ]

    private static let gameRules: [String: GameRule] = [
        "promo": .titles(["今晚的暗号", "老板的秘密题", "收集这枚风味印章", "新品盲测局", "招牌菜限时盲猜", "咖啡风味人格"]),
        "plugin": .titles(["拍下这一刻", "集合点亮", "今日角色任务", "城市接力棒", "今日城市签", "午夜电台", "治愈音乐角"]),
        "icebreak": .titles(["一桌任务宾果", "分支故事接力", "便利店调酒师", "今日搭配任务"]),
        "teambuild": .titles(["小队能量接力", "小队竞速点亮", "一桌任务宾果", "分支故事接力"]),
        "riddle": .titles(["街角谜题", "今晚的暗号", "老板的秘密题", "细节观察挑战"]),
        "quiz": .titles(["老板的秘密题", "招牌菜限时盲猜", "咖啡风味人格", "小队能量接力"]),
        "blind": .titles(["闭眼味觉师", "新品盲测局", "招牌菜限时盲猜"]),
        "photo": .titles(["拍下这一刻", "城市取景任务"]),
        "relay": .titles(["城市接力棒", "分支故事接力", "小队能量接力"]),
        "roleplay": .titles(["今日角色任务", "集合点亮"]),
        "collect": .titles(["收集这枚风味印章", "今日城市签"]),
        "silent": .titles(["沉默点单"]),
        "sport": .titles(["低碳行动", "小队竞速点亮"]),
        "versus": .titles(["小队竞速点亮", "小队能量接力", "招牌菜限时盲猜"]),
        "taste": .titles(["闭眼味觉师", "便利店调酒师", "咖啡风味人格"]),
        "music": .titles(["治愈音乐角", "午夜电台"]),
        "fashion": .titles(["今日搭配任务"]),
        "cafe": .titles(["咖啡风味人格", "闭眼味觉师", "治愈音乐角", "新品盲测局"]),
        "dining": .titles(["招牌菜限时盲猜", "一桌任务宾果", "沉默点单"]),
        "bar": .titles(["闭眼味觉师", "午夜电台", "便利店调酒师"]),
        "store": .titles(["便利店调酒师", "沉默点单"]),
        "retail": .titles(["今日搭配任务", "新品盲测局"]),
        "books": .titles(["治愈音乐角"]),
        "street": .titles(["街角谜题", "城市取景任务", "低碳行动", "城市接力棒", "小队竞速点亮"]),
        "p1": .soloPlayer,
        "p2": .pairPlayer,
        "p3": .squadPlayer,
        "quick": .withinFiveMinutes,
        "night": .titles(["午夜电台"]),
        "daily": .titles(["今日城市签", "今日搭配任务", "今日角色任务"]),
        "shop": .group("shop"),
        "team": .group("team"),
        "city": .group("city")
    ]

    private static func isSegmentTitle(_ title: String) -> Bool {
        title.range(of: "^G\\d+｜", options: .regularExpression) != nil
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func publish(_ groups: [ShelfGroupDef], rowKeys: [String], selected: String?, live: (String) -> Bool) -> DiscoveryShelfTagSet {
        let visibleGroups: [DiscoveryShelfTagGroup] = groups.compactMap { group in
            let tags = group.tags.filter { live($0.key) }.map { DiscoveryShelfTag(key: $0.key, zh: $0.zh, en: $0.en) }
            guard !tags.isEmpty else { return nil }
            return DiscoveryShelfTagGroup(zh: group.zh, en: group.en, tags: tags)
        }
        let all = visibleGroups.flatMap(\.tags)
        var row = rowKeys.compactMap { key in all.first { $0.key == key } }
        let selection = selected.flatMap { key in all.contains { $0.key == key } ? key : nil }
        if let selection, let picked = all.first(where: { $0.key == selection }), !row.contains(picked) {
            row.insert(picked, at: 0)
        }
        return DiscoveryShelfTagSet(selection: selection, row: row, groups: visibleGroups)
    }
}

private struct ShelfTagDef: Equatable {
    let key: String
    let zh: String
    let en: String
}

private struct ShelfGroupDef: Equatable {
    let zh: String
    let en: String
    let tags: [ShelfTagDef]
}
