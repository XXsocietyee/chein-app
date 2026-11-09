import XCTest
@testable import QuestifyCore

@MainActor private final class MinePageReader: OfficialEventReading {
    var isConfigured = true
    var isAuthenticated = true
    var isOfflineExample = false
    var scope = UUID()
    var calls: [String] = []
    var result: Result<OfficialPublished, Error> = .failure(APIError.notConfigured)
    var publish = false
    var publishError: Error?
    var pauseFirst = false
    var release: CheckedContinuation<Void, Never>?
    func events(city: String?) async throws -> [OfficialEvent] { calls.append("events"); throw APIError.notConfigured }
    func detail(id: Int) async throws -> OfficialEvent { calls.append("detail"); throw APIError.notConfigured }
    func myEvents() async throws -> [OfficialEvent] { calls.append("myEvents"); throw APIError.notConfigured }
    func partyInbox() async throws -> [OfficialPartyInvite] { calls.append("inbox"); throw APIError.notConfigured }
    func canPublish() async throws -> Bool {
        calls.append("canPublish")
        if let publishError { throw publishError }
        return publish
    }
    func broadcastStats(id: Int) async throws -> OfficialBroadcastStats { calls.append("stats"); throw APIError.notConfigured }
    func myPublished() async throws -> OfficialPublished {
        calls.append("myPublished")
        let captured = result
        if pauseFirst {
            pauseFirst = false
            await withCheckedContinuation { release = $0 }
        }
        return try captured.get()
    }
}

@MainActor final class OfficialMinePageModelTests: XCTestCase {
    private let dash = OfficialMineCount.unknownMark

    private func published(_ json: String) throws -> OfficialPublished {
        try JSONDecoder().decode(OfficialPublished.self, from: Data(json.utf8))
    }

    func testUnknownCountIsAnEmDashAndNeverAGuessedZero() {
        XCTAssertEqual(dash, "—")
        XCTAssertNotEqual(dash, "0")
        XCTAssertEqual(OfficialMineCount.unknown.displayText, dash)
        XCTAssertEqual(OfficialMineCount.server(nil).displayText, dash)
        XCTAssertEqual(OfficialMineCount.server(-1).displayText, dash)
        XCTAssertEqual(OfficialMineCount.value(-4).displayText, dash)
        XCTAssertEqual(OfficialMineCount.server(0).displayText, "0")
        XCTAssertEqual(OfficialMinePageModel.loading.eventCountText, dash)
        XCTAssertEqual(OfficialMinePageModel.loading.broadcastCountText, dash)
        XCTAssertEqual(OfficialMinePageModel.loading.accessibilityIdentifier, OfficialMineAccessibility.loading)
        XCTAssertFalse(OfficialMinePageModel.loading.showsPublishActions)
        XCTAssertEqual(OfficialMinePageModel.unknown.eventCountText, dash)
        XCTAssertEqual(OfficialMinePageModel.unknown.accessibilityIdentifier, OfficialMineAccessibility.unknown)
        let failed = OfficialMinePageModel.failure(.httpStatus(500))
        XCTAssertEqual(failed.phase, .error(.httpStatus(500)))
        XCTAssertEqual(failed.eventCountText, dash)
        XCTAssertEqual(failed.broadcastCountText, dash)
        XCTAssertEqual(failed.accessibilityIdentifier, OfficialMineAccessibility.error)
        XCTAssertFalse(failed.showsPublishActions)
    }

