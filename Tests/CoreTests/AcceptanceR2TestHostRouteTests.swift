import XCTest
@testable import QuestifyCore

/// Acceptance R2 F-14: the TEST-only topic publish routes reach the production route table only while a DEBUG/TEST
/// e2e run says the requests are rewritten to TEST. Off by default; Release compiles a constant false.
final class AcceptanceR2TestHostRouteTests: XCTestCase {
    override func tearDown() {
        TestHostOnlyRouteAdmission.testHostActive = false
        super.tearDown()
    }

    func testTopicEditRequestRoutesAreClosedUntilTheTestHostIsActive() {
        TestHostOnlyRouteAdmission.testHostActive = false
        for path in ["/api/topic/edit-requests/submit", "/api/topic/publish-status"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        TestHostOnlyRouteAdmission.testHostActive = true
        for path in TestHostOnlyRouteAdmission.rawPaths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
    }

    func testOnlyTheFourTopicPublishRoutesAreListedAndNoneMovesMoney() {
        TestHostOnlyRouteAdmission.testHostActive = true
        XCTAssertEqual(TestHostOnlyRouteAdmission.paths.count, 4)
        XCTAssertFalse(TestHostOnlyRouteAdmission.admits(ChinaReviewedRouteCapability.normalized("/api/pay/create")))
        XCTAssertFalse(TestHostOnlyRouteAdmission.admits(ChinaReviewedRouteCapability.normalized("/api/wallet/withdraw")))
        for path in TestHostOnlyRouteAdmission.rawPaths {
            XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: ChinaReviewedRouteCapability.normalized(path)), path)
            XCTAssertNil(ChinaReviewedRouteCapability.forcedOff(path), path)
        }
    }
}
