import XCTest

/// Design-fixture smoke for `--design-fixture e1-bundle-detail`.
/// English and Simplified Chinese each get their own launch.
final class Fixture_e1_bundle_detailTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testE1BundleDetailEnglish() {
        launchAndAssert(language: "en", screenshotName: "e1-bundle-detail-en")
    }

    func testE1BundleDetailZhHans() {
        launchAndAssert(language: "zh-Hans", screenshotName: "e1-bundle-detail-zh")
    }

    private func launchAndAssert(language: String, screenshotName: String) {
        app.launchArguments = [
            "--design-fixture", "e1-bundle-detail",
            "-preferences.language", language,
        ]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(firstHittable.isHittable, app.debugDescription)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = screenshotName
        screenshot.lifetime = .keepAlways
        add(screenshot)

        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
                .firstMatch
                .exists,
            app.debugDescription
        )

        for text in app.staticTexts.allElementsBoundByIndex where isRawDottedKey(text.label) {
            XCTFail("Raw dotted key staticText: \(text.label)", file: #filePath, line: #line)
        }

        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App is not running (state \(app.state.rawValue))"
        )

        let textTypes: [XCUIElement.ElementType] = [
            .staticText, .button, .link, .textView, .textField, .searchField, .navigationBar,
        ]
        for type in textTypes {
            let matches = app.descendants(matching: type)
                .matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
            for index in 0..<matches.count {
                let label = matches.element(boundBy: index).label
                XCTAssertTrue(
                    label.contains("DEBUG"),
                    "Questify outside a DEBUG label: \(label)"
                )
            }
        }
    }

    /// Catalogue keys left on screen (`detail.title`). Sentences, prices (`199.00`), and DEBUG labels are not keys.
    private func isRawDottedKey(_ raw: String) -> Bool {
        let label = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = label.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { part in
            guard let first = part.first, first.isASCII, first.isLetter else { return false }
            return part.allSatisfy { character in
                character.isASCII && (character.isLetter || character.isNumber || character == "_")
            }
        }
    }
}
