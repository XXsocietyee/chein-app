import XCTest
import SwiftUI
@testable import Questify

@MainActor
final class LanguageSwitcherTests: XCTestCase {
    func testSwitcherBindsToTheSameKeyAsSettingsAndTheAppRoot() {
        XCTAssertEqual(LanguageSwitcher.storageKey, AppLanguage.storageKey)
        XCTAssertEqual(LanguageSwitcher.storageKey, "preferences.language")
    }

    func testStoredChoiceResolvesThroughTheLaunchConfigurationAndLeavesMarketDefaultsAlone() {
        XCTAssertEqual(RegionalLaunchConfiguration.language("en"), RegionalLaunchConfiguration.market?.language(storedValue: "en") ?? .english)
        XCTAssertEqual(RegionalLaunchConfiguration.language("zh-Hans"), .simplifiedChinese)
        // One-app (owner 2026-11-27): no stored choice follows the phone, whatever the market.
        XCTAssertEqual(RegionalMarket.china.language(storedValue: nil, preferredLanguages: ["zh-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(RegionalMarket.china.language(storedValue: nil, preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(RegionalMarket.unitedStates.language(storedValue: nil, preferredLanguages: ["en-US"]), .english)
        XCTAssertEqual(RegionalMarket.unitedStates.language(storedValue: nil, preferredLanguages: ["zh-Hant-TW"]), .simplifiedChinese)
        XCTAssertEqual(RegionalLaunchConfiguration.language(nil), AppLanguage.deviceDefault())
    }

    func testEnvironmentModifierPublishesTheActiveLanguage() {
        defer { AppLanguageRuntime.active = nil }
        XCTAssertEqual(AppLanguageEnvironment.apply(stored: "zh-Hans"), .simplifiedChinese)
        XCTAssertEqual(AppLanguageRuntime.active, .simplifiedChinese)
        XCTAssertEqual(AppLanguageEnvironment.apply(stored: "en"), .english)
        XCTAssertEqual(AppLanguageRuntime.active, .english)
    }
}
