import SwiftUI

/// `utils/tag-library.js` `tagIcon(label, 'merchant')` + `pages/merchant/components/cy/tag-sheet` artwork:
/// the merchant preset table first, then the keyword rules (more specific first). Unmapped labels get no icon,
/// as in the MP (the capsule falls back to text only).
enum MerchantTagIcons {
    private static let presets: [String: String] = [
        // 经营类目
        "城市运动": "sport", "户外活动": "outdoor", "健康生活": "heart-pulse", "美食": "noodles", "咖啡": "coffee",
        "茶饮": "cup-soda", "烘焙甜品": "croissant", "酒吧小酌": "wine", "手作": "brush", "亲子": "baby", "夜生活": "moon",
        "文化艺术": "platte", "展览": "frame", "书店阅读": "book-open", "音乐现场": "music", "剧本密室": "drama", "桌游": "dices",
        "电玩": "game-handle", "摄影": "camera", "城市漫步": "footprints", "骑行": "bike", "露营": "tent", "瑜伽": "viencharts",
        "球类": "tennis", "水上运动": "ripple", "花艺": "flower-2", "美容美发": "scissors", "宠物友好": "paw-print",
        // 空间
        "老街": "landmark", "天台": "outdoor", "独立空间": "frame", "夜间开放": "moon", "适合拍照": "camera",
        // 体验
        "适合单人": "footprints", "适合情侣": "heart-pulse", "适合亲子": "baby", "适合组队": "dices", "雨天可去": "tent", "安静": "book-open",
        // 人群
        "学生党": "book-open", "上班族": "coffee", "摄影爱好者": "camera", "美食探店": "noodles", "亲子家庭": "baby", "潮流青年": "music",
    ]
    private static let rules: [(String, String)] = [
        ("烘焙|甜品|面包", "croissant"), ("咖啡", "coffee"), ("茶饮|奶茶|饮品", "cup-soda"), ("酒吧|小酌|酒馆", "wine"),
        ("餐饮|美食|小吃", "noodles"), ("健康|养生", "heart-pulse"), ("瑜伽|普拉提", "viencharts"),
        ("球类|网球|羽毛球|篮球|足球", "tennis"), ("极限", "parachute"), ("游泳|水上", "ripple"), ("露营", "tent"),
        ("骑行|单车", "bike"), ("(?i)漫步|徒步|citywalk", "footprints"), ("户外|旅行|出行", "outdoor"), ("运动|健身", "sport"),
        ("(?i)KTV|唱歌", "voice"), ("(?i)音乐|演出|livehouse", "music"), ("夜生活|夜游|夜间", "moon"), ("剧本|密室|沉浸|剧情", "drama"),
        ("桌游|解谜", "dices"), ("展览|画廊|美术馆", "frame"), ("书店|阅读|图书|读书", "book-open"), ("(?i)手作|DIY", "brush"),
        ("艺术|文化", "platte"), ("亲子|儿童", "baby"), ("娱乐|电玩|游乐", "game-handle"), ("摄影|写真|拍照", "camera"),
        ("宠物", "paw-print"), ("花艺|花店", "flower-2"), ("美容|美发|美甲", "scissors"), ("景点|地标|博物馆|老街|历史", "landmark"),
        ("零售|购物|买手", "weixin-market"),
    ]

    static func iconName(for label: String) -> String? {
        let text = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let hit = presets[text] { return hit }
        return rules.first { text.range(of: $0.0, options: .regularExpression) != nil }?.1
    }

    static func image(for label: String) -> Image? { iconName(for: label).flatMap(image(named:)) }

    static func image(named name: String) -> Image? {
        switch name {
        case "baby": return MPAsset.FeatureIcon.baby
        case "bike": return MPAsset.FeatureIcon.bike
        case "book-open": return MPAsset.FeatureIcon.bookOpen
        case "brush": return MPAsset.FeatureIcon.brush
        case "camera": return MPAsset.FeatureIcon.camera
        case "check": return MPAsset.FeatureIcon.check
        case "coffee": return MPAsset.FeatureIcon.pagesMerchantImagesTagsCoffee
        case "croissant": return MPAsset.FeatureIcon.croissant
        case "cup-soda": return MPAsset.FeatureIcon.cupSoda
        case "dices": return MPAsset.FeatureIcon.pagesMerchantImagesTagsDices
        case "drama": return MPAsset.FeatureIcon.pagesMerchantImagesTagsDrama
        case "flower-2": return MPAsset.FeatureIcon.flower2
        case "footprints": return MPAsset.FeatureIcon.pagesMerchantImagesTagsFootprints
        case "frame": return MPAsset.FeatureIcon.frame
        case "game-handle": return MPAsset.FeatureIcon.pagesMerchantImagesTagsGameHandle
        case "heart-pulse": return MPAsset.FeatureIcon.heartPulse
        case "landmark": return MPAsset.FeatureIcon.landmark
        case "moon": return MPAsset.FeatureIcon.moon
        case "music": return MPAsset.FeatureIcon.pagesMerchantImagesTagsMusic
        case "noodles": return MPAsset.FeatureIcon.pagesMerchantImagesTagsNoodles
        case "outdoor": return MPAsset.FeatureIcon.outdoor
        case "parachute": return MPAsset.FeatureIcon.parachute
        case "paw-print": return MPAsset.FeatureIcon.pawPrint
        case "platte": return MPAsset.FeatureIcon.pagesMerchantImagesTagsPlatte
        case "ripple": return MPAsset.FeatureIcon.ripple
        case "scissors": return MPAsset.FeatureIcon.scissors
        case "sport": return MPAsset.FeatureIcon.pagesMerchantImagesTagsSport
        case "tennis": return MPAsset.FeatureIcon.tennis
        case "tent": return MPAsset.FeatureIcon.tent
        case "viencharts": return MPAsset.FeatureIcon.viencharts
        case "voice": return MPAsset.FeatureIcon.pagesMerchantImagesTagsVoice
        case "weixin-market": return MPAsset.FeatureIcon.weixinMarket
        case "wine": return MPAsset.FeatureIcon.wine
        default: return nil
        }
    }
}
