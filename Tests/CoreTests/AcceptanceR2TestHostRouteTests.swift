import XCTest
@testable import QuestifyCore

/// Acceptance R2 F-14: the TEST-only topic publish routes reach the production route table only while a DEBUG/TEST
/// e2e run says the requests are rewritten to TEST. Off by default; Release compiles a constant false.
final class AcceptanceR2TestHostRouteTests: XCTestCase {
    override func tearDown() {
        TestHostOnlyRouteAdmission.testHostActive = false
        super.tearDown()
    }

    /// P2-6 (11-28): r3 production serves these routes, so they are admitted with or without the TEST host.
    func testTopicEditRequestRoutesAreAdmittedOnProduction() {
        TestHostOnlyRouteAdmission.testHostActive = false
        for path in TestHostOnlyRouteAdmission.rawPaths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
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
