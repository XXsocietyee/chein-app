import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class WiringR6Transport: HTTPTransport {
    var requests: [URLRequest] = []
    var payload = #"{"code":200,"msg":"ok"}"#
    var status = 200
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(payload.utf8), status)
    }
}

@MainActor final class WiringR6IMReadTests: XCTestCase {
    private func service(inbox: Bool = false, paths: Set<String>? = nil) throws -> (IMExpandedService, WiringR6Transport) {
        let transport = WiringR6Transport()
        let service = try IMExpandedService(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.com/prod-api")!),
            transport: transport, approvedMediaOrigins: [], enabledPaths: paths,
            inboxConversationReadEnabled: inbox)
        return (service, transport)
    }

    func testInboxReadStaysOffAndDoesNotOpenOrdinaryRead() async throws {
        let (service, transport) = try service()
        XCTAssertFalse(service.canWriteInboxConversationRead)
        XCTAssertFalse(service.canWriteOrdinaryRead)
        do { try await service.markInboxConversationRead(conversationID: 12, token: "synthetic-im-token"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testInboxReadHookPostsOnlyConversationId() async throws {
        let (service, transport) = try service(inbox: true)
        XCTAssertTrue(service.canWriteInboxConversationRead)
        XCTAssertFalse(service.canWriteOrdinaryRead)
        try await service.markInboxConversationRead(conversationID: 12, token: "synthetic-im-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/prod-api/api/im/read")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-im-token")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        XCTAssertEqual(body?["conversation_id"] as? Int, 12)
        XCTAssertEqual(body?.count, 1)
    }

    func testInboxReadRefusesWhenThePathGrantOmitsIt() async throws {
        let (service, transport) = try service(inbox: true, paths: ["api/im/send"])
        XCTAssertFalse(service.canWriteInboxConversationRead)
        do { try await service.markInboxConversationRead(conversationID: 12, token: "synthetic-im-token"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}

@MainActor final class WiringR6ClubSettlementTests: XCTestCase {
    func testClubSourceIsAGetOnTheSummaryRoute() throws {
        let read = CoopFlowRead.clubSettlementSummary(clubID: 9)
        XCTAssertEqual(read.path, "api/club/settlement/summary")
        XCTAssertTrue(read.usesGet)
        XCTAssertFalse(read.expectsArray)
        XCTAssertEqual(read.queryItems, [URLQueryItem(name: "clubId", value: "9")])
        XCTAssertEqual(try read.body(), .object([:]))
        XCTAssertThrowsError(try CoopFlowRead.clubSettlementSummary(clubID: 0).body())
    }

    func testClubSourceReadSendsGetAndDoesNotWithdraw() async throws {
        let transport = WiringR6Transport()
        transport.payload = #"{"code":200,"data":{"topics":[],"isOwner":true,"settledAmountText":null}}"#
        let service = CoopFlowService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/")!), transport: transport)
        let session = try CoopFlowSession(accountID: 7, epoch: 1, token: "synthetic-coop-token")
        let value = try await service.read(.clubSettlementSummary(clubID: 9), session: session)
        XCTAssertEqual(value["isOwner"].flag, true)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.url?.path, "/api/club/settlement/summary")
        XCTAssertEqual(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.query, "clubId=9")
        XCTAssertFalse(transport.requests.contains { $0.url?.path.contains("withdraw") == true })
    }
}

@MainActor final class WiringR6MerchantReviewTests: XCTestCase {
    private func client(enabled: Bool, transport: WiringR6Transport) throws -> MerchantPublicReviewClient {
        MerchantPublicReviewClient(
            configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/")!),
            transport: transport, gate: MerchantPublicReviewGate(enabled: enabled))
    }

    func testGateOffSendsNothing() async throws {
        let transport = WiringR6Transport()
        let client = try client(enabled: false, transport: transport)
        let command = try MerchantPublicReviewCreate(merchantRowId: 73, registrationId: 19, rating: 5, content: "Fixture note", requestId: "req-1")
        do { _ = try await client.publicHome(memberId: 41); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .disabled) }
        do { _ = try await client.publicReviews(merchantRowId: 73, registrationId: 19, pageNum: 1, token: "synthetic-review-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .disabled) }
        do { _ = try await client.createReview(command, token: "synthetic-review-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .disabled) }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertFalse(MerchantPublicReviewGate.off.enabled)
    }

    func testEnabledHookUsesTheThreeLiveMerchantRoutes() async throws {
        let transport = WiringR6Transport()
        transport.payload = #"{"code":200,"data":{"id":73,"memberId":41}}"#
        let client = try client(enabled: true, transport: transport)
        let home = try await client.publicHome(memberId: 41)
        XCTAssertEqual(home.merchantRowId, 73)
        XCTAssertNotEqual(home.merchantRowId, 41)
        let homeRequest = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(homeRequest.httpMethod, "POST")
        XCTAssertEqual(homeRequest.url?.path, "/api/merchant/public-home")
        XCTAssertNil(homeRequest.value(forHTTPHeaderField: "Authorization"))
        let homeBody = try JSONSerialization.jsonObject(with: XCTUnwrap(homeRequest.httpBody)) as? [String: Any]
        XCTAssertEqual(homeBody?["memberId"] as? Int, 41)
        XCTAssertEqual(homeBody?.count, 1)

        transport.payload = #"{"code":200,"data":{"mode":"public","pageNum":1,"pageSize":20,"total":0,"hasMore":false,"averageRating":null,"eligibility":{"canCreate":false,"reasonCode":"LOGIN_REQUIRED","registrationId":null},"items":[]}}"#
        _ = try await client.publicReviews(merchantRowId: 73, registrationId: 19, pageNum: 1, token: "synthetic-review-token")
        let list = transport.requests[1]
        XCTAssertEqual(list.httpMethod, "POST")
        XCTAssertEqual(list.url?.path, "/api/merchant/reviews/public")
        XCTAssertEqual(list.value(forHTTPHeaderField: "Authorization"), "synthetic-review-token")
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: XCTUnwrap(list.url), resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query, ["merchantRowId": "73", "registrationId": "19", "pageNum": "1", "pageSize": "20"])

        transport.payload = #"{"code":200,"data":{"reviewId":9,"status":"PENDING_REVIEW","version":0,"replayed":false,"auditTaskId":2}}"#
        let command = try MerchantPublicReviewCreate(merchantRowId: 73, registrationId: 19, rating: 5, content: "Fixture note", imageUrls: [], requestId: "req-1")
        let receipt = try await client.createReview(command, token: "synthetic-review-token")
        XCTAssertEqual(receipt.reviewId, 9)
        let create = transport.requests[2]
        XCTAssertEqual(create.url?.path, "/api/merchant/reviews/create")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(create.httpBody)) as? [String: Any]
        XCTAssertEqual(Set(body?.keys ?? []), ["merchantRowId", "registrationId", "rating", "content", "imageUrls", "requestId"])
        XCTAssertEqual(body?["imageUrls"] as? [String], [])
        XCTAssertEqual(body?["requestId"] as? String, "req-1")
        XCTAssertFalse(transport.requests.contains { $0.url?.path.contains("free-explore/bundle/review") == true })
    }
}

@MainActor final class WiringR6InvoiceNotFoundTests: XCTestCase {
    func testOriginalRequestNotFoundIsNotAnUnknownTransportResult() async throws {
        let h = try InvoiceLaunchTestSupport.Harness()
        h.originalReceipts = true
        h.wire.responses = [try InvoiceLaunchTestSupport.failure("INVOICE_NOT_FOUND")]
        await InvoiceLaunchTestSupport.expect(.notFound) {
            _ = try await h.service.originalApplication(requestId: "original")
        }
        h.wire.failNext = true
        await InvoiceLaunchTestSupport.expect(.unavailable) {
            _ = try await h.service.originalApplication(requestId: "original")
        }
        h.wire.responses = [try InvoiceLaunchTestSupport.failure("INVOICE_NOT_FOUND")]
        await InvoiceLaunchTestSupport.expect(.outcomeUnknown) {
            _ = try await h.service.titleReceipt(requestId: "original")
        }
    }

    func testRecoveredMissKeepsTheJournalAndIsNotARollback() async throws {
        let h = try InvoiceLaunchTestSupport.Harness()
        h.originalReceipts = true
        let pending = InvoiceLaunchPending(kind: .apply, apply: try h.command(), originalApplicationReceipt: true)
        try h.store.save(pending)
        h.wire.responses = [try InvoiceLaunchTestSupport.failure("INVOICE_NOT_FOUND")]
        await InvoiceLaunchTestSupport.expect(.notFound) { _ = try await h.coordinator().recover() }
        XCTAssertEqual(try h.store.load(), pending)
    }
}

final class WiringR6TopicClubShareLinkTests: XCTestCase {
    func testParserCarriesClubFactsWithoutChoosingAChannelCode() {
        let link = TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42&clubCode=EAST")
        XCTAssertEqual(link, TopicClubShareLink(topicID: 8, sourceClubId: 42, clubCode: "EAST"))
        XCTAssertEqual(TopicClubShareLink.laterRegistrationField, "sourceChannelCode")
        let swapped = TopicClubShareLinkParser.parse("/pages/topic/index/index?clubCode=EAST&id=8&sourceClubId=42")
        XCTAssertEqual(swapped, link)
        let https = TopicClubShareLinkParser.parse("https://www.chengyinhub.com/pages/topic/index/index?id=8&sourceClubId=42&clubCode=EAST")
        XCTAssertEqual(https, link)
        let chein = TopicClubShareLinkParser.parse("chein://mp/pages/topic/index/index?id=8&sourceClubId=42&clubCode=EAST")
        XCTAssertEqual(chein, link)
    }

    func testParserRejectsIncompleteOrNonCanonicalLinks() {
        for raw in [
            "pages/topic/index/index?id=8",
            "pages/topic/index/index?id=8&sourceClubId=42",
            "pages/topic/index/index?id=08&sourceClubId=42&clubCode=EAST",
            "pages/topic/index/index?id=8&sourceClubId=0&clubCode=EAST",
            "pages/topic/index/index?id=8&sourceClubId=42&clubCode=",
            "pages/topic/index/index?id=8&sourceClubId=42&clubCode=EAST&extra=1",
            "pages/topic/detail/index?id=8&sourceClubId=42&clubCode=EAST",
            "http://www.chengyinhub.com/pages/topic/index/index?id=8&sourceClubId=42&clubCode=EAST"
        ] {
            XCTAssertNil(TopicClubShareLinkParser.parse(raw), raw)
        }
    }
}
