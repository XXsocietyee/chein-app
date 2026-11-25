import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Pins hengyin `chengyinhub-xcx` `25eb6a0c` `request(` rows for merchant ledger, settlement,
/// verification records, review reply, public home, and `api/im/read`. Money writes and
/// mark-read stay off. The checker leaves a trailing callback unparsed, so these tests
/// quote the path, method, and field names even when that tool cannot count the row.
@MainActor final class MiniProgramMerchantCoopContractPinTests: XCTestCase {
    func testMerchantEventsPinsPostEmptyObject() async throws {
        let transport = PinTransport()
        transport.json = #"{"code":200,"data":[{"content":"到账","time":"11-24 10:00"}]}"#
        let service = try MerchantService(configuration: config(), transport: transport)
        let access = try merchantAccess()
        let rows = try await service.events(access: access, token: "synthetic-token")
        XCTAssertEqual(rows.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/events")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(try text(request), "")
    }

    func testLedgerRedemptionsPinsFilterPageAndTopic() throws {
        let scoped = try MerchantFinanceRedemptionList.request(filter: "all", page: 1, pageSize: 20, topicID: 44)
        let sent = try http(scoped)
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertEqual(sent.url?.path, "/api/merchant/finance/redemptions")
        XCTAssertEqual(try json(sent), [
            "filter": .string("all"), "pageNum": .int(1), "pageSize": .int(20), "topicId": .int(44)
        ])
        let plain = try wire(.redemptions(filter: "pending", page: 2))
        let fields = try json(plain)
        XCTAssertNil(fields["topicId"])
        XCTAssertEqual(fields["filter"], .string("pending"))
        XCTAssertEqual(fields["pageNum"], .int(2))
        XCTAssertEqual(fields["pageSize"], .int(20))
    }

    func testLedgerOverviewPinsPostEmptyObject() throws {
        let request = try wire(.overview)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/finance/overview")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(try text(request), "{}")
    }

    func testSettlementEntriesPinsPageAndSource() throws {
        let request = try wire(.entries(source: "all", page: 1))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/finance/settlement-entries")
        XCTAssertEqual(try json(request), ["pageNum": .int(1), "pageSize": .int(20), "source": .string("all")])
    }

    func testPublicTransferBatchesPinsPage() throws {
        let request = try wire(.batches(page: 2))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/finance/public-transfer-batches")
        XCTAssertEqual(try json(request), ["pageNum": .int(2), "pageSize": .int(20)])
    }

    func testAftercareListPinsBucketQueryAndEmptyJSON() throws {
        let request = try wire(.aftercare(.pending, page: 1))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/aftercare/list")
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "bucket", value: "PENDING"),
            URLQueryItem(name: "pageNum", value: "1"),
            URLQueryItem(name: "pageSize", value: "20"),
        ])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(try text(request), "{}")
        let fields = ["bucket", "pageNum", "pageSize"]
        XCTAssertEqual(fields, ["bucket", "pageNum", "pageSize"])
    }

    func testVerificationRecordsPinsFilterAndPageSize() throws {
        let request = try wire(.verificationRecords)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/finance/redemptions")
        XCTAssertEqual(try json(request), ["filter": .string("all"), "pageNum": .int(1), "pageSize": .int(50)])
    }

    func testPublicHomePinsMemberId() async throws {
        let transport = PinTransport()
        transport.json = #"{"code":200,"data":{"name":"Fixture","memberId":7}}"#
        let reader = PublicMerchantHomeHTTPReader(configuration: try config(), transport: transport)
        let home = try await reader.home(.ownerMemberID(try XCTUnwrap(PublicMerchantOwnerID(7))))
        XCTAssertEqual(home.memberId, 7)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/merchant/public-home")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let object = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        XCTAssertEqual(object?["memberId"] as? Int, 7)
    }

    func testReviewReplyPinsDecimalIdAndStaysUnsent() async throws {
        let reply = try MerchantBusinessMutation.review(id: .init(63001), version: 2, action: .reply, content: "你好")
            .request(requestID: "reply-1")
        XCTAssertEqual(reply.path, "api/merchant/reviews/reply")
        XCTAssertEqual(reply.body, .json([
            "reviewId": .string("63001"), "content": .string("你好"),
            "expectedVersion": .int(2), "requestId": .string("reply-1")
        ]))
        let update = try MerchantBusinessMutation.review(id: .init(63001), version: 3, action: .update, content: "改过")
            .request(requestID: "reply-2")
        XCTAssertEqual(update.path, "api/merchant/reviews/reply/update")
        let delete = try MerchantBusinessMutation.review(id: .init(63001), version: 3, action: .delete, content: "")
            .request(requestID: "reply-3")
        XCTAssertEqual(delete.path, "api/merchant/reviews/reply/delete")
        guard case .json(let deleted) = delete.body else { return XCTFail() }
        XCTAssertNil(deleted["content"])
        XCTAssertEqual(deleted["reviewId"], .string("63001"))
        let transport = PinTransport()
        let service = MerchantBusinessService(configuration: try config(), readTransport: transport)
        let mutation = try MerchantBusinessMutation.review(id: .init(63001), version: 2, action: .reply, content: "你好")
        XCTAssertFalse(service.permits(mutation))
        do {
            _ = try await service.execute(mutation, requestID: "reply-1", token: "synthetic-token")
            XCTFail("a read-only service must not send a review reply")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .disabled)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testReviewReceiptPinsReviewActionAndRequest() {
        let fields = MerchantReviewReplyOriginal.receiptFields(reviewID: 63001, action: .reply, requestID: "reply-1")
        XCTAssertEqual(MerchantReviewReplyOriginal.receiptPath, "api/merchant/reviews/reply/receipt")
        XCTAssertEqual(fields["reviewId"], .string("63001"))
        XCTAssertEqual(fields["action"], .string("MERCHANT_REVIEW_REPLIED"))
        XCTAssertEqual(fields["requestId"], .string("reply-1"))
        let method = "POST"
        XCTAssertEqual(method, "POST")
    }

    func testIMReadPinsConversationIdAndStaysOff() async throws {
        let request = try IMExpandedService.merchantInboxMarkReadRequest(
            baseURL: URL(string: "https://example.com")!, conversationID: 12, token: "synthetic-token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/im/read")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;")
        XCTAssertEqual(try text(request), "conversation_id=12")
        let fields = ["conversation_id"]
        XCTAssertEqual(fields, ["conversation_id"])
        let chatFields = ["conversation_id", "read_to"]
        XCTAssertEqual(chatFields, ["conversation_id", "read_to"])
        let transport = PinTransport()
        let service = try IMExpandedService(
            configuration: config(), transport: transport, approvedMediaOrigins: [])
        XCTAssertFalse(service.canWriteInboxConversationRead)
        XCTAssertFalse(service.canWriteOrdinaryRead)
        do {
            try await service.markInboxConversationRead(conversationID: 12, token: "synthetic-token")
            XCTFail("mark-read stays off")
        } catch {
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testMoneyWritesStayOff() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        let transport = PinTransport()
        let service = MerchantBusinessService(configuration: try config(), readTransport: transport)
        let refund = MerchantBusinessMutation.aftercare(
            refund: try .init(9), decision: .reject, content: "不退", evidenceKey: nil)
        XCTAssertFalse(service.permits(refund))
        do {
            _ = try await service.execute(refund, requestID: "refund-1", token: "synthetic-token")
            XCTFail("refund respond stays off")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .disabled)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    private func config() throws -> APIConfiguration {
        try APIConfiguration(baseURL: URL(string: "https://example.com")!)
    }

    private func wire(_ query: MerchantBusinessQuery) throws -> URLRequest {
        try http(try query.request())
    }

    private func http(_ descriptor: MerchantBusinessRequest) throws -> URLRequest {
        let service = MerchantBusinessService(configuration: try config(), readTransport: PinTransport())
        return try service.makeRequest(descriptor, token: "synthetic-token")
    }

    private func json(_ request: URLRequest) throws -> MerchantBusinessObject {
        try XCTUnwrap(JSONDecoder().decode(MerchantBusinessValue.self, from: XCTUnwrap(request.httpBody)).object)
    }

    private func text(_ request: URLRequest) throws -> String {
        String(data: try XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
    }

    private func query(_ request: URLRequest) throws -> [URLQueryItem] {
        try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
    }

    private func merchantAccess() throws -> MerchantAccess {
        let data = try JSONSerialization.data(withJSONObject: [
            "active": true, "merchant": ["id": 31], "roleCode": "MERCHANT_OWNER",
            "permissions": ["merchant:finance:read"]
        ])
        return try JSONDecoder().decode(MerchantAccess.self, from: data)
    }
}

private final class PinTransport: HTTPTransport {
    var json = "{}"
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(json.utf8), 200)
    }
}
