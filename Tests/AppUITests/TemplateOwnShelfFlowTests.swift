import XCTest

/// Authored synthetic-only cases. Apple/XCUITest runtime NOT_RUN.
@MainActor final class TemplateOwnShelfFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication,
                        towardTop: Bool = false, requiresHittable: Bool = true) {
        let visible = revealFixtureElement(element, in: app, towardTop: towardTop,
                                           maximumSwipes: 12, requiresHittable: requiresHittable)
        if !visible {
            // Capture before the assertion aborts this synthetic-only test. A defer
            // cannot be relied on to run after XCTest's stop-on-failure interruption.
            // Fixed synthetic control facts only: no arbitrary text, IDs or account data.
            for identifier in ["templateAuthor.shelf.refresh", "memberTemplate.mine.901",
                               "templateAuthor.shelf.library.901", "templateAuthor.shelf.delete.901"] {
                let control = app.buttons[identifier]
                print("OWNED_SHELF_FIXTURE_REVEAL \(identifier) exists=\(control.exists) enabled=\(control.exists && control.isEnabled) hittable=\(control.exists && control.isHittable)")
            }
            attachFixtureScreenshot(self, app: app, name: "Owned shelf reveal failure")
        }
        XCTAssertTrue(visible, app.debugDescription)
        XCTAssertTrue(element.exists, app.debugDescription)
        if requiresHittable { XCTAssertTrue(element.isHittable, app.debugDescription) }
    }
    func app(_ extras: [String] = [], language: String = "en") -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting-reset-language", "--ui-template-authoring", "--template-author-shelf", "-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "zh_CN"] + extras; app.launch(); return app
    }
    func testOwnedDetailBackAndReopenKeepsStableDestination() {
        let app = app(); defer { attachFailureScreenshot(self, app: app); app.terminate() }
        for _ in 0..<2 {
            let detail = app.buttons["memberTemplate.mine.901"]
            reveal(detail, in: app); detail.tap()
            let title = app.staticTexts["Synthetic owned detail"]
            XCTAssertTrue(title.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertFalse(app.buttons["templateAuthor.shelf.refresh"].isHittable)
            app.navigationBars.buttons.firstMatch.tap()
            let refresh = app.buttons["templateAuthor.shelf.refresh"]
            XCTAssertTrue(refresh.waitForExistence(timeout: 5))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: refresh)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            reveal(app.buttons["templateAuthor.shelf.library.901"], in: app)
            XCTAssertTrue(app.buttons["templateAuthor.shelf.library.901"].isEnabled)
            app.buttons["templateAuthor.fixture.reopen"].tap()
        }
    }
    func testLibraryReviewShowsIdentityAndCancellationDoesNotSubmit() {
        let app = app(); defer { attachFailureScreenshot(self, app: app); app.terminate() }; let button = app.buttons["templateAuthor.shelf.library.901"]
        reveal(button, in: app); XCTAssertTrue(button.waitForExistence(timeout: 3)); button.tap()
        let question = app.staticTexts["templateAuthor.shelf.question"]
        XCTAssertTrue(question.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["templateAuthor.shelf.cancel"].tap()
        XCTAssertFalse(app.buttons["templateAuthor.shelf.confirm"].exists)
        XCTAssertTrue(button.isEnabled)
    }
    func testDeleteRequiresSeparateReviewAndSimulationIsLabelled() {
        let app = app(); defer { attachFailureScreenshot(self, app: app); app.terminate() }; let button = app.buttons["templateAuthor.shelf.delete.901"]
        reveal(button, in: app); XCTAssertTrue(button.waitForExistence(timeout: 3)); XCTAssertTrue(button.isEnabled); button.tap()
        XCTAssertTrue(app.staticTexts["templateOwnShelf.delete.title"].waitForExistence(timeout: 5))
        let confirm = app.buttons["templateAuthor.shelf.confirm"]
        reveal(confirm, in: app); confirm.tap()
        let status = app.staticTexts["templateAuthor.shelf.status"]
        reveal(status, in: app)
        XCTAssertEqual(status.label, "Example run finished. Nothing was saved or published.")
    }
    func testUnknownLocksBothActionsAcrossReopen() {
        let app = app(["--template-author-unknown"]); defer { attachFailureScreenshot(self, app: app); app.terminate() }; let button = app.buttons["templateAuthor.shelf.delete.901"]
        reveal(button, in: app); XCTAssertTrue(button.waitForExistence(timeout: 3)); XCTAssertTrue(button.isEnabled); button.tap()
        let confirm = app.buttons["templateAuthor.shelf.confirm"]
        reveal(confirm, in: app); confirm.tap()
        let status = app.staticTexts["templateAuthor.shelf.status"]
        reveal(status, in: app)
        XCTAssertEqual(status.label, "We couldn’t confirm whether your last change went through. Changes are paused until it’s resolved.")
        app.buttons["templateAuthor.fixture.reopen"].tap()
        reveal(button, in: app, requiresHittable: false); XCTAssertTrue(button.waitForExistence(timeout: 3)); XCTAssertFalse(button.isEnabled)
        let library = app.buttons["templateAuthor.shelf.library.901"]
        reveal(library, in: app, towardTop: true, requiresHittable: false)
        XCTAssertFalse(app.buttons["templateAuthor.shelf.library.901"].isEnabled)
    }
    func testAccountChangeDismissesReviewAndSignoutClearsShelf() {
        let app = app(); defer { attachFailureScreenshot(self, app: app); app.terminate() }; let button = app.buttons["templateAuthor.shelf.library.901"]
        XCTAssertTrue(button.waitForExistence(timeout: 3)); button.tap()
        let signOut = app.buttons["fixtureTemplate.review.signOut"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(signOut.isHittable, app.debugDescription); signOut.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, app.debugDescription)
        XCTAssertFalse(app.buttons["templateAuthor.shelf.confirm"].exists)
        XCTAssertFalse(app.buttons["fixtureTemplate.review.signOut"].exists)
    }
    func testDefaultDisabledHasNoMutationConfirmation() {
        let app = app(["--template-author-disabled"])
        XCTAssertTrue(app.buttons["templateAuthor.shelf.refresh"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["templateAuthor.shelf.confirm"].exists)
        XCTAssertFalse(app.buttons["templateAuthor.shelf.delete.901"].exists)
    }
    func testChineseLargeTextCanCancelReview() {
        let app = app(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], language: "zh-Hans")
        defer { attachFailureScreenshot(self, app: app); app.terminate() }
        let button = app.buttons["templateAuthor.shelf.library.901"]
        reveal(button, in: app); button.tap()
        let cancel = app.buttons["templateAuthor.shelf.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(cancel.label, "取消"); cancel.tap()
        XCTAssertFalse(app.buttons["templateAuthor.shelf.confirm"].exists)
        XCTAssertTrue(button.isEnabled)
    }
    func testDeleteReviewShowsSourceDangerCopyAndCancelDoesNotSubmit() {
        let app = app(); defer { attachFailureScreenshot(self, app: app); app.terminate() }
        let button = app.buttons["templateAuthor.shelf.delete.901"]
        reveal(button, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 3)); button.tap()
        let question = app.staticTexts["templateOwnShelf.delete.title"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        attachFixtureScreenshot(self, app: app, name: "Owned template deletion confirmation")
        app.buttons["templateAuthor.shelf.cancel"].tap()
        XCTAssertFalse(app.buttons["templateAuthor.shelf.confirm"].exists)
        XCTAssertTrue(button.isEnabled)
        button.tap()
        let confirm = app.buttons["templateAuthor.shelf.confirm"]
        reveal(confirm, in: app)
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
    }
    func testOwnedCardShowsZeroDurationAndNoMarketplacePublishButton() {
        let app = app(); defer { attachFailureScreenshot(self, app: app); app.terminate() }
        let duration = app.staticTexts["templateOwnShelf.card.duration.901"]
        reveal(duration, in: app)
        XCTAssertEqual(duration.label, "0 min")
        attachFixtureScreenshot(self, app: app, name: "Owned template card with known zero duration")
        XCTAssertFalse(app.buttons["templateOwnShelf.market.plan.901"].exists)
        XCTAssertFalse(app.buttons["templateOwnShelf.market.held.901"].exists)
        let library = app.buttons["templateAuthor.shelf.library.901"]
        reveal(library, in: app)
        XCTAssertTrue(library.isEnabled)
    }
}
