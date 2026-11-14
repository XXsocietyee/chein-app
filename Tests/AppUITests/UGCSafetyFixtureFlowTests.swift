import XCTest

/// DEBUG `--design-fixture ugc-square` only. Report, then block, then the post is hidden.
/// Submit stays untapped. The fixture service has no production host.
final class UGCSafetyFixtureFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testReportThenBlockHidesTheSquarePost() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting-reset-language",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--design-fixture", "ugc-square"
        ]
        app.launch()

        let content = app.staticTexts["ugc.fixture.content"]
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["ugc.fixture.memberID"].label, "880201")

        let report = app.buttons["ugc.safety.footer.report"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()

        let close = app.buttons["ugc.safety.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ugc.safety.submitReportButton"].exists)
        close.tap()

        app.buttons["ugc.safety.footer.block"].tap()
        let confirm = app.buttons["ugc.safety.block.confirm"]
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        } else {
            app.buttons["Block & Hide Content"].tap()
        }

        XCTAssertTrue(app.otherElements["ugc.safety.blockedBanner"].waitForExistence(timeout: 5))
        XCTAssertFalse(content.exists)
    }
}
