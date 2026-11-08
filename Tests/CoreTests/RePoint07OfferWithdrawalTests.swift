import Foundation
import XCTest
@testable import QuestifyCore

/// SYNTHETIC fixtures derived from ApiCoopController.offerWithdraw (AjaxResult {code,msg,data}). NOT COMPILED.
final class RePoint07OfferWithdrawalTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var reply: (Data, Int) = (Data(), 200)
        var fail = false
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request); if fail { throw URLError(.timedOut) }; return reply
        }
    }
    private let base = URL(string: "https://example.invalid/")!
    private func client(_ w: Wire, allowed: Bool = true) -> RePoint07OfferWithdrawalClient {
        .init(baseURL: base, token: { "synthetic-token" }, transport: w, allowed: { allowed })
    }

    func testDisabledByDefaultSendsNothing() async {
        let w = Wire()
        let c = RePoint07OfferWithdrawalClient(baseURL: base, token: { "synthetic-token" }, transport: w)
        let o = await c.withdraw(offerID: 5, reason: "x")
        XCTAssertEqual(o, .disabled); XCTAssertTrue(w.requests.isEmpty)
    }

    func testRequestShapeIsProductionJSON() async throws {
        let w = Wire()
        w.reply = (Data(#"{"code":200,"msg":"已退出供给","data":{"enrollmentPaused":true}}"#.utf8), 200)
        let o = await client(w).withdraw(offerID: 5, reason: "  歇业  ")
        XCTAssertEqual(o, .withdrawn(enrollmentPaused: true, message: "已退出供给"))
        let r = try XCTUnwrap(w.requests.first)
        XCTAssertEqual(r.url?.path, "/api/coop/offer/withdraw"); XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(r.httpBody)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["offerId", "reason"]); XCTAssertEqual(body["reason"] as? String, "歇业")
    }

    func testBusinessRefusalIsRejectedNotWithdrawn() async {
        let w = Wire(); w.reply = (Data(#"{"code":500,"msg":"缺少供给记录"}"#.utf8), 200)
        let o = await client(w).withdraw(offerID: 5, reason: "x")
        XCTAssertEqual(o, .rejected(code: 500, message: "缺少供给记录"))
    }

    func testTransportFailureAndServerErrorAreUnknown() async {
        let w = Wire(); w.fail = true
        let a = await client(w).withdraw(offerID: 5, reason: "x"); XCTAssertEqual(a, .unknown)
        let w2 = Wire(); w2.reply = (Data(), 502)
        let b = await client(w2).withdraw(offerID: 5, reason: "x"); XCTAssertEqual(b, .unknown)
    }

    func testInvalidInputNeverSends() async {
        let w = Wire()
        let a = await client(w).withdraw(offerID: 0, reason: "x"); XCTAssertEqual(a, .invalid)
        let b = await client(w).withdraw(offerID: 5, reason: "   "); XCTAssertEqual(b, .invalid)
        XCTAssertTrue(w.requests.isEmpty)
    }
}
