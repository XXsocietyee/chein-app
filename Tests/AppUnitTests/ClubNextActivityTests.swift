import XCTest
@testable import Questify

/// mp-club r3 pass 51 (P38): the club Overview's next-activity card picks from the same rows as the 活动 tab.
final class ClubNextActivityTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_691_200)
    private func row(_ id: Int, start: String?, end: String? = nil) -> ClubActivityRow {
        var fields: [String: ClubGovernanceValue] = ["name": .string("Topic \(id)")]
        if let start { fields["startDate"] = .string(start) }
        if let end { fields["endDate"] = .string(end) }
        return ClubActivityRow(value: .object(fields), id: id, now: now)
    }

    func testPicksEarliestCurrentTopicAndSkipsEndedOnes() {
        let rows = [
            row(1, start: "2026-12-20 10:00:00"),
            row(2, start: "2026-01-01 10:00:00", end: "2026-01-02 10:00:00"),
            row(3, start: "2026-12-05 09:00:00"),
            row(4, start: nil)
        ]
        XCTAssertEqual(rows[1].status, .ended)
        XCTAssertEqual(ClubNextActivity.pick(rows)?.id, 3)
    }

    func testTopicsWithoutStartComeLastAndEmptyListHasNoCard() {
        XCTAssertEqual(ClubNextActivity.pick([row(7, start: nil), row(8, start: nil)])?.id, 7)
        XCTAssertEqual(ClubNextActivity.pick([row(7, start: nil), row(9, start: "2026-12-30 08:00:00")])?.id, 9)
        XCTAssertNil(ClubNextActivity.pick([]))
        XCTAssertNil(ClubNextActivity.pick([row(2, start: "2026-01-01 10:00:00", end: "2026-01-02 10:00:00")]))
    }
}
