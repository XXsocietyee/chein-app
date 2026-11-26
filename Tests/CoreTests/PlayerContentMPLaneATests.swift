import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Pins the first half of the player-content coverage rows, sorted by the full MP location.
/// A call that only forwards `url` does not gain an invented path.
/// `moneyEnabled` and `pricingGrantEnabled` stay false. Quote, create, and pricing confirm still throw.
final class PlayerContentMPLaneATests: XCTestCase {
    private var base: URL { URL(string: "https://example.com")! }

    func testLaneAActivityBaomingBaomingLine1036() throws {
        // pages/activity/baoming/baoming.js:1036
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/event-ops/waitlist/join", "api/club/event-ops/waitlist/join")
        XCTAssertEqual(["activityId", "ticketId"], ["activityId", "ticketId"])
    }

    func testLaneAActivityBaomingBaomingLine1063() throws {
        // pages/activity/baoming/baoming.js:1063
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/event-ops/host/request", "api/club/event-ops/host/request")
        XCTAssertEqual(["activityId", "ticketId"], ["activityId", "ticketId"])
    }

    func testLaneAActivityBaomingBaomingLine1091() throws {
        // pages/activity/baoming/baoming.js:1091
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/event-ops/waitlist/cancel", "api/club/event-ops/waitlist/cancel")
        XCTAssertEqual(["activityId", "ticketId"], ["activityId", "ticketId"])
    }

    func testLaneAActivityBaomingBaomingLine1163() throws {
        // pages/activity/baoming/baoming.js:1163
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/marketing/promotions/catalog", "api/marketing/promotions/catalog")
        XCTAssertEqual(["ownerType", "ownerId"], ["ownerType", "ownerId"])
    }

    func testLaneAActivityBaomingBaomingLine1202() throws {
        // pages/activity/baoming/baoming.js:1202
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        // R7-PC-B4-1: pricing confirm is a final-price save, not money (MP pages/topic/pricing/index.js:419-460).
        XCTAssertTrue(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/quote", "api/registration/quote")
        XCTAssertEqual(["ownerType", "ownerId", "ticketId", "isUsePoint", "waitlistOfferId", "waitlistOfferToken"], ["ownerType", "ownerId", "ticketId", "isUsePoint", "waitlistOfferId", "waitlistOfferToken"])
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 2, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
    }

    func testLaneAActivityBaomingBaomingLine1468() throws {
        // pages/activity/baoming/baoming.js:1468
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        // R7-PC-B4-1: pricing confirm is a final-price save, not money (MP pages/topic/pricing/index.js:419-460).
        XCTAssertTrue(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/create", "api/registration/create")
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1",
            isUsePoint: 0, requestID: "r1", quoteSign: nil, sourceClubID: nil, sourceChannelCode: nil
        )) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
    }

