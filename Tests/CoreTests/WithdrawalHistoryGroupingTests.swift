#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class WithdrawalHistoryGroupingTests: XCTestCase {
    private func row(_ id: Int, _ time: String?) -> WithdrawalHistoryRow {
        WithdrawalHistoryRow(id: id, status: .processing, receivedAmount: 1, createTime: time)
    }
    func testDayKeyUsesChinaCalendarForBareAndOffsetTimes() {
        XCTAssertEqual(WithdrawalHistoryGrouping.dayKey("2026-11-05 23:30:00"), "2026-11-05")
        XCTAssertEqual(WithdrawalHistoryGrouping.dayKey("2026-11-05 00:00:00"), "2026-11-05")
        // 17:00Z is 01:00 the next day in China.
        XCTAssertEqual(WithdrawalHistoryGrouping.dayKey("2026-11-05T17:00:00Z"), "2026-11-06")
        XCTAssertEqual(WithdrawalHistoryGrouping.dayKey("2024-02-29 12:00:00"), "2024-02-29")
        XCTAssertNil(WithdrawalHistoryGrouping.dayKey(nil))
        XCTAssertNil(WithdrawalHistoryGrouping.dayKey("not a time"))
    }
    func testGroupsKeepServerOrderAndPutUndatedLast() {
        let rows = [row(1, "2026-11-05 23:30:00"), row(2, nil), row(3, "2026-11-05 08:00:00"),
                    row(4, "2026-11-04 12:00:00")]
        let groups = WithdrawalHistoryGrouping.groups(rows)
        XCTAssertEqual(groups.map(\.dayKey), ["2026-11-05", "2026-11-04", nil])
        XCTAssertEqual(groups[0].rows.compactMap(\.id), [1, 3])
        XCTAssertEqual(groups[1].rows.compactMap(\.id), [4])
        XCTAssertEqual(groups[2].rows.compactMap(\.id), [2])
    }
    func testEmptyInputHasNoGroups() {
        XCTAssertTrue(WithdrawalHistoryGrouping.groups([]).isEmpty)
    }
}
#endif
