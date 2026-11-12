import XCTest

/// Smoke the DEBUG `--design-fixture d2-square` host. Synthetic data only.
/// This does not claim a simulator run or a deployed service.
final class Fixture_d2_squareTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testD2SquareEnglish() {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-square", "-preferences.language", "en"]
        app.launch()
        assertLoadedDesignFixture(app, attachmentName: "d2-square-en")
    }

    func testD2SquareSimplifiedChinese() {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-square", "-preferences.language", "zh-Hans"]
        app.launch()
        assertLoadedDesignFixture(app, attachmentName: "d2-square-zh")
    }

    private func assertLoadedDesignFixture(_ app: XCUIApplication, attachmentName: String,
                                           file: StaticString = #filePath, line: UInt = #line) {
        defer {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = attachmentName
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 20),
                      "Expected the first hittable element. " + app.debugDescription,
                      file: file, line: line)
        XCTAssertTrue(firstHittable.isHittable, app.debugDescription, file: file, line: line)

        let unknown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, "Unknown design fixture. " + app.debugDescription, file: file, line: line)

        let rawDottedKey = NSPredicate(
            format: "label MATCHES %@",
            #"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9_]*)+$"#
        )
        let leakedKeys = app.staticTexts.matching(rawDottedKey).allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(leakedKeys.isEmpty, "staticText is a raw dotted key: \(leakedKeys)", file: file, line: line)

        XCTAssertEqual(app.state, .runningForeground, "App is still running", file: file, line: line)

        let questifyOutsideDebug = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", "Questify", "DEBUG")
        )
        XCTAssertEqual(questifyOutsideDebug.count, 0,
                       "Questify outside DEBUG labels. " + app.debugDescription,
                       file: file, line: line)
    }
}
