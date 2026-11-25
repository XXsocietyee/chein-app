import XCTest

/// Mini-program privacy gate parity (components/cy/privacy-gate, pages/privacy). Offline:
/// the unconfigured build sends nothing and the fixture keeps the choice in memory only.
final class EntryUsageConsentFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset-language", "--uitesting-usage-consent-pending", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }

    func testGateRequiresCheckboxAndDeclineKeepsGuestBrowsing() {
        XCTAssertTrue(app.navigationBars["Privacy protection"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["authEntry.gate.lead"].exists)
        let agree = app.buttons["authEntry.gate.agree"]
        // r9 B-PV-04: MP privacy/index.wxml:10, :22 — 同意 stays disabled until 我已阅读并同意 is checked.
        XCTAssertTrue(agree.exists); XCTAssertFalse(agree.isEnabled)
        let checkbox = app.buttons["authEntry.gate.checkbox"]
        XCTAssertTrue(checkbox.exists); checkbox.tap()
        XCTAssertTrue(agree.isEnabled)
        let decline = app.buttons["authEntry.gate.decline"]
        if !decline.isHittable { app.swipeUp() }
        decline.tap()
        let explore = app.tabBars.buttons["Home"]
        XCTAssertTrue(explore.waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Home", "Roam", "Publish", "Clubs", "Me"])
        XCTAssertFalse(app.tabBars.buttons["Publish"].exists)
        app.tabBars.buttons["Me"].tap()
        let player = app.buttons["welcome.player"]
        XCTAssertTrue(player.waitForExistence(timeout: 5)); player.tap()
        XCTAssertTrue(app.buttons["auth.otherChannels"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["authEntry.gate.requiredForSignIn"].exists)
        XCTAssertFalse(app.buttons["auth.otherChannels"].isEnabled)
        XCTAssertFalse(app.buttons["auth.wechat.signIn"].exists)
    }

    func testAgreeingFromSignInEnablesChannelsAndOpensLegalDocuments() {
        let decline = app.buttons["authEntry.gate.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 10))
        if !decline.isHittable { app.swipeUp() }
        decline.tap()
        app.tabBars.buttons["Me"].tap()
        app.buttons["welcome.player"].tap()
        let review = app.buttons["authEntry.gate.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 5)); review.tap()
        let agreement = app.buttons["authEntry.gate.agreement"]
        XCTAssertTrue(agreement.waitForExistence(timeout: 5)); agreement.tap()
        XCTAssertTrue(app.staticTexts["settingsNative.legal.version"].waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()
        let agree = app.buttons["authEntry.gate.agree"]
        XCTAssertTrue(agree.waitForExistence(timeout: 5))
        XCTAssertFalse(agree.isEnabled)
        let checkbox = app.buttons["authEntry.gate.checkbox"]
        if !checkbox.isHittable { app.swipeUp() }
        checkbox.tap()
        XCTAssertTrue(agree.isEnabled)
        if !agree.isHittable { app.swipeUp() }
        agree.tap()
        let channels = app.buttons["auth.otherChannels"]
        XCTAssertTrue(channels.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["authEntry.gate.requiredForSignIn"].exists)
        XCTAssertTrue(channels.isEnabled)
        if !channels.isHittable { app.swipeUp() }
        channels.tap()
        let privacy = app.buttons["auth.channels.privacyPolicy"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        if !privacy.isHittable { app.swipeUp() }
        XCTAssertTrue(privacy.isEnabled); privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy protection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["authEntry.privacy.consentStatus"].exists || app.otherElements["authEntry.privacy.consentStatus"].exists)
    }
}
