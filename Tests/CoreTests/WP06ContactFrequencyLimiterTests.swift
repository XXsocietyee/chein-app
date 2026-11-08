import XCTest
@testable import QuestifyCore

final class WP06ContactFrequencyLimiterTests: XCTestCase {
    private final class Clock { var date = Date(timeIntervalSince1970: 1_000) }

    func testSecondContactInsideWindowRefused() {
        let clock = Clock()
        var limiter = ContactFrequencyLimiter(window: 60, now: { clock.date })
        XCTAssertEqual(limiter.attempt(peerID: 7), .allowed)
        clock.date.addTimeInterval(20)
        XCTAssertEqual(limiter.attempt(peerID: 7), .insideWindow(retryAfter: 40))
    }
    func testWindowResetsWithInjectedClock() {
        let clock = Clock()
        var limiter = ContactFrequencyLimiter(window: 60, now: { clock.date })
        XCTAssertEqual(limiter.attempt(peerID: 7), .allowed)
        clock.date.addTimeInterval(60)
        XCTAssertEqual(limiter.attempt(peerID: 7), .allowed)
    }
    func testBlockEndsContactImmediately() {
        let clock = Clock()
        var limiter = ContactFrequencyLimiter(window: 60, now: { clock.date })
        XCTAssertEqual(limiter.attempt(peerID: 7), .allowed)
        limiter.block(peerID: 7)
        clock.date.addTimeInterval(3_600)
        XCTAssertEqual(limiter.attempt(peerID: 7), .blocked)
        XCTAssertEqual(limiter.attempt(peerID: 8), .allowed)
    }
}
