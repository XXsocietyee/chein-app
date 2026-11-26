import Foundation
import XCTest
@testable import Questify

@MainActor final class WP07CommerceLeaseTests: XCTestCase {
    private let base = URL(string: "https://composition.example.test")!

    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: base, role: "player",
              session: try .init(accountID: 7, epoch: 1, namespace: "tests", token: "synthetic-token", role: "player"))
    }

    private func request(_ path: String, body: [String: Any]? = nil, emptyBody: Bool = false) -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("synthetic-token", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if emptyBody {
            request.httpBody = Data()
        }
        return request
    }

    func testBothGrantsListTheFourRoutesAndWritesStayClosed() throws {
        let paths = ChinaReviewedRouteCapability.wp07CommerceOwnerGrant
        XCTAssertEqual(paths, Set([
            "/api/marketing/group-checkout/quote",
            "/api/marketing/group-checkout/create",
            "/api/marketing/product/activate",
            "/api/coupon/usability"
        ]))
        XCTAssertTrue(ReviewedProductionGateLeases.wp07CommercePaths.isSubset(of: ReviewedProductionGateLeases.playPaths))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/marketing/group-checkout/quote"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/coupon/usability"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/marketing/group-checkout/create"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/marketing/product/activate"))
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/marketing/group-checkout/create"), .payment)
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/marketing/product/activate"), .payment)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/marketing/group-checkout/quote"))
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 679)
        XCTAssertEqual(ChinaReviewedRouteCapability.missingCount, 12)
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(MPCommerceGate.purchasesEnabled)
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(host: "www.chengyinhub.com"))
        XCTAssertFalse(ReviewedAreaSwitch.moneyPayments(host: nil))
    }

    func testLeaseAdmitsQuoteAndUsabilityAndRefusesPricedOrWriteBodies() throws {
        let gates = ReviewedProductionGateLeases()
        gates.notePlayerWrites(true)
        let context = try context()
        let grant = try XCTUnwrap(gates.playerWriters(context))
        func accepts(_ request: URLRequest) -> Bool {
            ReviewedProductionFormMutationRoute.acceptsPlayerWrite(request, baseURL: base, token: "synthetic-token", context: context, grant: grant)
        }
        XCTAssertTrue(accepts(request("api/marketing/group-checkout/quote", body: ["productId": 15, "quantity": 2])))
        XCTAssertTrue(accepts(request("api/coupon/usability", emptyBody: true)))
        XCTAssertTrue(accepts(request("api/coupon/usability")))
        XCTAssertFalse(accepts(request("api/marketing/group-checkout/quote", body: ["productId": 15, "price": 12])))
        XCTAssertFalse(accepts(request("api/marketing/group-checkout/quote", body: ["productId": 15, "card": "4242"])))
        XCTAssertFalse(accepts(request("api/marketing/group-checkout/create", body: ["productId": 15])))
        XCTAssertFalse(accepts(request("api/marketing/product/activate", body: ["topicId": 3])))
    }
}
