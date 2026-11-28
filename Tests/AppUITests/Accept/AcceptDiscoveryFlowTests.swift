import XCTest

/// Discovery home. Design fixture `e1-discovery`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptDiscoveryFlowTests: XCTestCase {
    func testDiscoveryFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e1-discovery", markers: ["discovery.openRoutes", "discovery.openTemplates"], en: "Routes", zh: "路线")
    }
}
