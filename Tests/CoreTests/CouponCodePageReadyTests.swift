import XCTest
@testable import QuestifyCore

/// Page-ready facts for `subpackageMember/coupon-qr/index`. Existing issue, status, and
/// credential rules stay in place. Unknown numbers are an em dash. A literal 0 stays 0.
@MainActor final class CouponCodePageReadyTests: XCTestCase {
    private func session() throws -> CouponCodeSession {
        try .init(accountID: 1, epoch: 1, namespace: "synthetic-cn", role: "player", token: "synthetic-token")
    }
    private func decode(_ raw: String) throws -> CouponCodeReceipt {
        try JSONDecoder().decode(CouponCodeReceipt.self, from: Data(raw.utf8))
    }

    func testUnknownTTLIsEmDashAndLiteralZeroStaysZero() throws {
        let absent = try decode(#"{"useStatus":1}"#)
        XCTAssertNil(absent.expiresIn); XCTAssertEqual(absent.expiresInText, "—")
        for raw in [#"{"useStatus":2,"expiresIn":null}"#, #"{"useStatus":3,"expiresIn":"60"}"#, #"{"useStatus":1,"expiresIn":{"seconds":60}}"#] {
            let value = try decode(raw)
            XCTAssertNil(value.expiresIn, raw); XCTAssertEqual(value.expiresInText, "—", raw)
        }
        let zero = try decode(#"{"useStatus":1,"expiresIn":0}"#)
        XCTAssertEqual(zero.expiresIn, 0); XCTAssertEqual(zero.expiresInText, "0")
        let active = try decode(#"{"useStatus":0,"expiresIn":60,"token":"SYNTHETIC-NOT-REDEEMABLE"}"#)
        XCTAssertEqual(active.expiresIn, 60); XCTAssertEqual(active.expiresInText, "60")
        for raw in [#"{"useStatus":0,"expiresIn":0,"token":"A"}"#, #"{"useStatus":0,"token":"A"}"#, #"{"useStatus":0,"expiresIn":null,"token":"A"}"#, #"{"useStatus":0,"expiresIn":"60","token":"A"}"#, #"{"useStatus":"0","expiresIn":60,"token":"A"}"#, #"{"expiresIn":60,"token":"A"}"#] {
            XCTAssertThrowsError(try decode(raw), raw)
        }
    }

    func testUnknownStatusIsNotStoredAsAvailable() throws {
        let missing = try JSONDecoder().decode(OrderCouponStatus.self, from: Data(#"{}"#.utf8))
        XCTAssertNil(missing.useStatus); XCTAssertEqual(missing.stateKey, "unknown")
        let nullStatus = try JSONDecoder().decode(OrderCouponStatus.self, from: Data(#"{"useStatus":null}"#.utf8))
        XCTAssertNil(nullStatus.useStatus); XCTAssertEqual(nullStatus.stateKey, "unknown")
        let zero = try JSONDecoder().decode(OrderCouponStatus.self, from: Data(#"{"useStatus":0}"#.utf8))
        XCTAssertEqual(zero.useStatus, 0); XCTAssertEqual(zero.stateKey, "available")
        XCTAssertThrowsError(try JSONDecoder().decode(OrderCouponStatus.self, from: Data(#"{"useStatus":"0"}"#.utf8)))
    }

    func testMissingHistoryIsEmptyAndSendsNothing() async throws {
        let api = PageReadyCouponService(receipt: try decode(#"{"useStatus":0,"expiresIn":60,"token":"SYNTHETIC-NOT-REDEEMABLE"}"#))
        let owner = try session()
        let model = CouponCodeCoordinator(historyID: 0, service: api, currentSession: { owner })
        XCTAssertEqual(model.phase, .review); XCTAssertEqual(model.remainingSeconds, 0); XCTAssertEqual(model.remainingText, "—")
        let presentation = try XCTUnwrap(model.beginPresentation())
        let offer = try XCTUnwrap(model.offerConfirmation(presentation: presentation))
        await model.confirmPresentation(permit: offer)
        XCTAssertEqual(model.phase, .invalid); XCTAssertEqual(api.issues, 0); XCTAssertNil(model.displayToken)
        XCTAssertEqual(model.remainingText, "—")
    }

    func testLoadingEmptyCountdownAndReadyLiteralZero() async throws {
        let api = PageReadyCouponService(receipt: try decode(#"{"useStatus":0,"expiresIn":60,"token":"SYNTHETIC-NOT-REDEEMABLE"}"#))
        api.suspendIssue = true
        let owner = try session()
        var date = Date(timeIntervalSince1970: 100)
        let model = CouponCodeCoordinator(historyID: 71, service: api, currentSession: { owner }, now: { date })
        let presentation = try XCTUnwrap(model.beginPresentation())
        let offer = try XCTUnwrap(model.offerConfirmation(presentation: presentation))
        let task = Task { await model.confirmPresentation(permit: offer) }
        await api.waitUntilIssued()
        XCTAssertEqual(model.phase, .loading); XCTAssertEqual(model.remainingText, "—"); XCTAssertNil(model.displayToken)
        api.finishIssue()
        await task.value
        XCTAssertEqual(model.phase, .ready); XCTAssertEqual(model.remainingText, "60"); XCTAssertEqual(model.displayToken, "SYNTHETIC-NOT-REDEEMABLE")
        date = date.addingTimeInterval(59.6)
        await model.tick(presentation: presentation)
        XCTAssertTrue(model.canDisplay); XCTAssertEqual(model.remainingSeconds, 0); XCTAssertEqual(model.remainingText, "0")
    }

    func testIssueErrorShowsNoCodeAndNoZeroCountdown() async throws {
        let api = PageReadyCouponService(receipt: try decode(#"{"useStatus":0,"expiresIn":60,"token":"SYNTHETIC-NOT-REDEEMABLE"}"#))
        api.failure = .failed
        let owner = try session()
        let model = CouponCodeCoordinator(historyID: 71, service: api, currentSession: { owner })
        await model.confirmPresentation()
        XCTAssertEqual(model.phase, .failed); XCTAssertNil(model.displayToken); XCTAssertNil(model.receipt)
        XCTAssertEqual(model.remainingSeconds, 0); XCTAssertEqual(model.remainingText, "—"); XCTAssertEqual(api.issues, 1)
    }
}

@MainActor private final class PageReadyCouponService: CouponCodeServing {
    var enabled = true
    var issues = 0
    var failure: CouponCodeFailure?
    var suspendIssue = false
    private var pending: CheckedContinuation<CouponCodeReceipt, Error>?
    let receipt: CouponCodeReceipt
    init(receipt: CouponCodeReceipt) { self.receipt = receipt }
    func issue(historyID: Int, session: CouponCodeSession) async throws -> CouponCodeReceipt {
        issues += 1
        if suspendIssue { return try await withCheckedThrowingContinuation { pending = $0 } }
        if let failure { throw failure }
        return receipt
    }
    func waitUntilIssued() async { while pending == nil { await Task.yield() } }
    func finishIssue() { let continuation = pending; pending = nil; continuation?.resume(returning: receipt) }
    func status(historyID: Int, session: CouponCodeSession) async throws -> OrderCouponStatus {
        try JSONDecoder().decode(OrderCouponStatus.self, from: Data(#"{"useStatus":0}"#.utf8))
    }
    func image(_ receipt: CouponCodeReceipt) async throws -> Data { throw CouponCodeFailure.mediaUnavailable }
}
