import XCTest
@testable import Questify

/// WIRE-1 composition selection. The default build stays unconfigured. A matching China build selects the reviewed deployment.
@MainActor final class ReviewedChinaLaunchCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    func testChinaReviewedCompositionAcceptsTheProductionURL() throws {
        let composition = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        guard case .reviewed(let deployment) = composition.deployment else {
            return XCTFail("China reviewed composition must accept \(ReviewedMarketLaunch.chinaProductionBaseURL)")
        }
        XCTAssertEqual(deployment.regional.market, .china)
        XCTAssertEqual(deployment.regional.apiConfiguration?.baseURL.absoluteString, "https://www.chengyinhub.com/prod-api/")
        XCTAssertTrue(deployment.regional.canUseDomesticChinaPhone)
        XCTAssertEqual(deployment.regional.availableCapabilities, [.domesticChinaPhone])
        XCTAssertFalse(deployment.productionGatesEnabled)
        XCTAssertFalse(deployment.playerWritesEnabled)
        XCTAssertTrue(deployment.reads.isEmpty)
    }

    func testUnitedStatesReviewedCompositionStaysDisabled() {
        XCTAssertNil(ReviewedMarketLaunch.approvedBaseURLs[.unitedStates])
        let composition = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .unitedStates,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNil(composition.reviewed)
        guard case .incompatibleBuild = composition.deployment else {
            return XCTFail("US reviewed path must stay disabled")
        }
    }

    func testCrossMarketURLIsRejected() {
        let china = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .china,
            baseURL: "https://www.chengyinhub.com/other/",
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNil(china.reviewed)
        guard case .incompatibleBuild = china.deployment else {
            return XCTFail("a China deployment must reject a non-China URL")
        }
        let unitedStates = RegionalLaunchConfiguration.reviewedMarketComposition(
            market: .unitedStates,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNil(unitedStates.reviewed)
        XCTAssertThrowsError(try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .china,
            baseURL: "https://example.com/prod-api/",
            bundleIdentifier: bundle,
            realm: realm
        ))
        XCTAssertThrowsError(try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .unitedStates,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        ))
    }

    func testStorageScopeDiffersByMarket() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertEqual(deployment.storageScope.market, .china)
        let unitedStates = RegionalSessionStorageScope.serviceName(
            market: .unitedStates,
            endpoint: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNotEqual(deployment.storageScope.service, unitedStates)
        let offline = try RegionalConfiguration(market: .unitedStates)
        XCTAssertFalse(deployment.storageScope.matches(configuration: offline))
    }

    func testAbsentCapabilityStaysHiddenAndWritesStayOff() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedMarketDeployment(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertTrue(deployment.regional.isFeatureShown(.domesticChinaPhone))
        XCTAssertFalse(deployment.regional.isFeatureShown(.usernamePassword))
        XCTAssertFalse(deployment.regional.isFeatureShown(.digitalContentPayment))
        XCTAssertFalse(deployment.regional.isFeatureShown(.merchantPayout))
        XCTAssertFalse(deployment.regional.isFeatureShown(.physicalEventPayment))
        XCTAssertFalse(deployment.productionGatesEnabled)
        XCTAssertFalse(deployment.playerWritesEnabled)
        let unverified = try RegionalConfiguration(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs
        )
        XCTAssertFalse(unverified.isFeatureShown(.domesticChinaPhone))

        XCTAssertNil(RegionalLaunchConfiguration.composition.reviewed)
        guard case .unconfigured = RegionalLaunchConfiguration.composition.deployment else {
            return XCTFail("shipped composition must stay fail-closed")
        }
        for build in [
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: "", bundleIdentifier: bundle, realm: realm),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: " ", bundleIdentifier: bundle, realm: realm),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: ""),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: " "),
            RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: "", bundleIdentifier: bundle, realm: "")
        ] {
            let composition = RegionalLaunchConfiguration.shippedComposition(build: build)
            guard case .unconfigured = composition.deployment else {
                return XCTFail("empty URL or realm must stay unconfigured")
            }
            XCTAssertNil(composition.reviewed)
        }
        let admitted = RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        guard case .reviewed(let shipped) = admitted.deployment else {
            return XCTFail("a China host with a bundle and realm still selects the reviewed deployment")
        }
        XCTAssertTrue(shipped.playerWritesEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(RegionalLaunchConfiguration.composition.reviewed?.productionGatesEnabled == true)
        XCTAssertFalse(RegionalLaunchConfiguration.composition.reviewed?.playerWritesEnabled == true)
    }
}
