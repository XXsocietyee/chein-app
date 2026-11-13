import XCTest
@testable import Questify

@MainActor final class SquareRouteMapProviderTests: XCTestCase {
    private final class ReadCount { var value = 0 }
    private func document(_ object: String) throws -> TopicDetailDocument {
        let detail = try JSONDecoder().decode(TopicDetail.self, from: Data(object.utf8))
        return TopicDetailDocument(detail: detail, body: Data("{\"code\":200,\"data\":\(object)}".utf8))
    }

    func testUnverifiedGeometryHidesTheMap() async throws {
        let object = #"{"id":7,"name":"Synthetic","chaptersList":[{"id":11,"nodes":[{"id":21,"name":"甲","latitude":31.2,"longitude":121.5},{"id":22,"name":"乙","latitude":31.3,"longitude":121.6}]}]}"#
        let reads = ReadCount()
        let provider = SquareRouteMapProvider { id in
            reads.value += 1
            XCTAssertEqual(id, 7)
            return try self.document(object)
        }
        let route = try await provider.route(topicID: 7)
        XCTAssertEqual(reads.value, 1)
        XCTAssertTrue(route.nodes.isEmpty)
        XCTAssertTrue(route.roadSegments.isEmpty)
        XCTAssertFalse(route.isRoad)
    }

    func testVerifiedRoadKeepsChapterSegmentsAndAnEmDashForABlankStop() async throws {
        let object = """
        {"id":7,"name":"Synthetic","chaptersList":[
          {"id":11,"routeGeometryAvailable":true,"routeGeometry":[{"latitude":1,"longitude":2},{"latitude":1.1,"longitude":2.1}],
           "nodes":[{"id":21,"name":" ","latitude":1,"longitude":2}]},
          {"id":12,"routeGeometryAvailable":true,"routeGeometry":[{"latitude":3,"longitude":4},{"latitude":3.2,"longitude":4.2}],
           "nodes":[{"id":31,"name":"乙","latitude":3,"longitude":4}]}
        ]}
        """
        let provider = SquareRouteMapProvider { _ in try self.document(object) }
        let route = try await provider.route(topicID: 7)
        XCTAssertEqual(route.nodes.map(\.title), [SquareRouteMapVerified.unknownTitle, "乙"])
        XCTAssertEqual(route.roadSegments.count, 2)
        XCTAssertEqual(route.roadSegments[0].map(\.latitude), [1, 1.1])
        XCTAssertEqual(route.roadSegments[1].map(\.latitude), [3, 3.2])
        XCTAssertTrue(route.roadSegments[0].allSatisfy { $0.id < 0 })
        XCTAssertTrue(route.isRoad)
        let flat = route.roadSegments.flatMap { $0 }
        XCTAssertEqual(flat.count, 4)
    }

    func testNonPositiveTopicDoesNotRead() async throws {
        let provider = SquareRouteMapProvider { _ in throw APIError.notConfigured }
        do { _ = try await provider.route(topicID: 0); XCTFail() }
        catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
    }

    func testMismatchedDetailIsUnavailable() async throws {
        let provider = SquareRouteMapProvider { _ in
            try self.document(#"{"id":8,"name":"Other"}"#)
        }
        do { _ = try await provider.route(topicID: 7); XCTFail() }
        catch { XCTAssertEqual(error as? TopicReadFailure, .unavailable) }
    }
}
