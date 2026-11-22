import Foundation

/// A mini-program page path plus its query, accepted only for pages that have a native screen.
///
/// Parsing classifies a link and grants nothing: the host maps it to its parity route, and that screen keeps its own
/// sign-in, capability and confirmation gating (money stays off). Unknown pages, unknown or repeated keys, a missing
/// required key, a non-canonical id, a value over 512 UTF-16 code units or a control character reject the whole link.
public struct MiniProgramPageLink: Equatable, Sendable {
    /// Page path without the leading slash, for example `subpackageMember/market/gift/index`.
    public let page: String
    public let query: [String: String]

    public struct Rule: Equatable, Sendable {
        public let allowed: Set<String>
        public let required: Set<String>
        /// Keys whose value must be a positive canonical decimal id.
        public let ids: Set<String>
    }

    /// Every mini-program page the native parity router opens (`MPParityRoute(miniProgramPath:query:)`).
    /// `subpackagePass/reveal/index` takes no query: paid reveal facts in a link would be unverified, so they stay off.
    /// Paths are the `mini_path` values in `docs/parity/page-map.csv` whose target file already has a page view,
    /// plus the twelve parity screens that were already reviewed. A page whose file only has a section, card, or
    /// picker is absent. `pages/team/join/index` stays with the team-invitation parser.
    public static let reviewedPages: [String: Rule] = {
        var pages: [String: Rule] = [
            "subpackageA/pages/video-bounty/index": .init(allowed: ["campaignKey", "topicId"], required: [], ids: ["topicId"]),
            "subpackageMember/market/passes/index": .init(allowed: ["tab"], required: [], ids: []),
            "subpackageMember/market/pass/index": .init(allowed: ["id"], required: ["id"], ids: []),
            "subpackageMember/market/gift/index": .init(allowed: ["token"], required: [], ids: []),
            "subpackageMember/market/membership/index": .init(allowed: [], required: [], ids: []),
            "subpackageMember/market/library/index": .init(allowed: ["kind"], required: [], ids: []),
            "subpackageMember/market/pass-order/index": .init(allowed: ["orderNo"], required: ["orderNo"], ids: []),
            "subpackageMember/free-explore/index": .init(allowed: ["registrationId", "topicId", "requestId"], required: [],
                                                         ids: ["registrationId", "topicId"]),
            "subpackageMember/invoice-detail/index": .init(allowed: ["id"], required: ["id"], ids: ["id"]),
            "subpackageMember/signup/index": .init(allowed: ["focusId", "topicId", "arrive"], required: [], ids: ["focusId", "topicId"]),
            "subpackageMember/mycanyuinfo/mycanyuinfo": .init(allowed: ["id"], required: ["id"], ids: ["id"]),
            "subpackageMember/character/index": .init(allowed: ["topicId"], required: ["topicId"], ids: ["topicId"]),
            "subpackageMember/orient-score/index": .init(allowed: ["topicId", "activityId", "sessionId"], required: ["topicId"],
                                                         ids: ["topicId", "sessionId"]),  // activityId may be "0" (MP scope)
            "subpackageMember/report-detail/index": .init(allowed: ["reportId"], required: ["reportId"], ids: ["reportId"]),
            "subpackageMember/coupon-qr/index": .init(allowed: ["couponHistoryId", "historyId", "id"], required: [],
                                                      ids: ["couponHistoryId", "historyId", "id"]),
            "subpackagePass/reveal/index": .init(allowed: [], required: [], ids: []),
            "subpackageJourney/pages/landing/index": .init(allowed: ["k", "t", "aid", "tid"], required: ["k", "t"], ids: ["aid", "tid"]),
            "subpackageJourney/pages/seats/index": .init(allowed: ["registrationId"], required: ["registrationId"], ids: ["registrationId"]),
            "subpackageJourney/pages/promo/index": .init(allowed: [], required: [], ids: []),
            "subpackageJourney/pages/report/index": .init(allowed: ["activityId", "topicId", "runId", "topicName", "registrationId"],
                                                          required: [], ids: ["activityId", "topicId", "runId", "registrationId"]),
            "subpackageJourney/pages/settle/index": .init(allowed: ["activityId", "topicId", "runId", "topicName", "registrationId"],
                                                          required: [], ids: ["activityId", "topicId", "runId", "registrationId"]),
        ]
        let open = Rule(allowed: [], required: [], ids: [])
        let identified = Rule(allowed: ["id"], required: ["id"], ids: ["id"])
        let optionalID = Rule(allowed: ["id"], required: [], ids: ["id"])
        for page in openPages { pages[page] = open }
        for page in identifiedPages { pages[page] = identified }
        for page in optionalIDPages { pages[page] = optionalID }
        // Subscribe-message landing pages from public hengyin (cur-push). Set last: `pages/coop/list/index` keeps `tab`.
        // `order/order?detailId=` (subscribe-message landing) opens that order; `orderinfo?outTradeNo=` (payment
        // receipt) has no by-number read, so it lands on 我的订单.
        pages["subpackageMember/order/order"] = Rule(allowed: ["detailId"], required: [], ids: ["detailId"])
        pages["subpackageMember/orderinfo/orderinfo"] = Rule(allowed: ["id", "outTradeNo"], required: [], ids: ["id"])
        pages["pages/coop/list/index"] = Rule(allowed: ["tab"], required: [], ids: [])
        pages["subpackageA/pages/myproject/index"] = open
        pages["pages/merchant/ledger/index"] = open
        return pages
    }()

