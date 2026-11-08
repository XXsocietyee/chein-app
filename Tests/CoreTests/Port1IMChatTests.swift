import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1IMChatTests: XCTestCase {
    typealias P = IMChatPort
    func testSendableTextTrimsAndRejectsBlank() {
        XCTAssertEqual(P.sendableText("  hi \n"), "hi"); XCTAssertNil(P.sendableText(" \n "))
    }
    func testConfirmedServerID() {
        XCTAssertTrue(P.isConfirmedServerID("12")); XCTAssertFalse(P.isConfirmedServerID("0"))
        XCTAssertFalse(P.isConfirmedServerID("012")); XCTAssertFalse(P.isConfirmedServerID("-3"))
        XCTAssertFalse(P.isConfirmedServerID("1.5")); XCTAssertFalse(P.isConfirmedServerID(nil))
        XCTAssertFalse(P.isConfirmedServerID("99999999999999999999"))
    }
    func testCardTappable() {
        XCTAssertTrue(P.cardIsTappable(hasAction: true, hasResult: false, senderID: 9, hasBroadcastID: false))
        XCTAssertTrue(P.cardIsTappable(hasAction: false, hasResult: true, senderID: 0, hasBroadcastID: false))
        XCTAssertFalse(P.cardIsTappable(hasAction: false, hasResult: true, senderID: 5, hasBroadcastID: false))
        XCTAssertFalse(P.cardIsTappable(hasAction: false, hasResult: false, senderID: 0, hasBroadcastID: false))
        XCTAssertTrue(P.cardIsTappable(hasAction: false, hasResult: false, senderID: 0, hasBroadcastID: true))
    }
    func testGenericTitleFallbacks() {
        XCTAssertEqual(P.genericCardTitle(title: "T", content: "C"), "T")
        XCTAssertEqual(P.genericCardTitle(title: " ", content: "报名成功"), "报名成功")
        XCTAssertEqual(P.genericCardTitle(title: nil, content: nil), "通知")
    }
    func testDividerGap() {
        let a = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(P.needsDivider(previous: nil, current: a))
        XCTAssertFalse(P.needsDivider(previous: a, current: a.addingTimeInterval(300)))
        XCTAssertTrue(P.needsDivider(previous: a, current: a.addingTimeInterval(301)))
    }
    func testFreshIDs() { XCTAssertEqual(P.freshIDs(polled: [5, 9, 7, 3], knownMax: 6), [9, 7]) }
    func testMergeReplacesByClientIDAndPrependKeepsExisting() {
        let local = P.Entry(id: "tmp_a", clientMessageID: "a", senderID: 1)
        let server = P.Entry(id: "10", clientMessageID: "a", senderID: 1)
        let other = P.Entry(id: "11", clientMessageID: "a", senderID: 2)
        XCTAssertEqual(P.merge(existing: [local], incoming: [server]), [server])
        XCTAssertEqual(P.merge(existing: [local], incoming: [other]), [local, other])
        let old = P.Entry(id: "1", clientMessageID: nil, senderID: 2)
        XCTAssertEqual(P.merge(existing: [server], incoming: [old, server], prepend: true), [old, server])
    }
}
#endif
