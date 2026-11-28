import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// 1128 gap #30 (C-15): with merchant out of the first release the owner stage never asks for 邀请商家,
/// 查看邀请进度 or 合作邀约; a published topic goes straight to 开一场. With merchant on, the MP chain is unchanged.
final class ClubOwnerStageMerchantGateTests: XCTestCase {
    private func input(merchant: Bool, invites: [ClubOwnerStageInvite] = [], messages: [ClubOwnerStageMessage] = []) -> ClubOwnerStageInput {
        var value = ClubOwnerStageInput(isOwner: true, canGovern: true, clubID: 81,
                                        topics: [.init(id: 5, productType: 2, name: "城市漫游")],
                                        sentInvites: invites, messages: messages)
        value.merchantEnabled = merchant
        return value
    }

    func testReleaseSkipsTheMerchantInviteStep() {
        XCTAssertEqual(ClubOwnerStageMachine.resolve(input(merchant: true)).stage, .invite)
        XCTAssertEqual(ClubOwnerStageMachine.resolve(input(merchant: false)).stage, .run)
        XCTAssertEqual(ClubOwnerStageMachine.resolve(input(merchant: false)).label, "开一场")
    }

    func testReleaseSkipsPendingInvitesAndCoopOffers() {
        let pending = [ClubOwnerStageInvite(topicID: 5, status: 0)]
        XCTAssertEqual(ClubOwnerStageMachine.resolve(input(merchant: true, invites: pending)).stage, .pending)
        XCTAssertEqual(ClubOwnerStageMachine.resolve(input(merchant: false, invites: pending)).stage, .run)
        let offer = [ClubOwnerStageMessage(status: 0, toType: "club", toID: 81)]
        XCTAssertEqual(ClubOwnerStageMachine.resolve(input(merchant: true, messages: offer)).stage, .coopInvite)
        XCTAssertEqual(ClubOwnerStageMachine.resolve(input(merchant: false, messages: offer)).stage, .run)
    }

    func testReleaseFlagIsOffOutsideDebugAndTest() {
        #if !(DEBUG || TEST)
        XCTAssertFalse(PlayerLaunch.merchantCenterEnabled)
        #endif
        XCTAssertFalse(ClubOwnerStageInput(isOwner: true, canGovern: true, clubID: 1).merchantEnabled != PlayerLaunch.merchantCenterEnabled)
    }
}
