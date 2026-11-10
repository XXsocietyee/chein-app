import XCTest

final class EntryFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure=false
        app=XCUIApplication()
        app.launchArguments=["--uitesting-reset-language","-AppleLanguages","(en)","-AppleLocale","en_US"]
        app.launch()
        skipOnboardingIfPresent(in: app)
    }
    override func tearDownWithError() throws { attachFailureScreenshot(self,app:app); app.terminate();app=nil }

    func testPlayerAndMerchantEntryCanBeClosedAndRepeated() {
        // Launch is player-first (WelcomeView.showsMerchantChoice == false): the merchant role button is hidden.
        XCTAssertFalse(app.buttons["welcome.merchant"].exists)
        for _ in 0..<3 {
            let entry=app.buttons["welcome.player"]
            XCTAssertTrue(entry.waitForExistence(timeout:10))
            entry.tap()
            // The sign-in sheet has no navigation title; identify it by its controls.
            XCTAssertTrue(app.buttons["auth.otherChannels"].waitForExistence(timeout:5))
            XCTAssertFalse(app.buttons["auth.signIn"].exists)
            XCTAssertFalse(app.secureTextFields.firstMatch.exists)
            closeTopSheet()
            XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:5))
        }
    }

    func testGuestBrowsingCanReturnToIdentityEntry() {
        let browse=app.buttons["welcome.browse"]
        XCTAssertTrue(browse.waitForExistence(timeout:10))
        if !browse.isHittable { app.swipeUp() }
        browse.tap()
        // Mini-program consumer tab bar: 首页 · 漫游 · 发布 · 俱乐部 · 我的; activities live inside Home.
        let publish=app.tabBars.buttons["Publish"]
        XCTAssertTrue(publish.waitForExistence(timeout:10))
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Home","Roam","Publish","Clubs","Me"])
        XCTAssertFalse(app.tabBars.buttons["Activities"].exists)
        publish.tap()
        XCTAssertTrue(app.navigationBars["Templates"].waitForExistence(timeout:5))
        let account=app.tabBars.buttons["Me"]
        XCTAssertTrue(account.exists);account.tap()
        XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["welcome.merchant"].exists)
        app.buttons["welcome.player"].tap()
        XCTAssertTrue(app.buttons["auth.otherChannels"].waitForExistence(timeout:5))
        closeTopSheet()
        XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:5))
    }

    func testUnconfiguredPhoneAndAppleCannotDispatch() {
        app.buttons["welcome.player"].tap()
        let other=app.buttons["auth.otherChannels"]
        XCTAssertTrue(other.waitForExistence(timeout:5))
        if !other.isHittable { app.swipeUp() }
        other.tap()
        let phone=app.textFields["auth.channels.phone"]
        XCTAssertTrue(phone.waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["auth.channels.sendCode"].isEnabled)
        XCTAssertTrue(app.buttons["auth.channels.phoneSignIn"].exists)
        XCTAssertFalse(app.buttons["auth.channels.phoneSignIn"].isEnabled)
        XCTAssertFalse(app.buttons["auth.channels.appleSignIn"].exists)
        closeTopSheet()
        XCTAssertTrue(app.buttons["auth.otherChannels"].waitForExistence(timeout:5))
    }

    func testUnconfiguredBuildHidesUnsupportedPasswordAndKeepsPhoneDisabledAfterInput() {
        app.buttons["welcome.player"].tap()
        XCTAssertTrue(app.buttons["auth.otherChannels"].waitForExistence(timeout:5))
        XCTAssertFalse(app.textFields["Username"].exists)
        XCTAssertFalse(app.secureTextFields.firstMatch.exists)
        XCTAssertFalse(app.buttons["auth.signIn"].exists)
        let phoneEntry=app.buttons["auth.otherChannels"]
        if !phoneEntry.isHittable { app.swipeUp() }
        phoneEntry.tap()
        let phone=app.textFields["auth.channels.phone"]
        XCTAssertTrue(phone.waitForExistence(timeout:5));phone.tap();phone.typeText("10000000000")
        let code=app.textFields["auth.channels.code"]
        code.tap();code.typeText("123456")
        XCTAssertFalse(app.buttons["auth.channels.sendCode"].isEnabled)
        XCTAssertFalse(app.buttons["auth.channels.phoneSignIn"].isEnabled)
        closeTopSheet()
        XCTAssertTrue(phoneEntry.waitForExistence(timeout:5))
        phoneEntry.tap()
        XCTAssertTrue(phone.waitForExistence(timeout:5))
        XCTAssertTrue((phone.value as? String) == "" || (phone.value as? String) == phone.placeholderValue)
        XCTAssertTrue((code.value as? String) == "" || (code.value as? String) == code.placeholderValue)
        XCTAssertFalse(app.buttons["auth.channels.phoneSignIn"].isEnabled)
        closeTopSheet()
        closeTopSheet()
        XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:5))
    }

    func testChinesePreferenceSurvivesRelaunchAndSwitchesBack() {
        openSettings(title:"Settings")
        let chinese=app.buttons["简体中文"]
        XCTAssertTrue(chinese.waitForExistence(timeout:5),app.debugDescription);chinese.tap()
        let done=app.buttons["完成"]
        XCTAssertTrue(done.waitForExistence(timeout:5));done.tap()
        XCTAssertTrue(app.buttons["welcome.player"].label.contains("创建账号"))
        app.terminate()
        app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US"]
        app.launch()
        skipOnboardingIfPresent(in: app)
        XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:10))
        XCTAssertTrue(app.buttons["welcome.player"].label.contains("创建账号"))
        openSettings(title:"设置")
        let english=app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout:5),app.debugDescription);english.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout:5));app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["welcome.player"].label.contains("Create account"))
    }

    /// The sign-in sheet and its "More ways to sign in" sheet both carry a Close button and neither has a
    /// navigation title; the sheet on top is the only one whose Close button is hittable.
    private func closeTopSheet(file:StaticString=#filePath,line:UInt=#line) {
        let predicate=NSPredicate(format:"label == 'Close' AND hittable == true")
        let close=app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout:5),app.debugDescription,file:file,line:line)
        close.tap()
    }

    private func openSettings(title:String,file:StaticString=#filePath,line:UInt=#line) {
        let button=app.buttons["welcome.settings"]
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true AND hittable == true"),object:button)
        let outcome = XCTWaiter.wait(for: [ready], timeout: 10)
        if outcome != .completed && name.contains("testSettingsReopensAfterRepeatedColdLaunch") {
            // Observe the original failure without activating, relaunching, or extending its wait.
            let windowCount = app.windows.count
            let windowFrames = (0..<min(windowCount, 4)).map {
                String(describing: app.windows.element(boundBy: $0).frame)
            }
            let buttonExists = button.exists
            let report = "ENTRY_COLD_LAUNCH_FIRST_FAILURE outcome=\(outcome.rawValue) state=\(app.state.rawValue)"
                + " appFrame=\(String(describing: app.frame)) windows=\(windowCount) frames=\(windowFrames)"
                + " settingsExists=\(buttonExists) settingsHittable=\(buttonExists && button.isHittable)"
                + " settingsFrame=\(buttonExists ? String(describing: button.frame) : "missing")\nAX:\n"
                + app.debugDescription
            print(report)
            let state = XCTAttachment(string: report)
            state.name = "Cold-launch first failure state"
            state.lifetime = .keepAlways
            add(state)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Cold-launch first failure screenshot"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        XCTAssertEqual(outcome,.completed,app.debugDescription,file:file,line:line)
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout:10),app.debugDescription,file:file,line:line)
    }

    func testSettingsReopensAfterRepeatedColdLaunch() {
        for _ in 0..<3 {
            app.terminate();app.launch()
            skipOnboardingIfPresent(in: app)
            openSettings(title:"Settings")
            app.buttons["Done"].tap()
            XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:5))
        }
    }

    func testSimulatorScannerFallbackCanBeCancelled() {
        app.terminate()
        app.launchArguments.append("--uitesting-scanner")
        app.launch()
        XCTAssertTrue(app.staticTexts["Scanning Isn't Supported"].waitForExistence(timeout:10),app.debugDescription)
        app.buttons["Cancel"].tap()
        skipOnboardingIfPresent(in: app)
        XCTAssertTrue(app.buttons["welcome.player"].waitForExistence(timeout:5))
    }

}
