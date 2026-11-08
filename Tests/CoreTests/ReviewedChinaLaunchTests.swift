import XCTest
@testable import QuestifyCore

/// WIRE-1. The shipped composition stays fail-closed. The China deployment below is opt-in.
final class ReviewedChinaLaunchTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relative: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = repoRoot.appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("cannot read \(relative)", file: file, line: line)
            throw CocoaError(.fileReadNoSuchFile)
        }
        return text
    }

    func testChinaReviewedDeploymentAcceptsOnlyItsProductionURL() throws {
        let config = try ReviewedMarketLaunch.configuration(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL
        )
        XCTAssertEqual(config.market, .china)
        XCTAssertEqual(config.apiConfiguration?.baseURL.absoluteString, "https://www.chengyinhub.com/prod-api/")
        XCTAssertEqual(config.availableCapabilities, [.domesticChinaPhone])
        XCTAssertTrue(config.canUseDomesticChinaPhone)
        XCTAssertEqual(
            ReviewedMarketLaunch.approvedBaseURLs,
            [.china: ["https://www.chengyinhub.com/prod-api/"]]
        )
    }

    func testUnitedStatesReviewedPathStaysDisabledWithNoInventedURL() throws {
        XCTAssertNil(ReviewedMarketLaunch.approvedBaseURLs[.unitedStates])
        XCTAssertEqual(Set(ReviewedMarketLaunch.approvedBaseURLs.keys), [.china])
        let launch = try source("Core/RegionalConfiguration.swift")
        let registry = launch.components(separatedBy: "public enum ReviewedMarketLaunch").last ?? ""
        XCTAssertFalse(registry.contains("unitedStates:"))
        XCTAssertFalse(registry.contains("https://us."))
        for baseURL in ["", " ", ReviewedMarketLaunch.chinaProductionBaseURL, "https://example.com/prod-api/"] {
            XCTAssertThrowsError(try ReviewedMarketLaunch.configuration(market: .unitedStates, baseURL: baseURL)) { error in
                XCTAssertEqual(error as? RegionalConfigurationError, .unapprovedBackend)
            }
        }
    }

    func testCrossMarketURLIsRejected() throws {
        let foreign = [
            "https://www.chengyinhub.com/prod-api",
            "https://www.chengyinhub.com/other/",
            "https://us.chengyinhub.com/prod-api/",
            "http://www.chengyinhub.com/prod-api/",
            "https://47.103.124.64/prod-api/",
            "https://example.com/prod-api/"
        ]
        for url in foreign {
            XCTAssertThrowsError(try ReviewedMarketLaunch.configuration(market: .china, baseURL: url)) { error in
                XCTAssertEqual(error as? RegionalConfigurationError, .unapprovedBackend, url)
            }
        }
        XCTAssertThrowsError(
            try ReviewedMarketLaunch.configuration(market: .unitedStates, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL)
        ) { error in
            XCTAssertEqual(error as? RegionalConfigurationError, .unapprovedBackend)
        }
    }

    func testStorageScopeDiffersByMarket() throws {
        let china = try ReviewedMarketLaunch.storageScope(bundleIdentifier: bundle, realm: realm)
        XCTAssertEqual(china.market, .china)
        let unitedStates = RegionalSessionStorageScope.serviceName(
            market: .unitedStates,
            endpoint: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: bundle,
            realm: realm
        )
        XCTAssertNotEqual(china.service, unitedStates)
        XCTAssertNotEqual(china.restoreBlockedKey, unitedStates + ".preventRestore")
        XCTAssertEqual(
            china.service,
            RegionalSessionStorageScope.serviceName(
                market: .china,
                endpoint: ReviewedMarketLaunch.chinaProductionBaseURL,
                bundleIdentifier: bundle,
                realm: realm
            )
        )
        XCTAssertThrowsError(try ReviewedMarketLaunch.storageScope(market: .unitedStates, bundleIdentifier: bundle, realm: realm))
        let offlineUnitedStates = try RegionalConfiguration(market: .unitedStates)
        XCTAssertFalse(china.matches(configuration: offlineUnitedStates))
        XCTAssertNotEqual(china.market, offlineUnitedStates.market)
    }

    func testAbsentCapabilityStaysHidden() throws {
        let china = try ReviewedMarketLaunch.configuration(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL
        )
        XCTAssertTrue(china.isFeatureShown(.domesticChinaPhone))
        for capability in RegionalCapability.allCases where capability != .domesticChinaPhone {
            XCTAssertFalse(china.isFeatureShown(capability), "\(capability) stays hidden")
        }
        XCTAssertFalse(china.isFeatureShown(.usernamePassword))
        XCTAssertFalse(china.isFeatureShown(.digitalContentPayment))
        XCTAssertFalse(china.isFeatureShown(.merchantPayout))
        let unverified = try RegionalConfiguration(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs
        )
        XCTAssertFalse(unverified.canUseDomesticChinaPhone)
        XCTAssertFalse(unverified.isFeatureShown(.domesticChinaPhone))
    }

    func testShippedCompositionAndBuildInputsStayFailClosed() throws {
        let launch = try source("App/RegionalLaunchConfiguration.swift")
        XCTAssertTrue(launch.contains("makeComposition(reviewed: nil, build: .current)"))
        guard let start = launch.range(of: "static var composition"),
              let end = launch.range(of: "static func reviewedDeployment") else {
            return XCTFail("composition property not found")
        }
        let property = String(launch[start.lowerBound..<end.lowerBound])
        XCTAssertFalse(property.contains("reviewedMarketComposition"))
        XCTAssertFalse(property.contains("reviewedMarketDeployment"))
        XCTAssertFalse(property.contains("chinaProductionBaseURL"))
        XCTAssertFalse(property.contains("productionGatesEnabled: true"))
        XCTAssertTrue(launch.contains("let approved:[RegionalMarket:Set<String>]=[:]"))
        XCTAssertTrue(launch.contains("productionGatesEnabled: false"))

        let china = try source("Config/China.Production.xcconfig")
        XCTAssertTrue(china.contains("QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/"))
        let unitedStates = try source("Config/UnitedStates.Production.xcconfig")
        XCTAssertFalse(unitedStates.contains("chengyinhub.com"))
        XCTAssertTrue(unitedStates.contains("QUESTIFY_API_BASE_URL =\n"))
        let base = try source("Config/Base.xcconfig")
        XCTAssertTrue(base.contains("QUESTIFY_API_BASE_URL =\n"))
        XCTAssertFalse(base.contains("chengyinhub.com"))
        let debug = try source("Config/China.Development.xcconfig")
        XCTAssertFalse(debug.contains("chengyinhub.com"))
    }
}
