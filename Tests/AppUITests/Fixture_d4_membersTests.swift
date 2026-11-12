import XCTest

/// Smoke-launches the DEBUG `d4-members` design fixture in English and Simplified Chinese.
final class Fixture_d4_membersTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testD4MembersEnglish() {
        launch(language: "en")
        assertReadyFixture(screenshotName: "d4-members-en")
    }

    func testD4MembersChinese() {
        launch(language: "zh-Hans")
        assertReadyFixture(screenshotName: "d4-members-zh")
    }

    private func launch(language: String) {
        app.launchArguments = ["--design-fixture", "d4-members", "-preferences.language", language]
        app.launch()
    }

    private func assertReadyFixture(screenshotName: String) {
        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(firstHittable.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertTrue(firstHittable.isHittable)
        XCTAssertEqual(app.state, .runningForeground)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = screenshotName
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let unknown = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, unknown.firstMatch.label)

        var rawDottedKeys: [String] = []
        let staticTexts = app.staticTexts
        for index in 0..<staticTexts.count {
            let label = staticTexts.element(boundBy: index).label.trimmingCharacters(in: .whitespacesAndNewlines)
            if isRawDottedKey(label) {
                rawDottedKeys.append(label)
            }
        }
        XCTAssertEqual(rawDottedKeys, [], rawDottedKeys.joined(separator: ", "))

        let questify = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Questify"))
        for index in 0..<questify.count {
            let label = questify.element(boundBy: index).label
            XCTAssertTrue(label.contains("DEBUG"), "Questify outside a DEBUG label: \(label)")
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// A localization key left untranslated, such as `club.members` or `club.role.creator`.
    private func isRawDottedKey(_ label: String) -> Bool {
        label.range(
            of: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$"#,
            options: .regularExpression
        ) != nil
    }
}
