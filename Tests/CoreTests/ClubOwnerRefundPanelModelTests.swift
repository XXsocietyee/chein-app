#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class ClubOwnerRefundPanelModelTests: XCTestCase {
    private func model(_ coordinator: ClubOwnerRefundCoordinator, _ target: ClubOwnerRefundTarget, canRefund: Bool) -> ClubOwnerRefundPanelModel {
        ClubOwnerRefundPanelModel(status: coordinator.state(target), sourceCanRefund: canRefund, coordinatorAvailable: true,
            identityMatches: true, canDispatch: coordinator.canDispatch)
    }
    func testOwnerFlowThroughFakeTransportSwitchesReviewToReadback() async throws {
        let access = ClubOwnerRefundFixtureAccess(.accepted), locks = ClubOwnerRefundMemoryLocks()
        let coordinator = ClubOwnerRefundCoordinator(access: access, locks: locks)
        let target = try ClubOwnerRefundTarget(clubID: 81, registrationID: 121)
        let before = model(coordinator, target, canRefund: true)
        XCTAssertTrue(before.isVisible); XCTAssertTrue(before.showsReviewButton); XCTAssertFalse(before.showsReadbackButton)
        XCTAssertTrue(before.confirmEnabled); XCTAssertFalse(before.showsNotAvailableNote)
        let review = try await coordinator.prepare(target, ownerID: UUID())
        await coordinator.confirm(review)
        XCTAssertEqual(access.sent, 1)
        let after = model(coordinator, target, canRefund: false)
        XCTAssertTrue(after.isVisible); XCTAssertFalse(after.showsReviewButton); XCTAssertTrue(after.showsReadbackButton)
    }
    func testNonOwnerSeesNoPanelWhenIdle() throws {
        let coordinator = ClubOwnerRefundCoordinator(access: ClubOwnerRefundFixtureAccess(), locks: ClubOwnerRefundMemoryLocks())
        let target = try ClubOwnerRefundTarget(clubID: 81, registrationID: 121)
        let hidden = model(coordinator, target, canRefund: false)
        XCTAssertFalse(hidden.isVisible); XCTAssertFalse(hidden.showsReviewButton)
    }
    func testProductionGrantAbsentShowsNotAvailableAndNeverEnablesConfirm() async throws {
        let access = ClubOwnerRefundFixtureAccess(.disabled), locks = ClubOwnerRefundMemoryLocks()
        let coordinator = ClubOwnerRefundCoordinator(access: access, locks: locks)
        let target = try ClubOwnerRefundTarget(clubID: 81, registrationID: 121)
        let gated = model(coordinator, target, canRefund: true)
        XCTAssertTrue(gated.showsNotAvailableNote); XCTAssertFalse(gated.confirmEnabled)
        let review = try await coordinator.prepare(target, ownerID: UUID())
        await coordinator.confirm(review)
        XCTAssertEqual(access.sent, 0); XCTAssertTrue(locks.values.isEmpty)
        XCTAssertEqual(coordinator.state(target).failure, .disabled)
    }
    func testMissingCoordinatorOrForeignIdentityHidesLiveControls() {
        let missing = ClubOwnerRefundPanelModel(status: .init(), sourceCanRefund: true, coordinatorAvailable: false, identityMatches: false, canDispatch: false)
        XCTAssertFalse(missing.showsReviewButton); XCTAssertTrue(missing.showsNotAvailableNote); XCTAssertFalse(missing.confirmEnabled)
        let foreign = ClubOwnerRefundPanelModel(status: .init(), sourceCanRefund: true, coordinatorAvailable: true, identityMatches: false, canDispatch: true)
        XCTAssertFalse(foreign.showsLiveSection); XCTAssertFalse(foreign.confirmEnabled)
    }
    func testInFlightDisablesReviewAndConfirm() {
        var status = ClubOwnerRefundStatus(); status.phase = .submitting
        let busy = ClubOwnerRefundPanelModel(status: status, sourceCanRefund: true, coordinatorAvailable: true, identityMatches: true, canDispatch: true)
        XCTAssertFalse(busy.reviewEnabled); XCTAssertFalse(busy.confirmEnabled)
    }
}
#endif
