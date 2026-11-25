#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mini `pages/topic/merchantinfo` chapter application on a real transport.
/// Apply and withdraw stay closed unless that flag is set. `.closed` sends nothing.
private final class ChapterApplyTransport: HTTPTransport {
    var replies: [(String, Int)] = []
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst()
        return (Data(reply.0.utf8), reply.1)
    }
    func ok(_ raw: String) { replies.append(("{\"code\":200,\"data\":" + raw + "}", 200)) }
    func queueChapterRead() {
        ok(MerchantContentFixtureData.access)
        ok(#"{"id":70,"name":"Synthetic route"}"#)
        ok(#"[{"id":7,"name":"Synthetic chapter"}]"#)
    }
    func count(_ suffix: String) -> Int { requests.filter { $0.url?.path.hasSuffix(suffix) == true }.count }
}

@MainActor final class MerchantChapterApplyApprovalTests: XCTestCase {
    private func make(_ t: ChapterApplyTransport, journal: MerchantContentMemoryPendingStorage, approval: MerchantContentWriteApproval) throws -> MerchantContentService {
        let session = try MerchantContentSession(accountID: 1, epoch: 1, storageScope: "test-realm", token: "synthetic-token")
        return MerchantContentService(configuration: try APIConfiguration(baseURL: URL(string: "https://merchant-info.example")!),
                                      transport: t, currentSession: { session }, journal: journal, writeApproval: { approval })
    }
    func testDefaultApprovalKeepsApplyAndWithdrawClosed() throws {
        let t = ChapterApplyTransport()
        let service = try make(t, journal: MerchantContentMemoryPendingStorage(), approval: .init())
        XCTAssertFalse(service.permits(.apply(chapterID: 7, message: "hi")))
        XCTAssertFalse(service.permits(.withdraw(applicationID: 3)))
        XCTAssertFalse(MerchantContentWriteApproval().chapterApply)
        XCTAssertFalse(MerchantContentWriteApproval().chapterWithdraw)
        let closed = try make(t, journal: MerchantContentMemoryPendingStorage(), approval: .closed)
        XCTAssertFalse(closed.permits(.apply(chapterID: 7, message: "hi")))
        XCTAssertFalse(closed.permits(.withdraw(applicationID: 3)))
    }
    func testClosedApprovalPerformSendsNothing() async throws {
        let t = ChapterApplyTransport(); t.queueChapterRead()
        let service = try make(t, journal: MerchantContentMemoryPendingStorage(), approval: .closed)
        let base = try await service.load(.chapters(topicID: 70))
        let before = t.requests.count
        do { _ = try await service.perform(.apply(chapterID: 7, message: ""), baseline: base); XCTFail("must stay closed") }
        catch { XCTAssertEqual(error as? MerchantContentFailure, .disabled) }
        XCTAssertEqual(t.requests.count, before)
        XCTAssertEqual(t.count("chapter-application/apply"), 0)
    }
    func testApprovedApplySendsExactBodyOnceAndReleasesLock() async throws {
        let t = ChapterApplyTransport(), journal = MerchantContentMemoryPendingStorage()
        t.queueChapterRead()
        let service = try make(t, journal: journal, approval: .init(chapterApply: true, chapterWithdraw: false))
        let base = try await service.load(.chapters(topicID: 70))
        XCTAssertTrue(service.permits(.apply(chapterID: 7, message: "hi")))
        XCTAssertFalse(service.permits(.withdraw(applicationID: 3)))
        t.queueChapterRead(); t.ok("{}")
        _ = try await service.perform(.apply(chapterID: 7, message: "  hi  "), baseline: base)
        XCTAssertEqual(t.count("chapter-application/apply"), 1)
        let sent = try XCTUnwrap(t.requests.first { $0.url?.path.hasSuffix("chapter-application/apply") == true })
        let body = try JSONDecoder().decode([String: MerchantContentValue].self, from: XCTUnwrap(sent.httpBody))
        XCTAssertEqual(body, ["chapterId": .integer(7), "message": .string("hi")])
        XCTAssertTrue(try journal.records().isEmpty)
    }
}
#endif
