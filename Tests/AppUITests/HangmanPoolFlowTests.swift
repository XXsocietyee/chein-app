import XCTest

/// The letter-pool UI fixture host lives in ModuleFixtureSupport, which this package does not own.
/// The flow is covered by HangmanPoolTests until that host can register `letterPoolGame`.
final class HangmanPoolFlowTests: XCTestCase {
    func testLetterPoolFlowNeedsTheUnownedFixtureHost() throws {
        throw XCTSkip("letterPoolGame fixture host is outside P4 (ModuleFixtureSupport)")
    }
}
