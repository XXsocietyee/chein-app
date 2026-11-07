#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Drives the ledger order-detail read through the real service with a fake transport.
private actor RedemptionDetailTransport: MerchantBusinessTestTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        let json: String
        if path.hasSuffix("/access/me") {
            json = "{\"code\":200,\"data\":\(MerchantBusinessSyntheticFixtures.access)}"
        } else if path.hasSuffix("/finance/redemption-detail") {
            json = "{\"code\":200,\"data\":\(MerchantBusinessSyntheticFixtures.redemption)}"
        } else {
            json = #"{"code":404,"msg":"missing","data":null}"#
        }
        return (Data(json.utf8), 200)
    }
}

final class MerchantRedemptionDetailReadTransportTests: XCTestCase {
    func testRedemptionDetailReadPostsRecordTypeAndIdAndDecodesRow() async throws {
        let fake = RedemptionDetailTransport()
        let service = try MerchantBusinessService(configuration: .init(baseURL: URL(string: "https://example.com/test")!),
                                                  readTransport: fake, testingMutationTransport: nil)
        let access = try await service.access(token: "synthetic-token")
        let document = try await service.document(.redemption(recordID: "64001"), access: access, token: "synthetic-token")
        let requests = await fake.requests
        XCTAssertEqual(requests.count, 2)
        let detail = try XCTUnwrap(requests.last)
        XCTAssertEqual(detail.httpMethod, "POST")
        XCTAssertEqual(detail.url?.path, "/test/api/merchant/finance/redemption-detail")
        XCTAssertEqual(detail.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        let body = try JSONDecoder().decode(MerchantBusinessValue.self, from: XCTUnwrap(detail.httpBody)).object
        XCTAssertEqual(body?["recordType"], .string("redemption"))
        XCTAssertEqual(body?["recordId"], .string("64001"))
        XCTAssertEqual(document.query, .redemption(recordID: "64001"))
        XCTAssertEqual(document.rows.first?.kind, .redemption)
    }

    func testRedemptionDetailRejectsMismatchedRecordWithoutProducingDocument() async throws {
        let fake = RedemptionDetailTransport()
        let service = try MerchantBusinessService(configuration: .init(baseURL: URL(string: "https://example.com/test")!),
                                                  readTransport: fake, testingMutationTransport: nil)
        let access = try await service.access(token: "synthetic-token")
        do {
            _ = try await service.document(.redemption(recordID: "64002"), access: access, token: "synthetic-token")
            XCTFail("a detail for another record must not become a document")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .malformed)
        }
    }
}
#endif
