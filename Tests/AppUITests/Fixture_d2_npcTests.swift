import XCTest

/// CB706: `--design-fixture d2-npc` stays on the NPC screen in English and Simplified Chinese.
final class Fixture_d2_npcTests: XCTestCase {
    private static let rawDottedKey = NSPredicate(
        format: "label MATCHES %@",
        #"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$"#
    )

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testD2NPCEnglish() {
        launchAndAssert(language: "en", attachmentName: "d2-npc-en")
    }

    func testD2NPCSimplifiedChinese() {
        launchAndAssert(language: "zh-Hans", attachmentName: "d2-npc-zh")
    }

    private func launchAndAssert(language: String, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--design-fixture", "d2-npc", "-preferences.language", language]
        app.launch()

        let firstHittable = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hittable == true"))
            .firstMatch
        XCTAssertTrue(
            firstHittable.waitForExistence(timeout: 30),
            "Timed out waiting for the first hittable element"
        )
        attachScreenshot(app, name: attachmentName)

        let unknown = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Unknown design fixture"))
        XCTAssertEqual(unknown.count, 0, "Unexpected unknown design fixture text")

        let dotted = app.staticTexts.matching(Self.rawDottedKey)
        XCTAssertEqual(
            dotted.count,
            0,
            "Raw dotted key static text: \(dotted.allElementsBoundByIndex.map(\.label))"
        )

        let questify = questifyOutsideDebugLabels(in: app)
        XCTAssertTrue(questify.isEmpty, "Questify outside DEBUG labels: \(questify)")

        XCTAssertEqual(app.state, .runningForeground)
    }

    private func questifyOutsideDebugLabels(in app: XCUIApplication) -> [String] {
        let predicate = NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", "Questify", "DEBUG")
        let types: [XCUIElement.ElementType] = [.staticText, .button, .navigationBar, .textField, .textView]
        return types.flatMap { type in
            app.descendants(matching: type).matching(predicate).allElementsBoundByIndex.map(\.label)
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        guard app.state == .runningForeground || app.state == .runningBackground else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
