import Foundation
import XCTest
@testable import QuestifyCore

final class WP07CommerceClientTests: XCTestCase {
    private final class Transport: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var payload = Data()
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (payload, 200)
        }
    }

    private func client(_ transport: Transport) throws -> WP07CommerceClient {
        WP07CommerceClient(
            configuration: try APIConfiguration(baseURL: URL(string: "https://composition.example.test")!),
            transport: transport, token: "synthetic-token", apiHost: "composition.example.test")
    }

    func testGroupQuoteUsesServerTierAndPayAmountNotCatalogCash() async throws {
        let transport = Transport()
        let quote: [String: Any] = [
            "productName": "Group",
            "productKind": 5,
            "catalogCashPrice": 999,
            "activityId": 41,
            "ticketId": 8,
            "quote": [
                "payAmount": 12.5,
                "quoteSign": "signed",
                "marketingAdjustments": [
                    ["kind": "tier", "label": "3-9人", "amount": 1],
                    ["kind": "promo", "label": "not a tier"]
                ]
            ]
        ]
        transport.payload = try JSONSerialization.data(withJSONObject: ["code": 200, "data": quote])
        let display = try await client(transport).quote(productID: 15, quantity: 2)
        XCTAssertEqual(display.productKind, 5)
        XCTAssertEqual(display.tierLabel, "3-9人")
        XCTAssertEqual(display.totalText, "12.5")
        XCTAssertFalse(display.totalText?.contains("999") == true)
        XCTAssertEqual(display.activityID, "41")
        let body = try XCTUnwrap(transport.requests.first?.httpBody)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(Set(sent.keys), ["productId", "quantity"])
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/marketing/group-checkout/quote")
        XCTAssertEqual(transport.requests.first?.httpMethod, "POST")
    }

    func testEmptyQuoteIsEmptyAndMissingTotalIsUnknown() throws {
        let empty = try GroupCheckoutDisplay.decode(JSONSerialization.data(withJSONObject: [String: Any]()))
        XCTAssertTrue(empty.isEmpty)
        XCTAssertNil(empty.totalText)
        let named = try GroupCheckoutDisplay.decode(JSONSerialization.data(withJSONObject: [
            "productName": "School", "productKind": 6, "catalogCashPrice": 999,
            "quote": ["quoteSign": "signed"]
        ]))
        XCTAssertEqual(named.productName, "School")
        XCTAssertNil(named.totalText)
        XCTAssertNil(named.tierLabel)
    }

    func testCouponUsabilityKeepsDeductionAtZero() async throws {
        let transport = Transport()
        transport.payload = try JSONSerialization.data(withJSONObject: ["code": 200, "data": [
            ["historyId": 7, "name": "新人券", "amount": 5, "usable": false, "reason": "USED"],
            ["historyId": 8, "name": "未知", "usable": true, "reason": "WHATEVER"]
        ]])
        let rows = try await client(transport).usability()
        XCTAssertEqual(WP07CommerceClient.couponDeductYuan, .zero)
        XCTAssertEqual(rows.map(\.id), ["7", "8"])
        XCTAssertEqual(rows[0].reason, "USED")
        XCTAssertFalse(rows[0].usable)
        XCTAssertEqual(rows[0].faceText, "5")
        XCTAssertFalse(CouponUsabilityRow.knownReasons.contains("WHATEVER"))
        XCTAssertNil(transport.requests.first?.httpBody)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/coupon/usability")
    }

    func testCreateAndActivateDoNotSendAndDoNotOpenOnTheProductionHost() throws {
        let transport = Transport()
        let closed = WP07CommerceClient(
            configuration: try APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com")!),
            transport: transport, token: "synthetic-token", apiHost: "www.chengyinhub.com")
        // Default gate is closed; the App injects MPCommerceGate + ReviewedAreaSwitch (both closed on www.chengyinhub.com).
        XCTAssertFalse(closed.commerceWritesOpen)
        XCTAssertThrowsError(try closed.create(productID: 1)) { error in
            XCTAssertEqual(error as? WP07CommerceRefusal, .closed)
        }
        XCTAssertThrowsError(try closed.activate(topicID: 2)) { error in
            XCTAssertEqual(error as? WP07CommerceRefusal, .closed)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}
