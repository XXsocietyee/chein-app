import XCTest
@testable import QuestifyCore

final class PlayIndexPageReadinessTests: XCTestCase {
    private func snapshot(_ raw: String) throws -> PlaySnapshot {
        try .init(scope: .activity(41), result: JSONDecoder().decode(PlayNodesResult.self, from: Data(raw.utf8)))
    }

    func testUnknownMarkIsAnEmDash() {
        XCTAssertEqual(PlayIndexPageReadiness.unknownMark, "\u{2014}")
        XCTAssertNotEqual(PlayIndexPageReadiness.unknownMark, "0")
        XCTAssertNotEqual(PlayIndexPageReadiness.unknownMark, "-")
    }

    func testLoadingHidesAnyCount() throws {
        let state = PlayIndexPageReadiness(phase: "loading", readsEnabled: true, unresolved: false, snapshot: try snapshot(PlayExperienceSyntheticFixtures.classic))
        XCTAssertEqual(state.kind, .loading)
        XCTAssertEqual(state.titleKey, "playx.loading")
        XCTAssertEqual(state.accessibilityIdentifier, "playx.loading")
        XCTAssertEqual(state.progressText, "—")
    }

    func testDisabledReadsStayHiddenEmpty() throws {
        let state = PlayIndexPageReadiness(phase: "failed", readsEnabled: false, unresolved: false, snapshot: try snapshot(PlayExperienceSyntheticFixtures.classic))
        XCTAssertEqual(state.kind, .empty)
        XCTAssertEqual(state.titleKey, "playx.disabled.title")
        XCTAssertEqual(state.accessibilityIdentifier, "playx.disabled")
        XCTAssertEqual(state.progressText, "—")
    }

    func testMissingSnapshotIsAnErrorWhenReadsAreOn() {
        let state = PlayIndexPageReadiness(phase: "idle", readsEnabled: true, unresolved: false, snapshot: nil)
        XCTAssertEqual(state.kind, .error)
        XCTAssertEqual(state.titleKey, "playx.error.title")
        XCTAssertEqual(state.accessibilityIdentifier, "playx.issue")
        XCTAssertEqual(state.progressText, "—")
    }

    func testUnknownPhaseWithoutSnapshotStaysUnknown() {
        let state = PlayIndexPageReadiness(phase: "unknown", readsEnabled: true, unresolved: false, snapshot: nil)
        XCTAssertEqual(state.kind, .unknown)
        XCTAssertEqual(state.progressText, "—")
        XCTAssertEqual(state.accessibilityIdentifier, "referenceTask.phaseOnly")
    }

    func testEmptyRouteIsNotAZero() throws {
        let state = PlayIndexPageReadiness(phase: "ready", readsEnabled: true, unresolved: false, snapshot: try snapshot(#"{"playable":true,"registered":true,"total":0,"doneCount":0,"nodes":[]}"#))
        XCTAssertEqual(state.kind, .empty)
        XCTAssertEqual(state.titleKey, "play.empty")
        XCTAssertEqual(state.accessibilityIdentifier, "play.status")
        XCTAssertEqual(state.progressText, "—")
    }

    func testKnownZeroOfOneStaysNumeric() throws {
        let state = PlayIndexPageReadiness(phase: "ready", readsEnabled: true, unresolved: false, snapshot: try snapshot(PlayExperienceSyntheticFixtures.classic))
        XCTAssertEqual(state.kind, .ready)
        XCTAssertEqual(state.progressText, "0/1")
        XCTAssertEqual(state.accessibilityIdentifier, "referenceTask.count")
    }

    func testCompletedCountStaysTheServerTotal() throws {
        let state = PlayIndexPageReadiness(phase: "ready", readsEnabled: true, unresolved: false, snapshot: try snapshot(PlayExperienceSyntheticFixtures.complete))
        XCTAssertEqual(state.kind, .ready)
        XCTAssertEqual(state.progressText, "1/1")
    }

    func testMissingOrInconsistentTotalsStayAnEmDash() throws {
        let missing = PlayIndexPageReadiness(phase: "ready", readsEnabled: true, unresolved: false, snapshot: try snapshot(#"{"playable":true,"doneCount":0,"nodes":[{"nodeId":1,"done":false}]}"#))
        let inconsistent = PlayIndexPageReadiness(phase: "ready", readsEnabled: true, unresolved: false, snapshot: try snapshot(#"{"playable":true,"total":1,"doneCount":2,"nodes":[{"nodeId":1}]}"#))
        XCTAssertEqual(missing.kind, .ready)
        XCTAssertEqual(missing.progressText, "—")
        XCTAssertEqual(missing.accessibilityIdentifier, "referenceTask.phaseOnly")
        XCTAssertEqual(inconsistent.progressText, "—")
    }

    func testUnresolvedOutcomeDoesNotShowTheLastCount() throws {
        let state = PlayIndexPageReadiness(phase: "submitting", readsEnabled: true, unresolved: true, snapshot: try snapshot(PlayExperienceSyntheticFixtures.classic))
        XCTAssertEqual(state.kind, .unknown)
        XCTAssertEqual(state.titleKey, "playx.unknown.title")
        XCTAssertEqual(state.progressText, "—")
        XCTAssertNotEqual(state.progressText, "0/1")
    }

    func testUnknownAvailabilityDoesNotGuessZero() throws {
        let state = PlayIndexPageReadiness(phase: "ready", readsEnabled: true, unresolved: false, snapshot: try snapshot(#"{"registered":true,"total":1,"doneCount":0,"nodes":[{"nodeId":1,"done":false}]}"#))
        XCTAssertEqual(state.kind, .unknown)
        XCTAssertEqual(state.progressText, "—")
    }

    func testFailedReadbackDoesNotKeepACount() throws {
        let state = PlayIndexPageReadiness(phase: "failed", readsEnabled: true, unresolved: false, snapshot: try snapshot(PlayExperienceSyntheticFixtures.classic))
        XCTAssertEqual(state.kind, .error)
        XCTAssertEqual(state.progressText, "—")
    }

    func testUnknownWordDoesNotDecodeAsZero() {
        let raw = #"{"playable":true,"total":"UNKNOWN","doneCount":"UNKNOWN","nodes":[]}"#
        XCTAssertThrowsError(try JSONDecoder().decode(PlayNodesResult.self, from: Data(raw.utf8)))
        let state = PlayIndexPageReadiness(phase: "failed", readsEnabled: true, unresolved: false, snapshot: nil)
        XCTAssertEqual(state.kind, .error)
        XCTAssertEqual(state.progressText, "—")
        XCTAssertFalse(state.progressText.contains("0"))
    }

    func testNumericStringZeroRemainsARealZero() throws {
        let state = PlayIndexPageReadiness(phase: "ready", readsEnabled: true, unresolved: false, snapshot: try snapshot(#"{"playable":true,"registered":true,"total":"1","doneCount":"0","nodes":[{"nodeId":1,"done":false}]}"#))
        XCTAssertEqual(state.kind, .ready)
        XCTAssertEqual(state.progressText, "0/1")
    }
}
