import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Purchase, quote, order, and claim are compiled and refuse before any request. Money stays off.
final class PlatformPassPurchaseUnreachableTests: XCTestCase {
    func testPurchaseAndClaimStayUnreachableWhileMoneyIsOff() async throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(MPParityBindings.moneyEnabled)
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
        let forbidden = [PlatformPass.purchasePath, PlatformPass.quotePath, PlatformPass.orderPath, PlatformPass.claimPath]
        XCTAssertTrue(wire.requests.allSatisfy { request in
            forbidden.contains(request.url?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? "") == false
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
