import XCTest
@testable import Questify

/// Home and discovery reads on the shipped player path: `reviewedDeployment` + `makeComposition`.
@MainActor final class K40HomeDiscoveryCompositionTests: XCTestCase {
    static let base = "https://k40-home.example.test"

    final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let path = request.url?.path ?? ""
            let body: String
            if path.hasSuffix("/api/template/info") {
                body = #"{"code":200,"data":{"id":8,"title":"Walk"}}"#
            } else if path.hasSuffix("/api/template/list") {
                body = #"{"code":200,"data":[{"id":8,"title":"Walk"}]}"#
            } else if path.hasSuffix("/api/template/homeData") {
                body = #"{"code":200,"data":{}}"#
            } else {
                body = #"{"code":200,"data":{}}"#
            }
            return (Data(body.utf8), 200)
        }
    }

    private func release(_ wire: Wire, reads: Set<ReviewedAppDeployment.ReadGrant>? = nil) throws -> AppCompositionRoot {
        let suite = "k40-home-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "k40-home-" + UUID().uuidString.lowercased())
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: build, reads: reads ?? [.homeAndSearch, .publicMapLayers, .publicTopicTemplateCatalogAndDetail])
        XCTAssertTrue(deployment.productionGatesEnabled)
        XCTAssertTrue(deployment.reads.contains(.homeAndSearch) || reads != nil)
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { wire })
    }

    func testReviewedDeploymentAdmitsPublicPlayTemplateReads() async throws {
        let wire = Wire()
        let session = try release(wire).makeSession()
        await session.bootstrap()
        let before = wire.requests.count
        let detail = try await session.discoveryPlayTemplate(id: 8)
        let rows = try await session.discoveryPlayTemplates(keyword: "walk", packType: nil)
        let home = try await session.discoveryTemplateHome()
        XCTAssertEqual(detail.id, 8)
        XCTAssertEqual(rows.map(\.id), [8])
        XCTAssertTrue(home.isEmpty)
        let sent = wire.requests.dropFirst(before)
        XCTAssertEqual(sent.map { $0.url?.path }, ["/api/template/info", "/api/template/list", "/api/template/homeData"])
        XCTAssertTrue(sent.allSatisfy { $0.httpMethod == "POST" && $0.value(forHTTPHeaderField: "Authorization") == nil })
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        let myinfo = try AuthRequestBuilder.makeFormRequest(url: baseURL.appendingPathComponent("api/template/myinfo"),
            fields: ["id": "8"], token: nil, boundary: "k40-home-boundary")
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(myinfo, baseURL: baseURL))
        let scoped = try AuthRequestBuilder.makeFormRequest(url: baseURL.appendingPathComponent("api/template/info"),
            fields: ["id": "8", "scope": "my"], token: nil, boundary: "k40-home-boundary")
        XCTAssertFalse(PublicPlayTemplateReadRoute.accepts(scoped, baseURL: baseURL))
    }

    func testPublicTopicGrantAloneStillBlocksPlayTemplateReads() async throws {
        let wire = Wire()
        let session = try release(wire, reads: [.publicTopicTemplateCatalogAndDetail]).makeSession()
        await session.bootstrap()
        let before = wire.requests.count
        do {
            _ = try await session.discoveryPlayTemplate(id: 8)
            XCTFail("template info must stay closed without homeAndSearch")
        } catch {
            XCTAssertTrue(error is CancellationError || error as? APIError == .notConfigured, "\(error)")
        }
        XCTAssertEqual(wire.requests.count, before)
    }
}
