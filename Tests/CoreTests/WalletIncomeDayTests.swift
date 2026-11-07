import XCTest
@testable import QuestifyCore

final class WalletIncomeDayTests: XCTestCase {
    private let calendar = WalletIncomeDay.serverCalendar
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 0, minute: 30))! }
    func testTodayYesterdayAndMonthDayAcrossMonthBoundary() {
        XCTAssertEqual(WalletIncomeDay.make("2026-03-01 00:10:00", now: now, calendar: calendar), .today)
        XCTAssertEqual(WalletIncomeDay.make("2026-02-28 23:59:59", now: now, calendar: calendar), .yesterday)
        XCTAssertEqual(WalletIncomeDay.make("2026-02-27", now: now, calendar: calendar), .monthDay(month: 2, day: 27))
        XCTAssertEqual(WalletIncomeDay.make("2025-12-31 08:00:00", now: now, calendar: calendar), .monthDay(month: 12, day: 31))
    }
    func testInvalidDatesStayUnformatted() {
        for raw in [nil, "", "2026-02-30 10:00:00", "26-03-01", "2026/03/01", "today"] {
            XCTAssertNil(WalletIncomeDay.make(raw, now: now, calendar: calendar), raw ?? "nil")
        }
    }
    func testGroupRowsGroupsByServerCivilDayAndPreservesRowOrder() throws {
        let payload = """
        [
          {"id":101,"changeBalance":"50.00","changeType":1,"createTime":"2026-03-01 00:20:00","currency":"CNY"},
          {"id":102,"changeBalance":"-12.00","changeType":2,"createTime":"2026-03-01 00:05:00","currency":"CNY"},
          {"id":103,"changeBalance":"88.00","changeType":1,"createTime":"2026-02-28 21:00:00","currency":"CNY"},
          {"id":104,"changeBalance":"10.00","changeType":1,"createTime":"2026-02-15 09:00:00","currency":"CNY"}
        ]
        """
        let rows = try JSONDecoder().decode([WalletLedgerRow].self, from: Data(payload.utf8))
        let groups = WalletIncomeDay.group(rows, now: now, calendar: calendar)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].day, .today)
        XCTAssertEqual(groups[0].rows.map(\.id), [101, 102])
        XCTAssertEqual(groups[0].headerText(isEnglish: true), "Today")
        XCTAssertEqual(groups[0].headerText(isEnglish: false), "今天")
        XCTAssertEqual(groups[1].day, .yesterday)
        XCTAssertEqual(groups[1].rows.map(\.id), [103])
        XCTAssertEqual(groups[1].headerText(isEnglish: true), "Yesterday")
        XCTAssertEqual(groups[1].headerText(isEnglish: false), "昨天")
        XCTAssertEqual(groups[2].day, .monthDay(month: 2, day: 15))
        XCTAssertEqual(groups[2].rows.map(\.id), [104])
        XCTAssertEqual(groups[2].headerText(isEnglish: true), "Feb 15")
        XCTAssertEqual(groups[2].headerText(isEnglish: false), "2月15日")
    }
}
