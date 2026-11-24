#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class SweepHttpWriterTests: XCTestCase {
    private final class StubTransport: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var nextHandler: ((URLRequest) throws -> (Data, Int))?

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if let nextHandler {
                return try nextHandler(request)
            }
            return (Data(#"{"code":200,"msg":"ok","data":{"needRedeem":false}}"#.utf8), 200)
        }
    }

    nonisolated private func config() throws -> APIConfiguration {
        try APIConfiguration(baseURL: URL(string: "https://example.test")!)
    }

    private func formFields(from request: URLRequest) -> [String: String] {
        guard let type = request.value(forHTTPHeaderField: "Content-Type"),
              type.hasPrefix("multipart/form-data; boundary="),
              let body = request.httpBody,
              let text = String(data: body, encoding: .utf8) else { return [:] }
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        var out: [String: String] = [:]
        for chunk in text.components(separatedBy: "--\(boundary)") {
            guard let headerEnd = chunk.range(of: "\r\n\r\n") else { continue }
            let header = String(chunk[..<headerEnd.lowerBound])
            guard let nameStart = header.range(of: "name=\""),
                  let nameEnd = header[nameStart.upperBound...].range(of: "\"") else { continue }
            let key = String(header[nameStart.upperBound..<nameEnd.lowerBound])
            var value = String(chunk[headerEnd.upperBound...])
            if value.hasSuffix("\r\n") { value.removeLast() }  // "\r\n" is one Character
            out[key] = value
        }
        return out
    }

    func testChallengePOIWriterSuccessAndFormEncoding() async throws {
        let transport = StubTransport()
        transport.nextHandler = { _ in
            (Data(#"{"code":200,"data":{"needRedeem":true,"alreadyClaimed":false,"medal":{"name":"Lantern Medal"}}}"#.utf8), 200)
        }
        let writer = ChallengePOIHTTPWriter(
            configuration: { try? self.config() },
            transport: transport,
            tokenProvider: { "Bearer test-token" }
        )
        let req = ChallengePOIRequestBuilder.request(
            nodeId: 42,
            payload: [
                "latitude": .number(31.23),
                "longitude": .number(121.47),
                "answer": .string("B"),
                "photoUrl": .string("https://cdn.example.test/p.jpg"),
            ]
        )
        let outcome = await writer.complete(req)
        guard case .success(let data) = outcome else {
            return XCTFail("Expected success, got \(outcome)")
        }
        XCTAssertEqual(data["needRedeem"].bool, true)
        XCTAssertEqual(transport.requests.count, 1)
        let sent = transport.requests[0]
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertEqual(sent.url?.path, "/api/city/nodes/42/complete")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        let fields = formFields(from: sent)
        XCTAssertEqual(fields["answer"], "B")
        XCTAssertEqual(fields["photoUrl"], "https://cdn.example.test/p.jpg")
        XCTAssertEqual(fields["code"], "")
        XCTAssertEqual(fields["lat"], "31.23")
        XCTAssertEqual(fields["lng"], "121.47")
    }

    func testChallengePOIWriterRejectsAndRequiresNeedRedeem() async throws {
        let transport = StubTransport()
        transport.nextHandler = { _ in
            (Data(#"{"code":500,"msg":"答案不正确"}"#.utf8), 200)
        }
        let writer = ChallengePOIHTTPWriter(
            configuration: { try? self.config() },
            transport: transport,
            tokenProvider: { "token-1" }
        )
        let req = ChallengePOIRequestBuilder.request(nodeId: 9, payload: ["answer": .string("A")])
        let rejected = await writer.complete(req)
        XCTAssertEqual(rejected, .rejected(message: "答案不正确"))

        transport.nextHandler = { _ in
            (Data(#"{"code":200,"data":{"ok":true}}"#.utf8), 200)
        }
        let missingRedeem = await writer.complete(req)
        guard case .unconfirmed = missingRedeem else {
            return XCTFail("Expected unconfirmed when needRedeem missing, got \(missingRedeem)")
        }
    }

    func testChallengePOIWriterGatesClosedRouteAndBlankToken() async throws {
        let transport = StubTransport()
        let closed = ChallengePOIHTTPWriter(
            configuration: { try? self.config() },
            transport: transport,
            tokenProvider: { "token-1" },
            isRouteOpen: { false }
        )
        let req = ChallengePOIRequestBuilder.request(nodeId: 1, payload: [:])
        let closedOutcome = await closed.complete(req)
        XCTAssertEqual(closedOutcome, .unavailable)
        XCTAssertTrue(transport.requests.isEmpty)

        let signedOut = ChallengePOIHTTPWriter(
            configuration: { try? self.config() },
            transport: transport,
            tokenProvider: { "   " }
        )
        let signedOutOutcome = await signedOut.complete(req)
        XCTAssertEqual(signedOutOutcome, .unavailable)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testMyProjectHTTPMutatorSendsAllSevenActionsAndMapsLibraryStatus() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .hostCancelRefund }
        let transport = StubTransport()
        transport.nextHandler = { _ in
            (Data(#"{"code":200,"msg":"操作成功"}"#.utf8), 200)
        }
        let mutator = MyProjectHTTPMutator(
            configuration: { try? self.config() },
            transport: transport,
            tokenProvider: { "token-mp" },
            allowsCancelActivity: { true }
        )

        let cases: [(MyProjectMutation, String, String, [String: String])] = [
            (.toggleOnline(biz: .topic, id: 10, currentlyOnline: true), "MERCHANT", "/api/topic/update_user_status", ["id": "10", "scope": "MERCHANT", "expectedUserStatus": "1"]),
            (.toggleOnline(biz: .activity, id: 11, currentlyOnline: false), "", "/api/activity/update_publish_status", ["id": "11", "scope": ""]),
            (.cancelActivity(id: 12), "MERCHANT", "/api/activity/cancel", ["id": "12", "reason": "主办方取消活动", "scope": "MERCHANT"]),
            (.delete(biz: .topic, id: 13), "", "/api/topic/delete", ["id": "13", "scope": ""]),
            (.delete(biz: .activity, id: 14), "", "/api/activity/delete", ["id": "14", "scope": ""]),
            (.deleteTemplate(id: 15), "MERCHANT", "/api/template/delete", ["template_id": "15", "scope": "MERCHANT"]),
            (.setTemplateLibrary(id: 16, published: false), "", "/api/template/updateLibraryStatus", ["template_id": "16", "status": "3", "scope": ""]),
            (.setTemplateLibrary(id: 17, published: true), "", "/api/template/updateLibraryStatus", ["template_id": "17", "status": "1", "scope": ""]),
        ]

        for (index, item) in cases.enumerated() {
            let outcome = await mutator.perform(MyProjectMutationBuilder.request(for: item.0, scope: item.1))
            XCTAssertEqual(outcome, .done)
            let sent = transport.requests[index]
            XCTAssertEqual(sent.httpMethod, "POST")
            XCTAssertEqual(sent.url?.path, item.2)
            XCTAssertEqual(formFields(from: sent), item.3)
        }
    }

    func testMyProjectHTTPMutatorGatesActivityCancelAndPropagatesFailure() async throws {
        let transport = StubTransport()
        let moneyClosed = MyProjectHTTPMutator(
            configuration: { try? self.config() },
            transport: transport,
            tokenProvider: { "token-mp" },
            allowsCancelActivity: { false }
        )
        let blocked = await moneyClosed.perform(MyProjectMutationBuilder.request(for: .cancelActivity(id: 9), scope: ""))
        XCTAssertEqual(blocked, .unavailable)
        XCTAssertTrue(transport.requests.isEmpty)

        transport.nextHandler = { _ in
            (Data(#"{"code":500,"msg":"当前状态已变更"}"#.utf8), 200)
        }
        let casMismatch = await moneyClosed.perform(MyProjectMutationBuilder.request(for: .toggleOnline(biz: .topic, id: 9, currentlyOnline: true), scope: ""))
        XCTAssertEqual(casMismatch, .failed(message: "当前状态已变更"))
        XCTAssertEqual(transport.requests.count, 1)
    }
}
#endif
