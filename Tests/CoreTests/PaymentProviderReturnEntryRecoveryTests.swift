import XCTest
@testable import QuestifyCore

@MainActor final class PaymentProviderReturnEntryRecoveryTests: XCTestCase {
    func testChangedIdentityBeforeEntryDoesNotReadAndNotifiesOnce() async {
        var scope = UUID()
        var reads = 0
        var changes = 0
        let verifier = OrderPaymentVerifier(currentScope: { scope }, read: { _ in
            reads += 1
            throw APIError.unauthorized
        })
        let flow = PaymentProviderReturnFlow(registrationID: 701, verifier: verifier, currentScope: { scope })
        flow.onChange = { changes += 1 }
        scope = UUID()
        await flow.reconcile()
        await flow.reconcile()
        XCTAssertEqual(flow.phase, .accessDenied)
        XCTAssertNil(flow.detail)
        XCTAssertTrue(flow.canClose)
        XCTAssertEqual(reads, 0)
        XCTAssertEqual(changes, 1)
    }

    func testInvalidOriginalIDsRemainUnknownWithoutReading() async {
        let scope = UUID()
        var reads = 0
        let verifier = OrderPaymentVerifier(currentScope: { scope }, read: { _ in
            reads += 1
            throw APIError.unauthorized
        })
        for id in [0, -1] {
            let flow = PaymentProviderReturnFlow(registrationID: id, verifier: verifier, currentScope: { scope })
            await flow.reconcile()
            XCTAssertEqual(flow.phase, .unknown)
            XCTAssertEqual(flow.registrationID, id)
            XCTAssertNil(flow.detail)
            XCTAssertTrue(flow.canClose)
        }
        XCTAssertEqual(reads, 0)
    }

    func testCancelledEntryRemainsUnknownWithoutReading() async {
        let scope = UUID()
        var reads = 0
        let verifier = OrderPaymentVerifier(currentScope: { scope }, read: { _ in
            reads += 1
            throw APIError.unauthorized
        })
        let flow = PaymentProviderReturnFlow(registrationID: 701, verifier: verifier, currentScope: { scope })
        let task = Task { @MainActor in await flow.reconcile() }
        // The current MainActor turn cannot be interleaved before this cancellation.
        task.cancel()
        await task.value
        XCTAssertEqual(flow.phase, .unknown)
        XCTAssertEqual(flow.registrationID, 701)
        XCTAssertNil(flow.detail)
        XCTAssertEqual(reads, 0)
    }
}
