import XCTest
@testable import Questify

/// OWN-C OWN-D OWN-G OWN-十六-12 OWN-十六-13 OWN-十六-14 OWN-20.1 OWN-20.2
/// OWN-十八 OWN-十三-10 OWN-十三-11
final class WP08HostTipLeaseTests: XCTestCase {
    func testPlayerLeaseAdmitsTheSurfaceAndRefusesAPayChannel() throws {
        XCTAssertTrue(ReviewedProductionGateLeases.playPaths.isSuperset(of: ReviewedProductionGateLeases.wp08Paths))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: ReviewedAreaSwitch.productionAPIHost))
        XCTAssertTrue(ReviewedAreaSwitch.payout(apiHost: "www.chengyinhub.com"))
        XCTAssertFalse(ReviewedAreaSwitch.moneyPayments(apiHost: nil))
        let paths = ReviewedProductionGateLeases.wp08Paths
        let mine = try request(method: "GET", path: "api/host-tip/config/mine", body: nil)
        XCTAssertEqual(ReviewedProductionFormMutationRoute.hostTipSurfaceDecision(method: "GET", relative: "api/host-tip/config/mine", request: mine, paths: paths), true)
        let prepare = try request(method: "POST", path: "api/host-tip/prepare", body: Data(#"{"hostMemberId":4,"amount":5,"requestId":"htip-1"}"#.utf8))
        XCTAssertEqual(ReviewedProductionFormMutationRoute.hostTipSurfaceDecision(method: "POST", relative: "api/host-tip/prepare", request: prepare, paths: paths), true)
        let paid = try request(method: "POST", path: "api/host-tip/prepare", body: Data(#"{"amount":5,"payChannel":"wechat"}"#.utf8))
        XCTAssertEqual(ReviewedProductionFormMutationRoute.hostTipSurfaceDecision(method: "POST", relative: "api/host-tip/prepare", request: paid, paths: paths), false)
        let landing = try request(method: "POST", path: "api/content-landing/translation/save", body: Data(#"{"topicId":1,"status":"APPROVED"}"#.utf8))
        XCTAssertEqual(ReviewedProductionFormMutationRoute.hostTipSurfaceDecision(method: "POST", relative: "api/content-landing/translation/save", request: landing, paths: paths), false)
        XCTAssertNil(ReviewedProductionFormMutationRoute.hostTipSurfaceDecision(method: "POST", relative: "api/registration/pay", request: paid, paths: paths))
    }

    private func request(method: String, path: String, body: Data?) throws -> URLRequest {
        let url = try XCTUnwrap(URL(string: "https://www.chengyinhub.com/prod-api/" + path))
        var request = URLRequest(url: url)
        request.httpMethod = method
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }
}
