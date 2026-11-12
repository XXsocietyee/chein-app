import XCTest

/// DEBUG design fixture `d4-join-confirm`: the club detail with the join confirmation sheet.
/// Launch only. No App, Vendor, or copy changes.
final class Fixture_d4_join_confirmTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishJoinConfirmFixture() throws {
        try launchAndAssert(language: "en", screenshotName: "d4-join-confirm-en")
    }

    func testSimplifiedChineseJoinConfirmFixture() throws {
        try launchAndAssert(language: "zh-Hans", screenshotName: "d4-join-confirm-zh")
    }

    private func launchAndAssert(language: String, screenshotName: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-join-confirm", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .element(boundBy: 0)
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 20), app.debugDescription)

        let unknown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, "Unknown design fixture must not be shown")

        let rawKeys = try rawDottedStaticTexts(in: app)
        XCTAssertEqual(rawKeys, [], "Raw dotted localization keys: \(rawKeys)")

        XCTAssertEqual(app.state, .runningForeground)

        let questify = questifyLabelsOutsideDebug(in: app)
        XCTAssertEqual(questify, [], "Questify outside DEBUG labels: \(questify)")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    /// A static text whose whole label is an unresolved catalogue key, such as `club.action.join`.
    private func rawDottedStaticTexts(in app: XCUIApplication) throws -> [String] {
        let dottedKey = try NSRegularExpression(pattern: #"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$"#)
        var found: [String] = []
        for text in app.staticTexts.allElementsBoundByIndex {
            let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            let range = NSRange(label.startIndex..<label.endIndex, in: label)
            if dottedKey.firstMatch(in: label, range: range) != nil {
                found.append(label)
            }
        }
        return found
    }

    /// Visible labels may mention Questify only when that same label is a DEBUG marker.
    private func questifyLabelsOutsideDebug(in app: XCUIApplication) -> [String] {
        app.descendants(matching: .any).allElementsBoundByIndex.compactMap { element in
            guard element.elementType != .window else { return nil }
            let label = element.label
            guard label.contains("Questify"), !label.contains("DEBUG") else { return nil }
            return label
        }
    }
}
