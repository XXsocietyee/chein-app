import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class FactoryWire: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request); return (Data(#"{"code":200,"msg":"ok"}"#.utf8), 200)
    }
}

@MainActor final class TopicUnlikeFactoryTests: XCTestCase {
    private let base = URL(string: "https://unlike.example/native")!
    private func context(role: String = "player", market: RegionalMarket = .china, epoch: UInt64 = 1) throws -> RuntimeDependencyContext {
        RuntimeDependencyContext(market: market, baseURL: base, role: role,
            session: try PlayExperienceSession(accountID: 4, epoch: epoch, namespace: "synthetic", token: "synthetic-unlike", role: role))
    }
    func testBuiltControllerIsAvailableAndSendsOnlyAfterConfirmation() async throws {
        let ctx = try context(), wire = FactoryWire()
        let controller = try XCTUnwrap(TopicUnlikeFactory.makeController(context: ctx, transport: wire,
            current: { ctx }, onUnauthorized: {}, lifetime: 600))
        XCTAssertTrue(controller.isAvailable)
        let id = try XCTUnwrap(controller.request(topicID: 9))
        XCTAssertTrue(wire.requests.isEmpty)
        await controller.confirm(id)
        XCTAssertEqual(controller.phase, .removed(topicID: 9))
        XCTAssertEqual(wire.requests.count, 1)
    }
    func testNonChinaMarketAndUnsupportedRoleGetNoController() throws {
        let wire = FactoryWire()
        let overseas = try context(market: .unitedStates)
        XCTAssertNil(TopicUnlikeFactory.makeController(context: overseas, transport: wire, current: { overseas }, onUnauthorized: {}, lifetime: 600))
        let merchant = try context(role: "merchant")
        XCTAssertNil(TopicUnlikeFactory.makeController(context: merchant, transport: wire, current: { merchant }, onUnauthorized: {}, lifetime: 600))
    }
    func testInvalidLifetimeGetsNoController() throws {
        let ctx = try context(), wire = FactoryWire()
        XCTAssertNil(TopicUnlikeFactory.makeController(context: ctx, transport: wire, current: { ctx }, onUnauthorized: {}, lifetime: 0))
        XCTAssertNil(TopicUnlikeFactory.makeController(context: ctx, transport: wire, current: { ctx }, onUnauthorized: {}, lifetime: .infinity))
    }
    func testContextChangeMakesControllerUnavailableAndSendsNothing() async throws {
        let ctx = try context(), wire = FactoryWire()
        var live: RuntimeDependencyContext? = ctx
        let controller = try XCTUnwrap(TopicUnlikeFactory.makeController(context: ctx, transport: wire,
            current: { live }, onUnauthorized: {}, lifetime: 600))
        let id = try XCTUnwrap(controller.request(topicID: 9))
        live = try context(epoch: 2)
        XCTAssertFalse(controller.isAvailable)
        await controller.confirm(id)
        XCTAssertTrue(wire.requests.isEmpty)
    }
}
