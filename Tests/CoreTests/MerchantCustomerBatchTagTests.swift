import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(QuestifyCore)
@testable import QuestifyCore

private actor BatchTagTransport: MerchantBusinessTestTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"msg":"ok","data":{"updated":2}}"#.utf8), 200)
    }
}

/// Source pages/merchant/customer/index.js submitBatchTag.
final class MerchantCustomerBatchTagTests: XCTestCase {
    func testIssuesMatchSourceRules() {
        XCTAssertEqual(MerchantCustomerBatchTag.issue(selected: 0, name: "VIP"), .noSelection)
        XCTAssertEqual(MerchantCustomerBatchTag.issue(selected: 2, name: "   "), .invalidName)
        XCTAssertEqual(MerchantCustomerBatchTag.issue(selected: 2, name: String(repeating: "x", count: 17)), .invalidName)
        XCTAssertNil(MerchantCustomerBatchTag.issue(selected: 2, name: " " + String(repeating: "x", count: 16) + " "))
        XCTAssertTrue(MerchantCustomerBatchTag.canSelectMore(currentCount: 99))
        XCTAssertFalse(MerchantCustomerBatchTag.canSelectMore(currentCount: 100))
    }

    func testInvalidDraftBuildsNoMutation() throws {
        let ids = [try MerchantCustomerID(61001), try MerchantCustomerID(61002)]
        XCTAssertNil(MerchantCustomerBatchTag.mutation(ids: [], name: "VIP"))
        XCTAssertNil(MerchantCustomerBatchTag.mutation(ids: ids, name: ""))
        XCTAssertNil(MerchantCustomerBatchTag.mutation(ids: [ids[0], ids[0]], name: "VIP"))
    }

    @MainActor func testBatchTagPostsSourceFieldsThroughFakeTransport() async throws {
        let fake = BatchTagTransport()
        let service = try MerchantBusinessService(configuration: .init(baseURL: URL(string: "https://example.com/test")!),
                                                  readTransport: fake, testingMutationTransport: fake)
        let ids = [try MerchantCustomerID(61001), try MerchantCustomerID(61002)]
        let mutation = try XCTUnwrap(MerchantCustomerBatchTag.mutation(ids: ids, name: "  VIP  "))
        _ = try await service.execute(mutation, requestID: "batch-tag-1", token: "synthetic-token")
        let requests = await fake.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.url?.path, "/test/api/merchant/crm/customers/tags/batch")
        XCTAssertNil(request.url?.query)
        let object = try JSONDecoder().decode(MerchantBusinessValue.self, from: XCTUnwrap(request.httpBody)).object
        XCTAssertEqual(object?["customerMemberIds"], .array([.number(61001), .number(61002)]))
        XCTAssertEqual(object?["tagName"], .string("VIP"))
        XCTAssertNil(object?["tagColor"])
        XCTAssertEqual(object?["requestId"], .string("batch-tag-1"))
    }
}
#endif
