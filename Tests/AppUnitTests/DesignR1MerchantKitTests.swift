import XCTest
@testable import Questify

/// Design hand-off r1 · merchant & creator kit rules (review/full-merchant-creator.md MR-17, MR-20).
final class DesignR1MerchantKitTests: XCTestCase {
    private func point(_ date: String, _ amount: String?) throws -> MerchantRevenuePoint {
        let json: [String: Any] = amount.map { ["date": date, "amount": $0] } ?? ["date": date]
        return try JSONDecoder().decode(MerchantRevenuePoint.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10))!
    }

    func testTodayIncomeReadsTodaysPointOnly() throws {
        let points = [try point("2026-11-15", "88"), try point("2026-11-16", "39.5")]
        let today = MerchantR1Today.make(revenue7d: points, pendingOrders: 3, now: now, calendar: calendar)
        XCTAssertEqual(today.income, "¥39.50")
        XCTAssertEqual(today.pending, "3")
    }

    func testTodayIncomeAcceptsShortDates() throws {
        XCTAssertEqual(MerchantR1Today.todayIncome([try point("11-16", "12")], now: now, calendar: calendar), "¥12.00")
    }

    func testUnknownTodayNumbersAreDashes() throws {
        let today = MerchantR1Today.make(revenue7d: [try point("2026-11-15", "88")], pendingOrders: nil, now: now, calendar: calendar)
        XCTAssertEqual(today.income, "—")
        XCTAssertEqual(today.pending, "—")
        XCTAssertEqual(today.redemptions, "—", "the server has no date-scoped redemption count yet")
    }

    func testStatusColoursFollowTheMerchantRule() {
        XCTAssertEqual(MerchantR1Status.needsMe.tone, .warning)
        XCTAssertEqual(MerchantR1Status.waiting.tone, .neutral)
        XCTAssertEqual(MerchantR1Status.waiting.symbol, "clock")
        XCTAssertEqual(MerchantR1Status.live.tone, .success)
        XCTAssertEqual(MerchantR1Status.failed.tone, .danger)
        XCTAssertFalse(MerchantR1Status.allCases.contains { $0.tone == .info }, "blue is not used")
    }

    func testUnknownMerchantValuesReadAsDash() {
        XCTAssertEqual(merchantR1Value(nil), "—")
        XCTAssertEqual(merchantR1Value(" "), "—")
    }
}
