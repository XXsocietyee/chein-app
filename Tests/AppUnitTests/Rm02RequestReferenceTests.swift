import XCTest
@testable import QuestifyCore
@testable import QuestifyApp

/// OWN-OPT-072: Non-play unknown-result and error surfaces mount `RequestReferenceRow`
/// backed by `RequestReferenceLedger` without inventing synthetic request IDs.
final class Rm02RequestReferenceTests: XCTestCase {
    @MainActor
    func testNonPlayRegistrationPayAndOrderErrorRenderRequestReferenceRow() {
        let ledger = RequestReferenceLedger()
        let now = Date()
        ledger.record(path: "/api/registration/pay", headerValue: "deadbeef12345678abcdef0011223344", now: now)
        ledger.record(path: "/api/registration/quote", headerValue: "cafe0000111122223333444455556666", now: now)
        ledger.record(path: "/api/club/settlement/mine", headerValue: "1234567890abcdef1234567890abcdef", now: now)

        let payRow = RequestReferenceRow(pathFragment: "/api/registration/pay", ledger: ledger)
        XCTAssertEqual(payRow?.reference, "deadbeef12345678abcdef0011223344")

        let quoteRow = RequestReferenceRow(pathFragment: "/api/registration/quote", ledger: ledger)
        XCTAssertEqual(quoteRow?.reference, "cafe0000111122223333444455556666")

        let clubRow = RequestReferenceRow(pathFragment: "/api/club/", ledger: ledger)
        XCTAssertEqual(clubRow?.reference, "1234567890abcdef1234567890abcdef")

        // Never invents a reference when absent or stale
        XCTAssertNil(RequestReferenceRow(pathFragment: "/api/user/", ledger: ledger))
        XCTAssertNil(ledger.latest(pathFragment: "/api/registration/pay", maxAge: 120, now: now.addingTimeInterval(300)))
    }
}
