import XCTest
@testable import Questify

final class ActivityCalendarDraftTests: XCTestCase {
    private func summary(start: String?, end: String?, addressName: String? = "老城门") throws -> ActivitySummary {
        var json: [String: Any] = ["id": 7, "name": "西湖夜游"]
        if let start { json["startDate"] = start }
        if let end { json["endDate"] = end }
        if let addressName { json["addressName"] = addressName }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(ActivitySummary.self, from: data)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testUpcomingActivityGivesTitleRangeAndPlace() throws {
        let draft = ActivityCalendarDraft.make(summary: try summary(start: "2027-01-15T10:00:00Z", end: "2027-01-15T12:00:00Z"), now: now)
        XCTAssertEqual(draft?.title, "西湖夜游")
        XCTAssertEqual(draft?.location, "老城门")
        XCTAssertEqual(draft.map { $0.end.timeIntervalSince($0.start) }, 7200)
    }

    func testMissingEndDefaultsToOneHour() throws {
        let draft = ActivityCalendarDraft.make(summary: try summary(start: "2027-01-15T10:00:00Z", end: nil), now: now)
        XCTAssertEqual(draft.map { $0.end.timeIntervalSince($0.start) }, 3600)
    }

    func testEndedOrUndatedActivityOffersNoCalendarAction() throws {
        XCTAssertNil(ActivityCalendarDraft.make(summary: try summary(start: "2020-01-15T10:00:00Z", end: "2020-01-15T12:00:00Z"), now: now))
        XCTAssertNil(ActivityCalendarDraft.make(summary: try summary(start: nil, end: nil), now: now))
    }
}
