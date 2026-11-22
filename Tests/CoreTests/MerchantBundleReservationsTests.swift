import XCTest
@testable import QuestifyCore

/// Source pages/merchant/bundle-reservations/index.js shape/startMs and the 记未到店 rule.
final class MerchantBundleReservationsTests: XCTestCase {
    func testRowsParseMillisAndChinaLocalTextAndRejectUnknownStatus() throws {
        let value: MerchantBusinessValue = .array([
            .object(["id": .number(91), "startAt": .string("2026-11-20 18:30:00"), "status": .string("BOOKED")]),
            .object(["id": .string("92"), "startAt": .number(1_763_000_000_000), "status": .string("NO_SHOW")])])
        let rows = try XCTUnwrap(MerchantBundleReservation.rows(value))
        XCTAssertEqual(rows.map(\.id), [91, 92])
        let calendar = MerchantBundleReservation.chinaCalendar
        XCTAssertEqual(calendar.component(.hour, from: rows[0].start), 18)
        XCTAssertTrue(rows[0].canMarkNoShow(now: rows[0].start.addingTimeInterval(60)))
        XCTAssertFalse(rows[0].canMarkNoShow(now: rows[0].start.addingTimeInterval(-60)))
        XCTAssertFalse(rows[1].canMarkNoShow(now: Date()))
        XCTAssertNil(MerchantBundleReservation.rows(.array([.object(["id": .number(1), "startAt": .string("2026-11-20 18:30"), "status": .string("UNKNOWN")])])))
        XCTAssertNil(MerchantBundleReservation.rows(.array([.object(["id": .number(0), "startAt": .string("2026-11-20 18:30"), "status": .string("BOOKED")])])))
        XCTAssertNil(MerchantBundleReservation.rows(.object([:])))
    }
    func testWindowIsTwoDaysBackNineDaysWide() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let window = MerchantBundleReservation.window(now: now)
        XCTAssertEqual(window.from, 1_000_000_000 - 2 * 86_400_000)
        XCTAssertEqual(window.to - window.from, 9 * 86_400_000)
    }
}
