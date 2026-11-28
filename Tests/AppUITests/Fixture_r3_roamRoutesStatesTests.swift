import XCTest

/// mp-roam r3. DEBUG design fixtures for 官方线路 (MP subpackageRoam/official-routes) list, empty and error states
/// on the shipping map-home list.
final class Fixture_r3_roamRoutesStatesTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testRoutesListShowsRows() {
        let app = launch("r3-roam-routes", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["officialRoute.row.1"].firstMatch.waitForExistence(timeout: 20))
    }

    func testRoutesEmptyShowsMPEmptyState() {
        let app = launch("r3-roam-routes-empty", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["officialRoute.list.empty"].firstMatch.waitForExistence(timeout: 20))
    }

    func testRoutesErrorShowsRetry() {
        let app = launch("r3-roam-routes-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["officialRoute.list.error"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Retry"].firstMatch.waitForExistence(timeout: 5))
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
