#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class OrientScoreReviewModelTests: XCTestCase {
    private struct Boom: Error, LocalizedError { var errorDescription: String? { "boom" } }

    private final class Recorder {
        var calls: [(OrientScoreReviewModel.Kind, String, String)] = []
        var failuresLeft = 0
    }

    private func model(_ recorder: Recorder) -> OrientScoreReviewModel {
        var counter = 0
        return OrientScoreReviewModel(submitter: { kind, reason, key in
            recorder.calls.append((kind, reason, key))
            if recorder.failuresLeft > 0 { recorder.failuresLeft -= 1; throw Boom() }
        }, makeKey: { counter += 1; return "key-\(counter)" })
    }

    func testNoSubmitterIsHonestlyUnavailable() {
        let m = OrientScoreReviewModel(submitter: nil, makeKey: { "k" })
        m.review(kind: .appeal, reason: "wrong score")
        XCTAssertEqual(m.state, .unavailable)
    }

    func testReasonValidationAndConfirmBeforeSend() async {
        let recorder = Recorder()
        let m = model(recorder)
        m.review(kind: .appeal, reason: "   ")
        if case .failed = m.state {} else { XCTFail("blank reason must fail") }
        m.review(kind: .appeal, reason: String(repeating: "a", count: 501))
        if case .failed = m.state {} else { XCTFail("over-long reason must fail") }
        m.review(kind: .dispute, reason: "  unfair  ")
        XCTAssertEqual(m.state, .awaitingConfirmation(kind: .dispute, reason: "unfair"))
        XCTAssertTrue(recorder.calls.isEmpty, "nothing is sent before confirm")
        await m.confirm()
        XCTAssertEqual(recorder.calls.count, 1)
        XCTAssertEqual(recorder.calls[0].1, "unfair")
        XCTAssertEqual(m.state, .submitted(.dispute))
    }

    func testFailureKeepsTheSameKeyForRetry() async {
        let recorder = Recorder()
        recorder.failuresLeft = 1
        let m = model(recorder)
        m.review(kind: .appeal, reason: "wrong")
        await m.confirm()
        XCTAssertEqual(m.state, .failed("boom"))
        m.review(kind: .appeal, reason: "wrong")
        await m.confirm()
        XCTAssertEqual(recorder.calls.count, 2)
        XCTAssertEqual(recorder.calls[0].2, recorder.calls[1].2, "retry replays the original idempotency key")
        XCTAssertEqual(m.state, .submitted(.appeal))
        m.review(kind: .appeal, reason: "again")
        await m.confirm()
        XCTAssertNotEqual(recorder.calls[2].2, recorder.calls[0].2, "a later, separate appeal gets a new key")
    }

    func testCancelReturnsToIdleWithoutSending() async {
        let recorder = Recorder()
        let m = model(recorder)
        m.review(kind: .appeal, reason: "x")
        m.cancel()
        await m.confirm()
        XCTAssertTrue(recorder.calls.isEmpty)
        XCTAssertEqual(m.state, .idle)
    }
}
#endif
