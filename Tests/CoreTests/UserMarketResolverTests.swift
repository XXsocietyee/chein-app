import XCTest
@testable import QuestifyCore

/// US launch r1, one-app (owner 2026-11-27): one binary, per-user market at runtime.
final class UserMarketResolverTests: XCTestCase {
    func testOrderIsAccountRegionThenSignInPhoneThenDeviceRegionThenBuild() {
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: "US", signInPhone: "+86", deviceRegion: "CN", buildDefault: .china), .unitedStates)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: "cn", signInPhone: "+1", deviceRegion: "US", buildDefault: .unitedStates), .china)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: nil, signInPhone: "+1", deviceRegion: "CN", buildDefault: .china), .unitedStates)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: "", signInPhone: "+86", deviceRegion: "US", buildDefault: .unitedStates), .china)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: "JP", signInPhone: nil, deviceRegion: "US", buildDefault: .china), .unitedStates)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: nil, signInPhone: nil, deviceRegion: "CN", buildDefault: .unitedStates), .china)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: nil, signInPhone: nil, deviceRegion: "GB", buildDefault: .unitedStates), .unitedStates)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: nil, signInPhone: nil, deviceRegion: "GB", buildDefault: .china), .china)
        XCTAssertEqual(UserMarketResolver.resolve(accountRegion: nil, signInPhone: nil, deviceRegion: nil, buildDefault: nil), .china)
    }

    func testPhoneValuesMapByCountryCode() {
        XCTAssertEqual(UserMarketResolver.market(phone: "+86"), .china)
        XCTAssertEqual(UserMarketResolver.market(phone: "+8613800138000"), .china)
        XCTAssertEqual(UserMarketResolver.market(phone: "13800138000"), .china)
        XCTAssertEqual(UserMarketResolver.market(phone: "+1"), .unitedStates)
        XCTAssertEqual(UserMarketResolver.market(phone: "+15551234567"), .unitedStates)
        XCTAssertNil(UserMarketResolver.market(phone: "+44"))
        XCTAssertNil(UserMarketResolver.market(phone: nil))
        XCTAssertEqual(UserMarketResolver.market(phone: PhoneCountryCode.china.dialCode), .china)
        XCTAssertEqual(UserMarketResolver.market(phone: PhoneCountryCode.unitedStates.dialCode), .unitedStates)
    }

    func testRegionCodes() {
        XCTAssertEqual(UserMarketResolver.market(region: " CHN "), .china)
        XCTAssertEqual(UserMarketResolver.market(region: "usa"), .unitedStates)
        XCTAssertNil(UserMarketResolver.market(region: "HK"))
    }

    func testAccountRegionDecodesFromUserInfo() throws {
        let withRegion = try JSONDecoder().decode(MemberIdentitySnapshot.self, from: Data(#"{"nickname":"a","region":"US"}"#.utf8))
        XCTAssertEqual(withRegion.accountRegion, "US")
        let withCountry = try JSONDecoder().decode(MemberIdentitySnapshot.self, from: Data(#"{"nickname":"a","countryCode":"CN"}"#.utf8))
        XCTAssertEqual(withCountry.accountRegion, "CN")
        let none = try JSONDecoder().decode(MemberIdentitySnapshot.self, from: Data(#"{"nickname":"a"}"#.utf8))
        XCTAssertNil(none.accountRegion)
    }
}
