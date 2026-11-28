import XCTest
@testable import Questify

/// fix/1128b-maps: the map gaps #23 / #24 / #25 of the 1128 plan are switched on in the shipped (Release) composition,
/// which `RegionalLaunchConfiguration.shippedComposition` builds through `reviewedDeployment`.
@MainActor final class Fix1128bMapsCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    private func shipped() -> AppCompositionRoot {
        RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { URLSessionTransport() })
    }

    private func context(_ composition: AppCompositionRoot, role: String = "player") throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: role, session: session)
    }

    func testReleaseDeploymentHasProductionGatesOn() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        XCTAssertTrue(deployment.productionGatesEnabled)
        XCTAssertTrue(deployment.playerWritesEnabled)
    }

    /// Gap #24 (R-02d): the live roam reveal is on, so the live map draws the walk's fog.
    func testLiveRoamFogIsOn() {
        XCTAssertTrue(PersonalFogFeature.liveRevealEnabled)
    }

    /// Gap #25 (R-04c): the nearby topic/activity reader has a production lease for player, club and merchant.
    func testReleaseIssuesTheNearbyEventsLease() throws {
        let composition = shipped()
        for role in ["player", "club", "merchant"] {
            let ctx = try context(composition, role: role)
            let access = try XCTUnwrap(composition.roamNearbyEventsReadAccess(ctx), role)
            XCTAssertEqual(access.endpoints.paths, [RoamNearbyEventsReadRoute.path], role)
            XCTAssertTrue(access.matches(ctx), role)
            // Stable per context: the reader's identity does not churn between reads.
            XCTAssertTrue(composition.roamNearbyEventsReadAccess(ctx) === access, role)
        }
        XCTAssertNil(composition.roamNearbyEventsReadAccess(try context(composition, role: "guest")))
    }
}
