#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// pages/club/customers/index search + filter chips: the request carries {clubId, filter, keyword}
/// exactly as the mini-program's POST /api/club/crm/customers/list, and the empty list presentation
/// is distinguishable. Fake transport only; no network.
final class ClubCustomerSearchFilterTests: XCTestCase {
    private final class Transport: ClubGovernanceOfflineTransport {
        var requests: [URLRequest] = []
        var customersStatus = 200
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let path = request.url!.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path == "api/userInfo" { return (Data(#"{"code":200,"appUser":{"id":701,"role":"player"}}"#.utf8), 200) }
            if path == ClubGovernanceRead.customers.path && customersStatus != 200 { return (Data(), customersStatus) }
            var value = ClubGovernanceValue.null
            if let read = ClubGovernanceRead.allCases.first(where: { $0.path == path }) { value = ClubGovernanceFixtures.value(read) }
            let body = ClubGovernanceValue.object(["code": .integer(200), "data": value, "msg": .string("ok")])
            return (try JSONEncoder().encode(body), 200)
        }
    }
    private func service(_ transport: Transport) throws -> ClubGovernanceService {
        let config = try APIConfiguration(baseURL: URL(string: "https://example.com/")!)
        return ClubGovernanceService(configuration: config, transport: transport)
    }
    private func session() throws -> ClubGovernanceSession { try .init(accountID: 701, epoch: 1, token: "synthetic-token") }

    func testFilterAndKeywordAreSentExactlyOnce() async throws {
        let transport = Transport()
        _ = try await service(transport).read(.customers, scope: .init(clubID: 81),
            options: ["filter": .string("repeat"), "keyword": .string("ada")], session: session(), check: {})
        let lists = transport.requests.filter { $0.url?.path.hasSuffix("api/club/crm/customers/list") == true }
        XCTAssertEqual(lists.count, 1)
        let body = try JSONDecoder().decode([String: ClubGovernanceValue].self, from: XCTUnwrap(lists[0].httpBody))
        XCTAssertEqual(body["clubId"], .integer(81))
        XCTAssertEqual(body["filter"], .string("repeat"))
        XCTAssertEqual(body["keyword"], .string("ada"))
    }

    func testDefaultQueryIsAllWithEmptyKeyword() async throws {
        let transport = Transport()
        _ = try await service(transport).read(.customers, scope: .init(clubID: 81), session: session(), check: {})
        let list = try XCTUnwrap(transport.requests.last(where: { $0.url?.path.hasSuffix("api/club/crm/customers/list") == true }))
        let body = try JSONDecoder().decode([String: ClubGovernanceValue].self, from: XCTUnwrap(list.httpBody))
        XCTAssertEqual(body["filter"], .string("all"))
        XCTAssertEqual(body["keyword"], .string(""))
    }

    func testUnknownFilterIsRejectedBeforeAnyRequest() async throws {
        let transport = Transport()
        do {
            _ = try await service(transport).read(.customers, scope: .init(clubID: 81),
                options: ["filter": .string("bogus")], session: session(), check: {})
            XCTFail("An unknown chip must not reach the server")
        } catch { XCTAssertEqual(error as? ClubGovernanceFailure, .invalidRequest) }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testServerFailureSurfacesAsErrorNotEmptyList() async throws {
        let transport = Transport()
        transport.customersStatus = 503
        do {
            _ = try await service(transport).read(.customers, scope: .init(clubID: 81), session: session(), check: {})
            XCTFail("A 503 must not become an empty customer list")
        } catch { /* any thrown error is the honest outcome */ }
    }

    func testEmptyItemsPresentAsEmptyList() throws {
        let value = ClubGovernanceValue.object(["total": .integer(0), "monthNew": .integer(0), "items": .array([])])
        let list = try ClubOpsCustomerListPresentation(value: value)
        XCTAssertTrue(list.rows.isEmpty)
        XCTAssertEqual(list.total, 0)
    }

    func testForbiddenReadMapsToPermissionDeniedCopyWithoutRetry() throws {
        let copy = try XCTUnwrap(ClubOpsFailureCopy(operation: .customers, failure: .forbidden))
        XCTAssertNil(copy.retryKey)
        XCTAssertEqual(copy.titleKey, "clubOps.customers.forbidden")
        let failed = try XCTUnwrap(ClubOpsFailureCopy(operation: .customers, failure: .invalidRequest))
        XCTAssertNotNil(failed.retryKey)
    }
}
#endif
