import XCTest
@testable import Questify

/// WIRE-1 composition selection. The default build stays unconfigured. A matching China build selects the reviewed deployment.
@MainActor final class ReviewedChinaLaunchCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    func testChinaReviewedCompositionAcceptsTheProductionURL() throws {
        let composition = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        guard case .reviewed(let deployment) = composition.deployment else {
            return XCTFail("China reviewed composition must accept \(ReviewedMarketLaunch.chinaProductionBaseURL)")
        }
        XCTAssertEqual(deployment.regional.market, .china)
        XCTAssertEqual(deployment.regional.apiConfiguration?.baseURL.absoluteString, "https://www.chengyinhub.com/prod-api/")
        XCTAssertTrue(deployment.regional.canUseDomesticChinaPhone)
        XCTAssertEqual(deployment.regional.availableCapabilities, [.domesticChinaPhone])
        XCTAssertFalse(deployment.productionGatesEnabled)
        XCTAssertFalse(deployment.playerWritesEnabled)
        XCTAssertTrue(deployment.reads.isEmpty)
    }

    func testUnitedStatesReviewedCompositionStaysDisabled() {
        XCTAssertNil(ReviewedMarketLaunch.approvedBaseURLs[.unitedStates])
        let composition = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .unitedStates,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNil(composition.reviewed)
        guard case .incompatibleBuild = composition.deployment else {
            return XCTFail("US reviewed path must stay disabled")
        }
    }

    func testCrossMarketURLIsRejected() {
        let china = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .china,
            baseURL: "https://www.chengyinhub.com/other/",
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNil(china.reviewed)
        guard case .incompatibleBuild = china.deployment else {
            return XCTFail("a China deployment must reject a non-China URL")
        }
        let unitedStates = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .unitedStates,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNil(unitedStates.reviewed)
        XCTAssertThrowsError(try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .china,
            baseURL: "https://example.com/prod-api/",
            bundleIdentifier: bundle,
            realm: realm
        ))
        XCTAssertThrowsError(try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .unitedStates,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        ))
    }

    func testStorageScopeDiffersByMarket() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertEqual(deployment.storageScope.market, .china)
        let unitedStates = RegionalSessionStorageScope.serviceName(
            market: .unitedStates,
            endpoint: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNotEqual(deployment.storageScope.service, unitedStates)
        let offline = try RegionalConfiguration(market: .unitedStates)
        XCTAssertFalse(deployment.storageScope.matches(configuration: offline))
    }

    func testAbsentCapabilityStaysHiddenAndWritesStayOff() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertTrue(deployment.regional.isFeatureShown(.domesticChinaPhone))
        XCTAssertFalse(deployment.regional.isFeatureShown(.usernamePassword))
        XCTAssertFalse(deployment.regional.isFeatureShown(.digitalContentPayment))
        XCTAssertFalse(deployment.regional.isFeatureShown(.merchantPayout))
        XCTAssertFalse(deployment.regional.isFeatureShown(.physicalEventPayment))
        XCTAssertFalse(deployment.productionGatesEnabled)
        XCTAssertFalse(deployment.playerWritesEnabled)
        let unverified = try RegionalConfiguration(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs
        )
        XCTAssertFalse(unverified.isFeatureShown(.domesticChinaPhone))

        XCTAssertNil(RegionalLaunchConfiguration.composition.reviewed)
        guard case .unconfigured = RegionalLaunchConfiguration.composition.deployment else {
            return XCTFail("shipped composition must stay fail-closed")
        }
        for build in [
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: "", bundleIdentifier: bundle, realm: realm),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: " ", bundleIdentifier: bundle, realm: realm),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: ""),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: " "),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: "", bundleIdentifier: bundle, realm: "")
        ] {
            let composition = RegionalLaunchConfiguration.shippedComposition(build: build)
            guard case .unconfigured = composition.deployment else {
                return XCTFail("empty URL or realm must stay unconfigured")
            }
            XCTAssertNil(composition.reviewed)
        }
        let admitted = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        guard case .reviewed(let shipped) = admitted.deployment else {
            return XCTFail("a China host with a bundle and realm still selects the reviewed deployment")
        }
        XCTAssertTrue(shipped.playerWritesEnabled)
        let player = try playerContext(admitted)
        let grant = try XCTUnwrap(admitted.playerWriteGrant(player))
        XCTAssertEqual(grant.imSend.paths, ["api/im/send", "api/im/send-receipt"])
        XCTAssertTrue(grant.clubAdmission.allowsWrites)
        XCTAssertTrue(grant.clubCommunity.paths.contains("api/club/post/create"))
        XCTAssertTrue(grant.clubCommunity.paths.contains("api/club/post/repost"))
        XCTAssertFalse(grant.clubCommunity.paths.contains("api/club/roles/assign"))
        XCTAssertTrue(grant.square.paths.contains("api/v1/community/posts"))
        XCTAssertTrue(grant.square.paths.contains("api/v1/community/guidelines/ack"))
        XCTAssertEqual(grant.profile.paths, ["api/user/update", "api/common/uploadOSS"])
        XCTAssertTrue(grant.avatar.nativePicker)
        XCTAssertFalse(grant.avatar.approvedOrigins.isEmpty)
        XCTAssertEqual(grant.registration.paths, ["api/registration/create"])
        XCTAssertEqual(grant.team.paths, ["api/team/command", "api/team/command/query", "api/team/command/cancel"])
        XCTAssertTrue(grant.play.paths.contains("api/play/arrive"))
        XCTAssertTrue(grant.play.paths.contains("api/play/help"))
        XCTAssertTrue(grant.play.paths.contains("api/play/scan-entry"))
        XCTAssertTrue(grant.play.paths.contains("api/play/journey/opening/complete"))
        XCTAssertFalse(grant.roamExtras.paths.contains("api/roam/presence"))
        XCTAssertFalse(grant.roamExtras.paths.contains("api/roam/presence-visibility"))
        XCTAssertTrue(grant.roamExtras.paths.contains("api/roam/checkin"))
        XCTAssertTrue(grant.likes.paths.contains("api/topic/like"))
        XCTAssertTrue(grant.reports.paths.contains("api/v1/community/reports"))
        XCTAssertTrue(grant.reports.paths.contains("api/v1/community/appeals"))
        XCTAssertTrue(grant.reports.paths.contains("api/orient/scoring/appeal"))
        XCTAssertTrue(grant.reports.paths.contains("api/orient/scoring/dispute"))
        XCTAssertFalse(grant.reports.paths.contains { $0.hasSuffix("/sync") || $0.hasSuffix("/settle") || $0.contains("purchase") || $0.contains("payout") })
        XCTAssertTrue(grant.friends.endpoint.paths.isSuperset(of: NativeFriendApproval.writePaths))
        XCTAssertTrue(grant.channelTextSend.allowsAnyPositiveConversation)
        XCTAssertEqual(grant.channelTextSend.operation, .send)
        XCTAssertEqual(grant.channelTextReceipt.operation, .receipt)
        XCTAssertNotNil(admitted.clubCommunityWriteService(baseURL: player.baseURL, transport: PlayerWriteRecorder()))
        XCTAssertNotNil(admitted.teamCommandWriter(context: player, transport: PlayerWriteRecorder()))
        XCTAssertEqual(try XCTUnwrap(admitted.sessionDependencies(player).configuration).play, [
            .reads, .classicCompletion, .hints, .advanced, .playerCommands, .runPersistence, .journeyOpening, .actionContextBinding
        ])
        XCTAssertEqual(try XCTUnwrap(admitted.roamLiveApproval(player)).presence, false)
        XCTAssertNil(admitted.clubRoleAssignmentApproval(player))
        XCTAssertNil(admitted.clubRoleRevocationApproval(player))
        XCTAssertNil(admitted.merchantOperationsWriteApproval(player))
        let merchant = RuntimeDependencyContext(market: .china, baseURL: player.baseURL, role: "merchant", session: player.session)
        XCTAssertNil(admitted.playerWriteGrant(merchant))
        XCTAssertNil(RegionalLaunchConfiguration.composition.playerWriteGrant(player))
        let market = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle, realm: realm)
        XCTAssertNil(market.playerWriteGrant(player))
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(RegionalLaunchConfiguration.composition.reviewed?.productionGatesEnabled == true)
        XCTAssertFalse(RegionalLaunchConfiguration.composition.reviewed?.playerWritesEnabled == true)
    }

    func testShippedChinaAdmitsFreePlayerWritesAndKeepsMoneyClosed() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let base = player.baseURL
        let free = jsonRequest(base.appendingPathComponent("api/registration/create"),
            #"{"payAmount":0,"requestId":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}"#, token: player.session.token)
        _ = try await transport.send(free)
        XCTAssertEqual(recorder.paths, ["api/registration/create"])
        let paid = jsonRequest(base.appendingPathComponent("api/registration/create"),
            #"{"payAmount":1,"payChannel":"APP"}"#, token: player.session.token)
        await assertClosed { try await transport.send(paid) }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/login"), "{}", token: player.session.token)) }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/registration/pay"), #"{"payAmount":1}"#, token: player.session.token)) }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/roam/presence"), #"{"lat":1}"#, token: player.session.token)) }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/club/roles/assign"), #"{"id":1}"#, token: player.session.token)) }
        let publish = jsonRequest(base.appendingPathComponent("api/v1/community/posts/9/publish"),
            #"{"expectedVersion":1,"requestId":"publish-workflow"}"#, token: player.session.token)
        _ = try await transport.send(publish)
        XCTAssertEqual(recorder.paths.last, "api/v1/community/posts/9/publish")
        var draftParts = URLComponents(url: base.appendingPathComponent("api/v1/community/drafts"), resolvingAgainstBaseURL: false)
        draftParts?.queryItems = [URLQueryItem(name: "limit", value: "20")]
        var drafts = URLRequest(url: try XCTUnwrap(draftParts?.url))
        drafts.httpMethod = "GET"
        drafts.setValue("application/json", forHTTPHeaderField: "Accept")
        drafts.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(drafts)
        XCTAssertEqual(recorder.paths.last, "api/v1/community/drafts")
        var send = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/im/send"),
            fields: ["conversation_id": "4", "msg_type": "1", "content": "hello", "client_message_id": String(repeating: "ab", count: 16)],
            token: player.session.token)
        // Same shape as NativeChannelTextService: the channel text route requires cookie handling off.
        send.httpShouldHandleCookies = false
        _ = try await transport.send(send)
        XCTAssertEqual(recorder.paths.last, "api/im/send")
        XCTAssertFalse(recorder.paths.contains("api/login"))
        XCTAssertFalse(recorder.paths.contains("api/roam/presence"))
        XCTAssertFalse(recorder.paths.contains("api/registration/pay"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/theme/replay"))
        let grant = try XCTUnwrap(composition.playerWriteGrant(player))
        XCTAssertTrue(grant.play.paths.contains("api/play/theme/replay"))
        XCTAssertFalse(grant.play.paths.contains("api/roam/presence"))
        XCTAssertFalse(grant.play.paths.contains("api/registration/pay"))
        let replay = jsonRequest(base.appendingPathComponent("api/play/theme/replay"), #"{"sessionId":41}"#, token: player.session.token)
        _ = try await transport.send(replay)
        XCTAssertEqual(recorder.paths.last, "api/play/theme/replay")
        let priced = jsonRequest(base.appendingPathComponent("api/play/theme/replay"), #"{"sessionId":41,"amount":1}"#, token: player.session.token)
        await assertClosed { try await transport.send(priced) }
        let channeled = jsonRequest(base.appendingPathComponent("api/play/theme/replay"), #"{"sessionId":41,"payChannel":"APP"}"#, token: player.session.token)
        await assertClosed { try await transport.send(channeled) }
        var stateParts = URLComponents(url: base.appendingPathComponent("api/play/theme/state"), resolvingAgainstBaseURL: false)
        stateParts?.queryItems = [URLQueryItem(name: "sessionId", value: "41"), URLQueryItem(name: "topicId", value: "7")]
        var state = URLRequest(url: try XCTUnwrap(stateParts?.url))
        state.httpMethod = "GET"
        state.setValue("application/json", forHTTPHeaderField: "Accept")
        state.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(state)
        XCTAssertEqual(recorder.paths.last, "api/play/theme/state")
        let appeal = formRequest(base.appendingPathComponent("api/orient/scoring/appeal"),
            "entryId=30&idempotencyKey=score-key-01&reason=wrong&sessionId=9", token: player.session.token)
        _ = try await transport.send(appeal)
        XCTAssertEqual(recorder.paths.last, "api/orient/scoring/appeal")
        var receiptParts = URLComponents(url: base.appendingPathComponent("api/orient/scoring/receipt"), resolvingAgainstBaseURL: false)
        receiptParts?.queryItems = [
            URLQueryItem(name: "idempotencyKey", value: "score-key-01"),
            URLQueryItem(name: "kind", value: "APPEAL"),
            URLQueryItem(name: "sessionId", value: "9")
        ]
        var receipt = URLRequest(url: try XCTUnwrap(receiptParts?.url))
        receipt.httpMethod = "GET"
        receipt.setValue("application/json", forHTTPHeaderField: "Accept")
        receipt.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(receipt)
        XCTAssertEqual(recorder.paths.last, "api/orient/scoring/receipt")
        await assertClosed { try await transport.send(self.formRequest(base.appendingPathComponent("api/orient/scoring/session/9/sync"), "idempotencyKey=score-key-01&sessionId=9", token: player.session.token)) }
        await assertClosed { try await transport.send(self.formRequest(base.appendingPathComponent("api/orient/scoring/session/9/settle"), "idempotencyKey=score-key-01&sessionId=9", token: player.session.token)) }

        let gatesOnly = try ReviewedAppDeployment(market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: [.china: [ReviewedMarketLaunch.chinaProductionBaseURL]],
            verifiedCapabilities: [.domesticChinaPhone], bundleIdentifier: bundle, realm: "gates-only",
            productionGatesEnabled: true, playerWritesEnabled: false)
        let closed = RegionalLaunchConfiguration.makeComposition(reviewed: gatesOnly, build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: "gates-only"),
            makeTransport: { PlayerWriteRecorder() })
        XCTAssertNil(closed.playerWriteGrant(player))
        let closedTransport = closed.transport()
        closedTransport.current = transport.current
        await assertClosed { try await closedTransport.send(free) }
        await assertClosed { try await closedTransport.send(replay) }
        await assertClosed { try await closedTransport.send(state) }
    }

    /// E2E-20261112 F2: the shipped China composition grants signed-in topic/activity/route detail reads.
    func testShippedChinaGrantsSignedInContentDetailReads() async throws {
        let recorder = PlayerReadRecorder()
        let composition = shipped(recorder)
        XCTAssertEqual(composition.reviewed?.contentDetails, .activityAndTopic)
        let player = try playerContext(composition)
        let identity = CompositionHTTPTransport.SessionIdentity(epoch: player.session.epoch, accountID: player.session.accountID,
            role: player.role, token: player.session.token)
        XCTAssertEqual(composition.readAvailability(.contentDetail, identity: identity), .available)
        let guest = CompositionHTTPTransport.SessionIdentity(epoch: 1, accountID: nil, role: nil, token: nil)
        XCTAssertEqual(composition.readAvailability(.contentDetail, identity: guest), .signInRequired)
        let transport = signedIn(composition, player)
        for path in ["api/topic/info-to-user", "api/activity/info"] {
            let request = try AuthRequestBuilder.makeFormRequest(url: player.baseURL.appendingPathComponent(path),
                fields: ["id": "990013"], token: player.session.token)
            _ = try await transport.send(request)
            XCTAssertEqual(recorder.paths.last, path)
        }
        let market = RegionalLaunchConfiguration.reviewedMarketComposition(market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm)
        XCTAssertNil(market.reviewed?.contentDetails)
    }

    /// E2E-20261112 F4/F5: every live player read and write the owner approved is admitted for a signed-in player in the
    /// shipped China composition; money routes stay refused.
    func testShippedChinaAdmitsLivePlayerReadsAndKeepsMoneyClosed() async throws {
        let recorder = PlayerReadRecorder()
        let composition = shipped(recorder)
        let player = try playerContext(composition)
        let transport = signedIn(composition, player)
        let base = player.baseURL, token = player.session.token
        let api = try APIConfiguration(baseURL: base)
        // Real service request builders, so a drift in their wire shape fails here.
        _ = try await ClubService(configuration: api, transport: transport).homeBody(token: token)
        XCTAssertEqual(recorder.paths.last, "api/club/home")
        _ = try await ClubService(configuration: api, transport: transport).detailBody(id: 7001, token: token)
        XCTAssertEqual(recorder.paths.last, "api/club/detail")
        _ = try await ClubService(configuration: api, transport: transport).directory(token: token)
        XCTAssertEqual(recorder.paths.last, "api/club/list")
        _ = try await MessagingService(configuration: api, transport: transport).conversations(token: token)
        XCTAssertEqual(recorder.paths.last, "api/im/conversations")
        _ = try await transport.send(jsonPost(base.appendingPathComponent("api/coop/list"), [:], token: token))
        XCTAssertEqual(recorder.paths.last, "api/coop/list")
        var profile = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/user/info"), fields: [:],
            token: token, includesBody: false)
        profile.setValue("multipart/form-data; boundary=ProfileRead-1", forHTTPHeaderField: "Content-Type")
        profile.httpBody = Data("--ProfileRead-1--\r\n".utf8)
        _ = try await transport.send(profile)
        XCTAssertEqual(recorder.paths.last, "api/user/info")
        // Live-route sweep: player profile, journey and launch reads, each in its service's wire shape.
        _ = try await transport.send(LaunchFeatureFlagsReader.request(baseURL: base, token: token))
        XCTAssertEqual(recorder.paths.last, "api/config/features")
        for path in ["api/medal/wall", "api/badge/wall-v2"] {
            _ = try await transport.send(jsonPost(base.appendingPathComponent(path), [:], token: token))
            XCTAssertEqual(recorder.paths.last, path)
        }
        _ = try await transport.send(AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/growth/leaderboard"),
            fields: ["metric": "XP", "period": "WEEK", "limit": "20"], token: token))
        XCTAssertEqual(recorder.paths.last, "api/growth/leaderboard")
        _ = try await transport.send(AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/registration/my-joined"),
            fields: [:], token: token, includesBody: false))
        XCTAssertEqual(recorder.paths.last, "api/registration/my-joined")
        var cards = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/object-card/list"), fields: [:],
            token: token, includesBody: false)
        cards.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        cards.httpShouldHandleCookies = false
        cards.httpBody = Data("pageNum=1&pageSize=40&category=npc".utf8)
        _ = try await transport.send(cards)
        XCTAssertEqual(recorder.paths.last, "api/object-card/list")
        var send = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/im/send"),
            fields: ["conversation_id": "1", "msg_type": "1", "content": "E2E hello", "client_message_id": String(repeating: "cd", count: 16)],
            token: token)
        // Same shape as NativeChannelTextService: the channel text route requires cookie handling off.
        send.httpShouldHandleCookies = false
        _ = try await transport.send(send)
        XCTAssertEqual(recorder.paths.last, "api/im/send")
        // An expired or revoked channel lease is re-minted for the same signed-in context, not left refusing every send.
        try XCTUnwrap(composition.playerWriteGrant(player)).channelTextSend.revoke()
        _ = try await transport.send(send)
        XCTAssertEqual(recorder.paths.last, "api/im/send")
        XCTAssertFalse(try XCTUnwrap(composition.playerWriteGrant(player)).channelTextSend.isRevoked)

        let before = recorder.paths.count
        for path in ["api/registration/pay", "api/withdrawal/create", "api/wallet/withdraw", "api/pay/create",
                     "api/club/settlement/withdraw", "api/coop/accept"] {
            await assertClosed { try await transport.send(self.jsonPost(base.appendingPathComponent(path), ["id": 1], token: token)) }
        }
        // A read path with a money field or a nested body is not a read; a guest or a foreign token is not this player.
        await assertClosed { try await transport.send(self.jsonPost(base.appendingPathComponent("api/coop/list"), ["payAmount": 1], token: token)) }
        await assertClosed { try await transport.send(AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/growth/leaderboard"),
            fields: ["payChannel": "APP"], token: token)) }
        await assertClosed { try await transport.send(self.jsonPost(base.appendingPathComponent("api/club/home"), ["filter": ["a": 1]], token: token)) }
        await assertClosed { try await transport.send(self.jsonPost(base.appendingPathComponent("api/club/home"), [:], token: "other-token")) }
        XCTAssertEqual(recorder.paths.count, before)
        let guest = composition.transport()
        guest.current = { .init(epoch: 1, accountID: nil, role: nil, token: nil) }
        await assertClosed { try await guest.send(self.jsonPost(base.appendingPathComponent("api/coop/list"), [:], token: token)) }
    }

    private func shipped(_ recorder: PlayerReadRecorder) -> AppCompositionRoot {
        RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
    }

    private func signedIn(_ composition: AppCompositionRoot, _ player: RuntimeDependencyContext) -> CompositionHTTPTransport {
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        return transport
    }

    private func jsonPost(_ url: URL, _ json: [String: Any], token: String) throws -> URLRequest {
        var request = try AuthRequestBuilder.makeFormRequest(url: url, fields: [:], token: token, includesBody: false)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        return request
    }

    func testShippedChinaAdmitsHintLadderUseAndSkipAndKeepsMoneyClosed() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let base = player.baseURL
        let grant = try XCTUnwrap(composition.playerWriteGrant(player))
        for help in ["api/play/help/use", "api/play/help/skip"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + help))
            XCTAssertTrue(grant.play.paths.contains(help))
            let request = jsonRequest(base.appendingPathComponent(help),
                #"{"runId":9,"nodeId":3,"requestId":"help-request-01"}"#, token: player.session.token)
            _ = try await transport.send(request)
            XCTAssertEqual(recorder.paths.last, help)
        }
        for money in ["/api/registration/pay", "/api/pay/create", "/api/withdrawal/create", "/api/wallet/withdraw", "/api/asset/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/wallet/withdraw"), #"{"amount":1}"#, token: player.session.token)) }
    }

    /// H1: template copy, place to-dos and image credits are admitted for a signed-in China player; money stays closed.
    func testShippedChinaAdmitsTemplateAdoptionAndKeepsMoneyClosed() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let grant = try XCTUnwrap(composition.playerWriteGrant(player))
        for path in ["api/template/topic-template/use", "api/template/topic-template/binding-status",
                     "api/template/topic-template/binding", "api/media/asset/attribution"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(grant.templateAdoption.paths.contains(path), path)
        }
        let token = player.session.token
        let service = TopicTemplateAdoptionService(configuration: try APIConfiguration(baseURL: player.baseURL),
            transport: transport, token: { token })
        _ = await service.use(TopicTemplateUseRequest(id: 41, scope: "SAME_CITY"))
        XCTAssertEqual(recorder.paths.last, "api/template/topic-template/use")
        _ = try? await service.status(topicId: 41, scope: nil)
        XCTAssertEqual(recorder.paths.last, "api/template/topic-template/binding-status")
        _ = await service.bind(topicId: 41, scope: nil, slotKey: "stop-1", nodeId: "n-1", expectedRevision: 1)
        XCTAssertEqual(recorder.paths.last, "api/template/topic-template/binding")
        _ = await service.credit(reference: "cover-1")
        XCTAssertEqual(recorder.paths.last, "api/media/asset/attribution")
        XCTAssertEqual(recorder.paths.count, 4)
        for money in ["/api/registration/pay", "/api/pay/create", "/api/wallet/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/pay/create"), #"{"amount":1}"#, token: token)) }
    }

    /// G2 + G3 (owner approval 2026-11-13): invoice, order-center and creator topic-editor routes are in
    /// the shipped China grant in both places (lease playPaths and the China route capability), the
    /// composition transport sends them, and pay, refund, and withdraw stay closed.
    func testShippedChinaAdmitsInvoiceOrderCenterAndTopicEditorAndKeepsMoneyClosed() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let base = player.baseURL
        let grant = try XCTUnwrap(composition.playerWriteGrant(player))
        let posts = ["api/invoice/list", "api/invoice/detail", "api/invoice/orders/eligible", "api/invoice/apply",
                     "api/invoice/request", "api/invoice/cancel", "api/invoice/titles", "api/invoice/titles/save",
                     "api/invoice/titles/save-request", "api/invoice/titles/request", "api/invoice/titles/delete",
                     "api/order-center/detail", "api/topic/author-edit-detail", "api/topic/author-saved-detail",
                     "api/topic/publish-draft", "api/topic/share-code", "api/topic/invite-chapters", "api/topic/host-qrcode"]
        for path in posts {
            XCTAssertTrue(grant.play.paths.contains(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            _ = try await transport.send(formRequest(base.appendingPathComponent(path), "id=9", token: player.session.token))
            XCTAssertEqual(recorder.paths.last, path)
        }
        let named = jsonRequest(base.appendingPathComponent("api/topic/state-keys/named"),
            #"{"kind":"clue","label":"Door","topicId":9}"#, token: player.session.token)
        _ = try await transport.send(named)
        XCTAssertEqual(recorder.paths.last, "api/topic/state-keys/named")
        for read in ["api/topic/play-setup", "api/topic/attribute-binding", "api/topic/state-keys"] {
            var parts = URLComponents(url: base.appendingPathComponent(read), resolvingAgainstBaseURL: false)
            parts?.queryItems = [URLQueryItem(name: "topicId", value: "9")]
            var get = URLRequest(url: try XCTUnwrap(parts?.url))
            get.httpMethod = "GET"
            get.setValue("application/json", forHTTPHeaderField: "Accept")
            get.setValue(player.session.token, forHTTPHeaderField: "Authorization")
            _ = try await transport.send(get)
            XCTAssertEqual(recorder.paths.last, read)
        }
        for (path, body) in [("api/topic/play-setup", #"{"playWindow":{"mode":"any"},"prepItems":[],"topicId":9}"#),
                             ("api/topic/state-keys/clue.door", #"{"key":{"label":"Front"},"topicId":9}"#)] {
            var put = jsonRequest(base.appendingPathComponent(path), body, token: player.session.token)
            put.httpMethod = "PUT"
            _ = try await transport.send(put)
            XCTAssertEqual(recorder.paths.last, path)
        }
        let perk = formRequest(base.appendingPathComponent("api/topic/chapter/supply-terms"),
            "chapterId=31&maxMerchant=3&termsMode=PERK", token: player.session.token)
        _ = try await transport.send(perk)
        XCTAssertEqual(recorder.paths.last, "api/topic/chapter/supply-terms")
        XCTAssertNotNil(composition.invoiceLaunchReadApproval(player))
        XCTAssertTrue(ReviewedProductionGateLeases.grantsInvoiceWrites(grant))

        let sent = recorder.paths.count
        await assertClosed { try await transport.send(self.formRequest(base.appendingPathComponent("api/topic/chapter/supply-terms"),
            "chapterId=31&maxMerchant=3&maxPerHeadFee=8&termsMode=REVSHARE", token: player.session.token)) }
        var pricedPut = jsonRequest(base.appendingPathComponent("api/topic/play-setup"), #"{"amount":1,"topicId":9}"#, token: player.session.token)
        pricedPut.httpMethod = "PUT"
        await assertClosed { try await transport.send(pricedPut) }
        var otherPut = jsonRequest(base.appendingPathComponent("api/topic/update"), #"{"topicId":9}"#, token: player.session.token)
        otherPut.httpMethod = "PUT"
        await assertClosed { try await transport.send(otherPut) }
        for money in ["api/registration/pay", "api/pay/create", "api/withdrawal/create", "api/wallet/withdraw",
                      "api/asset/withdraw", "api/registration/cancel-refund", "api/coop/deposit/refund/retry"] {
            XCTAssertFalse(grant.play.paths.contains(money), money)
            XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(
                formRequest(base.appendingPathComponent(money), "id=9", token: player.session.token),
                baseURL: base, token: player.session.token, context: player, grant: grant), money)
        }
        for money in ["api/registration/pay", "api/pay/create", "api/withdrawal/create", "api/wallet/withdraw", "api/asset/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + money), money)
            await assertClosed { try await transport.send(self.formRequest(base.appendingPathComponent(money), "id=9", token: player.session.token)) }
        }
        XCTAssertEqual(recorder.paths.count, sent)
    }

    /// H7 U08-02: report-a-problem after a run is admitted for a signed-in China player; money stays closed.
    func testShippedChinaAdmitsRunFeedbackAndKeepsMoneyClosed() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/feedback/submit"))
        XCTAssertTrue(try XCTUnwrap(composition.playerWriteGrant(player)).play.paths.contains("api/play/feedback/submit"))
        let feedback = jsonRequest(player.baseURL.appendingPathComponent("api/play/feedback/submit"),
            #"{"runId":41,"category":"STUCK","content":"stop 2 will not open","requestId":"feedback-request-01"}"#, token: player.session.token)
        _ = try await transport.send(feedback)
        XCTAssertEqual(recorder.paths.last, "api/play/feedback/submit")
        // The NPC route egg was removed by the owner (2026-09-07): no route, no capability, no entry.
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/egg/collect"))
        XCTAssertEqual(try XCTUnwrap(composition.sessionDependencies(player).configuration).journeyCollect, false)
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/pay/create"), #"{"amount":1}"#, token: player.session.token)) }
    }

    private func assertClosed(_ body: () async throws -> some Any) async {
        do { _ = try await body(); XCTFail("expected the write to stay closed") }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
    }

    private func playerContext(_ composition: AppCompositionRoot) throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    private func formRequest(_ url: URL, _ body: String, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }

    private func jsonRequest(_ url: URL, _ body: String, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }
}

private final class PlayerWriteRecorder: HTTPTransport {
    var paths: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let relative = request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? ""
        paths.append(relative)
        return (Data(#"{"code":200}"#.utf8), 200)
    }
}

private final class PlayerReadRecorder: HTTPTransport {
    var paths: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? "")
        return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
    }
}
