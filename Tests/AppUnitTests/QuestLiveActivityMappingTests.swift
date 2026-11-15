import XCTest
@testable import Questify

/// Pure state mapping for the roam-walk / play-session Live Activity. No ActivityKit request is made here.
@MainActor final class QuestLiveActivityMappingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func content(_ update: QuestLiveActivityUpdate) -> QuestLiveActivityContent? {
        switch update {
        case .show(_, let content): return content
        case .end(_, _, let last): return last
        }
    }

    // MARK: Roam

    func testActiveRoamShowsDistancePlacesAndRunningTimer() {
        let update = QuestLiveActivityMapping.roam(phase: .active, hasRecord: true, distanceMeters: 1234.6, placesRevealed: 3,
                                                   elapsedSeconds: 125, now: now, previous: nil)
        guard case .show(let descriptor, let state) = update else { return XCTFail("expected show, got \(update)") }
        XCTAssertEqual(descriptor, QuestLiveActivityDescriptor(kind: .roam, key: QuestLiveActivityMapping.roamKey, title: nil))
        XCTAssertEqual(state.status, .active)
        XCTAssertEqual(state.distanceMeters, 1235)
        XCTAssertEqual(state.placesRevealed, 3)
        XCTAssertEqual(state.elapsedSeconds, 125)
        XCTAssertEqual(state.runningSince, now.addingTimeInterval(-125))
        XCTAssertNotNil(state.timerInterval)
        XCTAssertNil(state.stopName); XCTAssertNil(state.cluesTotal)
    }

    func testBackgroundRoamKeepsPreviousTimerAnchor() {
        let since = now.addingTimeInterval(-600)
        let previous = QuestLiveActivityContent(status: .active, elapsedSeconds: 300, runningSince: since, distanceMeters: 400, placesRevealed: 1)
        let update = QuestLiveActivityMapping.roam(phase: .active, hasRecord: true, distanceMeters: 520, placesRevealed: 2,
                                                   elapsedSeconds: nil, now: now, previous: previous)
        let state = content(update)
        XCTAssertEqual(state?.runningSince, since)
        XCTAssertEqual(state?.elapsedSeconds, 600)
        XCTAssertEqual(state?.distanceMeters, 520)
    }

    func testPausedRoamFreezesTimer() {
        let previous = QuestLiveActivityContent(status: .active, elapsedSeconds: 60, runningSince: now.addingTimeInterval(-90))
        for phase in [RoamLivePhase.paused, .recoveryRequired, .recovering, .finishing] {
            let update = QuestLiveActivityMapping.roam(phase: phase, hasRecord: true, distanceMeters: 10, placesRevealed: 0,
                                                       elapsedSeconds: nil, now: now, previous: previous)
            guard case .show(_, let state) = update else { return XCTFail("\(phase) should keep the activity") }
            XCTAssertEqual(state.status, .paused)
            XCTAssertNil(state.runningSince)
            XCTAssertNil(state.timerInterval)
            XCTAssertEqual(state.elapsedSeconds, 90)
        }
    }

    func testFinishedRoamEndsWithLastValuesAfterRecordClears() {
        let previous = QuestLiveActivityContent(status: .active, elapsedSeconds: 30, runningSince: now.addingTimeInterval(-42),
                                                distanceMeters: 880, placesRevealed: 4)
        let update = QuestLiveActivityMapping.roam(phase: .finished, hasRecord: false, distanceMeters: nil, placesRevealed: nil,
                                                   elapsedSeconds: nil, now: now, previous: previous)
        guard case .end(let kind, let key, let last?) = update else { return XCTFail("expected end with final values") }
        XCTAssertEqual(kind, .roam); XCTAssertEqual(key, QuestLiveActivityMapping.roamKey)
        XCTAssertEqual(last.status, .finished)
        XCTAssertEqual(last.distanceMeters, 880)
        XCTAssertEqual(last.placesRevealed, 4)
        XCTAssertEqual(last.elapsedSeconds, 42)
        XCTAssertNil(last.runningSince)
    }

    func testRoamWithoutWalkEndsImmediately() {
        for phase in [RoamLivePhase.ready, .acquiring, .unavailable, .locationDenied] {
            XCTAssertEqual(QuestLiveActivityMapping.roam(phase: phase, hasRecord: false, distanceMeters: nil, placesRevealed: nil,
                                                         elapsedSeconds: nil, now: now, previous: nil),
                           .end(.roam, key: QuestLiveActivityMapping.roamKey, last: nil))
        }
        XCTAssertEqual(QuestLiveActivityMapping.roam(phase: .active, hasRecord: false, distanceMeters: 5, placesRevealed: 0,
                                                     elapsedSeconds: 1, now: now, previous: nil),
                       .end(.roam, key: QuestLiveActivityMapping.roamKey, last: nil))
    }

    func testRoamRejectsNonFiniteDistance() {
        let previous = QuestLiveActivityContent(status: .active, distanceMeters: 77)
        let state = content(QuestLiveActivityMapping.roam(phase: .active, hasRecord: true, distanceMeters: .nan, placesRevealed: -2,
                                                          elapsedSeconds: 0, now: now, previous: previous))
        XCTAssertEqual(state?.distanceMeters, 77)
        XCTAssertEqual(state?.placesRevealed, 0)
    }

    // MARK: Play

    private func snapshot(_ json: String) throws -> PlaySnapshot {
        let result = try JSONDecoder().decode(PlayNodesResult.self, from: Data(json.utf8))
        return try PlaySnapshot(scope: .activity(41), result: result)
    }
    private let activeRoute = """
    {"topicId":7,"topicName":" Old Town ","mode":1,"playable":true,"registered":true,"total":3,"doneCount":1,
     "nodes":[{"nodeId":11,"name":"Gate","done":true},{"nodeId":12,"name":"Bell Tower","done":false},
              {"nodeId":13,"name":"Well","done":false,"locked":true}]}
    """

    func testActivePlayShowsCurrentStopCluesAndTimer() throws {
        let update = QuestLiveActivityMapping.play(key: "play:a", snapshot: try snapshot(activeRoute), clockPhase: .running,
                                                   elapsedSeconds: 75, now: now)
        guard case .show(let descriptor, let state) = update else { return XCTFail("expected show, got \(update)") }
        XCTAssertEqual(descriptor, QuestLiveActivityDescriptor(kind: .play, key: "play:a", title: "Old Town"))
        XCTAssertEqual(state.status, .active)
        XCTAssertEqual(state.stopName, "Bell Tower")
        XCTAssertEqual(state.stopIndex, 2)
        XCTAssertEqual(state.stopCount, 3)
        XCTAssertEqual(state.cluesSolved, 1)
        XCTAssertEqual(state.cluesTotal, 3)
        XCTAssertEqual(state.elapsedSeconds, 75)
        XCTAssertEqual(state.runningSince, now.addingTimeInterval(-75))
        XCTAssertNil(state.distanceMeters)
    }

    func testUntimedPlayShowsNoTimer() throws {
        let state = content(QuestLiveActivityMapping.play(key: "play:a", snapshot: try snapshot(activeRoute), clockPhase: .idle,
                                                          elapsedSeconds: 0, now: now))
        XCTAssertEqual(state?.status, .active)
        XCTAssertNil(state?.elapsedSeconds)
        XCTAssertNil(state?.timerInterval)
    }

    func testPausedPlayFreezesTimer() throws {
        let state = content(QuestLiveActivityMapping.play(key: "play:a", snapshot: try snapshot(activeRoute), clockPhase: .paused,
                                                          elapsedSeconds: 300, now: now))
        XCTAssertEqual(state?.status, .paused)
        XCTAssertEqual(state?.elapsedSeconds, 300)
        XCTAssertNil(state?.runningSince)
    }

    func testCompletedPlayEndsWithFinalProgress() throws {
        let done = """
        {"topicId":7,"topicName":"Old Town","mode":1,"playable":true,"registered":true,"total":2,"doneCount":2,
         "nodes":[{"nodeId":11,"name":"Gate","done":true},{"nodeId":12,"name":"Bell Tower","done":true}]}
        """
        let update = QuestLiveActivityMapping.play(key: "play:a", snapshot: try snapshot(done), clockPhase: .idle, elapsedSeconds: 0, now: now)
        guard case .end(.play, let key, let last?) = update else { return XCTFail("expected end with final values, got \(update)") }
        XCTAssertEqual(key, "play:a")
        XCTAssertEqual(last.status, .finished)
        XCTAssertEqual(last.cluesSolved, 2); XCTAssertEqual(last.cluesTotal, 2)
        XCTAssertNil(last.stopName); XCTAssertNil(last.stopIndex)
    }

    func testEndedRunEndsActivity() throws {
        let update = QuestLiveActivityMapping.play(key: "play:a", snapshot: try snapshot(activeRoute), clockPhase: .ended,
                                                   elapsedSeconds: 900, now: now)
        guard case .end(.play, let key, let last?) = update else { return XCTFail("expected end, got \(update)") }
        XCTAssertEqual(key, "play:a")
        XCTAssertEqual(last.elapsedSeconds, 900)
        XCTAssertNil(last.runningSince)
    }

    func testMissingOrUnavailablePlayEndsImmediately() throws {
        XCTAssertEqual(QuestLiveActivityMapping.play(key: "play:a", snapshot: nil, clockPhase: .running, elapsedSeconds: 5, now: now),
                       .end(.play, key: "play:a", last: nil))
        let unregistered = """
        {"topicId":7,"mode":1,"playable":true,"registered":false,"nodes":[{"nodeId":11,"name":"Gate","done":false}]}
        """
        XCTAssertEqual(QuestLiveActivityMapping.play(key: "play:a", snapshot: try snapshot(unregistered), clockPhase: .idle,
                                                     elapsedSeconds: 0, now: now),
                       .end(.play, key: "play:a", last: nil))
    }

    // MARK: Shared content

    func testContentRoundTripsThroughCodable() throws {
        let state = QuestLiveActivityContent(status: .paused, elapsedSeconds: 61, runningSince: nil, stopName: "Gate",
                                             stopIndex: 1, stopCount: 4, cluesSolved: 0, cluesTotal: 4)
        let decoded = try JSONDecoder().decode(QuestLiveActivityContent.self, from: try JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }

    func testDisplayText() {
        XCTAssertEqual(QuestLiveActivityText.distance(nil), "—")
        XCTAssertEqual(QuestLiveActivityText.distance(850), "850 m")
        XCTAssertEqual(QuestLiveActivityText.distance(1000), "1.0 km")
        XCTAssertEqual(QuestLiveActivityText.distance(1249), "1.2 km")
        XCTAssertEqual(QuestLiveActivityText.elapsed(75), "01:15")
        XCTAssertEqual(QuestLiveActivityText.elapsed(3_725), "1:02:05")
        XCTAssertEqual(QuestLiveActivityText.fraction(5, 3), "3/3")
        XCTAssertEqual(QuestLiveActivityText.fraction(1, 0), "—")
    }

    // MARK: Publisher wiring

    private final class Recorder: QuestLiveActivityPublishing {
        var updates: [QuestLiveActivityUpdate] = []
        func publish(_ update: QuestLiveActivityUpdate) { updates.append(update) }
    }

    private final class MemoryStorage: RoamHistoryDataStoring {
        var data: [String: Data] = [:]
        func read(key: String) throws -> Data? { data[key] }
        func write(_ value: Data, key: String) throws { data[key] = value }
    }

    func testRoamControllerPublishesEndWhenInvalidated() {
        let controller = RoamLiveSessionController(journal: RoamLiveJournal(storage: MemoryStorage()))
        let recorder = Recorder()
        controller.liveActivity = recorder
        controller.invalidate()
        XCTAssertEqual(recorder.updates.last, .end(.roam, key: QuestLiveActivityMapping.roamKey, last: nil))
    }
}
