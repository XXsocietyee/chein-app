import XCTest
@testable import QuestifyCore

/// U10 playkits: hangman, accusation and album projections, and the one-sheet rule.
final class PlayKitQuestoContractsTests: XCTestCase {
    private func wire(_ text: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(text.utf8)) }

    private func state(_ extra: String) throws -> PlayAdvancedState {
        try PlayAdvancedState(wire(#"{"sessionId":1,"nodeId":2,"version":3,"activityId":0,"topicId":4,"status":"RUNNING""# + extra + "}"))
    }

    func testHangmanFillsEditableCellsInOrderAndBuildsSlotsPayload() throws {
        let hangman = PlayKitHangmanProjection(segment: try wire(#"""
        {"title":"猜","slots":[{"i":0,"kind":"PREFILLED","ch":"E"},{"i":1,"kind":"BLANK"},{"i":2,"kind":"SEPARATOR","ch":" "},
        {"i":3,"kind":"FILLED","ch":"A"},{"i":4,"kind":"BLANK","ch":"leak"}],"solved":false,"display":"secret"}
        """#))
        XCTAssertEqual(hangman.blankCount, 3)
        XCTAssertEqual(hangman.display, "", "display is only shown once solved")
        XCTAssertEqual(hangman.slots.last?.character, "", "a blank slot never carries a character")
        XCTAssertEqual(hangman.groups(typed: [:]).count, 2, "a space separator splits words without drawing a glyph")
        XCTAssertEqual(hangman.initialText, "", "the leading run stops at the first empty editable cell")
        let typed = hangman.distribute("x y😀z")
        XCTAssertEqual(typed, [1: "x", 3: "y", 4: "😀"])
        XCTAssertEqual(hangman.payload(typed: typed), ["slots": .object(["1": .string("x"), "3": .string("y"), "4": .string("😀")])])
        XCTAssertNil(hangman.payload(typed: [1: "x"]), "a missing blank keeps the submit off; FILLED counts as typed")
        XCTAssertEqual(hangman.payload(typed: [1: "x", 4: "z"]), ["slots": .object(["1": .string("x"), "3": .string("A"), "4": .string("z")])])
    }

    func testAccusationOnlyForPickQaWithAccusationEnabledAndReadsServerVerdict() throws {
        let off = try state(#","playKit":{"qa":{"mode":"PICK","options":[{"id":"a","label":"A"}]}}"#)
        XCTAssertNil(PlayKitAccusationProjection.project(state: off))
        let typeMode = try state(#","playKit":{"qa":{"mode":"TYPE"}},"accusation":{"enabled":true}"#)
        XCTAssertNil(PlayKitAccusationProjection.project(state: typeMode))
        let open = try state(#"""
        ,"readyForBase":true,"playKit":{"qa":{"mode":"PICK","title":"谁？","attempts":1,"finished":false,"lastFeedback":"再查查",
        "options":[{"id":"a","label":"古董店老板"},{"id":"b","label":"B"}]}},
        "accusation":{"enabled":true,"suspects":[{"id":"a","identity":"钟楼对面","avatar":"http://x/a.png","testimony":[{"text":"那晚十点我在店里盘点。"}]},{"id":"b","name":"乙"}]},
        "clues":[{"id":7,"scope":"run","name":"钥匙","sources":[{"blocks":[{"text":"铜色","images":["https://cdn.example/k.png"]}]}]}]
        """#)
        let accusation = try XCTUnwrap(PlayKitAccusationProjection.project(state: open))
        XCTAssertEqual(accusation.suspects.map(\.name), ["古董店老板", "乙"], "the qa option label fills a missing name")
        XCTAssertNil(accusation.suspects[0].avatar, "http artwork is not drawn")
        XCTAssertEqual(accusation.suspects[0].initial, "古")
        XCTAssertEqual(accusation.clues, [.init(id: "7:run", name: "钥匙", text: "铜色", image: "https://cdn.example/k.png")])
        XCTAssertTrue(accusation.wrongAttempt)
        XCTAssertEqual(accusation.retryNote, "再查查")
        XCTAssertFalse(accusation.showsEnding, "readyForBase is never read as success")

        let pending = try state(#","playKit":{"qa":{"mode":"PICK","finished":true,"passed":true}},"accusation":{"enabled":true}"#)
        XCTAssertTrue(try XCTUnwrap(PlayKitAccusationProjection.project(state: pending)).pending)
        let early = try state(#","playKit":{"qa":{"mode":"PICK","finished":true}},"accusation":{"enabled":true,"result":{"verdict":"CORRECT","early":true,"terminal":true},"screen":["结案"]}"#)
        let ended = try XCTUnwrap(PlayKitAccusationProjection.project(state: early))
        XCTAssertEqual(ended.outcome, .early)
        XCTAssertEqual(ended.screen, [.text("结案")])
        XCTAssertTrue(ended.showsEnding)
    }

    func testAlbumShowsAuthorPhotosBeforeR5AndOnlyReceiptsAfter() throws {
        let legacy = PlayKitAlbumProjection(segment: try wire(#"{"title":"梦","images":[{"url":"https://a/1.png","line":"那天的风"},"https://a/2.png"]}"#), outcomeRulesVersion: nil)
        XCTAssertFalse(legacy.completionEnabled)
        XCTAssertEqual(legacy.photos.map(\.line), ["那天的风", ""])
        let r5Open = PlayKitAlbumProjection(segment: try wire(#"{"images":["https://a/1.png"]}"#), outcomeRulesVersion: 1)
        XCTAssertTrue(r5Open.completionEnabled)
        XCTAssertTrue(r5Open.photos.isEmpty, "author art is not player evidence")
        let r5Done = PlayKitAlbumProjection(segment: try wire(#"{"done":true,"images":["https://a/9.png"]}"#), outcomeRulesVersion: 1)
        XCTAssertEqual(r5Done.photos.map(\.url), ["https://a/9.png"])
    }

    func testHangmanAndAlbumActionsValidateAndRefuseMoneyFields() throws {
        XCTAssertEqual(PlayKitActionCatalog.actions["hangman"], Set(["SUBMIT_HANGMAN"]))
        XCTAssertEqual(PlayKitActionCatalog.actions["album"], Set(["SUBMIT_ALBUM"]))
        XCTAssertEqual(PlayKitActionCatalog.actions["qa"], Set(["SUBMIT_QA"]))
        XCTAssertNil(PlayKitActionCatalog.actions["accusation"])
        XCTAssertEqual(UGGameplay.contractExecution, "NOT_RUN")
        let open = try wire(#"{"solved":false,"slots":[{"i":0,"kind":"PREFILLED","ch":"E"},{"i":1,"kind":"BLANK"},{"i":2,"kind":"SEPARATOR","ch":" "}]}"#)
        let slots: [String: PlayWireValue] = ["slots": .object(["1": .string("N")])]
        XCTAssertNoThrow(try PlayKitInputContract.validate(kind: "hangman", action: "SUBMIT_HANGMAN", payload: slots, segment: open))
        XCTAssertEqual(try PlayKitActionCatalog.payload(kind: "hangman", action: "SUBMIT_HANGMAN", detail: slots), slots)
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "hangman", action: "SUBMIT_HANGMAN", payload: ["slots": .object(["1": .string("N")]), "amount": .int(1)], segment: open))
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "hangman", action: "SUBMIT_HANGMAN", payload: slots, segment: try wire(#"{"solved":true,"slots":[{"i":1,"kind":"BLANK"}]}"#)))
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "hangman", action: "SUBMIT_HANGMAN", payload: ["slots": .object(["1": .string("NO")])], segment: open))
        let album = try wire(#"{"done":false}"#)
        let photo = PlayKitPublishedWrites.albumDetail(imageURL: "https://cdn.example/a.jpg")
        XCTAssertNoThrow(try PlayKitInputContract.validate(kind: "album", action: "SUBMIT_ALBUM", payload: photo, segment: album))
        XCTAssertEqual(Set(photo.keys), ["imageUrls"])
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "album", action: "SUBMIT_ALBUM", payload: ["imageUrls": .array([.string("https://cdn.example/a.jpg")]), "amount": .int(1)], segment: album))
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "album", action: "SUBMIT_ALBUM", payload: ["imageUrls": .array([.string("http://cdn.example/a.jpg")])], segment: album))
        XCTAssertThrowsError(try PlayKitInputContract.validate(kind: "album", action: "SUBMIT_ALBUM", payload: photo, segment: try wire(#"{"done":true}"#)))
        XCTAssertEqual(PlayAlbumUploadOutcome.resolve(url: nil, issue: .unknownResult), .failed)
        XCTAssertEqual(PlayAlbumUploadOutcome.resolve(url: "https://cdn.example/a.jpg", issue: .rejected(400, nil)), .failed)
        XCTAssertEqual(PlayAlbumUploadOutcome.resolve(url: "https://cdn.example/a.jpg", issue: nil), .ready("https://cdn.example/a.jpg"))
        XCTAssertEqual(PlayKitPublishedWrites.accusationDetail(optionID: "a"), ["optionId": .string("a")])
    }

    func testHangmanStationTextAndDuplicateOptionLetter() throws {
        let blank = PlayKitHangmanProjection(segment: try wire(#"{"title":"  ","solved":false,"feedback":"hidden"}"#))
        XCTAssertEqual(blank.feedback, "")
        XCTAssertEqual(blank.stationTitle(question: " 一只猫 ", placeName: "站名"), "一只猫")
        XCTAssertEqual(blank.stationFeedback(passText: "过了"), "")
        let titled = PlayKitHangmanProjection(segment: try wire(#"{"title":"题面","solved":true,"feedback":" 服务端 "}#))
        XCTAssertEqual(titled.stationTitle(question: "题干", placeName: "站名"), "题面")
        XCTAssertEqual(titled.stationFeedback(passText: "站点"), "服务端")
        let fallback = PlayKitHangmanProjection(segment: try wire(#"{"solved":true}"#))
        XCTAssertEqual(fallback.stationTitle(question: "", placeName: " 钟楼 "), "钟楼")
        XCTAssertEqual(fallback.stationFeedback(passText: " 解开了 "), "解开了")
        XCTAssertEqual(PlayKitImageOption.stripDuplicateKey("A 许禾自述", key: "A"), "许禾自述")
        XCTAssertEqual(PlayKitImageOption.stripDuplicateKey("（a）许禾", key: "A"), "许禾")
        XCTAssertEqual(PlayKitImageOption.stripDuplicateKey("A. 许禾", key: "A"), "许禾")
        XCTAssertEqual(PlayKitImageOption.stripDuplicateKey("B 许禾", key: "A"), "B 许禾")
        XCTAssertEqual(PlayKitImageOption.stripDuplicateKey("A", key: "A"), "A")
        XCTAssertEqual(PlayKitImageOption.stripDuplicateKey("5 第五", key: "5"), "5 第五")
        let pictures = try XCTUnwrap(PlayKitImageOption.read(try wire(#"""
        {"options":[{"id":"1","label":"A 许禾","img":"https://cdn.example/a.jpg"},{"id":"2","t":"乙"}]}
        """#)))
        XCTAssertEqual(pictures.map(\.label), ["许禾", "乙"])
        XCTAssertEqual(pictures.map(\.key), ["A", "B"])
    }

    func testClosingThePlayKitSheetKeepsTheAdvancedPanel() {
        let open = AdvancedPlayKitPresentation(advancedOpen: true, playKitOpen: true)
        XCTAssertEqual(open.closingPlayKitSheet(), AdvancedPlayKitPresentation(advancedOpen: true, playKitOpen: false))
        XCTAssertEqual(open.closingAdvancedPanel(), AdvancedPlayKitPresentation(advancedOpen: false, playKitOpen: false))
    }
}
