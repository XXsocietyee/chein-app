import XCTest
@testable import QuestifyCore

/// CLB-G13a: `PlaySharedRunOps` against the MP `tests/unit/generic-director-ops.test.js` vectors
/// (pages/club/utils/generic-director-ops.js `genericOpsActions` / `genericOpsFields` / `genericOpsPayload`).
final class PlaySharedRunOpsTests: XCTestCase {
    private func control(_ actions: [String], epoch: Int = 2) -> PlayWireValue {
        .object(["revision": .integer(3), "run": .object(["authorityEpoch": .integer(Int64(epoch))]),
                 "availableActions": .array(actions.map(PlayWireValue.string))])
    }

    func testOfferedKeepsKnownActionsOnceAndDropsAttest() {
        XCTAssertEqual(PlaySharedRunOps.offered(control(["ACT_UNLOCK", "UNKNOWN", "MANUAL_SIGN", "ACT_UNLOCK"])), ["ACT_UNLOCK"])
        XCTAssertEqual(PlaySharedRunOps.offered(control(["STAFF_MANUAL_SIGN", "ARRIVAL_ATTEST"])), ["STAFF_MANUAL_SIGN"])
        XCTAssertEqual(PlaySharedRunOps.offered(control(["RUN_PAUSE"], epoch: 0)), [])
    }

    func testStaffManualSignNestsTheSignedCommand() throws {
        let draft = ["sequence": "1", "occurredAt": "1791577800000", "signedAction": "ARRIVAL_ATTEST", "teamId": "81",
                     "questKey": "quest.1", "reason": "纸质记录现场到达"]
        let payload = try PlaySharedRunOps.payload(action: "STAFF_MANUAL_SIGN", draft: draft, control: control(["STAFF_MANUAL_SIGN"]))
        XCTAssertEqual(payload["sequence"], .integer(1))
        XCTAssertEqual(payload["occurredAt"], .integer(1_791_577_800_000))
        XCTAssertEqual(payload["command"]?["action"], .string("ARRIVAL_ATTEST"))
        XCTAssertEqual(payload["command"]?["payload"], .object(["teamId": .integer(81), "questKey": .string("quest.1"), "reason": .string("纸质记录现场到达")]))
        XCTAssertNil(payload["originalRequestId"])
    }

