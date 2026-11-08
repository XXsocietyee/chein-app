import Foundation
import XCTest
@testable import QuestifyCore

/// NOT COMPILED. Fixtures are SYNTHETIC, derived from ApiClubController.java join/reviewJoinRequest and
/// chengyinhub-xcx/pages/club/{detail,join-requests}/index.js.
final class RePoint06ClubJoinTests: XCTestCase {
    private func obj(_ d: Data) -> [String: Any] { (try? JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:] }

    func testJoinBodyMatchesProductionShape() throws {
        let b = obj(try RePoint06ClubJoin.joinBody(clubID: 7, isClubKind: true, inviteID: nil, message: "  hi  "))
        XCTAssertEqual(b["id"] as? Int, 7)
        XCTAssertEqual(b["joinMessage"] as? String, "hi")
        XCTAssertNil(b["request_id"])
    }
    func testJoinRefusesInviteAndNonClub() {
        XCTAssertThrowsError(try RePoint06ClubJoin.joinBody(clubID: 7, isClubKind: true, inviteID: 3, message: nil))
        XCTAssertThrowsError(try RePoint06ClubJoin.joinBody(clubID: 7, isClubKind: false, inviteID: nil, message: nil))
        XCTAssertThrowsError(try RePoint06ClubJoin.joinBody(clubID: 0, isClubKind: true, inviteID: nil, message: nil))
    }
    func testReviewBodyAndRefusals() throws {
        let b = obj(try RePoint06ClubJoin.reviewBody(clubID: 7, memberID: 9, note: nil, reasonCode: nil))
        XCTAssertEqual(b["clubId"] as? Int, 7); XCTAssertEqual(b["memberId"] as? Int, 9)
        XCTAssertThrowsError(try RePoint06ClubJoin.reviewBody(clubID: 7, memberID: 9, note: "x", reasonCode: nil))
        XCTAssertThrowsError(try RePoint06ClubJoin.reviewBody(clubID: 7, memberID: 9, note: nil, reasonCode: 2))
        XCTAssertThrowsError(try RePoint06ClubJoin.reviewBody(clubID: 7, memberID: -1, note: nil, reasonCode: nil))
    }
    func testParseJoin() throws {
        XCTAssertEqual(try RePoint06ClubJoin.parseJoin(Data(#"{"code":200,"msg":"x","data":{"state":"pending"}}"#.utf8)), .pending)
        XCTAssertEqual(try RePoint06ClubJoin.parseJoin(Data(#"{"code":200,"msg":"x","data":{"state":"joined"}}"#.utf8)), .joined)
        XCTAssertThrowsError(try RePoint06ClubJoin.parseJoin(Data(#"{"code":200,"msg":"x"}"#.utf8)))
        XCTAssertThrowsError(try RePoint06ClubJoin.parseJoin(Data(#"{"code":500,"msg":"请先登录"}"#.utf8)))
        XCTAssertThrowsError(try RePoint06ClubJoin.parseJoin(Data(#"{"code":200,"data":{"state":"?"}}"#.utf8)))
    }
    func testParseReviewNeedsExplicit200() throws {
        try RePoint06ClubJoin.parseReview(Data(#"{"code":200,"msg":"已通过入会申请"}"#.utf8))
        XCTAssertThrowsError(try RePoint06ClubJoin.parseReview(Data(#"{"msg":"ok"}"#.utf8)))
        XCTAssertThrowsError(try RePoint06ClubJoin.parseReview(Data(#"{"code":500,"msg":"缺少俱乐部或申请人ID"}"#.utf8)))
    }
}
