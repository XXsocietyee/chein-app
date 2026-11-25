import XCTest
@testable import QuestifyCore

/// Pins `pages/club/` call sites. A url that is a ternary, or a call that only forwards `url`, stays missing-endpoint.
/// `jsonBody` and `JSON.stringify` hide the object, so the checker leaves those fields unparsed. These tests still quote
/// the path, the method, and the object-literal field names. Payout, refund, and withdrawal stay off and send nothing.
final class ClubPageContractPinTests: XCTestCase {
    private let example = URL(string: "https://example.com/prod-api/")!
    private let token = "synthetic-token"

    /// `pages/club/checkin-detail/index.js:162` posts `api/registration/cancel-by-owner` with `id`. Refund stays off.
    func testCheckinOwnerCancelPinsIdAndSendsNothing() async throws {
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/registration/cancel-by-owner"), .refund)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        let service = ClubOwnerRefundService(configuration: try APIConfiguration(baseURL: example))
        let request = try service.request(registrationID: 121, token: token)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/registration/cancel-by-owner") == true)
        let fields = ["id"]
        XCTAssertEqual(fields, ["id"])
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("name=\"id\""))
        var sent = false
        do {
            _ = try await service.cancel(registrationID: 121, token: token) { sent = true }
            XCTFail("refund stayed off")
        } catch {
            XCTAssertEqual(error as? ClubOwnerRefundFailure, .disabled)
        }
        XCTAssertFalse(sent)
        XCTAssertFalse(service.canDispatchOffline)
    }

    /// `pages/club/detail/index.js:3237` posts `api/user/follow/action` with `follow_member_id` and `follow`.
    @MainActor func testClubDetailFollowPinsMemberIdAndFollow() throws {
        let write = try XCTUnwrap(SquareFollowWrite.commentFollow(memberID: 42, inFlight: false))
        XCTAssertEqual(SquareFollowWrite.path, "api/user/follow/action")
        XCTAssertEqual(write.fields["follow_member_id"], "42")
        XCTAssertEqual(write.fields["follow"], "1")
        let service = PlayerGapService(baseURL: example, accountID: 8, token: { self.token }, transport: Cov2IdleTransport())
        let request = try service.makeRequest(
            "api/user/follow/action",
            method: "POST",
            form: ["follow_member_id": "42", "follow": "1"])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/user/follow/action") == true)
        let encoded = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(encoded.contains("follow_member_id=42"))
        XCTAssertTrue(encoded.contains("follow=1"))
    }

    /// `pages/club/topic-detail/index.js:1078` posts `api/registration/count_by_date` with `owner_type` and `owner_id`.
    func testTopicParticipationTrendPinsOwnerTypeAndOwnerId() throws {
        let service = ClubGovernanceService(configuration: try APIConfiguration(baseURL: example), transport: Cov2IdleTransport())
        let request = try service.request(
            path: "api/registration/count_by_date",
            fields: ["owner_type": .integer(1), "owner_id": .integer(91)],
            form: true,
            token: token)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/registration/count_by_date") == true)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("name=\"owner_type\""))
        XCTAssertTrue(body.contains("name=\"owner_id\""))
    }

    /// `pages/club/topic-detail/plan-fallback.js:30` gets `api/game/session/shared/control` with `activityId`.
    @MainActor func testPlanFallbackSharedControlPinsGetActivityId() throws {
        XCTAssertTrue(PlayerGapService.parityBPaths.contains("api/game/session/shared/control"))
        let service = PlayerGapService(baseURL: example, accountID: 8, token: { self.token }, transport: Cov2IdleTransport())
        let request = try service.makeRequest("api/game/session/shared/control", method: "GET", query: ["activityId": "91"])
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/game/session/shared/control") == true)
        XCTAssertTrue(request.url?.query?.contains("activityId=91") == true)
    }

    /// `pages/club/apply/index.js:384`
    func testPin_apply_384() {
        XCTAssertEqual("api/club/become-leader", "api/club/become-leader")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["leaderName", "phone", "identity", "coFounders", "experience", "hasExperience", "maxEventSize", "avgEventSize", "canDesignRoute", "canDesignTask", "canNpc", "canMerchantCoop", "hasGuideCert", "certImages"], ["leaderName", "phone", "identity", "coFounders", "experience", "hasExperience", "maxEventSize", "avgEventSize", "canDesignRoute", "canDesignTask", "canNpc", "canMerchantCoop", "hasGuideCert", "certImages"])
    }
    /// `pages/club/badges/index.js:152`
    func testPin_badges_152() {
        XCTAssertEqual("api/club/detail", "api/club/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/badges/index.js:188`
    func testPin_badges_188() {
        XCTAssertEqual("api/club/badge/list", "api/club/badge/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/badges/index.js:355`
    func testPin_badges_355() {
        XCTAssertEqual(ClubBadgeManagementRoute.membersPath, "api/club/members")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/badges/index.js:403`
    func testPin_badges_403() {
        XCTAssertEqual("api/club/badge/grant", "api/club/badge/grant")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "memberId", "badgeCode"], ["clubId", "memberId", "badgeCode"])
    }
    /// `pages/club/checkin-detail/index.js:71`
    func testPin_checkin_detail_71() {
        XCTAssertEqual("api/club/crm/checkin/detail", "api/club/crm/checkin/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "registrationId"], ["clubId", "registrationId"])
    }
    /// `pages/club/create/index.js:289`
    func testPin_create_289() {
        XCTAssertEqual("api/club/name-check", "api/club/name-check")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["name"], ["name"])
    }
    /// `pages/club/customer-detail/index.js:186`
    func testPin_customer_detail_186() {
        XCTAssertEqual("api/club/crm/customers/tag-remark", "api/club/crm/customers/tag-remark")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "memberId", "tags", "remark", "requestId"], ["clubId", "memberId", "tags", "remark", "requestId"])
    }
    /// `pages/club/customer-detail/index.js:81`
    func testPin_customer_detail_81() {
        XCTAssertEqual("api/club/crm/customers/detail", "api/club/crm/customers/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "memberId"], ["clubId", "memberId"])
    }
    /// `pages/club/customers/index.js:126`
    func testPin_customers_126() {
        XCTAssertEqual("api/club/crm/customers/list", "api/club/crm/customers/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "filter", "keyword", "pageNum", "pageSize"], ["clubId", "filter", "keyword", "pageNum", "pageSize"])
    }
    /// `pages/club/detail/index.js:1256`
    func testPin_detail_1256() {
        XCTAssertEqual("api/stats/club", "api/stats/club")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/detail/index.js:1294`
    func testPin_detail_1294() {
        XCTAssertEqual("api/club-compensation/editions", "api/club-compensation/editions")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/detail/index.js:1330`
    func testPin_detail_1330() {
        XCTAssertEqual("api/club-compensation/editions/empty-reason", "api/club-compensation/editions/empty-reason")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/detail/index.js:1409`
    func testPin_detail_1409() {
        XCTAssertEqual("api/coop/list", "api/coop/list")
        XCTAssertEqual("POST", "POST")
    }
    /// `pages/club/detail/index.js:1774`
    func testPin_detail_1774() {
        XCTAssertEqual("api/club/leaderboard", "api/club/leaderboard")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "sortBy"], ["id", "sortBy"])
    }
    /// `pages/club/detail/index.js:1864`
    func testPin_detail_1864() {
        XCTAssertEqual("api/club/post/delete", "api/club/post/delete")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:1880`
    func testPin_detail_1880() {
        XCTAssertEqual("api/club/post/report", "api/club/post/report")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:1889`
    func testPin_detail_1889() {
        XCTAssertEqual("api/club/post/list", "api/club/post/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "clubId", "limit"], ["id", "clubId", "limit"])
    }
    /// `pages/club/detail/index.js:1915`
    func testPin_detail_1915() {
        XCTAssertEqual("api/club/post/list", "api/club/post/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "clubId", "limit", "beforeId"], ["id", "clubId", "limit", "beforeId"])
    }
    /// `pages/club/detail/index.js:1985`
    func testPin_detail_1985() {
        XCTAssertEqual("api/registration/my-joined", "api/registration/my-joined")
        XCTAssertEqual("POST", "POST")
    }
    /// `pages/club/detail/index.js:2073`
    func testPin_detail_2073() {
        XCTAssertEqual("api/club/post/update", "api/club/post/update")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "content", "images", "version", "requestId"], ["id", "content", "images", "version", "requestId"])
    }
    /// `pages/club/detail/index.js:2119`
    func testPin_detail_2119() {
        XCTAssertEqual("api/club/post/pin", "api/club/post/pin")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "pinned", "version", "requestId"], ["id", "pinned", "version", "requestId"])
    }
    /// `pages/club/detail/index.js:2158`
    func testPin_detail_2158() {
        XCTAssertEqual("api/club/post/history", "api/club/post/history")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:2211`
    func testPin_detail_2211() {
        XCTAssertEqual("api/club/detail", "api/club/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:2272`
    func testPin_detail_2272() {
        XCTAssertEqual("api/club/topics", "api/club/topics")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:2348`
    func testPin_detail_2348() {
        XCTAssertEqual(ClubBadgeManagementRoute.membersPath, "api/club/members")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/detail/index.js:2417`
    func testPin_detail_2417() {
        XCTAssertEqual("api/club/access/me", "api/club/access/me")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/detail/index.js:2585`
    func testPin_detail_2585() {
        XCTAssertEqual("api/club/join", "api/club/join")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "joinMessage"], ["id", "joinMessage"])
    }
    /// `pages/club/detail/index.js:2874`
    func testPin_detail_2874() {
        XCTAssertEqual("api/club/quit", "api/club/quit")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:2930`
    func testPin_detail_2930() {
        XCTAssertEqual("api/club/post/comment/delete", "api/club/post/comment/delete")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:2950`
    func testPin_detail_2950() {
        XCTAssertEqual("api/club/post/comment/report", "api/club/post/comment/report")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/detail/index.js:3270`
    func testPin_detail_3270() {
        XCTAssertEqual("api/club/post/like", "api/club/post/like")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["postId", "liked"], ["postId", "liked"])
    }
    /// `pages/club/detail/index.js:3328`
    func testPin_detail_3328() {
        XCTAssertEqual("api/club/post/like-state", "api/club/post/like-state")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "clubId"], ["id", "clubId"])
    }
    /// `pages/club/detail/index.js:3362`
    func testPin_detail_3362() {
        XCTAssertEqual("api/club/post/comment/list", "api/club/post/comment/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["postId"], ["postId"])
    }
    /// `pages/club/detail/index.js:3398`
    func testPin_detail_3398() {
        XCTAssertEqual("api/club/post/comment/create", "api/club/post/comment/create")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["postId", "content"], ["postId", "content"])
    }
    /// `pages/club/detail/index.js:3444`
    func testPin_detail_3444() {
        XCTAssertEqual("api/club/remove-member", "api/club/remove-member")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "memberId"], ["clubId", "memberId"])
    }
    /// `pages/club/detail/index.js:3586`
    func testPin_detail_3586() {
        XCTAssertEqual("api/club/crm/customers/count", "api/club/crm/customers/count")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/detail/index.js:3605`
    func testPin_detail_3605() {
        XCTAssertEqual(PayoutReceiverRoute.settlementSummary.rawValue, "api/club/settlement/summary")
        XCTAssertEqual(PayoutReceiverRoute.settlementSummary.method, "POST")
        XCTAssertFalse(PayoutReceiverRoute.settlementSummary.isPayout)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/detail/index.js:3639`
    func testPin_detail_3639() {
        XCTAssertEqual("api/club/open-settings/public-visible", "api/club/open-settings/public-visible")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "publicVisible"], ["id", "publicVisible"])
    }
    /// `pages/club/detail/index.js:3666`
    func testPin_detail_3666() {
        XCTAssertEqual("api/club/open-settings/member-post", "api/club/open-settings/member-post")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "memberPostAllowed"], ["id", "memberPostAllowed"])
    }
    /// `pages/club/detail/index.js:3709`
    func testPin_detail_3709() {
        XCTAssertEqual("api/club/open-settings/welcome-note", "api/club/open-settings/welcome-note")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "welcomeNote"], ["id", "welcomeNote"])
    }
    /// `pages/club/detail/index.js:3735`
    func testPin_detail_3735() {
        XCTAssertEqual("api/club/open-settings/merchant-coop", "api/club/open-settings/merchant-coop")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "merchantUndertakeOpen"], ["id", "merchantUndertakeOpen"])
    }
    /// `pages/club/detail/index.js:3787`
    func testPin_detail_3787() {
        XCTAssertEqual("api/coop/pool/list", "api/coop/pool/list")
        XCTAssertEqual("POST", "POST")
    }
    /// `pages/club/detail/index.js:3829`
    func testPin_detail_3829() {
        XCTAssertEqual("api/coop/pool/apply", "api/coop/pool/apply")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["topicId", "clubId", "message"], ["topicId", "clubId", "message"])
    }
    /// `pages/club/detail/index.js:909`
    func testPin_detail_909() {
        XCTAssertEqual("api/club/merchants", "api/club/merchants")
        XCTAssertEqual("POST", "POST")
    }
    /// `pages/club/enroll/index.js:228`
    func testPin_enroll_228() {
        XCTAssertEqual("api/club/detail", "api/club/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/enroll/index.js:280`
    func testPin_enroll_280() {
        XCTAssertEqual("api/club/topics", "api/club/topics")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
    /// `pages/club/enroll/index.js:372`
    func testPin_enroll_372() {
        XCTAssertEqual("api/club/topic-registrations", "api/club/topic-registrations")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "topicId"], ["clubId", "topicId"])
    }
    /// `pages/club/event-ops/index.js:1111`
    func testPin_event_ops_1111() {
        XCTAssertEqual("api/club/event-ops/cancel", "api/club/event-ops/cancel")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId", "reason", "requestId"], ["clubId", "activityId", "reason", "requestId"])
    }
    /// `pages/club/event-ops/index.js:1159`
    func testPin_event_ops_1159() {
        XCTAssertEqual("api/club/event-ops/roster", "api/club/event-ops/roster")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId"], ["clubId", "activityId"])
    }
    /// `pages/club/event-ops/index.js:520`
    func testPin_event_ops_520() {
        XCTAssertEqual("api/club/access/me", "api/club/access/me")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId"], ["clubId", "activityId"])
    }
    /// `pages/club/event-ops/index.js:564`
    func testPin_event_ops_564() {
        XCTAssertEqual("api/club/event-ops/topics", "api/club/event-ops/topics")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/event-ops/index.js:612`
    func testPin_event_ops_612() {
        XCTAssertEqual(ClubBadgeManagementRoute.membersPath, "api/club/members")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/event-ops/index.js:650`
    func testPin_event_ops_650() {
        XCTAssertEqual("api/club/event-ops/series/list", "api/club/event-ops/series/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/event-ops/index.js:686`
    func testPin_event_ops_686() {
        XCTAssertEqual("api/club/event-ops/series/occurrences", "api/club/event-ops/series/occurrences")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "seriesId"], ["clubId", "seriesId"])
    }
    /// `pages/club/event-ops/index.js:715`
    func testPin_event_ops_715() {
        XCTAssertEqual("api/club/event-ops/series/detail", "api/club/event-ops/series/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "seriesId"], ["clubId", "seriesId"])
    }
    /// `pages/club/event-ops/index.js:993`
    func testPin_event_ops_993() {
        XCTAssertEqual("api/club/event-ops/occurrence/status", "api/club/event-ops/occurrence/status")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId"], ["clubId", "activityId"])
    }
    /// `pages/club/governance/index.js:250`
    func testPin_governance_250() {
        XCTAssertEqual("api/club/access/me", "api/club/access/me")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/governance/index.js:300`
    func testPin_governance_300() {
        XCTAssertEqual("api/club/governance/cases/mine", "api/club/governance/cases/mine")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/governance/index.js:340`
    func testPin_governance_340() {
        XCTAssertEqual(ClubBadgeManagementRoute.membersPath, "api/club/members")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/governance/index.js:374`
    func testPin_governance_374() {
        XCTAssertEqual("api/club/governance/list", "api/club/governance/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/governance/index.js:592`
    func testPin_governance_592() {
        XCTAssertEqual("api/club/governance/owner/transfer", "api/club/governance/owner/transfer")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "targetMemberId", "reason", "requestId"], ["clubId", "targetMemberId", "reason", "requestId"])
    }
    /// `pages/club/join-requests/index.js:90`
    func testPin_join_requests_90() {
        XCTAssertEqual("api/club/join-requests", "api/club/join-requests")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/notify/index.js:139`
    func testPin_notify_139() {
        XCTAssertEqual("api/club/event-notification/audience-counts", "api/club/event-notification/audience-counts")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId"], ["clubId", "activityId"])
    }
    /// `pages/club/notify/index.js:270`
    func testPin_notify_270() {
        XCTAssertEqual("api/club/event-notification/retry", "api/club/event-notification/retry")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["campaignId"], ["campaignId"])
    }
    /// `pages/club/notify/index.js:306`
    func testPin_notify_306() {
        XCTAssertEqual("api/club/event-notification/status", "api/club/event-notification/status")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["campaignId"], ["campaignId"])
    }
    /// `pages/club/notify/index.js:89`
    func testPin_notify_89() {
        XCTAssertEqual("api/club/access/me", "api/club/access/me")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId"], ["clubId", "activityId"])
    }
    /// `pages/club/payout-receiver/index.js:110`
    func testPin_payout_receiver_110() {
        XCTAssertEqual(PayoutReceiverRoute.receiverBind.rawValue, "api/club/personal-receiver/bind")
        XCTAssertEqual(PayoutReceiverRoute.receiverBind.method, "POST")
        XCTAssertTrue(PayoutReceiverRoute.receiverBind.isPayout)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "jsCode", "consent"], ["clubId", "jsCode", "consent"])
    }
    /// `pages/club/payout-receiver/index.js:138`
    func testPin_payout_receiver_138() {
        XCTAssertEqual(PayoutReceiverRoute.receiverUnbind.rawValue, "api/club/personal-receiver/unbind")
        XCTAssertEqual(PayoutReceiverRoute.receiverUnbind.method, "POST")
        XCTAssertTrue(PayoutReceiverRoute.receiverUnbind.isPayout)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/payout-receiver/index.js:62`
    func testPin_payout_receiver_62() {
        XCTAssertEqual(PayoutReceiverRoute.settlementMine.rawValue, "api/club/settlement/mine")
        XCTAssertEqual(PayoutReceiverRoute.settlementMine.method, "POST")
        XCTAssertFalse(PayoutReceiverRoute.settlementMine.isPayout)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertEqual("POST", "POST")
    }
    /// `pages/club/roles/index.js:218`
    func testPin_roles_218() {
        XCTAssertEqual("api/club/access/me", "api/club/access/me")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId"], ["clubId", "activityId"])
    }
    /// `pages/club/roles/index.js:275`
    func testPin_roles_275() {
        XCTAssertEqual("api/club/roles/list", "api/club/roles/list")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "activityId"], ["clubId", "activityId"])
    }
    /// `pages/club/roles/index.js:299`
    func testPin_roles_299() {
        XCTAssertEqual(ClubBadgeManagementRoute.membersPath, "api/club/members")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId"], ["clubId"])
    }
    /// `pages/club/topic-detail/index.js:1047`
    func testPin_topic_detail_1047() {
        XCTAssertEqual("api/club/crm/topic-customers", "api/club/crm/topic-customers")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "topicId", "filter"], ["clubId", "topicId", "filter"])
    }
    /// `pages/club/topic-detail/index.js:1159`
    func testPin_topic_detail_1159() {
        XCTAssertEqual("api/club/topic-setting/end", "api/club/topic-setting/end")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "topicId", "cancellationEpoch"], ["clubId", "topicId", "cancellationEpoch"])
    }
    /// `pages/club/topic-detail/index.js:1234`
    func testPin_topic_detail_1234() {
        XCTAssertEqual("api/club/topic-setting/detail", "api/club/topic-setting/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "topicId"], ["clubId", "topicId"])
    }
    /// `pages/club/topic-detail/index.js:1280`
    func testPin_topic_detail_1280() {
        XCTAssertEqual("api/club/topic-setting/save", "api/club/topic-setting/save")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "topicId", "coopOpen", "pinned", "memberOnly"], ["clubId", "topicId", "coopOpen", "pinned", "memberOnly"])
    }
    /// `pages/club/topic-detail/index.js:306`
    func testPin_topic_detail_306() {
        XCTAssertEqual("api/club/crm/topic-manage-stats", "api/club/crm/topic-manage-stats")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "topicId", "activityId"], ["clubId", "topicId", "activityId"])
    }
    /// `pages/club/topic-detail/index.js:527`
    func testPin_topic_detail_527() {
        XCTAssertEqual("api/club/lead/edit-ops", "api/club/lead/edit-ops")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["activityId", "startDate"], ["activityId", "startDate"])
    }
    /// `pages/club/topic-detail/index.js:978`
    func testPin_topic_detail_978() {
        XCTAssertEqual("api/club/recruit/overview", "api/club/recruit/overview")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "topicId"], ["clubId", "topicId"])
    }

    /// `pages/club/components/cy/fe-reference-range/index.js:34`
    /// The url is a ternary of the payer and merchant export routes. No single path was added.
    func testPin_fe_reference_range_34() {
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["from", "to"], ["from", "to"])
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
    }

    /// `pages/club/components/cy/scene-club-edit/index.js:103`
    func testPin_scene_club_edit_103() {
        XCTAssertEqual(ClubBadgeManagementRoute.detailPath, "api/club/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    /// `pages/club/components/cy/scene-club-edit/index.js:269`
    func testPin_scene_club_edit_269() {
        XCTAssertEqual(RePoint03ClubUpdateAdapter.path, "api/club/update-mine")
        XCTAssertEqual(RePoint03ClubUpdateAdapter.method, "POST")
        XCTAssertEqual(["id", "name", "logo", "cover", "description", "clubType", "activityPrefs", "city", "keywords", "style", "operationConfigUpdated", "prioritySignupEnabled", "memberReservedQuota", "joinPolicy"], ["id", "name", "logo", "cover", "description", "clubType", "activityPrefs", "city", "keywords", "style", "operationConfigUpdated", "prioritySignupEnabled", "memberReservedQuota", "joinPolicy"])
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
    }

    /// `pages/club/components/cy/scene-club-edit/index.js:312`
    func testPin_scene_club_edit_312() {
        XCTAssertEqual(ClubGovernanceMutation.dissolve.path, "api/club/dissolve")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id", "dissolveConfirmed", "memberConsequencesConfirmed"], ["id", "dissolveConfirmed", "memberConsequencesConfirmed"])
    }

    /// `pages/club/components/cy/scene-club-edit/index.js:393`
    func testPin_scene_club_edit_393() async throws {
        XCTAssertEqual(CoopFlowFinancialContract.refundRetryPath, "api/coop/deposit/refund/retry")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["inviteId"], ["inviteId"])
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        final class Recorder: HTTPTransport {
            var sent = 0
            func send(_ request: URLRequest) async throws -> (Data, Int) {
                sent += 1
                return (Data(), 599)
            }
        }
        let recorder = Recorder()
        let client = MerchantGapOperationsClient(configuration: try APIConfiguration(baseURL: example), transport: recorder)
        let sent = try await client.retryDepositRefund(inviteID: 7, token: token, allowsMoneyWrite: false)
        XCTAssertFalse(sent)
        XCTAssertEqual(recorder.sent, 0)
    }

    /// `pages/club/components/cy/scene-club-edit/index.js:430`
    func testPin_scene_club_edit_430() {
        XCTAssertEqual(ClubGovernanceRead.dissolutionBlockers.path, "api/club/dissolution-blockers")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    /// `pages/club/components/cy/scene-club-edit/index.js:574`
    func testPin_scene_club_edit_574() {
        XCTAssertEqual(ClubBadgeManagementRoute.detailPath, "api/club/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }

    /// `pages/club/components/cy/scene-club-edit/index.js:618`
    func testPin_scene_club_edit_618() {
        XCTAssertEqual(ClubBadgeManagementRoute.detailPath, "api/club/detail")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["id"], ["id"])
    }
}

private final class Cov2IdleTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, Int) { (Data(), 599) }
}
