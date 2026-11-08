import XCTest
@testable import QuestifyCore

@MainActor final class WP02GameVsShareSwitchTests: XCTestCase {
    func testStoppingShareDoesNotEndGameSession() async throws {
        let rig = try WP02Rig()
        rig.coordinator.gameCollectionChanged(active: true)
        let key = try XCTUnwrap(await rig.startSharing())
        XCTAssertTrue(rig.coordinator.collectionSwitches.shareActive)
        XCTAssertTrue(rig.coordinator.collectionSwitches.gameCollectionActive)
        await rig.coordinator.stop(requestKey: key)
        XCTAssertFalse(rig.coordinator.collectionSwitches.shareActive)
        XCTAssertTrue(rig.coordinator.collectionSwitches.gameCollectionActive, "stopping share is not leaving the game")
        // Every other share-stop path leaves the game switch alone as well.
        for trigger in [PersonalLocationShareCoordinator.StopTrigger.background, .offline, .teamExit, .ban] {
            let other = try WP02Rig()
            other.coordinator.gameCollectionChanged(active: true)
            _ = await other.startSharing()
            await other.coordinator.stop(for: trigger)
            XCTAssertFalse(other.coordinator.collectionSwitches.shareActive, "\(trigger)")
        }
        // The pure model: ending the share never writes the game switch.
        var switches = PersonalLocationShareCollectionSwitches()
        switches.setGameCollection(active: true); switches.shareStarted(); switches.shareStopped()
        XCTAssertTrue(switches.gameCollectionActive); XCTAssertFalse(switches.shareActive)
    }
    func testGameLocationCollectionDoesNotImplyShareConsent() async throws {
        let rig = try WP02Rig()
        rig.coordinator.gameCollectionChanged(active: true)
        await rig.prepareAndAcknowledge()
        // Only the explicit, separately acknowledged personal-share confirmation can start sharing.
        XCTAssertFalse(rig.coordinator.collectionSwitches.shareActive)
        XCTAssertNil(rig.coordinator.publishingRequestKey)
        XCTAssertEqual(rig.provider.makes, 0); XCTAssertEqual(rig.provider.samples, 0); XCTAssertEqual(rig.service.createCalls, 0)
        // Without disclosures acknowledged, game collection alone cannot reach a confirmation ticket.
        let bare = try WP02Rig()
        bare.coordinator.gameCollectionChanged(active: true)
        await bare.coordinator.prepare(recipientId: 2)
        XCTAssertFalse(bare.coordinator.canConfirm)
        XCTAssertNil(bare.coordinator.makeConfirmationTicket(displayedRecipientId: 2, presentationId: UUID(), allowsFirstPermissionRequest: false))
        XCTAssertEqual(bare.service.createCalls, 0)
        // Game collection ending does not by itself change the share consent either way.
        var switches = PersonalLocationShareCollectionSwitches()
        switches.setGameCollection(active: true)
        XCTAssertFalse(switches.shareActive)
        switches.shareStarted(); switches.setGameCollection(active: false)
        XCTAssertTrue(switches.shareActive)
    }
}
