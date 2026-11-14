import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class MerchantOpsWp03ClientTests: XCTestCase {
    private let base = URL(string: "https://8120.example.test/prod-api/")!

    func testCommerceOrderStaysUnsentWhenMoneyIsClosed() async {
        let script = MerchantOpsWp03Script()
        let client = MerchantOpsWp03Client(baseURL: base, transport: script)
        let order = MerchantOpsWp03Call.commerceOrder(bizType: "premium_template", requestID: "wp03-decor-order")
        let withheld = await client.perform(order, token: "token", allowsMoney: false, allowsMerchantWrite: true)
        XCTAssertEqual(withheld, .withheld)
        XCTAssertFalse(withheld.sent)
        XCTAssertEqual(withheld.detail, "\u{2014}")
        XCTAssertNotEqual(withheld.detail, "0")
        XCTAssertTrue(script.sent.isEmpty)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/merchant/commerce/order"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/merchant/commerce/order/status"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/commerce/order"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/commerce/order/status"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/claims/submit"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/share-code"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/chapter-application/invite/revoke"))
    }

    func testReadsAreAdmittedAndUnknownStaysAnEmDash() async {
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/claims/status"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/npc/review"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/coupon-summary"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/operators/invite/preview"))
        let script = MerchantOpsWp03Script()
        script.result = .success((Data(#"{"code":200,"data":{"couponCount":0,"couponTotal":0,"received":0,"verified":0}}"#.utf8), 200))
        let client = MerchantOpsWp03Client(baseURL: base, transport: script)
        let summary = await client.perform(.couponSummary(), token: "token", allowsMoney: false, allowsMerchantWrite: false)
        XCTAssertTrue(summary.succeeded)
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.message, "\u{2014}")
        XCTAssertNotEqual(summary.message, "0")
        let request = try? MerchantOpsWp03Client.request(baseURL: base, call: .npcReview(), token: "token")
        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertNil(request?.httpBody)
        XCTAssertEqual(request?.url?.path, "/prod-api/api/merchant/npc/review")
    }

    func testMerchantWriteIsWithheldUntilTheSwitchOpens() async throws {
        let script = MerchantOpsWp03Script()
        let client = MerchantOpsWp03Client(baseURL: base, transport: script)
        let submit = MerchantOpsWp03Call.claimsSubmit(merchantID: 9002, requestID: "wp03-claim", contactName: "Store", contactPhone: "13800000000", statement: "claim", proofType: "store", assetID: "wp03")
        let withheld = await client.perform(submit, token: "token", allowsMoney: true, allowsMerchantWrite: false)
        XCTAssertEqual(withheld, .withheld)
        XCTAssertTrue(script.sent.isEmpty)
        script.result = .success((Data(#"{"code":200,"msg":"ok","data":[]}"#.utf8), 200))
        let sent = await client.perform(.claimsStatus(), token: "token", allowsMoney: false, allowsMerchantWrite: false)
        XCTAssertTrue(sent.succeeded)
        XCTAssertTrue(sent.isEmpty)
        let share = try MerchantOpsWp03Client.request(baseURL: base, call: .shareCode(memberID: 9002), token: "token")
        XCTAssertEqual(share.httpMethod, "POST")
        XCTAssertEqual(share.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(String(data: share.httpBody ?? Data(), encoding: .utf8), "memberId=9002")
    }

    func testCatalogNamesEveryRoute() {
        XCTAssertEqual(MerchantOpsWp03Catalog.paths.count, 9)
        XCTAssertTrue(MerchantOpsWp03Catalog.money.contains(MerchantOpsWp03Catalog.commerceOrder))
        XCTAssertFalse(MerchantOpsWp03Catalog.reads.contains(MerchantOpsWp03Catalog.commerceOrder))
    }
}

private final class MerchantOpsWp03Script: HTTPTransport, @unchecked Sendable {
    var sent: [URLRequest] = []
    var result: Result<(Data, Int), Error> = .success((Data("{}".utf8), 200))
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        sent.append(request)
        return try result.get()
    }
}
