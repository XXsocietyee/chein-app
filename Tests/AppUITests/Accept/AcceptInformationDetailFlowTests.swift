import XCTest

/// Information detail. Design fixture `e5-info-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptInformationDetailFlowTests: XCTestCase {
    func testInformationDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e5-info-detail", markers: ["social.information.detail"], en: "Example city guide / 示例城市指南", zh: "Example city guide / 示例城市指南")
    }
}
