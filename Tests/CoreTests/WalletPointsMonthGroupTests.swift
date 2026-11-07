import XCTest
@testable import QuestifyCore

final class WalletPointsMonthGroupTests: XCTestCase {
    private func rows() throws -> [WalletLedgerRow] {
        let payload = """
        [
          {"id":5,"changePoints":"10","changeType":1,"createTime":"2026-11-02 10:00:00"},
          {"id":4,"changePoints":"3","changeType":2,"createTime":"2026-11-01 09:00:00"},
          {"id":3,"changePoints":"8","changeType":1,"createTime":"2026-10-30 09:00:00"},
          {"id":2,"changePoints":"1","changeType":1,"createTime":"not a time"},
          {"id":1,"changePoints":"2","changeType":1,"createTime":"2026-10-01 09:00:00"}
        ]
        """
        return try JSONDecoder().decode([WalletLedgerRow].self, from: Data(payload.utf8))
    }
    func testMonthKeyValidation() {
        XCTAssertEqual(WalletPointsMonthGroup.monthKey("2026-11-02 10:00:00"), "2026-11")
        XCTAssertEqual(WalletPointsMonthGroup.monthKey(" 2026-01"), "2026-01")
        for raw in [nil, "", "2026-13-01", "2026-00-01", "26-11-02", "abcd-ef", "2026/11/02"] {
            XCTAssertNil(WalletPointsMonthGroup.monthKey(raw), raw ?? "nil")
        }
    }
    func testGroupsAdjacentMonthsKeepsOrderAndNeverDropsUnknownTime() throws {
        let groups = WalletPointsMonthGroup.group(try rows())
        XCTAssertEqual(groups.map { $0.rows.map(\.id) }, [[5, 4], [3], [2], [1]])
        XCTAssertEqual(groups.map(\.monthKey), ["2026-11", "2026-10", nil, "2026-10"])
        XCTAssertEqual(Set(groups.map(\.id)).count, groups.count)
        XCTAssertEqual(groups.flatMap(\.rows).count, 5)
    }
    func testHeaderTextBothLanguages() throws {
        let groups = WalletPointsMonthGroup.group(try rows())
        XCTAssertEqual(groups[0].headerText(isEnglish: false), "2026年11月")
        XCTAssertEqual(groups[0].headerText(isEnglish: true), "Nov 2026")
        XCTAssertEqual(groups[2].headerText(isEnglish: false), "时间未知")
        XCTAssertEqual(groups[2].headerText(isEnglish: true), "Unknown time")
    }
    func testEmptyInput() { XCTAssertTrue(WalletPointsMonthGroup.group([]).isEmpty) }
}
