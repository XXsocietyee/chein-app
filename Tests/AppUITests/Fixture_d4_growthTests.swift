import XCTest

/// Offline DEBUG design fixture for the growth center.
/// English and Simplified Chinese each launch with `--design-fixture d4-growth`
/// and `-preferences.language`, then check the resolved screen.
final class Fixture_d4_growthTests: XCTestCase {
    func testD4GrowthEnglish() {
        let app = launch(language: "en")
        assertResolvedFixture(app)
        attachScreenshot(app, name: "d4-growth-en")
    }

    func testD4GrowthSimplifiedChinese() {
        let app = launch(language: "zh-Hans")
        assertResolvedFixture(app)
        attachScreenshot(app, name: "d4-growth-zh")
    }

    /// `-preferences.language` follows the fixture name so `fixtureArgument` keeps `d4-growth`.
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-growth", "-preferences.language", language]
        app.launch()
        return app
    }

    private func assertResolvedFixture(_ app: XCUIApplication) {
        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 15),
            "Timed out waiting for the first hittable element"
        )

        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknown.count, 0, "Unknown design fixture is on screen")

        assertNoRawDottedKeys(in: app)
        XCTAssertNotEqual(app.state, .notRunning, "App is no longer running")
        XCTAssertEqual(app.state, .runningForeground, "App is not running in the foreground")
        assertNoQuestifyOutsideDebugLabels(in: app)
    }

    /// A raw dotted key is the entire static text, such as `growth.title`.
    private func assertNoRawDottedKeys(in app: XCUIApplication) {
        let expression = try! NSRegularExpression(
            pattern: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$"#
        )
        var offenders: [String] = []
        for element in app.staticTexts.allElementsBoundByIndex {
            let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let range = NSRange(label.startIndex..., in: label)
            if expression.firstMatch(in: label, options: [], range: range) != nil {
                offenders.append(label)
            }
        }
        XCTAssertEqual(offenders, [], "Raw dotted keys: \(offenders)")
    }

    /// Product name may appear only inside a label that already says DEBUG.
    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication) {
        let matches = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Questify")
        )
        var offenders: [String] = []
        for index in 0..<matches.count {
            let label = matches.element(boundBy: index).label
            if !label.contains("DEBUG") {
                offenders.append(label)
            }
        }
        XCTAssertEqual(offenders, [], "Questify appeared outside DEBUG labels: \(offenders)")
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
