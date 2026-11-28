import XCTest

/// Authored only. Requires central DEBUG fixture registration and an Apple runner.
final class ProfileSelfProjectsFlowTests: XCTestCase {
    private var app:XCUIApplication!
    override func setUpWithError() throws {continueAfterFailure=false;app=XCUIApplication()}
    override func tearDownWithError() throws {attachFailureScreenshot(self,app:app);app.terminate();app=nil}
    private func launch(_ scenario:String="content",open:Bool=true) {
        app.launchArguments=["--uitesting-profile-self-projects","--profile-self-projects-scenario",scenario,"--uitesting-reset-language","-AppleLanguages","(en)","-AppleLocale","en_US"]
        app.launch();XCTAssertTrue(app.staticTexts["Synthetic projects owner"].waitForExistence(timeout:10))
        if open {let picker=app.buttons["social.profile.tabs"];if picker.exists {picker.tap()};let tab=app.buttons["Mine"];if tab.waitForExistence(timeout:3) {tab.tap()}else{app.staticTexts["Mine"].tap()}}
    }
    /// 11-28: 我的项目 refresh by pull-down (MP), so the test pulls the list instead of tapping a row.
    private func pullToRefresh() {let list=app.collectionViews.firstMatch;XCTAssertTrue(list.waitForExistence(timeout:3));list.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.2)).press(forDuration:0.1,thenDragTo:list.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.95)))}
    func testOwnPreviewFiltersEndedAndOtherBusinessType() {launch();XCTAssertTrue(app.buttons["profile.selfProjects.project.topic:7"].waitForExistence(timeout:5));XCTAssertFalse(app.buttons["profile.selfProjects.project.activity:7"].exists);XCTAssertFalse(app.buttons["profile.selfProjects.project.topic:8"].exists)}
    func testTopicDetailAndBackKeepUsablePreview() {launch();app.buttons["profile.selfProjects.project.topic:7"].tap();XCTAssertTrue(app.staticTexts["profile.selfProjectsFixture.detail"].waitForExistence(timeout:5));app.navigationBars.buttons.element(boundBy:0).tap();XCTAssertTrue(app.buttons["profile.selfProjects.project.topic:7"].waitForExistence(timeout:5))}
    func testFailureRetryReturnsGenuineRows() {launch("failure");let retry=app.buttons["profile.selfProjects.retry"];XCTAssertTrue(retry.waitForExistence(timeout:5));retry.tap();XCTAssertTrue(app.buttons["profile.selfProjects.project.topic:7"].waitForExistence(timeout:5))}
    func testRefreshFailureRetainsDisabledRowsThenRecovers() {launch("refreshFailure");XCTAssertTrue(app.buttons["profile.selfProjects.project.topic:7"].waitForExistence(timeout:5));pullToRefresh();XCTAssertTrue(app.staticTexts["profile.selfProjects.issue"].waitForExistence(timeout:5));XCTAssertFalse(app.buttons["profile.selfProjects.project.topic:7"].isEnabled);app.buttons["profile.selfProjects.retry"].tap();XCTAssertTrue(app.buttons["profile.selfProjects.project.topic:7"].isEnabled)}
    func testAllProjectsIncludesEndedAndActivityRows() {launch();app.buttons["profile.selfProjects.all"].tap();XCTAssertTrue(app.buttons["creatorContent.project.activity:7"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["creatorContent.project.topic:8"].exists)}
    /// 11-28: the MP hides the preview when there are no projects (no empty text); the 管理全部 link stays.
    func testTruncationAndEmptyHaveDifferentTruthfulStates() {launch("truncated");XCTAssertTrue(app.staticTexts["profile.selfProjects.truncated"].waitForExistence(timeout:5));app.terminate();launch("empty");XCTAssertTrue(app.buttons["profile.selfProjects.all"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["profile.selfProjects.empty"].exists);XCTAssertFalse(app.staticTexts["profile.selfProjects.issue"].exists)}
    func testGuestAndOtherMemberMakeNoPrivateReads() {for scenario in ["guest","other"] {launch(scenario,open:false);XCTAssertEqual(app.staticTexts["profile.selfProjectsFixture.reads"].label,"Projects reads: 0");XCTAssertFalse(app.buttons["profile.selfProjects.all"].exists);app.terminate()}}
}
