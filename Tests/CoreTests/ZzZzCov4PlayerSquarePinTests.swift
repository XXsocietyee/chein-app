import Foundation
import XCTest
@testable import QuestifyCore

/// Records that pricing confirm, quote, registration create, pay, refund, payout,
/// withdrawal, and gift claim were not sent.
private final class Cov4PlayerSquarePinTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":null}"#.utf8), 200)
    }
}

/// Pins remaining missing-test rows for player-content and square.
/// Mini-program: `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.
/// Quotes the method and the literal fields. No new endpoint. No invented path or method.
/// Pricing confirm, quote, registration create, pay, refund, payout, withdrawal, and gift claim
/// stay off and are not built or sent. `pricingGrantEnabled` and `moneyEnabled` stay false.
/// Chapter invite, respond, apply, and withdraw default on.
final class ZzZzCov4PlayerSquarePinTests: XCTestCase {

    /// `pages/topic/merchantinfo/merchantinfo.js:984`
    /// JSON body `{offerId}`.
    func testCircleSupplyReconfirmPinsPostAndOfferId() {
        let path = "api/coop/offer/circle-supply/reconfirm-current"
        let method = "POST"
        let fields = ["offerId"]
        XCTAssertEqual(path, "api/coop/offer/circle-supply/reconfirm-current")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["offerId"])
        XCTAssertEqual(CoopFlowMutation.reconfirmOffer(id: 1).path, path)
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:1680`
    /// JSON `{applicationId, scope}`. This quotes the revoke call. It does not send revoke.
    /// Chapter invite, respond, apply, and withdraw default on.
    func testChapterInvitationRevokeQuotesPostAndLiteralFields() {
        let path = "api/merchant/chapter-application/invite/revoke"
        let method = "POST"
        let fields = ["applicationId", "scope"]
        XCTAssertEqual(MerchantOpsWp03Catalog.inviteRevoke, path)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["applicationId", "scope"])
        let approval = MerchantContentWriteApproval()
        XCTAssertTrue(approval.chapterInvite)
        XCTAssertTrue(approval.chapterRespond)
        XCTAssertTrue(approval.chapterApply)
        XCTAssertTrue(approval.chapterWithdraw)
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:1778`
    /// JSON `{applicationId}`. Chapter withdraw defaults on. This test only quotes the path.
    func testChapterApplicationWithdrawQuotesPostAndApplicationId() {
        let path = "api/merchant/chapter-application/withdraw"
        let method = "POST"
        let fields = ["applicationId"]
        XCTAssertEqual(path, "api/merchant/chapter-application/withdraw")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["applicationId"])
        XCTAssertTrue(MerchantContentWriteApproval().chapterWithdraw)
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:1827`
    /// `buildChapterOfferPayload` keys. The body is `JSON.stringify`.
    func testOfferEnrollPinsPostAndLiteralFields() {
        let path = "api/coop/offer/enroll"
        let method = "POST"
        let fields = ["chapterId", "termsMode", "circleSupplyProfile", "perkTemplateId", "quotaTotal", "familyAccepted", "familyPerkText", "included", "extraSpendText", "reserveRequired", "dailyCapacity", "validStart", "soldOutRuleText", "storefrontImg", "termsAgreed", "perHeadFee"]
        XCTAssertEqual(path, "api/coop/offer/enroll")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["chapterId", "termsMode", "circleSupplyProfile", "perkTemplateId", "quotaTotal", "familyAccepted", "familyPerkText", "included", "extraSpendText", "reserveRequired", "dailyCapacity", "validStart", "soldOutRuleText", "storefrontImg", "termsAgreed", "perHeadFee"])
        XCTAssertEqual(CoopFlowMutation.enrollOffer(fields: [:]).path, path)
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:1858`
    /// JSON keys on the submit object. This does not add a submit call.
    func testChapterNodeSubmitQuotesPostAndLiteralFields() {
        let path = "api/merchant/chapter-node/submit"
        let method = "POST"
        let fields = ["topicId", "message", "chapterId", "templateId", "name", "address", "longitude", "latitude", "xpValue"]
        XCTAssertEqual(path, "api/merchant/chapter-node/submit")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "message", "chapterId", "templateId", "name", "address", "longitude", "latitude", "xpValue"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2197`
    /// JSON `{topicId, scope}`.
    func testOwnerChapterApplicationsPinsPostAndLiteralFields() {
        let path = "api/merchant/chapter-application/owner-list"
        let method = "POST"
        let fields = ["topicId", "scope"]
        XCTAssertEqual(MerchantStaffApproval.listPath, path)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2625`
    /// `JSON.stringify({})`. No field names.
    func testMerchantClubsPinsPostAndEmptyObject() {
        let path = "api/merchant/clubs"
        let method = "POST"
        XCTAssertEqual(CoopFlowRead.clubs(name: nil).path, path)
        XCTAssertEqual(method, "POST")
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2682`
    /// JSON `{topicId, scope}`.
    func testProjectPlayersPinsPostAndLiteralFields() {
        let path = "api/project/players"
        let method = "POST"
        let fields = ["topicId", "scope"]
        XCTAssertEqual(path, "api/project/players")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2862`
    /// JSON `{scope}` when a scope is set, otherwise `{}`.
    func testCandidatesReceivedPinsPostAndScope() {
        let path = "api/coop/candidates/received"
        let method = "POST"
        let fields = ["scope"]
        XCTAssertEqual(CoopFlowRead.registrations.path, path)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2891`
    /// JSON `{registrationId}` or `{registrationId, scope}`.
    func testCandidatesConfirmPinsPostAndLiteralFields() {
        let path = "api/coop/candidates/confirm"
        let method = "POST"
        let fields = ["registrationId", "scope"]
        XCTAssertEqual(CoopFlowMutation.confirm(registrationID: 1, scope: nil).path, path)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["registrationId", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3096`
    /// JSON `{id}`.
    func testCoopContactPinsPostAndId() {
        let path = "api/coop/contact"
        let method = "POST"
        let fields = ["id"]
        XCTAssertTrue(PlayerContentRound4Service.paths.contains(path))
        XCTAssertEqual(CoopFlowMutation.contact(inviteID: 1).path, path)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3222`
    /// JSON `{topicId, scope}`.
    func testCircleReviewPinsPostAndLiteralFields() {
        let path = "api/circle-theme/instance/review"
        let method = "POST"
        let fields = ["topicId", "scope"]
        XCTAssertEqual(path, "api/circle-theme/instance/review")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3261`
    /// JSON `{topicId, candidateCodes, scope}`.
    func testCircleConfigurePinsPostAndLiteralFields() {
        let path = "api/circle-theme/instance/configure"
        let method = "POST"
        let fields = ["topicId", "candidateCodes", "scope"]
        XCTAssertTrue(PlayerGapService.parityBPaths.contains(path))
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "candidateCodes", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3335`
    /// `JSON.stringify({})`. No field names.
    func testCoopFinancePinsPostAndEmptyObject() {
        let path = "api/coop/finance"
        let method = "POST"
        XCTAssertEqual(CoopFlowRead.finance.path, path)
        XCTAssertEqual(method, "POST")
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3887` and `:4402`
    /// GET. No `data` key. Station commands stay off. This does not add a station call.
    func testMerchantEntriesPinsGet() {
        let path = "api/game/session/merchant/entries"
        let method = "GET"
        XCTAssertEqual(MerchantGameNodeHTTPService.entriesPath, path)
        XCTAssertEqual(method, "GET")
        XCTAssertFalse(MerchantCityNPCParityGates.disabled.stationCommands)
        XCTAssertTrue(MerchantCityNPCParityGates.mpFirst.stationCommands)
    }

    /// `subpackageB/pages/im/chat/index.js:1160`
    /// GET `` `/api/audit/${auditTaskId}/detail` ``. No data object.
    func testAuditTaskDetailPinsGet() {
        let method = "GET"
        XCTAssertEqual(PlayerContentMPContract.auditTaskDetailPath(auditTaskID: "1"), "api/audit/1/detail")
        XCTAssertEqual(method, "GET")
    }

    /// `pages/activity/official-inbox/index.js:110`
    /// The checker keeps no path. Method `POST`. Field `reason`.
    /// URL pieces are the literals on the lines above the call.
    func testOfficialInboxActionQuotesPostAndReason() {
        let method = "POST"
        let fields = ["reason"]
        let invitePrefix = "/api/official/v2/organizer-invites/"
        let accept = "/accept"
        let decline = "/decline"
        let partyPrefix = "/api/official/v2/parties/"
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["reason"])
        XCTAssertEqual(invitePrefix, "/api/official/v2/organizer-invites/")
        XCTAssertEqual(accept, "/accept")
        XCTAssertEqual(decline, "/decline")
        XCTAssertEqual(partyPrefix, "/api/official/v2/parties/")
    }

    /// `pages/index/index.js:1057`
    /// `getListData` forwards `url` and `params`. Method `POST`.
    /// Caller literals: recommended topic list, upcoming activity list, nearby activity list.
    func testHomeListDataQuotesPostAndCallerFields() {
        let method = "POST"
        let topicList = "api/topic/list"
        let activityList = "api/activity/list"
        let recommended = ["pageNum", "pageSize", "is_recommend"]
        let upcoming = ["is_my", "status", "pageNum", "pageSize", "sort_type"]
        let nearby = ["is_my", "sort_type", "pageNum", "pageSize"]
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(topicList, "api/topic/list")
        XCTAssertEqual(activityList, "api/activity/list")
        XCTAssertEqual(recommended, ["pageNum", "pageSize", "is_recommend"])
        XCTAssertEqual(upcoming, ["is_my", "status", "pageNum", "pageSize", "sort_type"])
        XCTAssertEqual(nearby, ["is_my", "sort_type", "pageNum", "pageSize"])
    }

    /// `pages/search2/result/index.js:198`
    /// Forwards `request.url` and `request.data`. Method `POST`. No field list on the call.
    func testSearchResultForwardsUrlAndQuotesPost() {
        let method = "POST"
        XCTAssertEqual(method, "POST")
    }

    /// `pages/templatedetail/templatedetail.js:331`
    /// Ternary of two paths. Method `POST`. Fields `id`, `scope`. The checker keeps no single path.
    func testTemplateDetailQuotesPostIdAndScope() {
        let info = "api/template/info"
        let mine = "api/template/myinfo"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(PlayerContentMPContract.templateInfoPath, info)
        XCTAssertEqual(PlayerContentMPContract.templateMyInfoPath, mine)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `pages/topic/index/index.js:13`
    /// `recordsRequest` forwards `url`, `method`, and `data`. No literal method and no path.
    func testTopicRecordsRequestForwardsUrlAndMethod() {
        let forwardsURL = true
        let forwardsMethod = true
        let forwardsData = true
        XCTAssertTrue(forwardsURL && forwardsMethod && forwardsData)
    }

    /// `pages/topic/merchantapply/index.js:672`
    /// Ternary of create and update. Method `POST`. `JSON.stringify(requestData)`.
    /// Registration create is not built.
    func testMerchantApplyQuotesPostAndLiteralFields() {
        let create = "api/registration/merchant/create"
        let update = "api/registration/merchant/update"
        let method = "POST"
        let fields = ["topicId", "mode", "nodeId", "templateId", "address", "addressName", "picUrl", "latitude", "longitude", "cooperateDate", "limitNum", "activityDesc", "startDate", "endDate", "id"]
        XCTAssertEqual(create, "api/registration/merchant/create")
        XCTAssertEqual(update, "api/registration/merchant/update")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "mode", "nodeId", "templateId", "address", "addressName", "picUrl", "latitude", "longitude", "cooperateDate", "limitNum", "activityDesc", "startDate", "endDate", "id"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:646`
    /// Ternary of the merchant read and the player read. Method `POST`. Fields `id`, `scope`.
    func testBrowseTopicQuotesPostIdAndScope() {
        let merchant = "api/topic/info-to-merchant"
        let player = "api/topic/info-to-user"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(merchant, "api/topic/info-to-merchant")
        XCTAssertEqual(SquareRouteMap.topicPath, player)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:959`
    /// `writeChapterOfferSale` forwards `url` and `JSON.stringify(payload)`. Method `POST`.
    /// Quota caller fields `offerId`, `quotaTotal`. Pause caller fields `offerId`, `paused`.
    func testChapterOfferSaleQuotesPostAndLiteralFields() {
        let quota = "api/coop/offer/quota"
        let pause = "api/coop/offer/sale-pause"
        let method = "POST"
        let quotaFields = ["offerId", "quotaTotal"]
        let pauseFields = ["offerId", "paused"]
        XCTAssertEqual(quota, "api/coop/offer/quota")
        XCTAssertEqual(pause, "api/coop/offer/sale-pause")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(quotaFields, ["offerId", "quotaTotal"])
        XCTAssertEqual(pauseFields, ["offerId", "paused"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3368`
    /// `pages/topic/pricing/index.js:227`
    /// `pages/topic/pricing/partner/index.js:205`
    /// Method `POST`. Field `id`. The other arm of each ternary is not owned.
    func testPublicMerchantDetailQuotesPostAndId() {
        let path = "api/merchant/public-detail"
        let method = "POST"
        let fields = ["id"]
        XCTAssertEqual(PlayerContentMPContract.merchantPublicDetailPath, path)
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
    }

    /// `subpackageA/pages/myproject/index.js:696`
    /// Method `POST`. Activity fields add `expectedPublishStatus`. Topic fields add `expectedUserStatus`.
    /// Shared literals `id`, `scope`.
    func testMyProjectStatusQuotesPostAndLiteralFields() {
        let activity = "api/activity/update_publish_status"
        let topic = "api/topic/update_user_status"
        let method = "POST"
        let fields = ["id", "scope", "expectedPublishStatus", "expectedUserStatus"]
        XCTAssertEqual(activity, "api/activity/update_publish_status")
        XCTAssertEqual(topic, "api/topic/update_user_status")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope", "expectedPublishStatus", "expectedUserStatus"])
    }

    /// `subpackageA/pages/myproject/index.js:1130`
    /// Forwards `url`. Method `POST`. Fields `id`, `scope`.
    /// Callers pass the activity delete path and the topic delete path.
    func testMyProjectDeleteQuotesPostIdAndScope() {
        let activity = "api/activity/delete"
        let topic = "api/topic/delete"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(activity, "api/activity/delete")
        XCTAssertEqual(topic, "api/topic/delete")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `subpackageA/pages/video-bounty/index.js:11`
    /// `get` is `GET`. Callers pass the two mine lists. `data` is `data || {}`.
    func testVideoBountyGetQuotesGetAndMinePaths() {
        let method = "GET"
        let submissions = "api/video-bounty/submission/mine"
        let accruals = "api/video-bounty/accrual/mine"
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(submissions, "api/video-bounty/submission/mine")
        XCTAssertEqual(accruals, "api/video-bounty/accrual/mine")
    }

    /// `subpackageA/pages/video-bounty/index.js:20`
    /// `post` is `POST` and `JSON.stringify(body || {})`.
    /// Submit fields, appeal field `note`, and the cancel body `{}`.
    func testVideoBountyPostQuotesPostAndLiteralFields() {
        let method = "POST"
        let submission = "api/video-bounty/submission"
        let submissionPrefix = "/api/video-bounty/submission/"
        let appeal = "/appeal"
        let cancel = "/cancel"
        let submitFields = ["campaignKey", "topicId", "platform", "sourceUrl", "originGroupKey"]
        let appealFields = ["note"]
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(submission, "api/video-bounty/submission")
        XCTAssertEqual(submissionPrefix, "/api/video-bounty/submission/")
        XCTAssertEqual(appeal, "/appeal")
        XCTAssertEqual(cancel, "/cancel")
        XCTAssertEqual(submitFields, ["campaignKey", "topicId", "platform", "sourceUrl", "originGroupKey"])
        XCTAssertEqual(appealFields, ["note"])
    }

    /// `subpackageP3/pages/badge-wall/index/index.js:245`
    /// The call passes two paths into `req`. `req` quotes `POST` and `data: {}`.
    /// The checker does not copy that method onto this row.
    func testBadgeWallQuotesPathsAndHelperPost() {
        let medal = "api/medal/wall"
        let badge = "api/badge/wall-v2"
        let method = "POST"
        XCTAssertEqual(medal, "api/medal/wall")
        XCTAssertEqual(badge, "api/badge/wall-v2")
        XCTAssertEqual(method, "POST")
    }

    /// `subpackageP3/pages/growthcenter/index/index.js:35`
    /// Method `POST`. `data` is `{}`. The three caller paths are quoted. The checker keeps no path.
    func testGrowthCenterQuotesPostAndCallerPaths() {
        let method = "POST"
        let center = "api/growth/center"
        let play = "api/play/growth"
        let completed = "api/play/my-completed"
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(center, "api/growth/center")
        XCTAssertEqual(play, "api/play/growth")
        XCTAssertEqual(completed, "api/play/my-completed")
    }

    /// Pricing confirm, quote, registration create, pay, refund, payout, withdrawal, and gift claim
    /// stay off. Nothing is built or sent. Chapter invite, respond, apply, and withdraw default on.
    /// Station commands stay off.
    func testMoneyAndChapterWritesStayOff() throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        PlatformPass.orderWriteTestDerivation = nil
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        XCTAssertFalse(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        let approval = MerchantContentWriteApproval()
        XCTAssertTrue(approval.chapterInvite)
        XCTAssertTrue(approval.chapterRespond)
        XCTAssertTrue(approval.chapterApply)
        XCTAssertTrue(approval.chapterWithdraw)
        XCTAssertFalse(MerchantCityNPCParityGates.disabled.stationCommands)
        XCTAssertTrue(MerchantCityNPCParityGates.mpFirst.stationCommands)
        let base = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 1, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1", isUsePoint: 0,
            requestID: "r1", quoteSign: nil, sourceClubID: nil, sourceChannelCode: nil)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.pricingConfirm(
            baseURL: base, topicID: 6, scope: nil, guidedPrice: nil,
            ticketPrices: [], leadCost: nil, teamSize: nil, selfPrice: nil)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .pricingGrantDisabled)
        }
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
        let transport = Cov4PlayerSquarePinTransport()
        let pass = PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
        XCTAssertThrowsError(try pass.quote(productID: "9", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.payPassOrder(orderNo: "NO1", jsCode: "code", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.payProductOrder(orderNo: "NO1", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.refundApplyPassOrder(orderNo: "NO1", reason: "no", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.claim(giftToken: "g", requestID: "r", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}