    func testKnownEmptyIsZeroAndMalformedPayloadStaysUnknown() throws {
        let empty = OfficialMinePageModel.loaded(try published(#"{"events":[],"broadcasts":[]}"#))
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.eventCountText, "0")
        XCTAssertEqual(empty.broadcastCountText, "0")
        XCTAssertEqual(empty.accessibilityIdentifier, OfficialMineAccessibility.empty)
        XCTAssertFalse(empty.showsPublishActions)
        let granted = OfficialMinePageModel.loaded(try published(#"{"events":[],"broadcasts":[]}"#), publisherCapabilityGranted: true)
        XCTAssertTrue(granted.showsPublishActions)
        let unread = OfficialMinePageModel.from(result: .failure(APIError.malformedResponse))
        XCTAssertEqual(unread.phase, .unknown)
        XCTAssertEqual(unread.eventCountText, dash)
        XCTAssertNotEqual(unread.eventCountText, "0")
        XCTAssertFalse(unread.showsPublishActions)
        XCTAssertEqual(OfficialMinePageModel.from(result: .failure(APIError.httpStatus(503))).phase, .error(.httpStatus(503)))
        XCTAssertEqual(OfficialMinePageIssue(OfficialReadFailure.noPublisherPermission), .noPublisherPermission)
        XCTAssertEqual(OfficialMinePageIssue(CancellationError()).isUnreadable, false)
    }

    func testVisibleRowsKeepServerNumbersAndDropIncompleteOnes() throws {
        let json = #"{"events":[{"id":7,"title":"Published","status":7,"city":"Hangzhou","category":"city_light"},{"id":7,"title":"Duplicate","status":3},{"id":0,"title":"Dropped"},{"id":8,"title":"   "},{"id":9,"title":"No city"}],"broadcasts":[{"id":0,"title":"Dropped notice","reachedCount":4},{"id":3,"title":"Known zero","reachedCount":0},{"id":4,"title":"Missing"},{"id":5,"title":"Word","reachedCount":"UNKNOWN"},{"id":6,"title":"Negative","reachedCount":-2,"copyMode":1,"audience":"player","status":2,"city":"Hangzhou"}]}"#
        let model = OfficialMinePageModel.loaded(try published(json))
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.eventCountText, "2")
        XCTAssertEqual(model.events.map(\.id), [7, 9])
        XCTAssertEqual(model.events[0].statusKey, "official.privateParity.published.status.unknown")
        XCTAssertEqual(model.events[0].cityText, "Hangzhou")
        XCTAssertEqual(model.events[0].categoryKey, "official.detailParity.category.cityLight")
        XCTAssertEqual(model.events[0].accessibilityIdentifier, "official.published.event.7")
        XCTAssertEqual(model.events[0].statusAccessibilityIdentifier, "official.published.eventStatus.7")
        XCTAssertEqual(model.events[1].cityText, dash)
        XCTAssertNil(model.events[1].categoryKey)
        XCTAssertEqual(model.broadcastCountText, "4")
        XCTAssertEqual(model.broadcasts.map(\.reach.displayText), ["0", dash, dash, dash])
        XCTAssertEqual(model.broadcasts[0].accessibilityIdentifier, "official.broadcast.3")
        XCTAssertEqual(model.broadcasts[3].statusKey, "official.w206.broadcast.status.sent")
        XCTAssertNotEqual(model.broadcasts.map(\.reach.displayText), ["0", "0", "0", "0"])
        XCTAssertFalse(model.showsPublishActions)
    }

    func testCoordinatorHidesPublishUntilCanPublishAndSkipsOtherReads() async throws {
        let reader = MinePageReader()
        reader.result = .success(try published(#"{"events":[{"id":4,"title":"Mine","status":3}],"broadcasts":[]}"#))
        let hidden = OfficialMinePageCoordinator()
        await hidden.reload(using: reader)
        XCTAssertEqual(hidden.model.phase, .ready)
        XCTAssertEqual(hidden.model.eventCountText, "1")
        XCTAssertEqual(hidden.model.broadcastCountText, "0")
        XCTAssertFalse(hidden.model.showsPublishActions)
        XCTAssertEqual(reader.calls, ["myPublished", "canPublish"])

        reader.calls = []
        reader.publish = true
        let shown = OfficialMinePageCoordinator()
        await shown.reload(using: reader)
        XCTAssertTrue(shown.model.showsPublishActions)
        XCTAssertEqual(reader.calls, ["myPublished", "canPublish"])

        reader.calls = []
        reader.publish = true
        reader.publishError = APIError.unauthorized
        let denied = OfficialMinePageCoordinator()
        await denied.reload(using: reader)
        XCTAssertEqual(denied.model.phase, .ready)
        XCTAssertFalse(denied.model.showsPublishActions)
        XCTAssertEqual(denied.model.eventCountText, "1")
    }

    func testMissingSessionDoesNotReadAndUnreadableBodyIsNotZero() async {
        let signedOut = MinePageReader()
        signedOut.isAuthenticated = false
        let guest = OfficialMinePageCoordinator()
        await guest.reload(using: signedOut)
        XCTAssertEqual(guest.model.phase, .error(.unauthorized))
        XCTAssertEqual(guest.model.eventCountText, dash)
        XCTAssertTrue(signedOut.calls.isEmpty)

        let offline = MinePageReader()
        offline.isConfigured = false
        let unconfigured = OfficialMinePageCoordinator()
        await unconfigured.reload(using: offline)
        XCTAssertEqual(unconfigured.model.phase, .error(.notConfigured))
        XCTAssertTrue(offline.calls.isEmpty)
        XCTAssertFalse(unconfigured.model.showsPublishActions)

        let broken = MinePageReader()
        broken.result = .failure(APIError.malformedResponse)
        let unknown = OfficialMinePageCoordinator()
        await unknown.reload(using: broken)
        XCTAssertEqual(unknown.model.phase, .unknown)
        XCTAssertEqual(unknown.model.eventCountText, dash)
        XCTAssertEqual(unknown.model.broadcastCountText, dash)
        XCTAssertEqual(broken.calls, ["myPublished"])
    }

    func testANewerReloadDropsTheOlderPayload() async throws {
        let reader = MinePageReader()
        reader.pauseFirst = true
        reader.publish = true
        reader.result = .success(try published(#"{"events":[],"broadcasts":[]}"#))
        let coordinator = OfficialMinePageCoordinator()
        let first = Task { await coordinator.reload(using: reader) }
        for _ in 0..<200 where reader.release == nil { await Task.yield() }
        let gate = try XCTUnwrap(reader.release)
        reader.result = .success(try published(#"{"events":[{"id":8,"title":"Later","status":1}],"broadcasts":[]}"#))
        reader.publish = false
        let second = Task { await coordinator.reload(using: reader) }
        await second.value
        XCTAssertEqual(coordinator.model.eventCountText, "1")
        XCTAssertEqual(coordinator.model.events.first?.statusKey, "official.privateParity.published.status.pending")
        XCTAssertFalse(coordinator.model.showsPublishActions)
        gate.resume()
        await first.value
        XCTAssertEqual(coordinator.model.phase, .ready)
        XCTAssertEqual(coordinator.model.eventCountText, "1")
        XCTAssertEqual(reader.calls, ["myPublished", "myPublished", "canPublish"])
    }

#if DEBUG
    func testDebugFixtureDataKeepsUnknownReachAsAnEmDash() throws {
        let ready = OfficialMinePageModel.loaded(try published(OfficialMinePageFixtureData.ready))
        XCTAssertEqual(ready.broadcasts.first?.reach.displayText, "7")
        let missing = OfficialMinePageModel.loaded(try published(OfficialMinePageFixtureData.missingReach))
        XCTAssertEqual(missing.broadcasts.first?.reach.displayText, dash)
        let zero = OfficialMinePageModel.loaded(try published(OfficialMinePageFixtureData.zeroReach))
        XCTAssertEqual(zero.eventCountText, "0")
        XCTAssertEqual(zero.broadcasts.first?.reach.displayText, "0")
        let unknown = OfficialMinePageModel.loaded(try published(OfficialMinePageFixtureData.unknownReach))
        XCTAssertEqual(unknown.broadcasts.first?.reach.displayText, dash)
        let negative = OfficialMinePageModel.loaded(try published(OfficialMinePageFixtureData.negativeReach))
        XCTAssertEqual(negative.broadcasts.first?.reach.displayText, dash)
        XCTAssertEqual(OfficialMinePageModel.loaded(try published(OfficialMinePageFixtureData.empty)).phase, .empty)
    }
#endif
}
