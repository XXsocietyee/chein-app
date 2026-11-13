import XCTest
@testable import QuestifyCore

/// Album completion posts SUBMIT_ALBUM after a photo URL exists.
/// An unknown action result keeps the saved request id. Upload failure does not.
@available(macOS 14.0, *)
@MainActor final class PlayKitStubWriteTests: XCTestCase {
    private func state(version: Int = 1, done: Bool = false) -> String {
        """
        {"sessionId":501,"activityId":41,"topicId":71,"nodeId":701,"version":\(version),"status":"RUNNING","config":{"outcomeRulesVersion":1},"playKit":{"album":{"done":\(done)}}}
        """
    }

    private func make(_ transport: PlayRecoveryRecordingTransport, current: @escaping () -> PlayExperienceSession?) throws -> PlayAdvancedCoordinator {
        let service = PlayExperienceService(configuration: try .init(baseURL: URL(string: "https://example.com/fixture/")!), transport: transport, enabled: [.reads, .advanced])
        return .init(activityID: 41, topicID: 71, nodeID: 701, service: service, currentSession: current)
    }

    func testUnknownAlbumActionKeepsTheSavedRequestID() async throws {
        let owner = try PlayExperienceSession(accountID: 9001, epoch: 1, namespace: "synthetic", token: "synthetic")
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/fixture/api/play/advanced/start"] = .reply(PlayExperienceSyntheticFixtures.envelope(state()), 200)
        transport.responses["/fixture/api/play/advanced/action"] = .failure(.unknownResult)
        let model = try make(transport, current: { owner })
        await model.start()
        let detail = PlayKitPublishedWrites.albumDetail(imageURL: "https://cdn.example/photo.jpg")
        await model.submit(kind: PlayKitPublishedWrites.albumKind, action: PlayKitPublishedWrites.albumAction, detail: detail)
        let pending = try XCTUnwrap(model.pending)
        XCTAssertEqual(model.phase, "unknown")
        XCTAssertEqual(pending.action, "SUBMIT_ALBUM")
        let body = try JSONDecoder().decode(PlayWireValue.self, from: XCTUnwrap(transport.requests.last?.httpBody))
        XCTAssertEqual(body["action"], .string("SUBMIT_ALBUM"))
        XCTAssertEqual(body["idempotencyKey"], .string(pending.key))
        XCTAssertEqual(body["payload"], .object(detail))
        XCTAssertEqual(body["amount"], .null)
        XCTAssertEqual(body["price"], .null)
        let saved = pending.key
        await model.submit(kind: PlayKitPublishedWrites.albumKind, action: PlayKitPublishedWrites.albumAction, detail: detail)
        XCTAssertEqual(transport.requests.filter { $0.httpMethod == "POST" }.count, 2)
        XCTAssertEqual(model.pending?.key, saved)
        await model.recover()
        XCTAssertEqual(model.pending?.key, saved)
        XCTAssertNotEqual(model.phase, "ready")
    }

    func testUploadFailureDoesNotPostAlbum() async throws {
        XCTAssertEqual(PlayAlbumUploadOutcome.resolve(url: "https://cdn.example/photo.jpg", issue: .unknownResult), .failed)
        XCTAssertEqual(PlayAlbumUploadOutcome.resolve(url: "file:///tmp/a.jpg", issue: nil), .failed)
        let owner = try PlayExperienceSession(accountID: 9001, epoch: 1, namespace: "synthetic", token: "synthetic")
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/fixture/api/play/advanced/start"] = .reply(PlayExperienceSyntheticFixtures.envelope(state()), 200)
        let model = try make(transport, current: { owner })
        await model.start()
        let posts = transport.requests.filter { $0.httpMethod == "POST" }.count
        XCTAssertNil(model.pending)
        XCTAssertEqual(posts, 1)
        XCTAssertThrowsError(try model.review(kind: "album", action: "SUBMIT_ALBUM", detail: ["imageUrls": .array([.string("http://cdn.example/a.jpg")])]))
        XCTAssertEqual(transport.requests.filter { $0.httpMethod == "POST" }.count, posts)
    }
}
