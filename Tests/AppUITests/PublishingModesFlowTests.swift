import XCTest

/// Authored, NOT_RUN. Integrator must mount PublishingModesFixtureHost for this flag.
@MainActor final class PublishingModesFlowTests: XCTestCase {
    private func launch(_ language: String = "en") -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting-reset-language", "--ui-publishing-modes", "-AppleLanguages", "(\(language))"]; app.launch(); return app
    }
    /// mp-r3-publish: MP V3-44 removed quick setup; the menu offers the publish sheet's three choices in MP order
    /// (自由探索, 城市定向, 互动), and a topic type opens the professional editor directly.
    func testMenuOffersTheThreeMiniProgramChoicesInOrder() {
        let app = launch()
        let explore = app.buttons["publishModes.pro.freeExplore"], city = app.buttons["publishModes.pro.city"], interaction = app.buttons["publishModes.interaction"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(explore.label, "Free exploration"); XCTAssertEqual(city.label, "City orientation"); XCTAssertEqual(interaction.label, "Interactive")
        XCTAssertLessThan(explore.frame.minY, city.frame.minY); XCTAssertLessThan(city.frame.minY, interaction.frame.minY)
        XCTAssertFalse(app.buttons["Quick route setup"].exists)
        explore.tap()
        let editor = app.staticTexts["publishModes.fixture.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5)); XCTAssertEqual(editor.label, "freeExplore")
        XCTAssertFalse(app.buttons["publishModes.quick.continue"].exists)
    }
    func testActivityIsDistinctFromQuickRoute() {
        let app = launch(); app.buttons["Publish an activity"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["publishModes.activity.start"].firstMatch.waitForExistence(timeout: 5)) // C-A2: read-only row
        XCTAssertFalse(app.buttons["publishModes.quick.continue"].exists)
        // Activity review follows the category, template, collaborator and local-draft
        // sections. The Form does not materialize this button in its initial viewport.
        let review = app.buttons["publishModes.activity.review"]
        for _ in 0..<8 { if review.exists && review.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(review.exists, app.debugDescription)
        XCTAssertTrue(review.isHittable, app.debugDescription)
        XCTAssertTrue(review.isEnabled); review.tap()
        let message = app.staticTexts["publishModes.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(message.label, "Check the required fields, event times and ticket windows. Publishing also requires a current club-leader role.")
        XCTAssertFalse(app.buttons["publishModes.quick.continue"].exists)
        XCTAssertFalse(app.staticTexts["publishModes.fixture.seed"].exists)
    }
    func testIdentityNeverCollectsSensitiveID() {
        let app = launch(); app.buttons["Publisher registration"].tap()
        XCTAssertEqual(app.secureTextFields.count, 0); XCTAssertEqual(app.textFields.count, 0)
    }
    func testChineseEntryIsLocalized() {
        let app = launch("zh-Hans")
        for title in ["自由探索", "城市定向", "互动", "发布活动"] { XCTAssertTrue(app.buttons[title].exists, title) }
        XCTAssertFalse(app.buttons["快速配置"].exists)
    }
}
