import XCTest

/// Offline journeys for team play, registration points, and payout bind.
/// These cases are authored only. This file does not run them and does not claim a compile.
final class Cur3OfflineUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }

    func testTeamPlaySharedHintSkipTimerExpiryAndTotalScore() {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--design-fixture", "cur3-team-play"]
        app.launch()
        let hint = app.buttons["teamPool.useHint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 10), app.debugDescription)
        let score = app.descendants(matching: .any)["teamPool.run.score"]
        XCTAssertEqual(score.label, "—")
        hint.tap()
        let shared = app.descendants(matching: .any)["teamPool.hint"]
        XCTAssertTrue(shared.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(shared.label.contains("Shared fixture hint"))
        app.buttons["teamPool.useSkip"].tap()
        let named = app.buttons["teamPool.skip.confirm"]
        let labeled = app.buttons["Confirm team skip"]
        let confirm = named.waitForExistence(timeout: 5) ? named : labeled
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), app.debugDescription)
        confirm.tap()
        XCTAssertTrue(app.descendants(matching: .any)["teamPool.skipped"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.descendants(matching: .any)["teamPool.timerExpired"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.descendants(matching: .any)["teamPool.run.score"].label, "42")
        XCTAssertFalse(app.buttons["registration.pay.submit"].exists)
    }

    func testRegistrationPointsRefusalAsksForRequoteAndKeepsPayClosed() {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--uitesting-registration-fixture", "pointsRefused"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Activity registration"].waitForExistence(timeout: 10), app.debugDescription)
        let points = app.switches["registration.form.usePoints"]
        reveal(points)
        points.tap()
        let refusal = app.descendants(matching: .any)["registration.form.pointsRefusal"]
        XCTAssertTrue(refusal.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(refusal.label.contains("support points"), refusal.label)
        XCTAssertEqual(points.value as? String, "0")
        let refresh = app.buttons["registration.form.refreshQuote"]
        reveal(refresh)
        refresh.tap()
        XCTAssertTrue(refusal.waitForExistence(timeout: 5))
        let closed = app.descendants(matching: .any)["registration.pay.closed"]
        XCTAssertTrue(closed.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["registration.pay.submit"].exists)
        XCTAssertFalse(app.buttons["registration.form.confirm"].exists)
    }

    func testPayoutBindStaysClosedOnProductionAndCanOpenOnTestHost() {
        launchPayout("cur3-payout-closed")
        let closed = app.descendants(matching: .any)["payoutReceiver.closed"]
        XCTAssertTrue(closed.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(closed.label.contains("sends nothing"), closed.label)
        XCTAssertFalse(app.buttons["payoutReceiver.bind"].exists)
        XCTAssertFalse(app.buttons["payoutReceiver.bind.confirm"].exists)
        app.terminate()
        launchPayout("cur3-payout-open")
        let bind = app.buttons["payoutReceiver.bind"]
        XCTAssertTrue(bind.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.buttons["payoutReceiver.bind.confirm"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["payoutReceiver.closed"].exists)
    }

    private func launchPayout(_ fixture: String) {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--design-fixture", fixture]
        app.launch()
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<12 { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.exists && element.isHittable, app.debugDescription)
    }
}
