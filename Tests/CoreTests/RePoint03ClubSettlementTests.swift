import XCTest
@testable import QuestifyCore

// SYNTHETIC fixtures derived from ApiClubSettlementController.java:70-127. NOT COMPILED.
final class RePoint03ClubSettlementTests: XCTestCase {
    private func json(_ s: String) -> Data { Data(s.utf8) }
    func testVerifiedAndPendingRows() throws {
        let r = try RePoint03ClubSettlementAdapter.decode(json("""
        {"code":200,"data":{"settledAmountText":"¥100.00","settledAmountStatus":"verified","unverifiedSettledCount":0,
         "pendingAdjustment":null,"isOwner":true,"topics":[
         {"id":1,"topicId":9,"name":"A","originalAmountText":"¥100.00","executedAdjustmentText":"¥0.00","netAmountText":"¥100.00","amountText":"¥100.00","amountStatus":"verified","arrivedText":"x","paidText":"已入账","status":"settled"},
         {"id":2,"topicId":10,"name":"B","originalAmountText":"¥5.00","executedAdjustmentText":"¥0.00","netAmountText":"¥5.00","amountText":"¥5.00","amountStatus":"verified","arrivedText":"y","paidText":"待入账","status":"pending"}]}}
        """))
        XCTAssertEqual(r.records.map(\.status), [.credited, .pending])
        XCTAssertEqual(r.settledAmountText, "¥100.00")
    }
    func testUnverifiedTotalStaysNilNotZero() throws {
        let r = try RePoint03ClubSettlementAdapter.decode(json("""
        {"code":200,"data":{"settledAmountText":null,"unverifiedSettledCount":1,"isOwner":false,"topics":[
         {"id":3,"topicId":11,"name":"C","originalAmountText":"¥1.00","executedAdjustmentText":"¥0.00","netAmountText":"¥1.00","amountText":null,"amountStatus":"unverified","arrivedText":"入账记录待核验","paidText":"入账金额未核验","status":"settled"}]}}
        """))
        XCTAssertNil(r.settledAmountText)
        XCTAssertEqual(r.records.first?.status, .unverified)
    }
    func testMissingFieldsAndErrorsThrow() {
        XCTAssertThrowsError(try RePoint03ClubSettlementAdapter.decode(json(#"{"code":500,"msg":"仅主理人与联席主理人可查看分润"}"#)))
        XCTAssertThrowsError(try RePoint03ClubSettlementAdapter.decode(json(#"{"code":200,"data":{"unverifiedSettledCount":0,"isOwner":true,"topics":[]}}"#)))
    }
    func testRequestRejectsNonPositiveClub() {
        XCTAssertNil(RePoint03SettlementRequest(clubID: 0))
        XCTAssertNotNil(RePoint03SettlementRequest(clubID: 7))
    }
}
