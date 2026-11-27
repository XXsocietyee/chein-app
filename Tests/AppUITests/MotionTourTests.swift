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
        for _ in 0..<6 where !element.isHittable { scrollPageUp() }
        element.tap()
    }
    /// Scrolls the page from its right margin: a slow swipe from the middle can land on a horizontal card shelf and open a card.
    private func scrollPageUp() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.72)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.985, dy: 0.32)))
    }
    /// Back along the same path: the nav bar back button, else the interactive edge swipe; retried until the detail's back
    /// button is gone, so the next step always starts on the screen the tour came from.
    private func goBack() {
        for _ in 0..<3 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            if back.exists, back.isHittable { back.tap() } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
            }
            pause(1.2)
            if !app.buttons["BackButton"].exists { return }
        }
    }

    /// d2-home: rail cards (feed card → activity / topic zoom). mp-home r3: 首页 follows the MP section order
    /// (hero, 编辑精选, 附近活动, 即将上线, stream); the Today card is no longer on it, so the tour starts at the rails.
    func testTour1TodayAndRailCardsZoom() {
        launch(fixture: "d2-home", extra: ["--design-today", "activity"])
        let nearby = app.buttons["homeFeed.nearby.activity.7"]
        XCTAssertTrue(nearby.waitForExistence(timeout: 30), app.debugDescription)
        pause(1.0)
        // Present in the d2-home AX tree: the nearby shelf card, then the carousel card (both open activity 7).
        tap(app.buttons["homeFeed.nearby.activity.7"])
        pause(1.5)
        goBack()
        pause(1.0)
        let carousel = app.descendants(matching: .any)["carousel.card.activity.7"]
        if carousel.exists || carousel.waitForExistence(timeout: 5) { tap(carousel); pause(1.5); goBack(); pause(1.0) }
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
        for title in ["Roam", "Clubs", "Me", "Home"] {
            let tab = bar.buttons[title]
            XCTAssertTrue(tab.exists, app.debugDescription)
            tab.tap()
            pause(1.2)
        }
    }
}
