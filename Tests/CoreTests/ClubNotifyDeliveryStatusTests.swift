#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// pages/club/notify delivery status, end to end over a fake transport:
/// send (gated by the provider rule) -> campaign -> status read by campaignId -> retry offer.
@MainActor final class ClubNotifyDeliveryStatusTests: XCTestCase {
    private final class Transport: ClubGovernanceOfflineTransport {
        var requests: [URLRequest] = []
        var statusOverride: ClubGovernanceValue?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let path = request.url!.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path == "api/userInfo" { return (Data(#"{"code":200,"appUser":{"id":701,"role":"player"}}"#.utf8), 200) }
            var value = ClubGovernanceValue.null
            if path == ClubGovernanceRead.notificationStatus.path, let statusOverride { value = statusOverride }
            else if let read = ClubGovernanceRead.allCases.first(where: { $0.path == path }) { value = ClubGovernanceFixtures.value(read) }
            else if let mutation = ClubGovernanceMutation.allCases.first(where: { $0.path == path }) { value = ClubGovernanceFixtures.receipt(mutation) }
            let body = ClubGovernanceValue.object(["code": .integer(200), "data": value, "msg": .string("ok")])
            return (try JSONEncoder().encode(body), 200)
        }
    }
    private func config() throws -> APIConfiguration { try APIConfiguration(baseURL: URL(string: "https://example.com/")!) }
    private func session() throws -> ClubGovernanceSession { try .init(accountID: 701, epoch: 1, token: "synthetic-token") }

    func testSendDispatchesOnceAndReceiptBecomesACampaign() async throws {
        let transport = Transport()
        let service = ClubGovernanceService(offlineConfiguration: try config(), offlineTransport: transport,
                                            risks: [.administrative, .financial, .identity, .provider])
        let reply = try await service.dispatch(try ClubGovernanceFixtures.command(.sendNotification), session: session(), check: {})
        XCTAssertEqual(transport.requests.filter { $0.url?.path.hasSuffix("api/club/event-notification/send") == true }.count, 1)
        let campaign = try ClubOpsNotifyCampaign(value: reply)
        XCTAssertEqual(campaign.id, 131)
        XCTAssertEqual(campaign.totalCount, 8)
        XCTAssertEqual(campaign.pendingCount, 2)
        XCTAssertTrue(campaign.canRetryFailed)
    }

    func testStatusReadSendsOnlyTheCampaignIdAndPresentsDelivery() async throws {
        let transport = Transport()
        let service = ClubGovernanceService(configuration: try config(), transport: transport)
        let snapshot = try await service.read(.notificationStatus, scope: .init(clubID: 81, campaignID: 131), session: session(), check: {})
        let request = try XCTUnwrap(transport.requests.last(where: { $0.url?.path.hasSuffix("api/club/event-notification/status") == true }))
        let body = try JSONDecoder().decode([String: ClubGovernanceValue].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body, ["campaignId": .integer(131)])
        let campaign = try ClubOpsNotifyCampaign(value: snapshot.value)
        XCTAssertEqual(campaign.successCount, 5)
        XCTAssertEqual(campaign.failedCount, 1)
    }

    func testRefreshShowsCompletedDeliveryAndStopsOfferingRetry() async throws {
        let transport = Transport()
        let service = ClubGovernanceService(configuration: try config(), transport: transport)
        transport.statusOverride = .object(["id": .integer(131), "totalCount": .integer(8), "successCount": .integer(8),
                                            "failedCount": .integer(0), "status": .string("COMPLETED")])
        let snapshot = try await service.read(.notificationStatus, scope: .init(clubID: 81, campaignID: 131), session: session(), check: {})
        let campaign = try ClubOpsNotifyCampaign(value: snapshot.value)
        XCTAssertEqual(campaign.phase, .completed)
        XCTAssertEqual(campaign.pendingCount, 0)
        XCTAssertFalse(campaign.canRetryFailed)
    }

    func testMalformedStatusIsNeverPresentedAsDelivered() async throws {
        let transport = Transport()
        let service = ClubGovernanceService(configuration: try config(), transport: transport)
        transport.statusOverride = .object(["id": .integer(131), "totalCount": .string("many")])
        do {
            let snapshot = try await service.read(.notificationStatus, scope: .init(clubID: 81, campaignID: 131), session: session(), check: {})
            XCTAssertThrowsError(try ClubOpsNotifyCampaign(value: snapshot.value))
        } catch { /* a strict-schema rejection at the service is equally honest */ }
    }
}
#endif
