import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// UG-01…UG-10 fixtures. Responses are synthetic and stay in this test target.
final class UGGameplayTests: XCTestCase {
    func testContractOrderHidesSkipGemAndPublish() {
        XCTAssertEqual(UGFeature.displayOrder.map(\.rawValue), ["UG-01", "UG-02", "UG-03", "UG-04", "UG-05", "UG-06", "UG-07", "UG-08", "UG-09", "UG-10"])
        XCTAssertEqual(UGGameplay.contractExecution, "NOT_RUN")
        XCTAssertFalse(UGGameplay.offersSkipButton)
        XCTAssertFalse(UGGameplay.recordsGemBalance)
        XCTAssertFalse(UGGameplay.hasCoinWallet)
        XCTAssertTrue(UGGameplay.accusationPublishable)
        XCTAssertEqual(PlayKitPublishedWrites.accusationAction, "SUBMIT_QA")
        XCTAssertNil(PlayKitActionCatalog.actions["accusation"])
        XCTAssertFalse(UGGameplay.catalogSynced)
        XCTAssertFalse(UGPaidWorkshopInstall.completesInstall)
        XCTAssertEqual(UGPaidWorkshopInstall.unavailableReason, "PAID_INSTALL_AUTHORITY_UNAVAILABLE")
        XCTAssertEqual(UGPaidWorkshopInstall.unavailableReason(for: "AVAILABLE"), UGPaidWorkshopInstall.unavailableReason)
        XCTAssertEqual(UGPaidWorkshopInstall.unavailableReason(for: nil), UGPaidWorkshopInstall.unavailableReason)
    }

    func testUnknownNumbersAreNeverZero() {
        XCTAssertNil(UGNumberFact.parse(.string("UNKNOWN")).literal)
        XCTAssertNil(UGNumberFact.parse(.null).literal)
        XCTAssertNil(UGNumberFact.parse(.string("0")).literal)
        XCTAssertNil(UGNumberFact.parse(.object(["total": .integer(0)])).literal)
        XCTAssertNotEqual(UGNumberFact.parse(.string("UNKNOWN")).literal, 0)
        XCTAssertEqual(UGNumberFact.parse(.integer(0)).literal, 0)
    }

