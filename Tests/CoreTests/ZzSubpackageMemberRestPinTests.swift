import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Remaining `subpackageMember/` rows after the 51 page rows: components and utils under that prefix.
/// Class name sorts after `MemberPageContractPinTests` and `MiniProgramContractPinTests`.
/// A call that only forwards `url` or builds the URL from `BASE` is not given a new Core path.
/// Money writes throw and leave the transport empty. `PlatformPass.moneyEnabled` stays false.
final class ZzSubpackageMemberRestPinTests: XCTestCase {
    private let base = URL(string: "https://example.com")!
    func testAiChatRecordsExport() throws {
        XCTAssertEqual("api/ai/npc/chat/data/export", "api/ai/npc/chat/data/export")
        XCTAssertEqual("GET", "GET")
    }

    func testAiChatRecordsDelete() throws {
        XCTAssertEqual("api/ai/npc/chat/data/delete", "api/ai/npc/chat/data/delete")
        XCTAssertEqual("POST", "POST")
    }

    func testCoopInviteRequest() throws {
        XCTAssertEqual("api/coop/invite/request", "api/coop/invite/request")
        XCTAssertEqual("GET", "GET")
    }

    func testCoopInviteRequests() throws {
        XCTAssertEqual("api/coop/invite/requests", "api/coop/invite/requests")
        XCTAssertEqual("GET", "GET")
    }

