import XCTest

/// mp-roam r3. DEBUG design fixtures for 地点详情 (MP scene-roam-poi-detail): node card, 节点无法打开, 节点未开放或已下线 and 找不到这个节点 resolve and render.
final class Fixture_r3_roamPoiTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testPoiContentShowsPlaceHeader() {
        let app = launch("r3-roam-poi", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["roam.place.header"].firstMatch.waitForExistence(timeout: 20))
    }

    func testPoiErrorShowsRetry() {
        let app = launch("r3-roam-poi-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roam.error"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testPoiUnavailableShowsMPEmpty() {
        let app = launch("r3-roam-poi-unavailable", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["roamSub.w208.poi.unavailable"].firstMatch.waitForExistence(timeout: 20))
    }

    func testPoiMissingShowsMPEmpty() {
        let app = launch("r3-roam-poi-missing", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["roamSub.w208.poi.missing"].firstMatch.waitForExistence(timeout: 20))
    }

    private func launch(_ fixture: String, language: String) -> XCUIApplication {
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = ["--design-fixture", fixture, "-preferences.language", language]
        app.launch()
        return app
    }
}
