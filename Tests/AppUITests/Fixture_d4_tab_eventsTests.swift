import XCTest

/// Smoke the DEBUG `--design-fixture d4-tab-events` host in English and Simplified Chinese.
/// The registry must mount the club events tab, resolved copy must replace raw keys, and the
/// legacy brand must stay off the screen except inside a DEBUG label.
final class Fixture_d4_tab_eventsTests: XCTestCase {
    private static let rawDottedKey = try! NSRegularExpression(
        pattern: "^[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z0-9_]+)+$"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD4TabEventsEnglish() {
        launchAndAssert(language: "en", screenshotName: "d4-tab-events-en")
    }

    func testD4TabEventsSimplifiedChinese() {
        launchAndAssert(language: "zh-Hans", screenshotName: "d4-tab-events-zh")
    }

    private func launchAndAssert(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-tab-events", "-preferences.language", language]
        app.launch()
        defer { app.terminate() }

        let firstHittable = app.descendants(matching: .any).matching(NSPredicate(format: "hittable == true")).firstMatch
        let appeared = firstHittable.waitForExistence(timeout: 20)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = screenshotName
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(appeared, "No hittable element appeared. \(app.debugDescription)")

        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknown.count, 0, "Design fixture was not registered. \(app.debugDescription)")
        assertNoRawDottedKeys(in: app)
        XCTAssertEqual(app.state, .runningForeground, "App is not running. \(app.debugDescription)")
        assertQuestifyStaysInsideDebugLabels(in: app)
    }

    private func assertNoRawDottedKeys(in app: XCUIApplication) {
        for text in app.staticTexts.allElementsBoundByIndex {
            let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let range = NSRange(location: 0, length: (label as NSString).length)
            if Self.rawDottedKey.firstMatch(in: label, range: range) != nil {
                XCTFail("Raw dotted key shown as static text: \(label). \(app.debugDescription)")
            }
        }
    }

    private func assertQuestifyStaysInsideDebugLabels(in app: XCUIApplication) {
        let branded = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
        for index in 0..<branded.count {
            let label = branded.element(boundBy: index).label
            XCTAssertTrue(
                label.contains("DEBUG"),
                "Questify outside a DEBUG label: \(label). \(app.debugDescription)"
            )
        }
    }
}
