import XCTest

/// Slow, assertion-light tours for screen recording: simctl cannot tap, so these drive the hero-zoom and tab-pill
/// continuity while a recorder runs (`xcrun simctl io <udid> recordVideo ...`). Pauses are deliberate so every animation
/// is captured; the only assertions are element existence.
final class MotionTourTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }

    private func launch(fixture: String, extra: [String] = []) {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--design-fixture", fixture] + extra
        app.launch()
        skipOnboardingIfPresent(in: app)
    }
    private func pause(_ seconds: TimeInterval) { _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pause")], timeout: seconds) }

    /// Taps once the element exists, scrolling a little when it is below the fold.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), app.debugDescription, file: file, line: line)
        for _ in 0..<6 where !element.isHittable { app.swipeUp(velocity: .slow) }
        element.tap()
    }
    /// Back along the same path: the nav bar back button, else the interactive edge swipe.
    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists, back.isHittable { back.tap() } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        }
    }

    /// d2-home: Today card action, then rail cards (feed card → activity / topic zoom).
    func testTour1TodayAndRailCardsZoom() {
        launch(fixture: "d2-home", extra: ["--design-today", "activity"])
        let today = app.otherElements["homeFeed.today.clubEvent"]
        XCTAssertTrue(today.waitForExistence(timeout: 30), app.debugDescription)
        pause(1.0)
        tap(app.buttons["homeFeed.today.action"])
        pause(1.5)
        goBack()
        pause(1.0)
        let rail = app.buttons["homeFeed.recommended.topic.7"]
        tap(rail)
        pause(1.5)
        goBack()
        pause(1.0)
        let nearby = app.buttons["homeFeed.nearby.activity.7"]
        if nearby.exists || nearby.waitForExistence(timeout: 5) { tap(nearby); pause(1.5); goBack(); pause(1.0) }
    }

    /// clubcards-home: club row card and photo card → club detail.
    func testTour2ClubCardZoom() {
        launch(fixture: "clubcards-home")
        let row = app.buttons["fixture.club.Riverside Runners"]
        tap(row)
        pause(1.5)
        goBack()
        pause(1.0)
        let photo = app.buttons["fixture.club.Night Market Crew"]
        tap(photo)
        pause(1.5)
        goBack()
        pause(1.0)
        tap(photo)
        pause(1.5)
        goBack()
        pause(1.0)
    }

    /// ia-passport: stamp cells (earned, then locked) → stamp detail.
    func testTour3PassportStampZoom() {
        launch(fixture: "ia-passport")
        tap(app.buttons["passport.stamp.0"])
        pause(2.0)
        goBack()
        pause(1.0)
        tap(app.buttons["passport.stamp.8"])
        pause(2.0)
        goBack()
        pause(1.0)
    }

    /// ia-tabs: each tab in turn, then back to the first, so the pill stretches and lands four times.
    func testTour4TabPill() {
        launch(fixture: "ia-tabs")
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20), app.debugDescription)
        pause(1.2)
        for title in ["Roam", "Clubs", "Passport", "Explore"] {
            let tab = bar.buttons[title]
            XCTAssertTrue(tab.exists, app.debugDescription)
            tab.tap()
            pause(1.2)
        }
    }
}
