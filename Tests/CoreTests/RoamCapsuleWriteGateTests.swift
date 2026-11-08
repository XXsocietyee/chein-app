#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// A read-only approval must list capsules, but never reach the create route.
@available(macOS 14.0, *)
@MainActor final class RoamCapsuleWriteGateTests: XCTestCase {
    private func unlock(_ tools: RoamPrivateToolsFixture) -> String {
        RoamCapsuleUnlockOption.options(now: tools.now)[0].date
    }
    func testReadOnlyApprovalListsCapsulesAndRefusesToPrepareACreate() async {
        let tools = RoamPrivateToolsFixture(scenario: .readOnly)
        XCTAssertTrue(tools.isConfigured)
        XCTAssertFalse(tools.allowsWrites)
        let model = RoamCapsuleCoordinator(tools: tools)
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertFalse(model.items.isEmpty)
        XCTAssertFalse(model.canWrite)
        model.prepareCreate(body: "Dear future me", unlockDate: unlock(tools))
        XCTAssertEqual(model.issue, .writesDisabled)
        XCTAssertNil(model.review)
        let confirmed = await model.confirmCreate()
        XCTAssertFalse(confirmed)
        XCTAssertTrue(tools.dispatchedWrites.isEmpty)
    }
    func testWritableApprovalStillPreparesAReviewBeforeAnyDispatch() async {
        let tools = RoamPrivateToolsFixture(scenario: .content)
        let model = RoamCapsuleCoordinator(tools: tools)
        await model.load()
        XCTAssertTrue(model.canWrite)
        model.prepareCreate(body: "Dear future me", unlockDate: unlock(tools))
        XCTAssertNotNil(model.review)
        XCTAssertTrue(tools.dispatchedWrites.isEmpty)
    }
}
#endif
