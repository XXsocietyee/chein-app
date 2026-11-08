import XCTest
@testable import QuestifyCore

// SYNTHETIC fixtures derived from ApiClubController.java:457-533. NOT COMPILED.
final class RePoint03ClubUpdateTests: XCTestCase {
    func testBodyOmitsOperationConfigUnlessChanged() throws {
        var d = ClubOperationsDraft(); d.name = "N"; d.city = "C"
        let plain = try JSONSerialization.jsonObject(with: RePoint03ClubUpdateAdapter.body(clubID: 5, draft: d, operationConfigChanged: false)) as! [String: Any]
        XCTAssertEqual(plain["id"] as? Int, 5)
        XCTAssertNil(plain["operationConfigUpdated"])
        d.prioritySignupEnabled = true; d.memberReservedQuota = "3"
        let full = try JSONSerialization.jsonObject(with: RePoint03ClubUpdateAdapter.body(clubID: 5, draft: d, operationConfigChanged: true)) as! [String: Any]
        XCTAssertEqual(full["prioritySignupEnabled"] as? Int, 1)
        XCTAssertEqual(full["memberReservedQuota"] as? Int, 3)
    }
    func testInvalidInputThrows() {
        var d = ClubOperationsDraft(); d.memberReservedQuota = "-1"
        XCTAssertThrowsError(try RePoint03ClubUpdateAdapter.body(clubID: 0, draft: d, operationConfigChanged: false))
        XCTAssertThrowsError(try RePoint03ClubUpdateAdapter.body(clubID: 1, draft: d, operationConfigChanged: true))
    }
    func testDecode() throws {
        let ok = try RePoint03ClubUpdateAdapter.decode(Data(#"{"code":200,"msg":"已保存","data":{"joinPolicySupported":true,"joinPolicy":1}}"#.utf8))
        XCTAssertEqual(ok, .init(joinPolicySupported: true, joinPolicy: 1))
        XCTAssertThrowsError(try RePoint03ClubUpdateAdapter.decode(Data(#"{"code":500,"msg":"无权修改该俱乐部"}"#.utf8)))
        XCTAssertThrowsError(try RePoint03ClubUpdateAdapter.decode(Data(#"{"code":200,"data":{}}"#.utf8)))
    }
}
