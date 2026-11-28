import XCTest
@testable import Questify

/// MP topic-detail director.js:378-385 `classifyLoadError` → wxml:163-171 load states.
@MainActor
final class ClubTopicDirectorLoadStateTests: XCTestCase {
    func testNotFoundIsTheEmptyState() {
        XCTAssertEqual(ClubTopicDirectorEmbeddedMount.loadState(phase: "rejected", issue: .rejected(404, nil)), .empty(nil))
        XCTAssertEqual(ClubTopicDirectorEmbeddedMount.loadState(phase: "rejected", issue: .rejected(404, "场次不存在")), .empty("场次不存在"))
    }

    func testRefusalShowsTheServerSentence() {
        XCTAssertEqual(ClubTopicDirectorEmbeddedMount.loadState(phase: "rejected", issue: .rejected(403, "无权限")), .failed("无权限"))
        XCTAssertEqual(ClubTopicDirectorEmbeddedMount.loadState(phase: "rejected", issue: .rejected(500, "  ")), .failed(nil))
    }

    func testTransportFailureIsTheNetworkState() {
        XCTAssertEqual(ClubTopicDirectorEmbeddedMount.loadState(phase: "failed", issue: .unknownResult), .network)
        XCTAssertEqual(ClubTopicDirectorEmbeddedMount.loadState(phase: "failed", issue: .malformed), .failed(nil))
    }

    func testOtherPhasesRenderNoLoadState() {
        for phase in ["idle", "loading", "ready", "disabled", "stale"] {
            XCTAssertNil(ClubTopicDirectorEmbeddedMount.loadState(phase: phase, issue: nil))
        }
    }
}
