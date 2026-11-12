import XCTest

/// DEBUG design fixture `d4-stamps`: real stamp album on synthetic data.
/// Launch stays offline. These checks only read what the screen shows.
final class Fixture_d4_stampsTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD4StampsEnglish() {
        assertDesignFixture(language: "en", screenshotName: "d4-stamps-en")
    }

    func testD4StampsZhHans() {
        assertDesignFixture(language: "zh-Hans", screenshotName: "d4-stamps-zh")
    }

    private func assertDesignFixture(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-stamps", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 15),
            "Timed out waiting for the first hittable element"
        )
        XCTAssertTrue(firstHittable.isHittable)

        let staticLabels = app.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertFalse(staticLabels.contains { $0.contains("Unknown design fixture") }, "Unknown design fixture")
        let rawKeys = staticLabels.filter(Self.isRawDottedKey)
        XCTAssertTrue(rawKeys.isEmpty, "Raw dotted key shown as static text: \(rawKeys)")
        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App is no longer running"
        )
        let questify = (staticLabels + controlLabels(in: app)).filter { $0.contains("Questify") && !$0.contains("DEBUG") }
        XCTAssertTrue(questify.isEmpty, "Questify outside DEBUG labels: \(questify)")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screenshotName
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// A static text whose whole label is an untranslated catalog key, such as `roam.experience.album`.
    private static func isRawDottedKey(_ label: String) -> Bool {
        let parts = label.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy(isIdentifierSegment)
    }

    private static func isIdentifierSegment(_ part: Substring) -> Bool {
        guard let first = part.first, isASCIILetter(first) else { return false }
        return part.allSatisfy { isASCIILetter($0) || isASCIIDigit($0) }
    }

    private static func isASCIILetter(_ character: Character) -> Bool {
        ("A"..."Z").contains(character) || ("a"..."z").contains(character)
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        ("0"..."9").contains(character)
    }

    private func controlLabels(in app: XCUIApplication) -> [String] {
        let elements = app.buttons.allElementsBoundByIndex
            + app.textViews.allElementsBoundByIndex
            + app.textFields.allElementsBoundByIndex
        return elements.map(\.label)
    }
}
