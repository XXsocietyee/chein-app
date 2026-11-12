import XCTest

/// Offline smoke for `--design-fixture d4-directory` in English and Simplified Chinese.
/// The fixture host is already registered; this file does not change App views.
final class Fixture_d4_directoryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDirectoryEnglish() {
        assertDirectory(language: "en", attachmentName: "d4-directory-en")
    }

    func testDirectorySimplifiedChinese() {
        assertDirectory(language: "zh-Hans", attachmentName: "d4-directory-zh")
    }

    private func assertDirectory(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-directory", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        let appeared = firstHittable.waitForExistence(timeout: 15)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = attachmentName
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertTrue(appeared, "No hittable element for d4-directory (\(language)). " + app.debugDescription)
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
                .count,
            0,
            "Unknown design fixture is on screen. " + app.debugDescription
        )
        let dottedKeys = rawDottedKeyLabels(in: app)
        XCTAssertTrue(dottedKeys.isEmpty, "Raw dotted key static text: \(dottedKeys). " + app.debugDescription)
        XCTAssertEqual(app.state, .runningForeground, "App is not running. " + app.debugDescription)
        let questify = questifyLabelsOutsideDebug(in: app)
        XCTAssertTrue(questify.isEmpty, "Questify outside DEBUG labels: \(questify). " + app.debugDescription)
    }

    /// A static text whose whole label is an untranslated dotted key, such as `club.directory`.
    private func rawDottedKeyLabels(in app: XCUIApplication) -> [String] {
        let pattern = #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#
        return app.staticTexts.allElementsBoundByIndex.map(\.label).filter { label in
            label.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Visible "Questify" is allowed only on a label that is itself a DEBUG label.
    private func questifyLabelsOutsideDebug(in app: XCUIApplication) -> [String] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
            .allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.contains("DEBUG") }
    }
}
