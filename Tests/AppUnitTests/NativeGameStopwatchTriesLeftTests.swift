import XCTest
@testable import Questify

/// MP playkit-stopwatch `sw__cap` 还有 N 次机会: the count follows the server's cap and attempts.
@MainActor final class NativeGameStopwatchTriesLeftTests: XCTestCase {
    func testTriesLeftFollowsTheServerCap() {
        let capped: PlayWireValue = .object(["maxTries": .int(3), "attempts": .int(1)])
        XCTAssertEqual(NativeGameTimedKit.triesLeft(segment: capped), 2)
        let attemptsCap: PlayWireValue = .object(["maxAttempts": .int(2), "attempts": .int(5)])
        XCTAssertEqual(NativeGameTimedKit.triesLeft(segment: attemptsCap), 0)
        let fresh: PlayWireValue = .object(["maxTries": .int(3)])
        XCTAssertEqual(NativeGameTimedKit.triesLeft(segment: fresh), 3)
    }

    func testUncappedStopwatchShowsNoCount() {
        XCTAssertNil(NativeGameTimedKit.triesLeft(segment: .object(["attempts": .int(1)])))
        XCTAssertNil(NativeGameTimedKit.triesLeft(segment: .object(["maxTries": .int(0)])))
    }
}
