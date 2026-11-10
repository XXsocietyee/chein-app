import XCTest
@testable import QuestifyCore

final class ClubCreatePageModelTests: XCTestCase {
    private let closed = ClubCreationGate.productionDefault
    private let open = ClubCreationGate(isConfigured: true, writeAvailability: .approved)

    func testUnknownCountIsAnEmDashAndNeverZero() {
        XCTAssertEqual(ClubCreatePageModel.unknownMark, "—")
        XCTAssertNotEqual(ClubCreatePageModel.unknownMark, "0")
        XCTAssertFalse(ClubCreatePageModel.showsOnPlayerFirstEntry)
        XCTAssertFalse(ClubCreatePageModel.mediaUploadVisible)
        XCTAssertTrue(ClubCreatePageModel.usesExistingCreateCommand())
        for owned in [ClubCreateOwnedRead.withheld, .unknownIDs] {
            let model = ClubCreatePageModel.interpret(owned: owned, accountRole: "club", gate: open, onPlayerFirstEntry: false)
            XCTAssertEqual(model.phase, .unknown)
            XCTAssertEqual(model.recordCountText, "—")
            XCTAssertNotEqual(model.recordCountText, "0")
            XCTAssertFalse(model.offersForm)
            XCTAssertFalse(model.liveSubmitEnabled)
        }
    }

