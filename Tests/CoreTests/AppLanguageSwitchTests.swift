import XCTest
@testable import QuestifyCore

final class AppLanguageSwitchTests: XCTestCase {
    private func makeDefaults() throws -> (UserDefaults, () -> Void) {
        let name = "AppLanguageSwitchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    func testSelectingEachLanguageChangesResolvedLanguageAndPersistsAcrossNewReads() throws {
        let (defaults, cleanup) = try makeDefaults(); defer { cleanup() }
        for market in RegionalMarket.allCases {
            for choice in [AppLanguage.english, .simplifiedChinese, .system] {
                AppLanguagePreference(defaults: defaults, market: market).select(choice)
                // A brand-new preference object (as after a relaunch) sees the same explicit choice.
                XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: market).language, choice)
                XCTAssertEqual(defaults.string(forKey: "preferences.language"), choice.rawValue)
            }
        }
    }

    func testSwitchingChangesResolvedStringLanguage() {
        XCTAssertTrue(AppLanguage.simplifiedChinese.isChinese(systemLanguageCode: "en"))
        XCTAssertFalse(AppLanguage.english.isChinese(systemLanguageCode: "zh-Hans"))
        XCTAssertTrue(AppLanguage.system.isChinese(systemLanguageCode: "zh-Hans"))
        XCTAssertFalse(AppLanguage.system.isChinese(systemLanguageCode: "en"))
    }

    /// One-app (owner 2026-11-27): with no stored choice the phone decides (zh* → zh-Hans, else English),
    /// for every market; the derived default is never written; an explicit choice (System included) wins.
    func testFirstLaunchFollowsThePhoneAndExplicitChoiceSurvives() throws {
        let (defaults, cleanup) = try makeDefaults(); defer { cleanup() }
        for market in [RegionalMarket.china, .unitedStates, nil] {
            XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: market, preferredLanguages: ["zh-Hans-US"]).language, .simplifiedChinese)
            XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: market, preferredLanguages: ["zh-HK"]).language, .simplifiedChinese)
            XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: market, preferredLanguages: ["en-CN"]).language, .english)
            XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: market, preferredLanguages: ["ja-JP", "zh-Hans"]).language, .english)
            XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: market, preferredLanguages: []).language, .english)
        }
        XCTAssertNil(defaults.string(forKey: AppLanguage.storageKey))
        // Explicit System is a stored choice, not "unset": the phone default must not replace it.
        AppLanguagePreference(defaults: defaults, market: .china).select(.system)
        XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: .china, preferredLanguages: ["en-US"]).language, .system)
        AppLanguagePreference(defaults: defaults, market: .unitedStates).select(.english)
        XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: .unitedStates, preferredLanguages: ["zh-Hans"]).language, .english)
    }

    func testStorageKeyIsTheSettingsKey() {
        XCTAssertEqual(AppLanguage.storageKey, "preferences.language")
    }
}
