import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1ClubDetailRankingTests: XCTestCase {
    typealias P = ClubDetailRankingPort
    func testFoldKeepsShortListsWhole() {
        XCTAssertEqual(P.fold([1, 2, 3, 4, 5, 6], me: 2).count, 6)
    }
    func testFoldTopThreeGapAndTail() {
        let rows = P.fold(Array(1...12), me: nil)
        XCTAssertEqual(rows.count, 7)
        XCTAssertEqual(rows[3], .gap(hidden: 6))
        XCTAssertEqual(rows.last, .member(rank: 12, id: 12, isMe: false))
    }
    func testFoldWidensTailAroundViewer() {
        let rows = P.fold(Array(1...12), me: 6)   // index 5 -> tail starts at index 4
        XCTAssertEqual(rows[3], .gap(hidden: 1))
        XCTAssertTrue(rows.contains(.member(rank: 6, id: 6, isMe: true)))
        XCTAssertEqual(rows.count, 3 + 1 + 8)
    }
    func testViewerInTopThreeUsesDefaultTail() {
        let rows = P.fold(Array(1...12), me: 2)
        XCTAssertEqual(rows.count, 7)
        XCTAssertEqual(rows[1], .member(rank: 2, id: 2, isMe: true))
    }
    func testDurationAndDecimalText() {
        XCTAssertEqual(P.durationText(minutes: 65), "1小时5分")
        XCTAssertEqual(P.durationText(minutes: 45), "45分")
        XCTAssertEqual(P.durationText(minutes: 0), "—"); XCTAssertEqual(P.durationText(minutes: nil), "—")
        XCTAssertEqual(P.oneDecimal(15), "15.0"); XCTAssertEqual(P.oneDecimal(nil), "0.0")
    }
    func testEmptyKeyAndStrip() {
        XCTAssertEqual(P.emptyKey(sort: "mileage"), "mileage"); XCTAssertEqual(P.emptyKey(sort: "pace"), "composite")
        XCTAssertEqual(P.memberStrip(loaded: 9, total: 30), .init(shownIndexes: [0, 1, 2, 3], overflow: 26))
        XCTAssertEqual(P.memberStrip(loaded: 2, total: nil), .init(shownIndexes: [0, 1], overflow: 0))
    }
}
#endif
