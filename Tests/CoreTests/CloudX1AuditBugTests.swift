import XCTest
@testable import QuestifyCore

/// One lock per X1 port-time bug. These assert the corrected behavior, not the mini-program bug.
final class CloudX1AuditBugTests: XCTestCase {
    func testReactionBallShakeAndQuietHoldRequireStartBeforeSubmit() {
        for pair in [("reaction", "SUBMIT_REACTION"), ("ballShake", "SUBMIT_BALL_SHAKE"), ("quietHold", "SUBMIT_QUIET_HOLD")] {
            XCTAssertFalse(PlayKitChallengeStartGate.allowsSubmit(kind: pair.0, action: pair.1, started: false))
            XCTAssertTrue(PlayKitChallengeStartGate.allowsSubmit(kind: pair.0, action: pair.1, started: true))
        }
        XCTAssertTrue(PlayKitChallengeStartGate.allowsSubmit(kind: "note", action: "SUBMIT_NOTE", started: false))
        XCTAssertTrue(PlayKitActionCatalog.actions["reaction"]?.contains("START_CHALLENGE") == true)
    }

    func testUnknownPaymentStateExplainsItself() {
        let unknown = UnknownPaymentState.explanation(payment: 9, registration: 1)
        XCTAssertEqual(unknown, W8Text.t(
            "支付状态无法识别（9）。这台设备不会收款，也不会把订单标成已支付。",
            "Payment state 9 is not recognized. This device will not collect payment or mark the order paid."))
        let absent = UnknownPaymentState.explanation(payment: nil, registration: nil)
        XCTAssertNotNil(absent)
        XCTAssertTrue(absent?.contains("—") == true)
        XCTAssertTrue(absent?.contains("不会收款") == true || absent?.contains("will not collect") == true)
        XCTAssertNil(UnknownPaymentState.explanation(payment: 1, registration: 1))
        XCTAssertNil(UnknownPaymentState.explanation(payment: 2, registration: nil))
    }

    func testTopicOrderCarriesSourceClubId() throws {
        let topic = try XCTUnwrap(SelfPlayTopicID(rawValue: 77))
        let intent = try TopicSelfPlayIntent(topic: topic, realName: "Synthetic", phone: "13800000000", requestID: "synthetic-intent", sourceClubId: 42)
        let body = try JSONDecoder().decode([String: ProjectEditJSON].self, from: JSONEncoder().encode(intent))
        XCTAssertEqual(body["sourceClubId"], .number(42))
        XCTAssertEqual(body["isUsePoint"], .number(0))
        XCTAssertEqual(body["payChannel"], .string("APP"))
        let omitted = try TopicSelfPlayIntent(topic: topic, realName: "Synthetic", phone: "13800000000", requestID: "synthetic-intent", sourceClubId: 0)
        let plain = try JSONDecoder().decode([String: ProjectEditJSON].self, from: JSONEncoder().encode(omitted))
        XCTAssertNil(plain["sourceClubId"])
    }

