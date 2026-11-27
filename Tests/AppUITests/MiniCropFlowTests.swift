import XCTest

/// Offline fixture for the mini pages/crop counterpart: synthetic drawn images, no picker, camera or upload.
final class MiniCropFlowTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset-language", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "--uitesting-module", "mini-crop"]
        app.launch(); return app
    }
    func testBatchWalksEachImageAndReportsPerImageResult() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["miniCrop.progress"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["miniCrop.progress"].label, "Crop 1/2")
        // mp-settings r3: a ready frame offers 还原, not 使用原图 (MP crop/index.wxml:56-66).
        XCTAssertFalse(app.buttons["miniCrop.useOriginal"].exists)
        app.buttons["miniCrop.reset"].tap()
        app.buttons["miniCrop.confirm"].tap()
        XCTAssertEqual(app.staticTexts["miniCrop.progress"].label, "Crop 2/2")
        app.buttons["miniCrop.confirm"].tap()
        // Untouched 1:1 crops of 400x300 and 300x400 images select the centered 300x300 squares.
        XCTAssertTrue(app.staticTexts["miniCrop.outcome"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["miniCrop.outcome"].label, "crop 300x300, crop 300x300")
    }
    func testCancelReturnsWithoutResults() {
        let app = launch()
        XCTAssertTrue(app.buttons["miniCrop.cancel"].waitForExistence(timeout: 5))
        app.buttons["miniCrop.cancel"].tap()
        XCTAssertEqual(app.staticTexts["miniCrop.outcome"].label, "cancelled")
    }
}
