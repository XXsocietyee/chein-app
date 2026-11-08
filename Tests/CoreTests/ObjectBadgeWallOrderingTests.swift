#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class ObjectBadgeWallOrderingTests: XCTestCase {
    private func identities(_ json: String) throws -> [ProfileIdentityBadge] {
        try JSONDecoder().decode([ProfileIdentityBadge].self, from: Data(json.utf8))
    }
    func testLitCardsComeFirstAndServerOrderIsKeptInsideEachGroup() throws {
        let rows = try identities(#"[{"badgeCode":"A","unlocked":false},{"badgeCode":"B","unlocked":true},{"badgeCode":"C","unlocked":false},{"badgeCode":"D","unlocked":true}]"#)
        XCTAssertEqual(ObjectBadgeWallOrdering.litFirst(rows).map(\.badgeCode), ["B", "D", "A", "C"])
    }
    func testNothingIsDroppedOrDuplicated() throws {
        let rows = try identities(#"[{"badgeCode":"A"},{"badgeCode":"B","unlocked":true}]"#)
        let ordered = ObjectBadgeWallOrdering.litFirst(rows)
        XCTAssertEqual(ordered.count, rows.count)
        XCTAssertEqual(Set(ordered.map(\.badgeCode)), ["A", "B"])
        XCTAssertEqual(ObjectBadgeWallOrdering.litFirst([]), [])
    }
}
#endif
