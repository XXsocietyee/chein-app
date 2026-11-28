import XCTest

final class RegionalEntryFlowTests:XCTestCase {
    private var app:XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure=false;app=XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self,app:app); app.terminate();app=nil }
    private func launch(_ market:String,first:Bool=true) {
        app.launchArguments=["--uitesting-market",market,"-AppleLanguages","(en)","-AppleLocale","en_US"]
        if first { app.launchArguments.append("--uitesting-first-launch-language") }
        app.launch()
        skipOnboardingIfPresent(in: app)
        XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:15),app.debugDescription)
    }
    func testChinaDefaultsChineseAndLanguagePersistsWithoutChangingMarket() {
        launch("CN")
        XCTAssertTrue(app.staticTexts["出发吧"].waitForExistence(timeout:5),app.debugDescription)
        revealWelcomeSettings(in:app).tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["region.market.value"].label,"CN")
        XCTAssertTrue(selectLanguage(in:app,option:"English"),app.debugDescription)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout:5),app.debugDescription)
        XCTAssertEqual(app.staticTexts["region.market.value"].label,"CN")
        app.buttons["Done"].tap();app.terminate()
        launch("CN",first:false)
        XCTAssertTrue(app.staticTexts["Let's go"].waitForExistence(timeout:5))
    }
    /// Owner 11-28 04:30: the US gets +1 phone + Apple, each shown only once the deployment verified it (P27: a
    /// gated channel renders nothing, no "not available in your region" notice). This UI-test deployment verifies
    /// nothing, so the US sheet shows no China credential form and no phone page.
    func testUSDefaultsEnglishAndCannotUseChinaCredentialForms() {
        launch("US")
        XCTAssertTrue(app.staticTexts["Let's go"].waitForExistence(timeout:5))
        app.buttons["welcome.player"].tap()
        XCTAssertTrue(app.buttons["auth.close"].waitForExistence(timeout:5))
        XCTAssertFalse(app.secureTextFields.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["region.auth.pending"].exists)
        XCTAssertFalse(app.buttons["auth.otherChannels"].exists)
        XCTAssertFalse(app.textFields["auth.channels.phone"].exists)
        XCTAssertFalse(app.buttons["auth.channels.sendCode"].exists)
        XCTAssertFalse(app.buttons["auth.channels.appleSignIn"].exists)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="US login – gated channels render nothing";shot.lifetime = .keepAlways;add(shot)
    }
    func testUSCanChooseChineseWithoutEnablingDomesticPhone() {
        launch("US")
        revealWelcomeSettings(in:app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout:5),app.debugDescription)
        XCTAssertTrue(selectLanguage(in:app,option:"简体中文"),app.debugDescription)
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["region.market.value"].label,"US")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.staticTexts["出发吧"].waitForExistence(timeout:5))
        app.buttons["welcome.player"].tap()
        XCTAssertTrue(app.buttons["auth.close"].waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["region.auth.pending"].exists)
        XCTAssertFalse(app.secureTextFields.firstMatch.exists)
        XCTAssertFalse(app.buttons["auth.otherChannels"].exists)
        XCTAssertFalse(app.textFields["auth.channels.phone"].exists)
        XCTAssertFalse(app.buttons["auth.channels.sendCode"].exists)
    }

    func testComputedLabelsUseSelectedLanguageInsteadOfDeviceLanguage() {
        app.launchArguments=["--uitesting-reset-language","--uitesting-module","localization","-AppleLanguages","(en)","-AppleLocale","en_US"]
        app.launch()
        let label=app.staticTexts["localization.fixture.computed"]
        XCTAssertTrue(label.waitForExistence(timeout:10))
        XCTAssertEqual(label.label,"Settings")
        app.buttons["localization.fixture.chinese"].tap()
        let chinese=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","设置"),object:label)
        XCTAssertEqual(XCTWaiter.wait(for:[chinese],timeout:5),.completed,app.debugDescription)
        app.buttons["localization.fixture.english"].tap()
        let english=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Settings"),object:label)
        XCTAssertEqual(XCTWaiter.wait(for:[english],timeout:5),.completed,app.debugDescription)
    }

}
