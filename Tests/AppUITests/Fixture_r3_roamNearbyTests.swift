import XCTest

/// mp-roam r3. DEBUG design fixtures for 附近 (MP subpackageRoam/nearby): team list, 附近暂无节点 and 附近信息获取失败 · 重试 resolve and render.
final class Fixture_r3_roamNearbyTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testNearbyContentShowsTeamRow() {
        let app = launch("r3-roam-nearby", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["nearby.team.611"].firstMatch.waitForExistence(timeout: 20))
    }

    func testNearbyEmptyShowsMPEmpty() {
        let app = launch("r3-roam-nearby-empty", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["nearby.list.empty"].firstMatch.waitForExistence(timeout: 20))
    }

    func testNearbyErrorShowsRetry() {
        let app = launch("r3-roam-nearby-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["nearby.w208.issue.action"].firstMatch.waitForExistence(timeout: 20))
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
