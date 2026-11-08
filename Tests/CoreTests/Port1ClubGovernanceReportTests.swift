import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1ClubGovernanceReportTests: XCTestCase {
    typealias P = ClubGovernanceReportPort
    func testTypeKeyFallsBackToMember() {
        XCTAssertEqual(P.typeKey("CLUB"), "CLUB"); XCTAssertEqual(P.typeKey("ACTIVITY"), "ACTIVITY")
        XCTAssertEqual(P.typeKey("MEMBER"), "MEMBER"); XCTAssertEqual(P.typeKey(nil), "MEMBER"); XCTAssertEqual(P.typeKey("x"), "MEMBER")
    }
    func testDisplayNameCollapsesWhitespaceAndClips() {
        XCTAssertEqual(P.displayName("  夜跑 \n 09-24  "), "夜跑 09-24")
        XCTAssertNil(P.displayName("   ")); XCTAssertNil(P.displayName(nil))
        XCTAssertEqual(P.displayName(String(repeating: "a", count: 60))?.count, 40)
        XCTAssertEqual(P.quotedName("夜跑"), "「夜跑」")
    }
    func testReasonValidationAndKeys() {
        XCTAssertFalse(P.reasonIsValid(" \n")); XCTAssertTrue(P.reasonIsValid(" x "))
        XCTAssertEqual(P.reasonRequiredKey(.transfer), "clubOpsGov.reasonRequired.transfer")
        XCTAssertEqual(P.ReasonMode.allCases.count, 4)
    }
}
#endif
