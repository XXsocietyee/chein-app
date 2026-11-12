import XCTest

/// Lane CB746. DEBUG design fixture `e1-bundle-shelf` in English and Simplified Chinese.
/// The product name may appear only inside a DEBUG label.
final class Fixture_e1_bundle_shelfTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testE1BundleShelfEnglish() {
        let app = launch(language: "en")
        assertReadyFixture(app, screenshotName: "e1-bundle-shelf-en")
    }

    func testE1BundleShelfSimplifiedChinese() {
        let app = launch(language: "zh-Hans")
        assertReadyFixture(app, screenshotName: "e1-bundle-shelf-zh")
    }

    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = ["--design-fixture", "e1-bundle-shelf", "-preferences.language", language]
        app.launch()
        return app
    }

    private func assertReadyFixture(_ app: XCUIApplication, screenshotName: String) {
        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "isHittable == TRUE"))
            .firstMatch
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 20),
                      "Timed out waiting for the first hittable element. \(app.debugDescription)")
        XCTAssertTrue(firstHittable.isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = screenshotName
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let unknownFixture = NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        XCTAssertEqual(app.staticTexts.matching(unknownFixture).count, 0)
        XCTAssertEqual(app.descendants(matching: .any).matching(unknownFixture).count, 0)

        for text in app.staticTexts.allElementsBoundByIndex where isRawDottedKey(text.label) {
            XCTFail("staticText is a raw dotted key: \(text.label)")
        }

        XCTAssertNotEqual(app.state, .notRunning)
        XCTAssertEqual(app.state, .runningForeground, "the app is still running")

        assertNoQuestifyOutsideDebugLabels(in: app)
    }

    private func isRawDottedKey(_ label: String) -> Bool {
        let pattern = #"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$"#
        return label.range(of: pattern, options: .regularExpression) != nil
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication) {
        let types: [XCUIElement.ElementType] = [.staticText, .button, .textField, .textView, .navigationBar, .link]
        for type in types {
            let matches = app.descendants(matching: type).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Questify", "Questify"))
            for element in matches.allElementsBoundByIndex {
                let label = element.label
                let value = element.value as? String ?? ""
                let debugLabel = label.contains("DEBUG") || value.contains("DEBUG")
                XCTAssertTrue(debugLabel, "Questify outside DEBUG labels: \(label)")
            }
        }
    }
}
