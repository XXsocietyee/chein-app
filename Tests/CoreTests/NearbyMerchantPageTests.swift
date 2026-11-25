import XCTest
@testable import QuestifyCore

@available(macOS 14.0, *)
final class NearbyMerchantPageTests: XCTestCase {
    private typealias Page = NearbyMerchantPage
    private let dash = "\u{2014}"

    private func rows(_ text: String) throws -> [NearbyMerchantRow] {
        try (JSONDecoder().decode(CoopFlowJSON.self, from: Data(text.utf8)).rows ?? []).map(NearbyMerchantRow.init)
    }

    func testTotalIsAnEmDashUntilALoadedReadAndZeroOnlyForALoadedEmptyRead() {
        let phases: [NearbyMerchantCoordinator.Phase] = [.idle, .unavailable, .consentRequired, .locating, .loading, .locationFailed, .locationDenied, .permissionDenied, .failed]
        for phase in phases {
            let value = Page.resolve(phase: phase, rows: [])
            XCTAssertEqual(value.totalText, dash, "\(phase)")
            XCTAssertTrue(value.cards.isEmpty)
        }
        let empty = Page.resolve(phase: .ready, rows: [])
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.totalText, "0")
    }

    func testStaleRowsAreNotShownOutsideAReadyRead() throws {
        let loaded = try rows(#"[{"id":1,"name":"Fixture","cover":"c","logo":"l","businessTime":"10-22","capacity":4,"chargeType":1,"suitActivityTypes":"1","lat":31.2,"lng":121.5}]"#)
        XCTAssertTrue(Page.resolve(phase: .idle, rows: loaded).cards.isEmpty)
        XCTAssertTrue(Page.resolve(phase: .permissionDenied, rows: loaded).cards.isEmpty)
        let kept = Page.resolve(phase: .failed, rows: loaded)
        XCTAssertEqual(kept.phase, .ready)
        XCTAssertEqual(kept.cards.map(\.id), [1])
        XCTAssertEqual(loaded.first?.cover, "c")
        XCTAssertEqual(loaded.first?.latitude, 31.2)
        XCTAssertEqual(loaded.first?.longitude, 121.5)
        let ready = Page.resolve(phase: .ready, rows: loaded)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.totalText, "1")
    }

    func testDistanceKeepsMeterSuffixAndALiteralZeroStaysZero() throws {
        let loaded = try rows(#"[{"id":1,"name":"Zero","distance":0},{"id":2,"name":"Near","distance":349.6},{"id":3,"name":"Unknown"}]"#)
        let cards = Page.resolve(phase: .ready, rows: loaded).cards
        XCTAssertEqual(cards.map(\.distanceText), ["0 m", "350 m", nil])
        XCTAssertNil(Page.distanceText(nil))
        XCTAssertNil(Page.distanceText(.nan))
        XCTAssertNil(Page.distanceText(-1))
    }

    func testPublicHomeOnlyForRegisteredAndPhoneOnlyForCallableLeads() throws {
        let loaded = try rows(#"[{"id":1,"name":"Lead","phone":"021-000","canCall":true},{"id":2,"name":"Member","memberId":9,"phone":"021-000","canCall":true}]"#)
        let cards = Page.resolve(phase: .ready, rows: loaded).cards
        XCTAssertEqual(cards.map(\.opensPublicHome), [false, true])
        XCTAssertEqual(cards.map(\.callablePhone), ["021-000", nil])
    }

    func testPhaseMappingKeepsRecoverableLocationStatesApart() {
        XCTAssertEqual(Page.mappedPhase(.locating, rowCount: 0), .loading)
        XCTAssertEqual(Page.mappedPhase(.locationDenied, rowCount: 0), .locationDenied)
        XCTAssertEqual(Page.mappedPhase(.locationFailed, rowCount: 0), .locationFailed)
        XCTAssertEqual(Page.mappedPhase(.permissionDenied, rowCount: 0), .permissionDenied)
        XCTAssertEqual(Page.mappedPhase(.failed, rowCount: 3), .error)
    }
}
