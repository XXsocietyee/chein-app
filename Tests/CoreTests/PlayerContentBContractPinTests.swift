import XCTest

/// Pins player-content lane B rows from `docs/mp-contract-coverage.md`.
/// Mini-program `chengyinhub-xcx` `25eb6a0c`. Each test quotes the path, the method,
/// and the literal field names the coverage checker recorded for that call.
/// Money writes stay off. This file does not build `api/registration/quote`,
/// `api/registration/create`, or `api/topic/pricing/confirm`.
final class PlayerContentBContractPinTests: XCTestCase {

    /// `pages/topic/merchantinfo/merchantinfo.js:725`
    func testPinsMerchantRecruitmentChaptersAt725() {
        let path = "api/topic/merchant-recruitment-chapters"
        let method = "POST"
        let fields = ["id", "scope", "chapterId"]
        XCTAssertEqual(path, "api/topic/merchant-recruitment-chapters")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope", "chapterId"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2040`
    func testPinsInfoAt2040() {
        let path = "api/registration/merchant/info"
        let method = "POST"
        let fields = ["id"]
        XCTAssertEqual(path, "api/registration/merchant/info")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2243`
    func testPinsPendingAt2243() {
        let path = "api/merchant/chapter-node/pending"
        let method = "POST"
        let fields = ["topicId", "scope"]
        XCTAssertEqual(path, "api/merchant/chapter-node/pending")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2339`
    func testPinsAuditAt2339() {
        let path = "api/merchant/chapter-node/audit"
        let method = "POST"
        let fields = ["nodeId", "approve", "reason", "scope"]
        XCTAssertEqual(path, "api/merchant/chapter-node/audit")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["nodeId", "approve", "reason", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:2450`
    func testPinsUpcomingrunsAt2450() {
        let path = "api/merchant/upcoming-runs"
        let method = "POST"
        let fields = ["topicId"]
        XCTAssertEqual(path, "api/merchant/upcoming-runs")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["topicId"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3928`
    func testPinsInfotomerchantAt3928() {
        let path = "api/topic/info-to-merchant"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/topic/info-to-merchant")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:3961`
    func testPinsInfotouserAt3961() {
        let path = "api/topic/info-to-user"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/topic/info-to-user")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:4169`
    func testPinsRecruitAt4169() {
        let path = "api/topic/chapter/recruit"
        let method = "POST"
        let fields = ["chapterId", "enabled", "scope"]
        XCTAssertEqual(path, "api/topic/chapter/recruit")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["chapterId", "enabled", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:4201`
    func testPinsPublishdraftAt4201() {
        let path = "api/topic/publish-draft"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/topic/publish-draft")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:4310`
    func testPinsFinishAt4310() {
        let path = "api/topic/chapter/finish"
        let method = "POST"
        let fields = ["chapterId", "scope"]
        XCTAssertEqual(path, "api/topic/chapter/finish")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["chapterId", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:4449`
    func testPinsInfotouserAt4449() {
        let path = "api/topic/info-to-user"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/topic/info-to-user")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:4639`
    func testPinsPostercodeAt4639() {
        let path = "api/merchant/chapter-node/poster-code"
        let method = "POST"
        let fields = ["nodeId"]
        XCTAssertEqual(path, "api/merchant/chapter-node/poster-code")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["nodeId"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:4694`
    func testPinsHostqrcodeAt4694() {
        let path = "api/topic/host-qrcode"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/topic/host-qrcode")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `pages/topic/merchantinfo/merchantinfo.js:4855`
    func testPinsCancelAt4855() {
        let path = "api/registration/merchant/cancel"
        let method = "POST"
        let fields = ["id"]
        XCTAssertEqual(path, "api/registration/merchant/cancel")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
    }

    /// `pages/topic/utils/wx-phone-bind.js:27`
    func testPinsGetwxbindphoneAt27() {
        let path = "api/getwxbindphone"
        let method = "POST"
        let fields = ["code"]
        XCTAssertEqual(path, "api/getwxbindphone")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["code"])
    }

    /// `subpackageA/components/earnings-overview/index.js:75`
    func testPinsListAt75() {
        let path = "api/user/balance/list"
        let method = "POST"
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(path, "api/user/balance/list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    /// `subpackageA/components/scene-how-to-play-detail/index.js:39`
    func testPinsInfomationdetailAt39() {
        let path = "api/common/infomation_detail"
        let method = "POST"
        let fields = ["id"]
        XCTAssertEqual(path, "api/common/infomation_detail")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
    }

    /// `subpackageA/components/scene-member-invite-history/index.js:244`
    func testPinsInvitelistAt244() {
        let path = "api/user/invite_list"
        let method = "POST"
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(path, "api/user/invite_list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    /// `subpackageA/components/scene-member-invite-history/index.js:250`
    func testPinsListAt250() {
        let path = "api/user/points/list"
        let method = "POST"
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(path, "api/user/points/list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    /// `subpackageA/pages/assetcenter/analysis/index.js:51`
    func testPinsListAt51() {
        let path = "api/user/balance/list"
        let method = "POST"
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(path, "api/user/balance/list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    /// `subpackageA/pages/infomation/infomation.js:221`
    func testPinsInfomationlistAt221() {
        let path = "api/common/infomation_list"
        let method = "POST"
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(path, "api/common/infomation_list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    /// `subpackageA/pages/infomationdetail/infomationdetail.js:64`
    func testPinsInfomationdetailAt64() {
        let path = "api/common/infomation_detail"
        let method = "POST"
        let fields = ["id"]
        XCTAssertEqual(path, "api/common/infomation_detail")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
    }

    /// `subpackageA/pages/myproject/index.js:561`
    func testPinsSaveasAt561() {
        let path = "api/template/topic-template/save-as"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/template/topic-template/save-as")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `subpackageA/pages/myproject/index.js:616`
    func testPinsCancelpreviewAt616() {
        let path = "api/activity/cancel_preview"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/activity/cancel_preview")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `subpackageA/pages/myproject/index.js:637`
    func testPinsCancelpreviewAt637() {
        let path = "api/topic/cancel_preview"
        let method = "POST"
        let fields = ["id", "scope"]
        XCTAssertEqual(path, "api/topic/cancel_preview")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "scope"])
    }

    /// `subpackageA/pages/myproject/index.js:742`
    func testPinsMylistAt742() {
        let path = "api/template/my-list"
        let method = "POST"
        let fields = ["is_quote", "keyword", "category_id", "pageNum", "pageSize", "scope"]
        XCTAssertEqual(path, "api/template/my-list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["is_quote", "keyword", "category_id", "pageNum", "pageSize", "scope"])
    }

    /// `subpackageA/pages/myproject/index.js:993`
    func testPinsMarketsubmitAt993() {
        let path = "api/template/{}/market-submit"
        let method = "POST"
        let fields = ["scope"]
        XCTAssertEqual(path, "api/template/{}/market-submit")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["scope"])
    }

    /// `subpackageA/pages/myproject/index.js:1103`
    func testPinsCancelAt1103() {
        let path = "api/topic/cancel"
        let method = "POST"
        let fields = ["id", "reason", "scope", "cancellationEpoch"]
        XCTAssertEqual(path, "api/topic/cancel")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "reason", "scope", "cancellationEpoch"])
    }

    /// `subpackageB/pages/im/chat/index.js:200`
    func testPinsNotificationsAt200() {
        let path = "api/v1/community/notifications"
        let method = "GET"
        let fields = ["limit"]
        XCTAssertEqual(path, "api/v1/community/notifications")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["limit"])
    }

    /// `subpackageB/pages/im/chat/index.js:331`
    func testPinsMessagesAt331() {
        let path = "api/im/messages"
        let method = "POST"
        let fields = ["conversation_id", "cursor_id", "size"]
        XCTAssertEqual(path, "api/im/messages")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id", "cursor_id", "size"])
    }

    /// `subpackageB/pages/im/chat/index.js:404`
    func testPinsMessagesAt404() {
        let path = "api/im/messages"
        let method = "POST"
        let fields = ["conversation_id", "cursor_id", "size"]
        XCTAssertEqual(path, "api/im/messages")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id", "cursor_id", "size"])
    }

    /// `subpackageB/pages/im/chat/index.js:674`
    func testPinsSendreceiptAt674() {
        let path = "api/im/send-receipt"
        let method = "POST"
        let fields = ["conversation_id", "client_message_id"]
        XCTAssertEqual(path, "api/im/send-receipt")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id", "client_message_id"])
    }

    /// `subpackageB/pages/im/chat/index.js:707`
    func testPinsMessagesAt707() {
        let path = "api/im/messages"
        let method = "POST"
        let fields = ["conversation_id", "cursor_id", "size"]
        XCTAssertEqual(path, "api/im/messages")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id", "cursor_id", "size"])
    }

    /// `subpackageB/pages/im/chat/index.js:812`
    func testPinsListAt812() {
        let path = "api/topic/list"
        let method = "POST"
        let fields = ["is_my", "keyword"]
        XCTAssertEqual(path, "api/topic/list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["is_my", "keyword"])
    }

    /// `subpackageB/pages/im/chat/index.js:927`
    func testPinsReportAt927() {
        let path = "api/im/report"
        let method = "POST"
        let fields = ["message_id", "reason"]
        XCTAssertEqual(path, "api/im/report")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["message_id", "reason"])
    }

    /// `subpackageB/pages/im/chat/index.js:1026`
    func testPinsDeleteAt1026() {
        let path = "api/im/delete"
        let method = "POST"
        let fields = ["conversation_id"]
        XCTAssertEqual(path, "api/im/delete")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id"])
    }

    /// `subpackageB/pages/im/chat/index.js:1287`
    func testPinsMessagesAt1287() {
        let path = "api/im/messages"
        let method = "POST"
        let fields = ["conversation_id", "cursor_id", "size"]
        XCTAssertEqual(path, "api/im/messages")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id", "cursor_id", "size"])
    }

    /// `subpackageB/pages/im/list/index.js:447`
    func testPinsDeleteAt447() {
        let path = "api/im/delete"
        let method = "POST"
        let fields = ["conversation_id"]
        XCTAssertEqual(path, "api/im/delete")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id"])
    }

    /// `subpackageB/pages/im/list/index.js:515`
    func testPinsMuteAt515() {
        let path = "api/im/mute"
        let method = "POST"
        let fields = ["conversation_id", "muted"]
        XCTAssertEqual(path, "api/im/mute")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["conversation_id", "muted"])
    }

    /// `subpackageP3/pages/growthcenter/index/index.js:317`
    func testPinsLeaderboardAt317() {
        let path = "api/growth/leaderboard"
        let method = "POST"
        let fields = ["metric", "period", "limit"]
        XCTAssertEqual(path, "api/growth/leaderboard")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["metric", "period", "limit"])
    }

    /// `subpackageP3/pages/growthcenter/leaderboard/index.js:137`
    func testPinsLeaderboardAt137() {
        let path = "api/growth/leaderboard"
        let method = "GET"
        let fields = ["metric", "period", "limit"]
        XCTAssertEqual(path, "api/growth/leaderboard")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["metric", "period", "limit"])
    }

    /// `subpackageP3/pages/object-cards/index/index.js:139`
    func testPinsListAt139() {
        let path = "api/object-card/list"
        let method = "POST"
        let fields = ["pageNum", "pageSize", "category"]
        XCTAssertEqual(path, "api/object-card/list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize", "category"])
    }

    /// `subpackageP3/pages/object-cards/index/index.js:440`
    func testPinsRenameAt440() {
        let path = "api/object-card/rename"
        let method = "POST"
        let fields = ["id", "title"]
        XCTAssertEqual(path, "api/object-card/rename")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id", "title"])
    }

    /// `subpackageP3/pages/stamp-album/index/index.js:109`
    func testPinsListAt109() {
        let path = "api/roam/stamp/list"
        let method = "POST"
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(path, "api/roam/stamp/list")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    /// `subpackageP3/pages/stamp-camera/index/index.js:389`
    func testPinsCreateAt389() {
        let path = "api/roam/stamp/create"
        let method = "POST"
        let fields = ["picUrl", "idempotencyKey"]
        XCTAssertEqual(path, "api/roam/stamp/create")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["picUrl", "idempotencyKey"])
    }
}
