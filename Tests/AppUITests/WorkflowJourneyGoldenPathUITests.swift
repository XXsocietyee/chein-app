import XCTest

/// Task 66 golden paths. DEBUG fixtures only. No network.
/// `WorkflowJourneyGoldenPathUITests` was not on this tip, so this file is the new host.
/// XCUITest was not executed here: this VM has no swiftc and no simulator.
final class WorkflowJourneyGoldenPathUITests: XCTestCase {
    private var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        attachFailureScreenshot(self, app: app)
        app?.terminate()
        app = nil
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let value = XCUIApplication()
        value.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + arguments
        value.launch()
        app = value
        return value
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func tap(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, in: app)
        XCTAssertTrue(revealFixtureElement(target, in: app), "missing \(id)", file: file, line: line)
        target.tap()
    }

    private func assertNoPaymentSuccess(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.buttons["Pay"].exists, file: file, line: line)
        let succeeded = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "succeeded")).firstMatch
        XCTAssertFalse(succeeded.exists, file: file, line: line)
        XCTAssertFalse(app.staticTexts["已开通"].exists, file: file, line: line)
    }

    /// Waits until one of `labels` is on screen. Returns the label that appeared.
    private func waitForAny(_ labels: [String], in app: XCUIApplication, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for label in labels where app.staticTexts[label].exists { return label }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("missing \(labels)", file: file, line: line)
        return ""
    }

    /// `--design-fixture merchant-home`. Home, then orders, then hosted projects. Offline reader.
    func testMerchantHomeOpensOrdersThenProjects() {
        let app = launch(["--design-fixture", "merchant-home"])
        XCTAssertTrue(element("merchant.store.name", in: app).waitForExistence(timeout: 8))
        tap("merchant.orders.entry", in: app)
        XCTAssertTrue(element("merchant.order.row.101", in: app).waitForExistence(timeout: 8))
        let back = app.navigationBars.buttons["Merchant dashboard"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(element("merchant.store.name", in: app).waitForExistence(timeout: 5))
        tap("merchant.projects.entry", in: app)
        let tabs = app.segmentedControls["merchant.projectBrowser.tabs"]
        XCTAssertTrue(revealFixtureElement(tabs, in: app), "missing merchant.projectBrowser.tabs")
        tabs.buttons["Activities"].tap()
        XCTAssertTrue(element("merchant.project.row.activity:201", in: app).waitForExistence(timeout: 8))
    }

    /// Wallet list is the offline commerce fixture. Payout stays on `ReviewedAreaSwitch`:
    /// `cur4-edition-empty-closed` uses www.chengyinhub.com and must not show a payment as succeeded.
    /// The open fixture host is fixture.example. The receiver fixture keeps payout off (`payoutEnabled` false).
    func testWalletAndPayoutDoNotShowSuccessOnProductionHost() {
        let wallet = launch(["--wallet-commerce-fixture"])
        tap("wallet.fixture.income", in: wallet)
        XCTAssertTrue(element("wallet.income.detail.open.4", in: wallet).waitForExistence(timeout: 8))
        assertNoPaymentSuccess(in: wallet)
        wallet.terminate()

        let closed = launch(["--design-fixture", "cur4-edition-empty-closed"])
        let closedCopy = waitForAny(["No shareable free-explore editions yet", "还没有可分享的自由探索期次"], in: closed)
        XCTAssertTrue(element("club.editions.emptyReason", in: closed).exists)
        XCTAssertFalse(closedCopy.contains("owner") || closedCopy.contains("主理人"))
        XCTAssertFalse(closed.staticTexts["Only the owner or an admin can see editions"].exists)
        XCTAssertFalse(closed.staticTexts["仅主理人或管理员可查看期次"].exists)
        assertNoPaymentSuccess(in: closed)
        closed.terminate()

        let opened = launch(["--design-fixture", "cur4-edition-empty"])
        _ = waitForAny(["Only the owner or an admin can see editions", "仅主理人或管理员可查看期次"], in: opened)
        assertNoPaymentSuccess(in: opened)
        opened.terminate()

        let receiver = launch(["--owner-decision-fixture", "receiver"])
        XCTAssertTrue(element("club.receiver.screen", in: receiver).waitForExistence(timeout: 8))
        _ = waitForAny(["Starts when the platform turns payouts on", "平台开通后开始"], in: receiver)
        assertNoPaymentSuccess(in: receiver)
    }

    /// `--design-fixture e5-external-game` mounts the library with no session.
    /// The catalog fails closed. Do not tap submit. There is no detail row and no install control.
    func testExternalGamesFailClosedWithoutSessionDoesNotSubmit() {
        let app = launch(["--design-fixture", "e5-external-game"])
        XCTAssertTrue(element("externalGame.catalog", in: app).waitForExistence(timeout: 8))
        let failed = element("externalGame.catalog.error", in: app)
        XCTAssertTrue(revealFixtureElement(failed, in: app), app.debugDescription)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "externalGame.install.")).count, 0)
        XCTAssertTrue(element("externalGame.submitReview", in: app).exists)
        tap("externalGame.submissions", in: app)
        XCTAssertTrue(element("externalGame.submissions.root", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("externalGame.submissions.error", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("externalGame.submissions.empty", in: app).exists)
    }

    /// `--design-fixture e4-deregister`. Delete review is on screen. The confirm control stays disabled.
    func testComplianceDeleteReviewStaysUnconfirmed() {
        let app = launch(["--design-fixture", "e4-deregister"])
        XCTAssertTrue(element("compliance.reviewWarning", in: app).waitForExistence(timeout: 8))
        let status = element("compliance.serverStatus", in: app)
        XCTAssertTrue(revealFixtureElement(status, in: app, requiresHittable: false), "missing compliance.serverStatus")
        let submit = element("compliance.submit", in: app)
        XCTAssertTrue(revealFixtureElement(submit, in: app, requiresHittable: false), app.debugDescription)
        XCTAssertFalse(submit.isEnabled)
        XCTAssertFalse(element("compliance.submit.confirm", in: app).exists)
        XCTAssertFalse(element("compliance.completed", in: app).exists)
    }
}
