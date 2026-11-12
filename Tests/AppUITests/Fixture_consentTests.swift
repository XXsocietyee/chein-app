import XCTest

/// DEBUG `--design-fixture consent` in English and Simplified Chinese.
/// `swiftc -parse` is the Linux check; the simulator is not launched here.
final class Fixture_consentTests: XCTestCase {
    private let dottedKey = #"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$"#

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testConsentEnglish() {
        exercise(language: "en", attachmentName: "consent-en")
    }

    func testConsentSimplifiedChinese() {
        exercise(language: "zh-Hans", attachmentName: "consent-zh")
    }

    private func exercise(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "consent", "-preferences.language", language]
        app.launch()
        waitForFirstHittableElement(in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = attachmentName
        screenshot.lifetime = .keepAlways
        add(screenshot)
        assertNoUnknownDesignFixture(in: app)
        assertNoRawDottedKeys(in: app)
        assertAppStillRunning(app)
        assertNoQuestifyOutsideDebugLabels(in: app)
    }

    private func waitForFirstHittableElement(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let descendants = app.descendants(matching: .any)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            descendants.allElementsBoundByIndex.first(where: \.isHittable) != nil
        }, object: app)
        XCTAssertEqual(
            XCTWaiter().wait(for: [ready], timeout: 20),
            .completed,
            "No hittable element. \(app.debugDescription)",
            file: file,
            line: line
        )
    }

    private func assertNoUnknownDesignFixture(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let unknown = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, "Unknown design fixture is on screen. \(app.debugDescription)", file: file, line: line)
    }

    private func assertNoRawDottedKeys(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let keys = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { label in
            label.range(of: dottedKey, options: .regularExpression) != nil
        }
        XCTAssertTrue(keys.isEmpty, "Raw dotted keys: \(keys). \(app.debugDescription)", file: file, line: line)
    }

    private func assertAppStillRunning(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.state, .runningForeground, "App is not running (\(app.state)). \(app.debugDescription)", file: file, line: line)
    }

    private func assertNoQuestifyOutsideDebugLabels(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let labels = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
            .allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.contains("DEBUG") }
        XCTAssertTrue(labels.isEmpty, "Questify outside DEBUG labels: \(labels). \(app.debugDescription)", file: file, line: line)
    }
}
