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
}
