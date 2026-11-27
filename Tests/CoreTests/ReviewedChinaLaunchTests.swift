import XCTest
@testable import QuestifyCore

/// WIRE-1. A matching China build selects the reviewed deployment. Every other build stays fail-closed.
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

    func testShippedChinaAdmissionAcceptsOnlyTheReviewedHost() {
        XCTAssertTrue(ReviewedMarketLaunch.admitsShippedChina(
            market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        XCTAssertTrue(ReviewedMarketLaunch.admitsShippedChina(
            market: .china, baseURL: "  \(ReviewedMarketLaunch.chinaProductionBaseURL)  ", bundleIdentifier: bundle, realm: realm))
        XCTAssertFalse(ReviewedMarketLaunch.admitsShippedChina(
            market: .unitedStates, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        XCTAssertNil(ReviewedMarketLaunch.approvedBaseURLs[.unitedStates])
        for host in ["", "https://www.chengyinhub.com/other/", "http://47.103.124.64/prod-api/", "https://api.example.com/"] {
            XCTAssertFalse(ReviewedMarketLaunch.admitsShippedChina(
                market: .china, baseURL: host, bundleIdentifier: bundle, realm: realm), host)
        }
        XCTAssertFalse(ReviewedMarketLaunch.admitsShippedChina(
            market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: "", realm: realm))
        XCTAssertFalse(ReviewedMarketLaunch.admitsShippedChina(
            market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: ""))
        XCTAssertFalse(ReviewedMarketLaunch.admitsShippedChina(
            market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: "$(QUESTIFY_SESSION_REALM)"))
    }

    func testShippedUnitedStatesAdmissionSharesOnlyTheReviewedHost() {
        XCTAssertTrue(ReviewedMarketLaunch.admitsShippedUnitedStates(
            market: .unitedStates, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        XCTAssertFalse(ReviewedMarketLaunch.admitsShippedUnitedStates(
            market: .china, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm))
        for host in ["", "https://www.chengyinhub.com/other/", "https://api.example.com/"] {
            XCTAssertFalse(ReviewedMarketLaunch.admitsShippedUnitedStates(
                market: .unitedStates, baseURL: host, bundleIdentifier: bundle, realm: realm), host)
        }
        XCTAssertFalse(ReviewedMarketLaunch.admitsShippedUnitedStates(
            market: .unitedStates, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: ""))
        XCTAssertFalse(ReviewedMarketLaunch.admitsShippedUnitedStates(
            market: .unitedStates, baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: "", realm: realm))
    }

    func testShippedCompositionAndBuildInputsStayFailClosed() throws {
        let launch = try source("App/RegionalLaunchConfiguration.swift")
        XCTAssertTrue(launch.contains("makeComposition(reviewed: nil, build: .current)"))
        XCTAssertFalse(launch.contains("https://"))
        guard let start = launch.range(of: "static var composition"),
              let end = launch.range(of: "static func reviewedDeployment") else {
            return XCTFail("composition property not found")
        }
        let property = String(launch[start.lowerBound..<end.lowerBound])
        XCTAssertTrue(property.contains("shippedComposition(build: .current)"))
        XCTAssertTrue(property.contains("ReviewedMarketLaunch.admitsShippedChina"))
        XCTAssertTrue(property.contains("reviewedComposition("))
        XCTAssertTrue(property.contains("ReviewedMarketLaunch.chinaProductionBaseURL"))
        XCTAssertTrue(property.contains("makeComposition(reviewed: nil, build: .current)"))
        XCTAssertTrue(property.contains(".manualMap"))
        XCTAssertTrue(property.contains(".officialPublicEventCatalogAndDetail"))
        XCTAssertTrue(property.contains(".playNodesAndRouteState"))
        XCTAssertFalse(property.contains("reviewedMarketComposition"))
        XCTAssertFalse(property.contains("reviewedMarketDeployment"))
        XCTAssertFalse(property.contains("productionGatesEnabled: true"))
        XCTAssertFalse(property.contains("unitedStates"))
        XCTAssertFalse(property.contains("usernamePassword"))
        XCTAssertFalse(property.contains("bankCreate"))
        XCTAssertFalse(property.contains(".mall"))
        XCTAssertFalse(property.contains("https://"))
        XCTAssertTrue(launch.contains("let approved:[RegionalMarket:Set<String>]=[:]"))
        XCTAssertTrue(launch.contains("productionGatesEnabled: false"))

        let china = try source("Config/China.Production.xcconfig")
        XCTAssertTrue(china.contains("QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/"))
        XCTAssertTrue(china.contains("QUESTIFY_SESSION_REALM = cn-prod"))
        // US launch r1: the US storefront ships on the same reviewed backend and realm (no backend market split).
        let unitedStates = try source("Config/UnitedStates.Production.xcconfig")
        XCTAssertTrue(unitedStates.contains("QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/"))
        XCTAssertTrue(unitedStates.contains("QUESTIFY_SESSION_REALM = cn-prod"))
        XCTAssertTrue(unitedStates.contains("QUESTIFY_MARKET = US"))
        XCTAssertTrue(property.contains("ReviewedMarketLaunch.admitsShippedUnitedStates"))
        for staging in ["Config/UnitedStates.Staging.xcconfig", "Config/UnitedStates.xcconfig"] {
            XCTAssertFalse(try source(staging).contains("chengyinhub.com"), staging)
        }
        let base = try source("Config/Base.xcconfig")
        XCTAssertTrue(base.contains("QUESTIFY_API_BASE_URL =\n"))
        XCTAssertFalse(base.contains("chengyinhub.com"))
        let debug = try source("Config/China.Development.xcconfig")
        XCTAssertFalse(debug.contains("chengyinhub.com"))
    }
}
