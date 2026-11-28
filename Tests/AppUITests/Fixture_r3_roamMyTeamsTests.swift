import XCTest

/// mp-roam r3. DEBUG design fixtures for 我的队伍 (MP subpackageRoam/my-teams): groups, 还没有队伍 + 附近在招募,
/// 队伍获取失败 · 重试, and the guest gate 登录后查看 (no failure card under it) resolve and render.
final class Fixture_r3_roamMyTeamsTests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testMyTeamsShowsGroups() {
        let app = launch("r3-roam-my-teams", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["nearby.joined.631"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["nearby.application.641"].firstMatch.exists)
    }

    func testMyTeamsEmptyShowsFindOnMap() {
        let app = launch("r3-roam-my-teams-empty", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["nearby.mine.findOnMap"].firstMatch.waitForExistence(timeout: 20))
    }

    func testMyTeamsErrorShowsRetry() {
        let app = launch("r3-roam-my-teams-error", language: "en")
        XCTAssertTrue(app.descendants(matching: .any)["nearby.w208.mine.retry"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testGuestSeesOnlySignInGate() {
        let app = launch("r3-roam-my-teams-signedout", language: "zh-Hans")
        XCTAssertTrue(app.descendants(matching: .any)["nearby.mine.signedOut"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(app.descendants(matching: .any)["nearby.w208.mine.retry"].firstMatch.exists)
    }

    private func launch(_ fixture: String, language: String) -> XCUIApplication {
        let app = XCUIApplication()
        self.app = app
        app.launchArguments = ["--design-fixture", fixture, "-preferences.language", language]
        app.launch()
        return app
    }
}
