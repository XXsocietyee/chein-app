import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1ClubHostApplyTests: XCTestCase {
    func testCapabilityCountCountsOnlyTheFourSelfAssessmentFlags() {
        XCTAssertEqual(ClubHostApplyPort.capabilityCount([:]), 0)
        XCTAssertEqual(ClubHostApplyPort.capabilityCount(["canNpc": true, "canDesignRoute": true, "hasGuideCert": true, "canDesignTask": false]), 2)
    }
    func testSizeValidation() {
        XCTAssertTrue(ClubHostApplyPort.isValidSize(""))
        XCTAssertTrue(ClubHostApplyPort.isValidSize(" 40 "))
        XCTAssertFalse(ClubHostApplyPort.isValidSize("-3"))
        XCTAssertFalse(ClubHostApplyPort.isValidSize("many"))
        XCTAssertEqual(ClubHostApplyPort.invalidSizeKeys(["maxEventSize": "5", "avgEventSize": "x"]), ["avgEventSize"])
    }
    func testStepGatingAndReview() {
        XCTAssertFalse(ClubHostApplyPort.canAdvance(step: 1, text: ["leaderName": "  ", "phone": "1"]))
        XCTAssertTrue(ClubHostApplyPort.canAdvance(step: 1, text: ["leaderName": "A", "phone": "1"]))
        XCTAssertFalse(ClubHostApplyPort.canAdvance(step: 2, text: ["experience": "", "maxEventSize": ""]))
        XCTAssertFalse(ClubHostApplyPort.canAdvance(step: 2, text: ["experience": "1-5场", "avgEventSize": "-1"]))
        XCTAssertTrue(ClubHostApplyPort.canAdvance(step: 3, text: [:]))
        XCTAssertTrue(ClubHostApplyPort.canReview(text: ["leaderName": "A", "phone": "1", "maxEventSize": "10"]))
        XCTAssertFalse(ClubHostApplyPort.canReview(text: ["leaderName": "A", "phone": "1", "maxEventSize": "-10"]))
    }
}
#endif
