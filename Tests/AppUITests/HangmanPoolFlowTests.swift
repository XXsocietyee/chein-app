import XCTest

/// `letterPoolGame` is registered on `ModuleFixture`. This package does not launch the host.
/// The pool rules stay in HangmanPoolTests.
final class HangmanPoolFlowTests: XCTestCase {
    func testLetterPoolFlowNeedsTheUnownedFixtureHost() throws {
        throw XCTSkip("letterPoolGame is registered in ModuleFixtureSupport; this package does not launch the host")
    }
}
