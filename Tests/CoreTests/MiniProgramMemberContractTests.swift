import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Member `request(` rows from hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Cancel, confirm, and refund-apply are contracts only. `PlatformPass.moneyEnabled` stays false
/// and those methods throw before any transport send. Create and pay are not repeated here.
final class MiniProgramMemberContractTests: XCTestCase {
    private let base = URL(string: "https://example.com")!

    func testPassOrderCancelPinsPostAndDecodesCancelled() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        let request = try PlatformPass.passOrderCancelRequest(baseURL: base, orderNo: "NO1", token: "synthetic")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/platform-pass/orders/NO1/cancel")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), "{}")
        let order = try PlatformPass.decodeOrderEnvelope(Data(#"{"code":200,"data":{"orderNo":"NO1","status":"CANCELLED"}}"#.utf8))
        XCTAssertEqual(order.status, .cancelled)
        XCTAssertEqual(order.stateText, "已取消")
        XCTAssertThrowsError(try PlatformPass.passOrderCancelRequest(baseURL: base, orderNo: "NO/1", token: "synthetic")) { error in
            XCTAssertEqual(error as? APIError, .invalidRequest)
        }
        let transport = MemberContractTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.cancelPassOrder(orderNo: "NO1", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPassOrderRefundApplyPinsReasonAndDecodesReviewStatus() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        let request = try PlatformPass.passOrderRefundApplyRequest(baseURL: base, orderNo: "NO1", reason: " 不想要了 ", token: "synthetic")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/platform-pass/orders/NO1/refund-apply")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String])
        XCTAssertEqual(parsed["reason"], "不想要了")
        let order = try PlatformPass.decodeOrderEnvelope(Data(#"{"code":"200","data":{"orderNo":"NO1","status":"PAID","refund":{"reviewStatus":"PENDING"}}}"#.utf8))
        XCTAssertEqual(order.status, .paid)
        XCTAssertEqual(order.refundText, "退款审核中")
        XCTAssertThrowsError(try PlatformPass.passOrderRefundApplyRequest(baseURL: base, orderNo: "NO1", reason: "  ", token: "synthetic")) { error in
            XCTAssertEqual(error as? APIError, .invalidRequest)
        }
        let transport = MemberContractTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.refundApplyPassOrder(orderNo: "NO1", reason: "不想要了", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testPassOrderConfirmPinsPostAndDecodesPaid() throws {
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        let request = try PlatformPass.passOrderConfirmRequest(baseURL: base, orderNo: "NO1", token: "synthetic")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/platform-pass/orders/NO1/confirm")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), "{}")
        let order = try PlatformPass.decodeOrderEnvelope(Data(#"{"code":"200","data":{"orderNo":"NO1","status":"PAID","planCode":"MONTH"}}"#.utf8))
        XCTAssertEqual(order.status, .paid)
        XCTAssertEqual(order.stateText, "已开通")
        let transport = MemberContractTransport()
        let client = try passClient(transport)
        XCTAssertThrowsError(try client.confirmPassOrder(orderNo: "NO1", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testProfileIMStartPinsTargetMemberIdAndDecodesConversationId() throws {
        let request = try ProfileIMStartContract.request(baseURL: base, targetMemberID: "82", token: "synthetic")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/im/start")
        XCTAssertEqual(ProfileIMStartContract.path, "api/im/start")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        let field = "target_member_id"
        XCTAssertEqual(field, "target_member_id")
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)
        XCTAssertEqual(body, "target_member_id=82")
        XCTAssertEqual(try ProfileIMStartContract.conversationID(in: Data(#"{"code":200,"data":{"conversationId":901}}"#.utf8)), 901)
        XCTAssertEqual(try ProfileIMStartContract.conversationID(in: Data(#"{"code":"200","data":{"conversationId":"901"}}"#.utf8)), 901)
        XCTAssertThrowsError(try ProfileIMStartContract.conversationID(in: Data(#"{"code":200,"data":{"conversationId":0}}"#.utf8))) { error in
            XCTAssertEqual(error as? APIError, .malformedResponse)
        }
        XCTAssertThrowsError(try ProfileIMStartContract.request(baseURL: base, targetMemberID: "", token: "synthetic")) { error in
            XCTAssertEqual(error as? APIError, .invalidRequest)
        }
    }

    private func passClient(_ transport: MemberContractTransport) throws -> PlatformPass {
        PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
    }
}

private final class MemberContractTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":null}"#.utf8), 200)
    }
}
