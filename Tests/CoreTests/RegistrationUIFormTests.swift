import Foundation
import XCTest
@testable import QuestifyCore

final class RegistrationUIFormTests: XCTestCase {
    func testSourceContactValidationAndTrimming() {
        XCTAssertEqual(RegistrationUIFormDraft().validation, .nameRequired)
        XCTAssertEqual(RegistrationUIFormDraft(realName: "Fixture").validation, .phoneRequired)
        for phone in ["138****1234", "+8613800000000", "２３４５６７８９０１２", "23800000000", "1380000000", "138000000000"] {
            XCTAssertEqual(RegistrationUIFormDraft(realName: "Fixture", phone: phone).validation, .invalidPhone)
        }
        let draft = RegistrationUIFormDraft(realName: " Fixture Guest \n", phone: " 13800000000 ")
        XCTAssertNil(draft.validation)
        XCTAssertEqual(draft.participantDetails.realName, "Fixture Guest")
        XCTAssertEqual(draft.participantDetails.phone, "13800000000")
        XCTAssertNil(draft.participantDetails.email)
        XCTAssertNil(draft.participantDetails.participateDate)
        XCTAssertTrue(draft.participantDetails.usesAppPaymentChannel)
    }
    func testMissingMoneyAndCurrencyStayUnknownWhileYuanDeductionsKeepCNY() {
        XCTAssertNil(RegistrationUIMoney.display(nil, locale: Locale(identifier: "en_US")))
        XCTAssertNil(RegistrationUIMoney.display(-1, locale: Locale(identifier: "en_US")))
        XCTAssertEqual(RegistrationUIMoney.yuanCurrencyCode, "CNY")
        XCTAssertEqual(RegistrationUIMoney.display(.zero, locale: Locale(identifier: "en_US")), "0.00")
        let en = RegistrationUIMoney.display(.zero, locale: Locale(identifier: "en_US"), currencyCode: RegistrationUIMoney.yuanCurrencyCode)
        XCTAssertNotNil(en)
        XCTAssertTrue(en?.contains("0.00") == true)
        XCTAssertTrue(en?.contains("CN") == true || en?.contains("CNY") == true || en?.contains("¥") == true)
        let zh = RegistrationUIMoney.display(12.5, locale: Locale(identifier: "zh_Hans_CN"), currencyCode: RegistrationUIMoney.yuanCurrencyCode)
        XCTAssertTrue(zh?.contains("12.50") == true)
    }
    /// Owner 2026-11-24: one shared MoneyDisplay, two decimals (¥12.50). The live switch stays `.twoDecimals`.
    func testMoneyDisplaySwitchDefaultsToCurrentTwoDecimals() throws {
        XCTAssertEqual(MoneyDisplay.current, .twoDecimals)
        XCTAssertEqual(MoneyDisplay.minimumFractionDigits(), 2)
        for (value, expected) in [("29.9", "29.90"), ("39", "39.00"), ("1200", "1200.00"), ("0.01", "0.01"), ("12.35", "12.35"), ("12.345", "12.35"), ("0", "0.00"), ("-15.4", "-15.40")] {
            XCTAssertEqual(MoneyDisplay.plain(try XCTUnwrap(Decimal(string: value)), rule: .twoDecimals), expected, value)
        }
        XCTAssertEqual(MoneyDisplay.yuan(try XCTUnwrap(Decimal(string: "39"))), "¥39.00")
        for (raw, expected) in [("29.9", "29.90"), ("39", "39.00"), ("39.000", "39.00"), ("0.01", "0.01"), ("+5.5", "+5.50"), ("12.345", "12.345"), ("n/a", "n/a")] {
            XCTAssertEqual(MoneyDisplay.text(raw, rule: .twoDecimals), expected, raw)
        }
    }
    /// chengyin-ios `fix/owner-decisions-1122` cases, run against the `.oneDecimal` rule explicitly.
    func testMoneyDisplayOneDecimalRuleUsesOneDecimalUnlessTheSecondIsNonZero() throws {
        XCTAssertEqual(MoneyDisplay.minimumFractionDigits(.oneDecimal), 1)
        for (value, expected) in [("29.9", "29.9"), ("39", "39.0"), ("1200", "1200.0"), ("0.01", "0.01"), ("12.35", "12.35"), ("0", "0.0"), ("-15.4", "-15.4"), ("-39", "-39.0")] {
            XCTAssertEqual(MoneyDisplay.plain(try XCTUnwrap(Decimal(string: value)), rule: .oneDecimal), expected, value)
        }
        XCTAssertEqual(MoneyDisplay.yuan(try XCTUnwrap(Decimal(string: "39")), rule: .oneDecimal), "¥39.0")
        for (raw, expected) in [("29.90", "29.9"), ("39", "39.0"), ("39.00", "39.0"), ("1200.00", "1200.0"), ("0.01", "0.01"), ("12.35", "12.35"),
                                ("0", "0.0"), ("0.00", "0.0"), ("-12.00", "-12.0"), ("-0.01", "-0.01"), ("+5.50", "+5.5"), ("12.345", "12.345"), ("n/a", "n/a")] {
            XCTAssertEqual(MoneyDisplay.text(raw, rule: .oneDecimal), expected, raw)
        }
    }
    func testOnlyVerifiedRegistrationLabelsAndCreationDisabledByDefault() {
        XCTAssertFalse(RegistrationUICreationPolicy.disabled.permitsCreation)
        XCTAssertTrue(RegistrationUICreationPolicy.free.permitsCreation)
        XCTAssertTrue(RegistrationUICreationPolicy.free.recordsServerConsent)
        XCTAssertFalse(RegistrationUICreationPolicy.disabled.recordsServerConsent)
        XCTAssertEqual(RegistrationUIStatus.registrationKey(1), "registration.form.awaitingPayment")
        XCTAssertEqual(RegistrationUIStatus.registrationKey(2), "registration.form.registered")
        XCTAssertEqual(RegistrationUIStatus.registrationKey(3), "registration.form.cancelled")
        XCTAssertEqual(RegistrationUIStatus.registrationKey(4), "registration.form.expired")
        XCTAssertEqual(RegistrationUIStatus.registrationKey(nil), "registration.form.unknownStatus")
        XCTAssertEqual(RegistrationUIStatus.registrationKey(99), "registration.form.unknownStatus")
    }
    func testSoldOutGuidanceUsesRealCapabilityAndCurrentEligibleOffer() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func status(_ state: String, eligibility: String = "ELIGIBLE", deadline: Date? = nil) throws -> RegistrationWaitlistStatus {
            let expiry = ISO8601DateFormatter().string(from: deadline ?? now.addingTimeInterval(300))
            let json = """
            {"id":9,"activityId":8,"ticketId":7,"memberId":6,"state":"\(state)",
             "eligibilityState":"\(eligibility)","waitlistJoinAllowed":\(eligibility == "ELIGIBLE"),
             "offerExpiresAt":"\(expiry)","offerToken":"synthetic-offer"}
            """
            return try JSONDecoder().decode(RegistrationWaitlistStatus.self, from: Data(json.utf8))
        }
        let waiting = try status("WAITING"), offered = try status("OFFERED")
        for value in [nil, waiting, offered] {
            XCTAssertEqual(RegistrationUIWaitlistGuidance.soldOutKey(available: false, status: value, outcomeUnknown: false, now: now), "registration.form.soldOutHint")
        }
        XCTAssertEqual(RegistrationUIWaitlistGuidance.soldOutKey(available: true, status: waiting, outcomeUnknown: false, now: now), "registration.form.soldOutWaiting")
        XCTAssertEqual(RegistrationUIWaitlistGuidance.soldOutKey(available: true, status: offered, outcomeUnknown: false, now: now), "registration.form.soldOutOffer")
        XCTAssertEqual(RegistrationUIWaitlistGuidance.soldOutKey(available: true, status: offered, outcomeUnknown: false, now: now.addingTimeInterval(300)), "registration.form.soldOutAvailable")
        for value in [nil, try status("CANCELLED"), try status("EXPIRED"), try status("OFFERED", deadline: now), try status("OFFERED", eligibility: "BLOCKED")] {
            XCTAssertEqual(RegistrationUIWaitlistGuidance.soldOutKey(available: true, status: value, outcomeUnknown: false, now: now), "registration.form.soldOutAvailable")
        }
        XCTAssertEqual(RegistrationUIWaitlistGuidance.soldOutKey(available: true, status: offered, outcomeUnknown: true, now: now), "registration.waitlist.unknown")
    }

}
