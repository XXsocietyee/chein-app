import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class ChinaReviewedRouteCapabilityTests: XCTestCase {
    func testEveryCallSiteHasOneMark() {
        XCTAssertEqual(ChinaReviewedRouteCapability.callSiteCount, 993)
        XCTAssertEqual(ChinaReviewedRouteCapability.liveInProductionCount, 608)
        XCTAssertEqual(ChinaReviewedRouteCapability.newBackendOnlyCount, 0)
        XCTAssertEqual(ChinaReviewedRouteCapability.missingCount, 385)
        XCTAssertEqual(
            ChinaReviewedRouteCapability.liveInProductionCount
                + ChinaReviewedRouteCapability.newBackendOnlyCount
                + ChinaReviewedRouteCapability.missingCount,
            ChinaReviewedRouteCapability.callSiteCount
        )
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 658)
        XCTAssertEqual(
            ChinaReviewedRouteCapability.productionBackendCommit,
            "014fc0d83afe9f53cf4a8b1f9544bcf634e9ce6c"
        )
        XCTAssertEqual(
            ChinaReviewedRouteCapability.publicSnapshotCommit,
            "147754ba8740abf208bda75cf86ed5901cac4c02"
        )
    }

    func testPasswordBankAndVirtualGoodsStayHiddenByCapability() {
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/login"), .liveInProduction)
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/login"))
        XCTAssertEqual(ChinaReviewedRouteCapability.hidingCapability(for: "api/login"), .usernamePassword)
        XCTAssertTrue(ChinaReviewedRouteCapability.isHiddenFromChinaReviewed("/api/login"))

        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/withdrawal/create"), .liveInProduction)
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/withdrawal/create"))
        XCTAssertEqual(ChinaReviewedRouteCapability.hidingCapability(for: "/api/fund/preflight/bank-withdrawal"), .merchantPayout)
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/fund/preflight/{}/confirm"))

        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/withdrawal/list"), .liveInProduction)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/withdrawal/list"))
        XCTAssertNil(ChinaReviewedRouteCapability.hidingCapability(for: "/api/withdrawal/list"))

        for path in ["/api/cart/list", "/api/product/info", "/api/product/list", "/api/registration/pay", "/api/registration/pay/app"] {
            XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: path), .liveInProduction, path)
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
            XCTAssertEqual(ChinaReviewedRouteCapability.hidingCapability(for: path), .digitalContentPayment, path)
        }
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/pay/create"), .missing)
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/pay/create"))
    }

    func testHiddenRoutesAreNotOfferedOnChinaOrWithoutAHost() throws {
        let china = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let fixture = try XCTUnwrap(URL(string: "https://example.test/native"))
        let hidden = [
            "/api/map/public-layers", "/api/play/help", "/api/login",
            "/api/withdrawal/create", "/api/fund/preflight/bank-withdrawal",
            "/api/cart/list", "/api/product/info", "/api/registration/pay", "/api/registration/pay/app",
            "/api/pay/create", "/api/approved-topic-release/v1/prepare"
        ]
        for path in hidden {
            XCTAssertFalse(ChinaReviewedRouteCapability.offersFeature(path, baseURL: nil), path)
            XCTAssertFalse(ChinaReviewedRouteCapability.offersFeature(path, baseURL: china), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.offersFeature(path, baseURL: fixture), path)
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.offersFeature("/api/activity/list", baseURL: china))
        XCTAssertTrue(ChinaReviewedRouteCapability.offersFeature("/api/withdrawal/list", baseURL: china))
        XCTAssertTrue(ChinaReviewedRouteCapability.offersFeature("/api/login/phone", baseURL: china))
        XCTAssertNil(ReviewedMarketLaunch.approvedBaseURLs[.unitedStates])

        let paid = try RegionalConfiguration(
            market: .china,
            baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            approvedBaseURLs: ReviewedMarketLaunch.approvedBaseURLs,
            verifiedCapabilities: [.domesticChinaPhone, .digitalContentPayment, .merchantPayout, .usernamePassword]
        )
        XCTAssertFalse(paid.showsRoute("/api/map/public-layers"))
        XCTAssertFalse(paid.showsRoute("/api/login"))
        XCTAssertFalse(paid.showsRoute("/api/withdrawal/create"))
        XCTAssertFalse(paid.showsRoute("/api/cart/list"))
        XCTAssertFalse(paid.showsRoute("/api/registration/pay"))
        XCTAssertFalse(paid.showsRoute("/api/play/help"))
        XCTAssertTrue(paid.showsRoute("/api/activity/list"))
        XCTAssertTrue(paid.showsRoute("/api/withdrawal/list"))
        XCTAssertTrue(paid.showsRoute("/api/login/phone"))
        let offline = try RegionalConfiguration(market: .china)
        XCTAssertFalse(offline.showsRoute("/api/activity/list"))
        let other = try RegionalConfiguration(
            market: .china,
            baseURL: "https://example.test/native",
            approvedBaseURLs: [.china: ["https://example.test/native"]]
        )
        XCTAssertTrue(other.showsRoute("/api/map/public-layers"))
        XCTAssertFalse(other.showsRoute("/api/cart/list"))
        XCTAssertFalse(other.showsRoute("/api/withdrawal/create"))
        XCTAssertFalse(other.showsRoute("/api/login"))
    }

    func testMissingAndNewBackendRoutesStayDark() {
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/play/help"), .missing)
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/help"))
        XCTAssertNil(ChinaReviewedRouteCapability.hidingCapability(for: "/api/play/help"))
        XCTAssertTrue(ChinaReviewedRouteCapability.isHiddenFromChinaReviewed("/api/play/help"))
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: "/api/author-write/receipt"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/author-write/receipt"))
    }

    func testLiveRoutesAndPrefixChildrenAreAdmitted() {
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/play/nodes"), .liveInProduction)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/nodes"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/play/os/15"))
        XCTAssertEqual(ChinaReviewedRouteCapability.normalized("/api/play/os/15"), "/api/play/os/{}")
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/coupon/command-receipt"))
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/coupon/command-receipt"), .missing)
    }

    func testOnlyTheChinaProductionHostIsGated() async throws {
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let live = base.appendingPathComponent("api/withdrawal/list")
        let hidden = base.appendingPathComponent("api/login")
        XCTAssertTrue(ChinaReviewedRouteCapability.targetsChinaProduction(live))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(live))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(hidden))
        let other = try XCTUnwrap(URL(string: "https://example.com/prod-api/api/login"))
        XCTAssertFalse(ChinaReviewedRouteCapability.targetsChinaProduction(other))
        XCTAssertNil(ReviewedMarketLaunch.approvedBaseURLs[.unitedStates])

        let wire = ChinaRouteRecorder()
        let transport = ChinaReviewedProductionTransport(underlying: wire)
        do {
            _ = try await transport.send(URLRequest(url: hidden))
            XCTFail("password login must not leave the device")
        } catch APIError.notConfigured {
        }
        XCTAssertEqual(wire.calls, 0)
        let allowed = try await transport.send(URLRequest(url: live))
        XCTAssertEqual(allowed.1, 204)
        XCTAssertEqual(wire.calls, 1)
        _ = try await transport.send(URLRequest(url: other))
        XCTAssertEqual(wire.calls, 2)

        try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(URLRequest(url: other))
        XCTAssertThrowsError(try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(URLRequest(url: hidden))) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
    }
}

private final class ChinaRouteRecorder: HTTPTransport {
    var calls = 0
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        calls += 1
        return (Data(), 204)
    }
}
