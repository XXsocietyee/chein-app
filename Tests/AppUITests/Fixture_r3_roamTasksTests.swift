import XCTest

/// mp-roam r3. DEBUG design fixtures for 官方活动 (MP scene-roam-task-list): list, cy-empty and cy-error · 重试 resolve and render.
final class Fixture_r3_roamTasksTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testTasksContentShowsLiveEvent() {
        let app = launch("r3-roam-tasks", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["roam.tasks.event.71"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["roam.tasks.results"].firstMatch.exists)
    }

    func testTasksEmptyShowsMPEmpty() {
        let app = launch("r3-roam-tasks-empty", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roam.tasks.empty"].firstMatch.waitForExistence(timeout: 20))
    }

    func testTasksErrorShowsRetry() {
        let app = launch("r3-roam-tasks-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roam.tasks.error"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(app.state, .runningForeground)
    }

    private func launch(_ fixture: String, language: String) -> XCUIApplication {
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = ["--design-fixture", fixture, "-preferences.language", language]
        app.launch()
        return app
    }
}
