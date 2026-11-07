#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Encodes utils/coop-invite-request.js and parseInviteId from utils/coop-invite-view.js.
final class CoopInviteRequestRulesTests: XCTestCase {
    typealias C = CoopInviteRequestRules

    // MARK: ids
    func testParseInviteIDStringRules() {
        XCTAssertEqual(C.parseInviteID("0012"), "12")
        XCTAssertEqual(C.parseInviteID("9223372036854775807"), "9223372036854775807")
        XCTAssertNil(C.parseInviteID("9223372036854775808"))
        XCTAssertNil(C.parseInviteID("00000"))
        XCTAssertNil(C.parseInviteID(""))
        XCTAssertNil(C.parseInviteID("12a"))
        XCTAssertNil(C.parseInviteID("-3"))
        XCTAssertNil(C.parseInviteID(" 3"))
        XCTAssertNil(C.parseInviteID("١٢"), "non-ASCII digits are not ids")
        XCTAssertEqual(C.parseInviteID("0009223372036854775807"), "9223372036854775807")
    }

    func testParseInviteIDIntegerRules() {
        XCTAssertEqual(C.parseInviteID(5), "5")
        XCTAssertNil(C.parseInviteID(0))
        XCTAssertNil(C.parseInviteID(-1))
        XCTAssertEqual(C.parseInviteID(9_007_199_254_740_991), "9007199254740991")
        XCTAssertNil(C.parseInviteID(9_007_199_254_740_992), "above the JS safe-integer range a number is not an exact id")
    }

    func testExactIDRequiresCanonicalForm() {
        XCTAssertTrue(C.isExactID("12"))
        XCTAssertFalse(C.isExactID("012"))
        XCTAssertFalse(C.isExactID(""))
    }

    func testRequestIDAlphabetAndLength() {
        XCTAssertTrue(C.isValidRequestID("abc-DEF_123"))
        XCTAssertTrue(C.isValidRequestID(String(repeating: "a", count: 64)))
        XCTAssertFalse(C.isValidRequestID(String(repeating: "a", count: 65)))
        XCTAssertFalse(C.isValidRequestID(""))
        XCTAssertFalse(C.isValidRequestID("a b"))
        XCTAssertFalse(C.isValidRequestID("a/b"))
        XCTAssertFalse(C.isValidRequestID("编号"))
    }

    // MARK: context / key
    func testScopeIsMerchantOnlyForTypeZero() {
        XCTAssertEqual(C.context(inviteType: 0, topicID: "1", toType: "merchant", toID: "2", scope: "MERCHANT", supplyStationID: nil).scope, "MERCHANT")
        XCTAssertEqual(C.context(inviteType: 1, topicID: "1", toType: "club", toID: "2", scope: "MERCHANT", supplyStationID: nil).scope, "")
        XCTAssertEqual(C.context(inviteType: 0, topicID: "1", toType: "merchant", toID: "2", scope: "merchant", supplyStationID: nil).scope, "")
    }

