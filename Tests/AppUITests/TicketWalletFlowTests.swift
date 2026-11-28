import XCTest

/// Integration requires ModuleFixture.ticketWallet -> TicketWalletFixtureHostView.
final class TicketWalletFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }
    private func launch(_ scenario: String = "content") {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--uitesting-module", "ticketWallet", "--uitesting-ticket-wallet-scenario", scenario]
        app.launch()
    }
    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 5)
        for _ in 0..<6 { if element.exists && element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.exists, app.debugDescription, file: file, line: line)
        XCTAssertTrue(element.isHittable, app.debugDescription, file: file, line: line)
    }
    /// Copy lookup by label across every element type, so a restyle (static text -> combined element) does not hide real copy.
    private func element(labelContaining text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
    private func revealText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = element(labelContaining: text)
        _ = element.waitForExistence(timeout: 5)
        // Drag from the lower half: a swipe that starts on the pass card is taken by its tilt gesture and never scrolls the list.
        for _ in 0..<10 {
            if element.exists { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        }
        XCTAssertTrue(element.exists, "Missing copy: \(text)\n\(app.debugDescription)", file: file, line: line)
    }
    func testWalletDetailEntitlementsBackAndReopenNeverOffersCodeOrPayment() {
        launch()
        let row = app.buttons["ticketWallet.row.901"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        attachFixtureScreenshot(self,app:app,name:"Ticket wallet initial content")
        row.tap()
        XCTAssertTrue(app.navigationBars["Ticket details"].waitForExistence(timeout: 5))
        // The Benefits section shows the pending count row and one row per chapter (title rendered by TicketWalletEntitlementRow).
        revealText("Chapters awaiting redemption")
        XCTAssertTrue(app.descendants(matching: .any)["ticketWallet.pendingChapters"].exists)
        revealText("Sample pending chapter")
        attachFixtureScreenshot(self,app:app,name:"Ticket detail entitlements")
        revealText("Redemption codes are not available in this native version yet")
        // Protection: the detail never offers a redemption code or a payment action, under any label spelling.
        XCTAssertFalse(app.buttons["Show redemption code"].exists)
        XCTAssertFalse(app.buttons["Pay"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'redemption code' OR label MATCHES[c] '^pay.*'")).count, 0)
        app.navigationBars["Ticket details"].buttons.firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.staticTexts["West Lake Night Walk"].waitForExistence(timeout: 5))
    }
    func testPartialEmptyIsNotReportedAsCompleteEmptyWallet() {
        launch("partialEmpty")
        XCTAssertTrue(app.staticTexts["Activity tickets could not be loaded"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No tickets found right now. Your ticket wallet may not show everything."].exists)
        XCTAssertFalse(app.staticTexts["No tickets yet. Join an activity and your ticket lands here."].exists)
        app.buttons["ticketWallet.retry"].tap()
        XCTAssertTrue(app.staticTexts["Activity tickets could not be loaded"].waitForExistence(timeout: 5))
    }
    func testUnavailableDetailRetryDoesNotShowCachedContent() {
        launch("unavailable")
        XCTAssertTrue(app.staticTexts["This ticket is unavailable"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["West Lake Night Walk"].exists)
        app.buttons["ticketWallet.retry"].tap()
        XCTAssertTrue(app.staticTexts["This ticket is unavailable"].waitForExistence(timeout: 5))
    }
    func testRefreshReadsCurrentStatusInsteadOfKeepingTheOldTicket() {
        launch("refreshed")
        XCTAssertTrue(app.staticTexts["West Lake Night Walk"].waitForExistence(timeout: 10))
        app.buttons["ticketWallet.detail.refresh"].tap()
        XCTAssertTrue(app.staticTexts["Sample cancelled after refresh"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["West Lake Night Walk"].exists)
        XCTAssertFalse(app.staticTexts["Sample pending chapter"].exists)
    }
    func testSignOutClearsDetailAndReturnsToLoginGate() {
        launch("sessionChange")
        let row = app.buttons["ticketWallet.row.901"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.navigationBars["Ticket details"].waitForExistence(timeout: 5))
        app.buttons["ticketWallet.fixture.signOut"].tap()
        XCTAssertTrue(app.staticTexts["Sign in to see your tickets"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["West Lake Night Walk"].exists)
        XCTAssertFalse(app.staticTexts["Sample pending chapter"].exists)
    }
    func testEmptyFailureGuestAndConfigurationStatesAreDistinct() {
        for (scenario, message) in [("empty", "No tickets yet. Join an activity and your ticket lands here."), ("failure", "Tickets could not be loaded"), ("guest", "Sign in to see your tickets"), ("unconfigured", "Tickets aren't available right now.")] {
            launch(scenario)
            XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 10), "Scenario: \(scenario)")
            if scenario != "empty" { XCTAssertFalse(app.staticTexts["No tickets yet. Join an activity and your ticket lands here."].exists) }
            XCTAssertFalse(app.staticTexts["West Lake Night Walk"].exists)
            app.terminate()
        }
    }
}
