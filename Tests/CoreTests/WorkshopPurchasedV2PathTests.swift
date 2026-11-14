import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// The purchased library moved to `api/workshop/v2/purchased/{list,detail}`. No TEST body for these
/// two reads is in the tree, so this only pins the method and path.
@MainActor final class WorkshopPurchasedV2PathTests: XCTestCase {
    func testListAndDetailPostTheV2Paths() async throws {
        let context = try WorkshopOwnedTestData.context()
        let wire = QuietWorkshopWire()
        let lease = ContentDraftSessionLease(context: context, current: { context })
        let grant = try WorkshopPurchasedReadApproval(context: context, expiresAt: .distantFuture)
        let service = WorkshopPurchasedService(
            api: try APIConfiguration(baseURL: context.baseURL),
            transport: wire,
            lease: lease,
            approval: grant,
            currentApproval: { grant }
        )
        let lifetime = WorkshopPurchasedReadLifetime()
        var listFailed = false
        do { _ = try await service.list(before: nil, lifetime: lifetime) } catch { listFailed = true }
        XCTAssertTrue(listFailed)
        let listed = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(listed.httpMethod, "POST")
        XCTAssertTrue(listed.url?.path.hasSuffix("/api/workshop/v2/purchased/list") == true)
        var detailFailed = false
        do { _ = try await service.detail(licenseId: "w18-paid-11", lifetime: lifetime) } catch { detailFailed = true }
        XCTAssertTrue(detailFailed)
        let detailed = try XCTUnwrap(wire.requests.last)
        XCTAssertEqual(detailed.httpMethod, "POST")
        XCTAssertTrue(detailed.url?.path.hasSuffix("/api/workshop/v2/purchased/detail") == true)
        let body = String(data: detailed.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(body, "license_id=w18-paid-11")
        XCTAssertEqual(wire.requests.count, 2)
    }

    func testPurchasedReadsOnTheTestHostAreConcreteV2Children() async throws {
        let context = RuntimeDependencyContext(
            market: .china,
            baseURL: URL(string: "https://8120.example.test/native/")!,
            role: "player",
            session: try .init(accountID: 7, epoch: 1, namespace: "synthetic", token: "synthetic")
        )
        let wire = QuietWorkshopWire()
        let lease = ContentDraftSessionLease(context: context, current: { context })
        let grant = try WorkshopPurchasedReadApproval(context: context, expiresAt: .distantFuture)
        let service = WorkshopPurchasedService(
            api: try APIConfiguration(baseURL: context.baseURL),
            transport: wire,
            lease: lease,
            approval: grant,
            currentApproval: { grant }
        )
        let lifetime = WorkshopPurchasedReadLifetime()
        var listFailed = false
        var detailFailed = false
        do { _ = try await service.list(before: nil, lifetime: lifetime) } catch { listFailed = true }
        do { _ = try await service.detail(licenseId: "w18-paid-11", lifetime: lifetime) } catch { detailFailed = true }
        XCTAssertTrue(listFailed)
        XCTAssertTrue(detailFailed)
        XCTAssertEqual(wire.requests.count, 2)
        guard wire.requests.count == 2 else { return }  // fail, don't trap the runner
        XCTAssertEqual(wire.requests[0].url?.host, "8120.example.test")
        XCTAssertTrue(wire.requests[0].url?.path.hasSuffix("/api/workshop/v2/purchased/list") == true)
        XCTAssertTrue(wire.requests[1].url?.path.hasSuffix("/api/workshop/v2/purchased/detail") == true)
        XCTAssertFalse(wire.requests.contains { request in
            let path = request.url?.path ?? ""
            return path.hasSuffix("/api/workshop/purchased") || path.hasSuffix("/api/workshop/purchased/")
        })
        let production = URLRequest(url: URL(string: "https://www.chengyinhub.com/prod-api/api/workshop/v2/purchased/list")!)
        XCTAssertThrowsError(try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(production)) { error in
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
    }
}

private final class QuietWorkshopWire: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(), 503)
    }
}