    /// Page-map paths whose native screen takes no query. A key on the link rejects the whole link.
    private static let openPages: [String] = [
        "pages/index/index",
        "pages/template/index",
        "pages/talent/list/index",
        "pages/member/index/index",
        "pages/roam/index",
        "pages/privacy/index",
        "pages/agreement/index",
        "pages/deregister/index",
        "pages/team/detail/index",
        "pages/play/index",
        "pages/play/merchant/index",
        "pages/play/circle/index",
        "pages/play/poi-challenge/index",
        "pages/activity/baoming/baoming",
        "pages/activity/list/index",
        "pages/activity/official-inbox/index",
        "pages/activity/official-mine/index",
        "pages/activity/official-organizer/index",
        "subpackageA/pages/myproject/index",
        "subpackageA/pages/infomation/infomation",
        "subpackageA/pages/assetcenter/income-detail/income-detail",
        "subpackageA/pages/assetcenter/earnings/index",
        "subpackageA/pages/assetcenter/analysis/index",
        "subpackageP3/pages/growthcenter/index/index",
        "subpackageP3/pages/growthcenter/leaderboard/index",
        "subpackageP3/pages/stamp-camera/index/index",
        "subpackageP3/pages/stamp-album/index/index",
        "subpackageP3/pages/badge-wall/index/index",
        "subpackageP3/pages/badge-3d/index",
        "subpackageP3/pages/object-cards/index/index",
        "subpackageB/pages/im/list/index",
        "subpackageB/pages/im/chat/index",
        "pages/publish/fabu/index",
        "pages/publish/simple/index",
        "pages/publish/temp/index",
        "pages/publish/activity/index",
        "pages/publish/topicadd/topicadd",
        "pages/publish/template-intro/index",
        "pages/club/apply/index",
        "pages/club/badges/index",
        "pages/club/create/index",
        "pages/club/customer-detail/index",
        "pages/club/customers/index",
        "pages/club/edit/index",
        "pages/club/enroll/index",
        "pages/club/checkin-detail/index",
        "pages/club/event-ops/index",
        "pages/club/group-code/index",
        "pages/club/join-requests/index",
        "pages/club/notify/index",
        "pages/club/topic-detail/index",
        "pages/club/topic-story/index",
        "pages/club/workbench/index",
        "pages/topic/merchantinfo/merchantinfo",
        "pages/topic/merchantapply/index",
        "pages/topic/pricing/index",
        "pages/topic/pricing/partner/index",
        "pages/merchant/index/index",
        "pages/merchant/apply/index",
        "pages/merchant/ledger/index",
        "pages/merchant/ledger/order-detail/index",
        "pages/merchant/ledger/batch-detail/index",
        "pages/merchant/aftercare/index",
        "pages/merchant/predict/index",
        "pages/merchant/aftercare/detail/index",
        "pages/merchant/profile/index",
        "pages/merchant/marketing/index",
        "pages/merchant/reviews/index",
        "pages/merchant/marketing/ai-insight/index",
        "pages/merchant/relation/index",
        "pages/merchant/citynode/index",
        "pages/merchant/citynode/create/index",
        "pages/merchant/decor/index",
        "pages/merchant/decor/ai-npc/index",
        "pages/merchant/decor/coop-setting/index",
        "pages/merchant/decor/gallery/index",
        "pages/merchant/decor/perks/index",
        "pages/merchant/coop-center/index",
        "pages/merchant/customer/index",
        "pages/merchant/game-node/index",
        "pages/merchant/verify-records/index",
        "pages/merchant/crm-campaigns/index",
        "pages/merchant/team/index",
        "pages/coop/list/index",
        "pages/coop/invite-detail/index",
        "pages/coop/invite/index",
        "pages/coop/nearby/index",
        "pages/coop/finance/index",
        "pages/coop/settlement-detail/index",
        "pages/coop/withdraw/index",
        "pages/coop/withdraw/records/index",
        "pages/square/list/index",
        "pages/search2/index",
        "pages/search2/result/index",
        "pages/searchmap/index",
        "pages/templatedetail/topic-preview/index",
        "pages/templatedetail/topic-detail/index",
        "pages/address/address",
        "pages/addressinfo/addressinfo",
        "pages/shezhi/shezhi",
        "pages/shezhi/about/index",
        "pages/shezhi/marketing/index",
        "pages/gerenziliao/gerenziliao",
        "pages/mylike/mylike",
        "pages/crop/index",
        "subpackageMember/invoice/index",
        "subpackageMember/invoice-apply/index",
        "subpackageMember/invoice-titles/index",
        "subpackageMember/invoice-title-edit/index",
        "subpackageMember/complaint/index",
        "subpackageMember/coupon-wallet/index",
        "subpackageMember/coupon/coupon",
        "subpackageMember/couponInfo/couponInfo",
        "subpackageMember/mycanyu/mycanyu",
        "subpackageMember/myinvite/myinvite",
        "subpackageMember/mytemplate/mytemplate",
        "subpackageMember/order/order",
        "subpackageMember/points-history/index",
        "subpackageMember/report-mine/index",
        "subpackageMember/appeal-mine/index",
        "subpackageMember/tixian/tixian",
        "subpackageMember/tixianjilu/tixianjilu",
        "subpackageRoam/citynode-code/index",
        "subpackageRoam/history/index",
        "subpackageRoam/nearby/index",
        "subpackageRoam/citystamp/index",
        "subpackageRoam/my-teams/index",
        "subpackageRoam/official-routes/index",
        "subpackageRoam/official-route/index",
        "subpackageTools/capsule/index",
        "subpackageTools/monthly-recap/index",
        "subpackageTools/exploration-goals/index",
        "subpackageTools/anniversary/index",
        "subpackageTools/exploration-export/index",
        "pages/templatedetail2/templatedetail2",
        "subpackageMember/signupInfo/signupInfo",
        "subpackageMember/signupInfo2/signupInfo2",
        "pages/topic/settlement/index",
        "pages/talent/search/index",
    ]

