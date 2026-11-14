import XCTest

/// One UI test for ui/h-visual-bugs. Launches the pushed growth fixture and checks
/// the tab bar is hidden. Does not submit, pay, or use the network.
/// This file is not executed on the VM.
final class Cur9VisualBugsFixtureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPushedGrowthHidesTabBar() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting-reset-language",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--design-fixture", "cur9-growth-pushed"
        ]
        app.launch()
        defer { app.terminate() }

        let name = app.staticTexts["Sample me"]
        XCTAssertTrue(name.waitForExistence(timeout: 20), "Growth contrast row did not appear. \(app.debugDescription)")
        let hidden = app.descendants(matching: .any)["cur9.tabBar.hidden"]
        XCTAssertTrue(hidden.waitForExistence(timeout: 5), "Pushed page did not hide the tab bar")
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        XCTAssertFalse(app.staticTexts["Unknown design fixture"].exists)
    }
}