    func testOwnedPayloadClassifiesEmptyErrorAndUnknown() throws {
        func parsed(_ json: String) -> ClubCreateOwnedRead {
            ClubCreatePageModel.parseOwned(Data(json.utf8))
        }
        XCTAssertEqual(parsed(#"{"data":{"owned":[]}}"#), .list([]))
        XCTAssertEqual(parsed(#"{"data":{"owned":[{"id":81},{"id":82}]}}"#), .list([81, 82]))
        XCTAssertEqual(parsed(#"{"data":{}}"#), .withheld)
        XCTAssertEqual(parsed(#"{"data":{"owned":[{"id":81},{"id":81}]}}"#), .unknownIDs)
        XCTAssertEqual(parsed(#"{"data":{"owned":[{"id":0}]}}"#), .unknownIDs)
        XCTAssertEqual(parsed(#"{"data":{"owned":[{"id":1.5}]}}"#), .unknownIDs)
        XCTAssertEqual(parsed(#"{"data":{"owned":[{"id":true}]}}"#), .unknownIDs)
        XCTAssertEqual(parsed(#"{"data":{"owned":"none"}}"#), .malformed)
        XCTAssertEqual(parsed("{}"), .malformed)
        XCTAssertEqual(parsed("not-json"), .malformed)

        let empty = ClubCreatePageModel.interpret(owned: .list([]), accountRole: "club", gate: closed, onPlayerFirstEntry: false)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.recordCountText, "0")
        XCTAssertTrue(empty.offersForm)
        XCTAssertFalse(empty.liveSubmitEnabled)

        let broken = ClubCreatePageModel.interpret(owned: .malformed, accountRole: "club", gate: open, onPlayerFirstEntry: false)
        XCTAssertEqual(broken.phase, .error)
        XCTAssertEqual(broken.recordCountText, "—")
        XCTAssertFalse(broken.offersForm)
    }

    func testLoadingSignedOutAndFailedReadDoNotGuessACount() {
        let snapshot = ClubOperationsSnapshot(target: .create, accountRole: "club", ownedClubIDs: [])
        let loading = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: true, gate: open, snapshot: snapshot, readback: .idle, onPlayerFirstEntry: false)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.recordCountText, "—")
        XCTAssertFalse(loading.offersForm)
        let signedOut = ClubCreatePageModel.interpret(signedIn: false, configured: true, loading: false, gate: open, snapshot: snapshot, readback: .idle, onPlayerFirstEntry: false)
        XCTAssertEqual(signedOut.phase, .error)
        XCTAssertEqual(signedOut.recordCountText, "—")
        let failed = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: snapshot, readback: .unavailable, onPlayerFirstEntry: false)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.recordCountText, "—")
        let unconfigured = ClubCreatePageModel.interpret(signedIn: true, configured: false, loading: false, gate: open, snapshot: snapshot, readback: .idle, onPlayerFirstEntry: false)
        XCTAssertEqual(unconfigured.phase, .error)
        XCTAssertFalse(unconfigured.liveSubmitEnabled)
    }

    func testCreationStaysGatedAndOffThePlayerFirstEntry() {
        let ready = ClubOperationsSnapshot(target: .create, accountRole: "club", ownedClubIDs: [81])
        let closedForm = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: closed, snapshot: ready, readback: .idle, onPlayerFirstEntry: false)
        XCTAssertEqual(closedForm.phase, .ready)
        XCTAssertEqual(closedForm.recordCountText, "1")
        XCTAssertTrue(closedForm.offersForm)
        XCTAssertFalse(closedForm.liveSubmitEnabled)
        let live = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: ready, readback: .idle, onPlayerFirstEntry: false)
        XCTAssertTrue(live.liveSubmitEnabled)
        XCTAssertFalse(live.showsHostApplication)
        let playerFirst = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: ready, readback: .idle, onPlayerFirstEntry: true)
        XCTAssertFalse(playerFirst.offersForm)
        XCTAssertFalse(playerFirst.showsHostApplication)
        XCTAssertFalse(playerFirst.liveSubmitEnabled)
        let limit = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: .init(target: .create, accountRole: "club", ownedClubIDs: [81, 82]), readback: .idle, onPlayerFirstEntry: false)
        XCTAssertEqual(limit.recordCountText, "2")
        XCTAssertFalse(limit.offersForm)
        XCTAssertFalse(limit.liveSubmitEnabled)
        let player = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: .init(target: .create, accountRole: "player", ownedClubIDs: []), readback: .idle, onPlayerFirstEntry: false)
        XCTAssertEqual(player.phase, .empty)
        XCTAssertFalse(player.offersForm)
        XCTAssertTrue(player.showsHostApplication)
        let unknownRole = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: .init(target: .create, accountRole: "", ownedClubIDs: []), readback: .idle, onPlayerFirstEntry: false)
        XCTAssertFalse(unknownRole.offersForm)
        XCTAssertFalse(unknownRole.showsHostApplication)
        let duplicates = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: .init(target: .create, accountRole: "club", ownedClubIDs: [81, 81]), readback: .idle, onPlayerFirstEntry: false)
        XCTAssertEqual(duplicates.phase, .unknown)
        XCTAssertEqual(duplicates.recordCountText, "—")
    }

    func testReceivedReadbackOutranksAStaleSnapshot() {
        let stale = ClubOperationsSnapshot(target: .create, accountRole: "club", ownedClubIDs: [])
        let current = ClubOperationsSnapshot(target: .create, accountRole: "club", ownedClubIDs: [81])
        let model = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: closed, snapshot: stale, readback: .received(current), onPlayerFirstEntry: false)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.recordCountText, "1")
        let wrongTarget = ClubCreatePageModel.interpret(signedIn: true, configured: true, loading: false, gate: open, snapshot: current, readback: .received(.init(target: .club(81))), onPlayerFirstEntry: false)
        XCTAssertEqual(wrongTarget.phase, .error)
        XCTAssertEqual(wrongTarget.recordCountText, "—")
        XCTAssertFalse(wrongTarget.liveSubmitEnabled)
    }
}

@MainActor final class ClubCreatePageCoordinatorTests: XCTestCase {
    func testCoordinatorProjectsTheGateWithoutSending() async {
        let access = CreatePageReadAccess()
        let coordinator = ClubOperationsCoordinator(access: access)
        let snapshot = ClubOperationsSnapshot(target: .create, accountRole: "club", ownedClubIDs: [])
        let hidden = coordinator.createPageModel(loading: false, snapshot: snapshot, onPlayerFirstEntry: true)
        XCTAssertEqual(hidden.phase, .empty)
        XCTAssertFalse(hidden.offersForm)
        XCTAssertFalse(hidden.liveSubmitEnabled)
        let gated = coordinator.createPageModel(loading: false, snapshot: snapshot, onPlayerFirstEntry: false)
        XCTAssertTrue(gated.offersForm)
        XCTAssertFalse(gated.liveSubmitEnabled)
        XCTAssertEqual(gated.recordCountText, "0")
        access.isConfigured = false
        let unavailable = coordinator.createPageModel(loading: false, snapshot: snapshot)
        XCTAssertEqual(unavailable.phase, .error)
        XCTAssertEqual(unavailable.recordCountText, "—")
        XCTAssertEqual(access.writes, 0)
        XCTAssertEqual(access.reads, 0)
    }

    func testNoFactsStayUnknownInsteadOfZero() {
        let access = CreatePageReadAccess()
        let coordinator = ClubOperationsCoordinator(access: access)
        let model = coordinator.createPageModel(loading: false, onPlayerFirstEntry: false)
        XCTAssertEqual(model.phase, .unknown)
        XCTAssertEqual(model.recordCountText, "—")
        XCTAssertNotEqual(model.recordCountText, "0")
        XCTAssertFalse(model.offersForm)
        XCTAssertEqual(access.writes, 0)
    }
}

#if DEBUG
@MainActor final class ClubCreatePageFixtureDataTests: XCTestCase {
    func testDebugFixtureDataFeedsTheReadModel() {
        func model(_ json: String, role: String = "club", gate: ClubCreationGate = .productionDefault) -> ClubCreatePageModel {
            ClubCreatePageModel.interpret(owned: ClubCreatePageModel.parseOwned(Data(json.utf8)), accountRole: role, gate: gate, onPlayerFirstEntry: false)
        }
        XCTAssertEqual(model(ClubCreatePageFixtureData.emptyOwned).phase, .empty)
        XCTAssertEqual(model(ClubCreatePageFixtureData.emptyOwned).recordCountText, "0")
        XCTAssertFalse(model(ClubCreatePageFixtureData.emptyOwned).liveSubmitEnabled)
        XCTAssertEqual(model(ClubCreatePageFixtureData.oneLive).recordCountText, "1")
        XCTAssertEqual(model(ClubCreatePageFixtureData.withheldOwned).phase, .unknown)
        XCTAssertEqual(model(ClubCreatePageFixtureData.withheldOwned).recordCountText, "—")
        XCTAssertEqual(model(ClubCreatePageFixtureData.duplicateIDs).phase, .unknown)
        XCTAssertEqual(model(ClubCreatePageFixtureData.nonPositiveID).recordCountText, "—")
        XCTAssertEqual(model(ClubCreatePageFixtureData.fractionalID).phase, .unknown)
        XCTAssertEqual(model(ClubCreatePageFixtureData.malformed).phase, .error)
        XCTAssertEqual(model(ClubCreatePageFixtureData.malformed).recordCountText, "—")
        let live = model(ClubCreatePageFixtureData.oneLive, gate: ClubCreationGate(isConfigured: true, writeAvailability: .syntheticOnly))
        XCTAssertTrue(live.liveSubmitEnabled)
        let playerFirst = ClubCreatePageModel.interpret(owned: .list([81]), accountRole: "club", gate: ClubCreationGate(isConfigured: true, writeAvailability: .syntheticOnly), onPlayerFirstEntry: true)
        XCTAssertFalse(playerFirst.offersForm)
        XCTAssertFalse(playerFirst.liveSubmitEnabled)
    }
}
#endif

@MainActor private final class CreatePageReadAccess: ClubOperationsAccess {
    var identity: ClubReadIdentity? = .init(accountID: 701, epoch: 1)
    var isConfigured = true
    var writeAvailability: ClubOperationsWriteAvailability = .unverified
    var reads = 0
    var writes = 0
    func snapshot(target: ClubOperationsTarget) async throws -> ClubOperationsSnapshot {
        reads += 1
        return .init(target: target, accountRole: "club", ownedClubIDs: [])
    }
    func perform(_ command: ClubOperationsCommand, target: ClubOperationsTarget, expectedIdentity: ClubReadIdentity) async throws -> ClubOperationsReceipt {
        writes += 1
        throw APIError.invalidRequest
    }
}