    /// Pages whose native screen is addressed by the existing canonical `id` query (`NativeContentTarget`, and
    /// `subpackageMember/orderinfo?id=`). No other key is accepted.
    private static let identifiedPages: [String] = [
        "pages/activity/detail/index",
        "pages/club/detail/index",
        "pages/topic/index/index",
        "pages/square/detail/index",
        "pages/templatedetail/templatedetail",
        "subpackageMember/orderinfo/orderinfo",
        "subpackageRoam/poi-detail/index",
        "subpackageRoam/session/index",
    ]

    /// Same `id` key, not required: a bare path still opens, and a non-canonical id still rejects the link.
    private static let optionalIDPages: [String] = [
        "pages/activity/official-detail/index",
        "pages/userinfo/userinfo",
        "subpackageA/pages/infomationdetail/infomationdetail",
    ]

    public init?(path: String, query: [String: String]) {
        let page = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let rule = Self.reviewedPages[page] else { return nil }
        // Empty values are absent (the mini-program reads `options.x || ''`).
        let present = query.filter { !$0.value.isEmpty }
        guard Set(query.keys).isSubset(of: rule.allowed), rule.required.isSubset(of: Set(present.keys)) else { return nil }
        for (key, value) in present {
            guard value.utf16.count <= 512, value.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { return nil }
            if rule.ids.contains(key), Self.positiveID(value) == nil { return nil }
        }
        if page == "subpackageJourney/pages/landing/index", !["r", "g", "s"].contains(present["k"] ?? "") { return nil }
        if page == "pages/coop/list/index", let tab = present["tab"], tab != "sent", tab != "received" { return nil }
        self.page = page
        self.query = present
    }

    /// Query items as a URL carries them: each name once, every item with a value.
    public init?(path: String, items: [URLQueryItem]) {
        guard Set(items.map(\.name)).count == items.count, items.allSatisfy({ $0.value != nil }) else { return nil }
        self.init(path: path, query: Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) }))
    }

    /// `chein://mp/<page path>?<query>`: the custom-scheme form of a mini-program page link.
    public init?(cheinURL url: URL) {
        guard url.absoluteString.utf8.count <= 2048,
              let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == CheinDeepLink.scheme, c.host?.lowercased() == "mp",
              c.user == nil, c.password == nil, c.port == nil, c.fragment == nil,
              c.path.hasPrefix("/") else { return nil }
        self.init(path: c.path, items: c.queryItems ?? [])
    }

    /// A referral, gift or seat landing (`chein://landing?k=…`) opens the same journey landing page.
    public init(journey intake: JourneyLinkIntake) {
        let kind: String
        switch intake.kind {
        case .referral: kind = "r"
        case .gift: kind = "g"
        case .seat: kind = "s"
        }
        var query = ["k": kind, "t": intake.token]
        if let id = intake.activityID { query["aid"] = String(id) }
        if let id = intake.topicID { query["tid"] = String(id) }
        page = "subpackageJourney/pages/landing/index"
        self.query = query
    }

    private static func positiveID(_ text: String) -> Int? {
        guard text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }
}
