import XCTest

/// mp-roam r3. DEBUG design fixtures for 漫游记录 (MP subpackageRoam/history): content, empty and error states resolve and render.
final class Fixture_r3_roamHistoryTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testHistoryContentShowsRunCards() {
        let app = launch("r3-roam-history", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["roam.experience.history.record"].firstMatch.waitForExistence(timeout: 20))
    }

    func testHistoryEmptyShowsMPEmptyState() {
        let app = launch("r3-roam-history-empty", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roam.experience.history.empty"].firstMatch.waitForExistence(timeout: 20))
    }

    func testHistoryErrorShowsRetry() {
        let app = launch("r3-roam-history-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roam.experience.error"].firstMatch.waitForExistence(timeout: 20))
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
