import XCTest

/// DEBUG `--design-fixture coupons` smoke check. Synthetic owned coupons, no network.
final class Fixture_couponsTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testCouponsDesignFixtureEnglish() {
        launchAndCheck(language: "en", screenshotName: "coupons-en")
    }

    func testCouponsDesignFixtureSimplifiedChinese() {
        launchAndCheck(language: "zh-Hans", screenshotName: "coupons-zh")
    }

    /// Launch `--design-fixture coupons` with `-preferences.language`, then check the screen.
    private func launchAndCheck(language: String, screenshotName: String) {
        app.launchArguments = ["--design-fixture", "coupons", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "isHittable == true"))
            .firstMatch
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 20), "Timed out waiting for the first hittable element")

        let unknownFixture = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertFalse(unknownFixture.firstMatch.exists)

        let dottedKeys = app.staticTexts.allElementsBoundByIndex.map(\.label).filter(Self.isRawDottedKey)
        XCTAssertEqual(dottedKeys, [], "Raw dotted key shown as static text: \(dottedKeys)")

        XCTAssertEqual(app.state, .runningForeground, "App is still running")

        let questifyOutsideDebug = app.descendants(matching: .any).matching(NSPredicate(
            format: "(label CONTAINS %@ AND NOT (label CONTAINS %@)) OR (value CONTAINS %@ AND NOT (value CONTAINS %@))",
            "Questify", "DEBUG", "Questify", "DEBUG"
        ))
        XCTAssertFalse(questifyOutsideDebug.firstMatch.exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A catalogue key left untranslated, such as `accountCollection.coupons.title`.
    private static func isRawDottedKey(_ label: String) -> Bool {
        label.range(
            of: #"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$"#,
            options: .regularExpression
        ) != nil
    }
}
