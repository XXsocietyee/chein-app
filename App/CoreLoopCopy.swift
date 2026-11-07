import Foundation

/// Inline bilingual copy for the W4 core loop views: Simplified Chinese source with an English counterpart.
/// Core presentations keep the mini-program's Chinese strings (tests pin them); views translate through this.
struct CoreLoopCopy {
    let locale: Locale
    var isChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    func t(_ zh: String, _ en: String) -> String { isChinese ? zh : en }

    /// English for Core's fixed Chinese strings (Core keeps the mini-program copy; tests pin it).
    /// Unknown text, and any text in a Chinese locale, passes through unchanged.
    func tr(_ zh: String) -> String {
        guard !isChinese else { return zh }
        if let hit = Self.table[zh] { return hit }
        if zh.hasPrefix("剩余可发布 "), zh.hasSuffix(" 个主题") {
            return "\(zh.dropFirst("剩余可发布 ".count).dropLast(" 个主题".count)) topic publish(es) left"
        }
        if zh.hasPrefix("集合前 24 小时可退（截止 "), zh.hasSuffix("）") {
            return "Refundable until 24 hours before meeting (deadline \(zh.dropFirst("集合前 24 小时可退（截止 ".count).dropLast()))"
        }
        return zh
    }
    private static let table: [String: String] = [
        "搜索主题、活动、俱乐部、商家": "Search topics, events, clubs, merchants",
        "本单不可退": "Non-refundable order",
        "该场次已过「集合前 24 小时」退款截止时间，支付后不可退款。确认继续下单？":
            "This session is past the refund deadline (24 hours before meeting). Payments cannot be refunded. Continue with the order?",
        "继续下单": "Continue", "再想想": "Not now",
        "该场次已过集合前 24 小时退款截止时间，本单不可退": "This session is past the 24-hour refund deadline, so this order is non-refundable",
        "订单已过期,请重新报名": "The order expired. Please register again",
        "价格已更新，请重新确认": "The price was updated. Please confirm again",
        "探索票每单限购 1 张": "Explore passes are limited to 1 per order",
        "当前账号已持有该主题的有效探索票，不能重复购买": "This account already holds a valid explore pass for this topic",
        "探店日不支持积分抵扣，请关闭积分后按全价购买": "Points can't be used on shop-visit days. Turn points off and pay full price",
        "自由探索只开放内容所属俱乐部的场次，不能跨俱乐部售票": "Free exploration only sells sessions of the content's own club",
        "该主题尚未完成招商与锁价,暂未开售": "This topic hasn't finished merchant onboarding and price lock, so it is not on sale yet",
        "该主题尚未生成销售快照，无法售票": "This topic has no sales snapshot yet, so tickets can't be sold",
        "该产品暂不支持在线支付(平台正在办理支付资质,预计 2 个月内开放);如需报名请联系主办方":
            "Online payment isn't available for this product yet (the platform is obtaining payment qualification, expected within 2 months). Contact the host to register",
        "请先加入俱乐部再报名": "Join the club before registering",
        "剩余名额已为俱乐部会员保留": "Remaining spots are reserved for club members",
        "名额已满": "Sold out", "暂无可用积分": "No points available", "该票不支持积分抵扣": "This ticket doesn't support points",
        "场次已开始": "Session has started", "场次已结束": "Session has ended", "报名已截止": "Registration closed",
        "已售合同继续履行": "Sold contracts will still be honored",
        "发布": "Publish", "选择发布方式": "Choose how to publish",
        "快速发布主题": "Quick topic", "专业版主题创编": "Pro topic studio", "发布单场活动": "Publish a single event",
        "3步轻量创建城市探索主题": "Create a city-exploration topic in 3 steps",
        "完整章节、节点与道具配置": "Full chapter, node and item setup",
        "面向俱乐部主理人发起定时活动": "For club hosts: start a scheduled event",
        "请先登录并获取发布权限": "Sign in and get publishing access first",
        "主题发布额度已用完": "Topic publishing quota used up",
        "仅认证俱乐部主理人可发布单场活动": "Only verified club hosts can publish single events",
        "今日发布额度已用完": "Today's publishing quota is used up",
        "当前账号暂无快速发布权限": "This account has no quick-publish access",
        "当前账号暂无专业创编权限": "This account has no pro-studio access",
    ]

    /// English counterparts for the activity publish wizard's fixed Core strings.
    func wizardHeading(for step: Int) -> String {
        switch ActivityPublishingWizard.clamp(step) {
        case 0: return t("这场活动叫什么、在哪儿办？", "What is this event called, and where is it?")
        case 1: return t("这场活动玩什么？", "What will people play?")
        default: return t("这场活动怎么卖票？", "How will tickets work?")
        }
    }
    var merchantFreeTicketOnlyNotice: String {
        t(ActivityPublishingWizard.merchantFreeTicketOnlyNotice, "Merchant events currently support free tickets only")
    }
    func reviewSummary(_ s: ActivityPublishingWizard.ReviewSummary) -> ActivityPublishingWizard.ReviewSummary {
        guard !isChinese else { return s }
        func swap(_ v: String) -> String {
            switch v {
            case "未选择": return "Not selected"
            case "保持当前关联模板不变": return "Keep the current linked template"
            case "未填写名称": return "No name entered"
            case "未选择地点": return "No place selected"
            default: return v
            }
        }
        var tickets: String?
        if let raw = s.ticketSummaryText {
            tickets = raw.hasSuffix(" 个票种") ? "\(raw.dropLast(" 个票种".count)) ticket type(s)" : raw
        }
        return ActivityPublishingWizard.ReviewSummary(
            isEditMode: s.isEditMode,
            heading: s.isEditMode ? "Changes summary" : "Pre-publish summary",
            nameText: swap(s.nameText), timeText: s.timeText, addressText: swap(s.addressText),
            templateText: swap(s.templateText), ticketSummaryText: tickets,
            visibilityNotice: s.isEditMode
                ? "This save only updates the items above and does not change who can see the event."
                : "Public by default: after publishing, the event appears in the event list. Continuing publishes with the current visibility.")
    }
}
