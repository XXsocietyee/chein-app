import XCTest
@testable import QuestifyCore

final class WP01LateApprovalOrderTests: XCTestCase {
    private let binding = try! NativeChannelMessageBinding(channelID: NativeChannelMessageID(rawValue: "7")!, conversationID: NativeChannelMessageID(rawValue: "9")!, mappingRevision: "r1")
    private func id(_ n: Int) -> NativeChannelMessageID { NativeChannelMessageID(rawValue: String(n))! }
    private func snap(_ n: Int, status: Int, version: Int = 1) throws -> NativeChannelMessageSnapshot {
        let body = status == 0 ? #","msgType":1,"content":"x","senderId":"3""# : ""
        return try JSONDecoder().decode(NativeChannelMessageSnapshot.self, from: Data(#"{"id":"\#(n)","conversationId":"9","version":\#(version),"status":\#(status)\#(body)}"#.utf8))
    }
    private func projection() throws -> NativeChannelMessageProjection {
        var p = NativeChannelMessageProjection()
        try p.replacedHistory(mutationCursor: "0", syncContract: "VISIBLE_ORDER_PLUS_MUTATIONS_V1", legacyCacheAction: "RELOAD_ON_RESUME",
                              snapshots: [try snap(1, status: 0), try snap(2, status: 1), try snap(3, status: 0)], binding: binding)
        return p
    }
    func testLateApprovedMessageKeepsServerPosition() throws {
        var p = try projection()
        let order = [id(1), id(2), id(3)]
        XCTAssertEqual(p.visibleIDs(inServerOrder: order), [id(1), id(3)])
        p.confirmCurrent(try snap(2, status: 0, version: 2))
        XCTAssertEqual(p.visibleIDs(inServerOrder: order), [id(1), id(2), id(3)], "approved late, yet not appended")
    }
    func testWithheldStatusStillVetoed() throws {
        var p = try projection()
        p.confirmCurrent(try snap(2, status: 2, version: 2))
        XCTAssertEqual(p.visibleIDs(inServerOrder: [id(1), id(2), id(3)]), [id(1), id(3)])
        p.confirmCurrent(try snap(2, status: 0, version: 1)) // stale version cannot lift the veto
        XCTAssertTrue(p.withheld.contains(id(2)))
    }
}
