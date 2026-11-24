import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

@MainActor final class OrientScoreReviewWriterTests: XCTestCase {
    private func score(status: Int = 1) throws -> OrientSessionScore {
        let json = """
        {"sessionId":9,"topicId":3,"activityId":0,"status":\(status),"totalCenti":1700,\
        "byDimension":{"TASK":2000,"PUZZLE":0,"BONUS":0,"PENALTY":-300,"ADJUSTMENT":0},\
        "timeline":[{"entryId":30,"dimension":"TASK","deltaCenti":2000,"runningCenti":2000,"reasonCode":"TASK_DONE"}],\
        "settlement":null,"appeals":[],"disputes":[]}
        """
        return try JSONDecoder().decode(OrientSessionScore.self, from: Data(json.utf8))
    }

    private func writer(_ transport: OrientTestTransport, status: Int = 1) throws -> OrientScoreReviewWriter {
        try OrientScoreReviewWriter(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
            transport: transport, token: { "synthetic-token" },
            ownerNamespace: "synthetic-cn-realm", accountID: 1, role: "player",
            score: try score(status: status),
            grantedPaths: [OrientScoreReviewWriter.appealPath, OrientScoreReviewWriter.disputePath])
    }

    private func record(reason: String = "申请复核", key: String = "score-key-01", entry: Int? = 30, status: Int = 0) -> String {
        let entryField = entry.map { "\"entryId\":\"\($0)\"" } ?? "\"entryId\":null"
        return """
        {"id":"72","sessionId":"9","memberId":"1",\(entryField),"nodeId":null,"reason":"\(reason)",\
        "status":\(status),"idempotencyKey":"\(key)","resolutionEntryId":null,"resolutionNote":null,"windowDeadline":null}
        """
    }

    private func paths(_ transport: OrientTestTransport) -> [String] {
        transport.requests.compactMap { $0.url?.path }
    }

