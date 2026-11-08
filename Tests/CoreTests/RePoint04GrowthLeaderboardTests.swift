import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// SYNTHETIC fixtures derived from GrowthServiceImpl.getLeaderboard / MemberLeaderboardVO. NOT COMPILED.
final class RePoint04GrowthLeaderboardTests: XCTestCase {
    func testRePointedServiceHitsProductionPathAndDecodesSyntheticBoard() async throws {
        let wire = Wire()
        let service = RePoint04GrowthLeaderboard.service(
            configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/native")!), transport: wire)
        let board = try await service.leaderboard(query: .init(metric: .exp, period: .week), limit: 2, token: "synthetic-token")
        let requests = await wire.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/native/api/growth/leaderboard")
        XCTAssertNotEqual(requests.first?.url?.path.hasSuffix("/anonymous"), true)
        XCTAssertEqual(board.metric, .exp); XCTAssertEqual(board.period, .week)
        XCTAssertEqual(board.list.first?.rank, 1)
        XCTAssertEqual(board.me.rank, nil, "UNKNOWN rank (null) is never 0")
    }
    private actor Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let json = #"{"code":200,"data":{"metric":"exp","period":"week","list":[{"rank":1,"memberId":7,"nickname":"synthetic","avatar":null,"score":120,"rankPercentage":null}],"me":{"rank":null,"memberId":9,"nickname":"me","avatar":null,"score":0,"rankPercentage":null}}}"#
            return (Data(json.utf8), 200)
        }
    }
}
