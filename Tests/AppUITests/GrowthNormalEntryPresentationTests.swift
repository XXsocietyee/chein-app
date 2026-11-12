import XCTest

/// Additional presentation checks on the unchanged synthetic fixture. Not live evidence.
final class GrowthNormalEntryPresentationTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }
    private func launch(_ scenario: String, language: String = "en", large: Bool = false) {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "zh_CN",
            "--uitesting-module", "growthCenter", "--uitesting-growth-scenario", scenario]
        if large { app.launchArguments += ["--uitesting-large-text", "--uitesting-dark"] }
        app.launch()
    }
    private func reveal(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: 5)
        for _ in 0..<12 { if element.exists && element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.exists, app.debugDescription); XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    // B68 (u10-screens): the page carries the mini-program section set (score card, 我的足迹, 我的徽章);
    // missions, check-ins and streak moved off this page (the profile growth card keeps check-ins and streak).
    func testEnglishEmptyRecordsAreExplicitWithoutInventedMissionAction() {
        launch("empty")
        reveal(app.descendants(matching: .any)["growth.completedTopics"].firstMatch)
        reveal(app.descendants(matching: .any)["growth.badges.empty"].firstMatch)
        XCTAssertFalse(app.buttons["growth.mission.complete"].exists)
        XCTAssertFalse(app.buttons["growth.checkin"].exists)
        XCTAssertFalse(app.staticTexts["growth.missions.empty"].exists)
    }
    func testChineseLargeTypeReadOnlyEmptyStatesRemainReachable() {
        launch("empty", language: "zh-Hans", large: true)
        assertFixtureEnvironment(in: app, colorScheme: "dark", dynamicTypeSize: "accessibility3")
        reveal(app.staticTexts["还没有点亮任何徽章"])
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        let refresh = app.buttons["growth.refresh"]
        XCTAssertTrue(refresh.exists)
        refresh.tap()
        reveal(app.staticTexts["还没有点亮任何徽章"])
    }
    func testFootprintMetricsStayAvailableAcrossNativeBoardReturn() {
        launch("content")
        let mileage = app.descendants(matching: .any)["growth.mileage"].firstMatch
        reveal(mileage)
        for _ in 0..<4 { app.swipeDown() }
        let board = app.buttons["growth.openLeaderboard"]; reveal(board); board.tap()
        XCTAssertTrue(app.navigationBars["Leaderboard"].waitForExistence(timeout: 5))
        app.navigationBars["Leaderboard"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Growth center"].waitForExistence(timeout: 5))
        reveal(mileage)
        reveal(app.descendants(matching: .any)["growth.completedTopics"].firstMatch)
    }
}