    func testAppealSuccessDoesNotRereadOrCallSyncSettlePurchaseOrPayout() async throws {
        let transport = OrientTestTransport()
        transport.append(record())
        let writer = try writer(transport)
        try await writer.submit(kind: .appeal, reason: " 申请复核 ", key: "score-key-01", entryID: 30)
        XCTAssertNil(writer.lockedKey)
        XCTAssertEqual(paths(transport), ["/api/orient/scoring/appeal"])
        let body = String(data: transport.requests[0].httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(body, "entryId=30&idempotencyKey=score-key-01&reason=%E7%94%B3%E8%AF%B7%E5%A4%8D%E6%A0%B8&sessionId=9")
        XCTAssertFalse(paths(transport).contains { $0.contains("sync") || $0.contains("settle") || $0.contains("purchase") || $0.contains("payout") })
    }

    func testClientErrorReleasesTheIdWithoutAReceiptRead() async throws {
        let transport = OrientTestTransport()
        transport.append("null", code: 400, status: 400)
        let writer = try writer(transport)
        do {
            try await writer.submit(kind: .appeal, reason: "申请复核", key: "score-key-01", entryID: 30)
            XCTFail("a 4xx is not success")
        } catch let outcome as OrientScoreReviewOutcome {
            guard case .rejected = outcome else { return XCTFail("expected a confirmed rejection") }
        }
        XCTAssertNil(writer.lockedKey)
        XCTAssertEqual(paths(transport), ["/api/orient/scoring/appeal"])
    }

    func testTransportFailureStaysLockedUntilTheReceiptMatches() async throws {
        let transport = OrientTestTransport()
        transport.replies.append(.failure(URLError(.networkConnectionLost)))
        transport.append("{\"state\":\"NOT_FOUND\",\"kind\":\"APPEAL\",\"idempotencyKey\":\"score-key-01\"}")
        let writer = try writer(transport)
        do {
            try await writer.submit(kind: .appeal, reason: "申请复核", key: "score-key-01", entryID: 30)
            XCTFail("an unknown transport result is not success")
        } catch let outcome as OrientScoreReviewOutcome {
            XCTAssertEqual(outcome, .unknown)
        }
        XCTAssertEqual(writer.lockedKey, "score-key-01")
        XCTAssertEqual(paths(transport), ["/api/orient/scoring/appeal", "/api/orient/scoring/receipt"])
        let firstBody = transport.requests[0].httpBody

        do {
            try await writer.submit(kind: .appeal, reason: "改写理由", key: "other-key", entryID: 31)
            XCTFail("a new id must not replace a locked one")
        } catch let outcome as OrientScoreReviewOutcome {
            XCTAssertEqual(outcome, .unknown)
        }
        XCTAssertEqual(writer.lockedKey, "score-key-01")
        XCTAssertEqual(transport.requests.count, 2)

        transport.append("{\"state\":\"NOT_FOUND\",\"kind\":\"APPEAL\",\"idempotencyKey\":\"score-key-01\"}")
        transport.append(record())
        try await writer.submit(kind: .appeal, reason: "改写理由", key: "score-key-01", entryID: 31)
        XCTAssertNil(writer.lockedKey)
        XCTAssertEqual(transport.requests[3].httpBody, firstBody)
        XCTAssertEqual(transport.requests[3].url, transport.requests[0].url)
        XCTAssertEqual(paths(transport).filter { $0.hasSuffix("/appeal") }.count, 2)
        XCTAssertTrue(paths(transport).allSatisfy {
            $0 == "/api/orient/scoring/appeal" || $0 == "/api/orient/scoring/receipt"
        })
    }

    func testServerErrorThenMatchingReceiptIsSuccess() async throws {
        let transport = OrientTestTransport()
        transport.append("null", code: 500, status: 500)
        let wrapped = "{\"state\":\"PENDING\",\"kind\":\"APPEAL\",\"idempotencyKey\":\"score-key-01\",\"record\":\(record())}"
        transport.append(wrapped)
        let writer = try writer(transport)
        try await writer.submit(kind: .appeal, reason: "申请复核", key: "score-key-01", entryID: 30)
        XCTAssertNil(writer.lockedKey)
        XCTAssertEqual(paths(transport), ["/api/orient/scoring/appeal", "/api/orient/scoring/receipt"])
        XCTAssertEqual(transport.requests[1].url?.query, "idempotencyKey=score-key-01&kind=APPEAL&sessionId=9")
    }

    func testDisputeUsesItsOwnPathAndRefusesAnOpenRound() async throws {
        let transport = OrientTestTransport()
        let open = try writer(transport, status: 0)
        do {
            try await open.submit(kind: .dispute, reason: "成绩异议", key: "score-key-02", entryID: nil)
            XCTFail("an open round cannot dispute")
        } catch let outcome as OrientScoreReviewOutcome {
            guard case .rejected = outcome else { return XCTFail("expected a client rejection") }
        }
        XCTAssertNil(open.lockedKey)
        XCTAssertTrue(transport.requests.isEmpty)

        transport.append(record(reason: "成绩异议", key: "score-key-02", entry: nil))
        let finished = try writer(transport, status: 1)
        try await finished.submit(kind: .dispute, reason: "成绩异议", key: "score-key-02", entryID: nil)
        XCTAssertEqual(paths(transport), ["/api/orient/scoring/dispute"])
        let body = String(data: transport.requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertFalse(body.contains("entryId="))
        XCTAssertFalse(body.contains("nodeId="))
        XCTAssertNil(finished.lockedKey)
    }

    func testMissedTaskAppealSendsNodeIdWithoutAnEntry() async throws {
        let transport = OrientTestTransport()
        transport.append("""
        {"id":"72","sessionId":"9","memberId":"1","entryId":null,"nodeId":"12","reason":"漏记任务",\
        "status":0,"idempotencyKey":"score-key-node","resolutionEntryId":null,"resolutionNote":null,"windowDeadline":null}
        """)
        let writer = try writer(transport)
        try await writer.submit(kind: .appeal, reason: "漏记任务", key: "score-key-node", entryID: nil, nodeID: 12)
        XCTAssertNil(writer.lockedKey)
        XCTAssertEqual(paths(transport), ["/api/orient/scoring/appeal"])
        let body = String(data: transport.requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("nodeId=12"))
        XCTAssertFalse(body.contains("entryId="))
        XCTAssertTrue(body.contains("sessionId=9"))
    }

    func testMissingEntryDoesNotBuildARequest() async throws {
        let transport = OrientTestTransport()
        let writer = try writer(transport)
        do {
            try await writer.submit(kind: .appeal, reason: "申请复核", key: "score-key-01", entryID: nil)
            XCTFail("an appeal needs a ledger entry")
        } catch is OrientScoreReviewOutcome {}
        XCTAssertNil(writer.lockedKey)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testGrantWithoutTheTwoWritesCannotBeConstructed() {
        XCTAssertThrowsError(try OrientScoreReviewWriter(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
            transport: OrientTestTransport(), token: { "synthetic-token" },
            ownerNamespace: "synthetic-cn-realm", accountID: 1, role: "player",
            score: try score(),
            grantedPaths: [OrientScoreReviewWriter.appealPath]))
    }
}
