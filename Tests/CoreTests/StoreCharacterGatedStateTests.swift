#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore

@MainActor private final class GatedCharacterReader: StoreCharacterReading {
    var scope = UUID(), isAuthenticated = true
    func access() async throws -> MerchantOperationsAccess {
        try JSONDecoder().decode(MerchantOperationsAccess.self, from: Data(#"{"active":true,"merchant":{"id":31},"roleCode":"MERCHANT_OWNER","permissions":["merchant:profile:write"]}"#.utf8))
    }
    func profile() async throws -> StoreCharacterProfile { StoreCharacterProfile() }
    func voiceStatus() async throws -> StoreCharacterVoiceState { throw StoreCharacterFailure.notConfigured }
    func mapPoint() async throws -> StoreCharacterMapPointState { throw StoreCharacterFailure.notConfigured }
}

/// Production ships with every NPC write gate off: the screen must say so instead of pretending to save.
@MainActor final class StoreCharacterGatedStateTests: XCTestCase {
    func testGatedFieldSaveShowsHonestNoticeAndNeverPreparesAConfirmation() async {
        let owner = StoreCharacterCoordinator(reader: GatedCharacterReader())
        await owner.load()
        XCTAssertEqual(owner.phase, .ready)
        XCTAssertFalse(owner.canSave)
        owner.editField(.name)
        owner.updateField("Synthetic shop")
        owner.saveField()
        XCTAssertEqual(owner.notice, .writesDisabled)
        XCTAssertNil(owner.saveConfirmation)
        XCTAssertFalse(owner.saving)
    }

    func testPhotoUploadIsAnHonestUnavailableNotice() async {
        let owner = StoreCharacterCoordinator(reader: GatedCharacterReader())
        await owner.load()
        owner.openAvatar()
        owner.choosePhoto()
        XCTAssertEqual(owner.notice, .photoUnavailable)
        XCTAssertNil(owner.saveConfirmation)
    }

    func testVoiceIsBlockedUntilAProfileIsSaved() async {
        let owner = StoreCharacterCoordinator(reader: GatedCharacterReader())
        await owner.load()
        await owner.openVoice()
        XCTAssertEqual(owner.notice, .saveProfileFirst)
        XCTAssertFalse(owner.voiceVisible)
        XCTAssertFalse(owner.canEnroll)
    }
}
#endif
