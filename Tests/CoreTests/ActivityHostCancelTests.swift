import Foundation
import XCTest
@testable import QuestifyCore

private final class CancelTransport: HTTPTransport, @unchecked Sendable {
    var replies: [(String, Int)] = []
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !replies.isEmpty else { throw APIError.httpStatus(503) }
        let r = replies.removeFirst(); return (Data(r.0.utf8), r.1)
    }
}
final class ActivityHostCancelRulesTests: XCTestCase {
    func testReasonRules() {
        XCTAssertFalse(ActivityHostCancelRules.canSubmit(reason: "  ", paidPlayers: 2))
        XCTAssertFalse(ActivityHostCancelRules.canSubmit(reason: "x", paidPlayers: nil))
        XCTAssertFalse(ActivityHostCancelRules.canSubmit(reason: String(repeating: "a", count: 101), paidPlayers: 0))
        XCTAssertTrue(ActivityHostCancelRules.canSubmit(reason: " rain ", paidPlayers: 0))
    }
    func testHostIdentity() {
        XCTAssertTrue(ActivityHostCancelRules.isHost(hostMemberID: 5, accountID: 5))
        XCTAssertFalse(ActivityHostCancelRules.isHost(hostMemberID: 5, accountID: 6))
        XCTAssertFalse(ActivityHostCancelRules.isHost(hostMemberID: nil, accountID: 5))
        XCTAssertFalse(ActivityHostCancelRules.isHost(hostMemberID: 0, accountID: 0))
    }
    func testUnknownPaidPlayerCountIsAnEmDash() {
        XCTAssertEqual(ActivityHostCancelPreview.paidPlayers(0).paidPlayerCountText, "0")
        XCTAssertEqual(ActivityHostCancelPreview.paidPlayers(4).paidPlayerCountText, "4")
        XCTAssertEqual(ActivityHostCancelPreview.paidPlayers(-1).paidPlayerCountText, "—")
        XCTAssertEqual(ActivityHostCancelPreview.unknownCount.paidPlayerCountText, "—")
        XCTAssertEqual(ActivityHostCancelPreview.blocked(nil).paidPlayerCountText, "—")
        XCTAssertNotEqual(ActivityHostCancelPreview.unknownCount.paidPlayerCountText, "0")
    }
}
@MainActor final class ActivityHostCancelAccessTests: XCTestCase {
    private func make(_ t: CancelTransport, enabled: Bool = true) throws -> ActivityHostCancelHTTPAccess {
        .init(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api")!), transport: t,
              enabled: { enabled }, session: { (3, "synthetic-token") })
    }
    func testPreviewVariants() async throws {
        let t = CancelTransport()
        t.replies = [(#"{"code":200,"data":{"paidPlayers":4}}"#, 200), (#"{"code":500,"msg":"no permission"}"#, 200),
                     (#"{"code":200,"data":{"paidPlayers":"x"}}"#, 200), (#"{"code":200,"data":{"paidPlayers":-1}}"#, 200)]
        let a = try make(t)
        let p1 = try await a.preview(activityID: 9)
        XCTAssertEqual(p1, .paidPlayers(4))
        XCTAssertEqual(t.requests[0].url?.path, "/prod-api/api/activity/cancel_preview")
        let p2 = try await a.preview(activityID: 9)
        XCTAssertEqual(p2, .blocked("no permission"))
        let p3 = try await a.preview(activityID: 9)
        XCTAssertEqual(p3, .unknownCount)
        let p4 = try await a.preview(activityID: 9)
        XCTAssertEqual(p4, .unknownCount)
    }
    func testCancelSendsTrimmedReasonAndMapsOutcome() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .hostCancelRefund }
        let t = CancelTransport()
        t.replies = [(#"{"code":200,"msg":"refunded"}"#, 200), (#"{"code":400,"msg":"late"}"#, 200), ("x", 502)]
        let a = try make(t)
        let c1 = try await a.cancel(activityID: 9, reason: " rain ")
        XCTAssertEqual(c1, .cancelled("refunded"))
        let body = try JSONSerialization.jsonObject(with: t.requests[0].httpBody!) as! [String: Any]
        XCTAssertEqual(body["reason"] as? String, "rain"); XCTAssertEqual(body["id"] as? Int, 9)
        let c2 = try await a.cancel(activityID: 9, reason: "r")
        XCTAssertEqual(c2, .rejected("late"))
        do { _ = try await a.cancel(activityID: 9, reason: "r"); XCTFail() } catch { XCTAssertEqual(error as? ActivityHostCancelFailure, .network) }
    }
    func testInvalidAndDisabledSendNothing() async throws {
        let t = CancelTransport(); let a = try make(t)
        do { _ = try await a.cancel(activityID: 9, reason: "  "); XCTFail() } catch { XCTAssertEqual(error as? ActivityHostCancelFailure, .invalid) }
        let off = try make(t, enabled: false)
        do { _ = try await off.preview(activityID: 9); XCTFail() } catch { XCTAssertEqual(error as? ActivityHostCancelFailure, .disabled) }
        XCTAssertTrue(t.requests.isEmpty)
    }
}
