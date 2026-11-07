#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Encodes utils/content-report.js, utils/community-report-sheet.js and utils/community-comment-recovery.js.
final class ContentReportAndCommentRecoveryRulesTests: XCTestCase {
    typealias R = ContentReportReasonRules
    typealias K = CommunityCommentRecoveryRules

    // MARK: report reasons
    func testLabelsAreTrimmedAndBlanksDropped() {
        let rows: [[String: Any]] = [["label": "  Spam "], ["label": "   "], ["label": 5], ["code": "x"], ["label": "Abuse"]]
        XCTAssertEqual(R.labels(code: 200, reasons: rows), ["Spam", "Abuse"])
    }

    func testLabelsRequireOkCodeAndReasonsArray() {
        XCTAssertEqual(R.labels(code: 500, reasons: [["label": "Spam"]]), [])
        XCTAssertEqual(R.labels(code: nil, reasons: [["label": "Spam"]]), [])
        XCTAssertEqual(R.labels(code: 200, reasons: nil), [])
        XCTAssertEqual(R.labels(code: 200, reasons: []), [])
    }

    func testWriteFieldsAreExactlyIdAndReasonOnThreeLiteralPaths() {
        XCTAssertEqual(R.fields(id: "9", reason: "Spam"), ["id": "9", "reason": "Spam"])
        XCTAssertEqual(R.topicWritePath, "api/topic/report")
        XCTAssertEqual(R.templateWritePath, "api/template/report")
        XCTAssertEqual(R.personalTemplateWritePath, "api/template/personal-report")
        XCTAssertEqual(R.templateWritePath, TemplateContentReportTarget(kind: .library, id: 1)?.writePath)
        XCTAssertEqual(R.personalTemplateWritePath, TemplateContentReportTarget(kind: .member, id: 1)?.writePath)
        XCTAssertEqual(R.policyPath, TemplateContentReportTarget.policyPath)
    }

    func testSheetSelectsOnlyInRangeIntegerAndClosesAfterward() {
        var sheet = R.Sheet()
        XCTAssertNil(sheet.open(count: 3, pageUnloaded: false, aborted: false))
        XCTAssertTrue(sheet.isOpen)
        guard case .success(2)? = sheet.select(2) else { return XCTFail("expected index 2") }
        XCTAssertFalse(sheet.isOpen)
        XCTAssertNil(sheet.select(1), "a second selection with no open sheet is ignored")
    }

    func testSheetRejectsOutOfRangeNilAndNegativeIndexAsInvalidSelection() {
        for bad in [Optional<Int>.none, -1, 3, 99] {
            var sheet = R.Sheet(); _ = sheet.open(count: 3, pageUnloaded: false, aborted: false)
            guard case .failure(.invalidSelection)? = sheet.select(bad) else { return XCTFail("\(String(describing: bad)) accepted") }
            XCTAssertFalse(sheet.isOpen)
        }
        XCTAssertEqual(R.SheetError.invalidSelection.sourceCode, 500)
    }

    func testSheetRefusesSecondOpenAndCancelledPages() {
        var sheet = R.Sheet()
        XCTAssertNil(sheet.open(count: 2, pageUnloaded: false, aborted: false))
        XCTAssertEqual(sheet.open(count: 2, pageUnloaded: false, aborted: false), .alreadyOpen)
        XCTAssertEqual(R.SheetError.alreadyOpen.sourceCode, 409)
        XCTAssertEqual(sheet.cancel(), .cancelled)
        XCTAssertNil(sheet.cancel())
        var gone = R.Sheet()
        XCTAssertEqual(gone.open(count: 2, pageUnloaded: true, aborted: false), .cancelled)
        XCTAssertEqual(gone.open(count: 2, pageUnloaded: false, aborted: true), .cancelled)
        XCTAssertFalse(gone.isOpen)
        XCTAssertTrue(R.SheetError.cancelled.isSilent)
        XCTAssertEqual(R.SheetError.cancelled.sourceCode, 499)
        XCTAssertFalse(R.SheetError.invalidSelection.isSilent)
    }

