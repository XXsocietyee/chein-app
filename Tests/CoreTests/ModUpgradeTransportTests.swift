import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class ModUpgradeTransportTests: XCTestCase {
    private let fixtureHash = String(repeating: "a", count: 64)
    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/native")!, role: "merchant",
              session: try .init(accountID: 7, epoch: 1, namespace: "synthetic-upgrade-wire", token: "synthetic-session", role: "merchant"))
    }
    private var source: ModInstallationIdentity { .init(licenseId: "old-license", moduleId: "module", releaseId: "old", contentHash: fixtureHash, termsHash: fixtureHash) }
    private final class Transport: HTTPTransport {
        var calls: [URLRequest] = []
        var response: Data = Data()
        var status = 200
        var afterDispatch: (() -> Void)?
        func send(_ request: URLRequest) async throws -> (Data, Int) { calls.append(request); afterDispatch?(); return (response, status) }
    }
    private func response() throws -> Data {
        let page = ModUpgradeVersionPage(schema: "mod-upgrade-versions-v1", source: source, sourceTitle: "Original", candidates: [], nextCursor: "offer-50")
        return try JSONSerialization.data(withJSONObject: ["code": 200, "data": JSONSerialization.jsonObject(with: JSONEncoder().encode(page))])
    }
    func testRequestUsesExactReadRouteAndCursorWithoutBody() async throws {
        let context = try context(), transport = Transport(); transport.response = try response()
        let approval = try ModUpgradeApproval(context: context, expiresAt: Date().addingTimeInterval(600), readApprovalReference: "reviewed-read")
        let service = try ModUpgradeService(lease: .init(context: context, current: { context }), approval: approval, currentApproval: { approval }, transport: transport)
        _ = try await service.versions(source: source, before: "offer-51")
        let request = try XCTUnwrap(transport.calls.first)
        XCTAssertEqual(request.httpMethod, "GET"); XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.url?.path, "/native/api/mod-upgrade/licenses/old-license/versions")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "before", value: "offer-51")])
        XCTAssertFalse(service.canStage)
    }
    func testApprovalReplacementRejectsLateResponseIrrevocably() async throws {
        let context = try context(), transport = Transport(); transport.response = try response()
        let approval = try ModUpgradeApproval(context: context, expiresAt: Date().addingTimeInterval(600), readApprovalReference: "reviewed-read")
        var current: ModUpgradeApproval? = approval
        let service = try ModUpgradeService(lease: .init(context: context, current: { context }), approval: approval, currentApproval: { current }, transport: transport)
        transport.afterDispatch = { current = nil }
        do { _ = try await service.versions(source: source, before: nil); XCTFail("Late response accepted") } catch { }
        XCTAssertFalse(service.isCurrent); current = approval; XCTAssertFalse(service.isCurrent)
        XCTAssertEqual(transport.calls.count, 1)
    }
    func testUnauthorizedExpiresOnlyCapturedCurrentSession() async throws {
        let context = try context(), transport = Transport(); transport.status = 401; transport.response = Data("{\"code\":401,\"msg\":\"expired\"}".utf8)
        let approval = try ModUpgradeApproval(context: context, expiresAt: Date().addingTimeInterval(600), readApprovalReference: "reviewed-read")
        var expired = 0
        let service = try ModUpgradeService(lease: .init(context: context, current: { context }), approval: approval, currentApproval: { approval }, transport: transport,
            onUnauthorized: { captured in XCTAssertTrue(ContentDraftContextFence.matches(captured, context)); expired += 1 })
        do { _ = try await service.versions(source: source, before: nil); XCTFail("Unauthorized accepted") } catch { }
        XCTAssertEqual(expired, 1); XCTAssertFalse(service.isCurrent)
    }
}
