import XCTest

final class ProfileDraftReviewRestoreFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }
    private func launch() {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--uitesting-profile-edit-fixture", "caseRemoval"]
        app.launch(); XCTAssertTrue(app.staticTexts["profile.edit.fixture.notice"].waitForExistence(timeout: 10))
    }
    private func changeName(_ suffix: String = " Local") {
        let entry = app.buttons["profile.fieldEdit.open.name"]; if !entry.isHittable { app.swipeDown() }; entry.tap()
        let field = app.textFields["profile.edit.name"]; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(suffix)
        app.buttons["profile.fieldEdit.apply"].tap()
    }
    // A3-06 (r9): MP gerenziliao.wxml:94 saveInfo saves on tap. The review sheet (compare / discard) is gone;
    // leaving with unsaved edits still asks through the guarded back (ProfileSelfEditReturnFlowTests).
    func testSaveWritesOnTapWithoutReviewSheet() {
        launch(); changeName(" Saved")
        let button = app.buttons["profile.edit.review"]; if !button.isHittable { app.swipeUp() }; button.tap()
        XCTAssertFalse(app.buttons["profile.reviewRestore.open"].waitForExistence(timeout: 2))
        let status = app.staticTexts["profile.edit.status"]; XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "Your profile was saved and verified.")
    }
}
