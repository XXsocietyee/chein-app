import XCTest

/// Uses the existing no-network editor fixture, not a new presentation-only route.
final class ProfileDraftReviewLayoutFlowTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false; app = XCUIApplication() }
    override func tearDownWithError() throws { attachFailureScreenshot(self, app: app); app.terminate(); app = nil }
    private func reveal(_ element: XCUIElement, upwards: Bool = true) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { break }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists); XCTAssertTrue(element.isHittable)
    }
    private func saveOnTap(chinese: Bool) throws {
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", chinese ? "(zh-Hans)" : "(en)",
            "-AppleLocale", chinese ? "zh_CN" : "en_US", "--uitesting-profile-edit-fixture", "caseRemoval",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let entry = app.buttons["profile.fieldEdit.open.name"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); reveal(entry); entry.tap()
        let input = app.textFields["profile.edit.name"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let before = try XCTUnwrap(input.value as? String)
        let suffix = chinese ? " 保留长文原始内容。换行展示不得改变草稿。取消确认后仍可返回编辑。" : " Long text stays exact across wrapping and return to the local draft."
        let after = before + suffix
        XCTAssertLessThanOrEqual(after.utf16.count, 140)
        input.tap(); input.typeText(suffix)
        let apply = app.buttons["profile.fieldEdit.apply"]
        XCTAssertTrue(apply.isEnabled); apply.tap()
        // A3-06 (r9): MP gerenziliao.wxml:94 saveInfo — 保存 writes on tap; no review/compare sheet.
        let review = app.buttons["profile.edit.review"]; reveal(review); review.tap()
        XCTAssertFalse(app.buttons["profile.reviewRestore.compare"].waitForExistence(timeout: 2))
        let status = app.staticTexts["profile.edit.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        if !chinese { XCTAssertEqual(status.label, "Your profile was saved and verified.") }
    }
    func testEnglishMaximumTextSavesOnTap() throws { try saveOnTap(chinese: false) }
    func testChineseMaximumTextSavesOnTap() throws { try saveOnTap(chinese: true) }
}
