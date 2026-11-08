import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1IMInboxTests: XCTestCase {
    typealias P = IMInboxPort
    func testTypedPreview() {
        XCTAssertEqual(P.typedPreview(messageType: 2, text: "x"), "[图片]")
        XCTAssertEqual(P.typedPreview(messageType: 3, text: nil), "[系统卡片]")
        XCTAssertEqual(P.typedPreview(messageType: 3, text: " 审核通过 "), "审核通过")
        XCTAssertEqual(P.typedPreview(messageType: 1, text: nil), "")
        XCTAssertEqual(P.typedPreview(messageType: nil, text: "hi"), "hi")
        XCTAssertEqual(P.typedPreview(messageType: 1, text: "secret", isRecalled: true), IMConversationPreviewPolicy.redactedPlaceholderText)
    }
    func testReadAllOutcome() {
        XCTAssertEqual(P.readAllOutcome(attempted: 0, failed: 0), .nothingToRead)
        XCTAssertEqual(P.readAllOutcome(attempted: 3, failed: 0), .allSucceeded)
        XCTAssertEqual(P.readAllOutcome(attempted: 3, failed: 3), .allFailed)
        XCTAssertEqual(P.readAllOutcome(attempted: 3, failed: 1), .partial(failed: 1))
        XCTAssertEqual(P.readAllOutcome(attempted: 3, failed: 9), .allFailed)
    }
    func testReadAllTargets() {
        XCTAssertEqual(P.readAllTargets([(1, 2, true), (2, 0, true), (3, nil, true), (4, 5, false), (5, 1, true)]), [1, 5])
    }
}
#endif
