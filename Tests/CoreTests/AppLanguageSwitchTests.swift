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

    func testFirstLaunchDefaultPerMarketIsUnchangedAndSystemChoiceSurvives() throws {
        let (defaults, cleanup) = try makeDefaults(); defer { cleanup() }
        XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: .china).language, .simplifiedChinese)
        XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: .unitedStates).language, .english)
        XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: nil).language, .system)
        // Explicit System is a stored choice, not "unset": it must not fall back to the market default.
        AppLanguagePreference(defaults: defaults, market: .china).select(.system)
        XCTAssertEqual(AppLanguagePreference(defaults: defaults, market: .china).language, .system)
    }

    func testStorageKeyIsTheSettingsKey() {
        XCTAssertEqual(AppLanguage.storageKey, "preferences.language")
    }
}
