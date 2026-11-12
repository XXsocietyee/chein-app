import XCTest

/// Lane CB748. Launches the DEBUG `--design-fixture e1-bundle-shelf-error` host once
/// in English and once in zh-Hans. Each launch keeps one screenshot.
final class Fixture_e1_bundle_shelf_errorTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testE1BundleShelfErrorEnglish() {
        exercise(language: "en", screenshotName: "e1-bundle-shelf-error-en")
    }

    func testE1BundleShelfErrorSimplifiedChinese() {
        exercise(language: "zh-Hans", screenshotName: "e1-bundle-shelf-error-zh")
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
            "--design-fixture", "e1-bundle-shelf-error",
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
        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknown.count, 0, app.debugDescription, file: file, line: line)
    }

    /// A catalogue key such as `shelf.error` shown as the whole label.
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
