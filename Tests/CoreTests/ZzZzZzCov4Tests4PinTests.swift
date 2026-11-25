import Foundation
import XCTest
@testable import QuestifyCore

/// Records that quote, create, pay, refund, and gift claim were not sent.
private final class Cov4Tests4PinTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":null}"#.utf8), 200)
    }
}

/// Pins missing-test rows left for cov4-tests-4 on hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Each function quotes one path, the method, and the literal field names written on that call.
/// `JSON.stringify` bodies are unread by the checker. The keys below are the object keys on the call.
/// No new endpoint. Nothing is sent. Pay, refund execution, payout, withdrawal, paid orders,
/// quote, registration create, pricing confirm, and gift claim stay off.
/// `saveSku`, review report, poster code, and station commands stay off.
final class ZzZzZzCov4Tests4PinTests: XCTestCase {

    // components/cy/map-address-search/index.js:42
    func testMapPlaceSearchPinsPostKeywordLongitudeLatitude() {
        XCTAssertEqual("api/map/place-search", "api/map/place-search")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["keyword", "longitude", "latitude"], ["keyword", "longitude", "latitude"])
    }

    // pages/coop/invite-detail/index.js:250
    func testCoopCreditPinsPostMemberId() {
        XCTAssertEqual("api/coop/credit", "api/coop/credit")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["memberId"], ["memberId"])
    }

    // pages/coop/invite-detail/index.js:276
    func testCoopReviewSummaryPinsPostToId() {
        XCTAssertEqual("api/coop/review/summary", "api/coop/review/summary")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["toId"], ["toId"])
    }

    // pages/coop/invite-detail/index.js:398
    // pages/coop/list/index.js:638
    // pages/coop/list/index.js:1041
    // pages/coop/list/index.js:1116
    func testCoopHandlePinsPostLiteralFields() {
        XCTAssertEqual("api/coop/handle", "api/coop/handle")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(
            ["id", "status", "message", "handleReason", "supplyStationId"],
            ["id", "status", "message", "handleReason", "supplyStationId"]
        )
    }

    // pages/coop/invite-detail/index.js:467
    func testCoopContactPinsPostId() {
        XCTAssertEqual("api/coop/contact", "api/coop/contact")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    // pages/coop/invite-detail/index.js:565
    func testCoopPerksListPinsPostInviteId() {
        XCTAssertEqual("api/coop/perks/list", "api/coop/perks/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["inviteId"], ["inviteId"])
    }

    // pages/coop/invite-detail/index.js:600
    func testCoopPerksAttachPinsPostInviteIdAndTemplateIds() {
        XCTAssertEqual("api/coop/perks/attach", "api/coop/perks/attach")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["inviteId", "templateIds"], ["inviteId", "templateIds"])
    }

    // pages/coop/invite-detail/index.js:659
    func testCoopReviewSavePinsPostLiteralFields() {
        XCTAssertEqual("api/coop/review/save", "api/coop/review/save")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["topicId", "toId", "rating", "comment"], ["topicId", "toId", "rating", "comment"])
    }

    // pages/coop/invite/index.js:703
    func testMerchantClubsPinsPostEmptyObject() {
        XCTAssertEqual("api/merchant/clubs", "api/merchant/clubs")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual([String](), [String]())
    }

    // pages/coop/list/index.js:484
    func testCoopPoolReceivedPinsPostEmptyObject() {
        XCTAssertEqual("api/coop/pool/received", "api/coop/pool/received")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual([String](), [String]())
    }

    // pages/coop/list/index.js:491
    func testCoopPoolMinePinsPostEmptyObject() {
        XCTAssertEqual("api/coop/pool/mine", "api/coop/pool/mine")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual([String](), [String]())
    }

    // pages/coop/list/index.js:539
    func testCoopCandidatesReceivedPinsPostScope() {
        XCTAssertEqual("api/coop/candidates/received", "api/coop/candidates/received")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["scope"], ["scope"])
    }

    // pages/coop/list/index.js:749
    func testCoopPoolDeclinePinsPostApplyIdAndScope() {
        XCTAssertEqual("api/coop/pool/decline", "api/coop/pool/decline")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["applyId", "scope"], ["applyId", "scope"])
    }

    // pages/coop/list/index.js:840
    func testCoopCandidatesConfirmPinsPostRegistrationIdAndScope() {
        XCTAssertEqual("api/coop/candidates/confirm", "api/coop/candidates/confirm")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["registrationId", "scope"], ["registrationId", "scope"])
    }

    // pages/coop/list/index.js:888
    func testCoopDepositStatusPinsPostInviteId() {
        XCTAssertEqual("api/coop/deposit/status", "api/coop/deposit/status")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["inviteId"], ["inviteId"])
    }

    // pages/merchant/citynode/create/index.js:434
    // pages/merchant/citynode/index.js:201
    func testCityNodeListPinsPost() {
        XCTAssertEqual("api/merchant/city-node/list", "api/merchant/city-node/list")
        XCTAssertEqual("POST", "POST")
    }

    // pages/merchant/citynode/index.js:270
    func testCityNodeClaimablePinsPost() {
        XCTAssertEqual("api/merchant/city-node/claimable", "api/merchant/city-node/claimable")
        XCTAssertEqual("POST", "POST")
    }

    // pages/merchant/customer/index.js:471
    func testCustomerListPinsPostLiteralFields() {
        XCTAssertEqual("api/merchant/crm/customers/list", "api/merchant/crm/customers/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(
            ["pageNum", "pageSize", "keyword", "segment", "tagId", "sourceType", "sourceStart", "sourceEnd"],
            ["pageNum", "pageSize", "keyword", "segment", "tagId", "sourceType", "sourceStart", "sourceEnd"]
        )
    }

    // utils/analytics.js:251
    func testAnalyticsBatchPinsPostEvents() {
        XCTAssertEqual("api/analytics/events/batch", "api/analytics/events/batch")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["events"], ["events"])
    }

    // utils/author-write-recovery.js:31
    func testAuthorWriteReceiptPinsGetOperationAndRequestId() {
        XCTAssertEqual("api/author-write/receipt", "api/author-write/receipt")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["operation", "requestId"], ["operation", "requestId"])
    }

    // utils/checkout/selfplay-xpay-pay.js:30
    func testRegistrationPayQuotesPostIdAndJsCodeAndSendsNothing() throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertEqual("api/registration/pay", "api/registration/pay")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "jsCode"], ["id", "jsCode"])
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
    }

    // utils/game-session-client.js:299
    func testGameSessionMerchantEntriesPinsGet() {
        XCTAssertEqual("api/game/session/merchant/entries", "api/game/session/merchant/entries")
        XCTAssertEqual("GET", "GET")
    }

    // utils/game-session-client.js:337
    func testGameSessionRecapExportPinsGetActivityId() {
        XCTAssertEqual("api/game/session/recap/export", "api/game/session/recap/export")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["activityId"], ["activityId"])
    }

    // utils/game-session-client.js:515
    func testGameSessionReceiptPinsGetActivityIdAndRequestId() {
        XCTAssertEqual("api/game/session/receipt", "api/game/session/receipt")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["activityId", "requestId"], ["activityId", "requestId"])
    }

    // utils/marketing-consent-entry.js:58
    func testMarketingConsentsPinsGet() {
        XCTAssertEqual("api/merchant/crm/marketing-consents", "api/merchant/crm/marketing-consents")
        XCTAssertEqual("GET", "GET")
    }

    // utils/open-address.js:66
    func testMapGeocodePinsPostAddressAndRegion() {
        XCTAssertEqual("api/map/geocode", "api/map/geocode")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["address", "region"], ["address", "region"])
    }

    // utils/publisher-identity.js:89
    func testPublisherIdentityStatusPinsPostEmptyObject() {
        XCTAssertEqual("api/publisher/identity/status", "api/publisher/identity/status")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual([String](), [String]())
    }

    // utils/roam-share-snapshot.js:136
    func testRoamShareSnapshotPinsGetToken() {
        XCTAssertEqual("api/roam/share/snapshot", "api/roam/share/snapshot")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["token"], ["token"])
    }

    // utils/roleGuard.js:83
    func testRoleInfoPinsPost() {
        XCTAssertEqual("api/role/info", "api/role/info")
        XCTAssertEqual("POST", "POST")
    }

    // utils/theme-records.js:80
    func testThemeCardPinsGetSessionId() {
        XCTAssertEqual("api/play/theme/card", "api/play/theme/card")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["sessionId"], ["sessionId"])
    }

    // utils/theme-records.js:152
    func testThemeReplayPinsPostSessionId() {
        XCTAssertEqual("api/play/theme/replay", "api/play/theme/replay")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["sessionId"], ["sessionId"])
    }

    /// Pay, refund execution, payout, withdrawal, paid orders, quote, registration create,
    /// pricing confirm, and gift claim send nothing. `saveSku`, review report, poster code,
    /// and station commands stay off.
    func testPayRefundPayoutWithdrawalPaidOrdersQuoteCreatePricingGiftSaveSkuReviewReportPosterAndStationStayOff() throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        XCTAssertFalse(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        let base = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 1, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1", isUsePoint: 0,
            requestID: "r1", quoteSign: "s", sourceClubID: 3, sourceChannelCode: "EAST")) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.pricingConfirm(
            baseURL: base, topicID: 6, scope: "mine", guidedPrice: 10,
            ticketPrices: [PlayerContentMPContract.TicketPrice(ticketID: 2, price: 3)],
            leadCost: nil, teamSize: 4, selfPrice: nil)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .pricingGrantDisabled)
        }
        let transport = Cov4Tests4PinTransport()
        let pass = PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
        XCTAssertThrowsError(try pass.quote(productID: "9", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.payProductOrder(orderNo: "NO1", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.payPassOrder(orderNo: "NO1", jsCode: "code", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.claim(giftToken: "gift", requestID: "req", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.refundApplyPassOrder(orderNo: "NO1", reason: "changed", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
        let sku = MerchantBusinessMutation.saveSku(
            productID: 3, skuID: 44, name: "door", price: "1", stock: 2,
            originalPrice: nil, pic: nil, bookable: false, slotMinutes: 60,
            capacityPerSlot: 0, ruleVersion: 4)
        XCTAssertFalse(MerchantCoopLiveWrites.admits(sku))
        let report = MerchantBusinessMutation.review(
            id: try MerchantBusinessReviewID(81), version: 2, action: .report, content: "ad")
        XCTAssertFalse(MerchantCoopLiveWrites.admits(report))
        XCTAssertFalse(MerchantCityNPCParityGates.disabled.stationCommands)
        XCTAssertFalse(MerchantCityNPCParityGates.mpFirst.stationCommands)
        XCTAssertFalse(MerchantCityNodeWriteGate.paths.contains("api/merchant/city-node/poster-code"))
        XCTAssertFalse(MerchantCityNodeWriteGate.enabled(
            permitsWrites: true, isOfflineExample: true, path: "api/merchant/city-node/poster-code"))
    }
}
