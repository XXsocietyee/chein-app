import XCTest

/// Offline CN build only. No real provider, account, or network is used.
final class WeChatAppAuthFlowTests: XCTestCase {
    func testDormantBilingualEntryCanCloseAndReopen() {
        for language in ["en", "zh-Hans"] {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(\(language))"]
            app.launch()
            skipOnboardingIfPresent(in: app)
            for _ in 0..<2 {
                XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout: 10))
                app.buttons["welcome.player"].tap()
                // Offline build: WeChat is not offered, so the row is hidden (no dead sign-in method, sweep 19:15).
                XCTAssertTrue(app.buttons["auth.otherChannels"].waitForExistence(timeout: 5))
                XCTAssertFalse(app.buttons["auth.wechat.signIn"].exists)
                XCTAssertFalse(app.staticTexts["auth.wechat.gate"].exists)
                XCTAssertFalse(app.buttons["auth.signIn"].exists)
                XCTAssertFalse(app.secureTextFields.firstMatch.exists)
                XCTAssertTrue(app.buttons["auth.otherChannels"].exists)
                app.buttons[language == "en" ? "Close" : "关闭"].tap()
            }
            app.terminate()
        }
    }
}
