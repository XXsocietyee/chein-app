import XCTest

/// mp-roam r3. DEBUG design fixtures for 本次漫游 (MP scene-roam-session): content, not-found and error states resolve and render.
final class Fixture_r3_roamSessionTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testSessionContentShowsShareAction() {
        let app = launch("r3-roam-session", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["roam.share.open"].firstMatch.waitForExistence(timeout: 20))
    }

    func testSessionMissingShowsMPNotFound() {
        let app = launch("r3-roam-session-missing", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roam.experience.history.missing"].firstMatch.waitForExistence(timeout: 20))
    }

    func testSessionErrorShowsRetry() {
        let app = launch("r3-roam-session-error", language: "en")
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
