import XCTest

/// d4-detail design fixture in English and Simplified Chinese.
/// The screen must come up, stay up, and show real copy.
final class Fixture_d4_detailTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testD4DetailEnglish() {
        assertFixture(language: "en", screenshotName: "d4-detail-en")
    }

    func testD4DetailSimplifiedChinese() {
        assertFixture(language: "zh-Hans", screenshotName: "d4-detail-zh")
    }

    private func assertFixture(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-detail", "-preferences.language", language]
        app.launch()

        let first = waitForFirstHittableElement(in: app)
        XCTAssertTrue(first.isHittable)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertFalse(containsText("Unknown design fixture", in: app))
        assertNoRawDottedKeyStaticText(in: app)
        XCTAssertEqual(app.state, .runningForeground)
        assertNoQuestifyOutsideDebugLabels(in: app)
    }

    private func waitForFirstHittableElement(in app: XCUIApplication) -> XCUIElement {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if let element = app.descendants(matching: .any).allElementsBoundByIndex.first(where: \.isHittable) {
                return element
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Timed out waiting for the first hittable element")
        return app
    }

    private func containsText(_ needle: String, in app: XCUIApplication) -> Bool {
        contentElements(in: app).contains { element in
            element.label.contains(needle) || (element.value as? String)?.contains(needle) == true
        }
    }

    private func assertNoRawDottedKeyStaticText(in app: XCUIApplication) {
        let pattern = #"^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$"#
        for text in app.staticTexts.allElementsBoundByIndex {
            let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.range(of: pattern, options: .regularExpression) != nil else { continue }
            XCTFail("Raw dotted key staticText: \(label)")
        }
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication) {
        for element in contentElements(in: app) {
            let texts = [element.label, element.value as? String].compactMap { $0 }
            for text in texts where text.contains("Questify") {
                XCTAssertTrue(element.label.contains("DEBUG"), "Questify outside a DEBUG label: \(text)")
            }
        }
    }

    private func contentElements(in app: XCUIApplication) -> [XCUIElement] {
        app.descendants(matching: .any).allElementsBoundByIndex.filter { $0.elementType != .window }
    }
}
