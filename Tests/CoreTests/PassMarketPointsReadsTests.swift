import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class PassMarketPointsRecordingTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var payload = #"{"code":200,"data":[]}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(payload.utf8), 200)
    }
}

final class PassMarketPointsReadsTests: XCTestCase {
    private let example = URL(string: "https://example.com")!
    private var china: URL { URL(string: ReviewedMarketLaunch.chinaProductionBaseURL)! }

    func testUnknownAmountIsAnEmDashAndZeroStaysZero() {
        XCTAssertEqual(PassMarketPointsReads.display(nil), "\u{2014}")
        XCTAssertEqual(PassMarketPointsReads.display(0), "0")
        XCTAssertNotEqual(PassMarketPointsReads.display(nil), "0")
    }

    func testUserPointsListIsNotTheHistoryPath() {
        XCTAssertTrue(PassMarketPointsReads.matches(path: "/api/points/list", relative: PassMarketPointsReads.listPath))
        XCTAssertTrue(PassMarketPointsReads.matches(path: "/prod-api/api/points/list", relative: PassMarketPointsReads.listPath))
        XCTAssertFalse(PassMarketPointsReads.matches(path: "/api/user/points/list", relative: PassMarketPointsReads.listPath))
        XCTAssertTrue(PassMarketPointsReads.matches(path: "/api/user/points/statistics", relative: PassMarketPointsReads.statisticsPath))
        XCTAssertTrue(PassMarketPointsReads.matches(path: "/api/points/result_list", relative: PassMarketPointsReads.rulesPath))
    }

    func testTransportForwardsOnlyTheThreePosts() async throws {
        let wire = PassMarketPointsRecordingTransport()
        let transport = PassMarketPointsReadTransport(underlying: wire)
        let service = WalletCommerceService(configuration: try APIConfiguration(baseURL: example), transport: transport)
        _ = try await service.ledger(.assetPoints, token: "synthetic-token")
        _ = try await service.pointsTasks(token: "synthetic-token")
        wire.payload = #"{"code":200,"data":{"weekPoints":0,"rankPercentage":"TOP1%","totalUsers":3,"userRank":1}}"#
        let weekly = ProfileWeeklyPointsService(configuration: try APIConfiguration(baseURL: example), transport: transport)
        let stats = try await weekly.read(token: "synthetic-token")
        XCTAssertEqual(stats.weekPoints, 0)
        XCTAssertEqual(wire.requests.map { $0.url?.path }, ["/api/points/list", "/api/points/result_list", "/api/user/points/statistics"])
        XCTAssertEqual(Set(wire.requests.compactMap(\.httpMethod)), Set(["POST"]))
        XCTAssertNil(wire.requests[2].httpBody)

        let before = wire.requests.count
        for kind in [WalletLedgerKind.points, .balance] {
            do { _ = try await service.ledger(kind, token: "synthetic-token"); XCTFail(String(describing: kind)) }
            catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        }
        do { _ = try await service.withdrawals(token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        var get = URLRequest(url: example.appendingPathComponent(PassMarketPointsReads.listPath))
        get.httpMethod = "GET"
        do { _ = try await transport.send(get); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        var queried = URLRequest(url: URL(string: "https://example.com/api/points/list?page=1")!)
        queried.httpMethod = "POST"
        do { _ = try await transport.send(queried); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        XCTAssertEqual(wire.requests.count, before)
    }

    func testChinaProductionRefusesWritesAndStillAllowsTheThreeReads() async throws {
        let wire = PassMarketPointsRecordingTransport()
        let transport = PassMarketPointsReadTransport(underlying: wire)
        var redeem = URLRequest(url: china.appendingPathComponent("api/cart/order/settlement"))
        redeem.httpMethod = "POST"
        var withdraw = URLRequest(url: china.appendingPathComponent("api/withdrawal/create"))
        withdraw.httpMethod = "POST"
        for request in [redeem, withdraw] {
            do { _ = try await transport.send(request); XCTFail(request.url?.path ?? "") }
            catch { XCTAssertEqual(error as? APIError, .notConfigured) }
        }
        XCTAssertTrue(wire.requests.isEmpty)
        for relative in [PassMarketPointsReads.listPath, PassMarketPointsReads.statisticsPath, PassMarketPointsReads.rulesPath] {
            var request = URLRequest(url: china.appendingPathComponent(relative))
            request.httpMethod = "POST"
            _ = try await transport.send(request)
        }
        XCTAssertEqual(wire.requests.count, 3)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/points/list"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/user/points/statistics"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/points/result_list"))
    }

    func testMissingStatisticsDoNotDecodeAsZero() throws {
        let missing = #"{"rankPercentage":"TOP1%","totalUsers":3,"userRank":1}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ProfileWeeklyPoints.self, from: missing))
        let zero = #"{"weekPoints":0,"rankPercentage":"TOP1%","totalUsers":3,"userRank":1}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(ProfileWeeklyPoints.self, from: zero).weekPoints, 0)
    }
}
