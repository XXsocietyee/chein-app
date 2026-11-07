#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mini-program `pages/topic/merchantinfo`: the merchant-perspective topic read
/// (`api/topic/info-to-user` then `api/topic/merchant-recruitment-chapters`) behind
/// `MerchantContentDocumentView(query: .chapters(topicID:))`. Synthetic transport only; no real host.
private final class MerchantInfoChaptersTransport: HTTPTransport {
    var replies: [(String, Int)] = []
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst()
        return (Data(reply.0.utf8), reply.1)
    }
    func ok(_ raw: String) { replies.append(("{\"code\":200,\"data\":" + raw + "}", 200)) }
}

@MainActor final class MerchantInfoChaptersReadTests: XCTestCase {
    private func session() throws -> MerchantContentSession {
        try MerchantContentSession(accountID: 1, epoch: 1, storageScope: "test-realm", token: "synthetic-token")
    }
    private func service(_ transport: MerchantInfoChaptersTransport, session: MerchantContentSession?) throws -> MerchantContentService {
        MerchantContentService(configuration: try APIConfiguration(baseURL: URL(string: "https://merchant-info.example")!),
                               transport: transport, currentSession: { session })
    }
    private func body(_ request: URLRequest) -> String {
        String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    }

    func testPublishedTopicReadsPlayerProjectionThenRecruitmentChaptersWithTopicID() async throws {
        let transport = MerchantInfoChaptersTransport()
        transport.ok(MerchantContentFixtureData.access)
        transport.ok(#"{"id":70,"name":"Synthetic route"}"#)
        transport.ok(#"[{"id":7,"name":"Synthetic chapter"}]"#)
        let result = try await service(transport, session: try session()).load(.chapters(topicID: 70))

        XCTAssertEqual(result.query, .chapters(topicID: 70))
        XCTAssertEqual(result.value["mode"].text, "chapters")
        XCTAssertEqual(result.value["topic"]["name"].text, "Synthetic route")
        XCTAssertEqual(result.value["chapters"].array?.count, 1)
        XCTAssertEqual(transport.requests.compactMap { $0.url?.path },
                       ["/api/merchant/access/me", "/api/topic/info-to-user", "/api/topic/merchant-recruitment-chapters"])
        XCTAssertTrue(transport.requests.allSatisfy { $0.httpMethod == "POST" })
        XCTAssertTrue(transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "synthetic-token" })
        XCTAssertTrue(body(transport.requests[1]).contains("name=\"id\"\r\n\r\n70\r\n"))
        XCTAssertTrue(body(transport.requests[2]).contains("name=\"id\"\r\n\r\n70\r\n"))
    }

    func testServerDenialOnRecruitmentChaptersFailsClosedWithoutSnapshot() async throws {
        let transport = MerchantInfoChaptersTransport()
        transport.ok(MerchantContentFixtureData.access)
        transport.ok(#"{"id":70,"name":"Synthetic route"}"#)
        transport.replies.append((#"{"code":403}"#, 200))
        let s = try service(transport, session: try session())
        do {
            _ = try await s.load(.chapters(topicID: 70))
            XCTFail("Expected denial")
        } catch {
            XCTAssertEqual(error as? MerchantContentFailure, .denied)
        }
        XCTAssertEqual(transport.requests.count, 3)
    }

    func testMismatchedTopicIdentityStopsBeforeChapterRead() async throws {
        let transport = MerchantInfoChaptersTransport()
        transport.ok(MerchantContentFixtureData.access)
        transport.ok(#"{"id":71,"name":"Another route"}"#)
        let s = try service(transport, session: try session())
        do {
            _ = try await s.load(.chapters(topicID: 70))
            XCTFail("Expected malformed")
        } catch {
            XCTAssertEqual(error as? MerchantContentFailure, .malformed)
        }
        XCTAssertEqual(transport.requests.compactMap { $0.url?.path }, ["/api/merchant/access/me", "/api/topic/info-to-user"])
    }

    func testSignedOutMakesNoRequest() async throws {
        let transport = MerchantInfoChaptersTransport()
        let s = try service(transport, session: nil)
        do {
            _ = try await s.load(.chapters(topicID: 70))
            XCTFail("Expected unauthorized")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}
#endif