    func testRunGuardsAgainstEmptyIdAndReentry() {
        var run = R.Run()
        XCTAssertFalse(run.begin(id: nil))
        XCTAssertFalse(run.begin(id: ""))
        XCTAssertTrue(run.begin(id: "5"))
        XCTAssertFalse(run.begin(id: "5"), "a second tap while reporting does nothing")
        run.finish()
        XCTAssertTrue(run.begin(id: "5"))
    }

    func testOutcomeAcceptsOnly200AndKeepsServerWords() {
        XCTAssertEqual(R.outcome(code: 200, message: "submitted"), .init(accepted: true, serverMessage: "submitted"))
        XCTAssertEqual(R.outcome(code: 200, message: nil), .init(accepted: true, serverMessage: nil))
        XCTAssertEqual(R.outcome(code: 500, message: ""), .init(accepted: false, serverMessage: nil))
        XCTAssertEqual(R.outcome(code: 403, message: "denied"), .init(accepted: false, serverMessage: "denied"))
    }

    // MARK: comment recovery
    private func wire(_ body: String = "hi", parent: String? = nil, key: String = "req-12345") -> K.Wire {
        .init(body: body, parentID: parent, clientRequestID: key)
    }
    private func row(_ status: K.Status = .unknown, wire w: K.Wire? = nil, key: String = "req-12345", member: String = "7", post: String = "9") -> K.Row {
        .init(key: key, memberID: member, postID: post, status: status, wire: w ?? wire(key: key))
    }

    func testExactIDAndKeyRules() {
        XCTAssertTrue(K.isExactID("1")); XCTAssertTrue(K.isExactID("9223372036854775807"))
        XCTAssertFalse(K.isExactID("9223372036854775808")); XCTAssertFalse(K.isExactID("0")); XCTAssertFalse(K.isExactID("01"))
        XCTAssertFalse(K.isExactID("")); XCTAssertFalse(K.isExactID("1x"))
        XCTAssertTrue(K.isValidKey("12345678")); XCTAssertFalse(K.isValidKey("1234567"))
        XCTAssertTrue(K.isValidKey(String(repeating: "k", count: 96))); XCTAssertFalse(K.isValidKey(String(repeating: "k", count: 97)))
        XCTAssertFalse(K.isValidKey("   abc   "), "length is measured after trimming")
    }

    func testPrepareFreshCommentCreatesSendingRow() throws {
        let result = try K.prepare(stored: nil, owner: "7", post: "9", wire: wire("hello")).get()
        XCTAssertFalse(result.reused)
        XCTAssertEqual(result.row.status, .sending)
        XCTAssertEqual(result.row.key, "req-12345")
        XCTAssertEqual(result.row.memberID, "7"); XCTAssertEqual(result.row.postID, "9")
    }

    func testPrepareValidatesIdentityBodyAndRequestID() {
        func failure(_ r: Result<(row: K.Row, reused: Bool), K.Failure>) -> K.Failure? { if case .failure(let f) = r { return f }; return nil }
        XCTAssertEqual(failure(K.prepare(stored: nil, owner: "0", post: "9", wire: wire())), .invalidIdentity)
        XCTAssertEqual(failure(K.prepare(stored: nil, owner: "7", post: "x", wire: wire())), .invalidIdentity)
        XCTAssertEqual(failure(K.prepare(stored: nil, owner: "7", post: "9", wire: wire("   "))), .invalidBody)
        XCTAssertEqual(failure(K.prepare(stored: nil, owner: "7", post: "9", wire: wire(String(repeating: "a", count: 2001)))), .invalidBody)
        XCTAssertNil(failure(K.prepare(stored: nil, owner: "7", post: "9", wire: wire(String(repeating: "a", count: 2000)))))
        XCTAssertEqual(failure(K.prepare(stored: nil, owner: "7", post: "9", wire: wire(key: "short"))), .invalidRequestID)
        XCTAssertEqual(K.Failure.invalidBody.sourceCode, 400)
        XCTAssertEqual(K.Failure.storageFailed.sourceCode, 507)
    }

