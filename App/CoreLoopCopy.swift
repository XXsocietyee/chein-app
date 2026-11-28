import Foundation

/// Inline bilingual copy for the W4 core loop views: Simplified Chinese source with an English counterpart.
/// Core presentations keep the mini-program's Chinese strings (tests pin them); views translate through this.
struct CoreLoopCopy {
    let locale: Locale
    var isChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    func t(_ zh: String, _ en: String) -> String { isChinese ? zh : en }

    /// English noun phrase with exact singular grammar: only a count of exactly 1 is singular.
    static func count(_ digits: Substring, _ one: String, _ other: String) -> String {
        "\(digits) \(Int(digits) == 1 ? one : other)"
    }

    /// English for Core's fixed Chinese strings (Core keeps the mini-program copy; tests pin it).
    /// Unknown text, and any text in a Chinese locale, passes through unchanged.
    func tr(_ zh: String) -> String {
        guard !isChinese else { return zh }
        if let hit = Self.table[zh] { return hit }
        if zh.hasPrefix("剩余可发布 "), zh.hasSuffix(" 个主题") {
            return "\(Self.count(zh.dropFirst("剩余可发布 ".count).dropLast(" 个主题".count), "topic publish", "topic publishes")) left"
        }
        if zh.hasPrefix("集合前 24 小时可退（截止 "), zh.hasSuffix("）") {
            return "Refundable until 24 hours before meeting (deadline \(zh.dropFirst("集合前 24 小时可退（截止 ".count).dropLast()))"
        }
        if zh.hasSuffix(" 天内过期") {
            return "Expires in \(Self.count(zh.dropLast(" 天内过期".count), "day", "days"))"
        }
        if zh.hasPrefix("将给 "), zh.hasSuffix(" 位已付款玩家全额退款,不可撤销。活动同时下架。") {
            let count = zh.dropFirst("将给 ".count).dropLast(" 位已付款玩家全额退款,不可撤销。活动同时下架。".count)
            return "\(Self.count(count, "paid attendee", "paid attendees")) will receive a full refund. This cannot be undone and the event will be unlisted."
        }
        if zh.hasPrefix("全队已完成 "), zh.hasSuffix(" 个节点") {
            return "Team completed \(Self.count(zh.dropFirst("全队已完成 ".count).dropLast(" 个节点".count), "node", "nodes"))"
        }
        return zh
    }
    private static let table: [String: String] = [
        // Core/TeamOrientBoard.swift summaryText
        "当前场次暂无定向任务": "No orienteering tasks for this session yet",
        // Core/MoneyParityRules.swift MoneyRefundPolicy reasons
        "未支付订单无需退款": "Unpaid order; no refund needed",
        "已核销订单需人工核实,请联系客服": "Verified order needs manual review. Please contact support",
        "已核销报名不可退款": "Verified registrations are not refundable",
        "集合时间缺失，需人工核实，请联系客服": "Meeting time is missing; manual review is needed. Please contact support",
        "可取消报名并释放名额": "Registration can be canceled and the spot released",
        "场次已开始，不可取消报名": "The session has started; registration can no longer be canceled",
        "退款截止时间缺失,需人工核实,请联系客服": "Refund deadline is missing; manual review is needed. Please contact support",
        "已过退款截止时间": "The refund deadline has passed",
        "可全额退款,原路退回": "Full refund to the original payment method",
        "上海": "Shanghai", "杭州": "Hangzhou", "北京": "Beijing",
        "深圳": "Shenzhen", "广州": "Guangzhou", "成都": "Chengdu",
        "搜索主题、活动、俱乐部、商家": "Search topics, events, clubs, merchants",
        "本单不可退": "Non-refundable order",
        "该场次已开始，支付后不可退款。确认继续下单？": "This session has started. You can't get a refund after you pay. Continue with the order?",
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
        "该产品暂不支持在线支付(平台正在办理支付资质,预计 2 个月内开放);如需报名请联系主办方": "Online payment isn't available for this product yet (the platform is obtaining payment qualification, expected within 2 months). Contact the host to register",
        "请先加入俱乐部再报名": "Join the club before registering",
        "剩余名额已为俱乐部会员保留": "Remaining spots are reserved for club members",
        "名额已满": "Sold out", "暂无可用积分": "No points available", "该票不支持积分抵扣": "This ticket doesn't support points",
        "场次已开始": "Session has started", "场次已结束": "Session has ended", "报名已截止": "Registration closed",
        "四店固定补偿产品已停止新开售，已售合同继续履行": "Four-shop fixed compensation products have stopped new sales; sold contracts will still be honored",
        "四店固定补偿产品已停止新售票，已售合同继续履行": "Four-shop fixed compensation products have stopped new ticket sales; sold contracts will still be honored",
        "已售合同继续履行": "Sold contracts will still be honored",
        "今天过期": "Expires today",
        "已退款": "Refunded",
        "退款已原路退回": "Refunded to the original payment method",
        "退款处理中": "Refund in progress",
        "原路退款异常，平台正在人工处理": "Original-route refund encountered an issue; platform support is processing it manually",
        "人工退款已处理，等待复核确认": "Manual refund processed; awaiting final review",
        "退款审核中": "Refund under review",
        "退款申请已提交，等待平台审核": "Refund request submitted; awaiting platform review",
        "原路退款中": "Refunding to original payment method",
        "微信已受理原路退款，到账以微信退款通知为准": "Refund accepted by payment provider; arrival depends on provider notification",
        "退款已批准，正在提交原路退款": "Refund approved; submitting to original payment method",
        "已售出，时间和地点不可改": "Tickets have been sold; time and location cannot be changed",
        "合作者可编辑内容，不参与结算": "Collaborators can edit the content but don’t share in earnings",
        "商家活动暂时只支持免费票": "Merchant events currently support free tickets only",
        "商家主办活动还没开通收款，票价只能是 0": "Merchant-hosted events do not have payments enabled yet; ticket price must be 0",
        "取消活动并退款": "Cancel event & refund",
        "请填写取消原因": "Please enter a cancellation reason",
        "取消原因不超过 100 字": "Cancellation reason cannot exceed 100 characters",
        "填写取消原因（会展示给已报名用户）": "Enter cancellation reason (shown to registered attendees)",
        "无法确认已付款人数，请稍后再试": "Could not verify paid attendee count. Please try again later.",
        "当前无法取消": "Cannot cancel right now",
        "重新检查": "Check again",
        "确认取消并退款": "Confirm cancel & refund",
        "活动已取消": "Event canceled",
        "已提交全额退款，到账时间以微信通知为准": "Full refund submitted; arrival depends on payment provider notification",
        "取消失败": "Cancellation failed",
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
            tickets = raw.hasSuffix(" 个票种") ? Self.count(raw.dropLast(" 个票种".count), "ticket type", "ticket types") : raw
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
