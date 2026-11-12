import XCTest

/// Launches the DEBUG `--design-fixture d2-play` screen in English and Simplified Chinese.
final class Fixture_d2_playTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD2PlayEnglish() throws {
        assertDesignFixture(language: "en", attachmentName: "d2-play-en")
    }

    func testD2PlaySimplifiedChinese() throws {
        assertDesignFixture(language: "zh-Hans", attachmentName: "d2-play-zh")
    }

    private func assertDesignFixture(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-play", "-preferences.language", language]
        app.launch()
        defer { app.terminate() }

        waitForFirstHittableElement(in: app)
        assertNoText("Unknown design fixture", in: app)
        assertNoRawDottedKeys(in: app)
        XCTAssertEqual(app.state, .runningForeground)
        assertNoQuestifyOutsideDebugLabels(in: app)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = attachmentName
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func waitForFirstHittableElement(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let types: [XCUIElement.ElementType] = [
            .button, .staticText, .cell, .textField, .secureTextField, .searchField,
            .switch, .link, .image, .other, .slider, .stepper, .navigationBar, .toolbar
        ]
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            for type in types {
                let element = app.descendants(matching: type).matching(NSPredicate(format: "hittable == true")).firstMatch
                if element.exists, element.isHittable { return }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Timed out waiting for the first hittable element. " + app.debugDescription, file: file, line: line)
    }

    private func assertNoText(_ text: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
        XCTAssertEqual(matches.allElementsBoundByIndex.map(\.label), [], file: file, line: line)
    }

    private func assertNoRawDottedKeys(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let pattern = "^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+$"
        let matches = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", pattern))
        XCTAssertEqual(matches.allElementsBoundByIndex.map(\.label), [], "Raw dotted key is visible", file: file, line: line)
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let matches = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND NOT (label CONTAINS %@)", "Questify", "DEBUG")
        )
        XCTAssertEqual(matches.allElementsBoundByIndex.map(\.label), [], "Questify appeared outside a DEBUG label", file: file, line: line)
    }
}
