import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

@MainActor final class PlayActionReceiptTests: XCTestCase {
    private func session() throws -> PlayExperienceSession {
        try .init(accountID: 9001, epoch: 1, namespace: "synthetic-cn", token: "synthetic-token")
    }
    private func service(_ transport: any HTTPTransport, enabled: Set<PlayExperienceCapability> = [.reads, .classicCompletion]) throws -> PlayExperienceService {
        .init(configuration: try .init(baseURL: URL(string: "https://example.com/")!), transport: transport, enabled: enabled)
    }
    private func recorder() -> PlayRecoveryRecordingTransport {
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/api/play/nodes"] = .reply(PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.branch), 200)
        transport.responses["/api/play/route-state"] = .reply(PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.route), 200)
        transport.responses["/api/play/answer"] = .failure(.unknownResult)
        return transport
    }
    private func coordinator(_ transport: any HTTPTransport, recovery: PlayMemoryCompletionRecovery, current: @escaping () -> PlayExperienceSession?) throws -> PlayExperienceCoordinator {
        .init(scope: .activity(41), service: try service(transport), recovery: recovery, pausedStorage: PlayMemoryPausedStorage(), currentSession: current)
    }
    private func routeActionID(_ request: URLRequest) throws -> String {
        if request.httpMethod == "GET" {
            let parts = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            return try XCTUnwrap(parts.queryItems?.first { $0.name == "routeActionId" }?.value)
        }
        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        let marker = "name=\"routeActionId\"\r\n\r\n"
        let start = try XCTUnwrap(body.range(of: marker))
        let rest = body[start.upperBound...]
        let end = try XCTUnwrap(rest.range(of: "\r\n"))
        return String(rest[..<end.lowerBound])
    }

    func testIdentityKeepsTheOriginalIdAndRefusesAReplacement() {
        XCTAssertEqual(PlayActionReceiptIdentity.retained(original: "action-1", proposed: "action-1"), "action-1")
        XCTAssertEqual(PlayActionReceiptIdentity.retained(original: " action-1 ", proposed: "action-1"), "action-1")
        XCTAssertNil(PlayActionReceiptIdentity.retained(original: "action-1", proposed: "action-2"))
        XCTAssertNil(PlayActionReceiptIdentity.retained(original: "", proposed: ""))
        XCTAssertNil(PlayActionReceiptIdentity.retained(original: "action 1", proposed: "action 1"))
    }

    func testPendingReceiptIsNotARejectionAndAForeignIdIsMalformed() throws {
        let pending = Data(#"{"code":520,"msg":"original result is still unknown","data":null}"#.utf8)
        XCTAssertEqual(try PlayActionReceipt.decode(pending, status: 200, routeActionID: "action-1"), .pending)
        XCTAssertThrowsError(try PlayActionReceipt.decode(Data(), status: 500, routeActionID: "action-1")) { error in
            XCTAssertEqual(error as? PlayExperienceError, .unknownResult)
        }
        let foreign = Data(#"{"code":200,"data":{"nodeId":701,"routeActionId":"other"}}"#.utf8)
        XCTAssertThrowsError(try PlayActionReceipt.decode(foreign, status: 200, routeActionID: "action-1")) { error in
            XCTAssertEqual(error as? PlayExperienceError, .malformed)
        }
        let confirmed = Data(#"{"code":200,"data":{"nodeId":701}}"#.utf8)
        guard case .confirmed(let value) = try PlayActionReceipt.decode(confirmed, status: 200, routeActionID: "action-1") else {
            return XCTFail("matching receipt")
        }
        XCTAssertEqual(value["nodeId"].tolerantInteger, 701)
    }

    func testReceiptReadUsesTheOriginalIdAndLeavesCode520Pending() async throws {
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/api/play/action-receipt"] = .reply(Data(#"{"code":520,"data":null}"#.utf8), 200)
        let api = try service(transport)
        let outcome = try await api.originalActionReceipt(scope: .activity(41), nodeID: 701, routeActionID: "action-1", token: "synthetic-token")
        XCTAssertEqual(outcome, .pending)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/play/action-receipt")
        XCTAssertEqual(try routeActionID(request), "action-1")
        let parts = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.queryItems?.first { $0.name == "activityId" }?.value, "41")
        XCTAssertEqual(parts.queryItems?.first { $0.name == "nodeId" }?.value, "701")
        XCTAssertNil(parts.queryItems?.first { $0.name == "topicId" })
    }

    func testUnknownWriteQueriesTheOriginalReceiptAndDoesNotFail() async throws {
        let current = try session(), transport = recorder(), recovery = PlayMemoryCompletionRecovery()
        transport.responses["/api/play/action-receipt"] = .reply(Data(#"{"code":520,"data":null}"#.utf8), 200)
        let model = try coordinator(transport, recovery: recovery, current: { current })
        await model.load()
        await model.submit(try model.review(nodeID: 701, evidence: .answer("synthetic answer")))
        XCTAssertEqual(model.phase, .unknown)
        XCTAssertNotEqual(model.phase, .failed)
        XCTAssertEqual(model.issue, .unknownResult)
        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        let reads = transport.requests.filter { $0.url?.path == "/api/play/action-receipt" }
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(reads.count, 1)
        XCTAssertEqual(try routeActionID(posts[0]), try routeActionID(reads[0]))
        let pending = try await recovery.read(PlayRunStorageKey.make(session: current, scope: .activity(41)))
        XCTAssertEqual(pending?.value.state, .unknown)
        XCTAssertFalse(pending?.value.requestAcknowledged == true)
    }

    func testUnknownRetryResubmitsTheSameActionId() async throws {
        let current = try session(), transport = recorder(), recovery = PlayMemoryCompletionRecovery()
        transport.responses["/api/play/action-receipt"] = .reply(Data(#"{"code":520,"data":null}"#.utf8), 200)
        let model = try coordinator(transport, recovery: recovery, current: { current })
        await model.load()
        await model.submit(try model.review(nodeID: 701, evidence: .answer("exact answer")))
        XCTAssertFalse(model.canRetryExactBranch)
        await model.load()
        XCTAssertTrue(model.canRetryExactBranch)
        transport.responses["/api/play/answer"] = .reply(Data(#"{"code":409,"msg":"synthetic conflict","data":null}"#.utf8), 200)
        await model.retryExactBranchAfterReadback()
        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(posts[0].httpBody, posts[1].httpBody)
        XCTAssertEqual(try routeActionID(posts[0]), try routeActionID(posts[1]))
        let queried = transport.requests.filter { $0.url?.path == "/api/play/action-receipt" }
        XCTAssertEqual(try routeActionID(queried[0]), try routeActionID(posts[0]))
        let pending = try await recovery.read(PlayRunStorageKey.make(session: current, scope: .activity(41)))
        XCTAssertEqual(pending?.value.state, .unknown)
    }

    func testConfirmedOriginalReceiptAcknowledgesTheSameNode() async throws {
        let current = try session(), transport = recorder(), recovery = PlayMemoryCompletionRecovery()
        let model = try coordinator(transport, recovery: recovery, current: { current })
        await model.load()
        let review = try model.review(nodeID: 701, evidence: .answer("synthetic answer"))
        let actionID = try XCTUnwrap(review.advance?.actionID)
        let body = #"{"code":200,"data":{"nodeId":701,"routeActionId":""# + actionID + #""}}"# // was `\"}}`: an unterminated JSON string
        transport.responses["/api/play/action-receipt"] = .reply(Data(body.utf8), 200)
        await model.submit(review)
        XCTAssertNotEqual(model.phase, .failed)
        XCTAssertNil(model.issue)
        let posts = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(try routeActionID(posts[0]), actionID)
        let pending = try await recovery.read(PlayRunStorageKey.make(session: current, scope: .activity(41)))
        XCTAssertEqual(pending?.value.state, .acknowledged)
        XCTAssertEqual(pending?.value.intent.advance?.actionID, actionID)
    }

    func testRejectedWriteDoesNotQueryAReceipt() async throws {
        let current = try session(), transport = recorder(), recovery = PlayMemoryCompletionRecovery()
        transport.responses["/api/play/answer"] = .reply(Data(#"{"code":409,"data":null}"#.utf8), 200)
        let model = try coordinator(transport, recovery: recovery, current: { current })
        await model.load()
        await model.submit(try model.review(nodeID: 701, evidence: .answer("synthetic answer")))
        XCTAssertTrue(transport.requests.filter { $0.url?.path == "/api/play/action-receipt" }.isEmpty)
        let pending = try await recovery.read(PlayRunStorageKey.make(session: current, scope: .activity(41)))
        XCTAssertEqual(pending?.value.state, .unknown)
    }
}
