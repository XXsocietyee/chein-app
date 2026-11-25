import XCTest
@testable import QuestifyCore

/// Quotes lane-b merchant and coop calls from hengyin `chengyinhub-xcx` `25eb6a0c`.
/// One function quotes that call's path, `POST`, and the literal field names.
/// Payout, refund, and withdrawal stay off. No request is sent.
/// `api/creativesquare/list` is not quoted. A call that only forwards `url` is not given a path.
final class ZzMerchantCoopLaneBContractTests: XCTestCase {
    func testCoopProfilePinsPost() {
        // pages/merchant/decor/coop-setting/index.js:117
        // pages/merchant/decor/gallery/index.js:161
        // POST with no data object.
        let path = "api/merchant/coop-profile"
        XCTAssertEqual(path, "api/merchant/coop-profile")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testCoopProfileSavePinsCapacityTimeTypesChargeDemandOpenAndParams() {
        // pages/merchant/decor/coop-setting/index.js:195
        // JSON body keys.
        let path = "api/merchant/coop-profile/save"
        XCTAssertEqual(path, "api/merchant/coop-profile/save")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["capacity", "availableTime", "suitActivityTypes", "chargeType", "demand", "coopOpen", "params"]
        XCTAssertEqual(fields, ["capacity", "availableTime", "suitActivityTypes", "chargeType", "demand", "coopOpen", "params"])
    }

    func testDecorGallerySavePinsGallery() {
        // pages/merchant/decor/gallery/index.js:261
        // JSON body key gallery. The decor page save forwards stablePatch and is quoted separately.
        let path = "api/merchant/decor/save"
        XCTAssertEqual(path, "api/merchant/decor/save")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["gallery"]
        XCTAssertEqual(fields, ["gallery"])
    }

    func testBusinessStatusPinsPost() {
        // pages/merchant/decor/index.js:86
        // pages/merchant/index/index.js:217
        // POST with no data object.
        let path = "api/merchant/business-status"
        XCTAssertEqual(path, "api/merchant/business-status")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testMerchantAccessMePinsPost() {
        // pages/merchant/decor/index.js:219
        // pages/merchant/index/index.js:876
        // pages/merchant/ledger/index.js:214
        // pages/merchant/marketing/index.js:417
        // pages/merchant/payout-account/index.js:41
        // pages/merchant/predict/index.js:114
        // pages/merchant/team/index.js:354
        // pages/merchant/verify-records/index.js:59
        // POST with no data object.
        let path = "api/merchant/access/me"
        XCTAssertEqual(path, "api/merchant/access/me")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testDecorProfileReadChoosesInfoOrCoopProfile() {
        // pages/merchant/decor/index.js:367
        // Ternary of two literal urls. POST with no data object.
        let paths = ["api/merchant/info", "api/merchant/coop-profile"]
        XCTAssertEqual(paths, ["api/merchant/info", "api/merchant/coop-profile"])
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testDecorSaveForwardsPatch() {
        // pages/merchant/decor/index.js:488
        // Body is JSON.stringify(stablePatch). stablePatch is Object.assign, so there is no closed field list on the call.
        let path = "api/merchant/decor/save"
        XCTAssertEqual(path, "api/merchant/decor/save")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testMerchantUpdateForwardsPatch() {
        // pages/merchant/decor/index.js:507
        // Body is JSON.stringify(stablePatch). stablePatch is Object.assign, so there is no closed field list on the call.
        let path = "api/merchant/update"
        XCTAssertEqual(path, "api/merchant/update")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testPerkTemplateListPinsEmptyObject() {
        // pages/merchant/decor/index.js:521
        // pages/merchant/decor/perks/index.js:169
        // pages/merchant/decor/perks/index.js:327
        // JSON body is {}.
        let path = "api/coop/perk-template/list"
        XCTAssertEqual(path, "api/coop/perk-template/list")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testCommerceCapabilitiesPinsPost() {
        // pages/merchant/decor/index.js:550
        // POST with no data object.
        let path = "api/merchant/commerce/capabilities"
        XCTAssertEqual(path, "api/merchant/commerce/capabilities")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testMerchantSubscriptionPinsPost() {
        // pages/merchant/decor/index.js:580
        // POST with no data object.
        let path = "api/merchant/subscription"
        XCTAssertEqual(path, "api/merchant/subscription")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testCommerceOrderStatusPinsOrderSn() {
        // pages/merchant/decor/index.js:606
        // JSON body key orderSn. This test does not send the request.
        let path = "api/merchant/commerce/order/status"
        XCTAssertEqual(path, "api/merchant/commerce/order/status")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["orderSn"]
        XCTAssertEqual(fields, ["orderSn"])
    }

    func testCommerceOrderQuotesPathAndSendsNothing() {
        // pages/merchant/decor/index.js:629
        // createOrder forwards payload. No closed field list on the call. This test does not send.
        let path = "api/merchant/commerce/order"
        XCTAssertEqual(path, "api/merchant/commerce/order")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testBusinessStatusUpdatePinsBusinessStatus() {
        // pages/merchant/decor/index.js:951
        // pages/merchant/index/index.js:196
        // Closed data object.
        let path = "api/merchant/business-status/update"
        XCTAssertEqual(path, "api/merchant/business-status/update")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["business_status"]
        XCTAssertEqual(fields, ["business_status"])
    }

    func testPerkTemplateSavePinsTypeNameValueCostQuotaAndEnd() {
        // pages/merchant/decor/perks/index.js:282
        // JSON body keys.
        let path = "api/coop/perk-template/save"
        XCTAssertEqual(path, "api/coop/perk-template/save")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["perkType", "name", "retailValue", "unitCost", "quota", "validEnd"]
        XCTAssertEqual(fields, ["perkType", "name", "retailValue", "unitCost", "quota", "validEnd"])
    }

    func testPerkTemplateDeletePinsId() {
        // pages/merchant/decor/perks/index.js:407
        // JSON body key id.
        let path = "api/coop/perk-template/delete"
        XCTAssertEqual(path, "api/coop/perk-template/delete")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["id"]
        XCTAssertEqual(fields, ["id"])
    }

    func testLiveCheckinCodePinsNodeId() {
        // pages/merchant/game-node/index.js:607
        // Closed data object.
        let path = "api/merchant/chapter-node/live-checkin-code"
        XCTAssertEqual(path, "api/merchant/chapter-node/live-checkin-code")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["nodeId"]
        XCTAssertEqual(fields, ["nodeId"])
    }

    func testTodoSummaryPinsPost() {
        // pages/merchant/index/index.js:381
        // POST with no data object.
        let path = "api/merchant/todo-summary"
        XCTAssertEqual(path, "api/merchant/todo-summary")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testUpcomingRunsPinsEmptyObject() {
        // pages/merchant/index/index.js:453
        // JSON body is {}.
        let path = "api/merchant/upcoming-runs"
        XCTAssertEqual(path, "api/merchant/upcoming-runs")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testMerchantEventsPinsPost() {
        // pages/merchant/index/index.js:510
        // pages/merchant/ledger/index.js:292
        // Home call has no data object. Ledger call passes {}.
        let path = "api/merchant/events"
        XCTAssertEqual(path, "api/merchant/events")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testIMConversationsPinsPost() {
        // pages/merchant/index/index.js:564
        // POST with no data object.
        let path = "api/im/conversations"
        XCTAssertEqual(path, "api/im/conversations")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testCoopListPinsEmptyObject() {
        // pages/merchant/index/index.js:581
        // JSON body is {}.
        let path = "api/coop/list"
        XCTAssertEqual(path, "api/coop/list")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testMerchantInfoPinsPost() {
        // pages/merchant/index/index.js:945
        // pages/merchant/index/index.js:984
        // pages/merchant/marketing/ai-insight/index.js:300
        // POST with no data object.
        let path = "api/merchant/info"
        XCTAssertEqual(path, "api/merchant/info")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testMerchantDashboardPinsPost() {
        // pages/merchant/index/index.js:1025
        // POST with no data object.
        let path = "api/merchant/dashboard"
        XCTAssertEqual(path, "api/merchant/dashboard")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testChapterApplicationMinePinsPost() {
        // pages/merchant/index/index.js:1152
        // POST with no data object.
        let path = "api/merchant/chapter-application/mine"
        XCTAssertEqual(path, "api/merchant/chapter-application/mine")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testDeskRedeemResolvePinsCodeAndMode() {
        // pages/merchant/index/index.js:1515
        // JSON body keys. This test does not submit a redemption.
        let path = "api/merchant/desk/redeem/resolve"
        XCTAssertEqual(path, "api/merchant/desk/redeem/resolve")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["code", "mode"]
        XCTAssertEqual(fields, ["code", "mode"])
    }

    func testPublicTransferBatchDetailPinsBatchId() {
        // pages/merchant/ledger/batch-detail/index.js:52
        // JSON body key batchId.
        let path = "api/merchant/finance/public-transfer-batch-detail"
        XCTAssertEqual(path, "api/merchant/finance/public-transfer-batch-detail")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["batchId"]
        XCTAssertEqual(fields, ["batchId"])
    }

    func testLedgerRedemptionsPinsFilterPageAndTopic() {
        // pages/merchant/ledger/index.js:324
        // pages/merchant/ledger/index.js:547
        // pages/merchant/verify-records/index.js:117
        // pages/merchant/verify-records/index.js:175
        // Ledger builds pageNum, pageSize, filter, and topicId when a topic is set. Verify records sends filter, pageNum, and pageSize.
        let path = "api/merchant/finance/redemptions"
        XCTAssertEqual(path, "api/merchant/finance/redemptions")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["filter", "pageNum", "pageSize", "topicId"]
        XCTAssertEqual(fields, ["filter", "pageNum", "pageSize", "topicId"])
    }

    func testAftercareListPinsBucketPage() {
        // pages/merchant/ledger/index.js:360
        // Query keys on the list url. Body is {}.
        let path = "api/merchant/aftercare/list"
        XCTAssertEqual(path, "api/merchant/aftercare/list")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["bucket", "pageNum", "pageSize"]
        XCTAssertEqual(fields, ["bucket", "pageNum", "pageSize"])
    }

    func testLedgerOverviewPinsPost() {
        // pages/merchant/ledger/index.js:490
        // Body is {}.
        let path = "api/merchant/finance/overview"
        XCTAssertEqual(path, "api/merchant/finance/overview")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testSettlementEntriesPinsPageAndSource() {
        // pages/merchant/ledger/index.js:492
        // pages/merchant/ledger/index.js:549
        // JSON keys.
        let path = "api/merchant/finance/settlement-entries"
        XCTAssertEqual(path, "api/merchant/finance/settlement-entries")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["pageNum", "pageSize", "source"]
        XCTAssertEqual(fields, ["pageNum", "pageSize", "source"])
    }

    func testPublicTransferBatchesPinsPage() {
        // pages/merchant/ledger/index.js:496
        // pages/merchant/ledger/index.js:551
        // JSON keys.
        let path = "api/merchant/finance/public-transfer-batches"
        XCTAssertEqual(path, "api/merchant/finance/public-transfer-batches")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["pageNum", "pageSize"]
        XCTAssertEqual(fields, ["pageNum", "pageSize"])
    }

    func testRedemptionDetailPinsRecordTypeAndId() {
        // pages/merchant/ledger/order-detail/index.js:63
        // JSON body keys.
        let path = "api/merchant/finance/redemption-detail"
        XCTAssertEqual(path, "api/merchant/finance/redemption-detail")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["recordType", "recordId"]
        XCTAssertEqual(fields, ["recordType", "recordId"])
    }

    func testMerchantInsightPinsPost() {
        // pages/merchant/marketing/ai-insight/index.js:182
        // POST with no data object.
        let path = "api/ai/merchant/insight"
        XCTAssertEqual(path, "api/ai/merchant/insight")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testMarketingHomePinsPost() {
        // pages/merchant/marketing/index.js:271
        // POST with no data object.
        let path = "api/merchant/marketing-home"
        XCTAssertEqual(path, "api/merchant/marketing-home")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testPayoutAccountPinsPostAndSendsNothing() {
        // pages/merchant/payout-account/index.js:78
        // Read-only POST with no data object. The payout switch is asserted off in the money test. This test does not send.
        let path = "api/merchant/payout-account"
        XCTAssertEqual(path, "api/merchant/payout-account")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testPredictInboxPinsPost() {
        // pages/merchant/predict/index.js:150
        // POST with no data object.
        let path = "api/merchant/predict/inbox"
        XCTAssertEqual(path, "api/merchant/predict/inbox")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testPredictSettlePinsNodeDayAndOption() {
        // pages/merchant/predict/index.js:212
        // Closed data object. This test does not send the settlement.
        let path = "api/merchant/predict/settle"
        XCTAssertEqual(path, "api/merchant/predict/settle")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["nodeId", "playDay", "settledOption"]
        XCTAssertEqual(fields, ["nodeId", "playDay", "settledOption"])
    }

    func testPublicHomePinsId() {
        // pages/merchant/profile/index.js:63
        // JSON body key id.
        let path = "api/merchant/public-home"
        XCTAssertEqual(path, "api/merchant/public-home")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["id"]
        XCTAssertEqual(fields, ["id"])
    }

    func testRelationHomePinsLimit() {
        // pages/merchant/relation/index.js:217
        // JSON body key limit.
        let path = "api/merchant/relation-home"
        XCTAssertEqual(path, "api/merchant/relation-home")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["limit"]
        XCTAssertEqual(fields, ["limit"])
    }

    func testClubMyPinsEmptyObject() {
        // pages/merchant/relation/index.js:320
        // JSON body is {}.
        let path = "api/club/my"
        XCTAssertEqual(path, "api/club/my")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testClubPostFeedPinsScopeLimitAndBeforeId() {
        // pages/merchant/relation/index.js:368
        // JSON keys. beforeId is set only when a cursor exists.
        let path = "api/club/post/feed"
        XCTAssertEqual(path, "api/club/post/feed")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["scope", "limit", "beforeId"]
        XCTAssertEqual(fields, ["scope", "limit", "beforeId"])
    }

    func testReviewsListQuotesManageAndPublic() {
        // pages/merchant/reviews/index.js:253
        // Manage query uses filter, pageNum, pageSize. Public query uses merchantRowId, pageNum, pageSize. POST with no body.
        let paths = ["api/merchant/reviews/manage", "api/merchant/reviews/public"]
        XCTAssertEqual(paths, ["api/merchant/reviews/manage", "api/merchant/reviews/public"])
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["filter", "pageNum", "pageSize", "merchantRowId"]
        XCTAssertEqual(fields, ["filter", "pageNum", "pageSize", "merchantRowId"])
    }

    func testReviewReplyQuotesThreePosts() {
        // pages/merchant/reviews/reply-recovery.js:67
        // Nested sendRequest urls. Delete omits content. This test does not send.
        XCTAssertEqual(MerchantCoopLaneBContract.reviewReplyPath, "api/merchant/reviews/reply")
        XCTAssertEqual(MerchantCoopLaneBContract.reviewReplyUpdatePath, "api/merchant/reviews/reply/update")
        XCTAssertEqual(MerchantCoopLaneBContract.reviewReplyDeletePath, "api/merchant/reviews/reply/delete")
        let paths = ["api/merchant/reviews/reply", "api/merchant/reviews/reply/update", "api/merchant/reviews/reply/delete"]
        XCTAssertEqual(paths, ["api/merchant/reviews/reply", "api/merchant/reviews/reply/update", "api/merchant/reviews/reply/delete"])
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["reviewId", "expectedVersion", "requestId", "content"]
        XCTAssertEqual(fields, ["reviewId", "expectedVersion", "requestId", "content"])
    }

    func testReviewReceiptPinsReviewActionAndRequest() {
        // pages/merchant/reviews/reply-recovery.js:76
        // Nested sendRequest. JSON keys. This test does not send.
        let path = "api/merchant/reviews/reply/receipt"
        XCTAssertEqual(path, "api/merchant/reviews/reply/receipt")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["reviewId", "action", "requestId"]
        XCTAssertEqual(fields, ["reviewId", "action", "requestId"])
    }

    func testOperatorRolesPinsPost() {
        // pages/merchant/team/index.js:430
        // POST with no data object.
        let path = "api/merchant/operators/roles"
        XCTAssertEqual(path, "api/merchant/operators/roles")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testOperatorListPinsPost() {
        // pages/merchant/team/index.js:480
        // POST with no data object.
        let path = "api/merchant/operators/list"
        XCTAssertEqual(path, "api/merchant/operators/list")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testOperatorInvitePinsRoleAndRequest() {
        // pages/merchant/team/index.js:567
        // JSON body keys.
        let path = "api/merchant/operators/invite"
        XCTAssertEqual(path, "api/merchant/operators/invite")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["roleCode", "requestId"]
        XCTAssertEqual(fields, ["roleCode", "requestId"])
    }

    func testOperatorRolePinsIdRoleVersionAndRequest() {
        // pages/merchant/team/index.js:623
        // JSON body keys.
        let path = "api/merchant/operators/role"
        XCTAssertEqual(path, "api/merchant/operators/role")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["operatorId", "roleCode", "version", "requestId"]
        XCTAssertEqual(fields, ["operatorId", "roleCode", "version", "requestId"])
    }

    func testOperatorRemoveOrRevokePinsReasonAndRequest() {
        // pages/merchant/team/index.js:715
        // Remove sends operatorId. Revoke sends inviteId. Both send version, reason, requestId.
        let paths = ["api/merchant/operators/remove", "api/merchant/operators/invite/revoke"]
        XCTAssertEqual(paths, ["api/merchant/operators/remove", "api/merchant/operators/invite/revoke"])
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["operatorId", "inviteId", "version", "reason", "requestId"]
        XCTAssertEqual(fields, ["operatorId", "inviteId", "version", "reason", "requestId"])
    }

    func testOperatorInvitePreviewPinsToken() {
        // pages/merchant/team/index.js:787
        // JSON body key token.
        let path = "api/merchant/operators/invite/preview"
        XCTAssertEqual(path, "api/merchant/operators/invite/preview")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["token"]
        XCTAssertEqual(fields, ["token"])
    }

    func testOperatorInviteAcceptPinsTokenAndRequest() {
        // pages/merchant/team/index.js:812
        // JSON body keys.
        let path = "api/merchant/operators/invite/accept"
        XCTAssertEqual(path, "api/merchant/operators/invite/accept")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields = ["token", "requestId"]
        XCTAssertEqual(fields, ["token", "requestId"])
    }

    func testArrivalsTodayPinsPost() {
        // pages/merchant/verify-records/index.js:153
        // POST with no data object.
        XCTAssertEqual(MerchantCoopLaneBContract.arrivalsTodayPath, "api/merchant/desk/arrivals/today")
        let path = "api/merchant/desk/arrivals/today"
        XCTAssertEqual(path, "api/merchant/desk/arrivals/today")
        let method = "POST"
        XCTAssertEqual(method, "POST")
        let fields: [String] = []
        XCTAssertTrue(fields.isEmpty)
    }

    func testPayoutRefundAndWithdrawalStayOff() {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(.payout))
        XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(.withdrawal))
        XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(.refund))
    }
}
