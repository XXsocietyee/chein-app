import XCTest
@testable import QuestifyCore

/// MP `publish/fabu/theme-media.js` `uploadThemeAudio` / `clearThemeAudio` (主题配乐, topic-detail-sheet.wxml:70-77).
@MainActor final class ProjectThemeAudioTests: XCTestCase {
    private let session = try! ProjectEditSession(accountID: 7, epoch: 1, storageNamespace: "theme-audio-tests")
    private let identity = try! ProjectEditDraftIdentity(topicID: 202)
    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
    }
    private func receipt(_ length: Int = 40) throws -> ProjectStoryUploadedAudio {
        let prefix = "https://example.com/"
        return try .restore(attemptID: UUID(), ownerKey: session.ownerKey,
            reference: prefix + String(repeating: "a", count: max(0, length - prefix.utf16.count)), filename: "bgm.mp3", format: .mp3)
    }
    func testApplySetsTopicAudioAndResetsDurationLikeTheMiniProgram() throws {
        var draft = ProjectEditSyntheticFixtures.draft()
        draft.preserved["audioUrl"] = .string("old.mp3"); draft.preserved["audioDuration"] = .number(42)
        draft.chapters[0].preserved["audioUrl"] = .string("chapter-stays.mp3")
        let target = try ProjectStoryAudioTarget(themeMusicIn: draft, identity: identity, session: session)
        XCTAssertEqual(target.kind, .themeMusic); XCTAssertTrue(target.chapterID.isEmpty); XCTAssertNil(target.blockID)
        XCTAssertTrue(target.hasValidDestination)
        let receipt = try receipt(512)
        let next = try target.applying(receipt, to: draft, identity: identity, session: session)
        XCTAssertEqual(next.preserved["audioUrl"], .string(receipt.reference))
        XCTAssertEqual(next.preserved["audioDuration"], .number(0))
        XCTAssertEqual(next.chapters[0].preserved["audioUrl"], .string("chapter-stays.mp3"))
        XCTAssertTrue(target.hasAppliedReference(receipt, in: next, identity: identity, session: session))
        XCTAssertThrowsError(try target.applying(self.receipt(513), to: draft, identity: identity, session: session))
        var changed = draft; changed.name += "!"
        XCTAssertThrowsError(try target.applying(receipt, to: changed, identity: identity, session: session))
    }
    func testClearMatchesClearThemeAudioAndKeepsUnsupportedValues() throws {
        var draft = ProjectEditSyntheticFixtures.draft()
        draft.preserved["audioUrl"] = .string("bgm.mp3"); draft.preserved["audioDuration"] = .number(30)
        XCTAssertTrue(ProjectThemeAudio.hasAudio(in: draft))
        let cleared = try ProjectThemeAudio.clearing(in: draft)
        XCTAssertEqual(cleared.preserved["audioUrl"], .string("")); XCTAssertEqual(cleared.preserved["audioDuration"], .number(0))
        XCTAssertFalse(ProjectThemeAudio.hasAudio(in: cleared))
        draft.preserved["audioUrl"] = .object(["future": .bool(true)])
        XCTAssertTrue(ProjectThemeAudio.isUnsupported(in: draft))
        XCTAssertThrowsError(try ProjectThemeAudio.clearing(in: draft))
        XCTAssertThrowsError(try ProjectStoryAudioTarget(themeMusicIn: draft, identity: identity, session: session))
    }
    func testThemeTargetRoundTripsAndRejectsChapterOrBlockShape() throws {
        let draft = ProjectEditSyntheticFixtures.draft()
        let target = try ProjectStoryAudioTarget(themeMusicIn: draft, identity: identity, session: session)
        let data = try encoded(target), object = try JSONDecoder().decode([String: ProjectEditJSON].self, from: data)
        XCTAssertEqual(object["kind"], .string("themeMusic")); XCTAssertNil(object["blockID"])
        XCTAssertEqual(try JSONDecoder().decode(ProjectStoryAudioTarget.self, from: data), target)
        var withBlock = object; withBlock["blockID"] = .string("fake")
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectStoryAudioTarget.self, from: encoded(withBlock)))
        var withChapter = object; withChapter["chapterID"] = .string(draft.chapters[0].id)
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectStoryAudioTarget.self, from: encoded(withChapter)))
    }
    func testThemeJournalUsesItsOwnKeyAndRefusesOtherKinds() throws {
        let storage = ProjectEditMemoryStorage(), blockJournal = ProjectStoryAudioJournal(storage: storage)
        let themeJournal = blockJournal.themeMusicJournal()
        XCTAssertTrue(themeJournal === blockJournal.themeMusicJournal())
        let draft = ProjectEditSyntheticFixtures.draft(), digest = String(repeating: "a", count: 64)
        let target = try ProjectStoryAudioTarget(themeMusicIn: draft, identity: identity, session: session)
        let snapshot = try themeJournal.begin(target: target, digest: digest, expected: themeJournal.read(session: session, identity: identity),
                                              session: session, identity: identity)
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(try themeJournal.read(session: session, identity: identity).entries[0].target, target)
        XCTAssertTrue(storage.data.keys.allSatisfy { $0.hasPrefix("project-theme-audio.v1.") })
        XCTAssertEqual(try blockJournal.read(session: session, identity: identity).entries.count, 0)
        let chapterJournal = blockJournal.chapterNarrationJournal()
        XCTAssertThrowsError(try chapterJournal.begin(target: target, digest: digest, expected: chapterJournal.read(session: session, identity: identity),
                                                      session: session, identity: identity))
    }
}
