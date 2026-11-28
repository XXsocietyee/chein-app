import XCTest
@testable import QuestifyCore

/// i18n r1 locale lane: Chinese output stays byte-identical to the owner-approved look; English output is
/// locale-formatted. ICU spacing (narrow no-break spaces) varies by OS, so English checks use `contains`.
final class LocaleDisplayTests: XCTestCase {
    private let zh = Locale(identifier: "zh_Hans_CN")
    private let us = Locale(identifier: "en_US")
    private let utc = TimeZone(secondsFromGMT: 0)!
    private var instant: Date { Date(timeIntervalSince1970: 1_795_791_900) } // 2026-11-27 15:05:00 UTC

    func testMoneyKeepsChineseLookAndNamesTheCurrencyInEnglish() throws {
        let amount = try XCTUnwrap(Decimal(string: "12.5"))
        XCTAssertEqual(LocaleDisplay.money(amount, locale: zh), "¥12.50")
        XCTAssertEqual(LocaleDisplay.money(fen: -255, locale: zh), "-¥2.55")
        let english = LocaleDisplay.money(amount, locale: us)
        // US r2: the event's currency keeps its own symbol under an English locale (never `CN¥`).
        XCTAssertTrue(english.contains("¥12.50"), english)
        XCTAssertFalse(english.contains("CN"), english)
        XCTAssertTrue(english.contains("12.50"), english)
        let dollars = LocaleDisplay.money(amount, currencyCode: "usd", locale: us)
        XCTAssertTrue(dollars.contains("$12.50"), dollars)
        XCTAssertFalse(dollars.contains("¥"), dollars)
        let dollarsInChinese = LocaleDisplay.money(amount, currencyCode: "USD", locale: zh)
        XCTAssertTrue(dollarsInChinese.contains("$12.50"), dollarsInChinese)
        XCTAssertFalse(dollarsInChinese.contains("US"), dollarsInChinese)
        XCTAssertEqual(LocaleDisplay.money(text: "39", locale: zh), "¥39.00")
        XCTAssertTrue(LocaleDisplay.money(text: "39", locale: us).contains("39.00"))
        XCTAssertEqual(LocaleDisplay.money(text: "待定", locale: us), "待定")
        XCTAssertEqual(LocaleDisplay.currencySymbol(locale: zh), "¥")
    }

    func testDatesKeepChinesePatternsAndLocalizeEnglish() {
        XCTAssertEqual(LocaleDisplay.dayTime(instant, locale: zh, timeZone: utc), "2026-11-27 15:05")
        XCTAssertEqual(LocaleDisplay.day(instant, locale: zh, timeZone: utc), "2026-11-27")
        XCTAssertEqual(LocaleDisplay.time(instant, locale: zh, timeZone: utc), "15:05")
        let english = LocaleDisplay.dayTime(instant, locale: us, timeZone: utc)
        XCTAssertTrue(english.contains("Nov 27, 2026"), english)
        XCTAssertTrue(english.contains("3:05"), english)
        XCTAssertTrue(english.contains("PM"), english)
        XCTAssertFalse(english.contains("年"), english)
        XCTAssertTrue(LocaleDisplay.monthDayTime(instant, locale: us, timeZone: utc).contains("Nov 27"))
        XCTAssertEqual(LocaleDisplay.monthDayTime(instant, locale: zh, timeZone: utc), "11月27日 15:05")
    }

    func testCivilServerTextIsReformattedWithoutShifting() {
        XCTAssertEqual(LocaleDisplay.civil("2026-11-27 23:30:00", locale: zh), "2026-11-27 23:30")
        XCTAssertEqual(LocaleDisplay.civil("2026-11-27T23:30:00", locale: zh), "2026-11-27 23:30")
        XCTAssertEqual(LocaleDisplay.civil("2026-11-27", locale: zh), "2026-11-27")
        let english = LocaleDisplay.civil("2026-11-27 23:30:00", locale: us)
        XCTAssertTrue(english.contains("Nov 27, 2026"), english)
        XCTAssertTrue(english.contains("11:30"), english)
        XCTAssertTrue(LocaleDisplay.civil("2026-11-27", locale: us).contains("Nov 27, 2026"))
        XCTAssertEqual(LocaleDisplay.civil("长期有效", locale: us), "长期有效")
        XCTAssertEqual(LocaleDisplay.civil("2026-13-40", locale: us), "2026-13-40")
    }

    func testDistanceUsesMilesInTheUSAndKilometresInChina() throws {
        let us1600 = try XCTUnwrap(LocaleDisplay.distance(meters: 1609.344, locale: us))
        XCTAssertTrue(us1600.contains("mi"), us1600)
        let cn = try XCTUnwrap(LocaleDisplay.distance(meters: 1500, locale: zh))
        XCTAssertTrue(cn.contains("1.5"), cn)
        XCTAssertFalse(cn.contains("mi"), cn)
        let gb = try XCTUnwrap(LocaleDisplay.distance(meters: 1500, locale: Locale(identifier: "en_CN")))
        XCTAssertTrue(gb.contains("km"), gb)
        XCTAssertNil(LocaleDisplay.distance(meters: -1, locale: us))
        XCTAssertNil(LocaleDisplay.distance(meters: .nan, locale: us))
        let radius = try XCTUnwrap(LocaleDisplay.radius(meters: 3000, locale: us))
        XCTAssertTrue(radius.contains("mi"), radius)
    }

