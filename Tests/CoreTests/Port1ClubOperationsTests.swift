import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1ClubOperationsTests: XCTestCase {
    func testCounterAndLimits() {
        XCTAssertEqual(ClubOperationsPort.counter("abc", field: "description")?.limit, 200)
        XCTAssertEqual(ClubOperationsPort.counter("城市探索", field: "keywords")?.used, 4)
        XCTAssertNil(ClubOperationsPort.counter("x", field: "unknown"))
        XCTAssertTrue(ClubOperationsPort.isOverLimit(String(repeating: "a", count: 31), field: "name"))
        XCTAssertFalse(ClubOperationsPort.isOverLimit(String(repeating: "a", count: 30), field: "name"))
    }
    func testLimitsMatchDraftValidator() {
        var draft = ClubOperationsDraft()
        draft.clubType = ClubOperationsCatalog.types[0]
        draft.name = String(repeating: "a", count: 30); draft.city = "Shanghai"
        XCTAssertNoThrow(try draft.validate(original: nil))
        for (field, limit) in ClubOperationsPort.limits {
            var d = draft
            let long = String(repeating: "a", count: limit + 1)
            switch field {
            case "name": d.name = long
            case "city": d.city = long
            case "description": d.description = long
            case "keywords": d.keywords = long
            default: d.style = long
            }
            XCTAssertThrowsError(try d.validate(original: nil), field)
        }
    }
    func testMissingCreateStepOrder() {
        XCTAssertEqual(ClubOperationsPort.missingCreateStep(clubType: "", name: "", city: ""), 1)
        XCTAssertEqual(ClubOperationsPort.missingCreateStep(clubType: "x", name: " ", city: ""), 3)
        XCTAssertEqual(ClubOperationsPort.missingCreateStep(clubType: "x", name: "n", city: " "), 4)
        XCTAssertNil(ClubOperationsPort.missingCreateStep(clubType: "x", name: "n", city: "c"))
        XCTAssertEqual(ClubOperationsPort.missingStepHintKey(3), "club.ops.create.needName")
        XCTAssertNil(ClubOperationsPort.missingStepHintKey(2))
    }
}
#endif
