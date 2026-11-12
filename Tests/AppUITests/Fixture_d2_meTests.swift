import XCTest

/// DEBUG `--design-fixture d2-me` account screen, in English and Simplified Chinese.
final class Fixture_d2_meTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testD2MeEnglish() {
        launchAndCheck(language: "en", screenshotName: "d2-me-en")
    }

    func testD2MeZhHans() {
        launchAndCheck(language: "zh-Hans", screenshotName: "d2-me-zh")
    }

    private func launchAndCheck(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-me", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .element(boundBy: 0)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: firstHittable
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screenshotName
        shot.lifetime = .keepAlways
        add(shot)

        assertNoText("Unknown design fixture", in: app)
        assertNoRawDottedKey(in: app)
        assertQuestifyStaysInsideDebugLabels(in: app)
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func textQueries(in app: XCUIApplication) -> [XCUIElementQuery] {
        [app.staticTexts, app.buttons, app.textViews, app.navigationBars]
    }

    private func assertNoText(_ needle: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", needle)
        for query in textQueries(in: app) {
            let hits = query.matching(predicate)
            XCTAssertEqual(hits.count, 0, hits.allElementsBoundByIndex.map(\.label).joined(separator: "\n"), file: file, line: line)
        }
    }

    /// A raw catalogue key is the entire static-text label, such as `wallet.title`.
    private func assertNoRawDottedKey(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let rawKey = app.staticTexts.matching(NSPredicate(
            format: "label MATCHES %@",
            "^[A-Za-z][A-Za-z0-9]*(\\.[A-Za-z][A-Za-z0-9]*)+$"
        ))
        XCTAssertEqual(rawKey.count, 0, rawKey.allElementsBoundByIndex.map(\.label).joined(separator: ", "), file: file, line: line)
    }

    private func assertQuestifyStaysInsideDebugLabels(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", "Questify")
        for query in textQueries(in: app) {
            for element in query.matching(predicate).allElementsBoundByIndex {
                XCTAssertTrue(element.label.contains("DEBUG"), "Questify outside a DEBUG label: \(element.label)", file: file, line: line)
            }
        }
    }
}
