import XCTest

/// Lane CB714. Launches the DEBUG `--design-fixture d4-badges-error` host once
/// in English and once in zh-Hans. Each launch keeps one screenshot.
final class Fixture_d4_badges_errorTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testD4BadgesErrorEnglish() {
        exercise(language: "en", screenshotName: "d4-badges-error-en")
    }

    func testD4BadgesErrorSimplifiedChinese() {
        exercise(language: "zh-Hans", screenshotName: "d4-badges-error-zh")
    }

    private func exercise(language: String, screenshotName: String) {
        let app = launch(language: language)
        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 20),
            "Timed out waiting for the first hittable element. " + app.debugDescription
        )
        XCTAssertTrue(firstHittable.isHittable, app.debugDescription)
        attachScreenshot(app, name: screenshotName)
        assertNoUnknownDesignFixture(in: app)
        assertNoRawDottedStaticText(in: app)
        assertNoQuestifyOutsideDebugLabels(in: app)
        XCTAssertEqual(app.state, .runningForeground, "App is no longer running. " + app.debugDescription)
    }

    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = [
            "--design-fixture", "d4-badges-error",
            "-preferences.language", language,
        ]
        app.launch()
        return app
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertNoUnknownDesignFixture(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let unknown = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")).firstMatch
        XCTAssertFalse(unknown.exists, app.debugDescription, file: file, line: line)
    }

    /// A catalogue key such as `profile.loadFailed` shown as the whole label.
    private func assertNoRawDottedStaticText(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for text in app.staticTexts.allElementsBoundByIndex where isRawDottedKey(text.label) {
            XCTFail("Raw dotted key shown as static text: \(text.label)", file: file, line: line)
        }
    }

    private func isRawDottedKey(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { part in
            guard let first = part.first, first.isASCII, first.isLetter else { return false }
            return part.allSatisfy { character in
                character.isASCII && (character.isLetter || character.isNumber || character == "_")
            }
        }
    }

    /// Visible copy may name Questify only inside a label that already says DEBUG.
    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let types: [XCUIElement.ElementType] = [.staticText, .button, .navigationBar, .textView, .textField]
        for type in types {
            let matches = app.descendants(matching: type).matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
            for element in matches.allElementsBoundByIndex {
                XCTAssertTrue(
                    element.label.contains("DEBUG"),
                    "Questify appeared outside a DEBUG label: \(element.label)",
                    file: file,
                    line: line
                )
            }
        }
    }
}