    func testListsDurationsAndNames() throws {
        XCTAssertEqual(LocaleDisplay.list(["Alice", "Bob", "Cara"], locale: us), "Alice, Bob, and Cara")
        XCTAssertEqual(LocaleDisplay.list(["Alice", " ", "Bob"], locale: us), "Alice and Bob")
        let duration = try XCTUnwrap(LocaleDisplay.duration(seconds: 3900, locale: us))
        XCTAssertTrue(duration.contains("1") && duration.contains("5"), duration)
        XCTAssertNil(LocaleDisplay.duration(seconds: -1, locale: us))
        XCTAssertEqual(LocaleDisplay.personName(given: "Ming", family: "Li", locale: us), "Ming Li")
        XCTAssertEqual(LocaleDisplay.address(["上海市", "黄浦区", "南京东路1号"], locale: zh), "上海市黄浦区南京东路1号")
        XCTAssertEqual(LocaleDisplay.address(["Shanghai", "Huangpu", nil, "1 Nanjing Rd E"], locale: us), "1 Nanjing Rd E, Huangpu, Shanghai")
    }

    func testPhoneCountryCodesKeepTheChinaWireValue() {
        XCTAssertEqual(PhoneCountryCode.china.wireValue("13800138000"), "13800138000")
        XCTAssertNil(PhoneCountryCode.china.wireValue("23800138000"))
        XCTAssertEqual(PhoneCountryCode.unitedStates.wireValue("4155550132"), "+14155550132")
        XCTAssertNil(PhoneCountryCode.unitedStates.wireValue("1155550132"), "NANP area codes start 2-9")
        XCTAssertNil(PhoneCountryCode.unitedStates.wireValue("4151550132"), "NANP exchanges start 2-9")
        XCTAssertEqual(PhoneCountryCode.unitedStates.sanitize("+1 (415) 555-0132"), "4155550132")
        XCTAssertEqual(PhoneCountryCode.china.sanitize("+86 138 0013 8000"), "13800138000")
        XCTAssertEqual(PhoneCountryCode.unitedStates.display("4155550132"), "(415) 555-0132")
        XCTAssertEqual(PhoneCountryCode.china.display("13800138000"), "138 0013 8000")
        XCTAssertEqual(PhoneCountryCode.default(marketCode: "US"), .unitedStates)
        XCTAssertEqual(PhoneCountryCode.default(marketCode: "CN"), .china)
        XCTAssertEqual(PhoneCountryCode.default(marketCode: nil), .china)
    }

    /// US launch r1: region default, US grouping while typing, E.164 drafts and validation.
    func testUSLaunchPhoneEntryHelpers() {
        XCTAssertEqual(PhoneCountryCode.default(region: "US", marketCode: "CN"), .unitedStates)
        XCTAssertEqual(PhoneCountryCode.default(region: "CN", marketCode: "US"), .china)
        XCTAssertEqual(PhoneCountryCode.default(region: "GB", marketCode: "US"), .unitedStates)
        XCTAssertEqual(PhoneCountryCode.default(region: nil, marketCode: nil), .china)

        XCTAssertEqual(PhoneCountryCode.unitedStates.fieldText("5551234567"), "(555) 123-4567")
        XCTAssertEqual(PhoneCountryCode.unitedStates.fieldText("(555) 123-456"), "(555) 123-456")
        XCTAssertEqual(PhoneCountryCode.unitedStates.fieldText("+1 555 123 4567"), "(555) 123-4567")
        XCTAssertEqual(PhoneCountryCode.china.fieldText("138 0013 8000"), "13800138000")

        XCTAssertEqual(PhoneCountryCode.unitedStates.draftWire("(415) 555-0132"), "+14155550132")
        XCTAssertEqual(PhoneCountryCode.china.draftWire("13800138000"), "13800138000")
        XCTAssertEqual(PhoneCountryCode.unitedStates.draftWire(""), "")

        XCTAssertEqual(PhoneCountryCode.split(wire: "+14155550132").country, .unitedStates)
        XCTAssertEqual(PhoneCountryCode.split(wire: "+14155550132").national, "4155550132")
        XCTAssertEqual(PhoneCountryCode.split(wire: "13800138000").country, .china)
        XCTAssertEqual(PhoneCountryCode.split(wire: "138****8000").national, "138****8000")

        XCTAssertTrue(PhoneCountryCode.isValidUnitedStatesWire("+14155550132"))
        XCTAssertFalse(PhoneCountryCode.isValidUnitedStatesWire("+11155550132"))
        XCTAssertFalse(PhoneCountryCode.isValidUnitedStatesWire("4155550132"))

        var participant = ParticipantFormDraft(); participant.fullName = "Ada"
        participant.mobilePhone = "+14155550132"; XCTAssertNil(participant.validation)
        participant.mobilePhone = "+1415555"; XCTAssertEqual(participant.validation, .invalidPhone)
        participant.mobilePhone = "13800138000"; XCTAssertNil(participant.validation)
        XCTAssertNil(RegistrationUIFormDraft(realName: "Ada", phone: "+14155550132").validation)
        XCTAssertEqual(RegistrationUIFormDraft(realName: "Ada", phone: "+1415").validation, .invalidPhone)
    }
}
