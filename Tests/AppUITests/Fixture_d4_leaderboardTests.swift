import XCTest

/// Offline smoke for the DEBUG design fixture `--design-fixture d4-leaderboard`.
final class Fixture_d4_leaderboardTests: XCTestCase {
    private static let dottedKey = try! NSRegularExpression(
        pattern: #"^[A-Za-z][A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]+)+$"#
    )

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
    }

    func testD4LeaderboardEnglish() {
        launchAndAssert(language: "en", screenshotName: "d4-leaderboard-en")
    }

    func testD4LeaderboardZhHans() {
        launchAndAssert(language: "zh-Hans", screenshotName: "d4-leaderboard-zh")
    }

    private func launchAndAssert(language: String, screenshotName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-leaderboard", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true"),
            object: firstHittable
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [ready], timeout: 15),
            .completed,
            "Timed out waiting for the first hittable element"
        )

        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
                .count,
            0,
            "Unknown design fixture"
        )
        assertNoRawDottedKeys(in: app)
        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App is not running"
        )
        assertQuestifyOnlyOnDebugLabels(in: app)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screenshotName
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func assertNoRawDottedKeys(in app: XCUIApplication) {
        for element in app.staticTexts.allElementsBoundByIndex {
            let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = NSRange(label.startIndex..<label.endIndex, in: label)
            XCTAssertNil(
                Self.dottedKey.firstMatch(in: label, range: range),
                "Raw dotted key: \(label)"
            )
        }
    }

    private func assertQuestifyOnlyOnDebugLabels(in app: XCUIApplication) {
        let matches = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Questify"))
        for element in matches.allElementsBoundByIndex where !element.label.contains("DEBUG") {
            XCTFail("Questify outside a DEBUG label: \(element.label)")
        }
    }
}
