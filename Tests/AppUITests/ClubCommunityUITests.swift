import XCTest

/// Authored integration tests. Host must mount ClubCommunityFixture under this flag.
/// Apple simulator/build/runtime: NOT_RUN in this Linux delivery.
final class ClubCommunityUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private func app(_ locale: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting-reset-language", "--club-community-fixture", "-AppleLanguages", "(\(locale))", "-AppleLocale", locale]
        app.launch(); return app
    }
    func testFeedCommentAndHistoryNavigation() {
        let app = app()
        // The normal comments action expands an inline reader. Full comments is
        // a separate explicit sheet entry, not a push caused by that first tap.
        func openFullComments() {
            let fullMatches = app.buttons.matching(NSPredicate(format: "label == %@", "Open full comments"))
            let full = fullMatches.firstMatch
            if !full.exists {
                let comments = app.buttons["club.community.comments.20"]
                XCTAssertTrue(comments.waitForExistence(timeout: 5), app.debugDescription)
                comments.tap()
            }
            // The panel's parent identifier propagates to its AX leaves on iOS;
            // use the actual unique, fixed-English fixture button label.
            XCTAssertTrue(full.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertEqual(fullMatches.count, 1, app.debugDescription)
            XCTAssertTrue(revealFixtureElement(full, in: app, maximumSwipes: 4), app.debugDescription)
            full.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        func commentsOpened() -> Bool {
            let opened = app.navigationBars["Comments"].waitForExistence(timeout: 5)
            if !opened {
                let trace = app.descendants(matching: .any).matching(identifier: "club.discussion.fixtureTrace").firstMatch
                let evidence = trace.exists ? String(describing: trace.value) : "trace-unavailable"
                print("QUESTIFY_CLUB_DISCUSSION_PRESENTATION_V1 " + evidence)
            }
            return opened
        }
        XCTAssertTrue(app.otherElements["club.community.post.20"].waitForExistence(timeout: 5))
        openFullComments()
        XCTAssertTrue(commentsOpened(), app.debugDescription)
        XCTAssertTrue(app.otherElements["club.community.comment.30"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Fixture comment"].exists)
        let close = app.navigationBars["Comments"].buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription); close.tap()
        XCTAssertTrue(app.otherElements["club.community.post.20"].waitForExistence(timeout: 5))
        let history = app.buttons["club.community.history.20"]
        for _ in 0..<4 { if history.exists && history.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(history.exists); history.tap()
        XCTAssertTrue(app.staticTexts["Previous public content"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openFullComments()
        XCTAssertTrue(commentsOpened(), app.debugDescription)
        XCTAssertTrue(app.otherElements["club.community.comment.30"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["Fixture comment"].exists)
    }
    func testComposerCancelAndImmutableReview() {
        let app = app()
        app.buttons["club.community.compose"].tap()
        let content = app.textViews["club.community.content"]
        XCTAssertTrue(content.waitForExistence(timeout: 5)); content.tap(); content.typeText("Offline draft")
        app.buttons["club.community.reviewDraft"].tap()
        XCTAssertTrue(app.buttons["club.community.confirm"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Offline draft"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.buttons["club.community.confirm"].exists)
    }
    func testChineseAccessibleComposer() {
        let app = app("zh-Hans")
        XCTAssertTrue(app.buttons["club.community.compose"].waitForExistence(timeout: 5))
        app.buttons["club.community.compose"].tap()
        XCTAssertTrue(app.textViews["club.community.content"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
    }

    // r11 A8-03: the 俱乐部活动 section left the ClubHomeView tab root (MP talent/list/index.wxml:57-95 is the create
    // row plus one club list), so the three home-topic navigation tests (`club.event.91`) went with it. Club events
    // are reached from the club detail page.
}
