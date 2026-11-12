import XCTest

/// DEBUG `--design-fixture d2-home` in English and zh-Hans.
/// A Linux host only parses this file; it does not launch the simulator.
final class Fixture_d2_homeTests: XCTestCase {
    private static let rawDottedKey = try! NSRegularExpression(
        pattern: #"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+(\.[A-Za-z0-9]+)*$"#
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD2HomeEnglish() {
        launchAndAssert(language: "en", screenshotName: "d2-home-en")
    }

    func testD2HomeZhHans() {
        launchAndAssert(language: "zh-Hans", screenshotName: "d2-home-zh")
    }

    private func launchAndAssert(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-home", "-preferences.language", language]
        app.launch()
        waitForFirstHittableElement(in: app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)
        assertNoUnknownDesignFixture(in: app)
        assertNoRawDottedKeys(in: app)
        assertNoQuestifyOutsideDebugLabels(in: app)
        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App is not running: \(app.state.rawValue)"
        )
    }

    private func waitForFirstHittableElement(in app: XCUIApplication) {
        let hittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "isHittable == YES"))
            .firstMatch
        XCTAssertTrue(
            hittable.waitForExistence(timeout: 20),
            "Timed out waiting for the first hittable element. \(app.debugDescription)"
        )
    }

    private func assertNoUnknownDesignFixture(in app: XCUIApplication) {
        let unknown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
            .firstMatch
        XCTAssertFalse(unknown.exists, "Screen shows an unknown design fixture. \(app.debugDescription)")
    }

    private func assertNoRawDottedKeys(in app: XCUIApplication) {
        let raw = app.staticTexts.allElementsBoundByIndex.map(\.label).filter(Self.isRawDottedKey)
        XCTAssertTrue(raw.isEmpty, "Raw dotted key staticText: \(raw)")
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication) {
        let labels = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
            .allElementsBoundByIndex
            .map(\.label)
        let outsideDebug = labels.filter { !$0.contains("DEBUG") }
        XCTAssertTrue(outsideDebug.isEmpty, "Questify outside DEBUG labels: \(outsideDebug)")
    }

    private static func isRawDottedKey(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return rawDottedKey.firstMatch(in: trimmed, range: range) != nil
    }
}
