#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Dashboard with the production read grant still off: honest "unavailable" state, no network, then retry works once granted.
@MainActor final class MerchantMarketingGatedDashboardTests: XCTestCase {
    private func make(_ transport: MerchantMarketingFixtureTransport, reads: Bool) throws -> MerchantMarketingCoordinator {
        let scope = try MerchantMarketingScope(namespace: "fixture-cn", accountID: 700, epoch: 1, token: "fixture-token")
        let service = try MerchantMarketingService(
            configuration: APIConfiguration(baseURL: URL(string: "https://merchant-marketing.example")!), transport: transport,
            gates: .init(reads: reads), currentSession: { scope })
        return MerchantMarketingCoordinator(service: service)
    }
    func testGatedReadsShowUnavailableWithoutAnyRequest() async throws {
        let transport = MerchantMarketingFixtureTransport()
        let coordinator = try make(transport, reads: false)
        await coordinator.load(.dashboard)
        XCTAssertEqual(coordinator.failure, .unavailable)
        XCTAssertEqual(coordinator.failure?.key, "merchantMarketing.unavailable")
        XCTAssertNil(coordinator.home)
        XCTAssertFalse(coordinator.busy)
        XCTAssertTrue(transport.requests.isEmpty)
    }
    func testDeniedAccessClearsHomeAndReloadRecovers() async throws {
        let denied = MerchantMarketingFixtureTransport(scenario: "denied")
        let first = try make(denied, reads: true)
        await first.load(.dashboard)
        XCTAssertEqual(first.failure, .denied)
        XCTAssertNil(first.home)
        let ok = MerchantMarketingFixtureTransport()
        let second = try make(ok, reads: true)
        await second.load(.dashboard)
        XCTAssertNil(second.failure)
        XCTAssertNotNil(second.home)
        await second.load(.dashboard)
        XCTAssertNil(second.failure)
        XCTAssertNotNil(second.home)
    }
}
#endif
