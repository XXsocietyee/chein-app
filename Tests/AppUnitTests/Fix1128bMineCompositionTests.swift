import XCTest
@testable import Questify

/// 1128 gaps #10 / #11 / #29: the Release composition (`RegionalLaunchConfiguration.reviewedDeployment`, shipped CN build)
/// switches on profile follow + 私信, the 提现 support contact and the 我的邀请 read.
@MainActor final class Fix1128bMineCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    private func shipped() throws -> (AppCompositionRoot, ReviewedAppDeployment) {
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        let reviewed = try XCTUnwrap(composition.reviewed)
        return (composition, reviewed)
    }

    private func player(_ composition: AppCompositionRoot, accountID: Int = 7) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: accountID, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    func testReleaseDeploymentMatchesTheReviewedDeployment() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        XCTAssertTrue(AppSession.releaseIssuesSocialMemberActions(deployment))
    }

    // MARK: gap #10

    func testReleaseIssuesExactFollowAndChatApprovals() throws {
        let (composition, reviewed) = try shipped()
        XCTAssertTrue(AppSession.releaseIssuesSocialMemberActions(reviewed))
        let context = try player(composition)
        let follow = try XCTUnwrap(SocialMemberActionReleaseIssuer.approval(context, operation: .follow, memberID: 42))
        XCTAssertEqual(follow.endpoint.paths, ["api/user/follow/action", "api/user/public-info"])
        XCTAssertEqual(follow.memberID, 42)
        XCTAssertEqual(follow.identity, SocialAccountIdentity(accountID: 7, epoch: 1, role: "player"))
        let chat = try XCTUnwrap(SocialMemberActionReleaseIssuer.approval(context, operation: .startChat, memberID: 42))
        XCTAssertEqual(chat.endpoint.paths, ["api/im/start", "api/user/public-info", "api/im/conversations"])
        // Never for oneself, an invalid member, or another market.
        XCTAssertNil(SocialMemberActionReleaseIssuer.approval(context, operation: .follow, memberID: 7))
        XCTAssertNil(SocialMemberActionReleaseIssuer.approval(context, operation: .follow, memberID: 0))
        let us = RuntimeDependencyContext(market: .unitedStates, baseURL: context.baseURL, role: "player", session: context.session)
        XCTAssertNil(SocialMemberActionReleaseIssuer.approval(us, operation: .follow, memberID: 42))
    }

    func testCompositionFirewallAdmitsTheMemberActionRequests() throws {
        let (composition, _) = try shipped()
        let context = try player(composition)
        let base = context.baseURL, token = context.session.token
        func form(_ path: String, _ fields: [String: String]) throws -> URLRequest {
            try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent(path), fields: fields, token: token)
        }
        for request in [try form("api/user/follow/action", ["follow_member_id": "42", "follow": "1"]),
                        try form("api/user/follow/action", ["follow_member_id": "42", "follow": "0"]),
                        try form("api/user/public-info", ["member_id": "42"]),
                        try form("api/im/start", ["target_member_id": "42"])] {
            XCTAssertTrue(ReviewedProductionFormMutationRoute.accepts(request, baseURL: base, token: token), request.url?.path ?? "")
        }
        for request in [try form("api/user/follow/action", ["follow_member_id": "42", "follow": "2"]),
                        try form("api/user/follow/action", ["follow_member_id": "0", "follow": "1"]),
                        try form("api/user/follow/action", ["follow_member_id": "42"]),
                        try form("api/user/public-info", ["member_id": "x"])] {
            XCTAssertFalse(ReviewedProductionFormMutationRoute.accepts(request, baseURL: base, token: token), request.url?.path ?? "")
        }
        // The exact request the coordinator sends for 关注 passes the firewall.
        let api = try XCTUnwrap(composition.reviewed?.regional.apiConfiguration)
        let profile = try JSONDecoder().decode(SocialPublicProfile.self, from: Data(#"{"id":42,"nickname":"n","isFollow":0}"#.utf8))
        var snapshot = SocialActionSnapshot(target: .member(42), profile: profile)
        snapshot.memberContext = context
        let built = try SocialActionRequestBuilder(configuration: api).make(.toggleFollow, snapshot: snapshot,
            identity: .init(accountID: 7, epoch: 1, role: "player"), token: token)
        XCTAssertTrue(ReviewedProductionFormMutationRoute.accepts(built, baseURL: base, token: token))
    }

    // MARK: gap #11

    func testBundledSupportContactReadsWithoutAnyRequest() async throws {
        XCTAssertEqual(WithdrawalSupportBundledSource.weChatID(" 18018571626 "), "18018571626")
        XCTAssertNil(WithdrawalSupportBundledSource.weChatID("$(QUESTIFY_WITHDRAW_SUPPORT_WECHAT_ID)"))
        XCTAssertNil(WithdrawalSupportBundledSource.weChatID(""))
        XCTAssertNil(WithdrawalSupportBundledSource.weChatID(nil))
        XCTAssertNil(WithdrawalSupportBundledSource.approval(reviewed: false, market: .china, weChatID: "18018571626"))
        XCTAssertNil(WithdrawalSupportBundledSource.approval(reviewed: true, market: .china, weChatID: nil))
        let approval = try XCTUnwrap(WithdrawalSupportBundledSource.approval(reviewed: true, market: .china, weChatID: "18018571626"))
        let scope = WalletCommerceScope(namespace: "cn-prod-ns", accountID: 7, epoch: UUID())
        let reader = WithdrawalSupportReader(source: {
            WithdrawalSupportBundledSource.configuration(namespace: scope.namespace, market: .china, weChatID: "18018571626", now: Date())
        }, approval: { approval }, session: { scope })
        let snapshot = try await reader.read()
        XCTAssertEqual(snapshot.contact.weChatID, "18018571626")
        let copied = try await reader.contactForCopy(snapshot)
        XCTAssertEqual(copied, "18018571626")
        // Signed out: the reader refuses instead of showing a stale contact.
        let signedOut = WithdrawalSupportReader(source: { nil }, approval: { approval }, session: { nil })
        do { _ = try await signedOut.read(); XCTFail("signed out must not read") }
        catch { XCTAssertEqual(error as? WithdrawalSupportFailure, .staleSession) }
    }

    // MARK: gap #29

    func testInviteHistoryReadIsIssuedInRelease() throws {
        let (composition, _) = try shipped()
        let context = try player(composition)
        let access = try XCTUnwrap(composition.profileInviteHistoryReadAccess(context))
        XCTAssertEqual(access.endpoints.paths, ProfileInviteHistoryReadRoute.paths)
        XCTAssertTrue(access.matches(context))
        XCTAssertTrue(composition.profileInviteHistoryReadAccess(context) === access)
        let other = try player(composition, accountID: 8)
        XCTAssertFalse(composition.profileInviteHistoryReadAccess(other) === access)
        XCTAssertNil(RegionalLaunchConfiguration.composition.profileInviteHistoryReadAccess(context))
    }
}