    func testHangmanProjectionDoesNotStoreOrCutTheAnswer() throws {
        let fact = try readyHangman(UGHangman.decodeProjection, #"""
        {"length":7,"blankCount":5,"caseSensitive":false,"solved":false,"display":"E_____S",
         "slots":[{"i":0,"kind":"PREFILLED","ch":"E"},{"i":1,"kind":"BLANK","ch":"N"},{"i":6,"kind":"PREFILLED","ch":"S"}]}
        """#)
        XCTAssertEqual(fact.display, "E_____S")
        XCTAssertEqual(fact.slots[1].character, nil)
        XCTAssertNil(fact.answerText)
        XCTAssertFalse(fact.storesAnswerLocally)
        XCTAssertFalse(fact.judgesLocally)
        XCTAssertFalse(fact.catalogSynced)
        XCTAssertFalse(strings(in: fact).contains("N"))
        XCTAssertEqual(UGHangman.decodeProjection(data: envelope(#"{"length":"UNKNOWN","blankCount":5,"caseSensitive":false,"solved":false,"display":"E_____S","slots":[]}"#), status: 200), .unknown)
        XCTAssertEqual(UGHangman.decodeProjection(data: envelope(#"{"answer":"ENDLESS","length":7,"blankCount":5,"caseSensitive":false,"solved":false,"display":"E_____S","slots":[]}"#), status: 200), .unknown)
        let solved = try readyHangman(UGHangman.decodeResult, #"""
        {"verdict":"CORRECT","solved":true,"display":"ENDLESS","answerText":"ENDLESS","length":7,"blankCount":0}
        """#)
        XCTAssertEqual(solved.answerText, "ENDLESS")
        XCTAssertEqual(UGHangman.decodeResult(data: envelope(#"{"verdict":"WRONG","solved":false,"display":"ENDLEXS","answerText":"ENDLESS"}"#), status: 200), .unknown)
        let wrong = try readyHangman(UGHangman.decodeResult, #"{"verdict":"WRONG","solved":false,"display":"ENDLEXS"}"#)
        XCTAssertNil(wrong.answerText)
        XCTAssertEqual(wrong.display, "ENDLEXS")
        let body = try UGHangman.submitData(input: "NDLES")
        let object = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(object["input"] as? String, "NDLES")
        XCTAssertNil(object["answer"])
        let slots = try UGHangman.submitData(slots: [1: "N"])
        let slotObject = try JSONSerialization.jsonObject(with: slots) as! [String: Any]
        XCTAssertNil(slotObject["answer"])
        XCTAssertNil(slotObject["format"])
    }

    func testImageOptionDropsUndeliveredMediaAndDoesNotStoreCorrect() throws {
        let fact = try readyImage(#"""
        {"options":[
          {"id":"o1","label":"张医生","img":"https://cdn.example.test/a.png","alt":"张医生","correct":true,"fb":"secret"},
          {"id":"o2","label":"李师傅","img":"media-asset:9","alt":"李师傅"},
          {"id":"o3","label":"周老板","img":"http://cdn.example.test/c.png","alt":"周老板"},
          {"id":"o4","label":"无图"}
        ]}
        """#)
        XCTAssertEqual(fact.options[0].imageURL, "https://cdn.example.test/a.png")
        XCTAssertEqual(fact.options[0].alt, "张医生")
        XCTAssertTrue(fact.options[0].submitsOptionID)
        XCTAssertTrue(fact.options[1].textOnly)
        XCTAssertTrue(fact.options[2].textOnly)
        XCTAssertNil(fact.options[3].imageURL)
        XCTAssertFalse(fact.storesCorrect)
        XCTAssertFalse(fact.storesFeedback)
        let flat = strings(in: fact)
        XCTAssertFalse(flat.contains("secret"))
        XCTAssertFalse(flat.contains("media-asset:9"))
        XCTAssertFalse(flat.contains { $0.hasPrefix("http://") })
    }

    func testAccusationIsNotPublishableAndDropsSecrets() throws {
        XCTAssertEqual(UGAccusation.decodePublic(data: envelope(#"{"enabled":true,"winScreen":"你指认了李师傅","suspects":[]}"#), status: 200), .unknown)
        let fact = try readyAccusation(#"""
        {"enabled":true,"suspects":[
          {"id":"o1","name":"张医生","identity":"诊所医生","avatar":"/profile/a.png","testimony":[{"key":"clue.a","text":"已获得"}]},
          {"id":"o2","name":"李师傅","avatar":"media-asset:4"}
        ],"introScreens":[{"text":"把线索钉上板子"}],"corkboardImage":{"img":"/profile/board.png","alt":"线索板"},"earlyAccuse":{"allowed":false}}
        """#)
        XCTAssertFalse(fact.publishable)
        XCTAssertEqual(fact.authorStatus, "待运行验证")
        XCTAssertFalse(fact.selectingConsumesChance)
        XCTAssertFalse(fact.countsAttemptsLocally)
        XCTAssertFalse(fact.showsRecordAs)
        XCTAssertEqual(fact.earlyAllowed, Optional(false))
        XCTAssertEqual(fact.suspects[0].testimony.map(\.text), ["已获得"])
        XCTAssertNil(fact.suspects[1].avatarURL)
        XCTAssertEqual(fact.introScreens.count, 1)
        let screen = try JSONDecoder().decode(PlayWireValue.self, from: Data(fact.introScreens[0].utf8))
        XCTAssertEqual(screen["text"].text, "把线索钉上板子")
        XCTAssertFalse(strings(in: fact).contains("media-asset:4"))
        let missingEarly = try readyAccusation(#"{"enabled":true,"suspects":[{"id":"o1","name":"张医生"},{"id":"o2","name":"李师傅"}]}"#)
        XCTAssertNil(missingEarly.earlyAllowed)
    }

    func testEarlyCloseIsNotFailureAndUnreadableProgressIsPending() throws {
        let early = try readyOutcome(#"""
        {"verdict":"CORRECT","correct":true,"early":true,"recordAs":"EARLY_CLOSED","recordCode":"EARLY_CLOSED","winScreen":"证据还没齐"}
        """#)
        XCTAssertEqual(early.label, Optional(UGAccusationOutcome.Label.early))
        XCTAssertEqual(early.endingCopy, "证据还没齐")
        XCTAssertFalse(early.isFailure)
        XCTAssertFalse(early.isSuccessfulAccusation)
        XCTAssertFalse(early.grantsSuccessReward)
        XCTAssertFalse(early.showsRecordAs)
        XCTAssertFalse(strings(in: early).contains("EARLY_CLOSED"))
        let pending = try readyOutcome(#"{"verdict":"FAILED","loseScreen":"这次指认没能说服任何人"}"#)
        XCTAssertEqual(pending.label, Optional(UGAccusationOutcome.Label.progressPending))
        XCTAssertNil(pending.endingCopy)
        XCTAssertFalse(pending.isFailure)
        XCTAssertFalse(strings(in: pending).contains("这次指认没能说服任何人"))
        let failed = try readyOutcome(#"{"verdict":"FAILED","early":false,"loseScreen":"指认不对"}"#)
        XCTAssertEqual(failed.label, Optional(UGAccusationOutcome.Label.failed))
        XCTAssertTrue(failed.isFailure)
        XCTAssertEqual(failed.endingCopy, "指认不对")
        let normal = try readyOutcome(#"{"verdict":"CORRECT","early":false,"winScreen":"证据链成立"}"#)
        XCTAssertEqual(normal.label, Optional(UGAccusationOutcome.Label.normal))
        XCTAssertTrue(normal.isSuccessfulAccusation)
        XCTAssertTrue(normal.grantsSuccessReward)
        let refused = try readyOutcome(#"{"verdict":"REFUSED","early":false,"refuseCode":"ACCUSATION_EARLY_NOT_ALLOWED"}"#)
        XCTAssertEqual(refused.consumesChance, Optional(false))
        XCTAssertNil(refused.label)
        XCTAssertFalse(refused.isFailure)
        XCTAssertFalse(refused.showsInternalCode)
        XCTAssertFalse(strings(in: refused).contains("ACCUSATION_EARLY_NOT_ALLOWED"))
        let settlement = try readyOutcome(#"{"early":false}"#)
        XCTAssertEqual(settlement.label, Optional(UGAccusationOutcome.Label.settlementPending))
        XCTAssertNil(settlement.endingCopy)
    }

    func testHelpLadderKeepsLegacyAndRejectsUnknownTypesGemsAndSkipControl() throws {
        let legacy = try readyHelp(#"{"runId":1,"nodeId":2,"enabled":false,"layers":[]}"#)
        XCTAssertTrue(legacy.keepsLegacyHintChain)
        XCTAssertTrue(legacy.layers.isEmpty)
        let view = try readyHelp(#"""
        {"runId":9,"nodeId":3,"enabled":true,"remainingFreeUses":"UNKNOWN","layers":[
          {"level":1,"type":"TEXT","usable":true,"unlocked":false,"free":true,"costPoints":0,"freeQuota":0,"reason":null},
          {"level":2,"type":"AUDIO","usable":true,"unlocked":false,"free":false,"costPoints":10,"freeQuota":3,"reason":"HELP_TYPE_UNSUPPORTED"},
          {"level":3,"type":"LOCATION","usable":true,"unlocked":false,"free":false,"costPoints":0,"freeQuota":0,"reason":null},
          {"level":4,"type":"SKIP","usable":true,"unlocked":false,"free":false,"costPoints":0,"freeQuota":0,"reason":null},
          {"level":5,"type":"TEXT","usable":true,"unlocked":false,"free":false,"costPoints":10,"freeQuota":0,"reason":null,"cost":{"gems":2,"coins":1,"points":10}}
        ]}
        """#)
        XCTAssertFalse(view.keepsLegacyHintChain)
        XCTAssertNil(view.remainingFreeUses.literal)
        XCTAssertNil(view.renderedRemaining(capability: UGCapability(granted: [.freeQuota])))
        XCTAssertEqual(view.layers[0].playerLine, "免费")
        XCTAssertTrue(view.layers[0].available)
        XCTAssertFalse(view.layers[1].available)
        XCTAssertNil(view.layers[1].renderedPerLayerFreeQuota)
        XCTAssertEqual(view.layers[1].freeQuota.literal, 3)
        XCTAssertFalse(view.layers[1].showsPerLayerFreeCount)
        XCTAssertFalse(view.layers[2].available)
        XCTAssertEqual(view.layers[3].serverUsable, Optional(true))
        XCTAssertFalse(view.layers[3].available)
        XCTAssertFalse(view.layers[3].offersSkipButton)
        XCTAssertFalse(UGGameplay.offersSkipButton)
        XCTAssertTrue(view.layers[4].currencyRejected)
        XCTAssertFalse(view.layers[4].available)
        XCTAssertFalse(view.recordsGemBalance)
        XCTAssertFalse(strings(in: view.layers[4]).contains("2"))
        let priced = try readyHelp(#"""
        {"runId":1,"nodeId":1,"enabled":true,"remainingFreeUses":0,"layers":[
          {"level":1,"type":"TEXT","usable":true,"unlocked":true,"free":true,"costPoints":0,"freeQuota":0,"reason":null},
          {"level":2,"type":"IMAGE","usable":true,"unlocked":false,"free":false,"costPoints":20,"freeQuota":0,"reason":null}
        ]}
        """#)
        XCTAssertEqual(priced.remainingFreeUses.literal, 0)
        XCTAssertEqual(priced.renderedRemaining(capability: UGCapability(granted: [.freeQuota])), 0)
        XCTAssertNil(priced.renderedRemaining(capability: .none))
        XCTAssertEqual(priced.layers[0].playerLine, "重看·免费")
        XCTAssertFalse(priced.layers[0].serverMarksFirstUnlockFree)
        XCTAssertEqual(priced.layers[1].playerLine, "消耗 20 积分")
        XCTAssertTrue(priced.layers[1].spendsPointsOnFirstUnlock)
        XCTAssertFalse(priced.layers[1].serverMarksFirstUnlockFree)
        let missingCounter = try readyHelp(#"""
        {"runId":1,"nodeId":1,"enabled":true,"layers":[
          {"level":1,"type":"TEXT","usable":true,"unlocked":false,"free":true,"costPoints":0,"freeQuota":0,"reason":null}
        ]}
        """#)
        XCTAssertNil(missingCounter.remainingFreeUses.literal)
        XCTAssertNotEqual(missingCounter.remainingFreeUses.literal, 0)
        let authorFree = try readyHelp(#"""
        {"runId":1,"nodeId":1,"enabled":true,"layers":[
          {"level":1,"type":"TEXT","usable":true,"unlocked":false,"free":false,"costPoints":0,"freeQuota":0,"reason":null},
          {"level":2,"type":"TEXT","usable":true,"unlocked":false,"free":true,"costPoints":0,"freeQuota":0,"reason":null}
        ]}
        """#)
        XCTAssertEqual(authorFree.layers[0].playerLine, "消耗 0 积分")
        XCTAssertFalse(authorFree.layers[0].serverMarksFirstUnlockFree)
        XCTAssertEqual(authorFree.layers[0].costPoints.literal, 0)
        XCTAssertEqual(authorFree.layers[1].playerLine, "免费")
        XCTAssertFalse(authorFree.layers[1].blockedUntilPrevious)
        XCTAssertTrue(authorFree.layers[1].available)
        XCTAssertTrue(authorFree.layers[1].serverMarksFirstUnlockFree)
        XCTAssertFalse(authorFree.decrementsQuotaLocally)
        XCTAssertEqual(UGHelpView.unavailableCopy, "提示暂不可用")
        let zeroCurrency = try readyHelp(#"""
        {"runId":1,"nodeId":1,"enabled":true,"layers":[
          {"level":1,"type":"TEXT","usable":true,"unlocked":false,"free":true,"costPoints":0,"freeQuota":0,"reason":null,"cost":{"gems":0,"coins":0,"points":0}}
        ]}
        """#)
        XCTAssertFalse(zeroCurrency.layers[0].currencyRejected)
        XCTAssertTrue(zeroCurrency.layers[0].available)
    }

    func testHelpUseDoesNotSliceOrOpenAWallet() throws {
        let digit = try readyUse(#"""
        {"runId":1,"nodeId":2,"level":4,"type":"DIGIT","content":"12","applied":true,"alreadyUnlocked":false,"chargedPoints":0,"balanceAfter":"UNKNOWN"}
        """#)
        XCTAssertNil(digit.content)
        XCTAssertEqual(digit.chargedPoints.literal, 0)
        XCTAssertNil(digit.balanceAfter.literal)
        XCTAssertFalse(digit.recordsGemBalance)
        XCTAssertFalse(digit.hasReplayedField)
        XCTAssertFalse(digit.cutsAnswerLocally)
        XCTAssertFalse(digit.offersSkipButton)
        let letter = try readyUse(#"""
        {"runId":1,"nodeId":2,"level":3,"type":"LETTER","content":"N","applied":true,"alreadyUnlocked":false,"chargedPoints":0,"balanceAfter":8}
        """#)
        XCTAssertEqual(letter.content, "N")
        let blocked = try readyUse(#"""
        {"runId":1,"nodeId":2,"level":1,"type":"TEXT","content":"secret hint","reason":"POINTS_INSUFFICIENT","applied":false,"alreadyUnlocked":false,"chargedPoints":0,"balanceAfter":0}
        """#)
        XCTAssertNil(blocked.content)
        XCTAssertTrue(blocked.insufficient)
        XCTAssertEqual(UGHelpView.insufficientCopy, "积分不足，本层未解锁")
        XCTAssertEqual(UGHelp.decodeUse(data: envelope(#"{"runId":1,"nodeId":2,"level":1,"type":"TEXT","content":"x","applied":true,"alreadyUnlocked":true,"chargedPoints":0,"balanceAfter":1,"replayed":true}"#), status: 200), .unknown)
        let replay = UGHelpIdempotency.resend(UGHelpUseDraft(runID: 1, nodeID: 2, level: 3, requestID: "req-help-1", costPoints: 0),
                                             original: UGHelpUseDraft(runID: 1, nodeID: 2, level: 2, requestID: "req-help-1", costPoints: 10))
        XCTAssertEqual(replay, .conflict)
        XCTAssertNil(replay.replacementRequestID)
        XCTAssertEqual(replay.playerCopy, "请求内容已变化，请刷新后重试")
        XCTAssertEqual(UGHelpIdempotency.unknownCopy, "结果待确认")
    }

    func testRunQuotaDoesNotPreferRootOrTurnUnknownIntoZero() {
        XCTAssertEqual(UGRunQuota.read(data: Data(#"{"hintFreeUsesPerRun":2,"nodeConfigs":{"31":{"hintFreeUsesPerRun":2}}}"#.utf8)), .value(2))
        let conflict = UGRunQuota.read(data: Data(#"{"hintFreeUsesPerRun":2,"nodeConfigs":{"31":{"hintFreeUsesPerRun":3}}}"#.utf8))
        XCTAssertEqual(conflict, .conflict)
        XCTAssertNil(conflict.literal)
        XCTAssertEqual(conflict.conflictReason, "PLAY_HELP_RUN_QUOTA_DECLARED_CONFLICT")
        XCTAssertNotEqual(conflict.literal, 2)
        XCTAssertEqual(UGRunQuota.read(data: Data(#"{"nodeAnswers":{"31":{"hintLadder":[{"level":1,"type":"TEXT"}]}}}"#.utf8)), .value(0))
        XCTAssertEqual(UGRunQuota.read(data: Data(#"{"nodeConfigs":{"31":{"qa":{"enabled":true}}}}"#.utf8)), .legacyNull)
        XCTAssertEqual(UGRunQuota.read(data: Data(#"{"hintFreeUsesPerRun":0}"#.utf8)), .value(0))
        XCTAssertEqual(UGRunQuota.read(data: Data(#"{"hintLadder":[]}"#.utf8)), .legacyNull)
        XCTAssertEqual(UGRunQuota.read(data: Data(#"{"hintFreeUsesPerRun":"UNKNOWN"}"#.utf8)).invalidReason, "PLAY_HELP_RUN_QUOTA_CONFIG_INVALID")
        XCTAssertEqual(UGRunQuota.read(data: Data(#"{"hintFreeUsesPerRun":1001}"#.utf8)), .invalid)
        let nested = UGRunQuota.read(data: Data(#"{"nodeConfigs":{"31":{"hintFreeUsesPerRun":2}},"nodeAnswers":{"31":{"advancedConfigJson":"{\"hintFreeUsesPerRun\":2}"}}}"#.utf8))
        XCTAssertEqual(nested, .value(2))
    }

    func testHelpReceiptDoesNotRenderUnknownOrNotScoredAsZero() throws {
        let unscored = try readyReceipt(#"""
        {"scoreState":"NOT_SCORED","baseScore":null,"netScore":null,"pointsCharged":20,"skipped":false,"assisted":false,"reason":"NO_BASE_SCORE",
         "levels":[{"level":1,"type":"TEXT","free":true,"pointsCharged":20}]}
        """#)
        XCTAssertNil(unscored.renderedNetScore)
        XCTAssertNil(unscored.netScore.literal)
        XCTAssertEqual(unscored.notScoredCopy, "本题不计分")
        XCTAssertNotEqual(unscored.notScoredCopy, unscored.reason)
        XCTAssertEqual(unscored.pointsCharged.literal, 20)
        XCTAssertFalse(unscored.pointsEnterNetScore)
        XCTAssertFalse(unscored.claimsGlobalRank)
        XCTAssertFalse(unscored.didComputeNet)
        let zeroHidden = try readyReceipt(#"{"scoreState":"NOT_SCORED","netScore":0,"pointsCharged":"UNKNOWN","skipped":true,"assisted":true}"#)
        XCTAssertNil(zeroHidden.renderedNetScore)
        XCTAssertEqual(zeroHidden.netScore.literal, 0)
        XCTAssertNil(zeroHidden.pointsCharged.literal)
        XCTAssertNil(zeroHidden.skipPhrase)
        XCTAssertEqual(zeroHidden.skippedLabel, "已跳过")
        let skipped = try readyReceipt(#"""
        {"scoreState":"SCORED","baseScore":100,"bonus":0,"helpDeduction":0,"skipDeduction":100,"netScore":0,"pointsCharged":5,"skipped":true,"assisted":true,"levels":[]}
        """#)
        XCTAssertEqual(skipped.renderedNetScore, 0)
        XCTAssertEqual(skipped.skipPhrase, "本题跳过 · 记 0 分 · 辅助完成")
        XCTAssertNil(skipped.revealPhrase)
        XCTAssertFalse(skipped.revealIsSkip)
        XCTAssertFalse(skipped.offersSkipButton)
        XCTAssertFalse(skipped.didSynthesizeZeroRow)
        let revealed = try readyReceipt(#"{"scoreState":"SCORED","netScore":40,"pointsCharged":0,"skipped":false,"assisted":true,"levels":[]}"#)
        XCTAssertEqual(revealed.revealPhrase, "揭示答案，未自行解出")
        XCTAssertFalse(revealed.revealIsSkip)
        XCTAssertNil(revealed.skipPhrase)
        let missing = try readyReceipt(#"{"scoreState":"SCORED","netScore":"UNKNOWN","pointsCharged":null}"#)
        XCTAssertNil(missing.renderedNetScore)
        XCTAssertNil(missing.pointsCharged.literal)
        XCTAssertTrue(missing.detailMissing)
        XCTAssertNil(missing.levels)
        XCTAssertEqual(missing.detailMissingCopy, "明细待补")
        XCTAssertFalse(missing.didSynthesizeZeroRow)
        XCTAssertEqual(UGHelpReceiptFact.unavailableCopy, "结算明细暂不可用")
    }

    func testReceiptUnknownStaysPendingAndScopeChangeDiscards() {
        let pending = UGActionReceiptClassifier.classify(data: envelope("{}"), status: 200, scopeMatches: true)
        XCTAssertEqual(pending.disposition, .pendingConfirmation)
        XCTAssertEqual(pending.pendingCopy, "待确认")
        XCTAssertFalse(pending.isFailure)
        XCTAssertFalse(pending.allowsNewActionID)
        XCTAssertTrue(pending.keepsRequestID)
        XCTAssertTrue(pending.checksOriginalReceipt)
        let held = UGActionReceiptClassifier.classify(data: Data(#"{"receiptState":"PENDING"}"#.utf8), status: 520, scopeMatches: true)
        XCTAssertEqual(held.disposition, .pendingConfirmation)
        XCTAssertFalse(held.isFailure)
        let terminal = UGActionReceiptClassifier.classify(data: envelope(#"{"intentTerminal":true}"#), status: 200, scopeMatches: true)
        XCTAssertEqual(terminal.disposition, .terminal)
        XCTAssertFalse(terminal.allowsNewActionID)
        let replace = UGActionReceiptClassifier.classify(data: envelope(#"{"newActionIdRequired":true}"#), status: 200, scopeMatches: true)
        XCTAssertEqual(replace.disposition, .terminal)
        XCTAssertTrue(replace.allowsNewActionID)
        let failed = UGActionReceiptClassifier.classify(data: envelope(#"{"intentNotExecuted":true}"#), status: 200, scopeMatches: true)
        XCTAssertEqual(failed.disposition, .explicitFailure)
        XCTAssertTrue(failed.allowsNewActionID)
        XCTAssertTrue(failed.isFailure)
        let discarded = UGActionReceiptClassifier.classify(data: envelope(#"{"intentTerminal":true,"netScore":0}"#), status: 200, scopeMatches: false)
        XCTAssertEqual(discarded.disposition, .discarded)
        XCTAssertFalse(discarded.isFailure)
        let business = UGActionReceiptClassifier.classify(data: Data(#"{"code":500,"data":{"netScore":0}}"#.utf8), status: 200, scopeMatches: true)
        XCTAssertEqual(business.disposition, .explicitFailure)
        let same = UGActionReceiptClassifier.classify(data: envelope(#"{"intentTerminal":false,"intentNotExecuted":false,"retryable":true}"#), status: 200, scopeMatches: true)
        XCTAssertEqual(same.disposition, .retrySameRequest)
        XCTAssertFalse(same.allowsNewActionID)
        let refresh = UGActionReceiptClassifier.classify(data: envelope(#"{"intentTerminal":false,"intentNotExecuted":false,"refreshRequired":true}"#), status: 200, scopeMatches: true)
        XCTAssertEqual(refresh.disposition, .refreshRequired)
        XCTAssertFalse(refresh.allowsNewActionID)
        XCTAssertTrue(refresh.keepsRequestID)
        let heldUnknown = UGActionReceiptClassifier.classify(data: Data(#"{"receiptState":"UNKNOWN"}"#.utf8), status: 520, scopeMatches: true)
        XCTAssertEqual(heldUnknown.disposition, .pendingConfirmation)
        XCTAssertFalse(heldUnknown.isFailure)
    }

    func testClueTransformDoesNotReverseTwiceOrGuess() throws {
        let plain = try readyClue(#"{"question":"钟摆后面"}"#)
        XCTAssertEqual(plain.mode, .standard)
        XCTAssertEqual(plain.presentationName, "原样")
        XCTAssertEqual(plain.textLayerScaleX, 1)
        XCTAssertFalse(plain.includesClueTransformKey)
        XCTAssertFalse(plain.reversesAgain)
        XCTAssertFalse(plain.flipsPage)
        XCTAssertFalse(plain.usesMirrorImage)
        let mirror = try readyClue(#"{"question":"钟摆后面","clueTransform":{"mode":"MIRROR"}}"#)
        XCTAssertEqual(mirror.mode, .mirror)
        XCTAssertEqual(mirror.questionText, "钟摆后面")
        XCTAssertEqual(mirror.textLayerScaleX, -1)
        XCTAssertFalse(mirror.flipsControls)
        XCTAssertFalse(mirror.exposesOriginalToVoiceOver)
        let reversed = try readyClue(#"{"question":"CBA","clueTransform":{"mode":"REVERSE"}}"#)
        XCTAssertEqual(reversed.questionText, "CBA")
        XCTAssertEqual(reversed.textLayerScaleX, 1)
        XCTAssertFalse(reversed.reversesAgain)
        let cipher = try readyClue(#"{"question":"钟摆后面","clueTransform":{"mode":"CYPHER"}}"#)
        XCTAssertEqual(cipher.mode, .unrecognized)
        XCTAssertEqual(cipher.textLayerScaleX, 1)
        XCTAssertTrue(cipher.rejectedCipher)
        XCTAssertTrue(cipher.reportsUnrecognized)
        let unknown = try readyClue(#"{"question":"钟摆后面","clueTransform":{"mode":"ROT13"}}"#)
        XCTAssertEqual(unknown.mode, .unrecognized)
        XCTAssertEqual(unknown.questionText, "钟摆后面")
        let extra = try readyClue(#"{"question":"钟摆后面","clueTransform":{"mode":"MIRROR","shift":3}}"#)
        XCTAssertEqual(extra.textLayerScaleX, 1)
        XCTAssertTrue(extra.rejectedCipher)
    }

    func testAbsentCapabilityHidesTheFeatureAndUndeclaredDoesNotBlock() {
        let required = [
            UGRequiredCapability(key: "answer.text", minVersion: 1),
            UGRequiredCapability(key: "game.hangman", minVersion: 1),
            UGRequiredCapability(key: "game.qa", minVersion: 1),
            UGRequiredCapability(key: "media.image", minVersion: 1)
        ]
        let supported = UGCompatibility.evaluate(required: required, supportedCapabilities: "answer.text@1,game.hangman@1,game.qa@1,media.image@1,extra.unknown@9")
        XCTAssertEqual(supported, UGCompatibility(declared: true, supported: true, source: "DECLARED", missingKeys: []))
        let missing = UGCompatibility.evaluate(required: required, supportedCapabilities: "answer.text@1")
        XCTAssertEqual(missing.supported, false)
        XCTAssertEqual(missing.missingKeys, ["game.hangman", "game.qa", "media.image"])
        let undeclared = UGCompatibility.evaluate(required: required, supportedCapabilities: "")
        XCTAssertNil(undeclared.supported)
        XCTAssertEqual(undeclared.source, "UNDECLARED")
        XCTAssertEqual(UGCompatibility.evaluate(required: required, supportedCapabilities: "media.image@x").source, "MALFORMED")
        let mixed = UGCompatibility.evaluate(required: required, supportedCapabilities: "answer.text@1,media.image@x")
        XCTAssertEqual(mixed.source, "DECLARED_MALFORMED")
        XCTAssertEqual(mixed.missingKeys, ["game.hangman", "game.qa", "media.image"])
        let granted = UGCapability(granted: [.hangman], supportedServerKeys: ["game.hangman"])
        XCTAssertFalse(UGVisibility.shown(.hangman, capability: .none, compatibility: supported))
        XCTAssertFalse(UGVisibility.shown(.hangman, capability: UGCapability(granted: [.hangman]), compatibility: supported))
        XCTAssertFalse(UGVisibility.shown(.hangman, capability: granted, compatibility: missing))
        XCTAssertTrue(UGVisibility.shown(.hangman, capability: granted, compatibility: undeclared))
        XCTAssertTrue(UGVisibility.shown(.hangman, capability: granted, compatibility: nil))
        let decoded = UGHangman.decodeProjection(data: Data(#"{"code":200,"data":{"length":1,"blankCount":1,"caseSensitive":false,"solved":false,"display":"_","slots":[{"i":0,"kind":"BLANK"}]}}"#.utf8), status: 200)
        let hidden = UGGate.presentation(feature: .hangman, capability: .none, compatibility: nil, fact: decoded)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertFalse(UGVisibility.shown(.imageOption, capability: UGCapability(granted: [.imageOption]), compatibility: nil))
        XCTAssertTrue(UGVisibility.shown(.imageOption, capability: UGCapability(granted: [.imageOption], supportedServerKeys: ["media.image"]), compatibility: undeclared))
        XCTAssertFalse(UGVisibility.shown(.accusation, capability: UGCapability(granted: [.accusation], supportedServerKeys: ["game.qa"]), compatibility: missing))
        XCTAssertTrue(UGFeature.hintLadder.serverKeys.isEmpty)
        XCTAssertTrue(UGFeature.skip.serverKeys.isEmpty)
    }

    func testReaderRefusesProductionWritesAndAnAbsentGrant() async throws {
        let wire = Wire()
        let awaited = try await makeReader(wire, granted: []).help(runID: "9", nodeID: "3", token: "session-token", scope: try scope(), currentScope: { try? self.scope() }).phase
        XCTAssertEqual(awaited, nil)
        XCTAssertTrue(wire.requests.isEmpty)
        let reader = try makeReader(wire, granted: [.hintLadder, .helpReceipt])
        wire.body = envelope(#"{"runId":9,"nodeId":3,"enabled":false,"layers":[]}"#)
        let session = try scope()
        let help = try await reader.help(runID: "9", nodeID: "3", token: "session-token", scope: session, currentScope: { session })
        guard case .ready(let view)? = help.phase else { return XCTFail("expected help") }
        XCTAssertTrue(view.keepsLegacyHintChain)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/play/help")
        XCTAssertTrue(wire.requests[0].url?.query?.contains("runId=9") == true)
        XCTAssertTrue(wire.requests[0].url?.query?.contains("nodeId=3") == true)
        wire.body = envelope(#"{"scoreState":"NOT_SCORED","netScore":null,"pointsCharged":0,"levels":[]}"#)
        let receipt = try await reader.receipt(runID: "9", nodeID: "3", token: "session-token", scope: session, currentScope: { session })
        guard case .ready(let row)? = receipt.phase else { return XCTFail("expected receipt") }
        XCTAssertNil(row.renderedNetScore)
        XCTAssertEqual(wire.requests[1].url?.path, "/api/play/help/receipt")
        let advanced = try await reader.advancedReceipt(sessionID: "4", nodeID: "3", token: "session-token", scope: session, currentScope: { session })
        XCTAssertEqual(advanced.phase == nil, false)
        XCTAssertEqual(wire.requests[2].url?.path, "/api/play/help/advanced/receipt")
        XCTAssertTrue(wire.requests[2].url?.query?.contains("sessionId=4") == true)
        XCTAssertThrowsError(try reader.skip(runID: "9", nodeID: "3", requestID: "req-1", token: "session-token")) {
            XCTAssertEqual($0 as? UGRefusal, .writesNotAvailable)
        }
        XCTAssertThrowsError(try reader.useHelp(runID: "9", nodeID: "3", level: 1, requestID: "req-1", token: "session-token"))
        XCTAssertThrowsError(try reader.submitAccusation(requestID: "req-1", token: "session-token")) {
            XCTAssertEqual($0 as? UGRefusal, .writesNotAvailable)
        }
        XCTAssertEqual(wire.requests.count, 3)
        XCTAssertThrowsError(try UGSessionScope(accountID: 0, epoch: 1, namespace: "cn"))
        for host in ["https://api.chengyinhub.cn", "https://www.chengyinhub.com", "https://47.103.124.64"] {
            XCTAssertThrowsError(try makeReader(wire, granted: [.hintLadder], url: host))
        }
        XCTAssertThrowsError(try makeReader(wire, granted: [.hintLadder], endpoint: .production)) {
            XCTAssertEqual($0 as? UGRefusal, .productionEndpoint)
        }
    }

    func testHangmanSubmitPostsTheAdvancedActionAndKeepsAnUnknownRequestID() async throws {
        let wire = Wire()
        let locked = try makeReader(wire, granted: [])
        do {
            _ = try await locked.submitHangman(sessionID: "501", version: 1, requestID: "req-1", slots: ["1": "N"], token: "session-token")
            XCTFail("hangman without a grant must not be sent")
        } catch { XCTAssertEqual(error as? UGRefusal, .writesNotAvailable) }
        XCTAssertTrue(wire.requests.isEmpty)
        let reader = try makeReader(wire, granted: [.hangman])
        do {
            _ = try await reader.submitHangman(sessionID: "0", version: 1, requestID: "req-1", slots: ["1": "N"], token: "session-token")
            XCTFail("a leading-zero session must not be sent")
        } catch { XCTAssertEqual(error as? UGRefusal, .invalidRequest) }
        XCTAssertTrue(wire.requests.isEmpty)
        wire.body = envelope(#"{"sessionId":501,"version":2,"status":"RUNNING"}"#)
        let accepted = try await reader.submitHangman(sessionID: "501", version: 1, requestID: "req-1", slots: ["1": "N"], token: "session-token")
        XCTAssertEqual(accepted, .accepted(requestID: "req-1"))
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/play/advanced/action")
        let body = try JSONDecoder().decode(PlayWireValue.self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body["action"], .string("SUBMIT_HANGMAN"))
        XCTAssertEqual(body["idempotencyKey"], .string("req-1"))
        XCTAssertEqual(body["sessionId"], .int(501))
        XCTAssertEqual(body["payload"]["slots"]["1"], .string("N"))
        XCTAssertEqual(body["payload"]["answer"], .null)
        XCTAssertEqual(body["amount"], .null)
        wire.status = 500
        let unknown = try await reader.submitHangman(sessionID: "501", version: 1, requestID: "req-1", slots: ["1": "N"], token: "session-token")
        XCTAssertEqual(unknown, .unknown(requestID: "req-1"))
        wire.status = 200
        wire.body = Data(#"{"code":400,"msg":"no"}"#.utf8)
        let failed = try await reader.submitHangman(sessionID: "501", version: 1, requestID: "req-1", slots: ["1": "N"], token: "session-token")
        XCTAssertEqual(failed, .failed)
        XCTAssertNil(failed.requestID)
        wire.failure = URLError(.timedOut)
        let dropped = try await reader.submitHangman(sessionID: "501", version: 1, requestID: "req-keep", slots: ["1": "N"], token: "session-token")
        XCTAssertEqual(dropped, .unknown(requestID: "req-keep"))
    }

    func testHangmanDropsPrivateKeysAndKeepsASeparator() throws {
        XCTAssertEqual(UGHangman.decodeProjection(data: envelope(#"{"aliases":["ENDLESS"],"length":7,"blankCount":5,"caseSensitive":false,"solved":false,"display":"E_____S","slots":[]}"#), status: 200), .unknown)
        XCTAssertEqual(UGHangman.decodeProjection(data: envelope(#"{"format":"A","length":7,"blankCount":5,"caseSensitive":false,"solved":false,"display":"E_____S","slots":[]}"#), status: 200), .unknown)
        XCTAssertEqual(UGHangman.decodeProjection(data: envelope(#"{"length":7,"blankCount":5,"solved":false,"display":"E_____S","slots":[]}"#), status: 200), .unknown)
        let slots = try readyHangman(UGHangman.decodeProjection, #"""
        {"length":3,"blankCount":1,"caseSensitive":false,"solved":false,"display":"-A_","slots":[
          {"i":0,"kind":"SEPARATOR","ch":"-"},{"i":1,"kind":"FILLED","ch":"A"},{"i":2,"kind":"BLANK","ch":"Z"}]}
        """#)
        XCTAssertEqual(slots.slots[0].kind, "SEPARATOR")
        XCTAssertEqual(slots.slots[0].character, "-")
        XCTAssertEqual(slots.slots[1].character, "A")
        XCTAssertNil(slots.slots[2].character)
        XCTAssertFalse(strings(in: slots).contains("Z"))
        XCTAssertEqual(UGHangman.decodeResult(data: envelope(#"{"verdict":"CORRECT","solved":false,"display":"ENDLESS","answerText":"ENDLESS"}"#), status: 200), .unknown)
        XCTAssertEqual(UGHangman.decodeResult(data: envelope(#"{"verdict":"WRONG","solved":true,"display":"ENDLESS"}"#), status: 200), .unknown)
        let bare = try readyHangman(UGHangman.decodeResult, #"{"verdict":"CORRECT","solved":true,"display":"ENDLESS","answerText":"ENDLESS"}"#)
        XCTAssertEqual(bare.slots.count, 0)
        XCTAssertEqual(bare.answerText, "ENDLESS")
        XCTAssertFalse(bare.judgesLocally)
    }

    func testAnswerLayerStaysKnownAndALongDigitIsNotShown() throws {
        let view = try readyHelp(#"""
        {"runId":1,"nodeId":1,"enabled":true,"layers":[
          {"level":1,"type":"ANSWER","usable":true,"unlocked":false,"free":true,"costPoints":0,"freeQuota":0,"reason":null}
        ]}
        """#)
        XCTAssertTrue(view.layers[0].knownType)
        XCTAssertTrue(view.layers[0].available)
        XCTAssertEqual(view.layers[0].playerLine, "免费")
        XCTAssertFalse(view.layers[0].offersSkipButton)
        let answer = try readyUse(#"""
        {"runId":1,"nodeId":2,"level":5,"type":"ANSWER","content":"END","applied":true,"alreadyUnlocked":false,"chargedPoints":0,"balanceAfter":8}
        """#)
        XCTAssertEqual(answer.content, "END")
        XCTAssertFalse(answer.cutsAnswerLocally)
        let letter = try readyUse(#"""
        {"runId":1,"nodeId":2,"level":3,"type":"LETTER","content":"AB","applied":true,"alreadyUnlocked":false,"chargedPoints":0,"balanceAfter":8}
        """#)
        XCTAssertNil(letter.content)
        let skip = try readyUse(#"""
        {"runId":1,"nodeId":2,"level":1,"type":"SKIP","content":"skip me","applied":false,"alreadyUnlocked":false,"chargedPoints":0,"balanceAfter":8}
        """#)
        XCTAssertNil(skip.content)
        XCTAssertFalse(skip.offersSkipButton)
    }

    func testReceiptKeepsBonusSourceOffTheNet() throws {
        let fact = try readyReceipt(#"""
        {"scoreState":"SCORED","baseScore":10,"bonus":0,"bonusSource":"THEME","helpDeduction":0,"skipDeduction":0,"netScore":10,"pointsCharged":0,"skipped":false,"assisted":false,
         "levels":[{"level":1,"type":"ANSWER","free":true,"pointsCharged":0}]}
        """#)
        XCTAssertEqual(fact.bonusSource, "THEME")
        XCTAssertEqual(fact.bonus.literal, 0)
        XCTAssertEqual(fact.renderedNetScore, 10)
        XCTAssertFalse(fact.didComputeNet)
        XCTAssertEqual(fact.levels?.first?.type, "ANSWER")
        XCTAssertFalse(fact.claimsGlobalRank)
    }

    func testClueNamesStayLiteralAndFlipIsNotAMirror() throws {
        let standard = try readyClue(#"{"question":"钟摆后面","clueTransform":{"mode":"STANDARD"}}"#)
        XCTAssertEqual(standard.mode, .standard)
        XCTAssertEqual(standard.presentationName, "原样")
        XCTAssertTrue(standard.includesClueTransformKey)
        XCTAssertEqual(standard.textLayerScaleX, 1)
        XCTAssertFalse(standard.reportsUnrecognized)
        XCTAssertFalse(standard.reversesAgain)
        let flip = try readyClue(#"{"question":"钟摆后面","clueTransform":{"mode":"FLIP"}}"#)
        XCTAssertEqual(flip.mode, .unrecognized)
        XCTAssertTrue(flip.rejectedCipher)
        XCTAssertEqual(flip.presentationName, "原样")
        XCTAssertEqual(flip.textLayerScaleX, 1)
        XCTAssertFalse(flip.flipsPage)
        XCTAssertFalse(flip.usesMirrorImage)
        let absent = try readyClue(#"{"question":"钟摆后面","clueTransform":null}"#)
        XCTAssertEqual(absent.mode, .standard)
        XCTAssertFalse(absent.includesClueTransformKey)
        let mirror = try readyClue(#"{"question":"钟摆后面","clueTransform":{"mode":"MIRROR"}}"#)
        XCTAssertEqual(mirror.presentationName, "镜像")
        let reversed = try readyClue(#"{"question":"CBA","clueTransform":{"mode":"REVERSE"}}"#)
        XCTAssertEqual(reversed.presentationName, "倒序")
        XCTAssertEqual(reversed.questionText, "CBA")
        XCTAssertEqual(UGClueTransform.decode(data: envelope(#"{"question":1}"#), status: 200), .unknown)
    }

    func testAccusationDropsAnObjectScreenAndASecretSuspect() throws {
        let early = try readyOutcome(#"{"verdict":"CORRECT","early":true,"winScreen":{"text":"证据还没齐"}}"#)
        XCTAssertEqual(early.label, Optional(UGAccusationOutcome.Label.early))
        XCTAssertNil(early.endingCopy)
        XCTAssertFalse(early.isSuccessfulAccusation)
        XCTAssertFalse(strings(in: early).contains("证据还没齐"))
        let board = try readyAccusation(#"""
        {"enabled":true,"suspects":[{"id":"o1","name":"张医生"}],"corkboardImage":"https://cdn.example.test/board.png"}
        """#)
        XCTAssertEqual(board.corkboardURL, "https://cdn.example.test/board.png")
        XCTAssertNil(board.corkboardAlt)
        let hidden = try readyAccusation(#"""
        {"enabled":true,"suspects":[{"id":"o1","name":"张医生"}],"corkboardImage":"media-asset:1"}
        """#)
        XCTAssertNil(hidden.corkboardURL)
        XCTAssertEqual(UGAccusation.decodePublic(data: envelope(#"{"enabled":true,"correctSuspectId":"o1","suspects":[]}"#), status: 200), .unknown)
    }

    func testSameHelpRequestIsNotAConflict() {
        let draft = UGHelpUseDraft(runID: 1, nodeID: 2, level: 3, requestID: "req-help-1", costPoints: 0)
        let same = UGHelpIdempotency.resend(draft, original: draft)
        XCTAssertEqual(same, .same)
        XCTAssertNil(same.playerCopy)
        XCTAssertNil(same.replacementRequestID)
        let other = UGHelpIdempotency.resend(draft, original: UGHelpUseDraft(runID: 1, nodeID: 2, level: 3, requestID: "req-help-2", costPoints: 0))
        XCTAssertEqual(other, .differentRequest)
        XCTAssertNil(other.playerCopy)
    }

    func testFractionalNumbersStayUnknown() {
        XCTAssertNil(UGNumberFact.parse(.number(1.5)).literal)
        XCTAssertEqual(UGNumberFact.parse(.number(2)).literal, 2)
        XCTAssertNil(UGNumberFact.parse(.bool(false)).literal)
        XCTAssertNotEqual(UGNumberFact.parse(.number(1.5)).literal, 0)
    }

    func testReaderRejectsALeadingZeroAndDropsAStaleOrFailedRead() async throws {
        let wire = Wire()
        let reader = try makeReader(wire, granted: [.hintLadder])
        let session = try scope()
        for runID in ["0", "09", "1a", ""] {
            do {
                _ = try await reader.help(runID: runID, nodeID: "3", token: "session-token", scope: session, currentScope: { session })
                XCTFail(runID)
            } catch UGRefusal.invalidRequest {}
        }
        XCTAssertThrowsError(try UGSessionScope(accountID: 7, epoch: 1, namespace: ""))
        XCTAssertTrue(wire.requests.isEmpty)

        wire.body = envelope(#"{"runId":9,"nodeId":3,"enabled":false,"layers":[]}"#)
        var current = try scope()
        wire.onSend = { current = try! UGSessionScope(accountID: 8, epoch: 2, namespace: "cn") }
        let stale = try await reader.help(runID: "9", nodeID: "3", token: "session-token",
                                          scope: try UGSessionScope(accountID: 7, epoch: 1, namespace: "cn"),
                                          currentScope: { current })
        XCTAssertNil(stale.phase)
        XCTAssertTrue(stale.hidden)

        wire.onSend = {}
        wire.failure = TestFailure()
        let failed = try await reader.help(runID: "9", nodeID: "3", token: "session-token", scope: current, currentScope: { current })
        guard case .error(let error)? = failed.phase else { return XCTFail("expected error") }
        XCTAssertNil(error.httpStatus)
        XCTAssertNil(error.businessCode)
        XCTAssertFalse(failed.hidden)

        wire.failure = nil
        wire.status = 500
        wire.body = Data(#"{"code":500,"data":{"runId":0,"nodeId":0,"enabled":false,"layers":[]}}"#.utf8)
        let http = try await reader.help(runID: "9", nodeID: "3", token: "session-token", scope: current, currentScope: { current })
        guard case .error(let httpError)? = http.phase else { return XCTFail("expected http error") }
        XCTAssertEqual(httpError.httpStatus, 500)
        XCTAssertNil(httpError.message)
    }

    func testCoreSourcesCarryNoFixtureAnswerWalletOrLiveSession() throws {
        let root = try repoRoot()
        let sources = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Core"), includingPropertiesForKeys: nil)
            // `UGC*` (user-generated-content safety) shares the two-letter prefix but is not the UG gameplay feature.
            .filter { $0.lastPathComponent.hasPrefix("UG") && !$0.lastPathComponent.hasPrefix("UGC") && $0.pathExtension == "swift" }
        XCTAssertEqual(sources.map(\.lastPathComponent).sorted(), ["UGGameplay.swift", "UGGameplayReader.swift"])
        let banned = ["URLSession", "ENDLESS", "GemWallet", "offersSkipButton = true", "mock", "fixture"]
        for source in sources {
            let text = try String(contentsOf: source, encoding: .utf8)
            for token in banned {
                XCTAssertFalse(text.contains(token), "\(source.lastPathComponent) contains \(token)")
            }
        }
        let launch = try String(contentsOf: root.appendingPathComponent("App/RegionalLaunchConfiguration.swift"), encoding: .utf8)
        XCTAssertTrue(launch.contains("makeComposition(reviewed: nil, build: .current)"))
        let purchased = try String(contentsOf: root.appendingPathComponent("Core/WorkshopPurchasedContracts.swift"), encoding: .utf8)
        XCTAssertTrue(purchased.contains("permitsPurchase: Bool { false }"))
        XCTAssertTrue(purchased.contains("permitsContentUse: Bool { false }"))
    }

    private func readyHangman(_ decode: (Data, Int) -> UGServerFact<UGHangmanProjection>, _ json: String) throws -> UGHangmanProjection {
        guard case .ready(let value) = decode(envelope(json), 200) else { throw TestFailure() }
        return value
    }

    private func readyImage(_ json: String) throws -> UGImageOptionSet {
        guard case .ready(let value) = UGImageOption.decode(data: envelope(json), status: 200) else { throw TestFailure() }
        return value
    }

    private func readyAccusation(_ json: String) throws -> UGAccusationPublic {
        guard case .ready(let value) = UGAccusation.decodePublic(data: envelope(json), status: 200) else { throw TestFailure() }
        return value
    }

    private func readyOutcome(_ json: String) throws -> UGAccusationOutcome {
        guard case .ready(let value) = UGAccusation.decodeOutcome(data: envelope(json), status: 200) else { throw TestFailure() }
        return value
    }

    private func readyHelp(_ json: String) throws -> UGHelpView {
        guard case .ready(let value) = UGHelp.decodeView(data: envelope(json), status: 200) else { throw TestFailure() }
        return value
    }

    private func readyUse(_ json: String) throws -> UGHelpUseFact {
        guard case .ready(let value) = UGHelp.decodeUse(data: envelope(json), status: 200) else { throw TestFailure() }
        return value
    }

    private func readyReceipt(_ json: String) throws -> UGHelpReceiptFact {
        guard case .ready(let value) = UGHelpReceipt.decode(data: envelope(json), status: 200) else { throw TestFailure() }
        return value
    }

    private func readyClue(_ json: String) throws -> UGCluePresentation {
        guard case .ready(let value) = UGClueTransform.decode(data: envelope(json), status: 200) else { throw TestFailure() }
        return value
    }

    private func envelope(_ data: String) -> Data {
        Data(#"{"code":200,"msg":"ok","data":\#(data)}"#.utf8)
    }

    private func scope() throws -> UGSessionScope {
        try UGSessionScope(accountID: 7, epoch: 1, namespace: "cn")
    }

    private func makeReader(_ wire: Wire, granted: Set<UGFeature>, url: String = "https://example.test",
                            endpoint: UGGameplayReader.EndpointClass = .nonProduction) throws -> UGGameplayReader {
        try UGGameplayReader(configuration: APIConfiguration(baseURL: URL(string: url)!), transport: wire, endpointClass: endpoint,
                             capabilities: UGCapability(granted: granted))
    }

    private func repoRoot() throws -> URL {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let files = FileManager.default
        while !files.fileExists(atPath: root.appendingPathComponent("Core/UGGameplay.swift").path) {
            let parent = root.deletingLastPathComponent()
            if parent.path == root.path { throw TestFailure() }
            root = parent
        }
        return root
    }

    private func strings(in value: Any, depth: Int = 0) -> [String] {
        if depth > 8 { return [] }
        if let text = value as? String { return [text] }
        return Mirror(reflecting: value).children.flatMap { strings(in: $0.value, depth: depth + 1) }
    }

    private struct TestFailure: Error {}

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body = Data()
        var status = 200
        var failure: Error?
        var onSend: () -> Void = {}
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            onSend()
            if let failure { throw failure }
            return (body, status)
        }
    }
}
