import XCTest

/// DEBUG launch of `--design-fixture d4-owner-detail` in English and Simplified Chinese.
final class Fixture_d4_owner_detailTests: XCTestCase {
    private static let rawDottedKey = try! NSRegularExpression(
        pattern: #"^[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)+$"#
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD4OwnerDetailEnglish() {
        launchAndAssert(language: "en", screenshotName: "d4-owner-detail-en")
    }

    func testD4OwnerDetailSimplifiedChinese() {
        launchAndAssert(language: "zh-Hans", screenshotName: "d4-owner-detail-zh")
    }

    /// The fixture name is the token immediately after `--design-fixture`.
    /// `-preferences.language` follows it so it is not read as the fixture name.
    private func launchAndAssert(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "--design-fixture", "d4-owner-detail",
            "-preferences.language", language,
        ]
        app.launch()
        defer {
            if app.state != .notRunning {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = screenshotName
                shot.lifetime = .keepAlways
                add(shot)
            }
            app.terminate()
        }

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == YES"))
            .element(boundBy: 0)
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 15),
            "Timed out waiting for the first hittable element. \(app.debugDescription)"
        )

        let unknown = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertFalse(unknown.firstMatch.exists, "Unknown design fixture is on screen. \(app.debugDescription)")

        assertNoRawDottedStaticText(in: app)
        XCTAssertEqual(app.state, .runningForeground, "App is not running.")
        assertNoQuestifyOutsideDebugLabels(in: app)
    }

    private func assertNoRawDottedStaticText(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let offenders = app.staticTexts.allElementsBoundByIndex.compactMap { element -> String? in
            let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            let range = NSRange(label.startIndex..<label.endIndex, in: label)
            return Self.rawDottedKey.firstMatch(in: label, range: range) == nil ? nil : label
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "Raw dotted key staticText: \(offenders.joined(separator: ", ")). \(app.debugDescription)",
            file: file,
            line: line
        )
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let hits = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
            .allElementsBoundByIndex
        let outside = hits.map(\.label).filter { !$0.contains("DEBUG") }
        XCTAssertTrue(
            outside.isEmpty,
            "Questify outside DEBUG labels: \(outside.joined(separator: " | "))",
            file: file,
            line: line
        )
    }
}
