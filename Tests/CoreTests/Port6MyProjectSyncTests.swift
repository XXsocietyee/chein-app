import XCTest
@testable import QuestifyCore

final class Port6MyProjectSyncTests: XCTestCase {
    func testKeepsRowsOnlyForSameQueryAndScopeWhileLoading() {
        let scope = UUID(), q = CreatorContentQuery()
        XCTAssertTrue(MyProjectSyncPort.keepsStaleRows(isLoading: true, previousQuery: q, currentQuery: q, previousScope: scope, currentScope: scope))
        XCTAssertFalse(MyProjectSyncPort.keepsStaleRows(isLoading: false, previousQuery: q, currentQuery: q, previousScope: scope, currentScope: scope))
        XCTAssertFalse(MyProjectSyncPort.keepsStaleRows(isLoading: true, previousQuery: q, currentQuery: .init(type: "topic"), previousScope: scope, currentScope: scope))
        XCTAssertFalse(MyProjectSyncPort.keepsStaleRows(isLoading: true, previousQuery: q, currentQuery: q, previousScope: UUID(), currentScope: scope))
        XCTAssertFalse(MyProjectSyncPort.keepsStaleRows(isLoading: true, previousQuery: nil, currentQuery: q, previousScope: nil, currentScope: scope))
    }
}
