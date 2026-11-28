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
        XCTAssertTrue(app.buttons["返回地图"].firstMatch.waitForExistence(timeout: 5))
    }

    func testRoutesErrorShowsRetry() {
        let app = launch("r3-roam-routes-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["officialRoute.list.error"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Retry"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testRouteDetailShowsStops() {
        let app = launch("r3-roam-route", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["officialRoute.detail"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["外滩源庭院"].firstMatch.waitForExistence(timeout: 5))
    }

    func testRouteDetailErrorAndNotFound() {
        let app = launch("r3-roam-route-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["officialRoute.detail.error"].firstMatch.waitForExistence(timeout: 20))
        app.terminate()
        let missing = launch("r3-roam-route-notfound", language: "zh-Hans")
        XCTAssertTrue(missing.descendants(matching: .any)["officialRoute.detail.notFound"].firstMatch.waitForExistence(timeout: 20))
    }

    private func launch(_ fixture: String, language: String) -> XCUIApplication {
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = ["--design-fixture", fixture, "-preferences.language", language]
        app.launch()
        return app
    }
}
