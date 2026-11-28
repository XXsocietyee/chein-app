import XCTest
@testable import QuestifyCore

/// H8 UG-05…UG-09 player ladder, UG-02 picture options, UG-01 whole word, UG-11 author ladder.
@MainActor final class PlayHelpLadderTests: XCTestCase {
    private func wire(_ json: String) -> PlayWireValue { try! JSONDecoder().decode(PlayWireValue.self, from: Data(json.utf8)) }
    private func envelope(_ data: String, code: Int = 200) -> PlayHelpReply {
        PlayHelpReply.classify(data: Data(#"{"code":\#(code),"msg":"m","data":\#(data)}"#.utf8), status: 200)
    }
    private let identity = PlayHelpIdentity(owner: "owner", runID: 9, nodeID: 3)!
    private let view = #"{"runId":9,"nodeId":3,"enabled":true,"remainingFreeUses":2,"layers":[{"level":1,"type":"TEXT","usable":true,"unlocked":false,"free":true,"costPoints":5},{"level":2,"type":"IMAGE","usable":true,"unlocked":false,"free":false,"costPoints":10},{"level":3,"type":"LOCATION","usable":true,"unlocked":false,"free":false,"costPoints":1},{"level":4,"type":"SKIP","usable":true}]}"#

    func testProjectionFollowsServerLayers() {
        let projection = PlayHelpProjection.project(wire(view), identity: identity)
        XCTAssertTrue(projection.enabled)
        XCTAssertEqual(projection.rows.map(\.level), [1, 2, 3])
        XCTAssertEqual(projection.rows.map(\.state), [.free, .gated, .unavailable])
        XCTAssertEqual(projection.skipLevel, 4)
        XCTAssertEqual(projection.freeLeft, 2)
    }

    func testDisabledOrForeignViewKeepsLegacyEntries() {
        XCTAssertFalse(PlayHelpProjection.project(wire(#"{"enabled":false,"layers":[]}"#)).enabled)
        let other = PlayHelpProjection.project(wire(view.replacingOccurrences(of: #""runId":9"#, with: #""runId":8"#)), identity: identity)
        XCTAssertFalse(other.enabled)
    }

    func testMissingCounterIsNotZeroAndPriceZeroIsFree() {
        let raw = #"{"enabled":true,"layers":[{"level":1,"type":"TEXT","usable":true,"unlocked":false,"free":false,"costPoints":0}]}"#
        let projection = PlayHelpProjection.project(wire(raw))
        XCTAssertNil(projection.freeLeft)
        XCTAssertEqual(projection.rows.first?.state, .free)
    }

    func testOnlyFourHundredsAreRefusals() {
        XCTAssertEqual(PlayHelpReply.classify(data: Data(#"{"code":409,"msg":"x","reasonCode":"POINTS_INSUFFICIENT"}"#.utf8), status: 200),
                       .refused(code: 409, reason: "POINTS_INSUFFICIENT", message: "x"))
        XCTAssertEqual(PlayHelpReply.classify(data: Data(#"{"code":500,"msg":"x"}"#.utf8), status: 200), .retryable(message: "x"))
        XCTAssertEqual(PlayHelpReply.classify(data: Data(#"{"code":500}"#.utf8), status: 200), .unknown)
        XCTAssertEqual(PlayHelpReply.classify(data: Data(), status: 502), .unknown)
        XCTAssertEqual(PlayHelpReply.classify(data: Data(#"{"code":401}"#.utf8), status: 200), .unauthorized)
    }

    func testUnknownUseKeepsRequestIDAndResendsIt() async {
        var sent: [String] = []
        var replies: [PlayHelpReply] = [.unknown, envelope(#"{"level":1,"type":"TEXT","content":"看门楣","chargedPoints":0}"#)]
        let store = PlayHelpMemoryRequestStore()
        var counter = 0
        var unlocked = false
        // The re-read after a use is the authority for row state; this fake server reports the unlock.
        let client = PlayHelpClient(identity: identity,
            view: { self.envelope(unlocked ? self.view.replacingOccurrences(of: #""free":true,"costPoints":5"#, with: #""free":true,"costPoints":5,"unlocked":true"#)
                                                .replacingOccurrences(of: #""unlocked":false,"free":true"#, with: #""free":true"#) : self.view) },
            use: { _, id in sent.append(id); let reply = replies.removeFirst(); if case .ok = reply { unlocked = true }; return reply },
            skip: { _ in .unknown }, receipt: { .unknown })
        let model = PlayHelpLadderModel(client: client, store: store, makeRequestID: { counter += 1; return "req-\(counter)" })
        await model.load()
        await model.use(1)
        XCTAssertEqual(model.row(1)?.problem, .pending)
        XCTAssertFalse(model.row(1)?.needsConfirmation ?? true)
        await model.use(1)
        XCTAssertEqual(sent, ["req-1", "req-1"])
        XCTAssertEqual(model.row(1)?.state, .review)
        XCTAssertEqual(model.row(1)?.content, "看门楣")
        XCTAssertNil(store.requestID(for: identity.storageKey(.use, level: 1)))
    }

    func testInsufficientPointsRendersNoContent() async {
        let client = PlayHelpClient(identity: identity, view: { self.envelope(self.view) },
            use: { _, _ in PlayHelpReply.refused(code: 400, reason: "POINTS_INSUFFICIENT", message: nil) },
            skip: { _ in .unknown }, receipt: { .unknown })
        let model = PlayHelpLadderModel(client: client, store: PlayHelpMemoryRequestStore())
        await model.load()
        await model.use(1)
        XCTAssertEqual(model.row(1)?.problem, .insufficient)
        XCTAssertNil(model.row(1)?.content)
    }

    func testRetryableUseKeepsTheRequestAndShowsTheSentence() async {
        let store = PlayHelpMemoryRequestStore()
        let client = PlayHelpClient(identity: identity, view: { self.envelope(self.view) },
            use: { _, _ in .retryable(message: "积分服务忙") },
            skip: { _ in .retryable(message: "跳过未确认") }, receipt: { .unknown })
        let model = PlayHelpLadderModel(client: client, store: store)
        await model.load()
        await model.use(1)
        XCTAssertEqual(model.row(1)?.problem, .pendingNote("积分服务忙"))
        XCTAssertTrue(model.row(1)?.pending ?? false)
        XCTAssertNotNil(store.requestID(for: identity.storageKey(.use, level: 1)))
        await model.skip()
        XCTAssertTrue(model.skipPending)
        XCTAssertEqual(model.notice, .pendingNote("跳过未确认"))
    }

    func testLetterContentMustBeOneCharacter() {
        XCTAssertEqual(PlayHelpLadderModel.renderable(content: "E", type: "LETTER"), "E")
        XCTAssertNil(PlayHelpLadderModel.renderable(content: "ENDLESS", type: "LETTER"))
        XCTAssertNil(PlayHelpLadderModel.renderable(content: "x", type: "LOCATION"))
    }

    func testSkipSettlesOnlyOnServerFact() async {
        var skipped = false
        let receipt = #"{"skipped":true,"helpReceipt":{"scoreState":"SCORED","baseScore":100,"skipDeduction":100,"netScore":0,"pointsCharged":0,"skipped":true,"assisted":true,"levels":[]}}"#
        let client = PlayHelpClient(identity: identity, view: { self.envelope(self.view) }, use: { _, _ in .unknown },
            skip: { _ in self.envelope(receipt) }, receipt: { .unknown }, onSkipped: { skipped = true })
        let model = PlayHelpLadderModel(client: client, store: PlayHelpMemoryRequestStore())
        await model.load()
        await model.skip()
        XCTAssertTrue(model.skipped)
        XCTAssertTrue(skipped)
        XCTAssertEqual(model.receipt, [.skipped, .baseScore(100), .skipDeduction(100), .netScore(0)])
    }

    func testNotScoredReceiptNeverShowsZero() {
        let lines = PlayHelpReceiptLine.lines(wire(#"{"scoreState":"NOT_SCORED","baseScore":null,"netScore":null,"pointsCharged":20,"levels":[{"level":1,"type":"TEXT","free":false,"pointsCharged":20}]}"#))
        XCTAssertEqual(lines, [.notScored, .pointsCharged(20), .level(level: 1, type: "TEXT", free: false, points: 20)])
        XCTAssertEqual(PlayHelpReceiptLine.lines(wire(#"{"scoreState":"SCORED","netScore":70}"#)), [.netScore(70), .detailMissing])
    }

    func testPictureOptionsFallBackToText() {
        let segment = wire(#"{"options":[{"id":"a","label":"甲","img":"https://x.example/a.png","alt":"红门"},{"id":"b","label":"乙","img":"media-asset:9"}]}"#)
        let options = PlayKitImageOption.read(segment)
        XCTAssertEqual(options?.map(\.key), ["A", "B"])
        XCTAssertEqual(options?.first?.spokenDescription, "甲，红门")
        XCTAssertNil(options?.last?.image)
        XCTAssertNil(PlayKitImageOption.read(wire(#"{"options":[{"id":"a","label":"甲","img":"http://x/a.png"}]}"#)))
    }

    func testWholeWordPayloadPassesInputContract() throws {
        let segment = wire(#"{"title":"t","solved":false,"slots":[{"i":0,"kind":"PREFILLED","ch":"E"},{"i":1,"kind":"BLANK"}]}"#)
        let payload = try XCTUnwrap(PlayKitHangmanProjection.wholeWordPayload(" ENDLESS "))
        XCTAssertEqual(payload["input"], .string("ENDLESS"))
        XCTAssertNoThrow(try PlayKitInputContract.validate(kind: "hangman", action: "SUBMIT_HANGMAN", payload: payload, segment: segment))
        XCTAssertNil(PlayKitHangmanProjection.wholeWordPayload("   "))
    }

    func testAuthorLadderSavesRootKeysOnly() throws {
        var draft = TemplateAdvancedDraft()
        draft.setHintLadder(on: true)
        draft.setHintPayload(0, " 看门楣 ")
        draft.setHintPoints(0, "5")
        draft.addHintLayer()
        draft.setHintType(1, "SKIP")
        draft.setHintFreeUses("2")
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
        let raw = try draft.serialize()
        let saved = wire(raw)
        XCTAssertEqual(saved["hintFreeUsesPerRun"], .integer(2))
        XCTAssertEqual(saved["hintLadder"].array?.count, 2)
        XCTAssertEqual(saved["hintLadder"][0], wire(#"{"level":1,"type":"TEXT","payload":"看门楣","cost":{"points":5}}"#))
        XCTAssertEqual(saved["hintLadder"].array?[1], wire(#"{"level":2,"type":"SKIP"}"#))
        let reopened = try TemplateAdvancedDraft(raw: raw)
        XCTAssertEqual(reopened.hintLayers.map(\.type), ["TEXT", "SKIP"])
        XCTAssertEqual(reopened.hintFreeUsesText, "2")
    }

    func testAuthorLadderBlocksEmptyTextAndOffClearsQuota() {
        var draft = TemplateAdvancedDraft()
        draft.setHintLadder(on: true)
        XCTAssertTrue(draft.issues.contains("templateHint.validation.text"))
        draft.setHintFreeUses("1001")
        XCTAssertEqual(draft.hintQuotaIssue, "templateHint.validation.quota")
        draft.setHintLadder(on: false)
        XCTAssertNil(draft.value["hintFreeUsesPerRun"])
        XCTAssertTrue(draft.issues.isEmpty)
    }

    func testPoolTrimIsHiddenUntilTheGateIsOn() {
        let raw = #"{"enabled":true,"layers":[{"level":1,"type":"POOL_TRIM","usable":true,"unlocked":false,"free":true,"costPoints":0},{"level":2,"type":"ANSWER","usable":true,"unlocked":false,"free":false,"costPoints":0}]}"#
        let closed = PlayHelpProjection.project(wire(raw))
        XCTAssertFalse(closed.rows.contains { $0.type == "POOL_TRIM" })
        XCTAssertEqual(closed.rows.map(\.type), ["ANSWER"])
        let open = PlayHelpProjection.project(wire(raw), poolTrimEnabled: true)
        XCTAssertEqual(open.rows.map(\.type), ["POOL_TRIM", "ANSWER"])
        XCTAssertEqual(open.rows.first?.state, .free)
        XCTAssertTrue(PlayHelpProjection.renderable.contains("POOL_TRIM"))
    }

    func testPoolTrimUseSettlesWithoutHintTextAndBumpsTheGeneration() async {
        let view = #"{"runId":9,"nodeId":3,"enabled":true,"layers":[{"level":1,"type":"POOL_TRIM","usable":true,"unlocked":false,"free":true,"costPoints":0}]}"#
        let unlocked = view.replacingOccurrences(of: #""unlocked":false"#, with: #""unlocked":true"#)
        var seen = false
        let client = PlayHelpClient(identity: identity,
            view: { self.envelope(seen ? unlocked : view) },
            use: { _, _ in seen = true; return self.envelope(#"{"level":1,"type":"POOL_TRIM","applied":true}"#) },
            skip: { _ in .unknown }, receipt: { .unknown })
        let model = PlayHelpLadderModel(client: client, store: PlayHelpMemoryRequestStore(), poolTrimEnabled: true)
        await model.load()
        XCTAssertEqual(model.poolTrimGeneration, 0)
        await model.use(1)
        XCTAssertNil(model.row(1)?.problem)
        XCTAssertEqual(model.row(1)?.state, .review)
        XCTAssertEqual(model.poolTrimGeneration, 1)
    }

    func testWrongReplyStaysUnderAMissAndNoRightAnswerIsRecorded() throws {
        XCTAssertEqual(PlayKitWrongReply.text(segment: wire(#"{"attempts":1,"passed":false,"lastFeedback":"前两个字母对了"}"#)), "前两个字母对了")
        XCTAssertNil(PlayKitWrongReply.text(segment: wire(#"{"attempts":0,"lastFeedback":"x"}"#)))
        XCTAssertNil(PlayKitWrongReply.text(segment: wire(#"{"attempts":2,"passed":true,"lastFeedback":"x"}"#)))
        XCTAssertNil(PlayKitWrongReply.text(segment: wire(#"{"attempts":2,"finished":true,"passed":false,"lastFeedback":"已结束"}"#)))
        XCTAssertNil(PlayKitWrongReply.text(segment: wire(#"{"attempts":2,"passed":false,"lastFeedback":"  "}"#)))
        XCTAssertTrue(PlayKitNoRightAnswer.applies(kind: .qa, segment: wire(#"{"mode":"PICK","judge":false}"#)))
        XCTAssertFalse(PlayKitNoRightAnswer.applies(kind: .qa, segment: wire(#"{"mode":"PICK"}"#)))
        XCTAssertFalse(PlayKitNoRightAnswer.applies(kind: .qa, segment: wire(#"{"mode":"TYPE","judge":false}"#)))
        XCTAssertFalse(PlayKitNoRightAnswer.applies(kind: .branch, segment: wire(#"{"mode":"PICK","judge":false}"#)))
    }
}

private extension PlayWireValue {
    subscript(_ index: Int) -> PlayWireValue { array?[index] ?? .null }
}
