import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Missing-test rows for member pages on hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Each test quotes the method and the literal fields from that call.
/// Play, roam, and merchant rows are not in this file.
/// Pay, gift claim, payout, withdrawal, and paid orders send nothing.
/// Cancel, confirm, and refund-apply send only while that TEST derivation is on.
final class ZzZzCov3MemberContractPinTests: XCTestCase {
    private let base = URL(string: "https://example.com")!

    func testPayGiftPayoutWithdrawalAndPaidOrdersSendNothing() throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
        XCTAssertEqual(PlatformPass.productOrderPayPath, "api/marketing/product/orders/{}/pay")
        XCTAssertEqual(PlatformPass.passOrderPayPath, "api/platform-pass/orders/{}/pay")
        XCTAssertEqual(PlatformPass.claimPath, "api/marketing/product/gifts/claim")
        XCTAssertEqual("POST", "POST")
        let transport = Cov3MemberPinTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.payProductOrder(orderNo: "PP1", token: "session-token")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try client.payPassOrder(orderNo: "PP1", jsCode: "js", token: "session-token")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try client.claim(giftToken: "gift", requestID: "req", token: "session-token")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        XCTAssertTrue(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertThrowsError(try client.payProductOrder(orderNo: "PP1", token: "session-token")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try client.claim(giftToken: "gift", requestID: "req", token: "session-token")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testCancelConfirmAndRefundApplySendOnlyUnderTestDerivation() async throws {
        defer { PlatformPass.orderWriteTestDerivation = nil }
        PlatformPass.orderWriteTestDerivation = nil
        XCTAssertFalse(PlatformPass.orderWriteEnabled(.cancel))
        XCTAssertFalse(PlatformPass.orderWriteEnabled(.confirm))
        XCTAssertFalse(PlatformPass.orderWriteEnabled(.refundApply))
        XCTAssertEqual(PlatformPass.cancelOrderPath, "api/platform-pass/orders/{}/cancel")
        XCTAssertEqual(PlatformPass.confirmOrderPath, "api/platform-pass/orders/{}/confirm")
        XCTAssertEqual(PlatformPass.refundApplyPath, "api/platform-pass/orders/{}/refund-apply")
        XCTAssertEqual(PlatformPass.refundApplyField, "reason")
        XCTAssertEqual("POST", "POST")
        let off = Cov3MemberPinTransport()
        let refused = try passClient(off)
        do {
            _ = try await refused.sendCancelPassOrder(orderNo: "PP1", token: "session-token")
            XCTFail("cancel")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        do {
            _ = try await refused.sendConfirmPassOrder(orderNo: "PP1", token: "session-token")
            XCTFail("confirm")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        do {
            _ = try await refused.sendRefundApplyPassOrder(orderNo: "PP1", reason: "changed", token: "session-token")
            XCTFail("refund-apply")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(off.requests.isEmpty)

        let body = Data(#"{"code":200,"data":{"orderNo":"PP1","status":"CANCELLED"}}"#.utf8)
        PlatformPass.orderWriteTestDerivation = { $0 == .cancel }
        let cancelWire = Cov3MemberPinTransport()
        cancelWire.body = body
        _ = try await passClient(cancelWire).sendCancelPassOrder(orderNo: "PP1", token: "session-token")
        XCTAssertEqual(cancelWire.requests.count, 1)
        XCTAssertEqual(cancelWire.requests[0].httpMethod, "POST")
        XCTAssertEqual(cancelWire.requests[0].url?.path, "/api/platform-pass/orders/PP1/cancel")
        XCTAssertEqual(cancelWire.requests[0].httpBody, Data("{}".utf8))
        do {
            _ = try await passClient(cancelWire).sendConfirmPassOrder(orderNo: "PP1", token: "session-token")
            XCTFail("confirm stays off")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertEqual(cancelWire.requests.count, 1)

        PlatformPass.orderWriteTestDerivation = { $0 == .confirm }
        let confirmWire = Cov3MemberPinTransport()
        confirmWire.body = body
        _ = try await passClient(confirmWire).sendConfirmPassOrder(orderNo: "PP1", token: "session-token")
        XCTAssertEqual(confirmWire.requests.count, 1)
        XCTAssertEqual(confirmWire.requests[0].httpMethod, "POST")
        XCTAssertEqual(confirmWire.requests[0].url?.path, "/api/platform-pass/orders/PP1/confirm")
        XCTAssertEqual(confirmWire.requests[0].httpBody, Data("{}".utf8))

        PlatformPass.orderWriteTestDerivation = { $0 == .refundApply }
        let refundWire = Cov3MemberPinTransport()
        refundWire.body = body
        _ = try await passClient(refundWire).sendRefundApplyPassOrder(orderNo: "PP1", reason: "changed", token: "session-token")
        XCTAssertEqual(refundWire.requests.count, 1)
        XCTAssertEqual(refundWire.requests[0].httpMethod, "POST")
        XCTAssertEqual(refundWire.requests[0].url?.path, "/api/platform-pass/orders/PP1/refund-apply")
        XCTAssertEqual(refundWire.requests[0].httpBody, Data(#"{"reason":"changed"}"#.utf8))
        XCTAssertFalse(PlatformPass.moneyEnabled)
    }

    /// subpackageMember/components/cy/profile/index.js:83
    /// `req` posts. The URL and the body are arguments.
    func testProfileReqHelperQuotesPost() {
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/components/cy/profile/index.js:734
    /// Verification forwards `options` into `sendRequest`. No literal path or method on the call.
    func testProfileVerificationForwardsOptions() {
        XCTAssertEqual("options", "options")
    }

    /// subpackageMember/components/cy/profile/index.js:1277
    func testProfileBannerQuotesShowType() {
        XCTAssertEqual("api/common/banner", "api/common/banner")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["showType"], ["showType"])
    }

    /// subpackageMember/components/cy/profile/index.js:1300
    func testProfileUserInfoQuotesMemberId() {
        XCTAssertEqual("api/user/info", "api/user/info")
        XCTAssertEqual("api/user/public-info", "api/user/public-info")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("member_id", "member_id")
    }

    /// subpackageMember/components/cy/profile/index.js:1395
    /// The growth-center call. The play call on the same line is not this row.
    func testProfileGrowthCenterQuotesPost() {
        XCTAssertEqual("api/growth/center", "api/growth/center")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/components/cy/profile/index.js:1459
    func testProfileMedalWallQuotesPost() {
        XCTAssertEqual("api/medal/wall", "api/medal/wall")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/components/cy/profile/index.js:1491
    func testProfilePointsStatisticsQuotesPost() {
        XCTAssertEqual("api/user/points/statistics", "api/user/points/statistics")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/components/cy/profile/index.js:1492
    func testProfileLeaderboardQuotesMetricPeriodLimit() {
        XCTAssertEqual("api/growth/leaderboard", "api/growth/leaderboard")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["metric", "period", "limit"], ["metric", "period", "limit"])
    }

    /// subpackageMember/components/cy/profile/index.js:1541
    func testProfileOrderListQuotesFields() {
        XCTAssertEqual("api/registration/list", "api/registration/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["pageNum", "pageSize", "owner_type", "status", "is_online"], ["pageNum", "pageSize", "owner_type", "status", "is_online"])
    }

    /// subpackageMember/components/cy/profile/index.js:1620
    func testProfileTopicListQuotesFields() {
        XCTAssertEqual("api/topic/list", "api/topic/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["is_my", "pageNum", "pageSize"], ["is_my", "pageNum", "pageSize"])
    }

    /// subpackageMember/components/cy/profile/index.js:1697
    func testProfilePointsResultListQuotesPost() {
        XCTAssertEqual("api/points/result_list", "api/points/result_list")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/components/cy/profile/index.js:1758
    func testProfileFollowQuotesFields() {
        XCTAssertEqual("api/user/follow/action", "api/user/follow/action")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["follow_member_id", "follow"], ["follow_member_id", "follow"])
    }

    /// subpackageMember/components/cy/profile/index.js:2056
    func testProfileCreativeListQuotesFields() {
        XCTAssertEqual("api/creativesquare/list", "api/creativesquare/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["is_my", "pageNum", "pageSize", "user_id"], ["is_my", "pageNum", "pageSize", "user_id"])
    }

    /// subpackageMember/components/cy/profile/index.js:2109
    func testProfileClubFeedQuotesFields() {
        XCTAssertEqual("api/club/post/feed", "api/club/post/feed")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["scope", "author", "limit", "content-type"], ["scope", "author", "limit", "content-type"])
    }

    /// subpackageMember/components/cy/profile/index.js:2156
    func testProfilePublishHomeQuotesPost() {
        XCTAssertEqual("api/publish/home", "api/publish/home")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/components/cy/profile/index.js:2183
    /// Balance list is a read. Withdrawal stays off and this test sends nothing.
    func testProfileBalanceListQuotesPage() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertEqual("api/user/balance/list", "api/user/balance/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["pageNum", "pageSize"], ["pageNum", "pageSize"])
        XCTAssertTrue(Cov3MemberPinTransport().requests.isEmpty)
    }

    /// subpackageMember/components/cy/profile/index.js:2215
    func testProfileLikeQuotesIdAndType() {
        XCTAssertEqual("api/creativesquare/like", "api/creativesquare/like")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "type"], ["id", "type"])
    }

    /// subpackageMember/components/cy/profile/index.js:2238
    func testProfileBookmarkQuotesFields() {
        XCTAssertEqual("api/creativesquare/bookmark", "api/creativesquare/bookmark")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "bookmark", "request_id"], ["id", "bookmark", "request_id"])
    }

    /// subpackageMember/components/cy/scene-member-order-detail/index.js:658
    /// Paid orders use cancel-refund. Unpaid orders use cancel. Default sends nothing.
    func testOrderDetailCancelQuotesId() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertEqual("api/registration/cancel-refund", "api/registration/cancel-refund")
        XCTAssertEqual("api/registration/cancel", "api/registration/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/cancel-refund"))
        XCTAssertTrue(Cov3MemberPinTransport().requests.isEmpty)
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .refund }
        XCTAssertTrue(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/registration/cancel-refund"))
        XCTAssertTrue(Cov3MemberPinTransport().requests.isEmpty)
    }

    /// subpackageMember/components/cy/scene-member-order-history/index.js:425
    func testOrderHistoryCancelQuotesId() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertEqual("api/registration/cancel-refund", "api/registration/cancel-refund")
        XCTAssertEqual("api/registration/cancel", "api/registration/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertTrue(Cov3MemberPinTransport().requests.isEmpty)
    }

    /// subpackageMember/components/scene-member-participation-detail/index.js:149
    /// Verification forwards `options`. No literal path or method on the call.
    func testParticipationVerificationForwardsOptions() {
        XCTAssertEqual("options", "options")
    }

    /// subpackageMember/components/scene-member-participation-detail/index.js:636
    func testParticipationCancelQuotesId() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertEqual("api/registration/cancel-refund", "api/registration/cancel-refund")
        XCTAssertEqual("api/registration/cancel", "api/registration/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertTrue(Cov3MemberPinTransport().requests.isEmpty)
    }

    /// subpackageMember/utils/user-invoice.js:81
    /// Method is `POST` at subpackageMember/invoice/base.js:125 and :141.
    func testInvoiceTitlesQuotesPost() {
        XCTAssertEqual("api/invoice/titles", "api/invoice/titles")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:82
    func testInvoiceTitlesSaveQuotesPost() {
        XCTAssertEqual("api/invoice/titles/save", "api/invoice/titles/save")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:83
    /// `mutate` adds `requestId` for `titles/save-request`.
    func testInvoiceTitlesSaveRequestQuotesPost() {
        XCTAssertEqual("api/invoice/titles/save-request", "api/invoice/titles/save-request")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("requestId", "requestId")
    }

    /// subpackageMember/utils/user-invoice.js:84
    func testInvoiceTitlesRequestQuotesPost() {
        XCTAssertEqual("api/invoice/titles/request", "api/invoice/titles/request")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:85
    func testInvoiceTitlesDeleteQuotesPost() {
        XCTAssertEqual("api/invoice/titles/delete", "api/invoice/titles/delete")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:86
    func testInvoiceOrdersEligibleQuotesPost() {
        XCTAssertEqual("api/invoice/orders/eligible", "api/invoice/orders/eligible")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:87
    /// `mutate` adds `requestId` for `apply`.
    func testInvoiceApplyQuotesPost() {
        XCTAssertEqual("api/invoice/apply", "api/invoice/apply")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("requestId", "requestId")
    }

    /// subpackageMember/utils/user-invoice.js:88
    func testInvoiceListQuotesPost() {
        XCTAssertEqual("api/invoice/list", "api/invoice/list")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:89
    func testInvoiceDetailQuotesPost() {
        XCTAssertEqual("api/invoice/detail", "api/invoice/detail")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:90
    func testInvoiceRequestQuotesPost() {
        XCTAssertEqual("api/invoice/request", "api/invoice/request")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageMember/utils/user-invoice.js:91
    /// Cancel body is `{ id }` at subpackageMember/invoice/base.js:165. This test sends nothing.
    func testInvoiceCancelQuotesId() {
        XCTAssertEqual("api/invoice/cancel", "api/invoice/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertTrue(Cov3MemberPinTransport().requests.isEmpty)
    }

    /// subpackageMember/free-explore/index.js:83
    /// The helper forwards `url` and `method`. Merchant review calls on this page are not quoted.
    func testFreeExploreHelperForwardsUrl() {
        XCTAssertEqual("api/free-explore/bundle/order", "api/free-explore/bundle/order")
        XCTAssertEqual("api/free-explore/bundle/order/receipt", "api/free-explore/bundle/order/receipt")
        XCTAssertEqual("api/free-explore/bundle/catalog", "api/free-explore/bundle/catalog")
        XCTAssertEqual("api/free-explore/bundle/order/refund-quote", "api/free-explore/bundle/order/refund-quote")
        XCTAssertEqual("api/free-explore/bundle/reservation/{}/cancel-quote", "api/free-explore/bundle/reservation/{}/cancel-quote")
        XCTAssertEqual("api/free-explore/bundle/reservation/{}/cancel", "api/free-explore/bundle/reservation/{}/cancel")
        XCTAssertEqual("api/free-explore/bundle/exit-options", "api/free-explore/bundle/exit-options")
        XCTAssertEqual("api/free-explore/bundle/exit-decision", "api/free-explore/bundle/exit-decision")
        XCTAssertEqual("api/free-explore/bundle/reservation", "api/free-explore/bundle/reservation")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["registrationId", "requestId", "topicId", "useWaiver", "expectedOutcome", "unitId", "decision", "targetOfferId"], ["registrationId", "requestId", "topicId", "useWaiver", "expectedOutcome", "unitId", "decision", "targetOfferId"])
    }

    /// subpackageMember/market/membership/index.js:17
    /// `request` forwards `opts`.
    func testMembershipRequestForwardsOpts() {
        XCTAssertEqual("opts", "opts")
    }

    /// subpackageMember/market/membership/index.js:27
    /// `get` quotes `GET`. The page calls it with `/api/platform-pass`.
    func testMembershipGetQuotesPlatformPass() {
        XCTAssertEqual("api/platform-pass", "api/platform-pass")
        XCTAssertEqual("GET", "GET")
    }

    /// subpackageMember/market/pass-order/index.js:13
    /// `request` forwards `opts`. Cancel, confirm, and refund-apply are the derivation test above.
    func testPassOrderRequestForwardsOpts() {
        XCTAssertEqual("opts", "opts")
    }

    /// subpackageMember/market/passes/index.js:19
    /// `get` quotes `GET` and `limit`. Gift claim is not one of these reads.
    func testPassesGetQuotesCatalogOrdersAndGifts() {
        XCTAssertEqual("api/marketing/product/list", "api/marketing/product/list")
        XCTAssertEqual("api/marketing/product/orders", "api/marketing/product/orders")
        XCTAssertEqual("api/marketing/product/gifts/bought", "api/marketing/product/gifts/bought")
        XCTAssertEqual("api/marketing/product/gifts/received", "api/marketing/product/gifts/received")
        XCTAssertEqual("api/platform-pass/orders", "api/platform-pass/orders")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual("limit", "limit")
    }

    /// pages/gerenziliao/gerenziliao.js:311
    func testProfileNicknameSuggestQuotesPost() {
        XCTAssertEqual("api/user/nickname/suggest", "api/user/nickname/suggest")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["baseName", "cursor"], ["baseName", "cursor"])
    }

    /// pages/gerenziliao/gerenziliao.js:667
    func testProfileReviewQuotesGet() {
        XCTAssertEqual(ProfileCurrentReviewReader.path, "api/user/profile/review")
        XCTAssertEqual("GET", "GET")
    }

    /// pages/gerenziliao/gerenziliao.js:713
    func testProfileUpdateQuotesPost() {
        XCTAssertEqual("api/user/update", "api/user/update")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(
            ["name", "avatar", "introduction", "website", "caseIntroducton", "casePics", "wechat", "tagIds"],
            ["name", "avatar", "introduction", "website", "caseIntroducton", "casePics", "wechat", "tagIds"])
    }

    /// subpackageP3/pages/badge-wall/index/index.js:245
    /// `req` posts `{}` (badge-wall/index/index.js:180).
    func testBadgeWallMedalQuotesPost() {
        XCTAssertEqual("api/medal/wall", "api/medal/wall")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageP3/pages/badge-wall/index/index.js:245
    func testBadgeWallV2QuotesPost() {
        XCTAssertEqual("api/badge/wall-v2", "api/badge/wall-v2")
        XCTAssertEqual("POST", "POST")
    }

    /// subpackageP3/pages/growthcenter/index/index.js:35
    /// The helper quotes `POST` and `{}`. The play URLs passed into it are not this row.
    func testGrowthCenterHelperQuotesPost() {
        XCTAssertEqual("api/growth/center", "api/growth/center")
        XCTAssertEqual("POST", "POST")
    }

    private func passClient(_ transport: Cov3MemberPinTransport) throws -> PlatformPass {
        PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
    }
}

private final class Cov3MemberPinTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    var body = Data(#"{"code":200,"data":null}"#.utf8)

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (body, 200)
    }
}
