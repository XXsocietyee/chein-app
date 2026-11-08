import XCTest
@testable import QuestifyCore

final class WP01IMUnreadMonotonicTests: XCTestCase {
    func testOlderTotalNeverReplacesNewerTotal() throws {
        var guardian = IMUnreadTotalMonotonicGuard()
        let older = guardian.begin(), newer = guardian.begin()
        XCTAssertEqual(try guardian.accept(7, ticket: newer, sessionIsCurrent: true), 7)
        XCTAssertEqual(try guardian.accept(3, ticket: older, sessionIsCurrent: true), 7)
        let later = guardian.begin()
        XCTAssertEqual(try guardian.accept(2, ticket: later, sessionIsCurrent: true), 2, "a genuinely later read may lower the badge")
    }
    func testNegativeAndNullStillRejectedAfterGuard() throws {
        var guardian = IMUnreadTotalMonotonicGuard()
        XCTAssertThrowsError(try guardian.accept(-1, ticket: guardian.begin(), sessionIsCurrent: true))
        XCTAssertThrowsError(try IMUnreadTotalService.decode(Data(#"{"code":200,"data":-1}"#.utf8)))
        XCTAssertThrowsError(try IMUnreadTotalService.decode(Data(#"{"code":401}"#.utf8)))
        XCTAssertThrowsError(try IMUnreadTotalService.decode(Data("not json".utf8)))
        // Source fallback `res.data || 0` is unchanged: null decodes to zero.
        XCTAssertEqual(try IMUnreadTotalService.decode(Data(#"{"code":200,"data":null}"#.utf8)), 0)
    }
    func testStaleSessionCompletionStillFenced() throws {
        var guardian = IMUnreadTotalMonotonicGuard()
        XCTAssertEqual(try guardian.accept(5, ticket: guardian.begin(), sessionIsCurrent: true), 5)
        XCTAssertThrowsError(try guardian.accept(9, ticket: guardian.begin(), sessionIsCurrent: false)) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(try guardian.accept(4, ticket: guardian.begin(), sessionIsCurrent: true), 4, "fenced completion left no state")
    }
}
