import XCTest
@testable import Questify

/// MC9-30-1 / MC9-32-1: each non-money cooperation action opens on the China production host.
/// Cancelling an accepted cooperation, and deposit pay / refund retry, stay on the money gate.
@MainActor final class MPFirstCoopWritesTests: XCTestCase {
    private let production = "www.chengyinhub.com"
    private let testHost = "8120.example.test"

    override func tearDown() {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        super.tearDown()
    }

    private func china(_ operation: CoopFlowMutation, cancelsAcceptedCooperation: Bool = false) -> Bool {
        MPFirstCoopWrites.admits(operation, market: .china, host: production,
                                 cancelsAcceptedCooperation: cancelsAcceptedCooperation, testOrDebug: true)
    }

    func testInviteDispatchesOnChinaProduction() throws {
        let operation = CoopFlowMutation.invite(try CoopFlowInvitation(
            kind: .merchant, recipient: try CoopFlowIdentity(.member, 9), topicID: 4, message: "来合作"))
        XCTAssertTrue(china(operation))
        XCTAssertFalse(MPFirstCoopWrites.admits(operation, market: .unitedStates, host: "shop.example.com", testOrDebug: false))
        XCTAssertTrue(MPFirstCoopWrites.admits(operation, market: nil, host: production, testOrDebug: false))
    }

    func testAcceptDispatchesOnChinaProduction() {
        XCTAssertTrue(china(.handle(inviteID: 8, action: .accept, reason: nil)))
    }

    func testRejectDispatchesOnChinaProduction() {
        XCTAssertTrue(china(.handle(inviteID: 8, action: .reject, reason: "时间不合")))
    }

    func testWithdrawInviteDispatchesOnChinaProduction() {
        XCTAssertTrue(china(.handle(inviteID: 8, action: .cancel, reason: "先撤回")))
    }

    func testStationAcceptAndTemplateExecutorOpenOnChinaProduction() {
        XCTAssertTrue(china(.handle(inviteID: 8, action: .accept, reason: "据点")))
        XCTAssertTrue(MPFirstCoopWrites.admitsUnprotectedWrites(market: .china, host: production))
    }

    func testContactDispatchesOnChinaProduction() {
        XCTAssertTrue(china(.contact(inviteID: 8)))
    }

    func testPerkAttachDispatchesOnChinaProduction() {
        XCTAssertTrue(china(.attachPerks(inviteID: 8, templateIDs: [3])))
    }

    func testReviewDispatchesOnChinaProduction() {
        XCTAssertTrue(china(.review(topicID: 4, memberID: 9, rating: 5, comment: "顺利")))
    }

    func testPoolDeclineAndWithdrawDispatchOnChinaProduction() {
        XCTAssertTrue(china(.decline(applyID: 6, scope: "MERCHANT")))
        XCTAssertTrue(china(.withdraw(topicID: 4)))
    }

    func testCandidateConfirmAndRejectDispatchOnChinaProduction() {
        XCTAssertTrue(china(.confirm(registrationID: 2, scope: "MERCHANT")))
        XCTAssertTrue(china(.reject(registrationID: 2, scope: "MERCHANT")))
    }

    func testOfficialAcceptAndRejectDispatchOnChinaProduction() {
        XCTAssertTrue(china(.handle(inviteID: 11, action: .accept, reason: "")))
        XCTAssertTrue(china(.handle(inviteID: 11, action: .reject, reason: "不接")))
    }

    func testCancelAcceptedCooperationStaysOffProductionEvenWhenRefundIsOn() {
        ReleaseMoneyWriteSwitch.testDerivation = { _ in true }
        let cancel = CoopFlowMutation.handle(inviteID: 8, action: .cancel, reason: "取消合作")
        XCTAssertFalse(china(cancel, cancelsAcceptedCooperation: true))
        XCTAssertTrue(MPFirstCoopWrites.admits(cancel, market: .china, host: testHost,
                                               cancelsAcceptedCooperation: true, testOrDebug: true))
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/coop/handle"))
    }

    func testDepositCreateAndRefundRetryStayMoneyBlocked() {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/coop/deposit/create"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/coop/deposit/create/app"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/coop/deposit/refund/retry"))
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/coop/deposit/create"), .payment)
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/coop/deposit/refund/retry"), .refund)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/coop/handle"))
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/coop/contact"))
    }
}
