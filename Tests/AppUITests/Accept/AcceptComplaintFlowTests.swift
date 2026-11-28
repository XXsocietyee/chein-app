import XCTest

/// Complaint. Design fixture `e4-complaint`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptComplaintFlowTests: XCTestCase {
    func testComplaintFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-complaint", markers: ["profile.complaint.pageSubtitle"], en: "Complaints & feedback", zh: "投诉与建议")
    }
}
