import XCTest

/// One UI test for ui/h-offline-2. Launches the offline sync fixture and checks the
/// banner text. Does not tap retry, submit, pay, or use the network.
/// This file is not executed on the VM.
final class Cur9OfflineFixtureTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOfflineWriteBannerAndSyncStatus() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting-reset-language",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "--design-fixture", "cur9-offline-sync"
        ]
        app.launch()
        defer { app.terminate() }

        let banner = app.descendants(matching: .any)["cy.offlineBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 20), "Offline banner did not appear. \(app.debugDescription)")
        let sync = app.staticTexts["Connection lost. Location sync is paused."]
        XCTAssertTrue(sync.waitForExistence(timeout: 5), "Roam sync status did not appear")
        let write = app.descendants(matching: .any)["cy.offlineWrite.status"]
        XCTAssertTrue(write.waitForExistence(timeout: 5), "Offline write banner did not appear")
        XCTAssertFalse(app.staticTexts["Unknown design fixture"].exists)
    }
}
