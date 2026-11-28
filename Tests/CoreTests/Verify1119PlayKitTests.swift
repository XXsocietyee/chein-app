import XCTest
@testable import QuestifyCore

/// verify-1119 items that live in the P4 kit files: howTo, reference image, and the five stage events.
/// Photo RECORD, completion mode, run start and quote validity belong to other packages.
@MainActor final class Verify1119PlayKitTests: XCTestCase {
    private func wire(_ json: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(json.utf8)) }
    private let slots = #""slots":[{"i":0,"kind":"BLANK"},{"i":1,"kind":"BLANK"}]"#

    func testHangmanHowToIsDecodedAndHiddenWhenAbsentOrBlank() throws {
        let note = try PlayKitHangmanProjection(validated: try wire("{\(slots),\"howTo\":\"一格一个字母，V＝ü\"}"))
        XCTAssertEqual(note.howTo, "一格一个字母，V＝ü")
        XCTAssertNil(try PlayKitHangmanProjection(validated: try wire("{\(slots)}")).howTo)
        XCTAssertNil(try PlayKitHangmanProjection(validated: try wire("{\(slots),\"howTo\":\"  \"}")).howTo)
    }

    func testReferenceImageSourceAcceptsBothKeysAndIgnoresBlank() throws {
        XCTAssertEqual(PlayKitReferenceImage.source(in: try wire(#"{"referenceImage":"https://a.example/r.png"}"#)), "https://a.example/r.png")
        XCTAssertEqual(PlayKitReferenceImage.source(in: try wire(#"{"referenceImageUrl":" https://a.example/s.png "}"#)), "https://a.example/s.png")
        XCTAssertEqual(PlayKitReferenceImage.alt(in: try wire(#"{"referenceImageAlt":" 门楣 "}"#)), "门楣")
        XCTAssertNil(PlayKitReferenceImage.source(in: try wire(#"{"referenceImage":""}"#)))
        XCTAssertNil(PlayKitReferenceImage.source(in: try wire(#"{"prompt":"x"}"#)))
        XCTAssertNil(PlayKitReferenceImage.alt(in: try wire(#"{"referenceImageAlt":" "}"#)))
    }

    func testStageEventNamesAreTheFiveAllowListedCodes() {
        XCTAssertEqual(Set(PlayStageEvent.allCases.map(\.rawValue)),
                       ["stage_enter", "hint_open", "stage_skip", "stage_issue_report", "material_view"])
        XCTAssertEqual(Set(PlayStageIssueKind.allCases.map(\.rawValue)), ["ALT_MATERIAL", "NOT_FOUND", "UNREADABLE", "LOGIC_ERROR"])
        XCTAssertTrue(PlayStageAnalyticsGate.enabled) // PLAY-r11-3: MP utils/stage-events.js:36-50
        XCTAssertTrue(PlayStageEvent.allCases.allSatisfy { AnalyticsEventClient.allowedEvents.contains($0.rawValue) })
    }

    func testStagePropertiesCarryOnlyCodes() {
        let fields = PlayStageAnalytics.properties(nodeID: 42, kit: "qa", issueKind: .notFound)
        XCTAssertEqual(fields["nodeId"], .int(42))
        XCTAssertEqual(fields["kit"], .string("qa"))
        XCTAssertEqual(fields["issueKind"], .string("NOT_FOUND"))
        XCTAssertEqual(Set(fields.keys), ["issueKind", "kit", "nodeId"])
        XCTAssertNil(PlayStageAnalytics.properties(nodeID: 0, kit: "", issueKind: nil)["nodeId"])
        XCTAssertTrue(PlayStageAnalytics.properties(nodeID: nil, kit: nil, issueKind: nil).isEmpty)
    }

    func testIssueReportNeedsAKindAndAClosedGateSendsNothing() {
        XCTAssertFalse(PlayStageAnalytics.track(nil, .stageIssueReport, nodeID: 1, kit: "qa", gate: true))
        XCTAssertFalse(PlayStageAnalytics.track(nil, .stageEnter, nodeID: 1, kit: "qa", gate: false))
        XCTAssertFalse(PlayStageAnalytics.track(nil, .materialView, nodeID: 1, kit: "hangman"))
        XCTAssertEqual(PlayStageAnalytics.pagePath, "/pages/play/index")
        XCTAssertEqual(PlayStageAnalytics.bizType, "topic_node")
    }
}
