import XCTest
@testable import QuestifyCore

/// MP 票夹 F13 (`subpackageMember/signup/index.js` usableTicket / walletOrder / refundingTicket), PLY-21-1.
final class TicketWalletUsableTests: XCTestCase {
    private func tickets(_ raw: String) throws -> [TicketWalletTicket] {
        try JSONDecoder().decode([TicketWalletTicket].self, from: Data(raw.utf8))
    }

    func testOnlyPaidUsableTicketsStayInTheWallet() throws {
        let rows = try tickets(#"""
        [{"id":1,"ownerType":1,"registrationStatus":2,"paymentStatus":2,"usableState":"USABLE"},
         {"id":2,"ownerType":1,"registrationStatus":1,"paymentStatus":1},
         {"id":3,"ownerType":1,"registrationStatus":3,"paymentStatus":2},
         {"id":4,"ownerType":1,"registrationStatus":2,"paymentStatus":2,"usableState":"EXPIRED"},
         {"id":5,"ownerType":1,"registrationStatus":2,"paymentStatus":2,"refundApplication":{"payoutStatus":1}},
         {"id":6,"ownerType":1,"registrationStatus":2,"paymentStatus":2,"refundApplication":{"status":0,"refundAmount":10}},
         {"id":7,"ownerType":1,"registrationStatus":2,"paymentStatus":2,"usableState":"UPCOMING","usableFrom":"2026-12-03 09:00:00"},
         {"id":8,"ownerType":1,"registrationStatus":2,"paymentStatus":1}]
        """#)
        XCTAssertEqual(rows.filter(\.isWalletUsable).map(\.id), [1, 6, 7])
        XCTAssertTrue(rows[5].isRefunding)
        XCTAssertTrue(rows[6].isUpcoming)
        XCTAssertEqual(rows[6].upcomingStartMonthDay?.month, 12)
        XCTAssertEqual(rows[6].upcomingStartMonthDay?.day, 3)
    }

    func testRejectedRefundStaysUsableAndUnlocked() throws {
        let row = try tickets(#"[{"id":1,"registrationStatus":2,"paymentStatus":2,"refundApplication":{"status":2,"refundAmount":10}}]"#)[0]
        XCTAssertTrue(row.isWalletUsable)
        XCTAssertFalse(row.isRefunding)
    }

    func testWalletOrderPutsUpcomingLastAndSoonestExpiryFirst() throws {
        let rows = try tickets(#"""
        [{"id":1,"registrationStatus":2,"paymentStatus":2,"usableState":"UPCOMING","usableFrom":"2026-12-10 09:00:00"},
         {"id":2,"registrationStatus":2,"paymentStatus":2,"usableState":"USABLE"},
         {"id":3,"registrationStatus":2,"paymentStatus":2,"usableState":"USABLE","usableUntil":"2099-01-02 00:00:00"},
         {"id":4,"registrationStatus":2,"paymentStatus":2,"usableState":"UPCOMING","usableFrom":"2026-12-01 09:00:00"},
         {"id":5,"registrationStatus":2,"paymentStatus":2,"usableState":"USABLE","usableUntil":"2099-01-01 00:00:00"}]
        """#)
        XCTAssertEqual(TicketWalletTicket.walletOrder(rows).map(\.id), [5, 3, 2, 4, 1])
    }

    func testClearStateWinsOverTopicCompleted() throws {
        let rows = try tickets(#"""
        [{"id":1,"registrationStatus":2,"clearState":"NOT_CLEARED","topicCompleted":true},
         {"id":2,"registrationStatus":2,"topicCompleted":true},
         {"id":3,"registrationStatus":2}]
        """#)
        XCTAssertEqual(rows.map(\.clearedFlag), [false, true, nil])
    }
}