    func testWriteKeyIsStablePerTargetAndMatchesSourceShape() {
        let a = C.context(inviteType: 0, topicID: "007", toType: "merchant", toID: "9", scope: "MERCHANT", supplyStationID: nil)
        XCTAssertEqual(C.writeKey(owner: "42", context: a), #"42:coop-invite:[0,"MERCHANT","7","9"]"#)
        let b = C.context(inviteType: 0, topicID: "7", toType: "merchant", toID: "9", scope: "MERCHANT", supplyStationID: "3")
        XCTAssertEqual(C.writeKey(owner: "42", context: b), #"42:coop-invite:[0,"MERCHANT","7","9","3"]"#)
        let club = C.context(inviteType: 1, topicID: "7", toType: "club", toID: "9", scope: nil, supplyStationID: nil)
        XCTAssertEqual(C.writeKey(owner: "42", context: club), #"42:coop-invite:[1,"","7","9"]"#)
        XCTAssertNotEqual(C.writeKey(owner: "43", context: club), C.writeKey(owner: "42", context: club))
    }

    func testInvalidIdsBecomeEmptyAndInvalidTypeBecomesNull() {
        let c = C.context(inviteType: nil, topicID: "x", toType: nil, toID: "y", scope: nil, supplyStationID: "z")
        XCTAssertEqual(C.writeKey(owner: "1", context: c), #"1:coop-invite:[null,"","","",""]"#)
    }

    // MARK: receipt
    private func created(_ overrides: [String: Any] = [:]) -> [String: Any] {
        var row: [String: Any] = ["state": "CREATED", "requestId": "req-1", "inviteId": "10", "inviteType": 0, "topicId": "7",
                                  "toType": "merchant", "toId": "9", "scope": "MERCHANT"]
        for (k, v) in overrides { row[k] = v }
        return row
    }

    func testCreatedReceiptValidates() {
        let r = C.receipt(created())
        XCTAssertEqual(r?.state, .created)
        XCTAssertEqual(r?.inviteID, "10")
        XCTAssertNil(r?.supplyStationID)
        XCTAssertEqual(C.receipt(created(["supplyStationId": "3"]))?.supplyStationID, "3")
        XCTAssertNil(C.receipt(created(["supplyStationId": NSNull()]))?.supplyStationID)
    }

    func testClubReceiptMustHaveClubTypeAndEmptyScope() {
        XCTAssertNotNil(C.receipt(created(["inviteType": 1, "toType": "club", "scope": ""])))
        XCTAssertNil(C.receipt(created(["inviteType": 1, "toType": "club", "scope": "MERCHANT"])))
        XCTAssertNil(C.receipt(created(["inviteType": 1, "toType": "merchant", "scope": ""])))
        XCTAssertNil(C.receipt(created(["inviteType": 0, "toType": "club"])))
        XCTAssertNil(C.receipt(created(["inviteType": 2])))
    }

    func testReceiptRejectsNonCanonicalIdsStationOnClubAndBadRequestId() {
        XCTAssertNil(C.receipt(created(["inviteId": "010"])))
        XCTAssertNil(C.receipt(created(["topicId": 7])), "ids must be strings")
        XCTAssertNil(C.receipt(created(["supplyStationId": "03"])))
        XCTAssertNil(C.receipt(created(["inviteType": 1, "toType": "club", "scope": "", "supplyStationId": "3"])))
        XCTAssertNil(C.receipt(created(["requestId": "bad id"])))
        XCTAssertNil(C.receipt(created(["scope": "OTHER"])))
        XCTAssertNil(C.receipt(created(["inviteType": true])))
        XCTAssertNil(C.receipt(nil))
    }

    func testNotFoundAndUnavailableReceiptsCarryNothingElse() {
        XCTAssertEqual(C.receipt(["state": "NOT_FOUND", "requestId": "r1"])?.state, .notFound)
        XCTAssertEqual(C.receipt(["state": "UNAVAILABLE", "requestId": "r1"])?.state, .unavailable)
        XCTAssertNil(C.receipt(["state": "NOT_FOUND", "requestId": "r1", "inviteId": "1"]))
        XCTAssertNil(C.receipt(["state": "WHATEVER", "requestId": "r1"]))
    }

    func testMatchesComparesEveryContextAxis() {
        let context = C.context(inviteType: 0, topicID: "7", toType: "merchant", toID: "9", scope: "MERCHANT", supplyStationID: nil)
        XCTAssertTrue(C.matches(C.receipt(created()), context: context))
        XCTAssertTrue(C.matches(C.receipt(created(["supplyStationId": "3"])), context: context), "station only compared when the context has one")
        XCTAssertFalse(C.matches(C.receipt(created(["topicId": "8"])), context: context))
        XCTAssertFalse(C.matches(C.receipt(created(["toId": "10"])), context: context))
        XCTAssertFalse(C.matches(C.receipt(["state": "NOT_FOUND", "requestId": "r1"]), context: context))
        XCTAssertFalse(C.matches(nil, context: context))
        let withStation = C.context(inviteType: 0, topicID: "7", toType: "merchant", toID: "9", scope: "MERCHANT", supplyStationID: "3")
        XCTAssertFalse(C.matches(C.receipt(created()), context: withStation))
        XCTAssertTrue(C.matches(C.receipt(created(["supplyStationId": "3"])), context: withStation))
    }

    // MARK: classify
    private func ok(_ replayed: Any? = false, requestId: String = "req-1") -> [String: Any] {
        var data = created(["requestId": requestId])
        if let replayed { data["replayed"] = replayed }
        return ["code": 200, "data": data]
    }

    func testResponseCodeNormalization() {
        XCTAssertEqual(C.responseCode(200), 200)
        XCTAssertEqual(C.responseCode("404"), 404)
        XCTAssertEqual(C.responseCode(99), 0)
        XCTAssertEqual(C.responseCode(600), 0)
        XCTAssertEqual(C.responseCode("600"), 0)
        XCTAssertEqual(C.responseCode("0404"), 0)
        XCTAssertEqual(C.responseCode(true), 0)
        XCTAssertEqual(C.responseCode(nil), 0)
    }

    func testSuccessNeedsMatchingRequestIDAndBooleanReplayed() {
        XCTAssertEqual(C.classify(response: ok(false), httpStatus: 200, requestID: "req-1"), .success)
        XCTAssertEqual(C.classify(response: ok(true), httpStatus: nil, requestID: "req-1"), .success)
        XCTAssertEqual(C.classify(response: ok(false, requestId: "other"), httpStatus: 200, requestID: "req-1"), .unknown)
        XCTAssertEqual(C.classify(response: ok(nil), httpStatus: 200, requestID: "req-1"), .unknown)
        XCTAssertEqual(C.classify(response: ok(1), httpStatus: 200, requestID: "req-1"), .unknown, "replayed must be a real boolean")
    }

    func testConflictSessionChangeAndMissingResponseStayUnknown() {
        XCTAssertEqual(C.classify(response: nil, httpStatus: nil, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 409], httpStatus: nil, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 400], httpStatus: 409, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 400, "reason": "sessionChanged"], httpStatus: nil, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ok(), httpStatus: 12, requestID: "req-1"), .unknown, "an unreadable HTTP status is unknown")
    }

    func testHttpStatusDecidesBeforeBody() {
        XCTAssertEqual(C.classify(response: ["code": 200], httpStatus: 403, requestID: "r"), .failed)
        XCTAssertEqual(C.classify(response: ["code": 200], httpStatus: 408, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 200], httpStatus: 500, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 200], httpStatus: 502, requestID: "r"), .unknown)
    }

    func testBodyCodesFourXXAreRejectionsExcept408() {
        XCTAssertEqual(C.classify(response: ["code": 400, "msg": "bad"], httpStatus: 200, requestID: "r"), .failed)
        XCTAssertEqual(C.classify(response: ["code": "422"], httpStatus: nil, requestID: "r"), .failed)
        XCTAssertEqual(C.classify(response: ["code": 408], httpStatus: nil, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 503], httpStatus: nil, requestID: "r"), .unknown)
    }

    func testWriteClosedServerMessageIsADefiniteRefusal() {
        XCTAssertEqual(C.classify(response: ["code": 500, "msg": "招商写入已关闭，请稍后再试"], httpStatus: nil, requestID: "r"), .failed)
        XCTAssertEqual(C.classify(response: ["code": 500, "msg": "系统繁忙"], httpStatus: nil, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 500], httpStatus: nil, requestID: "r"), .unknown)
    }

    func testOkCodeWithoutValidReceiptIsUnknownNotSuccess() {
        XCTAssertEqual(C.classify(response: ["code": 200], httpStatus: 200, requestID: "r"), .unknown)
        XCTAssertEqual(C.classify(response: ["code": 200, "data": ["state": "NOT_FOUND", "requestId": "r", "replayed": false]], httpStatus: 200, requestID: "r"), .unknown)
    }

    // MARK: readback paging
    func testReadbackPageValidity() {
        XCTAssertTrue(C.readbackPageIsValid(hasMore: false, nextCursor: nil, previousCursor: nil))
        XCTAssertTrue(C.readbackPageIsValid(hasMore: true, nextCursor: "90", previousCursor: nil))
        XCTAssertFalse(C.readbackPageIsValid(hasMore: nil, nextCursor: nil, previousCursor: nil))
        XCTAssertFalse(C.readbackPageIsValid(hasMore: true, nextCursor: nil, previousCursor: nil))
        XCTAssertFalse(C.readbackPageIsValid(hasMore: false, nextCursor: "90", previousCursor: nil))
        XCTAssertFalse(C.readbackPageIsValid(hasMore: true, nextCursor: "090", previousCursor: nil))
    }

    func testReadbackCursorMustStrictlyDecreaseNumerically() {
        XCTAssertTrue(C.readbackPageIsValid(hasMore: true, nextCursor: "99", previousCursor: "100"))
        XCTAssertTrue(C.readbackPageIsValid(hasMore: true, nextCursor: "50", previousCursor: "60"))
        XCTAssertFalse(C.readbackPageIsValid(hasMore: true, nextCursor: "60", previousCursor: "60"))
        XCTAssertFalse(C.readbackPageIsValid(hasMore: true, nextCursor: "61", previousCursor: "60"))
        XCTAssertFalse(C.readbackPageIsValid(hasMore: true, nextCursor: "100", previousCursor: "99"))
        XCTAssertTrue(C.readbackPageIsValid(hasMore: false, nextCursor: nil, previousCursor: "60"))
    }
}
#endif
