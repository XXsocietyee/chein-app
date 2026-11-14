import XCTest
@testable import QuestifyCore

/// Page-ready states for pages/activity/official-inbox. Synthetic rows only.
final class OfficialInboxPageReadyTests: XCTestCase {
    private func invite(_ json: String) throws -> OfficialPartyInvite {
        try JSONDecoder().decode(OfficialPartyInvite.self, from: Data(json.utf8))
    }

    func testExistingPartyInboxRouteStaysVisibleAndMissingRoutesStayHidden() {
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: OfficialInboxPageModel.partyInboxPath), .liveInProduction)
        // 2026-11-13 backend-final-gaps: served on TEST r2; the app feature is still not wired (listed for follow-up).
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/official/v2/organizer-invites/{}/{}"), .liveInProduction)
        XCTAssertNil(OfficialInboxPageModel.state(path: "api/official/v2/organizer-invites/9/decline", loading: false, failed: false, rows: []))
        XCTAssertNil(OfficialInboxPageModel.state(path: "api/not-a-route", loading: true, failed: false, rows: nil))
    }

    func testLoadingEmptyErrorAndUnknownNeverGuessACount() throws {
        let row = try invite(#"{"partyId":4,"title":"Synthetic"}"#)
        XCTAssertEqual(OfficialInboxPageModel.state(loading: true, failed: false, rows: [row]), .loading)
        XCTAssertEqual(OfficialInboxPageModel.rowCountText(.loading), "—")
        XCTAssertEqual(OfficialInboxPageModel.state(loading: false, failed: true, rows: []), .error)
        XCTAssertEqual(OfficialInboxPageModel.rowCountText(.error), "—")
        XCTAssertEqual(OfficialInboxPageModel.state(loading: false, failed: true, rows: nil), .error)
        XCTAssertEqual(OfficialInboxPageModel.state(loading: false, failed: false, rows: nil), .unknown)
        XCTAssertEqual(OfficialInboxPageModel.rowCountText(.unknown), "—")
        XCTAssertNotEqual(OfficialInboxPageModel.rowCountText(.unknown), "0")
        XCTAssertEqual(OfficialInboxPageModel.state(loading: false, failed: false, rows: []), .empty)
        XCTAssertEqual(OfficialInboxPageModel.rowCountText(.empty), "0")
        XCTAssertEqual(OfficialInboxPageModel.state(loading: false, failed: false, rows: [row]), .ready(rowCount: 1))
        XCTAssertEqual(OfficialInboxPageModel.rowCountText(.ready(rowCount: 1)), "1")
        XCTAssertEqual(OfficialInboxPageModel.rowCountText(.ready(rowCount: 0)), "—")
    }

    func testCapacityUnknownIsAnEmDashAndLiteralZeroStaysZero() throws {
        let unknown = try invite(#"{"partyId":1,"capacity":"UNKNOWN"}"#)
        XCTAssertNil(unknown.capacity)
        XCTAssertEqual(unknown.capacityFact, .unknown)
        XCTAssertEqual(unknown.capacityFact.displayText, "—")
        XCTAssertEqual(try invite(#"{"partyId":2}"#).capacityFact.displayText, "—")
        XCTAssertEqual(try invite(#"{"partyId":3,"capacity":null}"#).capacityFact.displayText, "—")
        let textZero = try invite(#"{"partyId":4,"capacity":"0"}"#)
        XCTAssertEqual(textZero.capacityFact, .unknown)
        XCTAssertNotEqual(textZero.capacityFact.displayText, "0")
        let zero = try invite(#"{"partyId":5,"capacity":0}"#)
        XCTAssertNil(zero.capacity)
        XCTAssertEqual(zero.capacityFact, .known(0))
        XCTAssertEqual(zero.capacityFact.displayText, "0")
        let positive = try invite(#"{"partyId":6,"capacity":4}"#)
        XCTAssertEqual(positive.capacity, 4)
        XCTAssertEqual(positive.capacityFact, .known(4))
        XCTAssertEqual(try invite(#"{"partyId":7,"capacity":1.5}"#).capacityFact, .unknown)
        XCTAssertEqual(try invite(#"{"partyId":8,"capacity":true}"#).capacityFact, .unknown)
        XCTAssertEqual(try invite(#"{"partyId":9,"capacity":{"n":1}}"#).capacityFact, .unknown)
        XCTAssertEqual(try invite(#"{"partyId":10,"capacity":-3}"#).capacityFact, .known(-3))
    }

    func testDebugFixtureDataDecodesWithoutInventingACount() throws {
        let rows = try JSONDecoder().decode([OfficialPartyInvite].self, from: OfficialInboxFixtureData.content)
        XCTAssertEqual(rows.map(\.id), [81, 82, 83, 84])
        let empty = try JSONDecoder().decode([OfficialPartyInvite].self, from: OfficialInboxFixtureData.empty)
        XCTAssertEqual(OfficialInboxPageModel.state(loading: false, failed: false, rows: empty), .empty)
        let unknown = try JSONDecoder().decode([OfficialPartyInvite].self, from: OfficialInboxFixtureData.unknownCapacity)
        XCTAssertEqual(unknown.first?.capacityFact.displayText, "—")
        let zero = try JSONDecoder().decode([OfficialPartyInvite].self, from: OfficialInboxFixtureData.zeroCapacity)
        XCTAssertEqual(zero.first?.capacityFact.displayText, "0")
        XCTAssertThrowsError(try JSONDecoder().decode([OfficialPartyInvite].self, from: OfficialInboxFixtureData.unreadable))
    }
}
