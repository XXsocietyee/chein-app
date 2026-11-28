import XCTest
@testable import QuestifyCore

/// U04-01..04 (cloud-h3): compatibility verdict, declaration, added story blocks, locked stop, reading resume.
final class PlayFullStoryH3Tests: XCTestCase {
    func testUndeclaredAndMalformedAreUnconfirmedNeverSupportedOrUnsupported() throws {
        let undeclared = try XCTUnwrap(PlayContentCompatibility(raw: wire(#"{"requiredCapabilities":[{"key":"chapter.blocks","minVersion":1}],"declared":false,"platform":null,"clientVersion":null,"missingCapabilities":[],"supported":null,"source":"UNDECLARED"}"#)))
        XCTAssertEqual(undeclared.verdict, .unconfirmed(source: "UNDECLARED"))
        let malformed = try XCTUnwrap(PlayContentCompatibility(raw: wire(#"{"requiredCapabilities":[],"declared":false,"missingCapabilities":[],"supported":null,"source":"MALFORMED"}"#)))
        XCTAssertEqual(malformed.verdict, .unconfirmed(source: "MALFORMED"))
        let damaged = try XCTUnwrap(PlayContentCompatibility(raw: wire(#"{"requiredCapabilities":[],"declared":true,"missingCapabilities":[],"supported":true,"source":"DECLARED_MALFORMED"}"#)))
        XCTAssertEqual(damaged.verdict, .unconfirmed(source: "DECLARED_MALFORMED"))
        XCTAssertNil(PlayContentCompatibility(raw: .null))
        XCTAssertNil(PlayContentCompatibility(raw: try wire(#"{"declared":true,"supported":"yes","source":"DECLARED"}"#)))
    }
    func testDeclaredMissingKeepsNullDeclaredVersion() throws {
        let value = try XCTUnwrap(PlayContentCompatibility(raw: wire(#"{"requiredCapabilities":[{"key":"chapter.blocks.branch","minVersion":1}],"declared":true,"platform":"ios-native","clientVersion":"1.0","missingCapabilities":[{"key":"chapter.blocks.branch","minVersion":1,"declaredVersion":null}],"supported":false,"source":"DECLARED"}"#)))
        XCTAssertEqual(value.verdict, .unsupported([.init(key: "chapter.blocks.branch", minVersion: 1, declaredVersion: nil)]))
    }
    func testDocumentCarriesCompatibilityAndContentIdentity() throws {
        let document: PlayExperienceDocument = try wire(#"{"topicId":9,"playable":true,"nodes":[],"publishedConfigVersion":4,"contentSnapshotVersion":2,"compatibility":{"requiredCapabilities":[],"declared":true,"missingCapabilities":[],"supported":true,"source":"DECLARED"}}"#).decoded()
        XCTAssertEqual(document.contentVersion, "s2"); XCTAssertEqual(document.compatibility?.verdict, .supported)
        let old: PlayExperienceDocument = try wire(#"{"topicId":9,"playable":true,"nodes":[]}"#).decoded()
        XCTAssertNil(old.contentVersion); XCTAssertNil(old.compatibility)
    }
    func testDeclarationIsServerFormatAndOmitsUnrenderedBranch() {
        let query = PlayClientCapabilities.nodesQuery(clientVersion: "1.2.3")
        XCTAssertEqual(query["clientPlatform"], "ios-native"); XCTAssertEqual(query["clientVersion"], "1.2.3")
        let tokens = Set((query["capabilities"] ?? "").split(separator: ",").map(String.init))
        XCTAssertTrue(tokens.contains("chapter.blocks.gallery@1")); XCTAssertTrue(tokens.contains("game.coinflip@1"))
        XCTAssertTrue(tokens.contains("chapter.blocks.branch@1")) // CAP-r11-1: MP client-capabilities.js:20
        XCTAssertTrue(tokens.contains("answer.estimate@1"))
        XCTAssertTrue(tokens.contains("hangman.pool@1"))
        XCTAssertTrue(tokens.contains("qa.letterPool@1"))
        XCTAssertEqual(UGCompatibility.evaluate(required: [.init(key: "chapter.blocks", minVersion: 1)], supportedCapabilities: query["capabilities"] ?? "").supported, true)
        XCTAssertNil(PlayClientCapabilities.nodesQuery(clientVersion: "bad version!")["clientVersion"])
    }
    func testUnsupportedRejectionIsRecognisedOnlyFromServerText() {
        XCTAssertTrue(PlayContentCompatibility.isUnsupportedRejection(.rejected(500, "当前客户端缺少本局所需能力，请升级客户端")))
        XCTAssertTrue(PlayContentCompatibility.isUnsupportedRejection(.rejected(409, "CONTENT_CAPABILITY_UNSUPPORTED")))
        XCTAssertFalse(PlayContentCompatibility.isUnsupportedRejection(.rejected(409, nil)))
        XCTAssertFalse(PlayContentCompatibility.isUnsupportedRejection(.unknownResult))
    }
    func testAddedBlocksKeepAuthorOrderAltTextAndPlaceholderForUnrendered() throws {
        let chapter = try ChapterStoryDocument(raw: wire(#"{"chapterId":8,"blocks":[{"type":"cap","cap":"open","content":"Opening"},{"type":"text","who":"Ada","content":"Hi","level":2},{"type":"divider"},{"type":"gallery","altText":"Square","images":[{"url":"https://story.test/a"},{"url":"https://story.test/b","altText":"Gate"}]},{"type":"audio","url":"https://story.test/c","altText":"Words"},{"type":"branch","question":"SECRET"},{"type":"cap","cap":"end","content":"Closing"}]}"#))
        let rows = ChapterStoryProjection.segments(chapter: chapter, snapshot: try snapshot(nodes: "[]"), variables: [:])
        XCTAssertEqual(rows.map(\.content), [.line(.init(speaker: .named("Ada"), text: "Hi")), .divider, .image("https://story.test/a"), .image("https://story.test/b"), .audio("https://story.test/c")])
        XCTAssertEqual(rows[0].odd, 2); XCTAssertEqual(rows[1].odd, 0)
        XCTAssertEqual(rows.compactMap(\.alt), ["Square", "Gate", "Words"])
        XCTAssertEqual(chapter.openingLine, "Opening"); XCTAssertEqual(chapter.closingLine, "Closing")
    }
    func testLockedStopOnlyWhenTheFlowEndsAtALockedNode() throws {
        let chapter = try ChapterStoryDocument(raw: wire(#"{"chapterId":8,"blocks":[{"type":"node","nodeId":1},{"type":"node","nodeId":2}]}"#))
        XCTAssertEqual(ChapterStoryProjection.lockedStop(chapter: chapter, snapshot: try snapshot(nodes: #"[{"nodeId":1,"chapterId":8,"done":true},{"nodeId":2,"chapterId":8,"done":false,"locked":true}]"#))?.id, 2)
        XCTAssertNil(ChapterStoryProjection.lockedStop(chapter: chapter, snapshot: try snapshot(nodes: #"[{"nodeId":1,"chapterId":8,"done":false},{"nodeId":2,"chapterId":8,"done":false,"locked":true}]"#)))
    }
    func testReadingPositionNeedsIdentityAndOnlyResumesARenderedLaterSegment() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "PlayFullStoryH3Tests"))
        defaults.removePersistentDomain(forName: "PlayFullStoryH3Tests")
        let store = ChapterReadingPositionStore(defaults: defaults)
        XCTAssertNil(ChapterReadingPositionStore.key(runIdentity: "run", contentVersion: nil, chapterID: 8))
        let key = ChapterReadingPositionStore.key(runIdentity: "run", contentVersion: "s2", chapterID: 8)
        store.save("block.3", key: key)
        XCTAssertEqual(store.read(key), "block.3")
        XCTAssertNil(store.read(ChapterReadingPositionStore.key(runIdentity: "run", contentVersion: "s3", chapterID: 8)))
        XCTAssertEqual(ChapterReadingPositionStore.resumeTarget(saved: "block.3", rendered: ["cover", "block.3"]), "block.3")
        XCTAssertNil(ChapterReadingPositionStore.resumeTarget(saved: "block.3", rendered: ["block.3"]))
        XCTAssertNil(ChapterReadingPositionStore.resumeTarget(saved: "block.9", rendered: ["cover", "block.3"]))
    }
    private func wire(_ source: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(source.utf8)) }
    private func snapshot(nodes: String) throws -> PlaySnapshot {
        let data = "{\"topicId\":9,\"mode\":1,\"playable\":true,\"registered\":true,\"nodes\":\(nodes),\"chapters\":[{\"chapterId\":8,\"name\":\"Chapter\"}]}"
        return try PlaySnapshot(scope: .topic(9), result: wire(data).decoded())
    }
}
