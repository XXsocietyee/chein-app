import XCTest
import CryptoKit
@testable import QuestifyCore

/// Proposal-only historical payload regression; no language overlay or new producer.
@MainActor final class PlayCompletionRetiredVenuePayloadProposalTests: XCTestCase {
    typealias Anchors = ContentDraftDurableJournalTests.Anchors
    typealias Blobs = ContentDraftDurableJournalTests.Blobs
    private let legacyVersionDigest = String(repeating: "a", count: 64)
    private func session(account: Int = 9001, namespace: String = "synthetic-cn") throws -> PlayExperienceSession {
        try .init(accountID: account, epoch: 1, namespace: namespace, token: "synthetic-token")
    }
    private func context() -> [String: Any] {
        ["schema": "original-mod-venue-context-v1", "runtimeDomain": "TOPIC_ROUTE", "run": "synthetic-run",
         "sessionId": 501, "topicId": 71, "nodeId": 701, "expectedVersion": 2, "expectedEpoch": 1,
         "consentId": 81, "consentVersion": legacyVersionDigest, "ruleVersion": legacyVersionDigest, "purpose": "VENUE_CHECK"]
    }
    private func model(_ transport: PlayRecoveryRecordingTransport, recovery: any PlayCompletionRecoveryStore,
                       current: @escaping () -> PlayExperienceSession?) throws -> PlayExperienceCoordinator {
        let service = PlayExperienceService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/fixture/")!),
            transport: transport, enabled: [.reads, .classicCompletion])
        return .init(scope: .activity(41), service: service, recovery: recovery,
                     pausedStorage: PlayMemoryPausedStorage(), currentSession: current)
    }
    private func intent(_ session: PlayExperienceSession) throws -> PlayCompletionIntent {
        .init(review: .init(nodeID: 701, evidence: .answer("synthetic"),
            advance: try .init(actionID: "synthetic-original-action", expectedVersion: 2), session: session,
            generation: 1, routeSessionID: 501, gameplayMode: .cityOrientation))
    }
    private func failClosed(_ operation: () async throws -> Void) async {
        do { try await operation(); XCTFail("Expected retained unavailable storage") }
        catch let issue as PlayExperienceError { XCTAssertEqual(issue, .persistenceUnavailable) }
        catch DecodingError.dataCorrupted(let context) {
            XCTAssertEqual(context.codingPath.last?.stringValue, "modVenue")
            XCTAssertEqual(context.debugDescription, "This legacy operation payload is not supported.")
        }
        catch { XCTFail("Unexpected refusal: \(error)") }
    }
    func testLegacyNonNullVenueIsRejectedByJSONAndPropertyListNullRemainsCompatible() throws {
        let value = try intent(session())
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
        XCTAssertNil(raw["modVenue"])
        for venue: Any in [context(), "not-a-context", false, 7] {
            raw["modVenue"] = venue
            XCTAssertThrowsError(try JSONDecoder().decode(PlayCompletionIntent.self, from: JSONSerialization.data(withJSONObject: raw)))
        }
        raw["modVenue"] = NSNull()
        XCTAssertEqual(try JSONDecoder().decode(PlayCompletionIntent.self, from: JSONSerialization.data(withJSONObject: raw)), value)
        let plist = try PropertyListEncoder().encode(value)
        var root = try XCTUnwrap(PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any])
        root["modVenue"] = context()
        let retired = try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0)
        XCTAssertThrowsError(try PropertyListDecoder().decode(PlayCompletionIntent.self, from: retired))
        XCTAssertEqual(try PropertyListDecoder().decode(PlayCompletionIntent.self, from: plist), value)
    }
    private struct RawAnchor: Codable {
        let schema: Int; let binding: Data; let blob: String; let key: Data; let digest: Data
        let generation: Data; let state: String
    }
    func testEncryptedLegacyVenueWithNoCurrentExtrasCannotReadClearOrRewriteOriginalBytes() async throws {
        let owner = try session(), key = PlayRunStorageKey.make(session: owner, scope: .activity(41))
        let value = try intent(owner), pending = PlayPendingCompletion(intent: value, state: .unknown, dispatchProcess: UUID())
        var raw = try XCTUnwrap(PropertyListSerialization.propertyList(from: PropertyListEncoder().encode(pending), format: nil) as? [String: Any])
        var oldIntent = try XCTUnwrap(raw["intent"] as? [String: Any]); oldIntent["modVenue"] = context(); raw["intent"] = oldIntent
        let originalBytes = try PropertyListSerialization.data(fromPropertyList: raw, format: .binary, options: 0)
        let anchors = Anchors(), blobs = Blobs(), binding = Data((key + ":completion").utf8)
        let slot = SHA256.hash(data: binding).map { String(format: "%02x", $0) }.joined()
        let blob = UUID().uuidString, encryptionKey = Data(repeating: 7, count: 32), generation = Data(repeating: 9, count: 32)
        let sealed = try AES.GCM.seal(originalBytes, using: SymmetricKey(data: encryptionKey), authenticating: binding + Data(blob.utf8))
        let encrypted = try XCTUnwrap(sealed.combined)
        let anchor = RawAnchor(schema: 1, binding: binding, blob: blob, key: encryptionKey,
            digest: Data(SHA256.hash(data: originalBytes)), generation: generation, state: "ready")
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        let item = ContentDraftAnchorItem(bytes: try encoder.encode(anchor), tag: generation)
        let presence = try await blobs.createPresence(slot: slot); XCTAssertTrue(presence)
        try await blobs.insert(name: blob, bytes: encrypted)
        let inserted = try await anchors.insert(slot: slot, item: item); XCTAssertTrue(inserted)
        let store = try PlayDurableRecovery(owner: .init(session: owner), key: key, anchors: anchors, ciphertexts: blobs)
        let snapshot = PlayCompletionRecoverySnapshot(value: pending, generation: generation, persistedBytes: originalBytes)
        await failClosed { _ = try await store.read(key) }
        await failClosed { _ = try await store.transition(snapshot, to: .dispatching, key: key) }
        await failClosed { try await store.clear(snapshot, key: key) }
        let transport = PlayRecoveryRecordingTransport()
        transport.responses["/fixture/api/play/nodes"] = .reply(PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.complete), 200)
        let model = try model(transport, recovery: store, current: { owner }); await model.load()
        XCTAssertEqual(model.issue, .persistenceUnavailable)
        let anchorAfter = await anchors.snapshots(), blobsAfter = await blobs.snapshots()
        XCTAssertEqual(anchorAfter, [item]); XCTAssertEqual(blobsAfter, [encrypted])
        XCTAssertEqual(transport.requests.count, 0)
    }
}
