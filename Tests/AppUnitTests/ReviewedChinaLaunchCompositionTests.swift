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
        // cur-team-u0802 adds the player team create (owner-approved, non-money) to the team grant.
        XCTAssertEqual(grant.team.paths, ["api/team/create", "api/team/command", "api/team/command/query", "api/team/command/cancel"])
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
        let roleAssign = try XCTUnwrap(admitted.clubRoleAssignmentApproval(player))
        XCTAssertTrue(roleAssign.permits(player, scope: .init(clubID: 9), writing: true))
        XCTAssertFalse(roleAssign.permits(player, scope: .init(), writing: true))
        let roleRevoke = try XCTUnwrap(admitted.clubRoleRevocationApproval(player))
        XCTAssertTrue(roleRevoke.permits(player, scope: .init(clubID: 9), writing: true))
        let governance = try XCTUnwrap(admitted.sessionDependencies(player).clubGovernanceApproval)
        XCTAssertTrue(governance.liveOperations.contains(.ban))
        XCTAssertTrue(governance.liveOperations.contains(.dissolve))
        XCTAssertFalse(governance.liveOperations.contains(.reportHours))
        XCTAssertFalse(governance.liveOperations.contains(.assignRole))
        XCTAssertNotNil(admitted.clubPublicRosterApproval(player))
        XCTAssertNotNil(admitted.clubWelcomeNoteWriteApproval(player))
        XCTAssertNotNil(admitted.clubWelcomeNoteReceiptApproval(player))
        XCTAssertNil(admitted.clubPostOriginalApproval(player))
        XCTAssertNil(admitted.clubCommentOriginalApproval(player))
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

    func testShippedChinaAdmitsTheOwnersTicketEntryCodeIssueOnly() async throws {
        // E2E rerun 3 (R8): Present pass -> Show code sends `api/verify/dyncode/issue` with one `registrationId` form field.
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let issue = try OrderLifecycleRequestContract.issueTicket(registrationID: 75, baseURL: player.baseURL, token: player.session.token)
        _ = try await transport.send(issue)
        XCTAssertEqual(recorder.paths, ["api/verify/dyncode/issue"])
        let url = player.baseURL.appendingPathComponent("api/verify/dyncode/issue")
        let extra = try AuthRequestBuilder.makeFormRequest(url: url, fields: ["registrationId": "75", "memberId": "1"], token: player.session.token)
        await assertClosed { try await transport.send(extra) }
        let zero = try AuthRequestBuilder.makeFormRequest(url: url, fields: ["registrationId": "0"], token: player.session.token)
        await assertClosed { try await transport.send(zero) }
        await assertClosed { try await transport.send(self.jsonRequest(url, #"{"registrationId":75}"#, token: player.session.token)) }
        XCTAssertEqual(recorder.paths, ["api/verify/dyncode/issue"])
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
        XCTAssertEqual(composition.readAvailability(.contentDetail, identity: guest), .available)
        let guestTransport = composition.transport()
        guestTransport.current = { guest }
        let anonymous = try AuthRequestBuilder.makeFormRequest(url: player.baseURL.appendingPathComponent("api/topic/info-to-user"),
            fields: ["id": "990013"], token: nil)
        _ = try await guestTransport.send(anonymous)
        XCTAssertEqual(recorder.paths.last, "api/topic/info-to-user")
        XCTAssertNil(anonymous.value(forHTTPHeaderField: "Authorization"))
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

    /// Owner approval 2026-11-12 (all non-money player writes): a China player gets the project editor (pages/publish/*),
    /// the production-served routes go through the shipped transport, and money/merchant publishing stays refused.
    func testShippedChinaGrantsPlayerProjectEditorAndKeepsMoneyAndMerchantPublishingClosed() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        // The same wiring AppSession installs on its composition transport.
        transport.projectEditConfigurationRevision = { 1 }
        transport.projectEditConfiguration = { composition.sessionDependencies($0).businessConfiguration }
        let business = try XCTUnwrap(composition.sessionDependencies(player).businessConfiguration)
        let factory = try XCTUnwrap(BusinessRuntimeFactory(configuration: business, api: try APIConfiguration(baseURL: player.baseURL),
            transport: transport, current: { player }))
        // (1) reads and writes the production host serves are granted and sent.
        XCTAssertTrue(factory.permits(.projectRead)); XCTAssertTrue(factory.permits(.projectWrite)); XCTAssertTrue(factory.permits(.projectPublicationRead))
        let client = factory.client([.projectRead, .projectWrite, .projectPublicationRead])
        let granted = factory.routes([.projectRead, .projectWrite, .projectPublicationRead]).map(\.path)
        for path in ["api/publish/home", "api/topic/edit-detail", "api/topic/create", "api/topic/update", "api/topic/v2/create", "api/topic/v2/update"] {
            XCTAssertTrue(granted.contains(path), path)
        }
        _ = try await client.send(jsonRequest(player.baseURL.appendingPathComponent("api/publish/home"), "{}", token: player.session.token))
        XCTAssertEqual(recorder.paths.last, "api/publish/home")
        let personal = #"{"scope":"","id":41,"name":"Synthetic topic"}"#
        _ = try await client.send(jsonRequest(player.baseURL.appendingPathComponent("api/topic/update"), personal, token: player.session.token))
        XCTAssertEqual(recorder.paths.last, "api/topic/update")
        // Merchant-scoped publishing stays with merchants.
        let merchant = #"{"scope":"MERCHANT","id":41,"name":"Synthetic topic"}"#
        let sentBefore = recorder.paths.count
        do { _ = try await client.send(jsonRequest(player.baseURL.appendingPathComponent("api/topic/update"), merchant, token: player.session.token)); XCTFail("merchant scope") }
        catch {}
        XCTAssertEqual(recorder.paths.count, sentBefore)
        _ = try await client.send(TopicPublicationReadRoute.check(topicID: 41, owner: .personal).request(baseURL: player.baseURL, token: player.session.token))
        XCTAssertEqual(recorder.paths.last, TopicPublicationPath.check)
        // (2) money and merchant publishing are not project-editor routes and stay closed.
        for closed in ["api/topic/pricing/preview", "api/topic/pricing/confirm", "api/pay/create", "api/registration/pay",
                       "api/merchant/topic/publish", "api/template/updateLibraryStatus", "api/wallet/withdraw"] {
            XCTAssertFalse(granted.contains(closed), closed)
            let before = recorder.paths.count
            do { _ = try await client.send(jsonRequest(player.baseURL.appendingPathComponent(closed), #"{"id":41}"#, token: player.session.token)); XCTFail(closed) }
            catch {}
            XCTAssertEqual(recorder.paths.count, before, closed)
        }
        // (3) publish-status and the edit-request receipts are not served by production: not granted, so the UI hides them.
        XCTAssertFalse(granted.contains(TopicPublicationPath.status))
        XCTAssertFalse(granted.contains(ProjectEditRequestContract.submitPath))
        let test = ReviewedProductionGateLeases.projectEditorRoutes(baseURL: try XCTUnwrap(URL(string: "http://127.0.0.1:8120/test-api")))
        XCTAssertTrue(test[.projectPublicationRead]?.contains(where: { $0.path == TopicPublicationPath.status }) == true)
        XCTAssertTrue(test[.projectWrite]?.contains(where: { $0.path == ProjectEditRequestContract.submitPath }) == true)
    }

    /// E2E-20261113 (2)+(3): club public activities are approved and club/access/me is a player read in the shipped
    /// China composition; money stays closed.
    func testShippedChinaApprovesClubPublicActivitiesAndAccessMe() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        // (2) the public activities/topics approval is issued and stable per viewer and club.
        let context = ClubPublicTopicsContext(identity: ClubReadIdentity(accountID: player.session.accountID, epoch: player.session.epoch),
            viewerRevision: 1, role: player.role, baseURL: player.baseURL, namespace: player.session.namespace)
        let first = try XCTUnwrap(composition.clubPublicTopicsApproval(context, 7001))
        XCTAssertEqual(composition.clubPublicTopicsApproval(context, 7001), first)
        XCTAssertNil(composition.clubPublicTopicsApproval(context, 0))
        // (3) club/access/me is a reviewed player read in both lists and is sent.
        XCTAssertTrue(ReviewedPlayerReadRoute.paths.contains("api/club/access/me"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/access/me"))
        // E2E R4: the backend serves JSON only; ClubGovernanceService sends access/me as JSON.
        XCTAssertFalse(ClubGovernanceRead.access.usesForm)
        _ = try await transport.send(jsonRequest(player.baseURL.appendingPathComponent("api/club/access/me"), #"{"clubId":7001}"#, token: player.session.token))
        XCTAssertEqual(recorder.paths.last, "api/club/access/me")
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/pay/create"), #"{"amount":1}"#, token: player.session.token)) }
    }

    /// polish-d-r1: club/members is a reviewed player read (JSON {"clubId"}), sent after club/detail by the members screen;
    /// a money field still closes it.
    func testShippedChinaAdmitsClubMembersRead() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        XCTAssertTrue(ReviewedPlayerReadRoute.paths.contains("api/club/members"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/members"))
        _ = try await transport.send(jsonRequest(player.baseURL.appendingPathComponent("api/club/members"), #"{"clubId":7003}"#, token: player.session.token))
        XCTAssertEqual(recorder.paths.last, "api/club/members")
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/club/members"), #"{"amount":1,"clubId":7003}"#, token: player.session.token)) }
    }

    /// E2E-20261113 R2, R3, R5, R7, R8, R11: the shipped China composition lets a signed-in player send DMs through the real
    /// sender, enter club chat, read club posts, open channels, show their own entry code and list their projects.
    func testShippedChinaE2EPlayerBlockersAreOpenAndMoneyStaysClosed() async throws {
        let recorder = PlayerWriteRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let api = try APIConfiguration(baseURL: player.baseURL)
        let token = player.session.token
        // R2: the production DM sender itself, not a hand-built request.
        let intent = try MessageTextIntent(conversationID: 4, content: "hello", clientMessageID: String(repeating: "ab", count: 16))
        _ = try? await MessageActionService(configuration: api, transport: transport).send(intent, token: token)
        XCTAssertEqual(recorder.paths.last, "api/im/send")
        // R3: club group chat, JSON {"id"} only.
        _ = try await transport.send(jsonRequest(player.baseURL.appendingPathComponent("api/club/chat"), #"{"id":7001}"#, token: token))
        XCTAssertEqual(recorder.paths.last, "api/club/chat")
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/club/chat"), #"{"id":7001,"amount":1}"#, token: token)) }
        // R5: club post list read lease, stable per context.
        let posts = try XCTUnwrap(composition.clubCommunityReadApproval(player))
        XCTAssertTrue(composition.clubCommunityReadApproval(player) === posts)
        XCTAssertTrue(posts.endpoints.paths.contains("api/club/post/list"))
        // R7: channel management for a club the player belongs to.
        let club = try NativeChannelManagementScope(guildKind: 1, guildID: try NativeChannelManagementID("7001"))
        XCTAssertNotNil(composition.nativeChannelManagementApproval(player, 1, club))
        // R8: the owner's registration/ticket entry code, not only the city voucher.
        let codes = try XCTUnwrap(composition.verificationCodeApproval(player))
        XCTAssertTrue(codes.allows(.ticket, context: player)); XCTAssertTrue(codes.allows(.cityVoucher, context: player))
        // R11: the player's own projects; the merchant-scoped list is not a player read.
        let mine = try AuthRequestBuilder.makeFormRequest(url: player.baseURL.appendingPathComponent("api/project/my"),
            fields: ["type": "all", "state": "all", "ownerType": "all", "pageNum": "1", "pageSize": "200"], token: token)
        _ = try await transport.send(mine)
        XCTAssertEqual(recorder.paths.last, "api/project/my")
        let merchant = try AuthRequestBuilder.makeFormRequest(url: player.baseURL.appendingPathComponent("api/project/my"),
            fields: ["type": "all", "state": "all", "ownerType": "all", "scope": "MERCHANT", "pageNum": "1", "pageSize": "200"], token: token)
        await assertClosed { try await transport.send(merchant) }
        // g-partials owner item: the player TEAM backpack command is a reviewed player write.
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/game/session/command"))
        XCTAssertTrue(try XCTUnwrap(composition.playerWriteGrant(player)).play.paths.contains("api/game/session/command"))
        // Only a TEAM item command body passes (PlayTeamItemCommandBody); valid bodies are covered by the team-command test.
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/game/session/command"), #"{"activityId":41,"type":"ITEM_USE"}"#, token: token)) }
        // R12: the player's own journey reads.
        for path in ["api/registration/my-joined", "api/play/my-completed"] {
            _ = try await transport.send(try AuthRequestBuilder.makeFormRequest(url: player.baseURL.appendingPathComponent(path), fields: [:], token: token, includesBody: false))
            XCTAssertEqual(recorder.paths.last, path)
        }
        _ = try await transport.send(try AuthRequestBuilder.makeFormRequest(url: player.baseURL.appendingPathComponent("api/registration/info"), fields: ["id": "41"], token: token))
        XCTAssertEqual(recorder.paths.last, "api/registration/info")
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/pay/create"), #"{"amount":1}"#, token: token)) }
    }

    /// G4/G5: the shipped China composition admits the community-trust, roam-extra, template and map/search
    /// player routes through the play lease and the owner grant (both places), and still refuses money routes.
    func testShippedChinaAdmitsSocialRoamTemplateMapRoutesAndKeepsMoneyClosed() async throws {
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
        let token = player.session.token
        let jsonWrites: [(String, String)] = [
            ("api/community-trust/contributions/submit", #"{"contributionType":"ISSUE_REPORT","description":"x","idempotencyKey":"mct-5-abcdef","issueType":"OTHER","merchantId":5}"#),
            ("api/community-trust/safety/ratings", #"{"idempotencyKey":"safety-5-a","merchantId":5,"overallLevel":"SAFE","reason":"x"}"#),
            ("api/community-trust/reports/appeal", #"{"reason":"x","reportId":3,"requestId":"rpa-3-abcdef"}"#),
            ("api/template/adopt-draft", #"{"originalTemplateId":"17","requestId":"adopt_1_x","scope":"","sourceVersion":"a"}"#)
        ]
        for (path, body) in jsonWrites {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(grant.play.paths.contains(path), path)
            _ = try await transport.send(jsonRequest(base.appendingPathComponent(path), body, token: token))
            XCTAssertEqual(recorder.paths.last, path)
        }
        let formWrites: [(String, String)] = [
            ("api/roam/session/records", "sessionId=4&records=%5B%5D"), ("api/roam/shop/visitors", "sourceType=1&sourceIds=3"),
            ("api/template/author-info", "id=5&scope="), ("api/template/author-myinfo", "id=5&scope="),
            ("api/template/topic-template/binding", "topicId=4&scope=&slotKey=s1&nodeId=9"),
            ("api/template/topic-template/binding-status", "topicId=4&scope="), ("api/template/topic-template/save-as", "id=4&scope="),
            ("api/template/41/market-submit", "scope="), ("api/map/geocode", "address=x&region="),
            ("api/map/place-search", "keyword=xx&longitude=1&latitude=1"), ("api/search/unified", "keyword=x&types=topic&pageNum=1&pageSize=12")
        ]
        for (path, body) in formWrites {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            _ = try await transport.send(formRequest(base.appendingPathComponent(path), body, token: token))
            XCTAssertEqual(recorder.paths.last, path)
        }
        var revoke = formRequest(base.appendingPathComponent("api/roam/share/revoke"), "", token: token)
        revoke.httpBody = Data()
        _ = try await transport.send(revoke)
        XCTAssertEqual(recorder.paths.last, "api/roam/share/revoke")
        for path in ["api/community-trust/contributions/taxonomy", "api/community-trust/safety/taxonomy",
                     "api/community-trust/safety/merchants/12", "api/template/adoption-source",
                     "api/template/adoption-receipt", "api/template/adoption-detail", "api/map/weather"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            var read = URLRequest(url: base.appendingPathComponent(path))
            read.httpMethod = "GET"
            read.setValue(token, forHTTPHeaderField: "Authorization")
            _ = try await transport.send(read)
            XCTAssertEqual(recorder.paths.last, path)
        }
        for path in ["/api/v1/community/me/posts", "/api/v1/community/me/bookmarks", "/api/v1/community/posts/7/actions/LIKE",
                     "/api/v1/community/posts/7/actions/BOOKMARK", "/api/v1/community/comments/8/actions/LIKE"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        for money in ["/api/registration/pay", "/api/pay/create", "/api/withdrawal/create", "/api/wallet/withdraw", "/api/asset/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/pay/create"), #"{"amount":1}"#, token: token)) }
    }

    func testShippedChinaAdmitsPlayerGapRoutesAndKeepsMoneyAndHostClosed() async throws {
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
        for path in PlayerGapService.paths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(grant.play.paths.contains(path), path)
        }
        let service = PlayerGapService(baseURL: player.baseURL, accountID: player.session.accountID,
                                       token: { player.session.token }, transport: transport)
        func sent(_ path: String, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(recorder.paths.last, path, file: file, line: line)
        }
        _ = await service.activeOfficialForRoam(); sent("api/official/active-for-roam")
        let command = try XCTUnwrap(OfficialSignupCommand(eventID: 71, requestID: OfficialSignupCommand.newRequestID()))
        _ = await service.signupCommand(.submit, command: command); sent("api/official/signup-command")
        _ = await service.signupCommand(.query, command: command); sent("api/official/signup-command/query")
        _ = await service.signupCommand(.cancel, command: command); sent("api/official/signup-command/cancel")
        _ = await service.teamInviteQRCode(teamID: 4); sent("api/team/invite-qrcode")
        _ = await service.teamTrailState(activityID: 9); sent("api/team/trail/state")
        _ = await service.teamTrailConsent(activityID: 9, share: true); sent("api/team/trail/consent")
        _ = await service.teamTrailSync(activityID: 9, points: [.init(latitude: 31.2, longitude: 121.4)], done: 1); sent("api/team/trail/sync")
        _ = await service.joinInfo(memberID: player.session.accountID); sent("api/registration/join_info")
        _ = await service.requestHost(activityID: 3, ticketID: 8); sent("api/club/event-ops/host/request")
        _ = await service.publishPrecheck(merchantHost: false); sent("api/activity/publish_precheck")
        _ = await service.leadArrive(activityID: 3, latitude: 31.2, longitude: 121.4); sent("api/club/lead/arrive")
        _ = await service.leadBroadcast(activityID: 3, text: "go"); sent("api/club/lead/broadcast")
        _ = await service.clubPostLikeState(postID: 5, clubID: 2); sent("api/club/post/like-state")
        _ = await service.favoriteCityNodes(); sent("api/city/nodes/favorites")
        _ = await service.merchantCityNode(merchantID: 12); sent("api/city/nodes/merchant/12")
        _ = await service.assetCredit(reference: "https://m/1.jpg"); sent("api/media/asset/attribution")
        _ = await service.renameObjectCard(id: 4, title: "Lamp"); sent("api/object-card/rename")
        _ = await service.playerCode(); sent("api/user/player-code")
        let before = recorder.paths.count
        let base = player.baseURL
        // Moderator pin and the leader tools are host-only; the player grant does not name them.
        for host in ["api/club/post/pin", "api/club/lead/start", "api/club/lead/settle", "api/club/lead/unlock-chapter"] {
            XCTAssertFalse(grant.play.paths.contains(host), host)
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/settlement/mine"))
        for money in ["api/registration/payment-readiness", "api/club/personal-receiver/bind", "api/club/personal-receiver/unbind",
                      "api/club/settlement/withdraw", "api/wallet/withdraw", "api/registration/pay",
                      "api/club-compensation/editions/empty-reason", "api/club/lead/release-station", "api/merchant/payout-account/save"] {
            XCTAssertFalse(grant.play.paths.contains(money), money)
            await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent(money), #"{"activityId":3}"#, token: player.session.token)) }
        }
        var status = URLRequest(url: base.appendingPathComponent("api/club/personal-receiver/status")); status.httpMethod = "GET"
        status.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        // Owner 2026-11-14: the receiver status is a status read and is admitted on production.
        _ = try await transport.send(status)
        XCTAssertEqual(recorder.paths.last, "api/club/personal-receiver/status")
        XCTAssertEqual(recorder.paths.count, before + 1)
    }

    /// Parity package P-B: organiser shared-run control, the lead ticket scan, editor alternatives, the circle host,
    /// and the analytics batch reach the network through the shipped China composition. Money stays closed.
    func testShippedChinaAdmitsParityBRoutesAndKeepsMoneyClosed() async throws {
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
        for path in PlayerGapService.parityBPaths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(grant.play.paths.contains(path), path)
        }
        let service = PlayerGapService(baseURL: player.baseURL, accountID: player.session.accountID,
                                       token: { player.session.token }, transport: transport)
        func sent(_ path: String, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(recorder.paths.last, path, file: file, line: line)
        }
        _ = await service.sharedControl(activityID: 5); sent("api/game/session/shared/control")
        _ = await service.sharedExport(activityID: 5); sent("api/game/session/shared/export")
        _ = await service.anchorSharedRun(activityID: 5); sent("api/game/session/shared/export/anchor")
        _ = await service.scanGroupMemberTicket(code: "dyn-1", activityID: 5); sent("api/registration/scan_group_member_ticket")
        let seat = try XCTUnwrap(RegistrationSeatTarget(code: "v1.88.topic_seat_2.a.b.c", activityID: 5))
        _ = await service.seatReceipt(seat); sent("api/verify/seat/receipt")
        _ = await service.saveOrientAlternative(topicID: 12, taskID: 34, row: .init(type: .photo, on: true, prompt: "door")); sent("api/orient/task/alternative")
        _ = await service.orientAlternatives(topicID: 12, taskID: 34); sent("api/topic/author-saved-detail")
        _ = await service.circleHostTopic(topicID: 12); sent("api/project/home")
        _ = await service.configureCircleInstance(topicID: 12, candidateCodes: ["F1", "F3", "F5"]); sent("api/circle-theme/instance/configure")
        let analytics = AnalyticsQueuedEvent(eventName: "finish_route_recommendation_click", anonymousId: "", actorScope: "member:1",
            sessionId: "s_1", source: AnalyticsEventClient.source, pagePath: "/pages/play/index", bizType: "activity", bizId: 9,
            cityCode: "", propertiesJson: "{}", idempotencyKey: "k1", occurredAt: "2026-11-13T00:00:00.000Z")
        _ = await service.postAnalyticsBatch([analytics]); sent("api/analytics/events/batch")
        let before = recorder.paths.count
        let base = player.baseURL
        // Money, and the merchant-scope supply review, stay closed.
        for closed in ["api/registration/pay", "api/registration/payment-readiness", "api/wallet/withdraw",
                       "api/club/settlement/withdraw", "api/circle-theme/instance/review"] {
            XCTAssertFalse(grant.play.paths.contains(closed), closed)
            await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent(closed), #"{"activityId":3}"#, token: player.session.token)) }
        }
        XCTAssertEqual(recorder.paths.count, before)
    }

    /// G1 play runtime: every owner-approved player read/write the play page needs reaches the network
    /// through the shipped China composition, built by the app's own `PlayRuntimeClient`. Money stays closed.
    func testShippedChinaAdmitsPlayRuntimeAndKeepsMoneyClosed() async throws {
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
        let client = try PlayRuntimeClient(configuration: APIConfiguration(baseURL: player.baseURL), transport: transport, token: player.session.token)
        let posts: [(String, [String: String])] = [
            ("api/play/check/roll", ["topicId": "12", "activityId": "0", "sessionId": "41", "nodeId": "34", "checkId": "c_1"]),
            ("api/play/check/reroll", ["topicId": "12", "activityId": "0", "sessionId": "41", "nodeId": "34", "checkId": "c_1"]),
            ("api/play/check/settle", ["topicId": "12", "activityId": "0", "sessionId": "41", "nodeId": "34", "checkId": "c_1"]),
            ("api/play/run-session/clear", ["savedAt": "1700000000000", "topicId": "12"])
        ]
        for (path, fields) in posts {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(grant.play.paths.contains(path), path)
            _ = try await client.postForm(path, fields: fields)
            XCTAssertEqual(recorder.paths.last, path)
        }
        let jsons: [(String, [String: PlayWireValue])] = [
            ("api/play/help/shared", ["activityId": .integer(5), "operation": .string("VIEW"), "capabilities": .string("game.teamCooperation@1")]),
            ("api/play/theme/gameplay-action", ["sessionId": .integer(41), "expectedVersion": .integer(6), "actionId": .string("theme_1"),
                                                "operation": .string("QUEST_START"), "contentId": .string("q1")]),
            ("api/play/theme/gameplay-preview", ["sessionId": .integer(41), "expectedVersion": .integer(6),
                                                 "operation": .string("QUEST_RESOLVE"), "contentId": .string("q1")]),
            ("api/game/session/shared/preview", ["activityId": .integer(5), "action": .string("TRADE_OPEN"), "payload": .object([:])]),
            ("api/circle-theme/session/answer", ["sessionId": .integer(9), "stage": .string("s1"), "value": .string("a")]),
            ("api/circle-theme/session/record", ["sessionId": .integer(9), "offerId": .integer(3), "note": .string("")])
        ]
        for (path, body) in jsons {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(grant.play.paths.contains(path), path)
            _ = try await client.postJSON(path, body: body)
            XCTAssertEqual(recorder.paths.last, path)
        }
        let reads: [(String, [String: String])] = [
            ("api/play/encounter", ["topicId": "12", "nodeId": "34"]),
            ("api/play/check/receipt", ["sessionId": "41", "nodeId": "34", "checkId": "c_1", "action": "roll"]),
            ("api/play/advanced/receipt", ["sessionId": "9", "idempotencyKey": "k-1"]),
            ("api/play/history", ["activityId": "0", "topicId": "12", "routeSessionId": "41"]),
            ("api/play/setup", ["topicId": "12"]),
            ("api/play/contact", ["topicId": "12", "nodeId": "34"])
        ]
        for (path, query) in reads {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            _ = try await client.get(path, query: query)
            XCTAssertEqual(recorder.paths.last, path)
        }
        // g-partials: the TEAM backpack reads the player's own game-session projection only.
        _ = try await client.get("api/game/session/view", query: ["activityId": "5", "perspective": "PLAYER"])
        XCTAssertEqual(recorder.paths.last, "api/game/session/view")
        let viewCount = recorder.paths.count
        for perspective in ["CLUB", "MERCHANT"] {
            var other = URLRequest(url: URL(string: player.baseURL.appendingPathComponent("api/game/session/view").absoluteString
                + "?activityId=5&perspective=" + perspective)!)
            other.httpMethod = "GET"; other.setValue(player.session.token, forHTTPHeaderField: "Authorization")
            await assertClosed { try await transport.send(other) }
        }
        XCTAssertEqual(recorder.paths.count, viewCount)
        // g-partials: the circle page's own player reads, open/join, answer and record.
        for circle in ["api/circle-theme/instance/{}/offers", "api/circle-theme/session", "api/circle-theme/session/join",
                       "api/circle-theme/session/{}/card", "api/circle-theme/session/answer", "api/circle-theme/session/record"] {
            XCTAssertTrue(grant.play.paths.contains(circle), circle)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + circle.replacingOccurrences(of: "{}", with: "12")), circle)
        }
        var card = URLRequest(url: player.baseURL.appendingPathComponent("api/circle-theme/session/12/card")); card.httpMethod = "GET"
        card.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(card)
        XCTAssertEqual(recorder.paths.last, "api/circle-theme/session/12/card")
        _ = try await client.postJSON("api/circle-theme/session", body: ["topicId": .integer(12)])
        XCTAssertEqual(recorder.paths.last, "api/circle-theme/session")
        // A read path is not a write grant. Organiser control/export and the circle configure are the parity-b grant
        // (testShippedChinaAdmitsParityBRoutesAndKeepsMoneyClosed); the merchant supply review stays closed.
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/play/history"), #"{"topicId":12}"#, token: player.session.token)) }
        XCTAssertFalse(grant.play.paths.contains("api/circle-theme/instance/review"))
        for money in ["/api/registration/pay", "/api/pay/create", "/api/withdrawal/create", "/api/wallet/withdraw", "/api/asset/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/pay/create"), #"{"amount":1}"#, token: player.session.token)) }
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/wallet/withdraw"), #"{"amount":1}"#, token: player.session.token)) }
        XCTAssertFalse(recorder.paths.contains("api/pay/create"))
        XCTAssertFalse(recorder.paths.contains("api/wallet/withdraw"))
    }

    /// U06 / U08-03 / U08-04: the creator's feedback, maintenance tickets and post-game outcome report are owner-approved
    /// non-money reads and writes for a signed-in China player or creator; money stays closed.
    func testShippedChinaAdmitsCreatorStudioAndKeepsMoneyClosed() async throws {
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
        for path in ["api/creator/feedback", "api/creator/maintenance/tickets", "api/creator/maintenance/tickets/{}",
                     "api/creator/maintenance/tickets/{}/close", "api/creator/maintenance/requests/{}",
                     "api/creator/analytics/post-game-outcome"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
            XCTAssertTrue(grant.play.paths.contains(path), path)
        }
        let token = player.session.token
        let service = CreatorStudioService(configuration: try APIConfiguration(baseURL: player.baseURL),
            transport: transport, token: { token })
        _ = try? await service.feedback(topicID: 992001)
        XCTAssertEqual(recorder.paths.last, "api/creator/feedback")
        _ = try? await service.tickets(limit: 1)
        XCTAssertEqual(recorder.paths.last, "api/creator/maintenance/tickets")
        _ = try? await service.ticket(id: 2)
        XCTAssertEqual(recorder.paths.last, "api/creator/maintenance/tickets/2")
        let open = CreatorTicketOpenRequest(topicId: 992001, title: "Entrance sign", note: nil, feedbackIds: [2])
        _ = await service.openTicket(open)
        XCTAssertEqual(recorder.paths.last, "api/creator/maintenance/tickets")
        _ = try? await service.openRequest(open.requestId)
        XCTAssertEqual(recorder.paths.last, "api/creator/maintenance/requests/" + open.requestId)
        _ = await service.closeTicket(id: 2, .init(expectedVersion: 1, resolution: .noChange, reason: "verified"))
        XCTAssertEqual(recorder.paths.last, "api/creator/maintenance/tickets/2/close")
        _ = try? await service.postGameOutcome(cohortDate: "2026-11-13", windowDays: 30)
        XCTAssertEqual(recorder.paths.last, "api/creator/analytics/post-game-outcome")
        XCTAssertEqual(recorder.paths.count, 7)
        // A ticket write carrying a money field is not this write.
        var priced = jsonRequest(player.baseURL.appendingPathComponent("api/creator/maintenance/tickets"),
            #"{"requestId":"0123456789abcdef0123456789abcdef","topicId":1,"title":"t","feedbackIds":[1],"amount":1}"#, token: token)
        priced.httpShouldHandleCookies = false
        await assertClosed { try await transport.send(priced) }
        for money in ["/api/registration/pay", "/api/pay/create", "/api/wallet/withdraw", "/api/club/settlement/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
        await assertClosed { try await transport.send(self.jsonRequest(player.baseURL.appendingPathComponent("api/pay/create"), #"{"amount":1}"#, token: token)) }
        XCTAssertEqual(recorder.paths.count, 7)
    }

    func testShippedChinaAdmitsAFreeQuoteAndSignupConsentAndRefusesAPaidQuote() async throws {
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
        let quoteFields: [String: Any] = ["isUsePoint": 0, "ownerId": 992031, "ownerType": 2, "ticketId": 992041]
        let quoteBody = try JSONSerialization.data(withJSONObject: quoteFields, options: .sortedKeys)
        var quote = URLRequest(url: base.appendingPathComponent("api/registration/quote"))
        quote.httpMethod = "POST"
        quote.httpBody = quoteBody
        quote.setValue("application/json", forHTTPHeaderField: "Content-Type")
        quote.setValue("application/json", forHTTPHeaderField: "Accept")
        quote.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(quote)
        XCTAssertEqual(recorder.paths.last, "api/registration/quote")
        let consentFields: [String: Any] = [
            "docType": "activity_host_data_sharing", "eventType": "AGREE",
            "requestId": "app-9004-free", "scene": "activity_signup"
        ]
        var consent = URLRequest(url: base.appendingPathComponent("api/compliance/consents"))
        consent.httpMethod = "POST"
        consent.httpBody = try JSONSerialization.data(withJSONObject: consentFields, options: .sortedKeys)
        consent.setValue("application/json", forHTTPHeaderField: "Content-Type")
        consent.setValue("application/json", forHTTPHeaderField: "Accept")
        consent.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(consent)
        XCTAssertEqual(recorder.paths.last, "api/compliance/consents")
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/registration/quote"), #"{"ownerType":2,"payAmount":1}"#, token: player.session.token)) }
        XCTAssertEqual(SessionRegistrationSheet.freeWhenUnapproved(.disabled), .free)
        XCTAssertEqual(SessionRegistrationSheet.freeWhenUnapproved(.free), .free)
    }

    /// Handover 27: team create and TEAM item commands join the existing player grant.
    /// The China route catalog already listed these paths, so the wired pattern count does not move.
    func testShippedChinaAdmitsTeamCreateAndTeamItemCommands() async throws {
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
        XCTAssertTrue(grant.team.paths.contains("api/team/create"))
        XCTAssertTrue(grant.play.paths.contains("api/game/session/command"))
        XCTAssertTrue(grant.play.paths.contains("api/game/session/view"))
        XCTAssertTrue(grant.play.paths.contains("api/game/session/receipt"))
        for path in ["api/team/create", "api/game/session/command", "api/game/session/view", "api/game/session/receipt", "api/activity/list"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        let create = jsonRequest(base.appendingPathComponent("api/team/create"),
            #"{"joinMode":1,"maxMembers":4,"ownerId":41,"ownerType":2}"#, token: player.session.token)
        _ = try await transport.send(create)
        XCTAssertEqual(recorder.paths.last, "api/team/create")
        let command = jsonRequest(base.appendingPathComponent("api/game/session/command"),
            #"{"action":"ITEM_USE","activityId":41,"expectedRevision":3,"nodeId":null,"payload":{"contentId":"tea"},"requestId":"pg-theme-abc12345"}"#,
            token: player.session.token)
        _ = try await transport.send(command)
        XCTAssertEqual(recorder.paths.last, "api/game/session/command")
        var viewParts = URLComponents(url: base.appendingPathComponent("api/game/session/view"), resolvingAgainstBaseURL: false)
        viewParts?.queryItems = [URLQueryItem(name: "activityId", value: "41"), URLQueryItem(name: "perspective", value: "PLAYER")]
        var view = URLRequest(url: try XCTUnwrap(viewParts?.url))
        view.httpMethod = "GET"
        view.setValue("application/json", forHTTPHeaderField: "Accept")
        view.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        _ = try await transport.send(view)
        XCTAssertEqual(recorder.paths.last, "api/game/session/view")
        let sent = recorder.paths.count
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/team/create"),
            #"{"amount":1,"maxMembers":4,"ownerId":41,"ownerType":2}"#, token: player.session.token)) }
        await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent("api/game/session/command"),
            #"{"action":"PLAYER_CHOICE","activityId":41,"expectedRevision":3,"nodeId":null,"payload":{"contentId":"tea"},"requestId":"pg-theme-abc12345"}"#,
            token: player.session.token)) }
        XCTAssertEqual(recorder.paths.count, sent)
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

    @MainActor func testShippedChinaAdmitsTeamLobbyAndSeatsWithBackendAuthContract() async throws {
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let recorder = PlayerReadRecorder()
        let composition = RegionalLaunchConfiguration.shippedComposition(
            build: .init(market: "CN", baseURL: base.absoluteString, bundleIdentifier: "com.chengyin.app", realm: "china-prod"),
            makeTransport: { recorder }
        )
        let session = composition.makeSession()
        let transport = session.runtimeHTTPTransport
        let token = "jwt.player.token"

        func getRequest(_ path: String, queryItems: [URLQueryItem], auth: String? = token) throws -> URLRequest {
            var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
            components.queryItems = queryItems.isEmpty ? nil : queryItems
            var request = URLRequest(url: try XCTUnwrap(components.url))
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let auth { request.setValue(auth, forHTTPHeaderField: "Authorization") }
            return request
        }

        // Direct route matcher aligns with backend-app-r2 (Authorization raw JWT + exact GET params in either order for lobby).
        let sortedLobby = try getRequest("api/orient/team/lobby", queryItems: [
            URLQueryItem(name: "ownerId", value: "7"),
            URLQueryItem(name: "ownerType", value: "2")
        ])
        let orderedLobby = try getRequest("api/orient/team/lobby", queryItems: [
            URLQueryItem(name: "ownerType", value: "1"),
            URLQueryItem(name: "ownerId", value: "7")
        ])
        let seats = try getRequest("api/play/player-journey/seats", queryItems: [URLQueryItem(name: "registrationId", value: "15")])
        let invitations = try getRequest("api/play/seat-invitations", queryItems: [URLQueryItem(name: "registrationId", value: "15")])
        let invitationDetail = try getRequest("api/play/seat-invitations/inv-1", queryItems: [])

        XCTAssertEqual(ReviewedOrientOfficialRoute.kind(sortedLobby, baseURL: base, token: token), .read)
        XCTAssertEqual(ReviewedOrientOfficialRoute.kind(orderedLobby, baseURL: base, token: token), .read)
        XCTAssertEqual(ReviewedOrientOfficialRoute.kind(seats, baseURL: base, token: token), .read)
        XCTAssertEqual(ReviewedOrientOfficialRoute.kind(invitations, baseURL: base, token: token), .read)
        XCTAssertEqual(ReviewedOrientOfficialRoute.kind(invitationDetail, baseURL: base, token: token), .read)

        // Missing or mismatched Authorization, zero IDs, duplicate query keys, or POST-only invitation segments stay refused.
        XCTAssertNil(ReviewedOrientOfficialRoute.kind(try getRequest("api/orient/team/lobby", queryItems: [URLQueryItem(name: "ownerId", value: "7"), URLQueryItem(name: "ownerType", value: "2")], auth: nil), baseURL: base, token: token))
        XCTAssertNil(ReviewedOrientOfficialRoute.kind(try getRequest("api/play/player-journey/seats", queryItems: [URLQueryItem(name: "registrationId", value: "0")]), baseURL: base, token: token))
        XCTAssertNil(ReviewedOrientOfficialRoute.kind(try getRequest("api/play/seat-invitations/invite", queryItems: []), baseURL: base, token: token))

        // Unauthenticated session transport must refuse seats / lobby before wire dispatch.
        await assertClosed { try await transport.send(sortedLobby) }
        await assertClosed { try await transport.send(seats) }
        XCTAssertTrue(recorder.paths.isEmpty)
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
