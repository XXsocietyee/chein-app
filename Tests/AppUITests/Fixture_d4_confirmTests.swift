import XCTest

/// DEBUG design host for the club leave confirmation (`--design-fixture d4-confirm`).
final class Fixture_d4_confirmTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testD4ConfirmEnglish() {
        assertFixture(language: "en", attachmentName: "d4-confirm-en")
    }

    func testD4ConfirmZhHans() {
        assertFixture(language: "zh-Hans", attachmentName: "d4-confirm-zh")
    }

    private func assertFixture(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-confirm", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 20), app.debugDescription)

        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
                .count,
            0,
            app.debugDescription
        )

        let rawDottedKey = NSPredicate(
            format: "label MATCHES %@",
            #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#
        )
        let leakedKeys = app.staticTexts.matching(rawDottedKey)
        XCTAssertEqual(leakedKeys.count, 0, leakedKeys.allElementsBoundByIndex.map(\.label).joined(separator: ", "))

        XCTAssertEqual(app.state, .runningForeground)

        let questifyOutsideDebug = NSPredicate(
            format: "label CONTAINS %@ AND NOT (label CONTAINS %@)",
            "Questify",
            "DEBUG"
        )
        let textual: [XCUIElement.ElementType] = [
            .staticText, .button, .link, .textField, .textView, .navigationBar, .searchField
        ]
        for type in textual {
            let hits = app.descendants(matching: type).matching(questifyOutsideDebug)
            XCTAssertEqual(hits.count, 0, hits.allElementsBoundByIndex.map(\.label).joined(separator: ", "))
        }

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = attachmentName
        shot.lifetime = .keepAlways
        add(shot)
    }
}
