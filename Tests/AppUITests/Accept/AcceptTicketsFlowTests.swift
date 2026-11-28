import XCTest

/// Ticket wallet. Design fixture `e4-tickets`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptTicketsFlowTests: XCTestCase {
    func testTicketsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-tickets", markers: ["ticketWallet.list", "ticketWallet.empty", "ticketWallet.partialFailure"], en: "Tickets", zh: "票夹")
    }
}
