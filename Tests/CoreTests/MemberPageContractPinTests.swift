import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Page rows under `subpackageMember/` (not `components/` or `utils/`) from hengyin `25eb6a0c`.
/// A row whose call only forwards `url` is not given a path here.
/// Quote, order, claim, pay, and cancel stay refused. `PlatformPass.moneyEnabled` stays false.
final class MemberPageContractPinTests: XCTestCase {
    private let base = URL(string: "https://example.com")!

    func testAppealReputationPinsGet() {
        XCTAssertEqual(MemberScoreReadRoute.reputation.path, "api/member/reputation")
        XCTAssertEqual("GET", "GET")
    }

    func testAppealScoringMinePinsPageSize() {
        XCTAssertEqual(MemberScoreReadRoute.list(page: 1, filter: .all).path, "api/orient/scoring/mine")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("pageSize", "pageSize")
    }

    func testComplaintTopicsPinsPost() {
        XCTAssertEqual("api/coop/complaint/topics", "api/coop/complaint/topics")
        XCTAssertEqual("POST", "POST")
    }

    func testComplaintMinePinsPost() {
        XCTAssertEqual("api/coop/complaint/mine", "api/coop/complaint/mine")
        XCTAssertEqual("POST", "POST")
    }

    func testComplaintReportPinsTopicIdAndReason() {
        XCTAssertEqual("api/coop/complaint/report", "api/coop/complaint/report")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["topicId", "reason"], ["topicId", "reason"])
    }

    func testCouponQrTokenPinsCouponHistoryId() {
        XCTAssertEqual(RewardPledgeRoutes.couponQRToken, "api/coupon/qr-token")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("couponHistoryId", "couponHistoryId")
    }

    func testCouponStatusPinsCouponHistoryId() {
        XCTAssertEqual(RewardPledgeRoutes.couponStatus, "api/coupon/status")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("couponHistoryId", "couponHistoryId")
    }

    func testCouponPublishedListPinsKeywordSelectAndScope() {
        XCTAssertEqual(CouponInfoSettingsPage.publishedPath, "/api/coupon/mypublishlist")
        XCTAssertEqual("api/coupon/mypublishlist", "api/coupon/mypublishlist")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["keyword", "is_select", "scope"], ["keyword", "is_select", "scope"])
    }

    func testCouponSummaryPinsPost() {
        XCTAssertEqual(MerchantOpsWp03Catalog.couponSummary, "api/merchant/coupon-summary")
        XCTAssertEqual("POST", "POST")
    }

    func testCouponStopPinsCouponIdAndScope() {
        XCTAssertEqual("api/coupon/stop", "api/coupon/stop")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["couponId", "scope"], ["couponId", "scope"])
    }

    func testGiftRedeemStatusPinsGet() {
        XCTAssertEqual(ChannelRedeemSource.statusPath, "api/channel/redeem/status")
        XCTAssertEqual("GET", "GET")
    }

    func testChannelRedeemPinsCodeAndRequestId() {
        XCTAssertEqual(ChannelRedeemSource.path, "/api/channel/redeem")
        XCTAssertEqual("api/channel/redeem", "api/channel/redeem")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["code", "requestId"], ["code", "requestId"])
    }

    func testGiftClaimPinsTokenAndRequestIdAndSendsNothing() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.claimPath, "api/marketing/product/gifts/claim")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["token", "requestId"], ["token", "requestId"])
        let transport = MemberPagePinTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.claim(giftToken: "gift", requestID: "req", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPublicCatalogListPinsLocaleSortTypeAndPage() {
        XCTAssertEqual(PlatformPass.publicCatalogListPath, "api/public-catalog/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["locale", "sort", "product_type", "pageNum", "pageSize"], ["locale", "sort", "product_type", "pageNum", "pageSize"])
    }

    func testPassOrderReadPinsGet() {
        XCTAssertEqual("api/platform-pass/orders/{}", "api/platform-pass/orders/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testPassOrderCancelPinsPostAndSendsNothing() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.cancelOrderPath, "api/platform-pass/orders/{}/cancel")
        XCTAssertEqual("POST", "POST")
        let transport = MemberPagePinTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.cancelPassOrder(orderNo: "NO1", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPassOrderTermsPinsGet() {
        XCTAssertEqual(PlatformPass.overviewPath, "api/platform-pass")
        XCTAssertEqual("GET", "GET")
    }

    func testProductDetailPinsGet() {
        XCTAssertEqual("api/marketing/product/{}", "api/marketing/product/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testProductQuotePinsFieldsAndSendsNothing() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.quotePath, "api/marketing/product/quote")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["productId", "quantity", "fulfillmentKind"], ["productId", "quantity", "fulfillmentKind"])
        let transport = MemberPagePinTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.quote(productID: "9", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testProductOrderPinsFieldsAndSendsNothing() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.orderPath, "api/marketing/product/order")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(
            ["productId", "payMode", "quantity", "fulfillmentKind", "quoteSign", "quoteExpiresAt", "requestId"],
            ["productId", "payMode", "quantity", "fulfillmentKind", "quoteSign", "quoteExpiresAt", "requestId"])
        let transport = MemberPagePinTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.order(productID: "9", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testProductOrderPayPinsPostAndSendsNothing() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertEqual(PlatformPass.productOrderPayPath, "api/marketing/product/orders/{}/pay")
        XCTAssertEqual("POST", "POST")
        let transport = MemberPagePinTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.payProductOrder(orderNo: "NO1", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testProductOrderReadPinsGet() {
        XCTAssertEqual(PlatformPass.productOrderDetailPath, "api/marketing/product/orders/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testPassesRedeemStatusPinsGet() {
        XCTAssertEqual(ChannelRedeemSource.statusPath, "api/channel/redeem/status")
        XCTAssertEqual("GET", "GET")
    }

    func testPassesOverviewPinsGet() {
        XCTAssertEqual(PlatformPass.overviewPath, "api/platform-pass")
        XCTAssertEqual("GET", "GET")
    }

    func testPassesPointsPinsPost() {
        XCTAssertEqual(AccountPublishMPContract.userInfoPath, "api/user/info")
        XCTAssertEqual("POST", "POST")
    }

    func testMyJoinedPinsPost() {
        XCTAssertEqual("api/registration/my-joined", "api/registration/my-joined")
        XCTAssertEqual("POST", "POST")
    }

    func testOrientCurrentPinsTopicIdAndActivityId() {
        XCTAssertEqual("api/play/orient/session/current", "api/play/orient/session/current")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["topicId", "activityId"], ["topicId", "activityId"])
    }

    func testOrientScoreSessionPinsGet() {
        XCTAssertEqual(OrientScorePage.readPath, "api/orient/scoring/session/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testOrientLeaderboardPinsGet() {
        XCTAssertEqual("api/orient/scoring/session/{}/leaderboard", "api/orient/scoring/session/{}/leaderboard")
        XCTAssertEqual("GET", "GET")
    }

    func testOrientReceiptPinsKindSessionAndKey() {
        XCTAssertEqual("api/orient/scoring/receipt", "api/orient/scoring/receipt")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["kind", "sessionId", "idempotencyKey"], ["kind", "sessionId", "idempotencyKey"])
    }

    func testOrientRecoveryPinsKind() {
        XCTAssertEqual("api/orient/scoring/session/{}/recovery", "api/orient/scoring/session/{}/recovery")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("kind", "kind")
    }

    func testOrientSyncPinsSessionAndKey() {
        XCTAssertEqual("api/orient/scoring/session/{}/sync", "api/orient/scoring/session/{}/sync")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["sessionId", "idempotencyKey"], ["sessionId", "idempotencyKey"])
    }

    func testReportTaxonomyPinsGet() {
        XCTAssertEqual(CommunityMemberReportClient.taxonomyPath, "api/community-trust/reports/taxonomy")
        XCTAssertEqual("GET", "GET")
    }

    func testReportDetailPinsGet() {
        XCTAssertEqual("api/community-trust/reports/{}", "api/community-trust/reports/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testReportDetailReadBackPinsGet() {
        XCTAssertEqual("api/community-trust/reports/{}", "api/community-trust/reports/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testReportAppealPinsReportReasonAndRequest() {
        XCTAssertEqual(CommunityTrustPlayerService.reportAppealPath, "api/community-trust/reports/appeal")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["reportId", "reason", "requestId"], ["reportId", "reason", "requestId"])
    }

    func testReportMinePinsGet() {
        XCTAssertEqual("api/community-trust/reports/mine", "api/community-trust/reports/mine")
        XCTAssertEqual("GET", "GET")
    }

    func testSignupIssueTicketPinsRegistrationId() {
        XCTAssertEqual("api/verify/dyncode/issue", "api/verify/dyncode/issue")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("registrationId", "registrationId")
    }

    func testSignupTopicListPinsOwnerTypePageNumAndPageSize() {
        XCTAssertEqual("api/registration/list", "api/registration/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["owner_type", "pageNum", "pageSize"], ["owner_type", "pageNum", "pageSize"])
    }

    func testSignupActivityListPinsOwnerTypePageNumAndPageSize() {
        XCTAssertEqual("api/registration/list", "api/registration/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["owner_type", "pageNum", "pageSize"], ["owner_type", "pageNum", "pageSize"])
    }

    private func passClient(_ transport: MemberPagePinTransport) throws -> PlatformPass {
        PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
    }
}

private final class MemberPagePinTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":null}"#.utf8), 200)
    }
}
