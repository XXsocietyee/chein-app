import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Purchase, quote, order, and claim are compiled and refuse before any request. Money stays off.
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
        XCTAssertThrowsError(try reader.quote(productID: "9", token: "session-token")) {
            XCTAssertEqual($0 as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try reader.order(productID: "9", token: "session-token")) {
            XCTAssertEqual($0 as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try reader.claim(giftToken: "gift-token", requestID: "gift_1", token: "session-token")) {
            XCTAssertEqual($0 as? PlatformPassWriteRefusal, .unreachable)
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
        XCTAssertThrowsError(try reader.payPassOrder(orderNo: "PP1", jsCode: "js", token: "session-token")) {
            XCTAssertEqual($0 as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertFalse(PlatformPass.moneyEnabled)
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
