import XCTest
@testable import Questify

/// R7-PC-B1-1 (MP-first rule, owner 2026-11-25): topic 收藏 sends what pages/topic/index/index.js sends.
@MainActor final class TopicFavoriteMPFirstTests: XCTestCase {
    private let base = URL(string: "https://topic-favorite.example")!
    private func field(_ request: URLRequest, _ name: String) -> String? {
        guard let body = request.httpBody, let text = String(data: body, encoding: .utf8),
              let range = text.range(of: "name=\"\(name)\"\r\n\r\n"),
              let end = text[range.upperBound...].range(of: "\r\n") else { return nil }
        return String(text[range.upperBound..<end.lowerBound])
    }

    /// index.js:625-626 `POST /api/topic/like {id, type: next ? 1 : 0}`.
    func test_toggle_request_shape_matches_mp_toggleFav() throws {
        let factory = TopicLikeOperationFactory(configuration: try APIConfiguration(baseURL: base))
        let like = try factory.request(topicID: 42, direction: TopicLikeDirection(liked: true), token: "synthetic-token")
        XCTAssertEqual(like.httpMethod, "POST")
        XCTAssertEqual(like.url?.path, "/api/topic/like")
        XCTAssertEqual(field(like, "id"), "42"); XCTAssertEqual(field(like, "type"), "1")
        let unlike = try factory.request(topicID: 42, direction: TopicLikeDirection(liked: false), token: "synthetic-token")
        XCTAssertEqual(field(unlike, "type"), "0")
    }

    /// index.js:582-583 `POST /api/topic/like_list {pageNum: 1, pageSize: 200}`; faved = rows contain the topic.
    func test_seed_read_shape_and_decode_match_mp_loadFav() throws {
        let request = try TopicFavoriteMP.listRequest(configuration: try APIConfiguration(baseURL: base), token: "synthetic-token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/topic/like_list")
        XCTAssertEqual(field(request, "pageNum"), "1"); XCTAssertEqual(field(request, "pageSize"), "200")
        let rows = Data(#"{"code":200,"data":{"rows":[{"id":7},{"id":42}]}}"#.utf8)
        XCTAssertTrue(try TopicFavoriteMP.liked(topicID: 42, data: rows, status: 200))
        XCTAssertFalse(try TopicFavoriteMP.liked(topicID: 43, data: rows, status: 200))
        XCTAssertThrowsError(try TopicFavoriteMP.liked(topicID: 42, data: Data(#"{"code":500}"#.utf8), status: 200))
    }

    /// Optimistic flip, rollback on a rejection (index.js:628-633).
    func test_displayed_state_is_optimistic_with_rollback() {
        XCTAssertNil(TopicFavoriteMP.displayed(nil))
        XCTAssertEqual(TopicFavoriteMP.displayed(.sending(.like)), true)
        XCTAssertEqual(TopicFavoriteMP.displayed(.awaitingReadback(.unlike)), false)
        XCTAssertEqual(TopicFavoriteMP.displayed(.rejected(.like, message: nil)), false)
        XCTAssertEqual(TopicFavoriteMP.displayed(.confirmed(liked: true)), true)
    }
}
