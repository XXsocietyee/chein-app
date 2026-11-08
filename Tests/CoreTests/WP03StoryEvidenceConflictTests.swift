import XCTest
@testable import QuestifyCore

final class WP03StoryEvidenceConflictTests: XCTestCase {
    private func submittedBridge() throws -> (StoryWalkingNavigationHostBridge, WalkingTargetReference) {
        var bridge = try StoryWalkingNavigationHostBridge(missionID: 8)
        let stop = try WalkingTargetReference(kind: .storyNode, id: 1, missionID: 8)
        _ = try bridge.ingestAuthorityReadback(.init(missionID: 8, revision: 1, currentStop: stop, finished: false))
        XCTAssertTrue(bridge.recordWalkingArrival(for: stop))
        XCTAssertTrue(bridge.storeEvidence("evidence-1", for: stop))
        XCTAssertTrue(bridge.recordVerificationSubmitted(for: stop))
        return (bridge, stop)
    }
    func testConflict409KeepsStoredEvidence() throws {
        var (bridge, stop) = try submittedBridge()
        XCTAssertTrue(bridge.recordSubmitConflict(for: stop, status: 409))
        XCTAssertEqual(bridge.storedEvidence(for: stop), "evidence-1")
        XCTAssertTrue(bridge.hasSubmitConflict(for: stop))
        XCTAssertEqual(bridge.phase, .verificationSubmitted(stop))   // no local advance or completion
        XCTAssertEqual(bridge.stopTransitionCount, 1)
        // Only 409 is a conflict; other statuses and unrelated stops change nothing.
        XCTAssertFalse(bridge.recordSubmitConflict(for: stop, status: 500))
        let other = try WalkingTargetReference(kind: .storyNode, id: 2, missionID: 8)
        XCTAssertFalse(bridge.recordSubmitConflict(for: other, status: 409))
        XCTAssertNil(bridge.storedEvidence(for: other))
        // A newer authority readback is what finally releases the evidence row.
        let next = try WalkingTargetReference(kind: .storyNode, id: 2, missionID: 8)
        _ = try bridge.ingestAuthorityReadback(.init(missionID: 8, revision: 2, currentStop: next, finished: false))
        XCTAssertNil(bridge.storedEvidence(for: stop))
        XCTAssertFalse(bridge.hasSubmitConflict(for: stop))
    }
    @MainActor func testNoStraightLineRouteIntroduced() async throws {
        var (bridge, stop) = try submittedBridge()
        XCTAssertTrue(bridge.recordSubmitConflict(for: stop, status: 409))
        XCTAssertNil(bridge.activeWalkingStop)
        XCTAssertNil(bridge.walkingDestination)
        // A coordinator fed a straight-line provider result still refuses to navigate.
        let rig = try WP03Rig(straightLine: true); await rig.model.start()
        XCTAssertEqual(rig.model.phase, .failed(.noRoute))
        XCTAssertNil(rig.model.route); XCTAssertNil(rig.model.progress)
        XCTAssertEqual(bridge.storedEvidence(for: stop), "evidence-1")
    }
}
