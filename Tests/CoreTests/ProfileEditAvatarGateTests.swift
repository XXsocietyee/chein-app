#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Avatar upload stays gated unless the injected service carries an avatar transport.
/// The text save path (the page's main action) must keep working while the gate is closed.
final class ProfileEditAvatarGateTests: XCTestCase {
    @MainActor func testAvatarSavingIsUnavailableWithoutAvatarTransportButTextSaveStillWorks() async throws {
        let session = try ProfileEditSession(accountID: 901, epoch: 1, token: "fixture")
        let coordinator = ProfileEditCoordinator(service: ProfileEditSyntheticService(), currentSession: { session })
        XCTAssertFalse(coordinator.avatarSavingAvailable)
        await coordinator.load()
        await coordinator.prepare(ProfileEditDraft(name: "Gate Name", introduction: "Gate bio"))
        let confirmation = try XCTUnwrap(coordinator.confirmation)
        await coordinator.save(confirmation)
        XCTAssertEqual(coordinator.snapshot?.nickname, "Gate Name")
        XCTAssertEqual(coordinator.messageKey, "profile.edit.saved")
        XCTAssertFalse(coordinator.avatarSavingAvailable)
    }
}
#endif