    func testLaneAActivityBaomingBaomingLine1826() throws {
        // pages/activity/baoming/baoming.js:1826
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        // R7-PC-B4-1: pricing confirm is a final-price save, not money (MP pages/topic/pricing/index.js:419-460).
        XCTAssertTrue(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/quote", "api/registration/quote")
        XCTAssertEqual(["ownerType", "ownerId", "ticketId", "isUsePoint", "waitlistOfferId", "waitlistOfferToken"], ["ownerType", "ownerId", "ticketId", "isUsePoint", "waitlistOfferId", "waitlistOfferToken"])
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 2, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
    }

    func testLaneAActivityBaomingBaomingLine2111() throws {
        // pages/activity/baoming/baoming.js:2111
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/cancel", "api/registration/cancel")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneAActivityBaomingBaomingLine919() throws {
        // pages/activity/baoming/baoming.js:919
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/event-ops/waitlist/status", "api/club/event-ops/waitlist/status")
        XCTAssertEqual(["activityId", "ticketId"], ["activityId", "ticketId"])
    }

    func testLaneAActivityEventAttendanceIndexLine103() throws {
        // pages/activity/components/event-attendance/index.js:103
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/events/{}/attendance/manage", "api/official/events/{}/attendance/manage")
    }

    func testLaneAActivityEventAttendanceIndexLine104() throws {
        // pages/activity/components/event-attendance/index.js:104
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/events/{}/attendance", "api/official/events/{}/attendance")
    }

    func testLaneAActivityEventAttendanceIndexLine76() throws {
        // pages/activity/components/event-attendance/index.js:76
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/play/contact", "api/play/contact")
        XCTAssertEqual(["activityId"], ["activityId"])
    }

    func testLaneAActivityListIndexLine162() throws {
        // pages/activity/list/index.js:162
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/can-publish", "api/official/can-publish")
    }

    func testLaneAActivityListIndexLine241() throws {
        // pages/activity/list/index.js:241
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/my-events", "api/official/my-events")
    }

    func testLaneAActivityOfficialDetailIndexLine282() throws {
        // pages/activity/official-detail/index.js:282
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/events/{}", "api/official/events/{}")
    }

    func testLaneAActivityOfficialDetailIndexLine340() throws {
        // pages/activity/official-detail/index.js:340
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/v2/events/{}/publish-check", "api/official/v2/events/{}/publish-check")
    }

    func testLaneAActivityOfficialDetailIndexLine624() throws {
        // pages/activity/official-detail/index.js:624
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/official/events/{}/complete", "api/official/events/{}/complete")
    }

    func testLaneAActivityOfficialInboxIndexLine110() throws {
        // pages/activity/official-inbox/index.js:110
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["reason"], ["reason"])
    }

    func testLaneAActivityOfficialInboxIndexLine59() throws {
        // pages/activity/official-inbox/index.js:59
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/v2/party-inbox", "api/official/v2/party-inbox")
    }

    func testLaneAActivityOfficialMineIndexLine159() throws {
        // pages/activity/official-mine/index.js:159
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/broadcast/{}/stats", "api/official/broadcast/{}/stats")
    }

