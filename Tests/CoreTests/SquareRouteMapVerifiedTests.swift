#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class SquareRouteMapVerifiedTests: XCTestCase {
    private func project(_ object: String) throws -> SquareRouteMapVerified.Route? {
        let detail = try JSONDecoder().decode(TopicDetail.self, from: Data(object.utf8))
        let body = Data("{\"code\":200,\"data\":\(object)}".utf8)
        return SquareRouteMapVerified.project(detail: detail, body: body)
    }

    func testVerifiedStringGeometrySortsStopsAndKeepsTheRoadOffTheNodes() throws {
        let route = try XCTUnwrap(project("""
        {"id":7,"name":"Synthetic","chaptersList":[{"id":11,"routeGeometryAvailable":true,
        "routeGeometry":"[{\\"latitude\\":31.2,\\"longitude\\":121.5},{\\"lat\\":31.3,\\"lng\\":121.6}]",
        "nodes":[
          {"id":22,"nodeName":"  ","latitude":31.21,"longitude":121.51,"sortId":2},
          {"id":21,"name":"甲","latitude":"31.20","longitude":"121.50","sortId":"1"}
        ]}]}
        """))
        XCTAssertEqual(route.stops.map(\.id), [21, 22])
        XCTAssertEqual(route.stops.map(\.title), ["甲", SquareRouteMapVerified.unknownTitle])
        XCTAssertEqual(route.segments.count, 1)
        XCTAssertEqual(route.segments[0].map(\.latitude), [31.2, 31.3])
        XCTAssertEqual(route.segments[0].map(\.longitude), [121.5, 121.6])
        XCTAssertNotEqual(route.segments[0].map(\.latitude), route.stops.map(\.latitude))
    }

    func testArrayGeometryStaysOneSegmentPerChapter() throws {
        let route = try XCTUnwrap(project("""
        {"id":7,"name":"Synthetic","chaptersList":[
          {"id":11,"routeGeometryAvailable":true,"routeGeometryErrorCode":0,
           "routeGeometry":[{"latitude":1,"longitude":2},{"latitude":1.1,"longitude":2.1}],
           "nodes":[{"id":21,"name":"甲","lat":1,"lng":2}]},
          {"id":12,"routeGeometryAvailable":true,"routeGeometryError":false,"routeGeometryErrorCode":"",
           "routeGeometry":[{"latitude":3,"longitude":4},{"latitude":3.1,"longitude":4.1}],
           "nodes":[{"id":31,"nodeName":"乙","latitude":3,"longitude":4}]}
        ]}
        """))
        XCTAssertEqual(route.segments.count, 2)
        XCTAssertEqual(route.segments[0].map(\.latitude), [1, 1.1])
        XCTAssertEqual(route.segments[1].map(\.latitude), [3, 3.1])
        XCTAssertEqual(route.stops.map(\.title), ["甲", "乙"])
        let joined = route.segments.flatMap { $0 }
        XCTAssertEqual(joined.count, 4)
        XCTAssertNotEqual(joined[1].latitude, joined[2].latitude)
    }

    func testMissingBrokenOrPartialGeometryHidesTheMap() throws {
        let nodes = #"[{"id":21,"name":"甲","latitude":31.2,"longitude":121.5},{"id":22,"name":"乙","latitude":31.3,"longitude":121.6}]"#
        let hidden = [
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"nodes":\#(nodes)}]}"#,
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"routeGeometryAvailable":1,"routeGeometry":[{"latitude":1,"longitude":2},{"latitude":1.1,"longitude":2.1}],"nodes":\#(nodes)}]}"#,
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"routeGeometryAvailable":true,"routeGeometryErrorCode":"BLOCK","routeGeometry":[{"latitude":1,"longitude":2},{"latitude":1.1,"longitude":2.1}],"nodes":\#(nodes)}]}"#,
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"routeGeometryAvailable":true,"routeGeometryError":true,"routeGeometry":[{"latitude":1,"longitude":2},{"latitude":1.1,"longitude":2.1}],"nodes":\#(nodes)}]}"#,
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"routeGeometryAvailable":true,"routeGeometry":[{"latitude":1,"longitude":2},{"latitude":"nope","longitude":3}],"nodes":\#(nodes)}]}"#,
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"routeGeometryAvailable":true,"routeGeometry":"not-json","nodes":\#(nodes)}]}"#,
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"routeGeometryAvailable":true,"routeGeometry":[{"latitude":1,"longitude":2}],"nodes":\#(nodes)}]}"#,
            #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"nodes":[{"id":21,"name":"甲","latitude":31.2,"longitude":121.5}]}]}"#,
            #"""
            {"id":7,"name":"Synthetic","chaptersList":[
              {"id":11,"routeGeometryAvailable":true,"routeGeometry":[{"latitude":1,"longitude":2},{"latitude":1.1,"longitude":2.1}],"nodes":[{"id":21,"name":"甲","latitude":1,"longitude":2}]},
              {"id":12,"nodes":\#(nodes)}
            ]}
            """#
        ]
        for json in hidden {
            XCTAssertNil(try project(json))
        }
    }

    func testDuplicateStopIsNotInventedAndARoadlessChapterIsSkippedOnlyWhenItHasNoStop() throws {
        let route = try XCTUnwrap(project("""
        {"id":7,"name":"Synthetic","chaptersList":[
          {"id":11,"routeGeometryAvailable":true,
           "routeGeometry":[{"latitude":1,"longitude":2},{"latitude":1.1,"longitude":2.1}],
           "nodes":[{"id":21,"name":"甲","latitude":1,"longitude":2},{"id":21,"name":"甲","latitude":1.2,"longitude":2.2}]},
          {"id":12,"nodes":[{"id":99,"name":"无坐标"}]}
        ]}
        """))
        XCTAssertEqual(route.stops.map(\.id), [21])
        XCTAssertEqual(route.segments.count, 1)
    }

    func testUnknownTitleIsAnEmDash() {
        XCTAssertEqual(SquareRouteMapVerified.title(nil), "—")
        XCTAssertEqual(SquareRouteMapVerified.title("  "), "—")
        XCTAssertEqual(SquareRouteMapVerified.title("甲"), "甲")
        XCTAssertEqual(SquareRouteMapVerified.unknownTitle, "\u{2014}")
    }
}
#endif
