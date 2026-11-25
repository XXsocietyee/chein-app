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
    private func service(inbox: Bool = false, writes: Bool = false, paths: Set<String>? = nil) throws -> (IMExpandedService, WiringR6Transport) {
        let transport = WiringR6Transport()
        let service = try IMExpandedService(
            configuration: APIConfiguration(baseURL: URL(string: "https://example.com/prod-api")!),
            transport: transport, approvedMediaOrigins: [], writesEnabled: writes, enabledPaths: paths,
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
        let (service, transport) = try service(inbox: true, writes: true, paths: ["api/im/read"])
        XCTAssertTrue(service.canWriteInboxConversationRead)
        XCTAssertFalse(service.canWriteOrdinaryRead)
        transport.payload = #"{"code":200,"msg":"ok"}"#
        try await service.markInboxConversationRead(conversationID: 12, token: "synthetic-im-token")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/prod-api/api/im/read")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-im-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertEqual(String(decoding: XCTUnwrap(request.httpBody), as: UTF8.self), "conversation_id=12")
        XCTAssertFalse(String(decoding: XCTUnwrap(request.httpBody), as: UTF8.self).contains("read_to"))
        transport.payload = #"{"code":409,"msg":"未读","errorCode":"CONFLICT"}"#
        transport.requests.removeAll()
        do { try await service.markInboxConversationRead(conversationID: 12, token: "synthetic-im-token"); XCTFail() }
        catch let error as MessagingReadFailure {
            XCTAssertEqual(error.code, 409)
            XCTAssertEqual(error.message, "未读")
            XCTAssertEqual(error.errorCode, "CONFLICT")
        }
    }

    func testInboxReadStaysOffWithoutTheWriteSwitchOrThePathGrant() async throws {
        let (noWrite, first) = try service(inbox: true, writes: false, paths: ["api/im/read"])
        let (noPath, second) = try service(inbox: true, writes: true, paths: nil)
        XCTAssertFalse(noWrite.canWriteInboxConversationRead)
        XCTAssertFalse(noPath.canWriteInboxConversationRead)
        do { try await noWrite.markInboxConversationRead(conversationID: 12, token: "synthetic-im-token"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertTrue(first.requests.isEmpty)
        XCTAssertTrue(second.requests.isEmpty)
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
    func testClubSourceIsAPostOnTheSummaryRoute() throws {
        let read = CoopFlowRead.clubSettlementSummary(clubID: 9, personal: false)
        XCTAssertEqual(read.path, "api/club/settlement/summary")
        XCTAssertFalse(read.usesGet)
        XCTAssertFalse(read.expectsArray)
        XCTAssertTrue(read.queryItems.isEmpty)
        XCTAssertEqual(try read.body(), .object(["clubId": .id(9)]))
        XCTAssertEqual(try CoopFlowRead.clubSettlementSummary(clubID: 9, personal: true).body(), .object(["clubId": .id(9), "personal": .bool(true)]))
        XCTAssertThrowsError(try CoopFlowRead.clubSettlementSummary(clubID: 0, personal: false).body())
    }

    func testClubSourceReadSendsPostAndDoesNotWithdraw() async throws {
        let transport = WiringR6Transport()
        transport.payload = #"{"code":200,"data":{"topics":[{"topicId":4,"name":"夜跑","status":"settled","amountStatus":"verified","amountText":"12.00","originalAmountText":"20.00","executedAdjustmentText":"0.00","netAmountText":"12.00","arrivedText":"已到账","paidText":"已打款","lineType":"INITIATOR_MARGIN"}],"isOwner":true}}"#
        let service = CoopFlowService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/")!), transport: transport)
        let session = try CoopFlowSession(accountID: 7, epoch: 1, token: "synthetic-coop-token")
        let value = try await service.read(.clubSettlementSummary(clubID: 9, personal: true), session: session)
        XCTAssertEqual(value["isOwner"].flag, true)
        XCTAssertEqual(value["topics"].rows?.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/club/settlement/summary")
        XCTAssertNil(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.query)
        XCTAssertEqual(request.httpBody, try CoopFlowRead.clubSettlementSummary(clubID: 9, personal: true).body().canonical())
        XCTAssertFalse(transport.requests.contains { $0.url?.path.contains("withdraw") == true })
        let detail = try XCTUnwrap(CoopClubSettlementDetail.resolve(try XCTUnwrap(value["topics"].rows?.first)))
        XCTAssertEqual(detail.topicID, 4)
        XCTAssertEqual(detail.amountLabel, "已入账金额")
        XCTAssertEqual(detail.lineTypeText, "主办分成")
        XCTAssertEqual(detail.amountText, "12.00")
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

        transport.payload = #"{"code":200,"data":{"mode":"public","pageNum":1,"pageSize":20,"total":0,"hasMore":false,"averageRating":null,"eligibility":{"canCreate":false,"reasonCode":"LOGIN_REQUIRED","registrationId":null,"requestedRegistrationId":19},"items":[]}}"#
        _ = try await client.publicReviews(merchantRowId: 73, registrationId: 19, pageNum: 1, token: "synthetic-review-token")
        let list = transport.requests[1]
        XCTAssertEqual(list.httpMethod, "POST")
        XCTAssertEqual(list.url?.path, "/api/merchant/reviews/public")
        XCTAssertEqual(list.value(forHTTPHeaderField: "Authorization"), "synthetic-review-token")
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: XCTUnwrap(list.url), resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query, ["merchantRowId": "73", "registrationId": "19", "pageNum": "1", "pageSize": "20"])

        transport.payload = #"{"code":200,"data":{"reviewId":9,"status":"PENDING_REVIEW","version":0,"replayed":false,"auditTaskId":2}}"#
        let command = try MerchantPublicReviewCreate(merchantRowId: 73, registrationId: 19, rating: 5, content: "Fixture note", requestId: "req-1")
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

    func testPublicHomeRequiresTheRequestedMemberAndReviewsRequireThisOrder() async throws {
        let transport = WiringR6Transport()
        transport.payload = #"{"code":200,"data":{"id":73,"memberId":99}}"#
        let client = try client(enabled: true, transport: transport)
        do { _ = try await client.publicHome(memberId: 41); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .malformed) }
        transport.payload = #"{"code":200,"data":{"id":73}}"#
        do { _ = try await client.publicHome(memberId: 41); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .malformed) }
        transport.payload = #"{"code":200,"data":{"mode":"public","pageNum":1,"pageSize":20,"total":0,"hasMore":false,"eligibility":{"canCreate":false,"reasonCode":"LOGIN_REQUIRED","registrationId":null,"requestedRegistrationId":18},"items":[]}}"#
        do { _ = try await client.publicReviews(merchantRowId: 73, registrationId: 19, pageNum: 1, token: "synthetic-review-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .malformed) }
    }

    func testCreateReviewRefusalIsRejectedAndAlwaysSendsAnEmptyImageList() async throws {
        let transport = WiringR6Transport()
        let client = try client(enabled: true, transport: transport)
        let command = try MerchantPublicReviewCreate(merchantRowId: 73, registrationId: 19, rating: 5, content: "Fixture note", requestId: "req-1")
        transport.status = 403
        transport.payload = #"{"code":403,"msg":"无权评价"}"#
        do { _ = try await client.createReview(command, token: "synthetic-review-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .rejected(403, "无权评价")) }
        transport.status = 409
        transport.payload = #"{"code":409,"msg":"你已评价过该订单"}"#
        do { _ = try await client.createReview(command, token: "synthetic-review-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .rejected(409, "你已评价过该订单")) }
        transport.status = 409
        transport.payload = #"{"code":409,"msg":"请稍后"}"#
        do { _ = try await client.createReview(command, token: "synthetic-review-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .malformed) }
        transport.status = 500
        transport.payload = #"{"code":500,"msg":"down"}"#
        do { _ = try await client.createReview(command, token: "synthetic-review-token"); XCTFail() }
        catch { XCTAssertEqual(error as? MerchantPublicReviewHookFailure, .unavailable) }
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(transport.requests.last?.httpBody)) as? [String: Any]
        XCTAssertEqual(body?["imageUrls"] as? [String], [])
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
        await InvoiceLaunchTestSupport.expect(.notFound) {
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
        let fields = TicketSourceRegistrationFields.payload(topicID: 8, link: link)
        XCTAssertEqual(fields["sourceClubId"] as? Int, 42)
        XCTAssertEqual(fields["sourceChannelCode"] as? String, "EAST")
        XCTAssertTrue(TicketSourceRegistrationFields.payload(topicID: 9, link: link).isEmpty)
        XCTAssertNil(ClubShareLink.club(id: 7)?.httpsURL())
    }

    func testParserKeepsClubFactsWhenTheCodeIsAbsent() {
        let bare = TopicClubShareLink(topicID: 8, sourceClubId: 42, clubCode: nil)
        XCTAssertEqual(TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42"), bare)
        XCTAssertEqual(TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42&clubCode="), bare)
        let extra = TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42&clubCode=EAST&extra=1")
        XCTAssertEqual(extra, TopicClubShareLink(topicID: 8, sourceClubId: 42, clubCode: "EAST"))
    }

    func testParserRejectsIncompleteOrNonCanonicalLinks() {
        XCTAssertEqual(
            TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42"),
            TopicClubShareLink(topicID: 8, sourceClubId: 42, clubCode: nil)
        )
        XCTAssertEqual(
            TopicClubShareLinkParser.parse("pages/topic/index/index?topicId=8&sourceClubId=42&sourceChannelCode=EAST&extra=1")?.clubCode,
            "EAST"
        )
        XCTAssertEqual(
            TopicClubShareLinkParser.parse("pages/topic/index/index?id=8&sourceClubId=42&clubCode=")?.clubCode,
            nil
        )
        for raw in [
            "pages/topic/index/index?id=8",
            "pages/topic/index/index?id=08&sourceClubId=42&clubCode=EAST",
            "pages/topic/index/index?id=8&sourceClubId=0&clubCode=EAST",
            "pages/topic/index/index?id=8&clubCode=EAST",
            "pages/topic/detail/index?id=8&sourceClubId=42&clubCode=EAST",
            "http://www.chengyinhub.com/pages/topic/index/index?id=8&sourceClubId=42&clubCode=EAST",
            "pages/topic/index/index?id=8&sourceClubId=42&clubCode=\(String(repeating: "A", count: 65))"
        ] {
            XCTAssertNil(TopicClubShareLinkParser.parse(raw), raw)
        }
    }
}
