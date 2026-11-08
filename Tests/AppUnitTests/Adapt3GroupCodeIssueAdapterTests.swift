import Foundation
import XCTest
@testable import Questify

/// ADAPT-3. Fixture copies GroupCodeServiceImpl.issue's AjaxResult data map (hengyin@4ac8c249).
final class Adapt3GroupCodeIssueAdapterTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        let reply: String
        init(_ reply: String) { self.reply = reply }
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(reply.utf8), 200) }
    }
    private let base = URL(string: "https://example.test/")!

    func testRequestIsFormEncodedNotJSON() throws {
        let adapter = try Adapt3GroupCodeIssueAdapter(baseURL: base, token: "synthetic-token", transport: Wire("{}"))
        let request = try adapter.request(activityID: 55)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/verify/groupcode/issue")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/x-www-form-urlencoded") == true)
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), "activityId=55")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertThrowsError(try adapter.request(activityID: 0))
    }

    func testIssueDecodesBackendDataMapAndChecksActivity() async throws {
        let ok = #"{"msg":"操作成功","code":200,"data":{"code":"g2.signed.token","qrcodeUrl":"data:image/png;base64,AAAA","ttlMs":60000,"expiresAt":1793000060000,"topicId":3,"activityId":55,"clubId":7}}"#
        let wire = Wire(ok)
        let adapter = try Adapt3GroupCodeIssueAdapter(baseURL: base, token: "synthetic-token", transport: wire)
        let outcome = try await adapter.issue(activityID: 55)
        XCTAssertEqual(outcome, .applied(Adapt3GroupCodeFact(code: "g2.signed.token", qrcodeUrl: "data:image/png;base64,AAAA", ttlMs: 60000, activityId: 55), message: "操作成功"))
        let other = try await Adapt3GroupCodeIssueAdapter(baseURL: base, token: "synthetic-token", transport: Wire(ok)).issue(activityID: 56)
        XCTAssertEqual(other, .unknown)
    }

    func testBackendRefusalsAreRejectedNotApplied() async throws {
        let missing = try await Adapt3GroupCodeIssueAdapter(baseURL: base, token: "synthetic-token", transport: Wire(#"{"msg":"参数缺失","code":500}"#)).issue(activityID: 55)
        XCTAssertEqual(missing, .rejected(code: 500, message: "参数缺失"))
        let denied = try await Adapt3GroupCodeIssueAdapter(baseURL: base, token: "synthetic-token", transport: Wire(#"{"msg":"您没有该场次的团码核销权限","code":500}"#)).issue(activityID: 55)
        XCTAssertEqual(denied, .rejected(code: 500, message: "您没有该场次的团码核销权限"))
    }
}