    func testUnconfirmedSameCommentReusesStoredRowAndKey() throws {
        let stored = row(.unknown, wire: wire("hello", parent: "3", key: "req-aaaaaaaa"), key: "req-aaaaaaaa")
        let result = try K.prepare(stored: stored, owner: "7", post: "9", wire: wire("hello", parent: "3", key: "req-bbbbbbbb")).get()
        XCTAssertTrue(result.reused)
        XCTAssertEqual(result.row.key, "req-aaaaaaaa", "the original request id is replayed, never a new one")
        XCTAssertEqual(result.row, stored)
    }

    func testParentNilAndEmptyAreTheSameForReplayComparison() throws {
        let stored = row(.sending, wire: wire("hello", parent: nil))
        XCTAssertTrue(try K.prepare(stored: stored, owner: "7", post: "9", wire: wire("hello", parent: "")).get().reused)
    }

    func testUnconfirmedDifferentCommentIsBlockedWithTheOriginalWire() {
        let stored = row(.unknown, wire: wire("first"))
        guard case .failure(.pendingDiffers(let original)) = K.prepare(stored: stored, owner: "7", post: "9", wire: wire("second", key: "req-zzzzzzzz")) else {
            return XCTFail("a different comment must not replace an unconfirmed one")
        }
        XCTAssertEqual(original.body, "first")
        let reply = row(.unknown, wire: wire("first", parent: "4"))
        guard case .failure(.pendingDiffers) = K.prepare(stored: reply, owner: "7", post: "9", wire: wire("first", parent: "5")) else {
            return XCTFail("a different parent is a different comment")
        }
    }

    func testRejectedRowDoesNotBlockANewComment() throws {
        let stored = row(.rejected, wire: wire("old", key: "req-aaaaaaaa"), key: "req-aaaaaaaa")
        let result = try K.prepare(stored: stored, owner: "7", post: "9", wire: wire("new", key: "req-bbbbbbbb")).get()
        XCTAssertFalse(result.reused)
        XCTAssertEqual(result.row.key, "req-bbbbbbbb")
        XCTAssertEqual(result.row.wire.body, "new")
    }

    func testIncompleteOrForeignStoredRowIsRefused() {
        let bad: [K.Row] = [
            row(.unknown, member: "8"),
            row(.unknown, post: "10"),
            row(.unknown, wire: wire("  ")),
            row(.unknown, wire: wire("x", key: "req-other-key"), key: "req-12345"),
            row(.unknown, wire: wire("x", parent: "0")),
            row(.unknown, wire: wire("x", key: "short"), key: "short"),
        ]
        for stored in bad {
            guard case .failure(.incompleteRecord) = K.prepare(stored: stored, owner: "7", post: "9", wire: wire("x")) else {
                return XCTFail("accepted a corrupt stored row: \(stored)")
            }
        }
    }

    func testSettleClearsOnSuccessAndClassifiesFailures() {
        let attempted = row(.sending)
        XCTAssertEqual(K.settle(stored: attempted, attempted: attempted, reused: false, code: 200), .clear)
        for code in [400, 403, 404] {
            XCTAssertEqual(K.settle(stored: attempted, attempted: attempted, reused: false, code: code), .keep(.rejected))
            XCTAssertEqual(K.settle(stored: attempted, attempted: attempted, reused: true, code: code), .keep(.unknown),
                           "a replay can never become a definite rejection")
        }
        for code in [401, 409, 429, 500, 502, 0] {
            XCTAssertEqual(K.settle(stored: attempted, attempted: attempted, reused: false, code: code), .keep(.unknown))
        }
    }

    func testSettleIgnoresMissingOrNewerStoredRow() {
        let attempted = row(.sending)
        XCTAssertEqual(K.settle(stored: nil, attempted: attempted, reused: false, code: 200), .ignore)
        let newer = row(.sending, wire: wire("other", key: "req-newer-key"), key: "req-newer-key")
        XCTAssertEqual(K.settle(stored: newer, attempted: attempted, reused: false, code: 200), .ignore)
    }
}
#endif