    func testOriginalRevisionNeedsOriginalRequest() {
        let draft = ["sequence": "1", "occurredAt": "1791577800000", "signedAction": "ARRIVAL_ATTEST", "teamId": "81",
                     "questKey": "quest.1", "reason": "纸质记录", "originalExpectedRevision": "4"]
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "STAFF_MANUAL_SIGN", draft: draft, control: nil)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .originalPair)
        }
    }

    func testArrivalTargetIsQuestOrOperationNotBoth() throws {
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "ARRIVAL_REVOKE",
                                                          draft: ["teamId": "5", "questKey": "q", "operationKind": "PLAN", "reason": "r"], control: nil))
        let operation = try PlaySharedRunOps.payload(action: "ARRIVAL_REVOKE",
                                                     draft: ["teamId": "5", "operationKind": "PLAN", "operationKey": "p1", "reason": "撤销"], control: nil)
        XCTAssertEqual(operation, ["teamId": .integer(5), "operationKind": .string("PLAN"), "operationKey": .string("p1"), "reason": .string("撤销")])
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "ARRIVAL_CONFIRM", draft: ["teamId": "5", "questKey": "q", "nonce": "short"], control: nil)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .nonce)
        }
    }

    func testRunControlNeedsReasonAndActUnlockNeedsAct() throws {
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "RUN_PAUSE", draft: [:], control: nil)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .confirm("reason"))
        }
        XCTAssertEqual(try PlaySharedRunOps.payload(action: "RUN_PAUSE", draft: ["reason": " 暂停 "], control: nil), ["reason": .string("暂停")])
        XCTAssertEqual(try PlaySharedRunOps.payload(action: "ACT_UNLOCK", draft: ["actKey": "act2", "reason": "开放"], control: nil),
                       ["actKey": .string("act2"), "reason": .string("开放")])
    }

    func testManualBeginUsesExportHashesAndValidatesUnknownList() throws {
        let hash = String(repeating: "a", count: 64)
        let good = ["highWaterHash": hash, "configHash": hash, "reason": "断网",
                    "unknownRequests": #"[{"memberId":9,"requestId":"game_1","requestHash":"\#(hash)"}]"#]
        let payload = try PlaySharedRunOps.payload(action: "MANUAL_BEGIN", draft: good, control: control(["MANUAL_BEGIN"]))
        XCTAssertEqual(payload["unknownRequests"]?.array?.count, 1)
        XCTAssertNil(payload["offlineStartedAt"])
        var bad = good; bad["unknownRequests"] = #"[{"memberId":9}]"#
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "MANUAL_BEGIN", draft: bad, control: nil)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .unknownItems)
        }
    }

    func testManualReviewKinds() throws {
        XCTAssertEqual(try PlaySharedRunOps.payload(action: "MANUAL_REVIEW", draft: ["reviewKind": "HIGH_WATER", "reason": "看"], control: nil),
                       ["acceptCurrentHighWater": .bool(true), "reason": .string("看")])
        XCTAssertEqual(PlaySharedRunOps.fields(action: "MANUAL_REVIEW", draft: ["reviewKind": "REQUEST"]).map(\.key),
                       ["reviewKind", "memberId", "requestId", "acceptLateConflict", "reason"])
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "MANUAL_REVIEW", draft: ["reason": "x"], control: nil)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .reviewKind)
        }
    }

    func testCommandBodyAdmission() throws {
        let body: [String: Any] = ["activityId": 41, "nodeId": NSNull(), "expectedRevision": 3, "requestId": "req_12345678",
                                   "action": "RUN_PAUSE", "payload": ["reason": "x"]]
        XCTAssertTrue(PlaySharedRunOps.acceptsCommandBody(try JSONSerialization.data(withJSONObject: body)))
        var item = body; item["action"] = "ITEM_USE"
        XCTAssertFalse(PlaySharedRunOps.acceptsCommandBody(try JSONSerialization.data(withJSONObject: item)))
        var extra = body; extra["amount"] = 1
        XCTAssertFalse(PlaySharedRunOps.acceptsCommandBody(try JSONSerialization.data(withJSONObject: extra)))
    }

    // MARK: MP guideCases (tests/unit/generic-director-ops.test.js), plain and nested in STAFF_MANUAL_SIGN.

    private static let ab: PlayWireValue = .array([.object(["id": .string("a"), "label": .string("甲")]),
                                                    .object(["id": .string("b"), "label": .string("乙")])])
    private static let xy: PlayWireValue = .array([.object(["id": .string("x"), "label": .string("一")]),
                                                    .object(["id": .string("y"), "label": .string("二")])])

    private static let guideCases: [(String, [String: PlayWireValue], [String: String], [String: PlayWireValue])] = [
        ("basic text", ["basic": .object(["mode": .string("TYPE"), "options": .array([])])], ["guide_basic": "口令"], ["answer": .string("口令")]),
        ("basic pick", ["basic": .object(["mode": .string("PICK"), "options": .array([.object(["id": .string("A"), "label": .string("甲")]),
                                                                                       .object(["id": .string("B"), "label": .string("乙")])])])],
         ["guide_basic_0": "true", "guide_basic_1": "true"], ["answer": .string("AB")]),
        ("qa text", ["qa": .object(["mode": .string("TYPE"), "title": .string("口令"), "options": .array([])])], ["guide_qa": "口令"],
         ["qa": .object(["input": .string("口令")])]),
        ("qa pick", ["qa": .object(["mode": .string("PICK"), "title": .string("选择口令"), "options": ab])], ["guide_qa": "b"],
         ["qa": .object(["optionId": .string("b")])]),
        ("qa multi", ["qa": .object(["mode": .string("PICK"), "multi": .bool(true), "title": .string("选择口令"), "options": ab])],
         ["guide_qa_0": "true", "guide_qa_1": "true"], ["qa": .object(["optionIds": .array([.string("a"), .string("b")])])]),
        ("sort", ["sort": .object(["prompt": .string("排列"), "items": ab])], ["guide_sort_0": "b", "guide_sort_1": "a"],
         ["sort": .object(["order": .array([.string("b"), .string("a")])])]),
        ("match", ["match": .object(["prompt": .string("连线"), "left": ab, "right": xy])], ["guide_match_0": "y", "guide_match_1": "x"],
         ["match": .object(["pairs": .array([.array([.string("a"), .string("y")]), .array([.string("b"), .string("x")])])])]),
        ("classify", ["classify": .object(["prompt": .string("分类"), "items": ab, "bins": xy])], ["guide_classify_0": "x", "guide_classify_1": "x"],
         ["classify": .object(["placement": .object(["a": .string("x"), "b": .string("x")])])])
    ]

    func testGuideCasesBuildTheExactServerAnswers() throws {
        for (kind, questions, answersDraft, answers) in Self.guideCases {
            var task = questions
            task["questKey"] = .string("q1"); task["nodeId"] = .integer(11)
            let snapshot: PlayWireValue = .object(["guideTasks": .array([.object(task)])])
            let base = ["teamId": "81", "questKey": "q1", "reason": "记录队伍实际作答", "passed": "true", "answerKey": "forbidden"]
            let draft = base.merging(answersDraft) { _, new in new }
            let expected: PlayWireValue = .object(["teamId": .integer(81), "questKey": .string("q1"), "reason": .string("记录队伍实际作答"),
                                                   "answers": .object(answers)])
            XCTAssertEqual(PlayWireValue.object(try PlaySharedRunOps.payload(action: "QUEST_GUIDE", draft: draft, control: snapshot)), expected, kind)
            var signed = draft
            signed["signedAction"] = "QUEST_GUIDE"; signed["sequence"] = "1"; signed["occurredAt"] = "1791577800000"
            let nested = try PlaySharedRunOps.payload(action: "STAFF_MANUAL_SIGN", draft: signed, control: snapshot)
            XCTAssertEqual(nested["command"], .object(["action": .string("QUEST_GUIDE"), "payload": expected]), kind)
        }
    }

    func testGuideFormFieldsAndErrors() {
        let snapshot: PlayWireValue = .object(["guideTasks": .array([.object(["questKey": .string("quest.1"), "nodeId": .integer(11),
                                                                               "sort": .object(["items": Self.ab])])])])
        let fields = PlaySharedRunOps.fields(action: "QUEST_GUIDE", draft: ["questKey": "quest.1"], control: snapshot)
        XCTAssertEqual(fields.map(\.key), ["teamId", "questKey", "reason", "guide_sort_0", "guide_sort_1"])
        XCTAssertEqual(fields[1].options, ["quest.1"])
        XCTAssertEqual(fields[3].options, ["a", "b"])
        XCTAssertEqual(fields[3].optionLabels, ["甲", "乙"])
        XCTAssertEqual(fields[4].guide?.detail, .position(2))
        let draft = ["teamId": "81", "questKey": "quest.1", "reason": "指导", "guide_sort_0": "a", "guide_sort_1": "a"]
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "QUEST_GUIDE", draft: draft, control: snapshot)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .guideDuplicate)
        }
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "QUEST_GUIDE", draft: ["teamId": "81", "questKey": "quest.9", "reason": "指导"],
                                                          control: snapshot)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .guideTask)
        }
        XCTAssertThrowsError(try PlaySharedRunOps.payload(action: "QUEST_GUIDE", draft: ["teamId": "81", "questKey": "quest.1", "reason": "指导",
                                                                                          "guide_sort_0": "a", "guide_sort_1": "z"], control: snapshot)) {
            XCTAssertEqual($0 as? PlaySharedRunOps.Failure, .guideIncomplete)
        }
    }
}
