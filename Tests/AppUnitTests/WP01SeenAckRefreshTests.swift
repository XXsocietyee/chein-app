import XCTest
@testable import Questify
import QuestifyCore

@MainActor final class WP01SeenAckRefreshTests: XCTestCase {
    private func receipt(_ readTo: Int) throws -> NativeChannelReadReceipt {
        try JSONDecoder().decode(NativeChannelReadReceipt.self, from: Data(#"{"conversationId":9,"readTo":\#(readTo),"lastReadMessageId":\#(readTo),"unread":0}"#.utf8))
    }
    func testSeenReceiptTriggersDirectoryRefreshOnce() throws {
        var count = 0
        let gate = NativeChannelSeenAckRefreshGate { count += 1 }
        let first = try receipt(10)
        gate.seenReceipt(first); gate.seenReceipt(first)
        XCTAssertEqual(count, 1)
        gate.seenReceipt(try receipt(11))
        XCTAssertEqual(count, 2)
    }
    func testNoRefreshWhenAckUnknownOutcome() {
        var count = 0
        let gate = NativeChannelSeenAckRefreshGate { count += 1 }
        gate.seenReceipt(nil)
        XCTAssertEqual(count, 0)
    }
}
