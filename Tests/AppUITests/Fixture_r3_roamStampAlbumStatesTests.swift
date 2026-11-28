import XCTest

/// mp-roam r3. DEBUG design fixtures for 集邮册 (MP scene-roam-stamp-album) empty and error states.
final class Fixture_r3_roamStampAlbumStatesTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testAlbumEmptyShowsMPEmptyState() {
        let app = launch("r3-roam-stamp-album-empty", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["roam.experience.album.empty"].firstMatch.waitForExistence(timeout: 20))
    }

    func testAlbumErrorShowsMPTitleAndRetry() {
        let app = launch("r3-roam-stamp-album-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roam.experience.error"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Couldn’t open the stamp album"].firstMatch.waitForExistence(timeout: 5))
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
