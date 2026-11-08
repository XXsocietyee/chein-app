import XCTest
@testable import QuestifyCore

final class Port6PlayResyncTests: XCTestCase {
    func testOffersResyncOnlyForReadSideIssues() {
        XCTAssertFalse(PlayResyncPort.offersResync(for: nil))
        for issue in [PlayExperienceError.staleSession, .malformed, .unknownResult, .persistenceUnavailable] {
            XCTAssertTrue(PlayResyncPort.offersResync(for: issue), "\(issue)")
        }
        for issue in [PlayExperienceError.disabled, .busy, .invalidAction, .unsupported, .unauthorized, .rejected(1, "x")] {
            XCTAssertFalse(PlayResyncPort.offersResync(for: issue), "\(issue)")
        }
    }
}
