import XCTest
@testable import Questify

@MainActor final class IMCoopInviteStripFactoryTests: XCTestCase {
    func testNoCooperationReaderMeansNoStrip() {
        XCTAssertNil(IMCoopInviteStripFactory.make(reader: nil))
    }
    #if DEBUG
    func testReaderProducesAStripFactory() {
        XCTAssertNotNil(IMCoopInviteStripFactory.make(reader: CooperationFixtureReader(scenario: .content)))
    }
    #endif
}
