import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Purchase stays refused. Quote, order, pay, and claim throw while no payment host is installed, and send once it is.
final class PlatformPassPurchaseUnreachableTests: XCTestCase {
    func testPurchaseAndClaimStayUnreachableWhileMoneyIsOff() async throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        for kind in ReleaseMoneyWriteKind.allCases {
            XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(kind))
        }

        let wire = Wire()
        wire.body = Data(#"{"code":200,"data":{"enabled":false}}"#.utf8)
        let reader = try PlatformPass(configuration: APIConfiguration(baseURL: URL(string: "https://fixture.example.test")!), transport: wire)
        _ = try await reader.overview(token: "session-token", viewerIsMerchant: false)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/platform-pass")

        XCTAssertThrowsError(try reader.purchase(planCode: "YEAR", channel: "XPAY", token: "session-token")) {
            XCTAssertEqual($0 as? PlatformPassWriteRefusal, .unreachable)
        }
        do {
            _ = try await reader.quote(productID: "9", token: "session-token")
            XCTFail("quote")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        do {
            _ = try await reader.order(productID: "9", token: "session-token", payMode: 1, quoteSign: "sign", quoteExpiresAt: 1, requestID: "mkp_1")
            XCTFail("order")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        do {
            _ = try await reader.claim(giftToken: "gift-token", requestID: "gift_1", token: "session-token")
            XCTFail("claim")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests.map { $0.httpMethod ?? "" }, ["GET"])
        do {
            _ = try await reader.sendCancelPassOrder(orderNo: "PP1", token: "session-token")
            XCTFail("cancel stays off")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertEqual(wire.requests.count, 1)
        let forbidden = [PlatformPass.purchasePath, PlatformPass.quotePath, PlatformPass.orderPath, PlatformPass.claimPath]
        XCTAssertTrue(wire.requests.allSatisfy { request in
            forbidden.contains(request.url?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "") == false
        })
    }

    func testCancelAndRefundApplySendOnlyWhenTheTestDerivationIsOn() async throws {
        defer { PlatformPass.orderWriteTestDerivation = nil }
        PlatformPass.orderWriteTestDerivation = nil
        let base = URL(string: ReviewedMarketLaunch.chinaProductionBaseURL)!
        func write(_ suffix: String) -> URLRequest {
            let url = ["api", "platform-pass", "orders", "PP1", suffix].reduce(base) { $0.appendingPathComponent($1) }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            return request
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(write("cancel")))
        XCTAssertTrue(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(write("pay")))
        PlatformPass.orderWriteTestDerivation = { $0 == .cancel || $0 == .refundApply }
        XCTAssertFalse(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(write("cancel")))
        XCTAssertFalse(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(write("refund-apply")))
        XCTAssertTrue(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(write("confirm")))
        XCTAssertTrue(ChinaReviewedRouteCapability.isPlatformPassOrderWrite(write("pay")))

        let wire = Wire()
        wire.body = Data(#"{"code":200,"data":{"orderNo":"PP1","status":"CANCELLED"}}"#.utf8)
        let reader = try PlatformPass(configuration: APIConfiguration(baseURL: URL(string: "https://fixture.example.test")!), transport: wire)
        _ = try await reader.sendCancelPassOrder(orderNo: "PP1", token: "session-token")
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests[0].httpMethod, "POST")
        XCTAssertEqual(wire.requests[0].url?.path, "/api/platform-pass/orders/PP1/cancel")
        XCTAssertEqual(wire.requests[0].httpBody, Data("{}".utf8))
        do {
            _ = try await reader.sendConfirmPassOrder(orderNo: "PP1", token: "session-token")
            XCTFail("confirm stays off")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        do {
            _ = try await reader.payPassOrder(orderNo: "PP1", jsCode: "js", token: "session-token")
            XCTFail("pay")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertFalse(PlatformPass.moneyEnabled)
    }

    /// Owner 2026-11-25: an installed host, including www.chengyinhub.com, turns payment on.
    /// Quote, order, pay, and gift claim then send the existing paths. A missing host still throws.
    /// Virtual goods stay off, and purchase still throws because it would pick a channel.
    func testQuoteOrderPayAndClaimSendWhenAPaymentHostIsInstalled() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        let closed = Wire()
        let refused = try PlatformPass(configuration: APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!), transport: closed)
        do {
            _ = try await refused.quote(productID: "9", token: "session-token")
            XCTFail("missing host")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(closed.requests.isEmpty)

        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .virtualGoods }
        XCTAssertTrue(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        do {
            _ = try await refused.payProductOrder(orderNo: "MO1", token: "session-token")
            XCTFail("virtual goods")
        } catch {
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(closed.requests.isEmpty)

        ReleaseMoneyWriteSwitch.testDerivation = { kind in
            switch kind {
            case .payment, .payout, .withdrawal, .refund, .hostCancelRefund: return true
            case .virtualGoods: return false
            }
        }
        XCTAssertTrue(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        let wire = Wire()
        wire.body = Data(#"{"code":200,"data":{"productId":9,"quantity":1,"fulfillmentKind":1,"quoteSign":"sig","quoteExpiresAt":1700000000000,"availablePayModes":[1],"orderNo":"MO1","statusLabel":"PAID","registrationId":"11"}}"#.utf8)
        let client = try PlatformPass(configuration: APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!), transport: wire)
        let quote = try await client.quote(productID: "9", token: "session-token")
        XCTAssertEqual(quote.quoteSign, "sig")
        XCTAssertEqual(quote.availablePayModes, [1])
        let ordered = try await client.order(productID: "9", token: "session-token", payMode: 1, quoteSign: "sig", quoteExpiresAt: 1_700_000_000_000, requestID: "mkp_1")
        XCTAssertEqual(ordered.orderNo, "MO1")
        let paid = try await client.payProductOrder(orderNo: "MO1", token: "session-token")
        XCTAssertEqual(paid.orderNo, "MO1")
        let passPaid = try await client.payPassOrder(orderNo: "PP1", jsCode: "js", token: "session-token")
        XCTAssertEqual(passPaid.orderNo, "PP1")
        let emptyCode = try await client.payPassOrder(orderNo: "PP1", jsCode: "", token: "session-token")
        XCTAssertEqual(emptyCode.orderNo, "PP1")
        let claimed = try await client.claim(giftToken: "gift-token", requestID: "gift_1", token: "session-token")
        XCTAssertEqual(claimed.registrationID, "11")
        XCTAssertThrowsError(try client.purchase(planCode: "YEAR", channel: "XPAY", token: "session-token")) {
            XCTAssertEqual($0 as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertEqual(wire.requests.map { $0.httpMethod }, ["POST", "POST", "POST", "POST", "POST", "POST"])
        XCTAssertEqual(wire.requests.map { $0.url?.path }, [
            "/prod-api/api/marketing/product/quote",
            "/prod-api/api/marketing/product/order",
            "/prod-api/api/marketing/product/orders/MO1/pay",
            "/prod-api/api/platform-pass/orders/PP1/pay",
            "/prod-api/api/platform-pass/orders/PP1/pay",
            "/prod-api/api/marketing/product/gifts/claim"
        ])
        XCTAssertEqual(wire.requests.map { $0.httpBody }, [
            Data(#"{"fulfillmentKind":1,"productId":9,"quantity":1}"#.utf8),
            Data(#"{"fulfillmentKind":1,"payMode":1,"productId":9,"quantity":1,"quoteExpiresAt":1700000000000,"quoteSign":"sig","requestId":"mkp_1"}"#.utf8),
            Data("{}".utf8),
            Data(#"{"jsCode":"js"}"#.utf8),
            Data("{}".utf8),
            Data(#"{"requestId":"gift_1","token":"gift-token"}"#.utf8)
        ])
        XCTAssertTrue(wire.requests.allSatisfy { body in
            let text = String(data: body.httpBody ?? Data(), encoding: .utf8) ?? ""
            return !text.contains("channel") && !text.contains("provider") && !text.contains("XPAY")
        })
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var body = Data()
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (body, 200)
        }
    }
}
