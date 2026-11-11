import XCTest
@testable import Questify

/// Roam fog spec §1e / stage 3: reveal events onto the existing `CYRevealChoreographer`, with an injected clock.
@MainActor final class RevealChoreographerTests: XCTestCase {
    private final class Clock { var now: TimeInterval = 100 }

    private func cells(_ count: Int) throws -> [FogRenderCell] {
        let codes = Array(FogFixtures.revealedCodes(FogFixtures.shanghaiPeoplesSquareWalk).prefix(count))
        XCTAssertEqual(codes.count, count)
        return try codes.map { code in
            let b = try XCTUnwrap(FogGeohash.bounds(of: code))
            return FogRenderCell(code: code, south: b.south, west: b.west, north: b.north, east: b.east, state: .confirmed, datum: .gcj02)
        }
    }
    private func event(_ cells: [FogRenderCell], at clock: Clock) -> FogRevealEvent {
        FogRevealEvent(cells: cells, origin: RoamCoordinate(latitude: 31.2304, longitude: 121.4737)!, at: Date(timeIntervalSinceReferenceDate: clock.now))
    }

    func testWipesAreStaggeredAndCappedAtSixWithTheRestBakedAtOnce() throws {
        let clock = Clock()
        let choreographer = RevealChoreographer(reduceMotion: { false }, clock: { clock.now })
        let all = try cells(8)
        let baked = choreographer.enqueue(event(all, at: clock))
        XCTAssertEqual(baked, Array(all.dropFirst(6)))
        XCTAssertEqual(choreographer.wipes.map(\.cell), Array(all.prefix(6)))
        for (i, wipe) in choreographer.wipes.enumerated() {
            XCTAssertEqual(wipe.start, clock.now + Double(i) * 0.04, accuracy: 0.0001)
            XCTAssertEqual(wipe.duration, 0.48, accuracy: 0.0001)
        }
        XCTAssertEqual(choreographer.crossfadeRevision, 0)
        XCTAssertEqual(choreographer.hapticSuccessSerial, 1, "first reveal of a session is a success haptic")
    }

    func testSettleReturnsFinishedWipesForBakingAndEmptiesTheLayer() throws {
        let clock = Clock()
        let choreographer = RevealChoreographer(reduceMotion: { false }, clock: { clock.now })
        let all = try cells(3)
        choreographer.enqueue(event(all, at: clock))
        XCTAssertTrue(choreographer.settle(at: clock.now + 0.1).isEmpty)
        XCTAssertEqual(choreographer.settle(at: clock.now + 0.54), [all[0], all[1]])
        XCTAssertEqual(choreographer.settle(at: clock.now + 0.6), [all[2]])
        XCTAssertTrue(choreographer.wipes.isEmpty)
    }

    func testReduceMotionBakesEverythingAndCrossfadesOnce() throws {
        let clock = Clock()
        let choreographer = RevealChoreographer(reduceMotion: { true }, clock: { clock.now })
        let all = try cells(3)
        XCTAssertEqual(choreographer.enqueue(event(all, at: clock)), all)
        XCTAssertTrue(choreographer.wipes.isEmpty, "no keyframes under Reduce Motion")
        XCTAssertEqual(choreographer.crossfadeRevision, 1)
        XCTAssertEqual(RevealChoreographer.crossfadeDuration, 0.2, accuracy: 0.0001)
        XCTAssertEqual(choreographer.hapticSuccessSerial, 1, "haptics are unchanged")
    }

    func testLowPowerSkipsTheWipeLikeReduceMotion() throws {
        let clock = Clock()
        let choreographer = RevealChoreographer(reduceMotion: { false }, lowPower: { true }, clock: { clock.now })
        let all = try cells(2)
        XCTAssertEqual(choreographer.enqueue(event(all, at: clock)), all)
        XCTAssertTrue(choreographer.wipes.isEmpty)
        XCTAssertEqual(choreographer.crossfadeRevision, 1)
    }

    func testHapticsNeverFireCloserThan150Milliseconds() throws {
        let clock = Clock()
        let choreographer = RevealChoreographer(reduceMotion: { false }, clock: { clock.now })
        let all = try cells(4)
        var fired: [TimeInterval] = []
        var seen = 0
        for (i, offset) in [0.0, 0.05, 0.1, 0.16, 0.2, 0.4].enumerated() {
            clock.now = 100 + offset
            choreographer.enqueue(event([all[i % all.count]], at: clock))
            let total = choreographer.hapticSuccessSerial + choreographer.hapticLightSerial
            if total != seen { fired.append(clock.now); seen = total }
        }
        XCTAssertEqual(fired.count, 3, "fires at 0, 0.16 and 0.4 s; the rest fall inside the 150 ms window")
        for pair in zip(fired, fired.dropFirst()) { XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 0.15 - 0.0001) }
        XCTAssertEqual(choreographer.hapticSuccessSerial, 1)
    }

    func testEmptyEventDoesNothing() {
        let clock = Clock()
        let choreographer = RevealChoreographer(reduceMotion: { false }, clock: { clock.now })
        XCTAssertTrue(choreographer.enqueue(event([], at: clock)).isEmpty)
        XCTAssertEqual(choreographer.hapticSuccessSerial + choreographer.hapticLightSerial, 0)
    }
}