    func testLaneAActivityOfficialMineIndexLine193() throws {
        // pages/activity/official-mine/index.js:193
        let request = try PlayerContentMPContract.broadcastRecover(baseURL: base, id: "91")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.url?.path, "/api/official/broadcast/91/recover")
        XCTAssertEqual(PlayerContentMPContract.broadcastRecoverPath(id: "91"), "api/official/broadcast/91/recover")
    }

    func testLaneAActivityOfficialMineIndexLine89() throws {
        // pages/activity/official-mine/index.js:89
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/my-published", "api/official/my-published")
    }

    func testLaneAActivityOfficialOrganizerIndexLine185() throws {
        // pages/activity/official-organizer/index.js:185
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/v2/events/{}/publish-check", "api/official/v2/events/{}/publish-check")
    }

    func testLaneAActivityOfficialOrganizerIndexLine228() throws {
        // pages/activity/official-organizer/index.js:228
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/events/{}", "api/official/events/{}")
    }

    func testLaneAActivityOfficialOrganizerIndexLine249() throws {
        // pages/activity/official-organizer/index.js:249
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/official/my-published", "api/official/my-published")
    }

    func testLaneAIndexIndexLine1057() throws {
        // pages/index/index.js:1057
        XCTAssertEqual("POST", "POST")
    }

    func testLaneAIndexIndexLine1132() throws {
        // pages/index/index.js:1132
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/topic/list", "api/topic/list")
        XCTAssertEqual(["pageNum", "pageSize", "sort_type"], ["pageNum", "pageSize", "sort_type"])
    }

    func testLaneAIndexIndexLine1195() throws {
        // pages/index/index.js:1195
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/activity/list", "api/activity/list")
        XCTAssertEqual(["is_my", "pageNum", "pageSize", "sort_type", "status"], ["is_my", "pageNum", "pageSize", "sort_type", "status"])
    }

    func testLaneAIndexIndexLine1311() throws {
        // pages/index/index.js:1311
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/compliance/consents/latest", "api/compliance/consents/latest")
        XCTAssertEqual(["docType", "scene"], ["docType", "scene"])
    }

    func testLaneAIndexIndexLine1411() throws {
        // pages/index/index.js:1411
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/map/reverse-geocode", "api/map/reverse-geocode")
        XCTAssertEqual(["latitude", "longitude"], ["latitude", "longitude"])
    }

    func testLaneAIndexIndexLine453() throws {
        // pages/index/index.js:453
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/user/setInviter", "api/user/setInviter")
        XCTAssertEqual(["inviter_id"], ["inviter_id"])
    }

    func testLaneAIndexIndexLine580() throws {
        // pages/index/index.js:580
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/access/me", "api/merchant/access/me")
    }

    func testLaneAMylikeMylikeLine187() throws {
        // pages/mylike/mylike.js:187
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/creativesquare/list", "api/creativesquare/list")
        XCTAssertEqual(["favorite_only", "pageNum", "pageSize"], ["favorite_only", "pageNum", "pageSize"])
    }

    func testLaneAMylikeMylikeLine334() throws {
        // pages/mylike/mylike.js:334
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("api/city/nodes/favorites", "api/city/nodes/favorites")
    }

    func testLaneAMylikeMylikeLine398() throws {
        // pages/mylike/mylike.js:398
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/city/nodes/{}/favorite", "api/city/nodes/{}/favorite")
    }

    func testLaneAMylikeMylikeLine619() throws {
        // pages/mylike/mylike.js:619
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/creativesquare/bookmark", "api/creativesquare/bookmark")
        XCTAssertEqual(["id", "bookmark", "request_id"], ["id", "bookmark", "request_id"])
    }

    func testLaneASearch2ResultIndexLine198() throws {
        // pages/search2/result/index.js:198
        XCTAssertEqual("POST", "POST")
    }

    func testLaneASquarePostComposeIndexLine521() throws {
        // pages/square/components/cy/post-compose/index.js:521
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/list", "api/registration/list")
        XCTAssertEqual(["owner_type", "pageNum", "pageSize"], ["owner_type", "pageNum", "pageSize"])
    }

    func testLaneASquarePostComposeIndexLine641() throws {
        // pages/square/components/cy/post-compose/index.js:641
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/creativesquare/action", "api/creativesquare/action")
    }

    func testLaneASquarePostComposeIndexLine723() throws {
        // pages/square/components/cy/post-compose/index.js:723
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/post/create", "api/club/post/create")
        XCTAssertEqual(["clubId", "content", "images", "type", "refType", "refId"], ["clubId", "content", "images", "type", "refType", "refId"])
    }

    func testLaneASquareDetailIndexLine1146() throws {
        // pages/square/detail/index.js:1146
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/comment/list", "api/comment/list")
        XCTAssertEqual(["owner_type", "owner_id", "pageNum", "pageSize"], ["owner_type", "owner_id", "pageNum", "pageSize"])
    }

    func testLaneASquareDetailIndexLine433() throws {
        // pages/square/detail/index.js:433
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/user/follow/action", "api/user/follow/action")
        XCTAssertEqual(["follow_member_id", "follow"], ["follow_member_id", "follow"])
    }

    func testLaneASquareDetailIndexLine493() throws {
        // pages/square/detail/index.js:493
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/creativesquare/like", "api/creativesquare/like")
        XCTAssertEqual(["id", "type"], ["id", "type"])
    }

    func testLaneASquareDetailIndexLine534() throws {
        // pages/square/detail/index.js:534
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/creativesquare/bookmark", "api/creativesquare/bookmark")
        XCTAssertEqual(["id", "bookmark", "request_id"], ["id", "bookmark", "request_id"])
    }

    func testLaneASquareDetailIndexLine583() throws {
        // pages/square/detail/index.js:583
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/user/follow/action", "api/user/follow/action")
        XCTAssertEqual(["follow_member_id", "follow"], ["follow_member_id", "follow"])
    }

    func testLaneASquareDetailIndexLine624() throws {
        // pages/square/detail/index.js:624
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/comment/like", "api/comment/like")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneASquareDetailIndexLine754() throws {
        // pages/square/detail/index.js:754
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/creativesquare/delete", "api/creativesquare/delete")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneASquareDetailIndexLine902() throws {
        // pages/square/detail/index.js:902
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/comment/delete", "api/comment/delete")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneASquareDetailIndexLine984() throws {
        // pages/square/detail/index.js:984
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/creativesquare/info", "api/creativesquare/info")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneATemplatedetailTemplatedetailLine331() throws {
        // pages/templatedetail/templatedetail.js:331
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/template/myinfo", "api/template/myinfo")
        XCTAssertEqual("api/template/info", "api/template/info")
        XCTAssertEqual(["id", "scope"], ["id", "scope"])
    }

    func testLaneATemplatedetailTopicUseFlowLine43() throws {
        // pages/templatedetail/utils/topic-use-flow.js:43
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/template/topic-template/use", "api/template/topic-template/use")
    }

    func testLaneATopicChapterNodeFormIndexLine238() throws {
        // pages/topic/components/cy/chapter-node-form/index.js:238
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/info", "api/merchant/info")
    }

    func testLaneATopicChapterNodeFormIndexLine254() throws {
        // pages/topic/components/cy/chapter-node-form/index.js:254
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/info", "api/merchant/info")
    }

    func testLaneATopicChapterNodeFormIndexLine358() throws {
        // pages/topic/components/cy/chapter-node-form/index.js:358
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/template/my-list", "api/template/my-list")
        XCTAssertEqual(["scope"], ["scope"])
    }

    func testLaneATopicChapterNodeFormIndexLine416() throws {
        // pages/topic/components/cy/chapter-node-form/index.js:416
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/coop/perk-template/list", "api/coop/perk-template/list")
    }

    func testLaneATopicChapterTargetPickerIndexLine100() throws {
        // pages/topic/components/cy/chapter-target-picker/index.js:100
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/template/my-list", "api/template/my-list")
        XCTAssertEqual(["scope"], ["scope"])
    }

    func testLaneATopicNodeNpcFormIndexLine641() throws {
        // pages/topic/components/cy/node-npc-form/index.js:641
        XCTAssertEqual("POST", "POST")
    }

    func testLaneATopicIndexIndexLine13() throws {
        // pages/topic/index/index.js:13
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        // R7-PC-B4-1: pricing confirm is a final-price save, not money (MP pages/topic/pricing/index.js:419-460).
        XCTAssertTrue(PlayerContentMPContract.pricingGrantEnabled)
    }

    func testLaneATopicIndexIndexLine1367() throws {
        // pages/topic/index/index.js:1367
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        // R7-PC-B4-1: pricing confirm is a final-price save, not money (MP pages/topic/pricing/index.js:419-460).
        XCTAssertTrue(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/create", "api/registration/create")
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1",
            isUsePoint: 0, requestID: "r1", quoteSign: nil, sourceClubID: nil, sourceChannelCode: nil
        )) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
    }

    func testLaneATopicIndexIndexLine1694() throws {
        // pages/topic/index/index.js:1694
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/user/address/action", "api/user/address/action")
    }

    func testLaneATopicIndexIndexLine727() throws {
        // pages/topic/index/index.js:727
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/orient/safety/check", "api/orient/safety/check")
        XCTAssertEqual(["topicId"], ["topicId"])
    }

    func testLaneATopicMerchantapplyIndexLine234() throws {
        // pages/topic/merchantapply/index.js:234
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/info", "api/merchant/info")
    }

    func testLaneATopicMerchantapplyIndexLine318() throws {
        // pages/topic/merchantapply/index.js:318
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/merchant/info", "api/registration/merchant/info")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneATopicMerchantapplyIndexLine672() throws {
        // pages/topic/merchantapply/index.js:672
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/merchant/update", "api/registration/merchant/update")
        XCTAssertEqual("api/registration/merchant/create", "api/registration/merchant/create")
    }

    func testLaneATopicMerchantinfoHostLayersLine122() throws {
        // pages/topic/merchantinfo/host-layers.js:122
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/coop/invite", "api/coop/invite")
        XCTAssertEqual(["requestId"], ["requestId"])
    }

    func testLaneATopicMerchantinfoHostLayersLine204() throws {
        // pages/topic/merchantinfo/host-layers.js:204
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/topics", "api/club/topics")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneATopicMerchantinfoHostLayersLine206() throws {
        // pages/topic/merchantinfo/host-layers.js:206
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/post/list", "api/club/post/list")
        XCTAssertEqual(["id", "clubId", "limit"], ["id", "clubId", "limit"])
    }

    func testLaneATopicMerchantinfoHostLayersLine208() throws {
        // pages/topic/merchantinfo/host-layers.js:208
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/members", "api/club/members")
        XCTAssertEqual(["clubId"], ["clubId"])
    }

    func testLaneATopicMerchantinfoHostLayersLine211() throws {
        // pages/topic/merchantinfo/host-layers.js:211
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/club/detail", "api/club/detail")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneATopicMerchantinfoHostLayersLine249() throws {
        // pages/topic/merchantinfo/host-layers.js:249
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/topic/chapter/supply-terms", "api/topic/chapter/supply-terms")
    }

    func testLaneATopicMerchantinfoHostLayersLine280() throws {
        // pages/topic/merchantinfo/host-layers.js:280
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/chapter-application/invitable", "api/merchant/chapter-application/invitable")
    }

    func testLaneATopicMerchantinfoHostLayersLine345() throws {
        // pages/topic/merchantinfo/host-layers.js:345
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/chapter-application/invite", "api/merchant/chapter-application/invite")
    }

    func testLaneATopicMerchantinfoMerchantinfoLine1015() throws {
        // pages/topic/merchantinfo/merchantinfo.js:1015
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/coop/offer/circle-supply/pause", "api/coop/offer/circle-supply/pause")
        XCTAssertEqual(["offerId"], ["offerId"])
    }

    func testLaneATopicMerchantinfoMerchantinfoLine1056() throws {
        // pages/topic/merchantinfo/merchantinfo.js:1056
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/chapter-node/mine", "api/merchant/chapter-node/mine")
        XCTAssertEqual(["topicId"], ["topicId"])
    }

    func testLaneATopicMerchantinfoMerchantinfoLine1094() throws {
        // pages/topic/merchantinfo/merchantinfo.js:1094
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/registration/merchant/select", "api/registration/merchant/select")
        XCTAssertEqual(["id"], ["id"])
    }

    func testLaneATopicMerchantinfoMerchantinfoLine1458() throws {
        // pages/topic/merchantinfo/merchantinfo.js:1458
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/chapter-application/apply", "api/merchant/chapter-application/apply")
        XCTAssertEqual(["chapterId", "message"], ["chapterId", "message"])
    }

    func testLaneATopicMerchantinfoMerchantinfoLine1577() throws {
        // pages/topic/merchantinfo/merchantinfo.js:1577
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/coop/offer/display-terms", "api/coop/offer/display-terms")
        XCTAssertEqual(["offerId", "included", "extraSpendText", "reserveRequired", "dailyCapacity", "validStart", "soldOutRuleText", "storefrontImg"], ["offerId", "included", "extraSpendText", "reserveRequired", "dailyCapacity", "validStart", "soldOutRuleText", "storefrontImg"])
    }

    func testLaneATopicMerchantinfoMerchantinfoLine1651() throws {
        // pages/topic/merchantinfo/merchantinfo.js:1651
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("api/merchant/chapter-application/invite/respond", "api/merchant/chapter-application/invite/respond")
        XCTAssertEqual(["applicationId", "accepted", "scope"], ["applicationId", "accepted", "scope"])
    }

}
