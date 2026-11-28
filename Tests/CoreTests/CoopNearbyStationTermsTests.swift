#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// MP `pages/coop/nearby/index.js` `stationTermsText`: each 可承接 chapter label carries its station terms tier.
final class CoopNearbyStationTermsTests: XCTestCase {
    private func row(_ fields: [String: MerchantContentValue]) -> MerchantContentValue { .object(fields) }

    func testTrafficTier() {
        let terms = CoopNearbyStationTerms(row: row(["termsMode": .string("TRAFFIC")]))
        XCTAssertEqual(terms, .traffic)
        XCTAssertEqual(CoopNearbyStationTerms.label(chapter: "灯笼巷", terms: terms, chinese: true), "灯笼巷(引流档 · 到店打卡)")
        XCTAssertEqual(CoopNearbyStationTerms.label(chapter: "Lantern Lane", terms: terms, chinese: false),
                       "Lantern Lane (traffic tier · in-store check-in)")
    }

    func testRevshareTierShowsTheClubCapAndZeroWhenMissing() {
        let terms = CoopNearbyStationTerms(row: row(["termsMode": .string("REVSHARE"), "maxPerHeadFee": .decimal(Decimal(string: "8.5")!)]))
        XCTAssertEqual(terms?.text(chinese: true), "(计酬档 · 俱乐部付 ≤ ¥8.50 / 人次)")
        let missing = CoopNearbyStationTerms(row: row(["termsMode": .string("REVSHARE")]))
        XCTAssertEqual(missing?.text(chinese: true), "(计酬档 · 俱乐部付 ≤ ¥0.00 / 人次)")
        let text = CoopNearbyStationTerms(row: row(["termsMode": .string("REVSHARE"), "maxPerHeadFee": .string("12")]))
        XCTAssertEqual(text?.text(chinese: false), " (paid tier · club pays up to ¥12.00 per visit)")
    }

    func testPerkTierShowsTheThresholdOnlyWhenAboveZero() {
        let withValue = CoopNearbyStationTerms(row: row(["termsMode": .string("PERK"), "perkMinValue": .integer(20)]))
        XCTAssertEqual(withValue?.text(chinese: true), "(权益档 · ≥ ¥20.00 权益)")
        let zero = CoopNearbyStationTerms(row: row(["termsMode": .string("PERK"), "perkMinValue": .integer(0)]))
        XCTAssertEqual(zero?.text(chinese: true), "(权益档)")
        let garbage = CoopNearbyStationTerms(row: row(["termsMode": .string("PERK"), "perkMinValue": .string("abc")]))
        XCTAssertEqual(garbage?.text(chinese: false), " (perk tier)")
    }

    func testUnknownOrMissingModeHasNoSuffix() {
        XCTAssertNil(CoopNearbyStationTerms(row: row([:])))
        XCTAssertNil(CoopNearbyStationTerms(row: row(["termsMode": .string("OTHER")])))
        XCTAssertEqual(CoopNearbyStationTerms.label(chapter: "灯笼巷", terms: nil, chinese: true), "灯笼巷")
    }
}
#endif
