import XCTest
@testable import QuestifyCore

/// i18n r2 locale lane: the `locale:` overloads keep Chinese byte-identical and read naturally in English.
/// ICU spacing (narrow no-break spaces) varies by OS, so English checks use `contains`.
final class LocaleDisplayR2Tests: XCTestCase {
    private let zh = Locale(identifier: "zh_Hans_CN")
    private let us = Locale(identifier: "en_US")
    private var instant: Date { Date(timeIntervalSince1970: 1_795_791_900) } // 2026-11-27 15:05:00 UTC

    func testOccurrenceClockKeepsChineseAndLocalizesEnglishOnTheSameWallClock() {
        let value = ClubGovernanceValue.string("2026-11-27 15:05:00")
        XCTAssertEqual(ClubOccurrenceClock.display(value, locale: zh), ClubOccurrenceClock.display(value))
        XCTAssertEqual(ClubOccurrenceClock.display(value, locale: zh), "2026-11-27 15:05")
        let english = ClubOccurrenceClock.display(value, locale: us) ?? ""
        XCTAssertTrue(english.contains("Nov 27, 2026"), english)
        XCTAssertTrue(english.contains("3:05"), english)
        XCTAssertNil(ClubOccurrenceClock.display(.null, locale: us))
    }

    func testOrderLifecycleTimeKeepsChineseAndLocalizesEnglish() {
        XCTAssertEqual(OrderLifecycleTime.display("2026-11-27 15:05:00", locale: zh), "2026-11-27 15:05")
        let english = OrderLifecycleTime.display("2026-11-27 15:05:00", locale: us) ?? ""
        XCTAssertTrue(english.contains("Nov 27, 2026"), english)
        XCTAssertTrue(english.contains("3:05"), english)
        XCTAssertNil(OrderLifecycleTime.display(nil, locale: us))
    }

    func testJourneyMonthDayTimeStaysInBeijingTime() {
        XCTAssertEqual(JourneyDateFormatterHelper.monthDayTime(instant, locale: zh), JourneyDateFormatterHelper.monthDayTime(instant))
        let english = JourneyDateFormatterHelper.monthDayTime(instant, locale: us)
        XCTAssertTrue(english.contains("Nov 27"), english)
        XCTAssertTrue(english.contains("11:05"), english) // 15:05 UTC is 23:05 in Beijing
        XCTAssertFalse(english.contains("月"), english)
    }

    func testCivilRendersRailAndDeadlineTextInEnglishOnly() {
        XCTAssertEqual(LocaleDisplay.civil("2026-11-27 15:05", locale: zh), "2026-11-27 15:05")
        XCTAssertTrue(LocaleDisplay.civil("2026-11-27 15:05", locale: us).contains("Nov 27, 2026"))
        XCTAssertEqual(LocaleDisplay.civil("今晚", locale: us), "今晚")
    }

    func testQuoteServiceWindowFollowsTheLocale() throws {
        let json = #"{"serviceStartAt":1767225600,"serviceEndAt":1767232800}"#
        let delivery = try JSONDecoder().decode(RegistrationQuoteDelivery.self, from: Data(json.utf8))
        XCTAssertEqual(delivery.windowText(locale: zh), "2026.01.01 08:00 – 2026.01.01 10:00")
        XCTAssertEqual(delivery.windowText(locale: zh), delivery.windowText(zh: true))
        let english = try XCTUnwrap(delivery.windowText(locale: us))
        XCTAssertTrue(english.contains("Jan 1, 2026"), english)
        XCTAssertTrue(english.contains("8:00"), english)
        XCTAssertFalse(english.contains("2026.01.01"), english)
    }

    func testYuanAmountsRelabelsOnlyOutsideChineseAndNeverTwice() {
        let line = "Fixed fee · ¥30 per check-in"
        XCTAssertEqual(LocaleDisplay.yuanAmounts(in: "固定型 · ¥30 / 核销人头", locale: zh), "固定型 · ¥30 / 核销人头")
        let english = LocaleDisplay.yuanAmounts(in: line, locale: us)
        XCTAssertTrue(english.contains("CN¥30.00"), english)
        XCTAssertEqual(LocaleDisplay.yuanAmounts(in: english, locale: us), english)
        XCTAssertEqual(LocaleDisplay.yuanAmounts(in: "—", locale: us), "—")
        let pair = LocaleDisplay.yuanAmounts(in: "¥1.2（6%） ¥18.8", locale: us)
        XCTAssertTrue(pair.contains("CN¥1.20"), pair)
        XCTAssertTrue(pair.contains("CN¥18.80"), pair)
    }

    func testDistanceArgumentKeepsChineseTextAndUsesMilesInTheUS() {
        XCTAssertEqual(LocaleDisplay.distanceArgument(meters: 1200, zhText: "1.2 公里", locale: zh), "1.2 公里")
        let english = LocaleDisplay.distanceArgument(meters: 1200, zhText: "1.2 公里", locale: us)
        XCTAssertTrue(english.contains("mi"), english)
        XCTAssertFalse(english.contains("公里"), english)
    }
}
