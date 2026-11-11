#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// `SquarePost.likeCount/commentCount` and `SquareComment.likeCount` are `Int?`:
/// nil is unknown (an em dash on screen), a literal 0 is a known 0.
final class SquareOptionalCountModelTests: XCTestCase {
    private func post(_ json: String) throws -> SquarePost {
        try JSONDecoder().decode(SquarePost.self, from: Data(json.utf8))
    }
    private func comment(_ json: String) throws -> SquareComment {
        try JSONDecoder().decode(SquareComment.self, from: Data(json.utf8))
    }

    func testPostCountsAreNilWhenOmittedNullNegativeOrNotANumber() throws {
        for json in [#"{"id":1}"#,
                     #"{"id":1,"likeCount":null,"commentCount":null}"#,
                     #"{"id":1,"likeNum":-1,"commentCount":-3}"#,
                     #"{"id":1,"likeCount":"4","commentCount":"0"}"#] {
            let value = try post(json)
            XCTAssertNil(value.likeCount, json)
            XCTAssertNil(value.commentCount, json)
        }
    }

    func testPostLiteralZeroStaysZeroAndIsNotNil() throws {
        let value = try post(#"{"id":1,"likeCount":0,"commentCount":0}"#)
        XCTAssertEqual(value.likeCount, 0)
        XCTAssertEqual(value.commentCount, 0)
        XCTAssertEqual(SquareCountDisplay.text(value.likeCount), "0")
    }

    func testPostKnownCountsAndLikeNumAlias() throws {
        let value = try post(#"{"id":1,"likeNum":12,"commentCount":3}"#)
        XCTAssertEqual(value.likeCount, 12)
        XCTAssertEqual(value.commentCount, 3)
    }

    func testCommentLikeCountNilVersusZero() throws {
        XCTAssertNil(try comment(#"{"id":801}"#).likeCount)
        XCTAssertNil(try comment(#"{"id":801,"likeCount":null}"#).likeCount)
        XCTAssertEqual(try comment(#"{"id":801,"likeCount":0}"#).likeCount, 0)
        XCTAssertEqual(try comment(#"{"id":801,"like_count":2}"#).likeCount, 2)
    }

    func testDisplayTextUsesEmDashOnlyForUnknown() {
        XCTAssertEqual(SquareCountDisplay.text(nil), "\u{2014}")
        XCTAssertEqual(SquareCountDisplay.text(-1), "\u{2014}")
        XCTAssertEqual(SquareCountDisplay.text(0), "0")
        XCTAssertEqual(SquareCountDisplay.text(7), "7")
    }
}
#endif
