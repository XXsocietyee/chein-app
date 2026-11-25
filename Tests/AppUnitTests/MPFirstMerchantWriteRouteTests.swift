import XCTest
@testable import Questify

/// Owner 2026-11-25 MP-first rule: the composition firewall admits the merchant writes the MP sends, exactly.
@MainActor final class MPFirstMerchantWriteRouteTests: XCTestCase {
    private let base = URL(string: "https://test.example.com")!
    private let token = "synthetic-token-123456"
    private func post(_ path: String, query: String? = nil, token: String? = nil, method: String = "POST") -> URLRequest {
        var url = base.appendingPathComponent(path)
        if let query { url = URL(string: url.absoluteString + "?" + query)! }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(token ?? self.token, forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)
        return request
    }

    func testAdmitsTheMPMerchantWrites() {
        for path in ["api/merchant/operators/invite", "api/merchant/operators/role", "api/merchant/operators/remove",
                     "api/merchant/operators/invite/revoke", "api/merchant/operators/invite/accept",
                     "api/merchant/reviews/reply", "api/merchant/reviews/reply/update", "api/merchant/reviews/reply/delete",
                     "api/merchant/reviews/manage/report", "api/merchant/crm/customers/tags/batch",
                     "api/merchant/crm/customers/61001/notes", "api/merchant/crm/customers/61001/notes/hide",
                     "api/merchant/crm/customers/61001/tags", "api/merchant/crm/customers/61001/tags/remove",
                     "api/merchant/city-node/claim", "api/merchant/city-node/claim/cancel", "api/merchant/city-node/offline",
                     "api/merchant/city-node/save", "api/game/session/command", "api/game/session/receipt",
                     "api/merchant/npc/save", "api/merchant/decor/save", "api/merchant/npc/voice/enroll", "api/merchant/npc/voice/reset"] {
            XCTAssertTrue(MPFirstMerchantWriteRoute.accepts(post(path), baseURL: base, token: token), path)
        }
        XCTAssertTrue(MPFirstMerchantWriteRoute.accepts(post("api/merchant/aftercare/respond", query: "refundId=62001"), baseURL: base, token: token))
    }

    func testRefusesAnythingElse() {
        XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post("api/merchant/operators/invite", method: "GET"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post("api/merchant/operators/invite", token: "other-token-123456"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post("api/merchant/operators/invite", query: "x=1"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post("api/merchant/aftercare/respond"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post("api/merchant/aftercare/respond", query: "refundId=0"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post("api/merchant/crm/customers/0/notes"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post("api/merchant/crm/customers/61001/contact"), baseURL: base, token: token))
        // Money stays out: payment, refund execution, payout and withdrawal are not MP-first merchant writes.
        for money in ["api/pay/create", "api/refund/apply", "api/withdrawal/apply", "api/merchant/commerce/order"] {
            XCTAssertFalse(MPFirstMerchantWriteRoute.accepts(post(money), baseURL: base, token: token), money)
        }
    }
}
