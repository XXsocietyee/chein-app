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
            "subpackageMember/market/pass/index": .init(allowed: ["id"], required: [], ids: []),
            "subpackageMember/market/gift/index": .init(allowed: ["token", "mode"], required: [], ids: []),
            "subpackageMember/market/membership/index": .init(allowed: [], required: [], ids: []),
            "subpackageMember/market/library/index": .init(allowed: ["kind"], required: [], ids: []),
            "subpackageMember/market/pass-order/index": .init(allowed: ["orderNo"], required: [], ids: []),
            "subpackageMember/free-explore/index": .init(allowed: ["registrationId", "topicId", "requestId"], required: [],
                                                         ids: ["registrationId", "topicId"]),
            "subpackageMember/invoice-detail/index": .init(allowed: ["id"], required: [], ids: ["id"]),
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
        // `coupon/coupon` is in openPages, which drops `scope`. The mini-program sends
        // scope=MERCHANT or omits it. The value is not a closed set.
        pages["subpackageMember/coupon/coupon"] = .init(allowed: ["scope"], required: [], ids: [])
        for page in identifiedPages { pages[page] = identified }
        for page in optionalIDPages { pages[page] = optionalID }
        // Club pages (CLB-*-01 parity r1): the keys each MP page reads in onLoad. `clubId` and `id` are both
        // accepted where the MP falls back from one to the other; the screen shows unavailable without a club.
        let clubKeyed = Rule(allowed: ["clubId", "id"], required: [], ids: ["clubId", "id"])
        for page in ["badges", "customers", "edit", "workbench"] { pages["pages/club/\(page)/index"] = clubKeyed }
        pages["pages/club/detail/index"] = Rule(allowed: ["id", "tab", "postId", "scan", "owner", "scope", "topicId"], required: [], ids: ["id", "postId", "topicId"])
        pages["pages/club/customer-detail/index"] = Rule(allowed: ["clubId", "memberId"], required: ["clubId", "memberId"], ids: ["clubId", "memberId"])
        pages["pages/club/checkin-detail/index"] = Rule(allowed: ["clubId", "registrationId"], required: ["clubId", "registrationId"], ids: ["clubId", "registrationId"])
        // CLB-enroll-08: no clubId still opens the page. The screen loads api/club/my and uses the one owned club.
        pages["pages/club/enroll/index"] = Rule(allowed: ["clubId", "clubName", "topicId", "id"], required: [], ids: ["clubId", "topicId", "id"])
        pages["pages/club/event-ops/index"] = Rule(allowed: ["clubId", "id", "activityId", "topicId", "recurrence"], required: [], ids: ["clubId", "id", "activityId", "topicId"])
        pages["pages/club/group-code/index"] = Rule(allowed: ["activityId", "activityName", "topicId", "topicName"], required: [], ids: ["activityId", "topicId"])
        pages["pages/club/join-requests/index"] = Rule(allowed: ["clubId"], required: ["clubId"], ids: ["clubId"])
        pages["pages/club/notify/index"] = Rule(allowed: ["clubId", "id", "activityId", "silent"], required: [], ids: ["clubId", "id", "activityId"])
        pages["pages/club/topic-detail/index"] = Rule(allowed: ["topicId", "clubId", "activityId", "id"], required: [], ids: ["topicId", "clubId", "activityId", "id"])
        pages["pages/club/topic-story/index"] = Rule(allowed: ["topicId", "clubId", "scope", "id"], required: [], ids: ["topicId", "clubId", "id"])
        // CLB-r8-governance-01 (MP governance js:204-207): no clubId still opens the page; the screen shows the
        // missing-param state (链接已失效 + 返回, `ClubGovernanceEntryRoute.Failure.missingClub`).
        pages["pages/club/governance/index"] = Rule(allowed: ["clubId", "memberId", "mode", "targetId", "targetMemberId", "targetName", "targetType"],
                                                    required: [], ids: ["clubId", "memberId", "targetId", "targetMemberId"])
        pages["pages/club/roles/index"] = Rule(allowed: ["clubId", "id", "activityId", "activityLabel", "memberId"], required: [], ids: ["clubId", "id", "activityId", "memberId"])
        // Subscribe-message landing pages from public hengyin (cur-push). Set last: `pages/coop/list/index` keeps `tab`.
        // `order/order?detailId=` (subscribe-message landing) opens that order; `orderinfo?outTradeNo=` (payment
        // receipt) has no by-number read, so it lands on 我的订单.
        pages["subpackageMember/order/order"] = Rule(allowed: ["detailId"], required: [], ids: ["detailId"])
        pages["subpackageMember/orderinfo/orderinfo"] = Rule(allowed: ["id", "outTradeNo"], required: [], ids: ["id"])
        pages["pages/coop/list/index"] = Rule(allowed: ["tab", "topicId", "topicName", "scope"], required: [], ids: ["topicId"])
        pages["subpackageA/pages/myproject/index"] = open
        pages["pages/merchant/ledger/index"] = Rule(allowed: ["view", "topicId", "ownerType", "ownerId", "source", "tab"], required: [], ids: ["topicId", "ownerType", "ownerId"])
        pages["pages/merchant/ledger/order-detail/index"] = Rule(allowed: ["recordType", "recordId"], required: [], ids: ["recordId"])
        pages["pages/merchant/ledger/batch-detail/index"] = Rule(allowed: ["batchId"], required: ["batchId"], ids: ["batchId"])
        pages["pages/merchant/relation/index"] = Rule(allowed: ["tab", "topicId"], required: [], ids: ["topicId"])
        pages["pages/merchant/coop-center/index"] = Rule(allowed: ["tab", "topicId"], required: [], ids: ["topicId"])
        pages["pages/merchant/profile/index"] = Rule(allowed: ["id", "poiId", "topicId", "topicName"], required: [], ids: ["id", "poiId", "topicId"])
        pages["pages/merchant/team/index"] = Rule(allowed: ["invite"], required: [], ids: [])
        pages["pages/coop/invite/index"] = Rule(allowed: ["type", "toId", "topicId", "originApplyId", "toName", "scope"], required: [], ids: ["toId", "topicId", "originApplyId"])
        pages["pages/coop/invite-detail/index"] = Rule(allowed: ["inviteId", "box"], required: [], ids: ["inviteId"])
        pages["pages/coop/nearby/index"] = Rule(allowed: ["topicId", "topicName"], required: [], ids: ["topicId"])
        pages["pages/coop/settlement-detail/index"] = Rule(allowed: ["source", "id", "topicId", "clubId", "personal"], required: [], ids: ["id", "topicId", "clubId"])
        // Play / roam pages whose MP onLoad reads a query (fix-parity play-roam: PLAY-10, PLAYC-1, RSESS-1, RSTAMP-1).
        pages["pages/play/index"] = Rule(allowed: ["topicId", "activityId", "registrationId", "regId", "topicName", "inviteCode"],
                                         required: [], ids: ["topicId", "activityId", "registrationId", "regId"])
        pages["pages/play/merchant/index"] = Rule(allowed: ["nodeId"], required: [], ids: ["nodeId"])
        // circle: the retired shim checks presence only; PlayCircleLegacyLink decides redirect vs 探索链接不完整.
        pages["pages/play/circle/index"] = Rule(allowed: ["topicId", "inviteCode", "registrationId"], required: [], ids: [])
        pages["pages/play/poi-challenge/index"] = Rule(allowed: ["poiId", "photo"], required: [], ids: ["poiId"])
        pages["subpackageRoam/citystamp/index"] = Rule(allowed: ["kind", "place"], required: [], ids: [])
        pages["subpackageRoam/official-route/index"] = optionalID
        pages["subpackageRoam/session/index"] = Rule(allowed: ["id", "shareToken", "sessionId", "ts"], required: [], ids: ["id"])
        pages["subpackageRoam/my-teams/index"] = Rule(allowed: ["tab", "ownerType", "ownerId", "scope"], required: [], ids: ["ownerType", "ownerId"])
        // mp-nav r3: MP poi-detail onLoad reads `poiId` (index.js:27; share path utils/place-share.js); native links use
        // `id`. Exactly one of the two, checked in init (`chein://mp/…` and notification `page` paths reach this rule).
        pages["subpackageRoam/poi-detail/index"] = Rule(allowed: ["id", "poiId"], required: [], ids: ["id", "poiId"])
        pages["subpackageRoam/citynode-code/index"] = Rule(allowed: ["poiId", "name"], required: [], ids: ["poiId"])
        // Parity r1 (player-content): pages whose MP `onLoad` reads a query now carry it to the native screen.
        for (page, rule) in queryPages { pages[page] = rule }
        // fix-parity r1 (account-publish X1): the keys each MP page reads in `onLoad`. Values are checked below.
        pages["pages/userinfo/userinfo"] = Rule(allowed: ["id", "userId", "tab", "topicId", "chapterId", "scope", "preview"], required: [], ids: ["id", "userId", "topicId", "chapterId"])
        pages["pages/talent/list/index"] = Rule(allowed: ["tab"], required: [], ids: [])
        pages["pages/gerenziliao/gerenziliao"] = Rule(allowed: ["field"], required: [], ids: [])
        pages["pages/addressinfo/addressinfo"] = optionalID
        pages["pages/agreement/index"] = Rule(allowed: ["type"], required: [], ids: [])
        pages["pages/shezhi/shezhi"] = Rule(allowed: ["scene"], required: [], ids: [])
        pages["pages/publish/fabu/index"] = Rule(allowed: ["id", "mode", "scope", "clubId"], required: [], ids: ["id", "clubId"])
        pages["pages/publish/temp/index"] = Rule(allowed: ["id", "scope", "from"], required: [], ids: ["id"])
        pages["pages/publish/activity/index"] = Rule(allowed: ["id", "scope"], required: [], ids: ["id"])
        pages["pages/publish/template-intro/index"] = Rule(allowed: ["scope"], required: [], ids: [])
        pages["pages/team/detail/index"] = Rule(allowed: ["teamId"], required: [], ids: ["teamId"])
        // Only the manual-code form; `?code=` invitations keep the team-invitation parser (NativeNavigationCompletion).
        pages["pages/team/join/index"] = Rule(allowed: ["entry"], required: ["entry"], ids: [])
        // F14c retired catalog: optional id opens the topic, a bare path opens home. `via=session` is the club-session entry.
        pages["pages/topic/catalog/index"] = optionalID
        // CLB-detail-11: 带票分享 lands here with the club that shared the edition.
        pages["pages/topic/index/index"] = Rule(allowed: ["id", "via", "sourceClubId", "clubCode"], required: ["id"], ids: ["id", "sourceClubId"])
        return pages
    }()

    /// Page-map paths whose native screen takes no query. A key on the link rejects the whole link.
    private static let openPages: [String] = [
        "pages/index/index",
        "pages/template/index",
        "pages/member/index/index",
        "pages/roam/index",
        "pages/privacy/index",
        "pages/deregister/index",
        "pages/activity/list/index",
        "pages/activity/official-inbox/index",
        "pages/activity/official-mine/index",
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
        "pages/publish/simple/index",
        "pages/publish/topicadd/topicadd",
        "pages/club/apply/index",
        "pages/club/create/index",
        "pages/merchant/index/index",
        "pages/merchant/apply/index",
        "pages/merchant/ledger/order-detail/index",
        "pages/merchant/aftercare/index",
        "pages/merchant/predict/index",
        "pages/merchant/aftercare/detail/index",
        "pages/merchant/marketing/index",
        "pages/merchant/reviews/index",
        "pages/merchant/marketing/ai-insight/index",
        "pages/merchant/citynode/index",
        "pages/merchant/citynode/create/index",
        "pages/merchant/decor/index",
        "pages/merchant/decor/ai-npc/index",
        "pages/merchant/decor/coop-setting/index",
        "pages/merchant/decor/gallery/index",
        "pages/merchant/decor/perks/index",
        "pages/merchant/customer/index",
        "pages/merchant/game-node/index",
        "pages/merchant/verify-records/index",
        "pages/merchant/crm-campaigns/index",
        "pages/coop/invite/index",
        "pages/coop/finance/index",
        "pages/coop/withdraw/index",
        "pages/coop/withdraw/records/index",
        "pages/square/list/index",
        "pages/address/address",
        "pages/shezhi/about/index",
        "pages/shezhi/marketing/index",
        "pages/mylike/mylike",
        "pages/crop/index",
        "subpackageMember/invoice-apply/index",
        "subpackageMember/invoice-titles/index",
        "subpackageMember/invoice-title-edit/index",
        "subpackageMember/complaint/index",
        "subpackageMember/coupon-wallet/index",
        "subpackageMember/coupon/coupon",
        "subpackageMember/couponInfo/couponInfo",
        "subpackageMember/mycanyu/mycanyu",
        "subpackageMember/myinvite/myinvite",
        "subpackageMember/order/order",
        "subpackageMember/points-history/index",
        "subpackageMember/report-mine/index",
        "subpackageMember/appeal-mine/index",
        "subpackageMember/tixian/tixian",
        "subpackageMember/tixianjilu/tixianjilu",
        "subpackageRoam/history/index",
        "subpackageRoam/nearby/index",
        "subpackageRoam/official-routes/index",
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

    /// MP `onLoad` keys per page (hengyin/chengyinhub-xcx). Ids are canonical positive decimals; nothing is required,
    /// so a bare path still opens and the screen shows its own missing state.
    private static let queryPages: [String: Rule] = [
        // shelf/index.js:405-414, topic-detail/index.js:295-300
        "pages/templatedetail/topic-preview/index": .init(allowed: ["id", "scope", "readonly"], required: [], ids: ["id"]),
        "pages/templatedetail/topic-detail/index": .init(allowed: ["id", "scope", "readonly", "tab"], required: [], ids: ["id"]),
        "pages/templatedetail/templatedetail": .init(allowed: ["id", "scope", "readonly"], required: ["id"], ids: ["id"]),
        // search2/index.js:505-513, search2/result/index.js:36-50, searchmap/index.js:1175-1190
        "pages/search2/index": .init(allowed: ["keyword"], required: [], ids: []),
        "pages/search2/result/index": .init(allowed: ["keyword", "categoryId", "cityCode", "city_code", "startDate", "endDate", "minPrice", "maxPrice", "sortType"],
                                            required: [], ids: ["categoryId"]),
        "pages/searchmap/index": .init(allowed: ["params"], required: [], ids: []),
        // baoming.js:318-327, official-organizer/index.js:87-95, im/chat/index.js:141-148
        "pages/activity/baoming/baoming": .init(allowed: ["activityId", "ticketId"], required: [], ids: ["activityId", "ticketId"]),
        "pages/activity/official-organizer/index": .init(allowed: ["id"], required: [], ids: ["id"]),
        "subpackageB/pages/im/chat/index": .init(allowed: ["conversationId", "type", "name", "avatar"], required: [], ids: ["conversationId"]),
        // merchantinfo.js:331-353, merchantapply/index.js:157-171, pricing/index.js:78-86, pricing/partner/index.js
        "pages/topic/merchantinfo/merchantinfo": .init(allowed: ["topicId", "id", "scope", "open"], required: [], ids: ["topicId", "id"]),
        "pages/topic/merchantapply/index": .init(allowed: ["id", "topicId", "nodeId", "templateId", "topicName", "chapterName", "nodeName"],
                                                 required: [], ids: ["id", "topicId", "nodeId", "templateId"]),
        "pages/topic/pricing/index": .init(allowed: ["topicId", "id", "scope", "club"], required: [], ids: ["topicId", "id"]),
        "pages/topic/pricing/partner/index": .init(allowed: ["topicId", "toId", "toType"], required: [], ids: ["topicId", "toId"]),
    ]

    /// Pages whose native screen is addressed by the existing canonical `id` query (`NativeContentTarget`, and
    /// `subpackageMember/orderinfo?id=`). No other key is accepted.
    private static let identifiedPages: [String] = [
        "pages/activity/detail/index",
        "pages/topic/index/index",
        "pages/square/detail/index",
        "subpackageMember/orderinfo/orderinfo",
    ]

    /// Same `id` key, not required: a bare path still opens, and a non-canonical id still rejects the link.
    private static let optionalIDPages: [String] = [
        "pages/activity/official-detail/index",
        "subpackageA/pages/infomationdetail/infomationdetail",
        // invoice/index.js invoiceOnLoad: `?id=` opens the detail; a bare path is the history.
        "subpackageMember/invoice/index",
    ]

    /// Keys whose MP values are a closed set: anything else would open a state the MP page never shows.
    private static let enumeratedValues: [String: [String: Set<String>]] = [
        "pages/userinfo/userinfo": ["tab": ["projects", "posts", "achievements", "about"], "scope": ["MERCHANT"], "preview": ["1"]],
        "pages/talent/list/index": ["tab": ["feed", "club"]],
        "pages/gerenziliao/gerenziliao": ["field": ["introduction", "category"]],
        "pages/shezhi/shezhi": ["scene": ["settings-deregister", "settings-profile", "settings-feedback", "settings-likes",
                                          "settings-how-to-play", "settings-identity-picker"]],
        "pages/publish/fabu/index": ["mode": ["1", "2"], "scope": ["MERCHANT"]],
        "pages/publish/temp/index": ["scope": ["MERCHANT", "my"], "from": ["fabu", "citynode"]],
        "pages/publish/activity/index": ["scope": ["MERCHANT"]],
        "pages/publish/template-intro/index": ["scope": ["MERCHANT"]],
        "pages/team/join/index": ["entry": ["code"]],
        "pages/merchant/ledger/order-detail/index": ["recordType": ["redemption", "activity_ticket", "session_fee"]],
        "pages/coop/list/index": ["scope": ["MERCHANT"]],
        "pages/coop/invite/index": ["type": ["0", "1"], "scope": ["MERCHANT"]],
        "pages/coop/invite-detail/index": ["box": ["received", "sent"]],
        "pages/coop/settlement-detail/index": ["personal": ["1"]],
        "pages/topic/index/index": ["via": ["session"]],
    ]

    public init?(path: String, query: [String: String]) {
        var page = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var incoming = query
        // fix-r10 R8-MEM-26-1b: the MP removed `subpackageMember/mytemplate/mytemplate` from app.json
        // (xcx 910de033). The page rule is gone; only this redirect is kept. It opens 我的发布 and drops the query.
        if page == "subpackageMember/mytemplate/mytemplate" {
            page = "pages/activity/official-mine/index"
            incoming = [:]
        }
        guard let rule = Self.reviewedPages[page] else { return nil }
        // Empty values are absent (the mini-program reads `options.x || ''`).
        let present = incoming.filter { !$0.value.isEmpty }
        guard Set(incoming.keys).isSubset(of: rule.allowed), rule.required.isSubset(of: Set(present.keys)) else { return nil }
        for (key, value) in present {
            guard value.utf16.count <= 512, value.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { return nil }
            if rule.ids.contains(key), Self.positiveID(value) == nil { return nil }
        }
        if page == "subpackageJourney/pages/landing/index", !["r", "g", "s"].contains(present["k"] ?? "") { return nil }
        // MP group-code accepts activityId or topicId. A name alone is not enough.
        if page == "pages/club/group-code/index", present["activityId"] == nil, present["topicId"] == nil { return nil }
        if page == "subpackageRoam/poi-detail/index", present.count != 1 { return nil }
        if page == "pages/coop/list/index", let tab = present["tab"], tab != "sent", tab != "received" { return nil }
        if page == "pages/merchant/ledger/index", MerchantFinanceRoute.normalize(present) == nil { return nil }
        if page == "pages/merchant/profile/index", MerchantPublicHomeLink.target(present) == nil { return nil }
        if page == "pages/merchant/team/index", let invite = present["invite"], (try? MerchantOperatorAcceptance(token: invite)) == nil { return nil }
        if let values = Self.enumeratedValues[page] {
            for (key, value) in present { if let allowed = values[key], !allowed.contains(value) { return nil } }
        }
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

    /// Club session card (`via=session`): the primary bar opens the session picker before self-play.
    public var opensSessionPickerFirst: Bool {
        page == "pages/topic/index/index" && query["via"] == "session"
    }

    /// `pages/topic/catalog/index`: a canonical id is the topic; anything else is home.
    public var catalogDestination: TopicCatalogDestination? {
        guard page == "pages/topic/catalog/index" else { return nil }
        if let raw = query["id"], let id = Self.positiveID(raw) { return .topic(id) }
        return .home
    }
}

public enum TopicCatalogDestination: Equatable, Sendable {
    case topic(Int)
    case home
}

/// CLB-enroll-08. No club id loads `api/club/my` and opens the one owned club.
public enum ClubEnrollMissingClubCopy {
    public static let title = "还没有可管理的俱乐部"
    public static let body = "成为俱乐部主理人后，可在这里查看报名名册"
    public static func clubID(explicit: Int?, ownedClubIDs: [Int]) -> Int? {
        if let explicit, explicit > 0 { return explicit }
        guard ownedClubIDs.count == 1 else { return nil }
        let only = ownedClubIDs[0]
        return only > 0 ? only : nil
    }
}
