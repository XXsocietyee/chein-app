import XCTest
@testable import QuestifyCore

/// Mini-program signup copy projection (subpackageMember/signup). Presentation only.
final class TicketWalletSourceCopyTests: XCTestCase {
    private func ticket(_ fields: String) throws -> TicketWalletTicket {
        try JSONDecoder().decode(TicketWalletTicket.self, from: Data(("{\"id\":7," + fields + "}").utf8))
    }

    func testUntitledFallbackFollowsSourceLane() throws {
        XCTAssertEqual(try ticket(#""ownerType":1"#).untitledKey, "ticketWallet.parity.untitled.route")
        XCTAssertEqual(try ticket(#""ownerType":2"#).untitledKey, "ticketWallet.parity.untitled.activity")
        XCTAssertEqual(try ticket(#""ownerType":"2""#).lane, .activity)
    }

    func testUnknownLaneKeepsGenericFallback() throws {
        XCTAssertNil(try ticket(#""ownerType":9"#).lane)
        XCTAssertEqual(try ticket(#""ownerType":9"#).untitledKey, "ticketWallet.untitled")
        XCTAssertEqual(try ticket(#""registrationStatus":2"#).untitledKey, "ticketWallet.untitled")
    }

    func testReadyHintOnlyForUnverifiedPaidRows() throws {
        XCTAssertEqual(try ticket(#""registrationStatus":2"#).statusHintKey, "ticketWallet.parity.hint.ready")
        // Source wxs: verification precedes the paid label.
        XCTAssertNil(try ticket(#""registrationStatus":2,"verificationStatus":1"#).statusHintKey)
        for status in [1, 3, 4, 9] {
            XCTAssertNil(try ticket(#""registrationStatus":\#(status)"#).statusHintKey, "status \(status)")
        }
    }

    func testHintNeverChangesOpeningAction() throws {
        let pending = try ticket(#""registrationStatus":1"#)
        XCTAssertNil(pending.statusHintKey)
        XCTAssertEqual(pending.action, .paymentUnavailable)
        XCTAssertEqual(try ticket(#""registrationStatus":2"#).action, .detail)
    }

    func testMemberPartyAndExploreProgressDecodeWithoutDroppingTheTicket() throws {
        let plain = try ticket(#""registrationStatus":2"#)
        XCTAssertNil(plain.memberID)
        XCTAssertNil(plain.party)
        XCTAssertNil(plain.exploreProgress)
        let row = try ticket(#""memberId":12,"party":{"adultCount":1,"childCount":1},"exploreProgress":{"redeemed":2,"required":4,"active":true,"completed":false,"ended":false}"#)
        XCTAssertEqual(row.memberID, "12")
        XCTAssertEqual(row.party?.adultCount, 1)
        XCTAssertEqual(row.party?.childCount, 1)
        XCTAssertEqual(row.exploreProgress?.redeemed, 2)
        XCTAssertEqual(row.exploreProgress?.required, 4)
        XCTAssertEqual(row.exploreProgress?.active, true)
        XCTAssertNil(try ticket(#""memberId":"12","exploreProgress":{"required":0}"#).exploreProgress)
        XCTAssertEqual(try ticket(#""memberId":"12""#).memberID, "12")
    }
}
