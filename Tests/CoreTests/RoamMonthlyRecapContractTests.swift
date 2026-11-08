#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private actor RecapContractWire: HTTPTransport {
    var bodies: [String]
    private(set) var requests: [URLRequest] = []
    init(_ bodies: [String]) { self.bodies = bodies }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request); return (Data(bodies.removeFirst().utf8), 200)
    }
}

/// Consistent-fixture companions for the monthly-recap page: weekly columns only appear when
/// the deduplicated items equal the server's month total (no invented partial chart).
@MainActor final class RoamMonthlyRecapContractTests: XCTestCase {
    private let base = URL(string: "https://tools.example/native")!
    /// 2026-10-19 12:00 Asia/Shanghai.
    private let asOf: Int64 = 1_792_382_400_000
    private func service(_ wire: any HTTPTransport) throws -> RoamPassportToolsService {
        let fixed = Date(timeIntervalSince1970: TimeInterval(asOf) / 1000)
        return .init(configuration: try APIConfiguration(baseURL: base), transport: wire, now: { fixed })
    }
    private func recap(routes: Int, items: [String]) -> String {
        #"{"code":200,"data":{"month":"2026-10","kind":"routes","timeZone":"Asia/Shanghai","generatedAtMs":\#(asOf),"counts":{"routes":\#(routes),"places":1,"stamps":0},"items":[\#(items.joined(separator: ","))],"hasMore":false,"nextBeforeId":null}}"#
    }
    private func record(_ id: String, _ at: String) -> String { #"{"id":"\#(id)","objectId":"5","title":"T\#(id)","occurredAt":"\#(at)"}"# }
    private var items: [String] {
        [record("9", "2026-10-02 09:00:00"), record("8", "2026-10-09 10:00:00"),
         record("8", "2026-10-09 10:00:00"), record("7", "2026-10-31 23:59:59")]
    }

    func testDuplicateCollapseWithMatchingTotalBuildsWeeklyColumns() async throws {
        let wire = RecapContractWire([recap(routes: 3, items: items)])
        let page = try await service(wire).monthlyRecap(.init(month: "2026-10"), token: "t")
        XCTAssertEqual(page.items.map(\.id), ["9", "8", "7"])
        XCTAssertEqual(page.items.map(\.dateText), ["10/2", "10/9", "10/31"])
        XCTAssertEqual(page.weeks.map(\.count), [1, 1, 0, 0, 1])
        XCTAssertEqual(page.weeks.filter(\.isMax).map(\.index), [1, 2, 5])
        XCTAssertEqual(page.counts, RoamRecapCounts(routes: 3, places: 1, stamps: 0))
        let url = await wire.requests[0].url?.absoluteString
        XCTAssertEqual(url, "https://tools.example/native/api/monthly-recap?kind=routes&limit=20&month=2026-10")
    }
    func testTotalLargerThanReadItemsKeepsWeeksEmpty() async throws {
        let wire = RecapContractWire([recap(routes: 4, items: items)])
        let page = try await service(wire).monthlyRecap(.init(month: "2026-10"), token: "t")
        XCTAssertEqual(page.items.count, 3)
        XCTAssertTrue(page.weeks.isEmpty)
    }
    func testNonDescendingIdsAreMalformed() async throws {
        let wire = RecapContractWire([recap(routes: 2, items: [record("7", "2026-10-02 09:00:00"), record("8", "2026-10-09 10:00:00")])])
        do { _ = try await service(wire).monthlyRecap(.init(month: "2026-10"), token: "t"); XCTFail("expected malformed") }
        catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
    }
}
#endif
