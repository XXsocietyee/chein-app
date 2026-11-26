import XCTest

/// Authored synthetic UI coverage. Runtime and accessibility validation require Apple execution.
final class TopicTemplateNameSearchFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }
    private func launch(chinese: Bool = false) {
        app.launchArguments = ["--uitesting-reset-language", "--uitesting-module", "publicPlayTemplate",
                               "-AppleLanguages", chinese ? "(zh-Hans)" : "(en)", "-AppleLocale", chinese ? "zh_CN" : "en_US"]
        if chinese { app.launchArguments += ["--uitesting-max-text", "--uitesting-dark", "--uitesting-reduce-motion"] }
        app.launch()
        if chinese { assertFixtureEnvironment(in: app, colorScheme: "dark", dynamicTypeSize: "accessibility5") }
    }
    /// The shelf capsule is the only search entrance. It pushes the existing global search page.
    private func openGlobalSearch(maximumSwipes: Int = 12) {
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        let capsule = app.descendants(matching: .any)["discovery.globalSearch"].firstMatch
        XCTAssertTrue(revealFixtureElement(capsule, in: app, maximumSwipes: maximumSwipes), app.debugDescription)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "discovery.globalSearch").count, 1)
        XCTAssertTrue(capsule.isHittable, app.debugDescription)
        capsule.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
    }
    func testTopicShelfCapsuleOpensGlobalSearch() {
        launch()
        let topics = app.buttons["shelf.topic.all"]
        XCTAssertTrue(topics.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(revealFixtureElement(topics, in: app), app.debugDescription)
        openGlobalSearch()
    }
    func testGamesShelfKeepsCategoryChipsAndOpensTheSameSearch() {
        launch()
        let picker = app.segmentedControls["discovery.shelf"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), app.debugDescription)
        picker.buttons.element(boundBy: 1).tap()
        let games = app.buttons["shelf.game.all"]
        XCTAssertTrue(games.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(revealFixtureElement(games, in: app), app.debugDescription)
        openGlobalSearch()
    }
    func testChineseMaximumTextCapsuleOpensGlobalSearch() {
        launch(chinese: true)
        openGlobalSearch(maximumSwipes: 16)
    }
}
