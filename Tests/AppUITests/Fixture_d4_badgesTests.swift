import XCTest

/// DEBUG design fixture `d4-badges` (`ObjectBadgeWallView` via `D4MeFixture`).
/// English and Simplified Chinese each launch once and keep a screenshot.
final class Fixture_d4_badgesTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD4BadgesEnglish() {
        assertD4Badges(language: "en", attachmentName: "d4-badges-en")
    }

    func testD4BadgesSimplifiedChinese() {
        assertD4Badges(language: "zh-Hans", attachmentName: "d4-badges-zh")
    }

    private func assertD4Badges(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-badges", "-preferences.language", language]
        app.launch()
        defer { app.terminate() }

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 15),
            "No hittable element appeared for --design-fixture d4-badges (\(language))"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = attachmentName
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let unknownFixture = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknownFixture.count, 0, "Unknown design fixture is on screen")

        let rawDottedKey = NSPredicate(
            format: "label MATCHES %@",
            #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#
        )
        let rawKeys = app.staticTexts.matching(rawDottedKey)
        XCTAssertEqual(
            rawKeys.count,
            0,
            "Raw dotted key: \(rawKeys.allElementsBoundByIndex.map(\.label))"
        )

        XCTAssertTrue(
            app.state == .runningForeground || app.state == .runningBackground,
            "App is not running: \(app.state)"
        )

        let questifyOutsideDebug = app.descendants(matching: .any).matching(
            NSPredicate(format: "(label CONTAINS %@) AND NOT (label CONTAINS %@)", "Questify", "DEBUG")
        )
        XCTAssertEqual(
            questifyOutsideDebug.count,
            0,
            "Questify outside a DEBUG label: \(questifyOutsideDebug.allElementsBoundByIndex.map(\.label))"
        )
    }
}
