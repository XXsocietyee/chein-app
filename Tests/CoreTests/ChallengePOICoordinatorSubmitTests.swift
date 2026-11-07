import Foundation
import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// Proves the POI challenge submit state machine never shows success before a server 200.
/// There is no transport here on purpose: the challenge write has no approved path (see
/// PlayWriteAvailability.challengeSubmit), so this only covers local validation and result handling.
final class ChallengePOICoordinatorSubmitTests: XCTestCase {
    @MainActor
    func testPhotoRequiredBlocksPayloadAndAmbiguousFailureNeverShowsSuccess() throws {
        let node = ChallengePOINode(id: 55, name: "Clock Tower", photoRequired: true)
        let coordinator = ChallengePOICoordinator(nodeId: 55)
        coordinator.applyLoadedNode(node)
        XCTAssertEqual(coordinator.state, .photo)

        // Validation: no photo means no payload.
        XCTAssertThrowsError(try coordinator.buildCompletionPayload(userLat: nil, userLon: nil)) { error in
            XCTAssertEqual((error as NSError).code, 2)
        }

        coordinator.confirmPhotoUploaded("  https://example.test/photo.jpg  ")
        let payload = try coordinator.buildCompletionPayload(userLat: nil, userLon: nil)
        XCTAssertEqual(payload["nodeId"], .int(55))
        XCTAssertEqual(payload["photoUrl"], .string("https://example.test/photo.jpg"))
        XCTAssertNil(payload["answer"])

        // Ambiguous/server failure: not done, locked against blind resubmission.
        coordinator.applyCompletionResult(code: 500, data: .object([:]), message: nil)
        XCTAssertNotEqual(coordinator.state, .done)
        XCTAssertTrue(coordinator.unknownSubmission)
        XCTAssertFalse(coordinator.errorMessage.isEmpty)
        XCTAssertThrowsError(try coordinator.buildCompletionPayload(userLat: nil, userLon: nil)) { error in
            XCTAssertEqual((error as NSError).code, 10)
        }

        // Only an explicit server 200 reaches .done.
        coordinator.applyLoadedNode(node)
        XCTAssertFalse(coordinator.unknownSubmission)
        XCTAssertNotEqual(coordinator.state, .done)
        coordinator.applyCompletionResult(code: 200, data: .object([:]), message: nil)
        XCTAssertEqual(coordinator.state, .done)
        XCTAssertFalse(coordinator.unknownSubmission)
    }
}
#endif
