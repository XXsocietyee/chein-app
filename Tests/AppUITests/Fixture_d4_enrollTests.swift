import XCTest

final class Fixture_d4_enrollTests: XCTestCase {
    private let rawDottedKey = #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testD4EnrollEnglish() {
        verify(language: "en", screenshotName: "d4-enroll-en")
    }

    func testD4EnrollChinese() {
        verify(language: "zh-Hans", screenshotName: "d4-enroll-zh")
    }

    private func verify(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-enroll", "-preferences.language", language]
        app.launch()
        waitForFirstHittableElement(in: app)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertFalse(textExists("Unknown design fixture", in: app), app.debugDescription)
        for text in app.staticTexts.allElementsBoundByIndex {
            let label = text.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if label.range(of: rawDottedKey, options: .regularExpression) != nil {
                XCTFail("Raw dotted key staticText: \(label)")
            }
        }
        for label in visibleLabels(in: app) where label.contains("Questify") {
            XCTAssertTrue(label.contains("DEBUG"), "Questify outside a DEBUG label: \(label)")
        }
    }

    private func waitForFirstHittableElement(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.descendants(matching: .any).matching(NSPredicate(format: "hittable == true")).firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        let result = XCTWaiter.wait(for: [ready], timeout: 20)
        XCTAssertEqual(result, .completed, "Timed out waiting for the first hittable element. \(app.debugDescription)", file: file, line: line)
    }

    private func textExists(_ needle: String, in app: XCUIApplication) -> Bool {
        visibleLabels(in: app).contains { $0.contains(needle) }
    }

    private func visibleLabels(in app: XCUIApplication) -> [String] {
        let queries = [app.staticTexts, app.buttons, app.links, app.textFields, app.textViews, app.navigationBars]
        return queries.flatMap { $0.allElementsBoundByIndex.map(\.label) }
    }
}
