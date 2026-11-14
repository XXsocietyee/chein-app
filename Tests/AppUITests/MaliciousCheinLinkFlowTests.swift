import XCTest

/// Offline fixture only. The malicious `chein://` link is a launch argument, not a network request.
/// This VM does not run XCUITest; the case is here for the device lane.
final class MaliciousCheinLinkFlowTests: XCTestCase {
    private var runningApp: XCUIApplication?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        attachFailureScreenshot(self, app: runningApp)
        runningApp?.terminate()
        runningApp = nil
        super.tearDown()
    }

    func testMaliciousCheinLinkOpensNothing() {
        let app = XCUIApplication()
        let link = "chein://mp/%2e%2e/subpackagePass/reveal/index?mode=paid&count=9&token="
        app.launchArguments = [
            "--uitesting-reset-language",
            "--uitesting-module", "appsecChein",
            "--appsec-chein-url", link,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        runningApp = app
        app.launch()
        let closed = app.staticTexts["appsec.chein.closed"]
        XCTAssertTrue(closed.waitForExistence(timeout: 5))
        XCTAssertEqual(closed.label, "—")
        XCTAssertFalse(app.staticTexts["appsec.chein.opened"].exists)
    }
}
