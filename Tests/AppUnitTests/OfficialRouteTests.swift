import XCTest
@testable import Questify
#if canImport(QuestifyCore)
import QuestifyCore
#endif

final class OfficialRouteTests: XCTestCase {
    func testIDRuleMatchesMiniProgram() {
        XCTAssertTrue(OfficialRouteReader.isValidID("123456789012345678"))
        XCTAssertFalse(OfficialRouteReader.isValidID("1234567890123456789"))
        XCTAssertFalse(OfficialRouteReader.isValidID(""))
        XCTAssertFalse(OfficialRouteReader.isValidID("12a"))
    }

    func testMetaFormatIsLocaleAware() {
        let route = OfficialRoute(id: "1", name: "Bund", city: "Shanghai", previewImage: "", distanceKm: 1.5, totalMinutes: 80)
        XCTAssertEqual(OfficialRouteFormat.meta(route, chinese: false), "Shanghai · 1.5 km · 1 h 20 min")
        XCTAssertEqual(OfficialRouteFormat.meta(route, chinese: true), "Shanghai · 1.5 km · 1 小时 20 分")
        XCTAssertEqual(OfficialRouteFormat.duration(45, chinese: false), "45 min")
        XCTAssertEqual(OfficialRouteFormat.distance(0), "")
    }

    func testNodeDetailDropsUnnamedAndInvalidCoordinates() async throws {
        let json = #"{"data":{"id":"9","name":"Walk","nodes":[{"id":5,"name":"A","latitude":31.2,"longitude":121.4,"nodeTime":30},{"name":""},{"name":"B","latitude":120,"longitude":10}]}}"#
        let reader = OfficialRouteReader(list: { [] }, detail: { _ in
            try OfficialRouteDecoding.detail(Data(json.utf8))
        })
        let detail = try await reader.detail("9")
        XCTAssertEqual(detail.nodes.map(\.name), ["A", "B"])
        XCTAssertEqual(detail.nodes.map(\.order), [1, 2])
        XCTAssertNotNil(detail.nodes[0].latitude)
        XCTAssertNil(detail.nodes[1].latitude)
    }
}
