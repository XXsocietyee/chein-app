import Foundation
import XCTest
@testable import QuestifyCore

final class RpgGameplayParityTests: XCTestCase {

    // MARK: - PlayThemeGameplayRules (`pages/play/utils/theme-gameplay.js`)

    func testLabelsAndAmountsUseCustomStatsAndCatalogItems() {
        let view: PlayWireValue = .object([
            "hpName": .string("灵力"),
            "luckName": .string("机缘"),
            "actionName": .string("行动力"),
            "attributes": .array([
                .object(["key": .string("san"), "label": .string("理智")])
            ]),
            "world": .object([
                "itemCatalog": .array([
                    .object(["id": .string("key_gold"), "name": .string("黄金钥匙")])
                ])
            ])
        ])
        let labels = PlayThemeGameplayRules.labels(view)
        XCTAssertEqual(labels.hp, "灵力")
        XCTAssertEqual(labels.luck, "机缘")
        XCTAssertEqual(labels.action, "行动力")

        let source: PlayWireValue = .object([
            "hpCost": .int(2),
            "luckCost": .int(1),
            "statCosts": .array([
                .object(["statKey": .string("san"), "amount": .int(5)])
            ]),
            "resourceCosts": .array([
                .object(["itemId": .string("key_gold"), "quantity": .int(2)])
            ])
        ])
        let amounts = PlayThemeGameplayRules.amounts(source, view: view)
        XCTAssertEqual(amounts, ["灵力 2", "机缘 1", "理智 5", "黄金钥匙 ×2"])
        XCTAssertTrue(PlayThemeGameplayRules.hasFees(source))
    }

