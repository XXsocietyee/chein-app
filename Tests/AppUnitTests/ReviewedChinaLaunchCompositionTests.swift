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
            .reads, .classicCompletion, .hints, .advanced, .playerCommands, .runPersistence, .journeyOpening
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
        let send = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/im/send"),
            fields: ["conversation_id": "4", "msg_type": "1", "content": "hello", "client_message_id": String(repeating: "ab", count: 16)],
            token: player.session.token)
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
        for money in ["api/registration/payment-readiness", "api/club/personal-receiver/bind", "api/club/personal-receiver/unbind",
                      "api/club/settlement/mine", "api/club/settlement/withdraw", "api/wallet/withdraw", "api/registration/pay",
                      "api/club-compensation/editions/empty-reason", "api/club/lead/release-station"] {
            XCTAssertFalse(grant.play.paths.contains(money), money)
            await assertClosed { try await transport.send(self.jsonRequest(base.appendingPathComponent(money), #"{"activityId":3}"#, token: player.session.token)) }
        }
        var status = URLRequest(url: base.appendingPathComponent("api/club/personal-receiver/status")); status.httpMethod = "GET"
        status.setValue(player.session.token, forHTTPHeaderField: "Authorization")
        await assertClosed { try await transport.send(status) }
        XCTAssertEqual(recorder.paths.count, before)
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
