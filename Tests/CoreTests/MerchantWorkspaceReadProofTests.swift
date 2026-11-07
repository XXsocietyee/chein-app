import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// "Prove it" tests for the merchant workspace read screens (customers, aftercare list,
/// ledger overview/redemptions, verification records). Each test drives the screen's
/// main read through `MerchantBusinessService.document` with a fake transport and asserts
/// the request path, method, auth header and body, and that a document is produced only
/// when the server envelope reports code 200.
private actor MerchantProofWire: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private let body: Data
    private let status: Int
    init(body: Data, status: Int = 200) { self.body = body; self.status = status }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (body, status)
    }
}

final class MerchantWorkspaceReadProofTests: XCTestCase {
    private func service(_ wire: MerchantProofWire) throws -> MerchantBusinessService {
        try .init(configuration: .init(baseURL: URL(string: "https://example.com/test")!), readTransport: wire)
    }
    private func okEnvelope(_ payload: MerchantBusinessValue) throws -> Data {
        try JSONEncoder().encode(MerchantBusinessValue.object(["code": .int(200), "data": payload]))
    }
    private func ownerAccess() throws -> MerchantBusinessAccess {
        let value = try MerchantBusinessSyntheticFixtures.decode(MerchantBusinessSyntheticFixtures.access)
        return try MerchantBusinessAccess(try XCTUnwrap(value.object))
    }
    private func basicOnlyAccess() throws -> MerchantBusinessAccess {
        try MerchantBusinessAccess([
            "active": .bool(true),
            "merchant": .object(["id": .int(610), "name": .string("Synthetic workshop")]),
            "roleCode": .string("MERCHANT_MANAGER"),
            "permissions": .array([.string("merchant:basic:read")])
        ])
    }

    // pages/merchant/customer/index
    func testCustomerListReadPostsJSONToCrmListAndBuildsRows() async throws {
        let query = MerchantBusinessQuery.customers(.init())
        let wire = MerchantProofWire(body: try okEnvelope(try MerchantBusinessSyntheticFixtures.payload(query)))
        let document = try await service(wire).document(query, access: try ownerAccess(), token: "synthetic-token")
        XCTAssertEqual(document.rows.count, 1)
        let requests = await wire.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/test/api/merchant/crm/customers/list")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let sent = try JSONDecoder().decode(MerchantBusinessValue.self, from: try XCTUnwrap(request.httpBody))
        XCTAssertNotNil(sent.object)
    }

    func testCustomerListServerRejectionProducesNoDocument() async throws {
        let rejected = Data(#"{"code":500,"msg":"Synthetic failure","data":null}"#.utf8)
        let wire = MerchantProofWire(body: rejected)
        do {
            _ = try await service(wire).document(.customers(.init()), access: try ownerAccess(), token: "synthetic-token")
            XCTFail("A rejected envelope must not produce a document")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .rejected(500, "Synthetic failure"))
        }
    }

    func testCustomerListWithoutCrmPermissionNeverReachesTransport() async throws {
        let wire = MerchantProofWire(body: Data("{}".utf8))
        do {
            _ = try await service(wire).document(.customers(.init()), access: try basicOnlyAccess(), token: "synthetic-token")
            XCTFail("Missing merchant:crm:read must fail closed")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .denied)
        }
        let requests = await wire.requests
        XCTAssertTrue(requests.isEmpty)
    }

    // pages/merchant/aftercare/index
    func testAftercareListReadUsesBucketAndPagingQuery() async throws {
        let query = MerchantBusinessQuery.aftercare(.pending, page: 1)
        let wire = MerchantProofWire(body: try okEnvelope(try MerchantBusinessSyntheticFixtures.payload(query)))
        let document = try await service(wire).document(query, access: try ownerAccess(), token: "synthetic-token")
        XCTAssertEqual(document.rows.count, 1)
        XCTAssertEqual(document.total, 1)
        XCTAssertFalse(document.hasMore)
        let requests = await wire.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/test/api/merchant/aftercare/list")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems,
                       [URLQueryItem(name: "bucket", value: "PENDING"),
                        URLQueryItem(name: "pageNum", value: "1"),
                        URLQueryItem(name: "pageSize", value: "20")])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
    }

    // pages/merchant/ledger/index
    func testLedgerOverviewReadHitsFinanceOverviewAndKeepsServerTotals() async throws {
        let wire = MerchantProofWire(body: try okEnvelope(try MerchantBusinessSyntheticFixtures.payload(.overview)))
        let document = try await service(wire).document(.overview, access: try ownerAccess(), token: "synthetic-token")
        XCTAssertFalse(document.summary.isEmpty)
        let requests = await wire.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/test/api/merchant/finance/overview")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
    }

    func testLedgerRedemptionsReadSendsFilterAndNeedsFinancePermission() async throws {
        let query = MerchantBusinessQuery.redemptions(filter: "all", page: 1)
        let wire = MerchantProofWire(body: try okEnvelope(try MerchantBusinessSyntheticFixtures.payload(query)))
        let document = try await service(wire).document(query, access: try ownerAccess(), token: "synthetic-token")
        XCTAssertEqual(document.rows.count, 1)
        let requests = await wire.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/test/api/merchant/finance/redemptions")
        let sent = try JSONDecoder().decode(MerchantBusinessValue.self, from: try XCTUnwrap(request.httpBody))
        XCTAssertEqual(sent.object?["filter"], .string("all"))

        let denied = MerchantProofWire(body: Data("{}".utf8))
        do {
            _ = try await service(denied).document(query, access: try basicOnlyAccess(), token: "synthetic-token")
            XCTFail("Missing merchant:finance:read must fail closed")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .denied)
        }
        let deniedRequests = await denied.requests
        XCTAssertTrue(deniedRequests.isEmpty)
    }

    // pages/merchant/verify-records/index
    func testVerificationRecordsReadPostsMultipartAndBuildsRows() async throws {
        let query = MerchantBusinessQuery.verificationRecords
        let wire = MerchantProofWire(body: try okEnvelope(try MerchantBusinessSyntheticFixtures.payload(query)))
        let document = try await service(wire).document(query, access: try ownerAccess(), token: "synthetic-token")
        XCTAssertEqual(document.rows.count, 1)
        let requests = await wire.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/test/api/merchant/verification-records")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
    }

    func testVerificationRecordsNeedRecordReadPermissionAndHonorServerRejection() async throws {
        let denied = MerchantProofWire(body: Data("{}".utf8))
        do {
            _ = try await service(denied).document(.verificationRecords, access: try basicOnlyAccess(), token: "synthetic-token")
            XCTFail("Missing merchant:verify:record:read must fail closed")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .denied)
        }
        let deniedRequests = await denied.requests
        XCTAssertTrue(deniedRequests.isEmpty)

        let rejected = MerchantProofWire(body: Data(#"{"code":409,"msg":"Synthetic conflict","data":null}"#.utf8))
        do {
            _ = try await service(rejected).document(.verificationRecords, access: try ownerAccess(), token: "synthetic-token")
            XCTFail("A rejected envelope must not produce a document")
        } catch {
            XCTAssertEqual(error as? MerchantBusinessFailure, .rejected(409, "Synthetic conflict"))
        }
    }
}
#endif
