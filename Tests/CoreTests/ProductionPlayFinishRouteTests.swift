import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class ProductionPlayFinishRouteTests: XCTestCase {
    func testReaderPostsActivityList() async throws {
        let transport = FinishWire()
        let config = try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com/fixture/")))
        let service = PlayExperienceService(configuration: config, transport: transport, enabled: [.reads])
        let reader = ProductionPlayFinishRouteReader(service: service, token: { "player-token" })
        let origin = try XCTUnwrap(PlayFinishOrigin(latitude: 31.2, longitude: 121.5))
        let rows = try await reader.rows(origin: origin)
        XCTAssertEqual(transport.paths, ["api/activity/list"])
        XCTAssertEqual(rows.map(\.id), [9])
        let request = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(request.httpMethod, "POST")
        let text = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("is_my"))
        XCTAssertTrue(text.contains("sort_type"))
    }

    /// `docs/release/e2e/20261113b/requests.batch1.log` line 15. Empty page, not a filled card.
    func testCapturedEmptyActivityListDecodesNoRows() async throws {
        let captured = #"{"msg":"操作成功","code":200,"data":{"total":0,"rows":[],"code":200,"msg":"查询成功"}}"#
        let transport = FinishWire(body: captured)
        let config = try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com/fixture/")))
        let service = PlayExperienceService(configuration: config, transport: transport, enabled: [.reads])
        let reader = ProductionPlayFinishRouteReader(service: service, token: { "player-token" })
        let origin = try XCTUnwrap(PlayFinishOrigin(latitude: 31.2, longitude: 121.5))
        let rows = try await reader.rows(origin: origin)
        XCTAssertTrue(rows.isEmpty)
        XCTAssertEqual(transport.requests.last?.httpMethod, "POST")
        XCTAssertEqual(transport.paths, ["api/activity/list"])
    }

    func testFlagOffShowsNoCard() async {
        let coordinator = PlayFinishRouteRecommendationCoordinator(featureEnabled: false, reader: nil, currentActivityID: 41, currentTopicID: nil)
        await coordinator.show(origin: PlayFinishOrigin(latitude: 31.2, longitude: 121.5))
        XCTAssertNil(coordinator.card)
    }
}

private final class FinishWire: HTTPTransport {
    var paths: [String] = []
    var requests: [URLRequest] = []
    var body: String
    init(body: String = #"{"code":200,"data":{"rows":[{"id":9,"name":"Next","endDate":"2099-01-01 00:00:00"}]}}"#) {
        self.body = body
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        paths.append(request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? "")
        return (Data(body.utf8), 200)
    }
}
