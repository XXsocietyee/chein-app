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

    func testPhotoReferenceStaysUnavailableWhenSavesAreOff() async {
        let owner = StoreCharacterCoordinator(reader: GatedCharacterReader(), syntheticPhoto: "https://fixture.example/npc.png")
        await owner.load()
        let before = owner.selection
        owner.choosePhoto()
        XCTAssertEqual(owner.notice, .photoUnavailable)
        XCTAssertNil(owner.saveConfirmation)
        XCTAssertEqual(owner.selection, before)
    }

    func testPhotoReferenceSelectsOnlyWhenSavesAreOn() async {
        var gates = MerchantCityNPCParityGates()
        gates.storeCharacterSaves = true
        let owner = StoreCharacterCoordinator(reader: GatedCharacterReader(), writer: RM01UnusedCharacterWriter(), gates: gates, syntheticPhoto: "https://fixture.example/npc.png")
        await owner.load()
        owner.choosePhoto()
        XCTAssertNil(owner.notice)
        XCTAssertEqual(owner.selection, .photo("https://fixture.example/npc.png"))
        XCTAssertNil(owner.saveConfirmation)
    }

    func testVoiceEnrollStaysDisabledWithoutEnrollmentSwitch() async throws {
        let sample = try XCTUnwrap(StoreCharacterRecordedSample(url: "https://fixture.example/voice.m4a", durationSeconds: 10, byteCount: 128))
        let owner = StoreCharacterCoordinator(reader: SavedCharacterReader(), syntheticRecording: sample)
        await owner.load()
        await owner.openVoice()
        owner.setVoiceConsent(true)
        owner.useSyntheticRecording()
        owner.prepareEnroll()
        XCTAssertEqual(owner.voiceIssue, .writesDisabled)
        XCTAssertNil(owner.voiceConfirmation)
        XCTAssertFalse(owner.canEnroll)
    }
}

@MainActor private final class SavedCharacterReader: StoreCharacterReading {
    var scope = UUID()
    var isAuthenticated = true
    func access() async throws -> MerchantOperationsAccess {
        try JSONDecoder().decode(MerchantOperationsAccess.self, from: Data(#"{"active":true,"merchant":{"id":31},"roleCode":"MERCHANT_OWNER","permissions":["merchant:profile:write"]}"#.utf8))
    }
    func profile() async throws -> StoreCharacterProfile {
        var value = StoreCharacterProfile()
        value.name = "Shop"
        value.avatar = "px1:p01"
        return value
    }
    func voiceStatus() async throws -> StoreCharacterVoiceState { throw StoreCharacterFailure.notConfigured }
    func mapPoint() async throws -> StoreCharacterMapPointState { throw StoreCharacterFailure.notConfigured }
}

@MainActor private final class RM01UnusedCharacterWriter: StoreCharacterWriting {
    func save(_: StoreCharacterSavePayload, requestID _: UUID) async throws {}
    func recordVoiceConsent(_: StoreCharacterVoiceConsentRecord) async throws {}
    func enroll(_: StoreCharacterVoiceEnrollment, requestID _: UUID) async throws -> StoreCharacterVoiceState.Status { .none }
    func resetVoice(requestID _: UUID) async throws {}
    func saveMapPoint(_: StoreCharacterMapPointWrite, requestID _: UUID) async throws {}
}
#endif
