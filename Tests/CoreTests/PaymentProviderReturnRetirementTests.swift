import XCTest
@testable import QuestifyCore

@MainActor final class PaymentProviderReturnRetirementTests: XCTestCase {
    func testLeavingBeforeQueuedReconcileCannotRestartReadback() async {
        let scope = UUID()
        var reads = 0
        let verifier = OrderPaymentVerifier(currentScope: { scope }, read: { _ in
            reads += 1
            throw APIError.unauthorized
        })
        let flow = PaymentProviderReturnFlow(registrationID: 701, verifier: verifier, currentScope: { scope })
        flow.leave()
        await flow.reconcile()
        await flow.reconcile()
        XCTAssertEqual(flow.phase, .unknown)
        XCTAssertEqual(flow.registrationID, 701)
        XCTAssertNil(flow.detail)
        XCTAssertEqual(reads, 0)
    }

    func testLeavingCompletedPaidObservationDoesNotInventAnotherResultOrRead() async throws {
        let scope = UUID()
        var reads = 0
        let body = Data(#"{"id":701,"ownerType":1,"ownerId":77,"paymentStatus":2,"registrationStatus":2}"#.utf8)
        let detail = try JSONDecoder().decode(OrderLifecycleDetail.self, from: body)
        let verifier = OrderPaymentVerifier(currentScope: { scope }, read: { _ in
            reads += 1
            return detail
        })
        let flow = PaymentProviderReturnFlow(registrationID: 701, verifier: verifier, currentScope: { scope })
        await flow.reconcile()
        XCTAssertEqual(flow.phase, .paid)
        XCTAssertNotNil(flow.detail)
        flow.leave()
        await flow.reconcile()
        XCTAssertEqual(flow.phase, .paid)
        XCTAssertNil(flow.detail)
        XCTAssertEqual(reads, 1)
    }
}
