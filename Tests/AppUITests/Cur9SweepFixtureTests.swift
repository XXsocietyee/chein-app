import XCTest

/// One UI test for ui/h-sweep-2. Launches the ledger fixture and reads the ledger
/// and settlement text. Does not tap retry, submit, pay, or use the network.
/// This file is not executed on the VM.
final class Cur9SweepFixtureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLedgerAndSettlementText() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting-reset-language",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--design-fixture", "cur9-ledger"
        ]
        app.launch()
        defer { app.terminate() }

        let ledger = app.staticTexts["Direct Receivable Ledger"]
        XCTAssertTrue(ledger.waitForExistence(timeout: 20), "Ledger title did not appear. \(app.debugDescription)")
        let settlement = app.staticTexts["Personal Settlement Clubs"]
        XCTAssertTrue(settlement.waitForExistence(timeout: 5), "Settlement title did not appear")
        let closed = app.staticTexts["Personal payout settlement is closed in this release"]
        XCTAssertTrue(closed.waitForExistence(timeout: 5), "Closed settlement state did not appear")
        XCTAssertFalse(app.staticTexts["Unknown design fixture"].exists)
        XCTAssertFalse(app.buttons["Retry"].exists)
    }
}