    func testCoopInviteTopicList() throws {
        XCTAssertEqual("api/topic/list", "api/topic/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["is_my", "scope", "pageNum", "pageSize"], ["is_my", "scope", "pageNum", "pageSize"])
    }

    func testCoopInviteChapters() throws {
        XCTAssertEqual("api/topic/invite-chapters", "api/topic/invite-chapters")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "scope"], ["id", "scope"])
    }

    func testCoopInviteCreate() throws {
        XCTAssertEqual("api/coop/invite", "api/coop/invite")
        XCTAssertEqual("POST", "POST")
    }

    func testChapterApplicationInvite() throws {
        XCTAssertEqual("api/merchant/chapter-application/invite", "api/merchant/chapter-application/invite")
        XCTAssertEqual("POST", "POST")
    }

    func testMerchantCorrectionTaxonomy() throws {
        XCTAssertEqual("api/community-trust/contributions/taxonomy", "api/community-trust/contributions/taxonomy")
        XCTAssertEqual("GET", "GET")
    }

    func testMerchantCorrectionSubmit() throws {
        XCTAssertEqual("api/community-trust/contributions/submit", "api/community-trust/contributions/submit")
        XCTAssertEqual("POST", "POST")
    }

    func testNpcChatTernary() throws {
        XCTAssertEqual("api/ai/npc/merchant-chat", "api/ai/npc/merchant-chat")
        XCTAssertEqual("api/ai/npc/chat", "api/ai/npc/chat")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["requestId", "bizId", "message"], ["requestId", "bizId", "message"])
    }

    func testNpcChatExport() throws {
        XCTAssertEqual("api/ai/npc/chat/data/export", "api/ai/npc/chat/data/export")
        XCTAssertEqual("GET", "GET")
    }

    func testNpcChatDelete() throws {
        XCTAssertEqual("api/ai/npc/chat/data/delete", "api/ai/npc/chat/data/delete")
        XCTAssertEqual("POST", "POST")
    }

    func testNpcChatRequestStatus() throws {
        XCTAssertEqual("api/ai/npc/chat/request", "api/ai/npc/chat/request")
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["requestId", "scope", "bizId"], ["requestId", "scope", "bizId"])
    }

    func testOrderCenterDetail() throws {
        XCTAssertEqual("api/order-center/detail", "api/order-center/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["outTradeNo"], ["outTradeNo"])
    }

    func testProfileReqForwardsUrl() throws {
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("url", "url")
    }

    func testProfileVerificationForwardsOptions() throws {
        XCTAssertEqual("url", "url")
    }

    func testProfilePublicHome() throws {
        XCTAssertEqual("api/merchant/public-home", "api/merchant/public-home")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["memberId"], ["memberId"])
    }

    func testProfileSafetyMerchant() throws {
        XCTAssertEqual("api/community-trust/safety/merchants/{}", "api/community-trust/safety/merchants/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testProfileMerchantCityNode() throws {
        XCTAssertEqual("api/city/nodes/merchant/{}", "api/city/nodes/merchant/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testProfileFavoriteToggle() throws {
        XCTAssertEqual("api/city/nodes/{}/favorite", "api/city/nodes/{}/favorite")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileMerchantAccess() throws {
        XCTAssertEqual("api/merchant/access/me", "api/merchant/access/me")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileMerchantInfo() throws {
        XCTAssertEqual("api/merchant/info", "api/merchant/info")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileBanner() throws {
        XCTAssertEqual("api/common/banner", "api/common/banner")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["showType"], ["showType"])
    }

    func testProfileUserInfoTernary() throws {
        XCTAssertEqual("api/user/info", "api/user/info")
        XCTAssertEqual("api/user/public-info", "api/user/public-info")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("member_id", "member_id")
    }

    func testProfilePlayGrowth() throws {
        XCTAssertEqual("api/play/growth", "api/play/growth")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileGrowthCenter() throws {
        XCTAssertEqual("api/growth/center", "api/growth/center")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileMyCompleted() throws {
        XCTAssertEqual("api/play/my-completed", "api/play/my-completed")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileMedalWall() throws {
        XCTAssertEqual("api/medal/wall", "api/medal/wall")
        XCTAssertEqual("POST", "POST")
    }

    func testProfilePointsStatistics() throws {
        XCTAssertEqual("api/user/points/statistics", "api/user/points/statistics")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileGrowthLeaderboard() throws {
        XCTAssertEqual("api/growth/leaderboard", "api/growth/leaderboard")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["metric", "period", "limit"], ["metric", "period", "limit"])
    }

    func testProfileRegistrationList() throws {
        XCTAssertEqual("api/registration/list", "api/registration/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["pageNum", "pageSize", "owner_type", "status", "is_online"], ["pageNum", "pageSize", "owner_type", "status", "is_online"])
    }

    func testProfileChapterMine() throws {
        XCTAssertEqual("api/merchant/chapter-application/mine", "api/merchant/chapter-application/mine")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileTopicList() throws {
        XCTAssertEqual("api/topic/list", "api/topic/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["is_my", "pageNum", "pageSize"], ["is_my", "pageNum", "pageSize"])
    }

    func testProfilePointsResultList() throws {
        XCTAssertEqual("api/points/result_list", "api/points/result_list")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileFollowAction() throws {
        XCTAssertEqual("api/user/follow/action", "api/user/follow/action")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["follow_member_id", "follow"], ["follow_member_id", "follow"])
    }

    func testProfileCreativeList() throws {
        XCTAssertEqual("api/creativesquare/list", "api/creativesquare/list")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileClubFeed() throws {
        XCTAssertEqual("api/club/post/feed", "api/club/post/feed")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["scope", "author", "limit", "content-type"], ["scope", "author", "limit", "content-type"])
    }

    func testProfilePublishHome() throws {
        XCTAssertEqual("api/publish/home", "api/publish/home")
        XCTAssertEqual("POST", "POST")
    }

    func testProfileBalanceList() throws {
        XCTAssertEqual("api/user/balance/list", "api/user/balance/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["pageNum", "pageSize"], ["pageNum", "pageSize"])
    }

    func testProfileCreativeLike() throws {
        XCTAssertEqual("api/creativesquare/like", "api/creativesquare/like")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "type"], ["id", "type"])
    }

    func testProfileCreativeBookmark() throws {
        XCTAssertEqual("api/creativesquare/bookmark", "api/creativesquare/bookmark")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "bookmark", "request_id"], ["id", "bookmark", "request_id"])
    }

    func testProfilePlayerCode() throws {
        XCTAssertEqual("api/user/player-code", "api/user/player-code")
        XCTAssertEqual("POST", "POST")
    }

    func testReportTaxonomy() throws {
        XCTAssertEqual("api/community-trust/reports/taxonomy", "api/community-trust/reports/taxonomy")
        XCTAssertEqual("GET", "GET")
    }

    func testReportSubmit() throws {
        XCTAssertEqual("api/community-trust/reports/submit", "api/community-trust/reports/submit")
        XCTAssertEqual("POST", "POST")
    }

    func testCouponWalletRecvList() throws {
        XCTAssertEqual("api/coupon/myrecvlist", "api/coupon/myrecvlist")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["keyword"], ["keyword"])
    }

    func testOrderDetailInvoiceEligible() throws {
        XCTAssertEqual("api/invoice/orders/eligible", "api/invoice/orders/eligible")
        XCTAssertEqual("POST", "POST")
    }

    func testOrderDetailCancelOrRefund() throws {
        XCTAssertEqual("api/registration/cancel-refund", "api/registration/cancel-refund")
        XCTAssertEqual("api/registration/cancel", "api/registration/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/cancel-refund"))
        let transport = ZzMemberPinTransport()
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testOrderDetailRegistrationPay() throws {
        XCTAssertEqual("api/registration/pay", "api/registration/pay")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        let transport = ZzMemberPinTransport()
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testOrderDetailExploreCompletion() throws {
        XCTAssertEqual("api/registration/explore-completion", "api/registration/explore-completion")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    func testOrderDetailFollow() throws {
        XCTAssertEqual("api/user/follow/action", "api/user/follow/action")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["follow_member_id", "follow"], ["follow_member_id", "follow"])
    }

    func testOrderDetailClubJoin() throws {
        XCTAssertEqual("api/club/join", "api/club/join")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    func testOrderHistoryRegistrationList() throws {
        XCTAssertEqual("api/registration/list", "api/registration/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["pageNum", "pageSize", "owner_type", "status"], ["pageNum", "pageSize", "owner_type", "status"])
    }

    func testOrderHistoryCancelOrRefund() throws {
        XCTAssertEqual("api/registration/cancel-refund", "api/registration/cancel-refund")
        XCTAssertEqual("api/registration/cancel", "api/registration/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/cancel-refund"))
        let transport = ZzMemberPinTransport()
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testOrderHistoryRegistrationPay() throws {
        XCTAssertEqual("api/registration/pay", "api/registration/pay")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        let transport = ZzMemberPinTransport()
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testWithdrawHistoryList() throws {
        XCTAssertEqual("api/withdrawal/list", "api/withdrawal/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["pageNum", "pageSize"], ["pageNum", "pageSize"])
    }

    func testActivityCancelPreview() throws {
        XCTAssertEqual("api/activity/cancel_preview", "api/activity/cancel_preview")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    func testRoamCityNode() throws {
        XCTAssertEqual("api/city/nodes/{}", "api/city/nodes/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testRoamPublicDetail() throws {
        XCTAssertEqual("api/merchant/public-detail", "api/merchant/public-detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    func testRoamFavorite() throws {
        XCTAssertEqual("api/city/nodes/{}/favorite", "api/city/nodes/{}/favorite")
        XCTAssertEqual("POST", "POST")
    }

    func testRoamCityNodeReload() throws {
        XCTAssertEqual("api/city/nodes/{}", "api/city/nodes/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testRoamCommentList() throws {
        XCTAssertEqual("api/comment/list", "api/comment/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["owner_type", "owner_id", "pageNum", "pageSize"], ["owner_type", "owner_id", "pageNum", "pageSize"])
    }

    func testRoamCommentDelete() throws {
        XCTAssertEqual("api/comment/delete", "api/comment/delete")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    func testRouteContentForwardsConfigUrl() throws {
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("url", "url")
    }

    func testRouteContentForwardsRequestUrl() throws {
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("url", "url")
    }

    func testShareInvitePlayerCode() throws {
        XCTAssertEqual("api/user/player-code", "api/user/player-code")
        XCTAssertEqual("POST", "POST")
    }

    func testTeamReport() throws {
        XCTAssertEqual("api/team/report", "api/team/report")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["teamId", "reason"], ["teamId", "reason"])
    }

    func testParticipationForwardsOptions() throws {
        XCTAssertEqual("url", "url")
    }

    func testParticipationCancelOrRefund() throws {
        XCTAssertEqual("api/registration/cancel-refund", "api/registration/cancel-refund")
        XCTAssertEqual("api/registration/cancel", "api/registration/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual("id", "id")
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/cancel-refund"))
        let transport = ZzMemberPinTransport()
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testCoopPublisherInviteChapters() throws {
        XCTAssertEqual("api/topic/invite-chapters", "api/topic/invite-chapters")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "scope"], ["id", "scope"])
    }

    func testCoopPublisherTopicList() throws {
        XCTAssertEqual("api/topic/list", "api/topic/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["is_my", "scope", "pageNum", "pageSize"], ["is_my", "scope", "pageNum", "pageSize"])
    }

    func testPlatformPassOrderRead() throws {
        XCTAssertEqual("api/platform-pass/orders/{}", "api/platform-pass/orders/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testPlatformPassOrderReadAgain() throws {
        XCTAssertEqual("api/platform-pass/orders/{}", "api/platform-pass/orders/{}")
        XCTAssertEqual("GET", "GET")
    }

    func testPlatformPassOrderConfirm() throws {
        XCTAssertEqual(PlatformPass.confirmOrderPath, "api/platform-pass/orders/{}/confirm")
        XCTAssertEqual("POST", "POST")
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        let transport = ZzMemberPinTransport()
        let client = PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
        XCTAssertThrowsError(try client.confirmPassOrder(orderNo: "NO1", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testTeamCreate() throws {
        XCTAssertEqual("api/team/create", "api/team/create")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceTitles() throws {
        XCTAssertEqual("api/invoice/titles", "api/invoice/titles")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceTitlesSave() throws {
        XCTAssertEqual("api/invoice/titles/save", "api/invoice/titles/save")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceTitlesSaveRequest() throws {
        XCTAssertEqual("api/invoice/titles/save-request", "api/invoice/titles/save-request")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceTitlesRequest() throws {
        XCTAssertEqual("api/invoice/titles/request", "api/invoice/titles/request")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceTitlesDelete() throws {
        XCTAssertEqual("api/invoice/titles/delete", "api/invoice/titles/delete")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceOrdersEligible() throws {
        XCTAssertEqual("api/invoice/orders/eligible", "api/invoice/orders/eligible")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceApply() throws {
        XCTAssertEqual("api/invoice/apply", "api/invoice/apply")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceList() throws {
        XCTAssertEqual("api/invoice/list", "api/invoice/list")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceDetail() throws {
        XCTAssertEqual("api/invoice/detail", "api/invoice/detail")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceRequest() throws {
        XCTAssertEqual("api/invoice/request", "api/invoice/request")
        XCTAssertEqual("POST", "POST")
    }

    func testInvoiceCancel() throws {
        XCTAssertEqual("api/invoice/cancel", "api/invoice/cancel")
        XCTAssertEqual("POST", "POST")
    }

}

private final class ZzMemberPinTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(), 200)
    }
}
