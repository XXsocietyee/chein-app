import XCTest
@testable import QuestifyCore

/// Components r1 (C2): widget section values stay display-only and the streak counts calendar days.
final class QuestWidgetBoardTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func day(_ offset: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    func testStreakCountsBackFromTodayOrYesterday() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let stamps: [String] = [0, -1, -2, -4].map { QuestWidgetBoard.RoamDays.stamp(day($0, from: now), calendar: calendar) }
        let days = QuestWidgetBoard.RoamDays(days: stamps)
        XCTAssertEqual(days.streak(now: now, calendar: calendar), 3)
        XCTAssertEqual(days.streak(now: day(1, from: now), calendar: calendar), 3, "a streak that ended yesterday still counts")
        XCTAssertEqual(days.streak(now: day(2, from: now), calendar: calendar), 0)
        XCTAssertEqual(days.walkedCount(last: 7, now: now, calendar: calendar), 4)
    }

    func testDaysAreDedupedSortedAndCapped() {
        let stamps: [String] = (0..<100).map { String(format: "2026-%02d-%02d", 1 + $0 / 28, 1 + $0 % 28) }
        let days = QuestWidgetBoard.RoamDays(days: stamps + stamps)
        XCTAssertEqual(days.days.count, QuestWidgetBoard.RoamDays.keep)
        XCTAssertEqual(days.days, days.days.sorted())
        XCTAssertEqual(days.days.last, stamps.last)
    }

    func testCountersClampAndLinksFallBack() {
        let city = QuestWidgetBoard.CityProgress(cityName: nil, revealed: 1.7, stamps: -2)
        XCTAssertEqual(city.revealed, 1)
        XCTAssertEqual(city.stamps, 0)
        let community = QuestWidgetBoard.Community(unread: -1, clubName: nil, clubNewPosts: 3, clubID: nil)
        XCTAssertEqual(community.unread, 0)
        XCTAssertEqual(QuestWidgetBoard.ticket(nil), QuestWidgetBoard.myActivities)
        XCTAssertEqual(QuestWidgetBoard.club(0), QuestWidgetBoard.clubs)
        XCTAssertEqual(QuestWidgetBoard.ticket(7).absoluteString, "chein://ticket/7")
        XCTAssertNotNil(CheinDeepLink(url: QuestWidgetBoard.ticket(7)))
        for url in [QuestWidgetBoard.myActivities, QuestWidgetBoard.roamHistory, QuestWidgetBoard.messages,
                    QuestWidgetBoard.clubs, QuestWidgetBoard.club(3)] {
            XCTAssertNotNil(MiniProgramPageLink(cheinURL: url), url.absoluteString)
        }
    }

    func testEventLeavesTheWidgetThreeHoursAfterTheStart() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let event = QuestWidgetBoard.Event(title: "City run", startsAt: start, place: nil, ticketID: 7)
        XCTAssertEqual(event.expiresAt.timeIntervalSince(start), 3 * 60 * 60)
    }
}