    func testNullRemainingInventoryIsUnknownNotSoldOut() throws {
        let activityMissing = try JSONDecoder().decode(ActivityTicket.self, from: Data(#"{"id":11,"name":"Fixture"}"#.utf8))
        let activityZero = try JSONDecoder().decode(ActivityTicket.self, from: Data(#"{"id":11,"name":"Fixture","remainingInventory":0}"#.utf8))
        XCTAssertTrue(activityMissing.inventoryIsUnknown)
        XCTAssertFalse(activityMissing.isSoldOut)
        XCTAssertFalse(activityZero.inventoryIsUnknown)
        XCTAssertTrue(activityZero.isSoldOut)
        let topicMissing = try JSONDecoder().decode(TopicTicket.self, from: Data(#"{"id":3,"name":"Fixture"}"#.utf8))
        let topicZero = try JSONDecoder().decode(TopicTicket.self, from: Data(#"{"id":3,"name":"Fixture","remainingInventory":0}"#.utf8))
        XCTAssertNil(topicMissing.remaining)
        XCTAssertTrue(topicMissing.inventoryIsUnknown)
        XCTAssertFalse(topicMissing.isSoldOut)
        XCTAssertEqual(topicZero.remaining, 0)
        XCTAssertTrue(topicZero.isSoldOut)
    }

    func testRegistrationFormRechecksSignupDeadline() throws {
        let ticket = try JSONDecoder().decode(ActivityTicket.self, from: Data(#"{"id":11,"name":"Fixture","selfGuided":false,"startTime":"2031-10-02 12:00:00","endTime":"2031-10-02 18:00:00","signupDeadline":"2030-10-02 12:00:00"}"#.utf8))
        let deadline = try XCTUnwrap(RegistrationWaitlistStatus.parseDeadline("2030-10-02 12:00:00"))
        XCTAssertFalse(ticket.registrationClosed(at: deadline.addingTimeInterval(-1)))
        XCTAssertTrue(ticket.registrationClosed(at: deadline))
        let start = try XCTUnwrap(RegistrationWaitlistStatus.parseDeadline("2031-10-02 12:00:00"))
        let end = try XCTUnwrap(RegistrationWaitlistStatus.parseDeadline("2031-10-02 18:00:00"))
        XCTAssertEqual(TicketWindowRule.state(startTime: start, endTime: end, signupDeadline: deadline, selfGuided: false, now: deadline.addingTimeInterval(-1)), .available)
        XCTAssertEqual(TicketWindowRule.state(startTime: start, endTime: end, signupDeadline: deadline, selfGuided: false, now: deadline), .closed)
    }

    func testClubRolePickerUpdatesTheDraft() throws {
        var draft = ClubGovernanceFormDraft(operation: .assignRole, scope: ClubGovernanceScope(clubID: 7))
        XCTAssertEqual(draft.text["roleCode"], "CLUB_OPERATOR")
        draft.applyClubRolePicker(memberID: "42", roleCode: "CLUB_CO_OWNER")
        let command = try draft.command()
        XCTAssertEqual(command.fields["roleCode"]?.string, "CLUB_CO_OWNER")
        XCTAssertEqual(command.fields["targetMemberId"]?.int, 42)
    }

    func testSilentOrderGiveUpActsWithoutACompletionAction() {
        var clock = PlayKitSilentOrderGiveUp(running: true)
        clock.giveUp()
        XCTAssertFalse(clock.running)
        XCTAssertTrue(clock.gaveUp)
        XCTAssertEqual(PlayKitActionCatalog.actions["silentOrder"], [])
    }

    func testMode2ShopVisitCompletesOnlyFromMerchantRedemption() throws {
        XCTAssertFalse(PlayMode2ShopVisit.isComplete(done: false, arrived: true, selfReported: true))
        XCTAssertTrue(PlayMode2ShopVisit.isComplete(done: true, arrived: false, selfReported: false))
        let open = try snapshot(mode: 2, node: #"{"nodeId":701,"done":false,"arrived":true,"selfReported":true,"routeNodeState":"COMPLETED"}"#)
        XCTAssertNotEqual(PlayTaskStatusPresentation(node: open.visibleNodes[0], snapshot: open), .completed)
        let redeemed = try snapshot(mode: 2, node: #"{"nodeId":701,"done":true,"arrived":true,"selfReported":true}"#)
        XCTAssertEqual(PlayTaskStatusPresentation(node: redeemed.visibleNodes[0], snapshot: redeemed), .completed)
    }

    func testLeaderboardFetchFailureIsAnErrorNotEmpty() {
        XCTAssertEqual(LeaderboardFetchPresentation.resolve(phase: "failed", rowCount: 0), .error)
        XCTAssertNotEqual(LeaderboardFetchPresentation.resolve(phase: "failed", rowCount: 0), .empty)
        XCTAssertEqual(LeaderboardFetchPresentation.resolve(phase: "ready", rowCount: 0), .empty)
        XCTAssertEqual(LeaderboardFetchPresentation.resolve(phase: "ready", rowCount: 3), .ready)
    }

    func testClosingTheAdvancedPanelClosesThePlayKitSheet() {
        let open = AdvancedPlayKitPresentation(advancedOpen: true, playKitOpen: true)
        XCTAssertEqual(open.closingAdvancedPanel(), AdvancedPlayKitPresentation(advancedOpen: false, playKitOpen: false))
    }

    func testDisabledCallToActionExplainsWhy() {
        XCTAssertNil(DisabledCallToAction.reason(enabled: true))
        let reason = DisabledCallToAction.reason(enabled: false)
        XCTAssertEqual(reason, W8Text.t(
            "现在不能继续。这一步还没准备好。这台设备不会收款，也不会把订单标成已支付。",
            "You can’t continue yet. This step is not ready. This device will not collect payment or mark an order paid."))
    }

    @MainActor func testCreateResponseDataIsAScalarTopicId() throws {
        let session = try ProjectEditSession(accountID: 701, epoch: 1, storageNamespace: "test-cn")
        let pending = try ProjectEditPending(
            operationID: UUID(),
            ownerKey: session.ownerKey,
            identity: .init(),
            payload: ProjectEditContract.payload(ProjectEditSyntheticFixtures.draft(), topicID: nil, scope: .full))
        XCTAssertEqual(try ProjectEditStoryContract.path(payload: pending.payload, baseline: nil), ProjectEditStoryContract.createPath)
        let scalar = ProjectEditHTTPService.decodeAcknowledgment(Data(#"{"code":200,"data":8801}"#.utf8), status: 200, operation: pending)
        XCTAssertEqual(scalar, .acknowledged(operationID: pending.operationID, topicID: 8801))
        let object = ProjectEditHTTPService.decodeAcknowledgment(
            Data(#"{"code":200,"data":{"topicId":8801,"auditTaskId":null,"reviewState":"NOT_REQUIRED","published":false,"bundledTemplateIds":[]}}"#.utf8),
            status: 200, operation: pending)
        guard case .bundleAcknowledged(_, let acknowledgment) = object else {
            return XCTFail("object create acknowledgment must stay a bundle")
        }
        XCTAssertEqual(acknowledgment.topicID, 8801)
        XCTAssertThrowsError(try ProjectEditBundleAcknowledgment.decode(.number(71), expectedTopicID: nil))
    }

    func testResumeDraftAtTheSavedStep() throws {
        let session = PublishingSession(namespace: "synthetic", accountID: 1, epoch: UUID(), role: "player", region: .china)
        let draft = ActivityPublishDraft()
        let saved = try PublishingLocalDraft(session: session, identity: UUID(), activity: draft, wizardStep: 2)
        XCTAssertEqual(ActivityPublishingWizard.resumeIndex(draft), 0)
        XCTAssertEqual(ActivityPublishingWizard.located(2, draft: draft), 0)
        XCTAssertEqual(ActivityPublishingWizard.resume(savedStep: saved.wizardStep, draft: draft), 2)
        let decoded = try JSONDecoder().decode(PublishingLocalDraft.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded.wizardStep, 2)
        XCTAssertEqual(ActivityPublishingWizard.resume(savedStep: nil, draft: draft), 0)
    }

    func testCityNodeCodeFromTheWrongPlaceSaysWhereToRedeem() {
        XCTAssertThrowsError(try MerchantRedemptionContext.parse("v1.9.citynode_4.synthetic")) { error in
            let failure = error as? MerchantRedemptionFailure
            XCTAssertEqual(failure, .cityNodeWrongPlace)
            XCTAssertEqual(failure?.redemptionPlace, W8Text.t(
                "这是城市据点核销码，请到城市据点核销入口兑换，不要在门票或活动核销处使用。",
                "This is a city-node code. Redeem it at the city-node entry, not at ticket or activity redemption."))
        }
        XCTAssertThrowsError(try MerchantRedemptionContext.parse("v1.synthetic.admin.untrusted")) {
            XCTAssertEqual($0 as? MerchantRedemptionFailure, .unsupported)
        }
    }

    func testCountdownFallbackTTLIs300Seconds() throws {
        XCTAssertEqual(CountdownTTL.fallbackSeconds, 300)
        XCTAssertEqual(CountdownTTL.seconds(milliseconds: nil), 300)
        XCTAssertEqual(CountdownTTL.seconds(milliseconds: -5), 300)
        XCTAssertEqual(CountdownTTL.seconds(milliseconds: 0), 300)
        XCTAssertEqual(CountdownTTL.seconds(milliseconds: 1000), 1)
        let missing = try JSONDecoder().decode(RoamVoucherSnapshot.self, from: Data(#"{}"#.utf8))
        let negative = try JSONDecoder().decode(RoamVoucherSnapshot.self, from: Data(#"{"ttlMs":-1}"#.utf8))
        XCTAssertEqual(missing.countdownSeconds, 300)
        XCTAssertEqual(negative.countdownSeconds, 300)
    }

    private func snapshot(mode: Int, node: String) throws -> PlaySnapshot {
        try PlaySnapshot(scope: .activity(41), result: JSONDecoder().decode(PlayNodesResult.self, from: Data("""
        {"mode":\(mode),"playable":true,"registered":true,"nodes":[\(node)]}
        """.utf8)))
    }
}
