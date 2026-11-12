import XCTest

/// Smoke-checks the DEBUG design fixture `d4-tab-overview` in English and Simplified Chinese.
final class Fixture_d4_tab_overviewTests: XCTestCase {
    private let rawDottedKey = "^[A-Za-z][A-Za-z0-9]*(\\.[A-Za-z][A-Za-z0-9_]*)+$"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        attachFailureScreenshot(self, app: app)
        if app.state != .notRunning {
            app.terminate()
        }
    }

    func testEnglishDesignFixture() {
        launchAndVerify(language: "en", screenshotName: "d4-tab-overview-en")
    }

    func testSimplifiedChineseDesignFixture() {
        launchAndVerify(language: "zh-Hans", screenshotName: "d4-tab-overview-zh")
    }

    private func launchAndVerify(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-tab-overview", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 20),
            "Timed out waiting for the first hittable element"
        )
        XCTAssertTrue(firstHittable.isHittable)

        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknown.count, 0, "Unknown design fixture text is on screen")

        let dotted = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", rawDottedKey))
        if dotted.count != 0 {
            XCTFail("Raw dotted key static text: \(dotted.firstMatch.label)")
        }

        XCTAssertEqual(app.state, .runningForeground, "App is no longer running")

        let questify = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)", "Questify", "DEBUG")
        )
        if questify.count != 0 {
            XCTFail("Questify appears outside a DEBUG label: \(questify.firstMatch.label)")
        }

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screenshotName
        shot.lifetime = .keepAlways
        add(shot)
    }
}
