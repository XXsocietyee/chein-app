import XCTest
@testable import QuestifyCore

final class Port2MerchantPerkTemplateFormTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private func valid() -> MerchantPerkTemplateDraft {
        var d = MerchantPerkTemplateDraft(); d.name = "Coffee"; d.retailValue = "20"; d.quota = "5"; return d
    }
    func testFieldOrder() {
        var d = MerchantPerkTemplateDraft()
        XCTAssertEqual(MerchantPerkTemplateFormPort.firstInvalidField(d, validEnd: "", now: now), .name)
        d.name = "x"; XCTAssertEqual(MerchantPerkTemplateFormPort.firstInvalidField(d, validEnd: "", now: now), .retailValue)
        d.retailValue = "0"; XCTAssertEqual(MerchantPerkTemplateFormPort.firstInvalidField(d, validEnd: "", now: now), .retailValue)
        d.retailValue = "12.5"; XCTAssertEqual(MerchantPerkTemplateFormPort.firstInvalidField(d, validEnd: "", now: now), .quota)
        d.quota = "3"; d.unitCost = "abc"; XCTAssertEqual(MerchantPerkTemplateFormPort.firstInvalidField(d, validEnd: "", now: now), .unitCost)
        d.unitCost = "1.5"; XCTAssertNil(MerchantPerkTemplateFormPort.firstInvalidField(d, validEnd: "", now: now))
    }
    func testValidityMustBeTomorrowOrLater() {
        let tomorrow = MerchantPerkValidityDraft.wire(MerchantPerkValidityDraft.minimum(now: now))
        let today = MerchantPerkValidityDraft.wire(now)
        XCTAssertNil(MerchantPerkTemplateFormPort.firstInvalidField(valid(), validEnd: tomorrow, now: now))
        XCTAssertEqual(MerchantPerkTemplateFormPort.firstInvalidField(valid(), validEnd: today, now: now), .validEnd)
        XCTAssertEqual(MerchantPerkTemplateFormPort.firstInvalidField(valid(), validEnd: "2026-13-40", now: now), .validEnd)
    }
    func testDirty() {
        XCTAssertFalse(MerchantPerkTemplateFormPort.isDirty(MerchantPerkTemplateDraft(), validEndEnabled: false))
        XCTAssertTrue(MerchantPerkTemplateFormPort.isDirty(valid(), validEndEnabled: false))
        XCTAssertTrue(MerchantPerkTemplateFormPort.isDirty(MerchantPerkTemplateDraft(), validEndEnabled: true))
    }
}
