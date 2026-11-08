#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// FP-M6: malformed input degrades to nil / a thrown error / a placeholder instead of a trap.
final class HardeningWaveTests: XCTestCase {
    func testTranscriptMessageWithNegativeSenderDoesNotTrap() {
        let message = ChannelTranscriptMessage.make(id: 7, conversationID: 9, senderID: -5, content: "hi")
        XCTAssertEqual(message.wireMessage.id, 7)
        XCTAssertEqual(message.wireMessage.conversationID, 9)
        XCTAssertNil(message.wireMessage.content, "withheld placeholder carries no payload")
    }

    func testTranscriptMessageClampsNonPositiveIDs() {
        let message = ChannelTranscriptMessage.make(id: 0, conversationID: -3, senderID: 1)
        XCTAssertEqual(message.wireMessage.id, 1)
        XCTAssertEqual(message.wireMessage.conversationID, 1)
    }

    func testTranscriptMessageValidInputKeepsPayload() {
        let message = ChannelTranscriptMessage.make(id: 7, conversationID: 9, senderID: 3, content: "hello")
        XCTAssertEqual(message.wireMessage.content, "hello")
        XCTAssertEqual(message.wireMessage.senderID, 3)
    }

    func testStraightLinePreviewIsStraightAndFinite() throws {
        let origin = try XCTUnwrap(RoamCoordinate(latitude: 31.2, longitude: 121.4))
        let destination = try XCTUnwrap(RoamCoordinate(latitude: 31.3, longitude: 121.5))
        let request = SearchRouteRequest(origin: origin, destination: destination, mode: .walking)
        let preview = SearchRoutePreview.straightLine(request)
        XCTAssertTrue(preview.isStraightLine)
        XCTAssertEqual(preview.coordinates.count, 2)
        XCTAssertTrue(preview.distanceMeters.isFinite && preview.distanceMeters > 0)
        XCTAssertNil(preview.etaSeconds)
        XCTAssertNil(preview.provider)
    }

    func testRunAuthorityPlaceholderIsValidCreatedRun() {
        let placeholder = RunAuthorityProjection.placeholder
        XCTAssertEqual(placeholder.runId, "run-01")
        XCTAssertEqual(placeholder.stateVersion, 0)
        XCTAssertEqual(placeholder.status, .created)
        XCTAssertTrue(placeholder.nodes.isEmpty)
        XCTAssertNil(placeholder.pending)
    }

    func testOrientOperationValidationRejectsNonPositiveIDsWithoutTrapping() {
        XCTAssertThrowsError(try OrientSessionOperation.settle(sessionID: 0).validate())
        XCTAssertThrowsError(try OrientSessionOperation.task(sessionID: 1, taskID: 0, alternative: nil).validate())
        XCTAssertThrowsError(try OrientSessionOperation.appeal(sessionID: 1, entryID: nil, nodeID: nil, reason: "x").validate())
        XCTAssertThrowsError(try OrientSessionOperation.appeal(sessionID: 1, entryID: 0, nodeID: nil, reason: "x").validate())
        XCTAssertNoThrow(try OrientSessionOperation.start(sessionID: 1, ackConfigVersion: 0).validate())
    }
}
#endif
