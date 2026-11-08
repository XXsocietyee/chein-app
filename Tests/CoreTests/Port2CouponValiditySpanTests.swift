import XCTest
@testable import QuestifyCore

final class Port2CouponValiditySpanTests: XCTestCase {
    private func date(_ text: String) throws -> Date { try XCTUnwrap(CouponValidityTime.parse(text)) }
    func testCrossDaySpanKeepsMinutes() throws {
        let span = try XCTUnwrap(CouponValiditySpan.make(start: date("2026-08-28 22:00:00"), end: date("2026-08-31 02:30:00")))
        XCTAssertEqual(span.days, 2); XCTAssertEqual(span.hours, 4); XCTAssertEqual(span.minutes, 30)
    }
    func testOvernightIsFourHoursNotNegative() throws {
        let span = try XCTUnwrap(CouponValiditySpan.make(start: date("2026-09-01 22:00:00"), end: date("2026-09-02 02:00:00")))
        XCTAssertEqual(span.totalMinutes, 240)
    }
    func testNoSpanForMissingEqualOrReversed() throws {
        let a = try date("2026-09-01 10:00:00"), b = try date("2026-09-01 09:00:00")
        XCTAssertNil(CouponValiditySpan.make(start: nil, end: a))
        XCTAssertNil(CouponValiditySpan.make(start: a, end: a))
        XCTAssertNil(CouponValiditySpan.make(start: a, end: b))
    }
}
