import XCTest

/// DEBUG design fixture `d4-channels` (channel list) in English and Simplified Chinese.
final class Fixture_d4_channelsTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testD4ChannelsEnglish() {
        assertDesignFixture(language: "en", attachmentName: "d4-channels-en")
    }

    func testD4ChannelsSimplifiedChinese() {
        assertDesignFixture(language: "zh-Hans", attachmentName: "d4-channels-zh")
    }

    /// Launches with `--design-fixture d4-channels` and `-preferences.language <language>`.
    private func assertDesignFixture(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d4-channels", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 15),
            "Timed out waiting for the first hittable element"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = attachmentName
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let unknownFixture = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture")
        )
        XCTAssertEqual(unknownFixture.count, 0, "The d4-channels design fixture did not resolve")

        let rawDottedKey = #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#
        let rawKeys = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", rawDottedKey))
        XCTAssertEqual(
            rawKeys.count,
            0,
            "A static text is a raw dotted key: \(rawKeys.allElementsBoundByIndex.map(\.label))"
        )

        XCTAssertNotEqual(app.state, .notRunning, "App is no longer running")
        XCTAssertNotEqual(app.state, .unknown, "App state is unknown")

        let questify = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Questify")
        )
        for element in questify.allElementsBoundByIndex where element.exists {
            XCTAssertTrue(
                element.label.contains("DEBUG"),
                "Questify appeared outside a DEBUG label: \(element.label)"
            )
        }
    }
}