    func testShortfallTextAndActionRows() {
        let view: PlayWireValue = .object([
            "scope": .string("PLAYER"),
            "hpName": .string("体力"),
            "allowedActions": .array([
                .object([
                    "operation": .string("QUEST_START"),
                    "contentId": .string("q_1"),
                    "costOptions": .array([
                        .object(["label": .string("强行破拆"), "hpCost": .int(2), "affordable": .bool(true)]),
                        .object([
                            "label": .string("巧手开锁"),
                            "hpCost": .int(5),
                            "affordable": .bool(false),
                            "shortfall": .array([
                                .object(["key": .string("HP"), "missing": .int(3)])
                            ])
                        ])
                    ])
                ])
            ]),
            "quests": .array([
                .object([
                    "questKey": .string("q_1"),
                    "title": .string("开启密室"),
                    "nodeId": .int(10),
                    "status": .string("OPEN")
                ])
            ])
        ])

        let rows = PlayThemeGameplayRules.actionRows(
            view,
            nodes: [PlayThemeRouteNodeRef(nodeId: 10, name: "钟楼密室")]
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].title, "钟楼密室")
        XCTAssertEqual(rows[0].operation, "QUEST_START")
        XCTAssertTrue(rows[0].enabled)
        XCTAssertEqual(rows[0].costOptions.count, 2)
        XCTAssertEqual(rows[0].costOptions[1].shortfallText, "缺少体力 3")
    }

    func testQuestReceiptText() {
        let view: PlayWireValue = .object([
            "hpName": .string("体力"),
            "itemCatalog": .array([
                .object(["id": .string("herb"), "name": .string("止血草")])
            ])
        ])
        let receipt: PlayWireValue = .object([
            "settlement": .object([
                "questResult": .object([
                    "questKey": .string("q_1"),
                    "completed": .bool(true),
                    "statDeltas": .object(["HP": .int(-2)]),
                    "grantedItems": .array([
                        .object(["itemId": .string("herb"), "quantity": .int(3)])
                    ])
                ])
            ])
        ])
        let text = PlayThemeGameplayRules.questReceiptText(receipt, view: view)
        XCTAssertEqual(text, "支线已结算 · 体力 -2 · 止血草 ×3")
    }

    // MARK: - PlayThemeTradeRules (`pages/play/utils/theme-trade.js`)

    func testTradeRecoveryAndPayloadValidation() throws {
        let recRaw: PlayWireValue = .object([
            "facilityResult": .object([
                "recoveryKey": .string("rec_1"),
                "hpDelta": .int(5),
                "consumed": .bool(true),
                "remaining": .int(2)
            ])
        ])
        XCTAssertEqual(
            PlayThemeTradeRules.recoveryText(recRaw, hpName: "生命值"),
            "恢复生命值 5，已消耗一次，剩余 2 次"
        )

        let teamFacilityRaw: PlayWireValue = .object([
            "paidByTeamId": .int(3),
            "consumed": .bool(true),
            "noEffect": .bool(false)
        ])
        XCTAssertEqual(
            PlayThemeTradeRules.recoveryText(teamFacilityRaw),
            "工具已生效，仅队伍 3 支付一次"
        )

        let form = PlayThemeTradeForm(
            toTeamId: 2,
            tradeKey: "tr_1",
            items: [
                PlayThemeTradeFormItem(id: "herb", name: "止血草", give: "2", take: "0"),
                PlayThemeTradeFormItem(id: "gem", name: "灵石", give: "0", take: "1")
            ]
        )
        let payload = try PlayThemeTradeRules.payload(form)
        XCTAssertEqual(payload.tradeKey, "tr_1")
        XCTAssertEqual(payload.toTeamId, 2)
        XCTAssertEqual(payload.give, [PlayThemeTradePayloadItem(itemId: "herb", quantity: 2)])
        XCTAssertEqual(payload.take, [PlayThemeTradePayloadItem(itemId: "gem", quantity: 1)])
    }

    // MARK: - PlayThemeChallengeRules & PlayThemePlansRules (`theme-backpack.js` & `theme-plans.js`)

    func testZeroHpChallengeAndPlansEnding() throws {
        let nowMs: Int64 = 1_700_000_000_000
        let rawZeroHp: PlayWireValue = .object([
            "zeroHp": .object([
                "phase": .string("RECOVERING"),
                "policy": .string("WAIT"),
                "progress": .int(2),
                "required": .int(5),
                "waitUntilEpochMillis": .int(Int(nowMs + 65_000))
            ])
        ])
        let zeroHp = PlayThemeChallengeRules.presentZeroHp(rawZeroHp, nowMs: nowMs)
        XCTAssertNotNil(zeroHp)
        XCTAssertEqual(zeroHp?.phase, "RECOVERING")
        XCTAssertEqual(zeroHp?.countdownText, "01:05")
        XCTAssertFalse(zeroHp?.syncReady ?? true)

        let challengeView: PlayWireValue = .object([
            "scope": .string("TEAM"),
            "awaitingChallenge": .bool(true),
            "challenge": .object([
                "nodeId": .int(12),
                "progress": .int(1),
                "goal": .int(3),
                "restoreTo": .int(5),
                "used": .int(1),
                "limit": .int(3)
            ]),
            "endingResult": .object([
                "endingKey": .string("end_good"),
                "title": .string("完美结局"),
                "summary": .string("成功守护长安"),
                "tone": .string("SUCCESS"),
                "badges": .array([.string("无伤通关")])
            ])
        ])
        let challenge = PlayThemeChallengeRules.presentChallenge(
            challengeView,
            nodes: [PlayThemeRouteNodeRef(nodeId: 12, name: "鼓楼擂台")]
        )
        XCTAssertTrue(challenge.awaitingChallenge)
        XCTAssertEqual(challenge.challengeNodes.first?.name, "鼓楼擂台")
        XCTAssertEqual(challenge.challengeProgressLabel, "全队进度")
        XCTAssertEqual(challenge.challengeProgressText, "1/3")
        XCTAssertEqual(challenge.challengeRestoreText, "恢复到 5")
        XCTAssertEqual(challenge.challengeRetryText, "失败后可免费重试（已用 1/3）")

        let ending = PlayThemePlansRules.endingResult(challengeView)
        XCTAssertEqual(ending?.key, "end_good")
        XCTAssertEqual(ending?.title, "完美结局")
        XCTAssertEqual(ending?.badges, ["无伤通关"])
    }

    // MARK: - PlayThemeGameplayCoordinator State Machine (`theme-player-ops.js` & conflict handling)

    @MainActor
    func testCoordinatorPlayerOpsValidationAndAuthorityEpochConflict() {
        let teamView: PlayWireValue = .object([
            "scope": .string("TEAM"),
            "activityId": .int(88),
            "teamId": .int(4),
            "revision": .int(10),
            "authorityEpoch": .int(3),
            "availableActions": .array([
                .string("ARRIVAL_ISSUE"),
                .string("MANUAL_SIGN"),
                .string("TEAM_EXIT")
            ]),
            "quests": .array([
                .object([
                    "questKey": .string("q_bell"),
                    "title": .string("敲钟任务"),
                    "nodeId": .int(101),
                    "status": .string("ACTIVE")
                ])
            ]),
            "run": .object([
                "operationStatus": .string("RUNNING"),
                "authorityMode": .string("MANUAL"),
                "manual": .object([
                    "nextSequence": .int(2),
                    "records": .array([
                        .object([
                            "sequence": .int(1),
                            "status": .string("VERIFIED"),
                            "occurredAt": .int(1_700_000_000_000),
                            "command": .object(["action": .string("QUEST_START")])
                        ])
                    ])
                ])
            ])
        ])

        let coordinator = PlayThemeGameplayCoordinator(
            rawView: teamView,
            nodes: [PlayThemeRouteNodeRef(nodeId: 101, name: "古钟楼")]
        )
        XCTAssertEqual(coordinator.playerOperationRows.count, 3)
        XCTAssertEqual(coordinator.playerManualRows.count, 1)
        XCTAssertEqual(coordinator.playerRunText, "当前为现场人工授权")

        // MANUAL_SIGN requires strict YYYY-MM-DD HH:mm:ss format
        coordinator.openPlayerOperation("MANUAL_SIGN")
        coordinator.playerOperationForm?.occurredAtText = "2026-05-01 14:30"
        XCTAssertNil(coordinator.preparePlayerOperationCommand(requestId: "req_1"))
        XCTAssertEqual(coordinator.errorMessage, "请按 YYYY-MM-DD HH:mm:ss 填写实际发生时间")

        // Valid timestamp produces PendingTeamCommand with sequence 2
        coordinator.playerOperationForm?.occurredAtText = "2026-05-01 14:30:00"
        let cmd = coordinator.preparePlayerOperationCommand(requestId: "req_1")
        XCTAssertNotNil(cmd)
        XCTAssertEqual(cmd?.action, "MANUAL_SIGN")
        XCTAssertEqual(cmd?.authorityEpoch, 3)
        XCTAssertEqual(cmd?.payload["sequence"], .int(2))

        // Ambiguous PENDING receipt locks unknownReceiptPending
        let pendingReceipt: PlayWireValue = .object([
            "requestId": .string("req_1"),
            "action": .string("MANUAL_SIGN"),
            "outcome": .string("PENDING")
        ])
        XCTAssertFalse(coordinator.resolveTeamCommandReceipt(pendingReceipt))
        XCTAssertTrue(coordinator.unknownReceiptPending)

        // Applied receipt clears pending command
        let appliedReceipt: PlayWireValue = .object([
            "requestId": .string("req_1"),
            "action": .string("MANUAL_SIGN"),
            "outcome": .string("APPLIED")
        ])
        XCTAssertTrue(coordinator.resolveTeamCommandReceipt(appliedReceipt))
        XCTAssertFalse(coordinator.unknownReceiptPending)
        XCTAssertNil(coordinator.pendingTeamCommand)

        // TEAM_EXIT requires two-step confirmation and rejects stale authorityEpoch
        coordinator.openPlayerOperation("TEAM_EXIT")
        coordinator.playerOperationForm?.reason = "全队临时离场"
        XCTAssertNil(coordinator.preparePlayerOperationCommand(requestId: "req_exit"))
        XCTAssertTrue(coordinator.playerExitConfirm)

        // Simulate server advancing authorityEpoch from 3 to 4 before second confirmation tap
        var updatedObj = teamView.object ?? [:]
        updatedObj["authorityEpoch"] = .int(4)
        coordinator.applyView(.object(updatedObj))
        XCTAssertNil(coordinator.preparePlayerOperationCommand(requestId: "req_exit"))
        XCTAssertEqual(coordinator.errorMessage, "执行权已变化，请重新确认")
    }

    // MARK: - ChallengePOICoordinator (`pages/play/poi-challenge/index.js`)

    @MainActor
    func testChallengePOIHaversineAndStateTransitions() throws {
        let node = ChallengePOINode(
            id: 101,
            name: "鼓楼",
            title: "鼓楼打卡挑战",
            latitude: 39.9400,
            longitude: 116.3896,
            radiusM: 50,
            photoRequired: false,
            question: "鼓楼始建于哪个朝代？",
            options: ["元代", "唐代", "宋代"],
            completed: false
        )
        let coordinator = ChallengePOICoordinator(nodeId: 101)
        // Far coordinate fails radiusM + 30m check
        coordinator.applyLoadedNode(node, userLat: 39.9500, userLon: 116.3896)
        XCTAssertEqual(coordinator.state, .quiz)
        XCTAssertFalse(coordinator.withinRange)
        XCTAssertThrowsError(try coordinator.buildCompletionPayload(userLat: 39.9500, userLon: 116.3896))

        // Nearby coordinate passes radiusM + 30m check
        coordinator.selectedOptionIndex = 0
        let payload = try coordinator.buildCompletionPayload(userLat: 39.9403, userLon: 116.3896)
        XCTAssertEqual(payload["nodeId"], .int(101))
        XCTAssertEqual(payload["answer"], .string("元代"))

        // Prewrite rejection code (1003) unlocks without setting unknownSubmission
        coordinator.applyCompletionResult(code: 1003, data: .object([:]), message: "答案不正确")
        XCTAssertEqual(coordinator.state, .quiz)
        XCTAssertFalse(coordinator.unknownSubmission)
        XCTAssertEqual(coordinator.errorMessage, "答案不正确")

        // Successful completion transitions to .done and populates medal + alreadyClaimed
        coordinator.applyCompletionResult(
            code: 200,
            data: .object([
                "alreadyClaimed": .bool(true),
                "medal": .object([
                    "id": .string("m_1"),
                    "name": .string("鼓楼探索者")
                ])
            ]),
            message: nil
        )
        XCTAssertEqual(coordinator.state, .done)
        XCTAssertTrue(coordinator.alreadyClaimed)
        XCTAssertEqual(coordinator.medal?.name, "鼓楼探索者")
    }

    // MARK: - PlayRecapRules (`pages/play/recap.js`)

    func testBuildPlayRecapFiltersToCompletedUserPicUrlsUpTo12() {
        let nodes: [PlayRecapNodeInput] = [
            PlayRecapNodeInput(nodeId: 1, done: true, picUrl: "https://cdn.example.com/u1.jpg", imgUrl: "https://cdn.example.com/cover1.jpg"),
            PlayRecapNodeInput(nodeId: 2, done: true, picUrl: nil, imgUrl: "https://cdn.example.com/cover2.jpg"),
            PlayRecapNodeInput(nodeId: 3, done: false, picUrl: "https://cdn.example.com/u3.jpg", imgUrl: nil)
        ]
        let recap = PlayRecapRules.buildPlayRecap(nodes)
        XCTAssertTrue(recap.canReplayJournal)
        XCTAssertEqual(recap.photos.count, 1)
        XCTAssertEqual(recap.photos[0].nodeId, 1)
        XCTAssertEqual(recap.photos[0].picUrl, "https://cdn.example.com/u1.jpg")
    }

    // MARK: - CharacterCard & CharacterSheetPresenter (`user-character.js` & `character/index.js`)

    func testCharacterCardReadbackRpgSheetAndStars() {
        let levels = [
            CharacterAttributeLevel(at: 1, label: "初窥"),
            CharacterAttributeLevel(at: 4, label: "精通")
        ]
        let attr = CharacterCardAttribute(
            stateKey: "attr_insight",
            label: "洞察",
            value: 4,
            min: 0,
            max: 5,
            displayType: "stars",
            persistScope: "topic",
            levels: levels
        )
        XCTAssertEqual(attr.levelLabel(levels: levels), "精通")
        XCTAssertEqual(attr.scopeText, "同主题跨局保留")
        XCTAssertEqual(attr.rangeText, "范围 0–5")
        XCTAssertEqual(attr.percent, 80)
        XCTAssertEqual(attr.stars.count, 5)
        XCTAssertEqual(attr.stars.filter(\.filled).count, 4)

        let rpgRaw: PlayWireValue = .object([
            "enabled": .bool(true),
            "momentum": .int(3),
            "momentumMax": .int(6),
            "clocks": .array([
                .object(["var": .string("clk_alert"), "label": .string("警戒值"), "value": .int(2), "segments": .int(4)])
            ]),
            "facets": .array([
                .object(["key": .string("f_1"), "label": .string("老练仵作"), "desc": .string("善于验尸")])
            ]),
            "aspects": .array([
                .object(["key": .string("a_1"), "label": .string("火眼金睛"), "desc": .string("看破伪装")])
            ])
        ])
        let rpgSheet = CharacterRpgSheet.read(rpgRaw)
        XCTAssertNotNil(rpgSheet)
        XCTAssertEqual(rpgSheet?.momentum?.percent, 50)
        XCTAssertEqual(rpgSheet?.clocks.first?.percent, 50)
        XCTAssertEqual(rpgSheet?.facets.first?.tag, "侧面")
        XCTAssertEqual(rpgSheet?.aspects.first?.tag, "本局特质")

        let rows: [PlayWireValue] = [
            .object(["topicId": .int(10), "activityId": .int(99)])
        ]
        XCTAssertTrue(CharacterSheetPresenter.hasTopicRelation(rows: rows, topicID: "10"))
        XCTAssertFalse(CharacterSheetPresenter.hasTopicRelation(rows: rows, topicID: "11"))
        XCTAssertEqual(CharacterSheetPresenter.failure(code: 401, message: nil).state, "unauthorized")
        XCTAssertEqual(CharacterSheetPresenter.failure(code: 403, message: nil).state, "forbidden")
    }
}
