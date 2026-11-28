import XCTest

final class ProfileAuthorPostsRefreshFlowTests: XCTestCase {
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting", "--uitesting-profile-author-posts-refresh", "--profile-author-posts-scenario", scenario]
        app.launch(); return app
    }
    private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        if !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 3)); button.tap()
    }
    /// 11-28 05:35 sweep: the posts refresh by pull-down (MP), so the tests pull the list instead of tapping a row.
    private func pullToRefresh(_ app: XCUIApplication) {
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        start.press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
    }
    func testRefreshFailureRetainsCardsAndRetryReplacesTail() {
        let app = launch("refreshFailure")
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.101"].waitForExistence(timeout: 3))
        tap("profile.postsRefresh.more", in: app)
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.201"].waitForExistence(timeout: 3))
        app.swipeDown(); pullToRefresh(app)
        XCTAssertTrue(app.staticTexts["profile.postsRefresh.retained"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.201"].exists)
        tap("profile.postsRefresh.retry", in: app)
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.301"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["profile.postsRefresh.post.201"].exists)
    }
    func testEmptyRefreshReplacesPreviouslyVisiblePost() {
        let app = launch("emptyRefresh")
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.101"].waitForExistence(timeout: 3))
        pullToRefresh(app)
        XCTAssertTrue(app.staticTexts["profile.postsRefresh.empty"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["profile.postsRefresh.post.101"].exists)
    }
    func testMoreFailureRetriesContinuation() {
        let app = launch("moreFailure")
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.101"].waitForExistence(timeout: 3))
        tap("profile.postsRefresh.more", in: app); tap("profile.postsRefresh.retry", in: app)
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.201"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.101"].exists)
    }
    func testSignOutRemovesCardsAndShowsExistingSignInMessage() {
        let app = launch("content")
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.101"].waitForExistence(timeout: 3))
        tap("profile.postsFixture.logout", in: app)
        XCTAssertTrue(app.staticTexts["social.profile.postsSignIn"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["profile.postsRefresh.post.101"].exists)
    }
    func testLeavingAndReturningStartsFreshFirstPage() {
        let app = launch("content")
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.101"].waitForExistence(timeout: 3))
        tap("profile.postsFixture.toggle", in: app); tap("profile.postsFixture.toggle", in: app)
        XCTAssertTrue(app.buttons["profile.postsRefresh.post.301"].waitForExistence(timeout: 3))
    }
}
